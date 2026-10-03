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
## Skill: .claude/skills/ep2-seamless-transition/SKILL.md. Test: tests/transition_director_test.gd.

signal state_changed(from_state: String, to_state: String)
signal progress(fraction: float)
signal finished(scene_path: String)

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
const DISSOLVE_SECONDS := 0.6

## Named warm-up lists: directories whose resources are loaded ahead of the swap, besides the scene's own
## dependency tree. Episode 2 = every model/texture/sound of the runner, the hideout and the film.
const PRESETS := {
	"res://src/episode2/ep2_entry.tscn": {
		"dirs": ["res://src/episode2/assets/", "res://src/episode2/assets/hideout/", "res://src/episode2/assets/textures/",
			"res://src/episode2/assets/audio/"],
		"exts": ["glb", "jpg", "png", "wav", "mp3"],
		"files": ["res://src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv"],
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
var _cover: Control = null      # the film's last frame, when it is used as the cover instead of the card
var _going: bool = false
var _waited: float = 0.0
var _shown_for: float = 0.0
var _settle: int = 0
var _fade_t: float = 0.0
var _fade_from: float = 0.0
var _fade_to: float = 0.0
var _fade_len: float = 0.0
var _fade_active: bool = false
var _progress_shown: float = 0.0
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
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.position = Vector2(-360.0, -70.0)
	_title.size = Vector2(720.0, 60.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	_card.add_child(_title)
	_subtitle = Label.new()
	_subtitle.set_anchors_preset(Control.PRESET_CENTER)
	_subtitle.position = Vector2(-360.0, -8.0)
	_subtitle.size = Vector2(720.0, 40.0)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
	_card.add_child(_subtitle)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.18, 0.12, 0.08, 1.0)
	_bar_bg.set_anchors_preset(Control.PRESET_CENTER)
	_bar_bg.position = Vector2(-220.0, 50.0)
	_bar_bg.size = Vector2(440.0, 8.0)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.72, 0.25, 1.0)
	_bar.set_anchors_preset(Control.PRESET_CENTER)
	_bar.position = Vector2(-220.0, 50.0)
	_bar.size = Vector2(0.0, 8.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_bar)


# --- State -------------------------------------------------------------------------------------------------

func _set_state(s: int) -> void:
	if s == state:
		return
	var from: String = S.keys()[state]
	state = s
	state_changed.emit(from, S.keys()[state])


func is_busy() -> bool:
	return state >= S.COVERING


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
		for p in _queue:
			if str(p).get_extension().to_lower() in ["gd", "tscn", "scn"]:
				var r: Resource = ResourceLoader.load(str(p))
				if r != null:
					_hold.append(r)
					if str(p) == path and r is PackedScene:
						_packed = r
			else:
				keep.append(p)
		_queue = keep


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
	if state == S.WARMING or state == S.READY:
		_pump_render(delta)
		if state == S.READY and _render_queue.is_empty() and not _going:
			set_process(false)
	if state == S.WARMING or state == S.COVERING or state == S.LOADING:
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
	var covered: bool = state >= S.COVERING
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
		_bar.size.x = 440.0 * clampf(_progress_shown, 0.0, 1.0)


# --- The hand-off ------------------------------------------------------------------------------------------

## Cover, finish loading, swap, settle, reveal. Returns immediately (the work runs over frames; await `finished`).
## `card_title` / `card_subtitle` override the preset's wording.
func go(path: String, card_title: String = "", card_subtitle: String = "", cover: Control = null) -> void:
	if _going:
		return                             # one hand-off at a time
	if not ResourceLoader.exists(path):
		push_error("TransitionDirector: %s does not exist" % path)
		ErrorReporter.report("scene_load_failed", {"path": path, "route": "transition_director"})
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
	_cover = cover
	if _cover != null:
		# SEAMLESS MODE: the film's own last frame (Lil Blunt in the cart) IS the cover. No card, no black: the
		# frame stays on screen while Episode 2 loads, builds and draws for the first time behind it, then dissolves
		# into the live runner. (Jev simulation 2026-10-03 ranked this above the black card: tools/ep2_sim.)
		add_child(_cover)
		_cover.modulate.a = 1.0
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
		_abort()
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
		if frame_ms > STALL_MS:
			saw_stall = true                  # the first draw's compile/upload hitch happened (hidden under the cover)
			calm_after_stall = 0
		elif saw_stall:
			calm_after_stall += 1
		# Done once the hitch is behind us (2 normal frames after it), or nothing stalled for a few frames.
		if (saw_stall and calm_after_stall >= 2) or (not saw_stall and _settle >= SETTLE_FRAMES + 3):
			break
	# 5. REVEAL
	_set_state(S.REVEALING)
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


func _abort() -> void:
	StateMachine.recover_from_transition()
	_card.visible = false
	_going = false
	_reset_warm()
	set_process(false)


func _finish(path: String) -> void:
	_card.visible = false
	_card.modulate.a = 1.0
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
