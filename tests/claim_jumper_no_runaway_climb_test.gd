extends Node
## Founder, 2026-08-22 (PROMPT_CLAIM_JUMPER_STUCK_DOUBLE_JUMP.md):
## "He cannot move beyond the current platform/ledge point." Screenshot
## showed him looping erratically near the minecart/TNT/Hall of Blaze area.
##
## Root cause (same bug class as the Auditor, found + fixed 2026-08-21): the
## hop AND its air-hop both fired unconditionally on any is_on_wall() contact
## with no ceiling on cumulative height. `_clamp_to_arena()` pins X at the
## arena wall but deliberately does NOT clamp the ceiling ("Only the FLOOR is
## clamped, not the ceiling: he hops, and pinning his maximum height would
## cancel the hop mid-air") — so a hop taken right at the clamped wall re-armed
## every `_hop_cooldown` with X frozen by the clamp, climbing in place forever
## instead of ever getting a grounded chase frame. That reads as "stuck" even
## though he is technically airborne and "jumping".
##
## Fixed with an `already_high_enough` ceiling (>400px above the player) gating
## the hop trigger AND the air-hop fire condition (gating only the former was
## proven insufficient for the analogous Auditor bug — an already-armed air-hop
## from a hop taken a frame before crossing the threshold still chained past it).
##
## This gate reproduces the exact failure geometry: parks the player beyond the
## arena's east wall so the boss is permanently blocked and would, pre-fix,
## climb unboundedly in place. Runs the REAL level_03 arena via _on_boss_trigger.
##
## Run: godot --headless res://tests/claim_jumper_no_runaway_climb_test.tscn

const LEVEL := preload("res://src/level/level_03_gold_rush.tscn")
const SPAWN_Y := 500.0
const HEIGHT_CEILING := 400.0
const CEILING_TOLERANCE := 120.0  # bounded single-overshoot allowance, matching the Auditor's measured -54px residual

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CLAIM JUMPER NO RUNAWAY CLIMB:")
	await _run()
	print("CLAIM_JUMPER_NO_RUNAWAY_CLIMB: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
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
	# Beyond the arena's east wall (start_x=3700, end_x=4400) so the boss is
	# permanently blocked there — the exact geometry that used to produce an
	# endless in-place hop/air-hop climb.
	player.global_position = Vector2(4500.0, SPAWN_Y)
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

	var min_y: float = INF
	var air_hop_events: int = 0
	var prev_vy: float = 0.0
	var frames_far_above_ceiling: int = 0
	for f in range(960):  # 16s, pinned at the wall the whole time
		player.global_position = Vector2(4500.0, SPAWN_Y)
		if not is_instance_valid(boss):
			_check("Claim Jumper survives the whole run", false, "boss freed mid-run")
			return
		var vy: float = boss.velocity.y
		if not boss.is_on_floor() and vy < -400.0 and vy < prev_vy - 100.0:
			air_hop_events += 1
		prev_vy = vy
		min_y = minf(min_y, boss.global_position.y)
		if boss.global_position.y < SPAWN_Y - HEIGHT_CEILING - CEILING_TOLERANCE:
			frames_far_above_ceiling += 1
		await get_tree().physics_frame

	print("  [INFO] min_y=%.1f (spawn_y=%.1f, ceiling=%.1f) air_hop_events=%d frames_far_above_ceiling=%d"
		% [min_y, SPAWN_Y, SPAWN_Y - HEIGHT_CEILING, air_hop_events, frames_far_above_ceiling])
	_check("Boss never climbs unbounded past the height ceiling (+%.0fpx tolerance)" % CEILING_TOLERANCE,
		frames_far_above_ceiling == 0,
		"boss spent %d frames above the ceiling+tolerance — runaway climb regressed" % frames_far_above_ceiling)
	_check("Double jump still fires even while pinned at the arena wall",
		air_hop_events > 0, "no air-hop event observed in 16s pinned at the wall")

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
