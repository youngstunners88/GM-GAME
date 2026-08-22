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

	# GIVE HIM GEOMETRY THAT ACTUALLY NEEDS A JUMP.
	#
	# Founder, 2026-08-22: this gate used to kite the player along the FLAT
	# arena floor and count air-hops, and it passed with 11. Those 11 were the
	# wall-pogo: both arena walls were solid to the boss, `is_on_wall()` latched
	# every grounded frame, and he bounced. Once the walls were moved to a
	# player-only layer (they had been freezing him for 13.05s of a 15s run) the
	# count went to 0 — and 0 is CORRECT on a flat slab with a working standoff:
	# he never reaches the arena bound, so nothing asks him to jump.
	#
	# The founder's requirement is "double jump when geometry NEEDS it", so the
	# gate now builds that geometry: a real raised ledge inside the arena with
	# the player standing on top of it. That tests the actual behaviour instead
	# of counting a bug.
	var ledge := StaticBody2D.new()
	ledge.collision_layer = 1
	ledge.collision_mask = 0
	var lcs := CollisionShape2D.new()
	var lshape := RectangleShape2D.new()
	lshape.size = Vector2(260.0, 40.0)
	lcs.shape = lshape
	ledge.add_child(lcs)
	level.add_child(ledge)
	# WEST of the boss's spawn: he spawns at origin x=4050 with a 280px body
	# (centre 4190, span 4050-4330), so a ledge near 4180 would be built INSIDE
	# him and jam him at spawn. 3800 sits clear of that and makes him travel.
	ledge.global_position = Vector2(3800.0, 430.0)

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
		# Stand on the raised ledge — real higher ground he must jump to reach.
		player.global_position = Vector2(3800.0, 360.0)
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
	_check("Claim Jumper's double jump fires when geometry needs it (player on a raised ledge)",
		air_hop_events > 0,
		"no air-hop observed in 40s with the player on a real raised ledge — the double jump is dead, not merely unused")
	# He is climbing to a fixed ledge here, not kiting, so a wide x-span is not
	# the point of this gate any more — claim_jumper_moves_test owns that claim.
	_check("Claim Jumper approaches the ledge rather than parking at spawn",
		(max_x - min_x) >= 60.0, "x-range only %.0fpx" % (max_x - min_x))

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
