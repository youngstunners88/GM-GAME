extends Node
## Validates the Blaze Rush course data and the finish -> return-to-game flow.
##
## WHY THIS EXISTS: the layouts in blaze_rush_layouts.gd are hand-authored
## pixel coordinates with a speed ramp layered on top in blaze_rush.gd — a
## typo here doesn't fail to compile, it silently produces an unfair gap (one
## wider than the jump arc can clear at that point in the run) or a hazard
## sitting inside a pit with no floor under it. Nothing else in the gate
## battery would catch that. This also exercises the actual finish -> exit
## code path (GameManager.dash_return -> SceneRouter.load_scene) rather than
## trusting a code read that it works.
##
## Run: godot --headless res://tests/blaze_rush_layout_test.tscn

const GRAVITY: float = 2200.0
const JUMP_VELOCITY: float = -700.0
const AIR_TIME: float = 2.0 * 700.0 / GRAVITY  # ~0.636s, fixed regardless of run speed
const SAFETY_MARGIN: float = 0.8  # gap width must fit within 80% of max jump range

var _failures: Array[String] = []

func _ready() -> void:
	for level in [1, 2, 3]:
		_validate_layout_data(level)
	await _validate_finish_and_return_flow()
	_report_and_quit()

func test_blaze_rush_layouts_gaps_stay_within_local_jump_range(level: int, layout: Dictionary) -> void:
	var length: float = layout.get("length", 1.0)
	var speed_start: float = layout.get("speed_start", 320.0)
	var speed_end: float = layout.get("speed_end", speed_start)
	for ob in layout.get("obstacles", []):
		if ob.get("type", "") != "gap":
			continue
		var progress := clampf(ob.x / length, 0.0, 1.0)
		var local_speed: float = lerpf(speed_start, speed_end, progress)
		var max_range: float = local_speed * AIR_TIME * SAFETY_MARGIN
		var w: float = ob.get("w", 0.0)
		if w > max_range:
			_failures.append(
				"level %d gap at x=%.0f (w=%.0f) exceeds safe jump range %.1f at local speed %.1f"
				% [level, ob.x, w, max_range, local_speed]
			)

func test_blaze_rush_layouts_hazards_do_not_sit_inside_gaps(level: int, layout: Dictionary) -> void:
	var gaps: Array = []
	for ob in layout.get("obstacles", []):
		if ob.get("type", "") == "gap":
			gaps.append(Vector2(ob.x, ob.x + ob.get("w", 0.0)))
	for ob in layout.get("obstacles", []):
		var t: String = ob.get("type", "")
		if t != "candle" and t != "fud_wall":
			continue
		for gap in gaps:
			if ob.x > gap.x and ob.x < gap.y:
				_failures.append(
					"level %d %s at x=%.0f sits inside gap [%.0f, %.0f] with no floor under it"
					% [level, t, ob.x, gap.x, gap.y]
				)

func test_blaze_rush_layouts_last_hazard_leaves_a_clear_run_to_finish(level: int, layout: Dictionary) -> void:
	var length: float = layout.get("length", 0.0)
	var last_hazard_x := 0.0
	for ob in layout.get("obstacles", []):
		var t: String = ob.get("type", "")
		if t == "candle" or t == "fud_wall" or t == "gap":
			last_hazard_x = maxf(last_hazard_x, ob.x + ob.get("w", 0.0))
	if length - last_hazard_x < 150.0:
		_failures.append(
			"level %d last hazard ends at %.0f, only %.0f px before length %.0f (finish sits further out)"
			% [level, last_hazard_x, length - last_hazard_x, length]
		)

func _validate_layout_data(level: int) -> void:
	var layout := BlazeRushLayouts.get_layout(level)
	test_blaze_rush_layouts_gaps_stay_within_local_jump_range(level, layout)
	test_blaze_rush_layouts_hazards_do_not_sit_inside_gaps(level, layout)
	test_blaze_rush_layouts_last_hazard_leaves_a_clear_run_to_finish(level, layout)

func test_blaze_rush_finish_triggers_exit_to_return_scene() -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500.0, 400.0),
		"level_index": 1,
	}
	var packed: PackedScene = load("res://src/dashmode/blaze_rush.tscn")
	var run: Node2D = packed.instantiate()
	add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	# Teleport the player to the finish trigger's position and let one physics
	# step process the Area2D overlap — exercises the real _finish_run() ->
	# _exit_to_level() path instead of calling it directly.
	var player: CharacterBody2D = run.get("_player")
	if player == null:
		_failures.append("finish-flow: could not find _player on the Blaze Rush root")
		run.queue_free()
		return
	var course_length: float = run.get("_course_length")
	# Dead center of the finish Area2D built in _build_finish(): position
	# (course_length + 120, GROUND_Y - 60), a 20x300 box — well inside it.
	player.global_position = Vector2(course_length + 120.0, BlazeRushLayouts.GROUND_Y - 60.0)

	var cleared := false
	for i in range(30):
		await get_tree().physics_frame
		if bool(run.get("_finished")):
			cleared = true
			break

	if not cleared:
		_failures.append("finish-flow: crossing the finish area did not set _finished true within 30 physics frames")
		run.queue_free()
		return

	# _finish_run() awaits a 1.8s toast timer before calling _exit_to_level(),
	# which is the piece that actually reads GameManager.dash_return and calls
	# SceneRouter.load_scene — wait past it so that real code path runs.
	#
	# POLL, DO NOT SLEEP THROUGH IT. `_exit_to_level` ends in a real
	# SceneRouter.load_scene(), and this test node IS the current scene — so
	# the very success it is checking for also FREES it. A fixed
	# `await create_timer(2.2)` therefore resumed inside a freed node and the
	# suite died silently: no verdict line, no exit code, just a hang until the
	# CI timeout killed it. It behaved identically whether the code under test
	# passed or failed, which makes it worse than having no gate at all.
	#
	# So: sample every frame, and report the instant the observable effect
	# lands, before the scene swap can take us with it.
	var exited := false
	for i in range(200):
		if GameManager.dash_return.is_empty():
			exited = true
			break
		await get_tree().process_frame
	if not exited:
		_failures.append("finish-flow: _exit_to_level did not run — GameManager.dash_return was never cleared")
	_report_and_quit()

	if is_instance_valid(run):
		run.queue_free()

## Print the verdict and exit. Called from the finish-flow check the moment its
## result is known (see above) and again from _ready() as a backstop for runs
## that never reach the scene swap.
var _reported := false
func _report_and_quit() -> void:
	if _reported:
		return
	_reported = true
	if _failures.is_empty():
		print("BLAZE_RUSH_LAYOUT: ALL PASS")
		get_tree().quit(0)
	else:
		print("BLAZE_RUSH_LAYOUT: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  [FAIL] %s" % f)
		get_tree().quit(1)

func _validate_finish_and_return_flow() -> void:
	await test_blaze_rush_finish_triggers_exit_to_return_scene()
