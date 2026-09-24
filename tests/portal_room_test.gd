extends SceneTree
## Headless test for the Protocol Portals study rooms (step 3).
##
## Run with:
##   godot --headless --script res://tests/portal_room_test.gd
##
## Everything is preloaded by path: class_name globals are not guaranteed to be
## registered when a script is run with --script.

const Travel := preload("res://src/protocol_portals/PortalTravel.gd")
const Grant := preload("res://src/protocol_portals/ScorecardGrant.gd")
const QuizBankScript := preload("res://src/protocol_portals/QuizBank.gd")
const SignalsScript := preload("res://src/protocol_portals/PortalSignals.gd")

const PORTAL_DIR: String = "res://src/protocol_portals"
const SAVE_PATH: String = "user://portal_scorecards.json"

const REQUIRED_NODES: Array[String] = [
	"WhitepaperPlate",
	"VideoShrine",
	"Examiner",
	"AscentShaft",
	"Divider",
]

const SKINS: Array = [
	{
		"stage": 1,
		"protocol": "smoke",
		"token": "portal_smoke",
		"path": "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn",
	},
	{
		"stage": 2,
		"protocol": "diamonds",
		"token": "portal_diamonds",
		"path": "res://src/protocol_portals/rooms/diamonds/PressureStudy.tscn",
	},
	{
		"stage": 3,
		"protocol": "gold",
		"token": "portal_gold",
		"path": "res://src/protocol_portals/rooms/gold/ClaimOffice.tscn",
	},
]

var _failures: int = 0


func _initialize() -> void:
	print("PORTAL ROOMS: starting")
	paused = false
	_clean_save()

	_test_room_scene_map()
	_test_consume_return()
	_test_forbidden_tokens()

	for skin in SKINS:
		await _test_skin(skin)

	paused = false
	if _failures == 0:
		print("PORTAL ROOMS: ALL PASS")
		quit(0)
	else:
		print("PORTAL ROOMS: FAILURES %d" % _failures)
		quit(1)


# ---- Pure / static checks ---------------------------------------------------

func _test_room_scene_map() -> void:
	_check(Travel.room_scene_for("smoke") == "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn",
		"room_scene_for(smoke)")
	_check(Travel.room_scene_for("diamonds") == "res://src/protocol_portals/rooms/diamonds/PressureStudy.tscn",
		"room_scene_for(diamonds)")
	_check(Travel.room_scene_for("gold") == "res://src/protocol_portals/rooms/gold/ClaimOffice.tscn",
		"room_scene_for(gold)")


func _test_consume_return() -> void:
	Travel.return_scene = "res://src/protocol_portals/rooms/smoke/ReadingRing.tscn"
	Travel.protocol = "smoke"
	Travel.pending_return = true
	_check(not Travel.consume_return(Travel.return_scene, "diamonds"),
		"consume_return refuses a mismatched protocol")
	_check(Travel.consume_return(Travel.return_scene, "smoke"),
		"consume_return accepts the matching return once")
	_check(not Travel.consume_return(Travel.return_scene, "smoke"),
		"consume_return is one-shot")
	Travel.pending_return = false
	Travel.protocol = ""
	Travel.return_scene = ""


func _test_forbidden_tokens() -> void:
	var files: Array[String] = []
	_collect_files(PORTAL_DIR, files)
	_check(files.size() > 0, "portal scripts found to scan (%d)" % files.size())
	var forbidden: Array[String] = ["OS.execute", "JavaScriptBridge", "HTTPRequest"]
	var hits: int = 0
	for i in range(files.size()):
		var source: String = _read_text(files[i])
		if source.is_empty():
			continue
		for j in range(forbidden.size()):
			if source.contains(forbidden[j]):
				hits += 1
				_fail("%s contains forbidden token '%s'" % [files[i], forbidden[j]])
	_check(hits == 0, "no forbidden tokens in %d portal files" % files.size())


# ---- Per-skin checks --------------------------------------------------------

func _test_skin(skin: Dictionary) -> void:
	var path: String = String(skin["path"])
	var protocol: String = String(skin["protocol"])
	var token: String = String(skin["token"])

	_check(ResourceLoader.exists(path), "skin scene exists: %s" % path)
	if not ResourceLoader.exists(path):
		return

	var bank: RefCounted = QuizBankScript.load_bank(protocol)
	if bank == null:
		_fail("%s: quiz bank did not load" % protocol)
		return
	var key: Array[int] = bank.call("answer_key")

	# --- run 1: every answer correct ---------------------------------------
	Travel.session = null
	Travel.pending_return = false
	var room: Node = await _open_room(path)
	if room == null:
		return
	for i in range(REQUIRED_NODES.size()):
		var node_name: String = REQUIRED_NODES[i]
		_check(room.has_node(node_name), "%s: has node %s" % [protocol, node_name])
	_check(_room_has_player(room), "%s: player is in the group and in the room" % protocol)
	_check(room.has_method("test_run"), "%s: room exposes test_run()" % protocol)

	var passed_result: Dictionary = room.call("test_run", key)
	_check(bool(passed_result.get("passed", false)), "%s: perfect run passes" % protocol)
	_check(int(passed_result.get("score_correct", -1)) == 11, "%s: perfect run scores 11" % protocol)
	_check(bool(passed_result.get("completed", false)), "%s: perfect run completes" % protocol)
	_check(String(passed_result.get("nft_token_id", "")) == token,
		"%s: completion pins token id %s" % [protocol, token])
	_close_room(room)

	# --- run 2: every answer wrong, on a fresh room -------------------------
	Travel.session = null
	Travel.pending_return = false
	var room2: Node = await _open_room(path)
	if room2 == null:
		return
	var wrong: Array[int] = []
	for i in range(key.size()):
		wrong.append((int(key[i]) + 1) % 3)
	var failed_result: Dictionary = room2.call("test_run", wrong)
	_check(not bool(failed_result.get("passed", true)), "%s: all-wrong run fails" % protocol)
	_check(int(failed_result.get("score_correct", -1)) == 0, "%s: all-wrong run scores 0" % protocol)
	_check(not bool(failed_result.get("completed", true)),
		"%s: a failed run is not complete until the player proceeds" % protocol)

	var session: RefCounted = room2.get("session")
	if session == null:
		_fail("%s: room has no session" % protocol)
		_close_room(room2)
		return

	session.call("proceed_without_pass")
	_check(bool(session.call("eligible_for_scorecard")),
		"%s: proceed_without_pass makes the run scorecard-eligible" % protocol)

	var record: Dictionary = Grant.mark_eligible(session)
	_check(not record.is_empty(), "%s: mark_eligible writes a record" % protocol)
	_check(String(record.get("nft_token_id", "")) == token,
		"%s: record carries token id %s" % [protocol, token])
	_check(bool(record.get("eligible", false)), "%s: record is marked eligible" % protocol)
	_check(not bool(record.get("minted", true)), "%s: record is marked not minted" % protocol)
	_check(String(record.get("minted_at", "x")).is_empty(),
		"%s: record has an empty minted_at" % protocol)

	var all: Dictionary = Grant.load_all()
	_check(all.has(token), "%s: scorecard table contains %s" % [protocol, token])
	if all.has(token):
		var stored: Dictionary = all[token]
		_check(String(stored.get("nft_token_id", "")) == token,
			"%s: stored record keeps the token id" % protocol)
		_check(not bool(stored.get("minted", true)), "%s: stored record is not minted" % protocol)

	_close_room(room2)


# ---- Helpers ----------------------------------------------------------------

func _open_room(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		_fail("could not load %s" % path)
		return null
	var room: Node = packed.instantiate()
	root.add_child(room)
	# Two frames: one for _ready + the first physics tick, one for anything the
	# room defers.
	await process_frame
	await process_frame
	return room


func _close_room(room: Node) -> void:
	if room != null and is_instance_valid(room):
		root.remove_child(room)
		room.queue_free()


func _room_has_player(room: Node) -> bool:
	for node in get_nodes_in_group("player"):
		if room.is_ancestor_of(node):
			return true
	return false


func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_files(full, out)
		else:
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _clean_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures += 1
	print("[FAIL] %s" % label)
