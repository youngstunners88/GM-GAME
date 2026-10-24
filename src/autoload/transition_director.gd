extends CanvasLayer
## TransitionDirector: the ONE place a big hand-off between game modes is staged (autoload).
##
## Founder 2026-10-03: boss 3 -> Episode 2 "takes forever to load with the blue screen". Root cause (measured by
## reading the path): the hand-off used SceneRouter.load_scene(EPISODE2, DIAMOND). On web that routes to a
## SYNCHRONOUS change_scene_to_file after a dark-blue diamond wipe, so the whole of Episode 2 (scene + ~40 GLBs +
## textures + audio) was read and built while the player stared at a frozen blue wipe.
##
## The fix is a small state machine plus a rule:  NOTHING HEAVY HAPPENS IN FRONT OF THE PLAYER.
##
##   IDLE -> WARMING -> READY -> COVERING -> LOADING -> SWAPPING -> REVEALING -> IDLE
##
##  * `prewarm(path)`  (call it as EARLY as the destination is known: the moment boss 3 dies, so the death tween and
##    the 15 s victory film hide the work). Resources are loaded ONE AT A TIME inside a per-frame time budget
##    (BUDGET_MS) and held in `_hold` (Godot's cache only keeps what is referenced), so the film never hitches and
##    web needs no threads.
##  * `go(path, card)` covers the screen with a dark loading CARD (title + progress bar, never the blue wipe),
##    finishes any remaining warm-up while the progress bar moves, swaps the scene from the already-loaded
##    PackedScene (instant), keeps the card up while the new scene's own _ready runs, then fades it away.
##  * The global StateMachine follows: TRANSITIONING from the cover to the swap, PLAYING once revealed. A failure
##    at any step recovers (StateMachine.recover_from_transition) instead of soft-locking on the card.
##
## PHONE RULES (mobile transitions audit, 2026-10-22; DECISIONS section 5):
##  * The menu route (the EPISODE 2 button, ?ep2=1) is diverted here by SceneRouter.load_scene, so the same card, the
##    same warm-up and the same reveal serve it. The card is sized in dp and WORDLESS on a touch device
##    (TouchUi.keys_shown() == false): a drawn mine-cart glyph and ONE progress bar, no Labels. Desktop keeps its words.
##  * The old scene is FROZEN (the tree is paused; the director and AudioManager are PROCESS_MODE_ALWAYS) from the cover
##    until the reveal, so the dead level does not burn CPU under the cover and the new scene's physics (the runner) does
##    not start under a half-opaque cover. The pause is re-asserted after every StateMachine change.
##  * A cover that has been up longer than ALIVE_AFTER_SECONDS grows the same progress bar ("the game is alive").
##  * A failed swap fades and frees the cover, recovers the StateMachine and routes to the menu (home glyph), never a
##    frozen frame that eats every touch.
##  * `[TD] <from>-><to> t=<ms>` is printed at every state change and `[TD] stall <ms> <path>` for any single warm /
##    settle hitch over STALL_MS, so a phone session can be diagnosed from the console alone.
##
## Skill: .claude/skills/ep2-seamless-transition/SKILL.md. Test: tests/transition_director_test.gd.

signal state_changed(from_state: String, to_state: String)
signal progress(fraction: float)
signal finished(scene_path: String)
## A hand-off failed (the scene could not be built) and the screen was recovered.
signal aborted(scene_path: String)

enum S { IDLE, WARMING, READY, COVERING, LOADING, SWAPPING, REVEALING }

## Per-frame time given to warming while a film or the game is running (ms). Small on purpose: ~1 frame in 3 at 60 fps.
const BUDGET_MS := 5.0
## While the card is up nothing else is rendering, so warming may use much more of each frame.
const BUDGET_COVERED_MS := 60.0
const COVER_SECONDS := 0.22
const REVEAL_SECONDS := 0.55
## Minimum time the card shows once it is up (a flash of card is worse than a calm beat).
const MIN_CARD_SECONDS := 0.55
## The new scene gets this many rendered frames to run its _ready and draw once before the card lifts.
const SETTLE_FRAMES := 3
## Never wait forever: past this the swap happens anyway (and a failed load recovers).
const MAX_WAIT_SECONDS := 30.0
const MAX_SETTLE_SECONDS := 3.0
## A frame longer than this is "the stall" (shader compile / texture upload at the first draw).
const STALL_MS := 250.0
## Film-frame -> live runner dissolve.
const DISSOLVE_SECONDS := 0.18
## A cover (the film's frozen last frame) that has been up this long shows the progress bar: after ~1.2 s of an
## unmoving picture a phone player starts to think the game crashed. It fades in over ALIVE_FADE_SECONDS.
const ALIVE_AFTER_SECONDS := 1.2
const ALIVE_FADE_SECONDS := 0.3
## Failed swap: how long the cover / card takes to fade away once the menu route has been revealed (or given up on).
const ABORT_FADE_SECONDS := 0.3
const ABORT_ROUTE_WAIT_SECONDS := 3.0
## Touch sizes in dp (CSS px): the bar is at least 8 dp thick and about half the short side long.
const TOUCH_BAR_DP := 10.0
const TOUCH_GLYPH_DP := Vector2(88.0, 64.0)

## Named warm-up lists: directories whose resources are loaded ahead of the swap, besides the scene's own
## dependency tree. Episode 2 = every model/texture/sound of the runner, the hideout and the film.
## The two runner tracks are listed explicitly: they live in src/assets/music/, outside the preset directories, and
## the first runner leg plays them the moment the cover lifts (RunnerGraybox), so they must already be in memory.
const PRESETS := {
	"res://src/episode2/ep2_entry.tscn": {
		"dirs": ["res://src/episode2/assets/textures/"],
		"exts": ["glb", "jpg", "png", "wav", "mp3"],
		## Only opening-runner assets block entry; the root warms the hideout during play.
		"files": ["res://src/assets/music/ep2_deep_mining_theme.mp3",
			"res://src/assets/music/runner_run.mp3", "res://src/assets/music/runner_run_1.mp3",
			"res://src/episode2/assets/bear_rigged.glb",
			"res://src/episode2/assets/golden_revolver.glb",
			"res://src/episode2/assets/pickaxe.glb",
			"res://src/episode2/assets/ore_cart.glb",
			"res://src/episode2/assets/minecart.glb",
			"res://src/episode2/assets/lantern.glb",
			"res://src/episode2/assets/boulder_rock.glb",
			"res://src/episode2/assets/boulder.glb",
			"res://src/episode2/assets/gold_pile.glb",
			"res://src/episode2/assets/rock_chunk.glb",
			"res://src/episode2/assets/mine_tunnel_shell.glb",
			"res://src/episode2/assets/leaf_cart.glb",
			"res://src/episode2/assets/leaf_cart_wreck_a.glb",
			"res://src/episode2/assets/leaf_cart_wreck_b.glb",
			"res://src/episode2/assets/lil_blunt_hero.glb",
			"res://src/episode2/assets/mine_bear_archer.glb"],
		"title": "EPISODE 2",
		"subtitle": "THE GOLD MINE",
	},
}

var state: int = S.IDLE
var target_path: String = ""

var _queue: Array = []          # resource paths still to load
var _late: Array = []           # scripts/scenes: loaded only once the card covers the screen
var _total: int = 0
var _hold: Array = []           # strong refs so the resource cache keeps everything we loaded
var _packed: PackedScene = null
var _card: Control = null
var _bar: ColorRect = null
var _bar_bg: ColorRect = null
var _title: Label = null
var _subtitle: Label = null
var _bg: ColorRect = null
var _glyph: CardGlyph = null    # the drawn mine cart (or home) on a wordless touch card
var _prog: Control = null       # holds the ONE progress affordance (_bar_bg + _bar); above the card AND the cover
var _cover: Control = null      # the film's last frame, when it is used as the cover instead of the card
var _going: bool = false
var _frozen: bool = false       # the tree is paused for the hand-off (re-asserted every frame and after state changes)
var _alive_k: float = 0.0       # 0..1: how far the cover's "alive" bar has faded in
## Where a failed hand-off routes to ("" = the real main menu). A var so a test can point it at a fixture.
var home_scene_path: String = ""
## Diagnostics / tests: failed hand-offs so far, and how long the last compile_now prewarm froze the frame (ms).
var abort_count: int = 0
var last_compile_ms: float = 0.0
var _waited: float = 0.0
var _shown_for: float = 0.0
var _settle: int = 0
var _fade_t: float = 0.0
var _fade_from: float = 0.0
var _fade_to: float = 0.0
var _fade_len: float = 0.0
var _fade_active: bool = false
var _progress_shown: float = 0.0
var _bar_w: float = 440.0       # full width of the progress bar (set by _apply_card_layout)
## Diagnostics: [ms, path] of every warm-up item that took long (a long item stalls one frame of the film).
var slow_items: Array = []

# --- GPU warm-up (measured 2026-10-03: after everything is loaded, the FIRST DRAW of Episode 2 still stalls for
# 2.2-3.7 s (software GL; shader compiles + texture uploads run on the main thread). Loading cannot fix that, drawing
# can: every warmed model is drawn once, one at a time with a gap, in a tiny hidden SubViewport while the film plays,
# so the compile cost is paid as single-frame blips instead of one long freeze at the cut.)
const RENDER_GAP_SECONDS := 0.3
var _render_queue: Array = []   # PackedScenes (from .glb) still to be drawn once
var _warm_vp: SubViewport = null
var _warm_cam: Camera3D = null
var _warm_holder: Node3D = null
var _render_cooldown: float = 0.0
var rendered_count: int = 0


func _ready() -> void:
	layer = 110                    # above SceneTransition and every HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_card()
	# A rotation / resize while the card or the cover is up re-lays the glyph, words and bar out for the new shape.
	get_viewport().size_changed.connect(_apply_card_layout)
	set_process(false)


func _build_card() -> void:
	_card = Control.new()
	_card.name = "Card"
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP      # eats clicks while covering
	_card.visible = false
	add_child(_card)
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.015, 0.03, 1.0)           # the project clear colour family: black-violet, NEVER blue
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_bg)
	# Words: desktop only (a phone card is wordless). Positions are set by _apply_card_layout() from the live viewport.
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_subtitle)
	# Wordless identity on a touch card: a drawn mine cart (or, after a failed hand-off, a house).
	_glyph = CardGlyph.new()
	_glyph.name = "Glyph"
	_glyph.visible = false
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_glyph)
	# THE one progress affordance. It lives beside the card (not inside it) so it can also sit above a cover: the film's
	# frozen last frame that has been up for a while needs the same "the game is alive" bar as the card does.
	_prog = Control.new()
	_prog.name = "Progress"
	_prog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prog.visible = false
	add_child(_prog)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.18, 0.12, 0.08, 1.0)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prog.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.72, 0.25, 1.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prog.add_child(_bar)
	_apply_card_layout()


## Place the card's words / glyph and the progress bar for the CURRENT viewport and device. Touch (no key names
## shown): dp-sized, wordless, a bar >= 8 dp thick and about half the short side long. Desktop: the original centred
## title + subtitle + 440 x 8 bar. In cover mode only the bar is used, low and centred over the film frame.
func _apply_card_layout() -> void:
	if _card == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var wordless: bool = not TouchUi.keys_shown()
	var cover_mode: bool = _cover != null
	var bar_pos: Vector2
	var bar_size: Vector2
	if wordless:
		var dp: float = maxf(TouchUi.metrics().dp, 0.25)       # canvas units per dp
		var gs: Vector2 = TOUCH_GLYPH_DP * dp
		var bar_w: float = clampf(minf(vp.x, vp.y) * 0.5, 140.0 * dp, 420.0 * dp)
		var bar_h: float = TOUCH_BAR_DP * dp
		var gap: float = 22.0 * dp
		var top: float = (vp.y - (gs.y + gap + bar_h)) * 0.5
		_glyph.position = Vector2((vp.x - gs.x) * 0.5, top)
		_glyph.size = gs
		bar_size = Vector2(bar_w, bar_h)
		bar_pos = Vector2((vp.x - bar_w) * 0.5, top + gs.y + gap)
		if cover_mode:
			bar_pos = Vector2((vp.x - bar_w) * 0.5, vp.y - bar_h - 30.0 * dp)
	else:
		_title.position = Vector2((vp.x - 720.0) * 0.5, vp.y * 0.5 - 70.0)
		_title.size = Vector2(720.0, 60.0)
		_subtitle.position = Vector2((vp.x - 720.0) * 0.5, vp.y * 0.5 - 8.0)
		_subtitle.size = Vector2(720.0, 40.0)
		bar_size = Vector2(440.0, 8.0)
		bar_pos = Vector2(vp.x * 0.5 - 220.0, vp.y * 0.5 + 50.0)
		if cover_mode:
			bar_size = Vector2(260.0, 6.0)
			bar_pos = Vector2((vp.x - 260.0) * 0.5, vp.y - 42.0)
	_title.visible = not wordless
	_subtitle.visible = not wordless
	_glyph.visible = wordless and not cover_mode
	_bar_w = bar_size.x
	_bar_bg.position = bar_pos
	_bar_bg.size = bar_size
	_bar.position = bar_pos
	_bar.size = Vector2(_bar_w * clampf(_progress_shown, 0.0, 1.0), bar_size.y)


# --- State -------------------------------------------------------------------------------------------------

func _set_state(s: int) -> void:
	if s == state:
		return
	var from: String = S.keys()[state]
	state = s
	# One short line per change: a phone session is diagnosed from the browser console (and ?debug=1 beacons).
	print("[TD] %s->%s t=%d" % [from, S.keys()[state], Time.get_ticks_msec()])
	state_changed.emit(from, S.keys()[state])


func is_busy() -> bool:
	return state >= S.COVERING


## True while a hand-off is holding the NEW scene under the cover: from the cover until the reveal begins (COVERING,
## LOADING and SWAPPING, which includes the settle). The scene that has just been swapped in asks this in its _ready
## and in its physics tick: the first runner leg does not move, and does not start its music, until it turns false
## (the director is at REVEALING). Later legs, retries and a scene started without the director are never held.
func handoff_holding() -> bool:
	return _going and state >= S.COVERING and state < S.REVEALING


## True once nothing the player can see is moving any more: a COVER (the film's frozen last frame) is opaque from the first
## covering frame; the black CARD is only opaque once it has faded in (LOADING). The script / scene compiles (the one
## multi-hundred-ms stall) wait for this, so a half-faded card is never frozen by them.
func is_screen_covered() -> bool:
	return state >= S.LOADING or (state == S.COVERING and _cover != null)


func is_ready_for(path: String) -> bool:
	return target_path == path and state == S.READY


## 0..1: how much of the destination is already in memory.
func warm_fraction() -> float:
	if _total <= 0:
		return 1.0 if state == S.READY else 0.0
	return 1.0 - float(_queue.size() + _late.size()) / float(_total)


# --- Warming -----------------------------------------------------------------------------------------------

## Start loading `path` and everything it needs, a little per frame. Safe to call repeatedly (a second call for the
## same path does nothing; a different path while idle restarts for the new one).
func prewarm(path: String, compile_now: bool = false) -> void:
	if is_busy():
		return
	if path == target_path and state in [S.WARMING, S.READY]:
		return
	_reset_warm()
	target_path = path
	_queue = _build_queue(path)
	_total = _queue.size()
	_set_state(S.WARMING)
	set_process(true)
	if compile_now:
		# Script/scene compiles are the ONE multi-hundred-ms stall (453 ms measured). Pay it right now, at a moment
		# nobody is watching a moving picture (boss death tween), instead of at the cut.
		var keep: Array = []
		var t_compile: int = Time.get_ticks_usec()
		for p in _queue:
			if str(p).get_extension().to_lower() in ["gd", "tscn", "scn"]:
				var t_item: int = Time.get_ticks_usec()
				var r: Resource = ResourceLoader.load(str(p))
				_note_stall(float(Time.get_ticks_usec() - t_item) / 1000.0, str(p))
				if r != null:
					_hold.append(r)
					if str(p) == path and r is PackedScene:
						_packed = r
			else:
				keep.append(p)
		_queue = keep
		# MEASURED, not assumed: the whole compile is ONE blocking frame (the transitive preload closure sits inside a
		# single ResourceLoader.load; GDScript reports no preload dependencies, so it cannot be sliced per item).
		last_compile_ms = float(Time.get_ticks_usec() - t_compile) / 1000.0
		print("[TD] compile_now %d ms (%s)" % [int(last_compile_ms), path])


func _reset_warm() -> void:
	_queue.clear()
	_late.clear()
	_render_queue.clear()
	_hold.clear()
	_packed = null
	_total = 0
	_progress_shown = 0.0
	_set_state(S.IDLE)


func _build_queue(path: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var preset: Dictionary = PRESETS.get(path, {})
	# Dependencies first (textures/meshes the scene itself names), the scene file LAST: loading it last means every
	# sub-resource it instantiates is already cached.
	for dep in _collect_deps(path, seen):
		out.append(dep)
	var exts: Array = preset.get("exts", [])
	for d in preset.get("dirs", []):
		for f in DirAccess.get_files_at(str(d)):
			var ext: String = f.get_extension().to_lower()
			if ext in exts:
				var p: String = str(d) + f
				if not seen.has(p):
					seen[p] = true
					out.append(p)
	for f in preset.get("files", []):
		if not seen.has(str(f)) and ResourceLoader.exists(str(f)):
			seen[str(f)] = true
			out.append(str(f))
	if not seen.has(path):
		out.append(path)
	return out


func _collect_deps(path: String, seen: Dictionary) -> Array:
	var out: Array = []
	if seen.has(path) or not ResourceLoader.exists(path):
		return out
	seen[path] = true
	for dep in ResourceLoader.get_dependencies(path):
		var p: String = str(dep)
		if "::::" in p:                    # "uid://...::::res://path"
			p = p.split("::::")[1]
		elif p.begins_with("uid://") and "::" in p:
			p = p.split("::")[-1]
		if p.begins_with("res://") and not seen.has(p):
			out.append_array(_collect_deps(p, seen))
	out.append(path)
	return out


func _process(delta: float) -> void:
	if _frozen and not get_tree().paused:
		get_tree().paused = true         # something unpaused the tree under the cover (a scene's _ready, a state change)
	if state == S.WARMING or state == S.READY:
		_pump_render(delta)
		if state == S.READY and _render_queue.is_empty() and not _going:
			set_process(false)
	if state == S.WARMING or state == S.LOADING or (state == S.COVERING and _cover != null):
		_pump_warm(BUDGET_COVERED_MS if state >= S.COVERING else BUDGET_MS)
	if _fade_active:
		_fade_t += delta
		var k: float = clampf(_fade_t / maxf(_fade_len, 0.001), 0.0, 1.0)
		_card.modulate.a = lerpf(_fade_from, _fade_to, k)
		if k >= 1.0:
			_fade_active = false
	if _going:
		_waited += delta
		if _card.visible:
			_shown_for += delta
	_update_bar(delta)


## Load queued resources until this frame's time budget is spent.
func _pump_warm(budget_ms: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var covered: bool = is_screen_covered()
	while not _queue.is_empty():
		var p: String = str(_queue.front())
		# Script compiles and scene parses are single multi-hundred-millisecond stalls (ep2_entry.gd alone measured
		# 453 ms: it compiles the whole runner). They never run in front of the player: they wait for the card.
		if not covered and p.get_extension().to_lower() in ["gd", "tscn", "scn"]:
			_late.append(_queue.pop_front())
			continue
		_queue.pop_front()
		var t_item: int = Time.get_ticks_usec()
		var r: Resource = ResourceLoader.load(p)
		var item_ms: float = float(Time.get_ticks_usec() - t_item) / 1000.0
		if item_ms > 40.0:
			slow_items.append([item_ms, p])
		_note_stall(item_ms, p)
		if r != null:
			_hold.append(r)
			if p == target_path and r is PackedScene:
				_packed = r
			elif r is PackedScene and p.get_extension().to_lower() == "glb":
				_render_queue.append(r)
		if float(Time.get_ticks_usec() - t0) / 1000.0 >= budget_ms:
			break
	if covered and _queue.is_empty() and not _late.is_empty():
		_queue = _late.duplicate()
		_late.clear()
	if _queue.is_empty() and _late.is_empty() and state == S.WARMING:
		_set_state(S.READY)
		if not _going and _render_queue.is_empty():
			set_process(false)


## `[TD] stall <ms> <path>`: one blocking item (or settle frame) over STALL_MS. Counted in `stall_count` for tests.
var stall_count: int = 0
func _note_stall(ms: float, what: String) -> void:
	if ms > STALL_MS:
		stall_count += 1
		print("[TD] stall %d %s" % [int(ms), what])


## Draw one warmed model into the hidden viewport (compiling its shaders / uploading its textures), at most one per
## RENDER_GAP_SECONDS, so the film only ever sees a one-frame blip.
func _pump_render(delta: float) -> void:
	_render_cooldown -= delta
	if _render_cooldown > 0.0 or _render_queue.is_empty():
		return
	_ensure_warm_viewport()
	for c in _warm_holder.get_children():
		c.queue_free()
	var ps: PackedScene = _render_queue.pop_front()
	var inst: Node = ps.instantiate()
	_warm_holder.add_child(inst)
	var box: AABB = _aabb_of(inst)
	var centre: Vector3 = box.get_center()
	var radius: float = maxf(box.size.length() * 0.5, 0.25)
	_warm_cam.position = centre + Vector3(0.0, radius * 0.35, radius * 2.4)
	_warm_cam.look_at(centre)
	_warm_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	rendered_count += 1
	_render_cooldown = RENDER_GAP_SECONDS


func _ensure_warm_viewport() -> void:
	if _warm_vp != null:
		return
	_warm_vp = SubViewport.new()
	_warm_vp.size = Vector2i(64, 64)
	_warm_vp.transparent_bg = true
	_warm_vp.own_world_3d = true
	_warm_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_warm_vp)               # never shown: it has no TextureRect; it only has to DRAW
	_warm_holder = Node3D.new()
	_warm_vp.add_child(_warm_holder)
	_warm_cam = Camera3D.new()
	_warm_cam.far = 200.0
	_warm_vp.add_child(_warm_cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_warm_vp.add_child(sun)


func _aabb_of(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi: MeshInstance3D = cur
			if mi.mesh != null:
				var a: AABB = mi.global_transform * mi.mesh.get_aabb()
				out = a if first else out.merge(a)
				first = false
		for c in cur.get_children():
			stack.append(c)
	return out if not first else AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)


func _update_bar(delta: float) -> void:
	var f: float = warm_fraction()
	_progress_shown = move_toward(_progress_shown, f, delta * 1.6)
	progress.emit(_progress_shown)
	if _bar:
		_bar.size.x = _bar_w * clampf(_progress_shown, 0.0, 1.0)
	_update_progress_alpha()


## The ONE progress affordance. On the card it follows the card's own fade. On a cover (the film's frozen last frame) it
## stays invisible for ALIVE_AFTER_SECONDS, then fades in ("the game is alive, still loading"), and fades out with the
## cover's dissolve.
func _update_progress_alpha() -> void:
	if _prog == null or not _prog.visible:
		return
	if _cover != null and is_instance_valid(_cover):
		_alive_k = clampf((_waited - ALIVE_AFTER_SECONDS) / ALIVE_FADE_SECONDS, 0.0, 1.0)
		_prog.modulate.a = _alive_k * _cover.modulate.a
	else:
		_prog.modulate.a = _card.modulate.a if _card.visible else 0.0


# --- The hand-off ------------------------------------------------------------------------------------------

## Cover, finish loading, swap, settle, reveal. Returns immediately (the work runs over frames; await `finished`).
## `card_title` / `card_subtitle` override the preset's wording (desktop only: a touch card is wordless).
func go(path: String, card_title: String = "", card_subtitle: String = "", cover: Control = null) -> void:
	if _going:
		if cover != null and cover != _cover and not cover.is_inside_tree():
			cover.queue_free()                 # a second hand-off's cover would otherwise leak
		return                             # one hand-off at a time
	if not ResourceLoader.exists(path):
		push_error("TransitionDirector: %s does not exist" % path)
		ErrorReporter.report("scene_load_failed", {"path": path, "route": "transition_director"})
		_fail_early(path, cover)
		return
	_going = true
	_waited = 0.0
	_shown_for = 0.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	if target_path != path or state == S.IDLE:
		_reset_warm()
		target_path = path
		_queue = _build_queue(path)
		_total = _queue.size()
	var preset: Dictionary = PRESETS.get(path, {})
	_title.text = card_title if card_title != "" else str(preset.get("title", ""))
	_subtitle.text = card_subtitle if card_subtitle != "" else str(preset.get("subtitle", ""))
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	# FREEZE the old scene under the cover (the tree is paused; the director and AudioManager are PROCESS_MODE_ALWAYS).
	# change_state(TRANSITIONING) just unpaused the tree, so this comes AFTER it and is re-asserted on every state change.
	_set_frozen(true)
	_cover = cover
	_alive_k = 0.0
	_prog.modulate.a = 0.0
	_bg.visible = true
	_glyph.kind = CardGlyph.CART
	_apply_card_layout()
	if _cover != null:
		# SEAMLESS MODE: the film's own last frame (Lil Blunt in the cart) IS the cover. No card, no black: the
		# frame stays on screen while Episode 2 loads, builds and draws for the first time behind it, then dissolves
		# into the live runner. (Jev simulation 2026-10-03 ranked this above the black card: tools/ep2_sim.)
		add_child(_cover)
		_cover.modulate.a = 1.0
	move_child(_prog, get_child_count() - 1)       # the progress bar is above the card AND the cover
	_prog.visible = true
	set_process(true)
	_run(path)


func _run(path: String) -> void:
	# 1. COVER: the card comes up fast. It is black-violet, not the blue wipe.
	_set_state(S.COVERING)
	if _cover == null:
		_card.visible = true
		_card.modulate.a = 0.0
		_start_fade(0.0, 1.0, COVER_SECONDS)
		await get_tree().create_timer(COVER_SECONDS).timeout
	else:
		_shown_for = MIN_CARD_SECONDS            # the frame was already on screen: no minimum hold
	# 2. LOAD whatever the pre-warm did not finish, behind the card, with a visible bar.
	_set_state(S.LOADING)
	while (not _queue.is_empty() or not _late.is_empty()) and _waited < MAX_WAIT_SECONDS:
		await get_tree().process_frame
	if _packed == null:
		var r: Resource = ResourceLoader.load(path)     # cached already when warm; a plain load otherwise
		_packed = r as PackedScene
	while _shown_for < MIN_CARD_SECONDS:
		await get_tree().process_frame
	_progress_shown = 1.0
	# 3. SWAP: instant, from memory.
	_set_state(S.SWAPPING)
	var err: int = ERR_CANT_OPEN
	if _packed != null:
		err = get_tree().change_scene_to_packed(_packed)
	if err != OK:
		push_error("TransitionDirector: scene change failed for %s (err %d)" % [path, err])
		ErrorReporter.report("scene_load_failed", {"path": path, "err": err, "route": "transition_director"})
		_abort(path)
		return
	# 4. SETTLE: the new scene runs its _ready and does its FIRST DRAW (the long stall: shader compiles + texture
	# uploads) under the cover. Wait until the frames are smooth again (4 in a row under 50 ms), never longer than
	# MAX_SETTLE_SECONDS, so the cover lifts on a scene that is already running smoothly.
	_settle = 0
	var calm_after_stall: int = 0
	var saw_stall: bool = false
	var t_settle: int = Time.get_ticks_msec()
	var last_us: int = Time.get_ticks_usec()
	while float(Time.get_ticks_msec() - t_settle) / 1000.0 < MAX_SETTLE_SECONDS:
		await get_tree().process_frame
		var now_us: int = Time.get_ticks_usec()
		var frame_ms: float = float(now_us - last_us) / 1000.0
		last_us = now_us
		_settle += 1
		_note_stall(frame_ms, path)
		if frame_ms > STALL_MS:
			saw_stall = true                  # the first draw's compile/upload hitch happened (hidden under the cover)
			calm_after_stall = 0
		elif saw_stall:
			calm_after_stall += 1
		# Done once the hitch is behind us (2 normal frames after it), or nothing stalled for a few frames.
		if (saw_stall and calm_after_stall >= 2) or (not saw_stall and _settle >= SETTLE_FRAMES + 3):
			break
	# 5. REVEAL. The freeze ends HERE (before the StateMachine change that unpauses the tree), so the new scene's
	# physics starts with the dissolve and not a moment before.
	_set_state(S.REVEALING)
	_set_frozen(false)
	StateMachine.change_state(StateMachine.State.PLAYING)
	if _cover != null:
		var tw := create_tween()
		tw.tween_property(_cover, "modulate:a", 0.0, DISSOLVE_SECONDS)
		await tw.finished
		_cover.queue_free()
		_cover = null
	else:
		_start_fade(1.0, 0.0, REVEAL_SECONDS)
		await get_tree().create_timer(REVEAL_SECONDS).timeout
	_finish(path)


func _start_fade(from_a: float, to_a: float, seconds: float) -> void:
	_fade_from = from_a
	_fade_to = to_a
	_fade_len = seconds
	_fade_t = 0.0
	_fade_active = true


# --- The freeze --------------------------------------------------------------------------------------------

## While frozen the tree is paused: the dying scene stops burning CPU and the scene that was just swapped in cannot
## start its physics under the cover. `StateMachine.change_state` re-applies `paused = (state == PAUSED)` every time,
## so the pause is re-asserted after every state change and once per frame (the new scene's _ready may unpause too).
func _set_frozen(on: bool) -> void:
	_frozen = on
	var linked: bool = StateMachine.state_changed.is_connected(_on_state_changed_while_frozen)
	if on:
		get_tree().paused = true
		if not linked:
			StateMachine.state_changed.connect(_on_state_changed_while_frozen)
	elif linked:
		StateMachine.state_changed.disconnect(_on_state_changed_while_frozen)


func _on_state_changed_while_frozen(_from: String, _to: String) -> void:
	if _frozen:
		get_tree().paused = true


func is_frozen() -> bool:
	return _frozen


# --- Failure: never leave a frozen frame that eats every touch -----------------------------------------------

## Where a failed hand-off sends the player.
func _home_path() -> String:
	return home_scene_path if home_scene_path != "" else GameManager.MENU_SCENE


## Already on the home scene (the menu route failed from the menu itself)? Then there is nowhere to route to.
func _should_go_home() -> bool:
	var cs: Node = get_tree().current_scene
	return cs == null or cs.scene_file_path != _home_path()


## `go()` could not even start (the destination is missing from the build). The caller may already have torn its own
## scene down (a boss frees itself before handing off), so the cover it passed is freed, never left orphaned, and the
## StateMachine goes back to where it was; the player is routed home.
func _fail_early(path: String, cover: Control) -> void:
	abort_count += 1
	if cover != null and is_instance_valid(cover):
		cover.queue_free()
	StateMachine.recover_from_transition()
	aborted.emit(path)
	_recover_screen(null, _should_go_home())


## The swap itself failed (the scene could not be built: out of memory on a phone, a broken pack). The warm hold is
## cleared on purpose (so there is NO retry-go loop under a frozen frame), the freeze ends, the StateMachine recovers,
## and the cover / card shows a house while the menu route runs, then fades away.
func _abort(path: String) -> void:
	abort_count += 1
	var cover: Control = _cover
	_cover = null
	_going = false
	_fade_active = false
	_set_frozen(false)                     # BEFORE recover_from_transition, so the pause is not re-asserted
	_reset_warm()
	target_path = ""
	_prog.visible = false
	StateMachine.recover_from_transition()
	set_process(false)
	aborted.emit(path)
	_recover_screen(cover, _should_go_home())


## Fade the cover / card away; when going home, show the house glyph, route to the menu and wait for ITS reveal first
## (the menu loads underneath, so the player never sees the dead scene). Bounded: a menu route that never reveals
## still ends with the cover freed after ABORT_ROUTE_WAIT_SECONDS.
func _recover_screen(cover: Control, go_home: bool) -> void:
	var covering: bool = (cover != null and is_instance_valid(cover)) or _card.visible
	if go_home:
		if covering:
			_show_home_glyph(cover != null)
		SceneRouter.load_scene(_home_path(), SceneRouter.Transition.FADE)
		var t0: int = Time.get_ticks_msec()
		while not SceneRouter.is_revealed() and float(Time.get_ticks_msec() - t0) / 1000.0 < ABORT_ROUTE_WAIT_SECONDS:
			await get_tree().process_frame
	if covering:
		var tw := create_tween()
		tw.set_parallel(true)
		if cover != null and is_instance_valid(cover):
			tw.tween_property(cover, "modulate:a", 0.0, ABORT_FADE_SECONDS)
		if _card.visible:
			tw.tween_property(_card, "modulate:a", 0.0, ABORT_FADE_SECONDS)
		await tw.finished
	if cover != null and is_instance_valid(cover):
		cover.queue_free()
	if not _going:                         # a NEW hand-off (a second tap) already owns the card: do not hide it
		_hide_card()


## A drawn house, centred, on the card (or, over a cover, on a dark disc so it reads on any frame).
func _show_home_glyph(over_cover: bool) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var dp: float = 1.0
	if not TouchUi.keys_shown():
		dp = maxf(TouchUi.metrics().dp, 0.25)
	var gs: Vector2 = TOUCH_GLYPH_DP * dp
	_title.visible = false
	_subtitle.visible = false
	_bg.visible = not over_cover
	if over_cover:
		# The cover was added AFTER the card, so it draws above it: lift the card (its house sits on a dark disc) over the
		# cover, but still below the progress node, or the house would be hidden behind an opaque film frame.
		move_child(_card, maxi(_prog.get_index() - 1, 0))
	_glyph.kind = CardGlyph.HOME
	_glyph.size = gs
	_glyph.position = (vp - gs) * 0.5
	_glyph.visible = true
	_card.modulate.a = 1.0
	_card.visible = true


func _hide_card() -> void:
	_card.visible = false
	_card.modulate.a = 1.0
	move_child(_card, 0)                   # back under any cover (a failed hand-off lifted it)
	_bg.visible = true
	_glyph.kind = CardGlyph.CART
	_prog.visible = false
	_prog.modulate.a = 1.0


func _finish(path: String) -> void:
	_set_frozen(false)
	_hide_card()
	_going = false
	# `_hold` is KEPT on purpose: the hideout's models are only requested later (when the chamber is built), and
	# dropping our references now would evict them from the cache and bring the hitch back. The next prewarm() /
	# reset frees them.
	_packed = null
	_queue.clear()
	var done_path: String = path
	target_path = ""
	_set_state(S.IDLE)
	set_process(false)
	finished.emit(done_path)


# --- Drawn glyphs (no texture files: the web pack has no room, and a phone card carries no words) -----------

## A mine cart on its rail (the Episode 2 card) or a house (a failed hand-off heading home), drawn with primitives.
class CardGlyph extends Control:
	const CART := 0
	const HOME := 1
	var kind: int = CART:
		set(v):
			kind = v
			queue_redraw()
	var tint: Color = Color(1.0, 0.82, 0.38)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 1.0 or h <= 1.0:
			return
		var lw: float = maxf(2.0, h * 0.07)
		if kind == HOME:
			var c: Vector2 = size * 0.5
			draw_circle(c, minf(w, h) * 0.62, Color(0.02, 0.015, 0.03, 0.78))
			var roof := PackedVector2Array([Vector2(w * 0.20, h * 0.48), Vector2(w * 0.50, h * 0.16),
					Vector2(w * 0.80, h * 0.48)])
			draw_polyline(roof, tint, lw)
			var body := PackedVector2Array([Vector2(w * 0.28, h * 0.46), Vector2(w * 0.28, h * 0.84),
					Vector2(w * 0.72, h * 0.84), Vector2(w * 0.72, h * 0.46)])
			draw_polyline(body, tint, lw)
			draw_line(Vector2(w * 0.44, h * 0.84), Vector2(w * 0.44, h * 0.62), tint, lw)
			draw_line(Vector2(w * 0.56, h * 0.84), Vector2(w * 0.56, h * 0.62), tint, lw)
			draw_line(Vector2(w * 0.44, h * 0.62), Vector2(w * 0.56, h * 0.62), tint, lw)
			return
		# the cart: a tapered tub with a rim, two wheels, and the rail it runs on
		var tub := PackedVector2Array([Vector2(w * 0.12, h * 0.20), Vector2(w * 0.88, h * 0.20),
				Vector2(w * 0.76, h * 0.66), Vector2(w * 0.24, h * 0.66)])
		draw_colored_polygon(tub, tint.darkened(0.62))
		var outline: PackedVector2Array = tub.duplicate()
		outline.append(tub[0])
		draw_polyline(outline, tint, lw)
		draw_line(Vector2(w * 0.07, h * 0.20), Vector2(w * 0.93, h * 0.20), tint, lw * 1.5)
		draw_circle(Vector2(w * 0.32, h * 0.80), h * 0.115, tint)
		draw_circle(Vector2(w * 0.68, h * 0.80), h * 0.115, tint)
		draw_line(Vector2(0.0, h * 0.95), Vector2(w, h * 0.95), tint.darkened(0.35), lw)
