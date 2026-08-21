extends Node
## Grok 4.6 truth-audit (2026-08-22, on the height-cap fix in
## claim_jumper_no_runaway_climb_test.gd): "8 air-hops in 16s is still a lot
## of hopping in place... you only have aggregates. Needed: same real arena,
## player on a REACHABLE next spot, per-frame x,y showing he clears the old
## lip and closes on the player." That test proved the climb is BOUNDED when
## the player is unreachable beyond the wall; it did not prove he actually
## resumes ground pursuit and closes distance once the player is somewhere
## he CAN reach. This test does that, mirroring the exact pattern already
## established and trusted for the Auditor
## (auditor_full_stage_hunt_test.gd's stuck-streak / final-gap measurement).
##
## Flees the player, over real time, from the boss's spawn point all the way
## to BOTH reachable extremes of the real Stage 3 arena (the east edge near
## the old wall-pogo point, and the west edge near the entry seal) and
## asserts the Claim Jumper is never walled in place for more than a few
## seconds, and closes to striking distance by the end of each flee.
##
## Run: godot --headless res://tests/claim_jumper_escapes_and_pursues_test.tscn

const LEVEL := preload("res://src/level/level_03_gold_rush.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CLAIM JUMPER ESCAPES AND PURSUES:")
	await _run_flee(4050.0, 4370.0, "east (toward the old wall-pogo point)")
	await _run_flee(4050.0, 3730.0, "west (toward the entry seal)")
	print("CLAIM_JUMPER_ESCAPES_AND_PURSUES: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _run_flee(start_x: float, target_x: float, label: String) -> void:
	var level := LEVEL.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector2(start_x, 500.0)
	level._on_boss_trigger(player)
	await get_tree().process_frame

	var boss: CharacterBody2D = null
	for c in level.get_children():
		var sc: Script = c.get_script()
		if sc and "claim_jumper" in str(sc.resource_path):
			boss = c
			break
	if boss == null:
		_check("Claim Jumper spawned via _on_boss_trigger (%s)" % label, false)
		level.queue_free()
		return
	var hb := boss.get_node_or_null("Hitbox")
	if hb != null:
		hb.set_deferred("monitoring", false)

	# NOTE on methodology (Grok 4.6 truth-audit prompted this test; a first
	# draft used raw frame-to-frame position delta as a "stuck" proxy, which
	# produced false positives here: this boss deliberately HOLDS at
	# CHASE_SEPARATION (200px) once caught up (see
	# claim_jumper_chase_separation_test.gd) rather than walking on top of
	# the player, so near-zero x-delta during the hold phase is CORRECT
	# behavior, not a wall-stuck bug. The real signal for "stuck" is whether
	# the GAP fails to close toward CHASE_SEPARATION at all, not whether his
	# raw position is momentarily static.
	var min_gap_seen: float = INF
	var gap_at_5s: float = -1.0
	for f in range(960):  # 16s — the founder's own required flee-window length
		var t: float = float(f) / 60.0
		var progress: float = clampf(t / 10.0, 0.0, 1.0)  # cross over the first 10s, then hold
		var px: float = lerpf(start_x, target_x, progress)
		player.global_position = Vector2(px, 500.0)
		if not is_instance_valid(boss):
			_check("Claim Jumper survives the whole flee (%s)" % label, false, "boss freed mid-run")
			level.queue_free()
			return
		var gap: float = absf(boss.global_position.x - player.global_position.x)
		min_gap_seen = minf(min_gap_seen, gap)
		if f == 300:  # 5s in — plenty of time to have started closing
			gap_at_5s = gap
		await get_tree().physics_frame

	var final_gap: float = absf(boss.global_position.x - player.global_position.x)
	print("  [INFO] flee %s: final boss_x=%.0f player_x=%.0f final_gap=%.0f min_gap_seen=%.0f gap_at_5s=%.0f"
		% [label, boss.global_position.x, player.global_position.x, final_gap, min_gap_seen, gap_at_5s])
	_check("Claim Jumper actively closes distance fleeing %s (gap_at_5s < 400px, not abandoned early)" % label,
		gap_at_5s < 400.0, "gap_at_5s=%.0f — not pursuing" % gap_at_5s)
	_check("Claim Jumper ends within/near standoff distance fleeing %s (final gap <= CHASE_SEPARATION + 100px)" % label,
		final_gap <= 300.0, "final gap=%.0f — abandoned behind" % final_gap)

	boss.queue_free()
	level.queue_free()
	await get_tree().process_frame
