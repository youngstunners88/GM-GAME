extends CanvasLayer
## F3 truth overlay (merged 2026-08-26 residual, Phase 1). Toggle with F3 (also
## '?debug=1' on web forces it on at boot). Shows the live player + boss state so
## a founder screenshot during a freeze or a "boss parked" moment is hard
## evidence of the actual flags — injected BEFORE trusting any logic claim.
##
## Read-only: it never touches game state, only reports it. Off by default so it
## never covers normal play.
##
## HARNESS BEACON (2026-10-23, scripts/lib/pw.mjs + scripts/mobile-transition-probe.mjs): while the overlay is on
## (?debug=1, F3, or '?debug=beacon' = beacon WITHOUT the on-screen label, so screenshots stay clean) the overlay also
##   * adds SCENE / TOUCH / FRAME / MEM lines to the label, and
##   * posts a SCALAR JSON object about 4 times a second to the embedding page: {type:"gm", value:{...}}, which a
##     Playwright init script stores in window.__gm - so a probe asserts on data, not on pixels. Same fixed-template
##     window.parent.postMessage(JSON.stringify(...)) form as state_machine.gd (sentinel INJ-003 safe; a no-op off web
##     and for cross-origin embeds, e.g. the itch iframe, which also never has ?debug).
##   * answers an ON-DEMAND request for the list of visible text nodes (window.__gmWordsReq is bumped by the page);
##     the tree is only walked when asked, so the 4 Hz beacon stays cheap and does not perturb frame times.

var _label: Label
var _on: bool = false           # label + beacon (?debug=1 / F3)
var _beacon_only: bool = false  # ?debug=beacon: beacon + verbose logging, no label

const BEACON_INTERVAL_USEC: int = 250000
const WORDS_MAX: int = 300
const FRAME_RING: int = 120
const MB: float = 1048576.0

var _frame_ms: PackedFloat32Array = PackedFloat32Array()   # ring of the last FRAME_RING frame times (real ms)
var _frame_i: int = 0
var _last_usec: int = 0
var _worst_window_ms: float = 0.0      # worst frame since the last beacon
var _worst_all_ms: float = 0.0         # worst frame since the overlay turned on
var _frames: int = 0
var _beacon_due_usec: int = 0
var _words_req_seen: int = 0
var _scene_path_seen: String = ""
var _mem_peak_mb: float = 0.0
var _tex_peak_mb: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.position = Vector2(12, 70)
	add_child(_label)
	_label.visible = false
	# Web: allow ?debug=1 to force the overlay on for a founder capture session.
	if OS.has_feature("web"):
		var q: String = str(JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('debug') || ''", true))
		if q == "1":
			_on = true
			_label.visible = true
		elif q == "beacon":
			_beacon_only = true
	_frame_ms.resize(FRAME_RING)

## Is the F3 / ?debug=1 / ?debug=beacon overlay on? (Lets other systems add verbose logging only then.)
func is_on() -> bool:
	return _on or _beacon_only

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F3:
		_on = not _on
		_label.visible = _on

func _process(_delta: float) -> void:
	if not is_on():
		_last_usec = 0
		return
	# Real frame time (not the scaled delta: the film slow-mo and the pause both change Engine.time_scale).
	var now: int = Time.get_ticks_usec()
	if _last_usec != 0:
		var ms: float = float(now - _last_usec) / 1000.0
		_frame_ms[_frame_i % FRAME_RING] = ms
		_frame_i += 1
		_frames += 1
		_worst_window_ms = maxf(_worst_window_ms, ms)
		_worst_all_ms = maxf(_worst_all_ms, ms)
	_last_usec = now
	_sample_memory()
	if _on:
		_label.text = _compose()
	if now >= _beacon_due_usec:
		_beacon_due_usec = now + BEACON_INTERVAL_USEC
		_note_scene_change()
		_post_beacon()
		_answer_words_request()

# --- frame / memory / scene helpers -------------------------------------------------------------------------------

func _avg_ms() -> float:
	var n: int = mini(_frame_i, FRAME_RING)
	if n <= 0:
		return 0.0
	var s: float = 0.0
	for i in n:
		s += _frame_ms[i]
	return s / float(n)

func _scene_path() -> String:
	var cs: Node = get_tree().current_scene
	if cs == null:
		return ""
	return cs.scene_file_path if cs.scene_file_path != "" else str(cs.name)

func _sample_memory() -> void:
	_mem_peak_mb = maxf(_mem_peak_mb, Performance.get_monitor(Performance.MEMORY_STATIC) / MB)
	_tex_peak_mb = maxf(_tex_peak_mb, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB)

## One [MEM] line each time the current scene changes (only while the overlay is on): the probe diffs these.
func _note_scene_change() -> void:
	var p := _scene_path()
	if p == _scene_path_seen:
		return
	_scene_path_seen = p
	print("[MEM] scene=%s static=%.0fMB (peak %.0f) tex=%.0fMB (peak %.0f) video=%.0fMB"
		% [p, Performance.get_monitor(Performance.MEMORY_STATIC) / MB, _mem_peak_mb,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB, _tex_peak_mb,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB])

func _touch_line() -> String:
	var mgr: Node = get_node_or_null("/root/MobileLayoutManager")
	if mgr != null and mgr.has_method("debug_line"):
		return str(mgr.call("debug_line"))
	return "touch (no manager)"

func _held_actions() -> Dictionary:
	var held: Dictionary = {}
	for act: String in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash", "sprint", "interact"]:
		if InputMap.has_action(act) and Input.is_action_pressed(act):
			held[act] = snappedf(Input.get_action_strength(act), 0.01)
	return held

# --- the label ----------------------------------------------------------------------------------------------------

func _compose() -> String:
	var lines: Array[String] = []
	lines.append("BUILD %s   PAUSED %s   TIME_SCALE %.2f"
		% [GameManager.BUILD_TAG, str(get_tree().paused), Engine.time_scale])
	lines.append("STATE %s" % StateMachine.get_current_state())
	lines.append("SCENE %s" % _scene_path())
	lines.append("TOUCH %s" % _touch_line())
	lines.append("FRAME avg %.1f / worst %.1f ms   MEM %.0f MB (peak %.0f)"
		% [_avg_ms(), _worst_window_ms, Performance.get_monitor(Performance.MEMORY_STATIC) / MB, _mem_peak_mb])
	# What the game REALLY sees held (keyboard, gamepad or on-screen touch alike):
	# the ground truth behind any "the button looks pressed / the hero will not move".
	var held := ""
	for act: String in ["move_left", "move_right", "move_up", "move_down", "jump", "attack", "dash", "sprint", "interact"]:
		if InputMap.has_action(act) and Input.is_action_pressed(act):
			held += "%s=%.2f " % [act.trim_prefix("move_"), Input.get_action_strength(act)]
	lines.append("INPUT held: %s" % (held if held != "" else "-"))
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and is_instance_valid(pl):
		var v: Vector2 = pl.get("velocity") if pl.get("velocity") != null else Vector2.ZERO
		lines.append("PLAYER pos(%.0f,%.0f) |v|=%.0f floor=%s wall=%s climb=%s dying=%s scale=%.2f"
			% [pl.global_position.x, pl.global_position.y, v.length(),
				str(pl.call("is_on_floor") if pl.has_method("is_on_floor") else "?"),
				str(pl.call("is_on_wall") if pl.has_method("is_on_wall") else "?"),
				str(pl.get("_climbing")), str(pl.get("_dying")), pl.scale.x])
	# Any live bosses (group "boss"): state + lunge/dive + gap to player.
	for b in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(b):
			continue
		var state_v = b.get("current_state")
		if state_v == null:
			state_v = b.get("current_phase_state")
		var surge = b.get("_surge_active")
		var gap := "?"
		if pl != null and is_instance_valid(pl):
			gap = "%.0f" % absf((b.global_position.x) - pl.global_position.x)
		lines.append("BOSS %s state=%s lunge=%s gap=%s"
			% [str(b.get("boss_display_name")), str(state_v), str(surge), gap])
	return "\n".join(lines)

# --- the beacon (scalars only) ------------------------------------------------------------------------------------

func _beacon_value() -> Dictionary:
	var mgr: Node = get_node_or_null("/root/MobileLayoutManager")
	var touch: Dictionary = {"shown": false, "susp": false, "profile": "", "layout": "", "held": TouchActions.held_count()}
	if mgr != null:
		touch["shown"] = bool(mgr.get("controls_visible"))
		touch["susp"] = bool(mgr.get("controls_suspended"))
		if mgr.has_method("current_profile"):
			touch["profile"] = str(mgr.call("current_profile"))
		if mgr.has_method("current_layout_key"):
			touch["layout"] = str(mgr.call("current_layout_key"))
	var td_state: String = str(TransitionDirector.S.keys()[TransitionDirector.state])
	var td_frozen: bool = TransitionDirector.is_frozen()
	return {
		"t": Time.get_ticks_msec(),
		"build": GameManager.BUILD_TAG,
		"harness": OS.has_feature("gm_harness"),
		"state": StateMachine.get_current_state(),
		"paused": get_tree().paused,
		"time_scale": snappedf(Engine.time_scale, 0.01),
		"scene": _scene_path(),
		"td": td_state,
		"td_frozen": td_frozen,
		"held": _held_actions(),
		"touch": touch,
		"win": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"frames": _frames,
		"avg_ms": snappedf(_avg_ms(), 0.1),
		"worst_ms": snappedf(_worst_window_ms, 0.1),
		"worst_all_ms": snappedf(_worst_all_ms, 0.1),
		"mem_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / MB, 0.1),
		"mem_peak_mb": snappedf(_mem_peak_mb, 0.1),
		"tex_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB, 0.1),
		"tex_peak_mb": snappedf(_tex_peak_mb, 0.1),
	}

func _post_beacon() -> void:
	_worst_window_ms = 0.0
	if not OS.has_feature("web"):
		return
	_post_to_page({"type": "gm", "value": _beacon_value()})

## The ONLY way this file talks to the page: the fixed same-origin postMessage template, payload through
## JSON.stringify (a valid JS literal), exactly as StateMachine._announce_state_to_page.
func _post_to_page(msg: Dictionary) -> void:
	var payload := JSON.stringify(msg)
	JavaScriptBridge.eval(
		"try { window.parent.postMessage(%s, window.location.origin); } catch (e) {}" % payload
	)

# --- on-demand visible-text list ----------------------------------------------------------------------------------

func _answer_words_request() -> void:
	if not OS.has_feature("web"):
		return
	var req: int = int(JavaScriptBridge.eval("window.__gmWordsReq | 0", true))
	if req == _words_req_seen:
		return
	_words_req_seen = req
	_post_to_page({"type": "gm_words", "value": collect_words()})

## Visible text-bearing nodes right now: [{path, text}], at most WORDS_MAX. Public so a headless test can call it.
## Hidden branches, fully transparent branches and this overlay's own label are skipped; secret LineEdits report only
## their placeholder.
func collect_words() -> Array:
	var out: Array = []
	_walk_words(get_tree().root, out)
	return out

func _walk_words(n: Node, out: Array) -> void:
	if out.size() >= WORDS_MAX or n == self:
		return
	if n is CanvasItem:
		var ci := n as CanvasItem
		if not ci.visible:
			return
		if ci.modulate.a < 0.05 or ci.self_modulate.a < 0.05:
			return
	elif n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	elif n is Node3D and not (n as Node3D).visible:
		return
	var text := ""
	if n is Label:
		text = (n as Label).text
	elif n is RichTextLabel:
		text = (n as RichTextLabel).get_parsed_text()
	elif n is BaseButton and n.get("text") != null:
		text = str(n.get("text"))
	elif n is LineEdit:
		var le := n as LineEdit
		text = le.placeholder_text if le.secret else (le.text if le.text != "" else le.placeholder_text)
	elif n is Label3D:
		text = (n as Label3D).text
	text = text.strip_edges()
	if text != "" and n.is_visible_in_tree():
		var entry: Dictionary = {"path": str(n.get_path()), "text": text.substr(0, 80)}
		if n is Control and n.get_viewport() != null:
			# window pixels, so a probe can tap the node: css = px * canvas.clientWidth / beacon.win[0]
			var c := n as Control
			var r: Rect2 = n.get_viewport().get_final_transform() * c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)
			entry["rect"] = [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
		out.append(entry)
	for c: Node in n.get_children():
		_walk_words(c, out)
