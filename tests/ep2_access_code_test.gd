extends Node
## Founder 2026-09-30: Episode 2 asks for an access code before anything runs. The plaintext code is not in
## the repo; the positive check runs only when EP2_CODE is set in the environment.

const ENTRY := preload("res://src/episode2/ep2_entry.gd")
var _fail: int = 0

func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_fail += 1

func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ENTRY.UNLOCK_FILE))
	for bad in ["", "letmein", "episode 2", "PASSWORD", "1234", "   "]:
		_check("rejects %s" % (bad if bad != "" else "<empty>"), not ENTRY.code_ok(bad))
	var code: String = OS.get_environment("EP2_CODE")
	if code != "":
		_check("accepts the founder's code (EP2_CODE)", ENTRY.code_ok(code))
	var e: Node = load("res://src/episode2/ep2_entry.tscn").instantiate()
	add_child(e)
	for _i in 30:
		await get_tree().process_frame
	_check("locked: the code screen is up", e._gate != null and e._gate_input != null)
	_check("locked: no Episode 2 session is running behind it", e._root == null)
	e._try_code("wrong")
	_check("wrong code keeps it locked", e._gate != null and e._root == null)
	if code != "":
		e._try_code(code)
		await get_tree().process_frame
		_check("the right code opens Episode 2 (session running, code screen gone)", e._gate == null and e._root != null)
	e.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ENTRY.UNLOCK_FILE))
	# Earned by beating boss 3 (founder 2026-10-03): the seamless hand-off skips the code screen, in memory only.
	GameManager.ep2_story_unlocked = true
	var e2: Node = load("res://src/episode2/ep2_entry.tscn").instantiate()
	add_child(e2)
	for _i in 30:
		await get_tree().process_frame
	_check("story hand-off: no code screen after beating boss 3", e2._gate == null and e2._root != null)
	_check("...and nothing was written to disk", not FileAccess.file_exists(ENTRY.UNLOCK_FILE))
	e2.queue_free()
	GameManager.ep2_story_unlocked = false
	await get_tree().process_frame
	await _check_mobile_gate(code)
	print("EP2_ACCESS_CODE: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)

func _check_mobile_gate(code: String) -> void:
	var original_size: Vector2i = get_window().size
	var was_touch: bool = MobileLayoutManager.is_touch_device
	MobileLayoutManager.is_touch_device = true
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	var entry: Node = load("res://src/episode2/ep2_entry.tscn").instantiate()
	add_child(entry)
	await get_tree().process_frame
	_check("portrait phone shows the keypad and zoom control", entry._kp_rows != null and entry._gate_zoom != null)
	entry._gate_input.text = "test"
	var regular_size: int = entry._gate_input.get_theme_font_size("font_size")
	entry._gate_zoom.pressed.emit()
	_check("zoom enlarges the field and preserves the entered code",
		entry._gate_input.get_theme_font_size("font_size") > regular_size and entry._gate_input.text == "test")
	entry._gate_zoom.pressed.emit()
	_check("zoom out restores the original text size", entry._gate_input.get_theme_font_size("font_size") == regular_size)
	if code.is_empty():
		# Exercise re-entry from the same saved record without needing the production code.
		entry._write_unlock()
		entry.queue_free()
		await get_tree().process_frame
		entry = load("res://src/episode2/ep2_entry.tscn").instantiate()
		add_child(entry)
	else:
		entry._gate_input.text = code
		entry._gate_submit.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("unlocked portrait shows a rotation instruction before booting the runner",
		entry._gate != null and entry._root == null and "sideways" in entry._gate_msg.text)
	if not StateMachine.is_playing():
		StateMachine.change_state(StateMachine.State.TRANSITIONING)
	get_window().size = Vector2i(844, 390)
	for _i in 6:
		await get_tree().process_frame
	_check("rotation starts the runner from the unlocked screen",
		entry._gate == null and entry._root != null and entry._root.get_mode() == Ep2SessionRoot.Mode.RUNNER)
	entry.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ENTRY.UNLOCK_FILE))
	get_window().size = original_size
	MobileLayoutManager.is_touch_device = was_touch
