extends Node
## Founder, 2026-08-21 (final presentation residual): "Why is he not jumping.
## He needs to be able to double jump too!!!!"
##
## The Claim Jumper had exactly one vertical tool (a single hop, `HOP_VELOCITY`)
## and nothing else — unlike the Auditor, which already has a leap + air-jump.
## Added `_air_hop_ready` (armed on every hop takeoff, spent once while still
## rising, same envelope as the Auditor's air-jump) so this boss has the same
## double-jump vocabulary.
##
## This gate runs the REAL level_03 arena, triggers the real fight, and kites
## the player across the arena for real physics time — it asserts the air-hop
## actually fires (velocity.y receives a second upward kick to AIR_HOP_VELOCITY
## while airborne, not just gravity decelerating the first hop) and that the
## boss covers a real span of the arena rather than parking in one spot.
##
## Run: godot --headless res://tests/claim_jumper_double_jump_test.tscn

const LEVEL := preload("res://src/level/level_03_gold_rush.tscn")
const AIR_HOP_VELOCITY := -560.0

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CLAIM JUMPER DOUBLE JUMP:")
	await _run()
	print("CLAIM_JUMPER_DOUBLE_JUMP: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run() -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(3820.0, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss: CharacterBody2D = null
	for c in level.get_children():
		var sc: Script = c.get_script()
		if sc and "claim_jumper" in str(sc.resource_path):
			boss = c
			break
	if boss == null:
		_check("Claim Jumper spawned via _on_boss_trigger", false)
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	var min_x: float = INF
	var max_x: float = -INF
	var air_hop_events: int = 0
	var prev_vy: float = 0.0
	for f in range(2400):  # 40s
		var t: float = float(f) / 60.0
		player.global_position = Vector2(4050.0 + sin(t * 0.6) * 340.0, 500.0)
		if not is_instance_valid(boss):
			_check("Claim Jumper survives the whole run", false, "boss freed mid-run")
			return
		var vy: float = boss.velocity.y
		if not boss.is_on_floor() and vy < -400.0 and vy < prev_vy - 100.0:
			air_hop_events += 1
		prev_vy = vy
		min_x = minf(min_x, boss.global_position.x)
		max_x = maxf(max_x, boss.global_position.x)
		await get_tree().physics_frame

	print("  [INFO] air_hop_events=%d, x-range covered=[%.0f, %.0f] (%.0fpx)"
		% [air_hop_events, min_x, max_x, max_x - min_x])
	_check("Claim Jumper's double jump actually fires (air-hop kicks vy to ~%.0f mid-air)" % AIR_HOP_VELOCITY,
		air_hop_events > 0, "no air-hop event observed in 40s of real physics")
	_check("Claim Jumper covers a real span of the arena while kiting (>= 200px)",
		(max_x - min_x) >= 200.0, "x-range only %.0fpx — reads as parked" % (max_x - min_x))

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
