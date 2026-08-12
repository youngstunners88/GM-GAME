extends Node
## Regression test for the SPECIFIC mechanism behind "not firing diamonds /
## crystals / crystal shards as requested" (founder, reported a second time,
## after the attack was already shipped and passing every existing gate).
##
## Kimi K3 re-derived the actual rotation timeline and found the real cause:
## crystal shards sat THIRD in the 3-way action slot, so the first volley
## didn't fire until ~9.3s into a fresh fight — and the boss chases at
## 345px/s while any contact is an instant run-wipe, so a normal, SHORT
## engagement (a player who gets caught, or who is fighting cautiously) could
## end before ever reaching that slot. This asserts the fix directly: the
## first crystal-shard volley must land inside a realistic SHORT engagement
## window, not just "eventually, within 20s" (distributor_crystal_shard_test
## already covers the long-window case).
##
## Run: godot --headless res://tests/distributor_early_crystal_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("DISTRIBUTOR — EARLY CRYSTAL SHARD (short-engagement fix):")
	await _test_crystal_reachable_within_short_engagement()
	print("DISTRIBUTOR_EARLY_CRYSTAL: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## The real proof: a FRESH boss, driven only by its own real _physics_process
## (no direct calls), must fire a crystal shard within a short window that
## matches a realistic engagement — well under the old ~9.3s.
func _test_crystal_reachable_within_short_engagement() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame
	var boss: Node2D = DISTRIBUTOR.instantiate()
	add_child(boss)
	var player := CharacterBody2D.new()
	player.collision_layer = 2
	player.collision_mask = 0
	player.add_to_group("player")
	player.global_position = Vector2(400, 500)
	add_child(player)
	boss.global_position = Vector2(0, 400)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false  # isolate the timing measurement from contact-restart
	await get_tree().physics_frame

	# 5 real seconds — a short, realistic engagement window. The OLD rotation
	# order could not possibly fire a crystal shard this early (first slot
	# was `_begin_gravity_tell`, second `_throw_shards`; crystal was 3rd,
	# ~9.3s out). 300 frames = 5s @ 60Hz.
	var saw_crystal := false
	var frames_to_first_crystal := -1
	for i in range(300):
		await get_tree().physics_frame
		for child in get_children():
			if child.is_in_group("boss_projectile") and not bool(child.get("redirectable")):
				saw_crystal = true
				frames_to_first_crystal = i
				break
		if saw_crystal:
			break

	_check("a crystal shard fires within 5s of a fresh engagement (was ~9.3s)",
		saw_crystal,
		"no non-redirectable (crystal) projectile appeared within 300 real physics frames")
	if saw_crystal:
		_info("frames to first crystal shard", frames_to_first_crystal)

	get_tree().call_group("boss_projectile", "queue_free")
	boss.queue_free(); player.queue_free()
	await get_tree().process_frame

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s: %s" % [label, str(value)])
