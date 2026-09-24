extends SceneTree
## Headless gate for the Protocol Portal downward ladders (build step 2).
## Run: godot --headless --script res://tests/portal_ladder_test.gd
##
## For each stage scene: load + instantiate, add to the tree, let TWO process
## frames run (the ladder's _ready is deferred-filled and its floor snap is
## call_deferred, so one frame is not enough), then assert the portal contract.
##
## Scripts are preloaded BY PATH, never via class_name globals — a brand-new
## class_name is not in Godot's global class cache until the editor re-imports,
## so a headless gate would fail on a perfectly valid script (same reasoning as
## src/level/ladder.gd's note).

const PORTAL_SCRIPT: GDScript = preload("res://src/protocol_portals/PortalLadder.gd")

const STAGES := [
	{"path": "res://src/level/level_01_smoke_realm.tscn", "protocol": "smoke", "stage_id": 1},
	{"path": "res://src/level/level_02_crystal_caverns.tscn", "protocol": "diamonds", "stage_id": 2},
	{"path": "res://src/level/level_03_gold_rush.tscn", "protocol": "gold", "stage_id": 3},
]

var _failures: int = 0

func _initialize() -> void:
	_run()

func _run() -> void:
	for stage in STAGES:
		await _check_stage(stage)
	if _failures == 0:
		print("PORTAL LADDERS: ALL PASS")
	else:
		print("PORTAL LADDERS: FAILURES %d" % _failures)
	quit(0 if _failures == 0 else 1)

func _check_stage(stage: Dictionary) -> void:
	var path: String = String(stage["path"])
	var tag: String = path.get_file()

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_report(false, "%s: scene failed to load" % tag)
		return

	var level: Node = packed.instantiate()
	if level == null:
		_report(false, "%s: scene failed to instantiate" % tag)
		return
	root.add_child(level)
	await process_frame
	await process_frame

	var portals: Array = get_nodes_in_group("protocol_portal")
	_report(portals.size() == 1, "%s: exactly one node in group 'protocol_portal' (found %d)" % [tag, portals.size()])
	if portals.size() != 1:
		_teardown(level)
		return

	var portal = portals[0]
	_report(portal.get_script() == PORTAL_SCRIPT, "%s: portal runs PortalLadder.gd" % tag)
	_report(String(portal.get("protocol")) == String(stage["protocol"]),
		"%s: protocol == '%s' (got '%s')" % [tag, String(stage["protocol"]), String(portal.get("protocol"))])
	_report(int(portal.get("stage_id")) == int(stage["stage_id"]),
		"%s: stage_id == %d (got %d)" % [tag, int(stage["stage_id"]), int(portal.get("stage_id"))])

	var boss: Node = level.get_node_or_null("BossTrigger")
	var boss_shape: Node2D = null
	if boss != null:
		boss_shape = boss.get_node_or_null("CollisionShape2D") as Node2D
	if boss_shape == null:
		_report(false, "%s: BossTrigger/CollisionShape2D not found" % tag)
	else:
		var portal_x: float = (portal as Node2D).global_position.x
		var boss_x: float = boss_shape.global_position.x
		_report(portal_x < boss_x, "%s: portal x %.1f < boss trigger x %.1f" % [tag, portal_x, boss_x])

	_report(not _has_static_body(portal), "%s: portal has no StaticBody2D descendant" % tag)

	var zone: Node = portal.get_node_or_null("EnterZone")
	_report(zone is Area2D, "%s: portal has an Area2D named EnterZone" % tag)

	_teardown(level)

func _teardown(level: Node) -> void:
	root.remove_child(level)
	level.free()

func _has_static_body(node: Node) -> bool:
	if node is StaticBody2D:
		return true
	for child in node.get_children():
		if _has_static_body(child):
			return true
	return false

func _report(ok: bool, label: String) -> void:
	if ok:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)
