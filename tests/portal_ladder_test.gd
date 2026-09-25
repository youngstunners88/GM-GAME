extends SceneTree
## Headless test for the Protocol Portal ladders placed in the three stages.
##
## Run with:
##   godot --headless --script res://tests/portal_ladder_test.gd
##
## Everything is preloaded / loaded by path: class_name globals are not
## guaranteed to be registered when a script is run with --script.

const LadderScript := preload("res://src/protocol_portals/PortalLadder.gd")

const LADDER_PATH: String = "res://src/protocol_portals/PortalLadder.gd"
const MIN_SHAFT_DEPTH: float = 320.0

const STAGES: Array = [
	{
		"stage": 1,
		"protocol": "smoke",
		"path": "res://src/level/level_01_smoke_realm.tscn",
	},
	{
		"stage": 2,
		"protocol": "diamonds",
		"path": "res://src/level/level_02_crystal_caverns.tscn",
	},
	{
		"stage": 3,
		"protocol": "gold",
		"path": "res://src/level/level_03_gold_rush.tscn",
	},
]

var _failures: int = 0


func _initialize() -> void:
	print("PORTAL LADDERS: starting")
	paused = false

	_test_ladder_source()

	for entry in STAGES:
		await _test_stage(entry)

	paused = false
	if _failures == 0:
		print("PORTAL LADDERS: ALL PASS")
		quit(0)
	else:
		print("PORTAL LADDERS: FAILURES %d" % _failures)
		quit(1)


# ---- Source checks ----------------------------------------------------------

func _test_ladder_source() -> void:
	var source: String = _read_text(LADDER_PATH)
	_check(not source.is_empty(), "PortalLadder.gd source readable")
	if source.is_empty():
		return
	_check(not source.contains("interact"), "PortalLadder.gd does not mention 'interact'")
	_check(not source.contains("STUDY [E]"), "PortalLadder.gd has no 'STUDY [E]' prompt")
	_check(not source.contains("STUDY  [E]"), "PortalLadder.gd has no 'STUDY  [E]' prompt")
	_check(source.contains("enter_ladder_zone"), "PortalLadder.gd calls enter_ladder_zone")
	_check(source.contains("exit_ladder_zone"), "PortalLadder.gd calls exit_ladder_zone")


# ---- Per-stage checks -------------------------------------------------------

func _test_stage(entry: Dictionary) -> void:
	var path: String = String(entry["path"])
	var protocol: String = String(entry["protocol"])
	var stage: int = int(entry["stage"])
	var tag: String = "stage %d (%s)" % [stage, protocol]

	_check(ResourceLoader.exists(path), "%s: scene exists %s" % [tag, path])
	if not ResourceLoader.exists(path):
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("%s: could not load %s" % [tag, path])
		return
	var level: Node = packed.instantiate()
	if level == null:
		_fail("%s: could not instantiate %s" % [tag, path])
		return
	root.add_child(level)
	# Two frames: _ready + the deferred floor snap.
	await process_frame
	await process_frame

	var portals: Array[Node] = []
	for node in get_nodes_in_group("protocol_portal"):
		if level.is_ancestor_of(node):
			portals.append(node)
	_check(portals.size() == 1, "%s: exactly one protocol_portal (found %d)" % [tag, portals.size()])
	if portals.is_empty():
		await _close_level(level)
		return

	var portal: Node2D = portals[0] as Node2D
	if portal == null:
		_fail("%s: protocol_portal is not a Node2D" % tag)
		await _close_level(level)
		return

	_check(portal.get_script() == LadderScript, "%s: portal uses PortalLadder.gd" % tag)
	var got_protocol: String = String(portal.get("protocol"))
	var got_stage: int = int(portal.get("stage_id"))
	_check(got_protocol == protocol, "%s: portal protocol is %s (got %s)" % [tag, protocol, got_protocol])
	_check(got_stage == stage, "%s: portal stage_id is %d (got %d)" % [tag, stage, got_stage])

	# Boss trigger lies to the right of the portal.
	var boss: Node = level.find_child("BossTrigger", true, false)
	_check(boss != null, "%s: BossTrigger found" % tag)
	if boss != null:
		var shape: CollisionShape2D = _find_shape(boss)
		_check(shape != null, "%s: BossTrigger has a CollisionShape2D" % tag)
		if shape != null:
			var px: float = portal.global_position.x
			var bx: float = shape.global_position.x
			_check(px < bx, "%s: portal x %.1f < boss trigger x %.1f" % [tag, px, bx])

	# Never solid.
	var statics: int = _count_static_bodies(portal)
	_check(statics == 0, "%s: portal has no StaticBody2D descendants (found %d)" % [tag, statics])

	# Shaft depth.
	if portal.has_method("top_y") and portal.has_method("bottom_y"):
		var top: float = float(portal.call("top_y"))
		var bottom: float = float(portal.call("bottom_y"))
		var depth: float = bottom - top
		_check(depth >= MIN_SHAFT_DEPTH, "%s: shaft depth %.1f >= %.1f" % [tag, depth, MIN_SHAFT_DEPTH])
	else:
		_fail("%s: portal exposes top_y()/bottom_y()" % tag)

	_check(portal.has_method("top_exit_position"), "%s: portal exposes top_exit_position()" % tag)

	await _close_level(level)


# ---- Helpers ----------------------------------------------------------------

func _find_shape(node: Node) -> CollisionShape2D:
	if node is CollisionShape2D:
		return node as CollisionShape2D
	for child in node.get_children():
		var found: CollisionShape2D = _find_shape(child)
		if found != null:
			return found
	return null


func _count_static_bodies(node: Node) -> int:
	var total: int = 0
	for child in node.get_children():
		if child is StaticBody2D:
			total += 1
		total += _count_static_bodies(child)
	return total


func _close_level(level: Node) -> void:
	paused = false
	if level != null and is_instance_valid(level):
		root.remove_child(level)
		level.queue_free()
	await process_frame


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures += 1
	print("[FAIL] %s" % label)
