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
	print("EP2_ACCESS_CODE: %s" % ("ALL PASS" if _fail == 0 else "FAIL (%d)" % _fail))
	get_tree().quit(0 if _fail == 0 else 1)
