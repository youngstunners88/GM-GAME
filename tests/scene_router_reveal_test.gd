extends Node
## SceneRouter.revealed + the Blaze-only wipe length.
##
## Two additions to the router, both scoped so nothing else moves:
##   * `revealed` fires when the wipe-in / fade-in that follows a load_scene() has
##     FINISHED (right away for INSTANT / SLIDE, which have no cover). Blaze Rush's armed
##     start waits for it so the cube never runs under a half-covered screen. A load that a
##     NEWER load_scene() superseded stays quiet. `is_revealed()` mirrors it.
##   * `load_scene(path, transition, wipe_seconds)`: a third argument, default -1 = the
##     global 0.45 s. Only blaze_portal.gd and blaze_rush.gd pass
##     SceneRouter.blaze_wipe_seconds() (0.30 s) next to blaze_transition_for_level().
##     Nothing else may shorten a wipe: the boss-3 / Episode 2 hand-offs, vault doors and
##     victory screen keep 0.45 s.
## `_play_in_transition` is NOT awaited by its callers, so `_abort_load` still starts the
## reveal and THEN calls StateMachine.recover_from_transition (pinned below).
##
## The test detaches itself from `current_scene` so the router's scene swap does not free
## the test. Run: godot --headless res://tests/scene_router_reveal_test.tscn
## Verdict: SCENE_ROUTER_REVEAL: ALL PASS | N FAILURE(S)

const TARGET := "res://tests/router_reveal_target.tscn"

var _fail: int = 0
var _checks: int = 0
var _t0: int = 0
var _loaded_ms: int = -1
var _revealed_ms: Array[int] = []

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _ready() -> void:
	await get_tree().process_frame
	print("SCENE ROUTER REVEAL:")
	SceneRouter.load_finished.connect(_on_loaded)
	SceneRouter.revealed.connect(_on_revealed)
	get_tree().current_scene = null
	_test_static_contract()
	await _load_and_measure("default SMOKE wipe", SceneRouter.Transition.SMOKE, -1.0, 0.38, 0.62, 0.40, 0.70)
	await _load_and_measure("Blaze wipe (0.30 s)", SceneRouter.Transition.SMOKE, SceneRouter.blaze_wipe_seconds(), 0.22, 0.38, 0.27, 0.60)
	await _load_and_measure("default GOLD wipe", SceneRouter.Transition.GOLD, -1.0, 0.38, 0.62, 0.40, 0.70)
	await _load_and_measure("FADE (0.3 s, the global default transition)", SceneRouter.Transition.FADE, -1.0, 0.22, 0.38, 0.27, 0.60)
	await _instant_reveals_at_once()
	await _superseded_reveal_stays_quiet()
	await _failed_load_still_reveals()
	_free_loaded()
	get_tree().current_scene = self
	if _checks < 25:
		_fail += 1
		print("  [FAIL] only %d checks ran - a false green" % _checks)
	print("SCENE_ROUTER_REVEAL: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _on_loaded(_p: String) -> void:
	_loaded_ms = Time.get_ticks_msec() - _t0

func _on_revealed() -> void:
	_revealed_ms.append(Time.get_ticks_msec() - _t0)

func _free_loaded() -> void:
	var cur: Node = get_tree().current_scene
	if cur != null and cur != self:
		cur.queue_free()
		get_tree().current_scene = null

func _wait_for(cond: Callable, max_frames: int = 600) -> bool:
	for i in range(max_frames):
		if cond.call():
			return true
		await get_tree().process_frame
	return false

# ---- source contract --------------------------------------------------------------------

func _test_static_contract() -> void:
	_check("the global wipe default is 0.45 s", is_equal_approx(SceneRouter.DEFAULT_WIPE_SECONDS, 0.45))
	_check("Blaze's wipe is 0.30 s", is_equal_approx(SceneRouter.blaze_wipe_seconds(), 0.30))
	var src: String = FileAccess.get_file_as_string("res://src/autoload/scene_router.gd")
	var abort_at: int = src.find("func _abort_load()")
	var abort_body: String = src.substr(abort_at, 300)
	_check("_abort_load still starts the reveal BEFORE recover_from_transition (order untouched)",
		abort_body.find("_play_in_transition()") != -1 and abort_body.find("_play_in_transition()") < abort_body.find("recover_from_transition()"),
		abort_body)
	_check("_abort_load does not await the reveal (callers never await _play_in_transition)",
		abort_body.find("await") == -1)
	# Only the two Blaze files may pass the short wipe.
	var users: Array[String] = []
	for path in ["res://src/dashmode/blaze_portal.gd", "res://src/dashmode/blaze_rush.gd"]:
		if FileAccess.get_file_as_string(path).contains("SceneRouter.blaze_wipe_seconds()"):
			users.append(path.get_file())
	_check("blaze_portal.gd and blaze_rush.gd both pass blaze_wipe_seconds()", users.size() == 2, str(users))
	var strays: Array[String] = []
	_scan_for_wipe_users("res://src", strays)
	_check("no other script passes a wipe length to the router", strays.is_empty(), ", ".join(strays))

func _scan_for_wipe_users(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_for_wipe_users(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var full: String = dir_path.path_join(f)
		if full.ends_with("scene_router.gd") or full.ends_with("blaze_portal.gd") or full.ends_with("blaze_rush.gd"):
			continue
		var text: String = FileAccess.get_file_as_string(full)
		if text.contains("blaze_wipe_seconds") or text.contains("BLAZE_WIPE_SECONDS"):
			out.append(full)

# ---- timing -------------------------------------------------------------------------------------

## One real load. `loaded_lo/hi` bound load_finished (the wipe-OUT wait + the load);
## `rev_gap_lo/hi` bound revealed - load_finished (the wipe-IN, less the node-count work the
## router does between starting the reveal and emitting load_finished).
func _load_and_measure(label: String, kind: SceneRouter.Transition, secs: float,
		rev_gap_lo: float, rev_gap_hi: float, loaded_lo: float, loaded_hi: float) -> void:
	_free_loaded()
	await get_tree().process_frame
	_loaded_ms = -1
	_revealed_ms.clear()
	_t0 = Time.get_ticks_msec()
	SceneRouter.load_scene(TARGET, kind, secs)
	_check("%s: is_revealed() is false while the load is in flight" % label, not SceneRouter.is_revealed())
	await _wait_for(func() -> bool: return not _revealed_ms.is_empty())
	_check("%s: revealed fired exactly once" % label, _revealed_ms.size() == 1, str(_revealed_ms))
	_check("%s: is_revealed() is true afterwards" % label, SceneRouter.is_revealed())
	if _loaded_ms < 0 or _revealed_ms.is_empty():
		return
	var out_s: float = float(_loaded_ms) / 1000.0
	var in_s: float = float(_revealed_ms[0] - _loaded_ms) / 1000.0
	print("     (info) %s: load_finished at %.0f ms, revealed %.0f ms later" % [label, out_s * 1000.0, in_s * 1000.0])
	_check("%s: loaded after %.2f s (window %.2f-%.2f)" % [label, out_s, loaded_lo, loaded_hi], out_s >= loaded_lo and out_s <= loaded_hi)
	_check("%s: revealed %.2f s after the load (window %.2f-%.2f)" % [label, in_s, rev_gap_lo, rev_gap_hi], in_s >= rev_gap_lo and in_s <= rev_gap_hi)

func _instant_reveals_at_once() -> void:
	_free_loaded()
	await get_tree().process_frame
	_loaded_ms = -1
	_revealed_ms.clear()
	_t0 = Time.get_ticks_msec()
	SceneRouter.load_scene(TARGET, SceneRouter.Transition.INSTANT)
	await _wait_for(func() -> bool: return not _revealed_ms.is_empty())
	_check("INSTANT: revealed fires with the load (no cover to wait for)",
		_revealed_ms.size() == 1 and _loaded_ms >= 0 and absi(_revealed_ms[0] - _loaded_ms) < 120,
		"loaded %d revealed %s" % [_loaded_ms, str(_revealed_ms)])

## A reveal that a newer load superseded must NOT announce a scene that is about to be replaced.
func _superseded_reveal_stays_quiet() -> void:
	_free_loaded()
	await get_tree().process_frame
	_loaded_ms = -1
	_revealed_ms.clear()
	_t0 = Time.get_ticks_msec()
	SceneRouter.load_scene(TARGET, SceneRouter.Transition.SMOKE, SceneRouter.blaze_wipe_seconds())
	await _wait_for(func() -> bool: return _loaded_ms >= 0)
	# A is loaded and its reveal is running. Start B right now.
	_free_loaded()
	SceneRouter.load_scene(TARGET, SceneRouter.Transition.SMOKE, SceneRouter.blaze_wipe_seconds())
	_check("a newer load flips is_revealed() back to false", not SceneRouter.is_revealed())
	await _wait_for(func() -> bool: return not _revealed_ms.is_empty())
	await get_tree().create_timer(0.8).timeout
	_check("the superseded load's reveal stayed quiet: ONE revealed for two loads", _revealed_ms.size() == 1, str(_revealed_ms))

## A load that fails (_abort_load) still lifts the cover and announces the reveal.
func _failed_load_still_reveals() -> void:
	_free_loaded()
	await get_tree().process_frame
	_revealed_ms.clear()
	_t0 = Time.get_ticks_msec()
	SceneRouter.load_scene("res://tests/this_scene_does_not_exist.tscn", SceneRouter.Transition.FADE)
	await _wait_for(func() -> bool: return not _revealed_ms.is_empty())
	_check("a failed load is aborted and STILL reveals (the cover lifts, the router is free again)",
		_revealed_ms.size() == 1 and SceneRouter.is_revealed() and SceneRouter._loading_path == "", str(_revealed_ms))
