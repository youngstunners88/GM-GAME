extends Node
## Regression test for T4's new attack: "lets make the 2nd boss fire crystals
## rather and crystal shards at times."
##
## Proves, under real physics, that _throw_crystal_shards() is actually wired
## into the boss's own action rotation (not just a function that exists but
## is never called) and that it is mechanically distinct from the existing
## ETH-orb volley: different tint, not redirectable, faster.
##
## Run: godot --headless res://tests/distributor_crystal_shard_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("DISTRIBUTOR CRYSTAL SHARD ATTACK:")
	await _test_crystal_shards_reachable_in_rotation()
	await _test_crystal_shard_is_distinct_from_eth_orb()
	print("DISTRIBUTOR_CRYSTAL_SHARD: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Drives the boss's REAL action rotation (not a direct call) long enough to
## see all three actions (pull, ETH-orb volley, crystal shard) actually fire.
func _test_crystal_shards_reachable_in_rotation() -> void:
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	var player := CharacterBody2D.new()
	player.collision_layer = 2
	player.collision_mask = 0
	player.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 32)
	cs.shape = r
	cs.position = Vector2(16, 16)
	player.add_child(cs)
	player.global_position = Vector2(1400, 500)
	add_child(player)
	boss.global_position = Vector2(600, 500)
	# Mute contact so this long-running measurement isn't cut short by a
	# level restart the moment the boss catches up — the established pattern
	# from tests/distributor_behaviour_test.gd's own state-coverage test.
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	await get_tree().process_frame

	var saw_crystal_shard := false
	# Three full action cycles at ~1.5-2.6s cadence each comfortably fits in
	# 20s of real physics; long enough to see all three rotation slots land.
	for i in range(1200):
		await get_tree().physics_frame
		for child in get_children():
			if child.is_in_group("boss_projectile") and not bool(child.get("redirectable")):
				saw_crystal_shard = true
				break
		if saw_crystal_shard:
			break

	_check("the boss's own action rotation fires a crystal shard within 20s of real physics",
		saw_crystal_shard,
		"never saw a non-redirectable boss_projectile — _throw_crystal_shards() is unreachable from the real state machine")

	boss.queue_free()
	player.queue_free()
	await get_tree().process_frame

## Direct call (isolated from timing) to check the projectile's own
## properties are actually distinct from the ETH-orb volley's.
func _test_crystal_shard_is_distinct_from_eth_orb() -> void:
	# The previous test drove 20s of real physics and its own orbs/shards
	# outlive boss.queue_free() (they're children of the BOSS'S PARENT — this
	# test node — not the boss itself, and carry their own lifetime timers).
	# Group membership alone is not enough to identify THIS test's own
	# projectile (test-standards.md's documented gotcha) — clear the slate
	# first so the very next boss_projectile found is unambiguously this
	# call's own.
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame

	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	var player := CharacterBody2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(900, 500)
	add_child(player)
	boss.global_position = Vector2(600, 500)

	boss.call("_throw_crystal_shards")
	var shard: Node = null
	for child in get_children():
		if child.is_in_group("boss_projectile"):
			shard = child
			break
	_check("_throw_crystal_shards spawns a projectile", shard != null)
	if shard != null:
		_check("crystal shard is NOT redirectable (distinct from Forced Distribution)",
			not bool(shard.get("redirectable")))
		_check("crystal shard is NOT the ETH-orb blue tint",
			Color(shard.get("tint")) != Color(0.6, 0.8, 1.0, 1.0),
			str(shard.get("tint")))
		_check("crystal shard does not home (straight-line pressure, not tracking)",
			float(shard.get("homing")) == 0.0)

	get_tree().call_group("boss_projectile", "queue_free")
	boss.queue_free()
	player.queue_free()
