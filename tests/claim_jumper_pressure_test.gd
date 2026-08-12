extends Node2D
## Regression test for "the final boss... too easy to kill" (founder, this
## session — a DIFFERENT complaint than the previous "too easy to escape",
## which chase-speed tuning already fixed).
##
## Root cause (Kimi K3 TTK analysis, verified by hand against the real file):
## `claim_jumper.gd::take_damage()` had NO state gate at all, unlike
## `auditor.gd`/`distributor.gd` which both require an explicit VULNERABLE
## window. Worse, `current_state` never actually left PATROL in the shipped
## code — `_throw_dynamite()` reset `throw_timer` and spawned dynamite
## without ever setting `current_state = State.THROW`, so the THROW/
## VULNERABLE branches in `_physics_process` were dead code. A player at axe
## range (2.5 DPS, 0.4s cooldown) could kill 18 HP in 7.2s from any state,
## any range, with zero exposure to his only attack.
##
## This proves, with real physics: (1) damage is REJECTED outside VULNERABLE,
## (2) the boss actually reaches VULNERABLE via his own real attack cycle
## (not a hand-set state), (3) time-to-kill under sustained real axe fire is
## meaningfully longer than the old risk-free 7.2s floor — DeepSeek's
## compliance matrix put the honest bar at "not trivially short"; this
## measures the real number rather than asserting a round target.
##
## Run: godot --headless res://tests/claim_jumper_pressure_test.tscn

const CLAIM_JUMPER := preload("res://src/boss/claim_jumper.tscn")

var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("CLAIM JUMPER — PRESSURE (vulnerable-window gating):")
	await _test_damage_rejected_outside_vulnerable()
	await _test_boss_reaches_vulnerable_via_real_attack_cycle()
	await _test_time_to_kill_under_sustained_fire()
	print("CLAIM_JUMPER_PRESSURE: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s: %s" % [label, str(value)])

## `throw_timer` defaults to 0.0, so he commits to his first THROW on the very
## first physics frame (by design — he doesn't stand around on spawn). Assert
## the thing that actually matters: whatever state he's in this early is NOT
## VULNERABLE, so damage this early must be a no-op.
func _test_damage_rejected_outside_vulnerable() -> void:
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	await get_tree().process_frame
	var before: int = int(boss.get("health"))
	_check("boss has not reached VULNERABLE yet (State.VULNERABLE == 2)",
		int(boss.get("current_state")) != 2, "current_state=%s" % str(boss.get("current_state")))
	boss.call("take_damage", 1)
	_check("take_damage() outside VULNERABLE is rejected",
		int(boss.get("health")) == before,
		"health went %d -> %d — damage landed with zero exposure" % [before, int(boss.get("health"))])
	boss.queue_free()
	await get_tree().process_frame

## Drive the boss with ONLY its own real _physics_process (no direct state
## writes) and prove it actually reaches VULNERABLE — the exact reachability
## class of bug this project has hit before (a correct-looking branch that is
## never actually entered).
func _test_boss_reaches_vulnerable_via_real_attack_cycle() -> void:
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(4000, 80)
	fcs.shape = frect
	floor_body.add_child(fcs)
	floor_body.global_position = Vector2(1000, 620)
	add_child(floor_body)
	boss.global_position = Vector2(800, 500)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false  # isolate from boss-contact-restart during the timing measurement
	await get_tree().process_frame

	var reached_throw := false
	var reached_vulnerable := false
	for i in range(180):  # 3s — comfortably longer than throw_cooldown (0.85s)
		await get_tree().physics_frame
		var s := int(boss.get("current_state"))
		if s == 1:
			reached_throw = true
		if s == 2:
			reached_vulnerable = true
		if reached_vulnerable:
			break
	_check("the boss's own attack cycle actually enters THROW",
		reached_throw, "current_state never became 1 (THROW) in 3s of real physics")
	_check("the boss's own attack cycle actually enters VULNERABLE",
		reached_vulnerable, "current_state never became 2 (VULNERABLE) in 3s of real physics")

	boss.queue_free(); floor_body.queue_free()
	await get_tree().process_frame

## Sustained axe fire (real cooldown-gated calls to take_damage, exactly as
## fast as the player's own 0.4s AXE_COOLDOWN allows) against a boss driven
## by its own real state machine. Measures actual time-to-kill; asserts it is
## no longer the old risk-free 7.2s floor.
func _test_time_to_kill_under_sustained_fire() -> void:
	const AXE_COOLDOWN := 0.4
	var boss: Node2D = CLAIM_JUMPER.instantiate()
	add_child(boss)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fcs := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(4000, 80)
	fcs.shape = frect
	floor_body.add_child(fcs)
	floor_body.global_position = Vector2(1000, 620)
	add_child(floor_body)
	boss.global_position = Vector2(800, 500)
	var hb := boss.get_node("Hitbox") as Area2D
	hb.monitoring = false  # isolate TTK from boss-contact-restart ending the run early
	await get_tree().process_frame

	var start_health: int = int(boss.get("health"))
	var axe_cd: float = 0.0
	var t: float = 0.0
	var dt: float = 1.0 / 60.0
	var max_seconds: float = 40.0
	while t < max_seconds and not bool(boss.get("is_dead")):
		axe_cd -= dt
		# A "perfect" attacker: fires the instant the cooldown allows, every
		# single time, regardless of state — the real gate is take_damage()
		# itself, not whether this test bothers to check state first.
		if axe_cd <= 0.0:
			boss.call("take_damage", 1)
			axe_cd = AXE_COOLDOWN
		await get_tree().physics_frame
		t += dt

	var end_health: int = int(boss.get("health"))
	_check("boss actually dies under sustained perfect axe fire (fight is completable)",
		bool(boss.get("is_dead")) or end_health <= 0,
		"health at %.0fs: %d -> %d (never reached 0)" % [max_seconds, start_health, end_health])
	_info("time to kill under sustained perfect axe fire", "%.1fs" % t)
	# The old, ungated code killed 18 HP in exactly 7.2s (18 hits x 0.4s) from
	# ANY state, any range, zero exposure. The gate only requires "no longer
	# that" — a real number pulled from real physics, not a chosen target the
	# implementation was reverse-tuned to hit.
	_check("time-to-kill is no longer the old risk-free 7.2s floor",
		t > 8.0, "TTK=%.1fs — the vulnerable-window gate did not meaningfully slow the kill" % t)

	boss.queue_free(); floor_body.queue_free()
	await get_tree().process_frame
