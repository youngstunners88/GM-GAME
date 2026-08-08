extends Node2D
## LIVE-BUILD PROOF for Blaze Rush finish + ESC, all three levels.
##
## The founder has now reported "finish doesn't return me" and "Esc doesn't
## work" FIVE times, across builds that each shipped with a probe claiming the
## opposite. Those probes only ever read `_return_path` out of the node — a
## DATA check. A data check cannot fail the way the founder's session fails,
## because the bug is not "the string is wrong", it is "the scene never
## actually changes".
##
## This probe drives the real code path and asserts on
## `get_tree().current_scene.scene_file_path` — the only thing that
## corresponds to what the founder sees on screen.

const BLAZE := preload("res://src/dashmode/blaze_rush.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("BLAZE LIFECYCLE E2E:")
	for lvl in [1, 2, 3]:
		await _prove(lvl, "finish")
		await _prove(lvl, "esc")
	await _prove_real_triggers()
	print("BLAZE_LIFECYCLE_E2E: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

## THE PART THAT HAS NEVER BEEN PROVEN.
##
## Calling _finish_run()/_exit_to_level() directly proves the exit LOGIC. It
## does NOT prove the player can ever reach those functions in play, and that
## distinction is exactly where five "fixed" claims died: the founder does not
## call a method, he skates into a finish line and presses a key.
##
## So: drop the real auto-running player just short of the real finish Area2D
## and let real physics carry him in, and feed a real InputEventKey through
## Input.parse_input_event() rather than hand-calling _input().
func _prove_real_triggers() -> void:
	Engine.time_scale = 1.0
	var want := GameManager.level_scene(3)

	# --- real finish-line contact -----------------------------------------
	GameManager.dash_return = {
		"scene_path": want, "position": Vector2(1234.0, 500.0), "level_index": 3}
	var run := BLAZE.instantiate()
	get_tree().root.add_child(run)
	get_tree().current_scene = run
	for i in 5:
		await get_tree().process_frame

	var course: float = float(run.get("_course_length"))
	var plr: CharacterBody2D = run.get("_player")
	_check("finish: the auto-runner exists to be carried into the line", plr != null)
	if plr:
		# 90px short of the finish (which sits at course + 120): close enough
		# that the run's own forward motion carries him across it.
		plr.global_position = Vector2(course + 30.0, plr.global_position.y)
		var crossed := false
		for i in range(420):
			await get_tree().physics_frame
			var cur := get_tree().current_scene
			if is_instance_valid(cur) and cur != run and cur.scene_file_path == want:
				crossed = true
				break
		_check("finish: SKATING INTO the finish line returns to the origin stage",
			crossed,
			"ended at '%s' — the finish Area2D never fired in real physics"
				% (get_tree().current_scene.scene_file_path
					if is_instance_valid(get_tree().current_scene) else "<freed>"))
	if is_instance_valid(run):
		run.queue_free()
	await get_tree().process_frame

	# --- real ESC keypress -------------------------------------------------
	GameManager.dash_return = {
		"scene_path": want, "position": Vector2(1234.0, 500.0), "level_index": 3}
	var run2 := BLAZE.instantiate()
	get_tree().root.add_child(run2)
	get_tree().current_scene = run2
	for i in 5:
		await get_tree().process_frame

	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)

	var esc_worked := false
	for i in range(420):
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if is_instance_valid(cur) and cur != run2 and cur.scene_file_path == want:
			esc_worked = true
			break
	_check("esc: a REAL Escape keypress exits to the origin stage",
		esc_worked,
		"ended at '%s' — the key never reached _input()"
			% (get_tree().current_scene.scene_file_path
				if is_instance_valid(get_tree().current_scene) else "<freed>"))
	if is_instance_valid(run2):
		run2.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Drive one (level, exit-route) pair from a clean state and assert the tree
## really landed on that level's scene.
func _prove(level_index: int, route: String) -> void:
	Engine.time_scale = 1.0
	var want := GameManager.level_scene(level_index)
	var portal := Vector2(1234.0, 500.0)

	# Exactly what BlazePortal writes when the player enters.
	GameManager.dash_return = {
		"scene_path": want,
		"position": portal,
		"level_index": level_index,
	}
	GameManager.level_checkpoints.clear()

	var run := BLAZE.instantiate()
	get_tree().root.add_child(run)
	get_tree().current_scene = run
	# Let _ready() build the course and snapshot the return target.
	for i in 5:
		await get_tree().process_frame

	if route == "finish":
		run.call("_finish_run")
	else:
		run.call("_exit_to_level")

	# _finish_run holds a 1.8s toast before exiting; SceneRouter's SMOKE wipe
	# adds ~0.45s. Budget well past both.
	var landed := false
	for i in range(600):
		await get_tree().process_frame
		var cur := get_tree().current_scene
		if is_instance_valid(cur) and cur != run and cur.scene_file_path == want:
			landed = true
			break

	_check("L%d %s -> returns to %s" % [level_index, route, want.get_file()],
		landed,
		"ended at '%s'" % (get_tree().current_scene.scene_file_path
			if is_instance_valid(get_tree().current_scene) else "<freed>"))

	# The drop-point must be filed under THIS level, or the level spawns the
	# player at its start instead of at the portal they left from.
	_check("L%d %s -> checkpoint filed under level %d" % [level_index, route, level_index],
		level_index in GameManager.level_checkpoints,
		"keys present: %s" % str(GameManager.level_checkpoints.keys()))

	if is_instance_valid(run):
		run.queue_free()
	var scene := get_tree().current_scene
	if is_instance_valid(scene) and scene != run:
		scene.queue_free()
	await get_tree().process_frame
