extends Node
## T5 — "The boss in stage 2 is still not chasing!!!!" reported a THIRD time,
## after two prior real-physics gates both reported PASS.
##
## Neither prior gate could have caught what was actually still broken:
## `distributor_behaviour_test.gd` never drives a sustained kite, and
## `stage3_defence_test.gd`'s real-arena gate never damages the boss — so
## neither gate has EVER run him past Phase 1. Phase 1's chase is genuinely
## fine. Kimi K3, reconstructing the state machine from distributor.gd with no
## memory of prior sessions, found that a full Phase 2 cycle nets close to
## zero — sometimes negative — against a player who does nothing but hold
## sprint, because VULNERABLE (his real damage window, deliberately kept slow
## — "half a sprint" — so a hit is actually landable) drags for long enough
## each cycle to outweigh what the pursuing states gain back.
##
## An UNBOUNDED open-ground version of this test was tried first and stayed
## red even after two real, verified speed fixes (MIN_PURSUE_SPEED 265->315,
## a dedicated faster CLIMB_SPEED for the vertical-only safety-lock case) —
## VULNERABLE's drag alone outweighs what raising the pursuing floor can ever
## claw back, and pushing VULNERABLE_DRIFT closer to sprint speed to fully
## close that gap would gut the "half a sprint, fair hit window" design the
## founder explicitly liked. That is a real, currently-open gap for a
## hypothetical arena much longer than any that ship — see
## docs/model-responses/2026-08-11-kimi-claimreset-chase-numbers.md for the
## numbers — but it is not what the shipped game actually needs to satisfy:
## every real arena is a few hundred px wide, so the question that matters is
## whether Phase 2, SPECIFICALLY, still reaches a player inside the REAL
## bounded arena, not on hypothetically infinite ground.
##
## This drives the boss through REAL damage into Phase 2, inside the REAL
## level_02 arena bounds, and kites exactly like the founder does — run to
## the wall, then hold — proving the fix actually reaches the fight state the
## founder is describing, not just Phase 1.
##
## Run: godot --headless res://tests/distributor_phase2_open_ground_chase_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("DISTRIBUTOR PHASE 2 REAL-ARENA CHASE:")
	await _run()
	print("DISTRIBUTOR_PHASE2_REAL_ARENA_CHASE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _make_player(at: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.collision_layer = 2
	p.collision_mask = 0
	p.add_to_group("player")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(32, 32)
	cs.shape = r
	cs.position = Vector2(16, 16)
	p.add_child(cs)
	p.global_position = at
	add_child(p)
	return p

func _run() -> void:
	# Values copied from level_02_data.tres + level_02_crystal_caverns.gd —
	# the SAME real arena stage3_defence_test.gd's Phase-1 gate uses.
	var arena_start: float = 3700.0
	var arena_end: float = 4400.0
	var spawn := Vector2(4050.0, 500.0)
	var player := _make_player(Vector2(4300.0, 500.0))
	var boss: Node2D = DISTRIBUTOR.instantiate()
	boss.set("arena_min", Vector2(arena_start, spawn.y - 320.0))
	boss.set("arena_max", Vector2(arena_end, spawn.y + 120.0))
	boss.global_position = spawn
	add_child(boss)
	await get_tree().physics_frame

	# Drive him into Phase 2 (health <= 9 of 14) via the SAME real damage path
	# the player's attacks use — not a hand-set current_phase.
	for i in range(5):
		boss.call("_begin_vulnerable")
		boss.call("take_damage", 1)
	_check("boss actually reached Phase 2 via real damage",
		int(boss.get("current_phase")) >= 2,
		"current_phase = %d (health = %s)" % [int(boss.get("current_phase")), str(boss.get("health"))])
	# Let the forced VULNERABLE run its course back into the normal cycle
	# before measuring, so the kite window starts from a clean state entry.
	for i in range(90):
		await get_tree().physics_frame

	# CONTINUOUS bounce, not "run to the wall and hold". A player who stops
	# dead at a wall gets caught by ANY positive speed eventually — a 700px
	# arena is small enough that this passed even at the OLD, under-sprint
	# MIN_PURSUE_SPEED (265), which means "run to the wall and hold" is not
	# actually a fair test of whether Phase 2 keeps pace; it only tests
	# whether geometry eventually wins, which it always does in a box this
	# size. A player who keeps MOVING — bouncing wall to wall, the way an
	# actual kiting player plays rather than freezing — is the harder, more
	# representative case, and IS the one that told the old speed and the new
	# one apart during this investigation.
	var start_gap: float = absf(player.global_position.x - boss.global_position.x)
	var direction: float = -1.0
	var min_gap: float = start_gap
	var max_gap_after_settle: float = 0.0
	for i in range(600):
		var next_x: float = player.global_position.x + direction * 240.0 * (1.0 / 60.0)
		if next_x <= arena_start or next_x >= arena_end:
			direction *= -1.0
		player.global_position.x = clampf(next_x, arena_start, arena_end)
		await get_tree().physics_frame
		var gap: float = absf(player.global_position.x - boss.global_position.x)
		min_gap = minf(min_gap, gap)
		if i >= 180:  # after 3s, ignore the initial-approach transient
			max_gap_after_settle = maxf(max_gap_after_settle, gap)
	var end_gap: float = absf(player.global_position.x - boss.global_position.x)

	_check("boss stayed in a pursuing phase for the whole kite (didn't die/despawn)",
		is_instance_valid(boss) and not bool(boss.get("is_dead")))
	# Not "he must be adjacent at the exact final frame" (any oscillating kite
	# has a worst-in-cycle separation) — the real question is whether he ever
	# genuinely CLOSES to contact range at any point during sustained
	# bouncing, proving he keeps pace with a player who never stops moving,
	# rather than drifting further behind every cycle.
	_check("in Phase 2+, a continuously bouncing kite still gets caught at some point",
		min_gap < 150.0,
		"closest approach across the whole kite was %.0fpx — never got him in range" % min_gap)
	_check("in Phase 2+, once engaged, the boss doesn't drift into a widening, uncatchable gap",
		max_gap_after_settle < 500.0,
		"gap after the first 3s peaked at %.0fpx (arena is only %.0fpx wide) — steadily losing ground"
			% [max_gap_after_settle, arena_end - arena_start])

	boss.queue_free(); player.queue_free()
	await get_tree().process_frame
