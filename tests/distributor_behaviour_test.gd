extends Node
## Runtime behaviour test for The Distributor (Boss 2).
##
## WHY THIS EXISTS: every previous check on this boss was STATIC — reading the
## code, or asking a model to read it. Static review cannot answer the only
## question that matters for a pull mechanic: *does it actually move the
## player?* The first implementation used pull_strength = 520 against the
## player's own ground_decel = 2800 and was therefore pure decoration; that was
## caught by arithmetic, not by measurement. This test measures.
##
## It also catches the failure that static review provably missed: `distributor.gd`
## shipped with a `:=`-from-Variant parse error, so the script did not load AT
## ALL and the boss was inert. A behaviour test fails loudly on that because
## the state machine never advances.
##
## Run: godot --headless res://tests/distributor_behaviour_test.tscn

const DISTRIBUTOR := preload("res://src/boss/distributor.tscn")
const PLAYER := preload("res://src/player/player.tscn")

# Distributor.Phase ordinals, mirrored here rather than referenced through
# `_boss` (typed Node2D so the tests aren't coupled to the boss's static
# type). Keep in sync with the enum in src/boss/distributor.gd.
const PHASE_PATROL := 0
const PHASE_VULNERABLE := 4

var _failures: int = 0
var _boss: Node2D
var _player: CharacterBody2D

func _ready() -> void:
	await _run()

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])

func _info(label: String, value: Variant) -> void:
	print("  [INFO] %s = %s" % [label, str(value)])

## Minimal arena: a wide solid floor plus walls, mirroring the real boss arena
## (level_02 ground segment 3700..4400 is solid — there are no pits in it).
func _build_arena() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 80)
	cs.shape = rect
	floor_body.add_child(cs)
	floor_body.global_position = Vector2(0, 400)
	add_child(floor_body)

func _run() -> void:
	_build_arena()

	_player = PLAYER.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = Vector2(-200, 300)

	_boss = DISTRIBUTOR.instantiate() as Node2D
	add_child(_boss)
	_boss.global_position = Vector2(0, 280)

	# Let both settle onto the floor.
	for i in 30:
		await get_tree().physics_frame

	print("Distributor behaviour:")
	await _test_script_actually_attached()
	await _test_states_reachable_at_runtime()
	await _test_pull_moves_a_standing_player()
	_test_vulnerable_window_shrinks_per_phase()
	await _test_orb_redirect_under_real_physics()
	await _test_pool_drain_under_real_physics()
	await _test_full_damage_cycle_and_death()

	if _failures == 0:
		print("DISTRIBUTOR_BEHAVIOUR: ALL PASS")
		get_tree().quit(0)
	else:
		print("DISTRIBUTOR_BEHAVIOUR: %d FAILURE(S)" % _failures)
		get_tree().quit(1)

## The check that a parse error cannot survive: if the script failed to load,
## the node has no script and none of these members exist.
func _test_script_actually_attached() -> void:
	var scr: Variant = _boss.get_script()
	_check("boss script attached", scr != null, "(parse error would leave this null)")
	_check("boss exposes its state machine", "current_phase_state" in _boss)
	_check("boss health initialised to 14", _boss.health == 14, str(_boss.health))

## Drive the boss through a full cycle and record which states are actually
## entered by REAL physics — not by grepping for assignments.
func _test_states_reachable_at_runtime() -> void:
	var seen := {}
	# CONTACT OFF FOR THIS MEASUREMENT ONLY.
	#
	# This test parks a real, uncontrolled player in the arena for 15 seconds.
	# That was harmless while the boss could not reach anybody — which is
	# precisely the defect the founder kept reporting ("the 2nd boss doesn't
	# chase Lil Blunt"). Now that he does chase, he catches the motionless
	# player, and boss contact restarts the level by design: SceneRouter loaded
	# level 2 underneath the test, `_boss` was freed, and the run hung on the
	# next `_boss.current_phase_state`.
	#
	# The boss being lethal to someone standing still is CORRECT and is
	# asserted elsewhere (tests/boss_stakes_test.gd covers the restart-on-touch
	# rule; stage3_defence covers the chase). What this test measures is which
	# STATES the machine reaches, which is driven by its own timers and does
	# not depend on the player surviving. So the hitbox is muted here rather
	# than the boss being slowed back down to make an unrelated test pass.
	var hb := _boss.get_node("Hitbox") as Area2D
	hb.monitoring = false
	# The boss alternates pull-cycle / volley-cycle, so run long enough to see
	# both branches (throw_cooldown is 2s; 900 frames ~= 15s at 60Hz).
	for i in 900:
		seen[int(_boss.current_phase_state)] = true
		await get_tree().physics_frame
	hb.set_deferred("monitoring", true)
	await get_tree().physics_frame
	# Phase enum: 0 PATROL, 1 GRAVITY_TELL, 2 HOARD_GRAVITY, 3 SHARD_THROW, 4 VULNERABLE
	var names := ["PATROL", "GRAVITY_TELL", "HOARD_GRAVITY", "SHARD_THROW", "VULNERABLE"]
	for i in names.size():
		_check("state %s entered at runtime" % names[i], seen.has(i),
			"(never reached in 15s of real physics)")

## THE measurement. Park the player at a known distance, force the field on,
## apply NO input, and record how far the pull actually drags them.
##
## A standing player decelerates at ground_decel = 2800, so a pull weaker than
## that produces literally zero displacement — which is what shipped first.
func _test_pull_moves_a_standing_player() -> void:
	# Ask the boss where its middle is rather than assuming +48: the body grew
	# from 96px to 240px and every hardcoded half-extent silently went stale.
	var centre: Vector2 = _boss.call("hit_centre")
	# Mid-field: far enough that the falloff is doing real work.
	var start := centre + Vector2(-220, 0)
	_player.global_position = start
	_player.velocity = Vector2.ZERO
	for i in 5:
		await get_tree().physics_frame

	var before: float = _player.global_position.x
	_boss.call("_begin_hoard_gravity")
	# The field lasts 1.4s in phase 1; sample 60 frames (~1s) of it.
	for i in 60:
		await get_tree().physics_frame
	var after: float = _player.global_position.x
	var moved := after - before

	_info("player x before pull", before)
	_info("player x after 1s of pull", after)
	_info("displacement toward boss (px)", moved)

	# Direction: the boss is to the RIGHT of the player here, so a working
	# pull produces POSITIVE displacement.
	_check("pull actually moves a standing player", moved > 20.0,
		"moved only %.1f px in 1s — this is the 'cosmetic pull' regression" % moved)
	# Sanity ceiling: a pull that yanks the player hundreds of px in a second
	# is a teleport, not a drag, and would feel like losing control.
	_check("pull is a drag, not a yank", moved < 400.0,
		"moved %.1f px in 1s — too strong to fight" % moved)

## The vulnerable window must SHRINK as phases escalate (the Claim Jumper
## pattern) so there is less free damage time as everything else gets harder.
func _test_vulnerable_window_shrinks_per_phase() -> void:
	var windows: Array[float] = []
	for phase in [1, 2, 3]:
		_boss.set("current_phase", phase)
		_boss.call("_begin_vulnerable")
		windows.append(float(_boss.get("state_timer")))
	_info("vulnerable window p1/p2/p3", windows)
	_check("window shrinks p1 -> p2", windows[1] < windows[0],
		"%.2f -> %.2f" % [windows[0], windows[1]])
	_check("window shrinks p2 -> p3", windows[2] < windows[1],
		"%.2f -> %.2f" % [windows[1], windows[2]])
	_check("window never collapses to nothing", windows[2] >= 0.6,
		"p3 window is %.2fs — too short to react to" % windows[2])

## THE evidence gap this session exists to close: everything above proves the
## boss MOVES and HAS a damage window, but nothing yet proves Forced
## Distribution — the fight's signature mechanic — actually connects under
## real physics. This drives the REAL spawn path (_throw_shards), then
## overlaps a stand-in "player attack" Area2D using the EXACT layer/group
## convention real player attacks use (layer 64, group "projectile" — see
## boss_projectile.gd), and lets Godot's own physics server fire the redirect,
## homing, and arrival — none of it called directly. A broken collision mask,
## a broken group check, or broken homing math would all show up here as a
## silent "orb never redirects" or "orb never arrives", exactly like a human
## playtester would observe, instead of a green unit test that only proves the
## function exists.
func _test_orb_redirect_under_real_physics() -> void:
	# Clear any orbs left over from _test_states_reachable_at_runtime(), which
	# runs the boss through 900 REAL physics frames (~15s) beforehand and
	# leaves its own naturally-spawned orbs alive (4s lifetime each — several
	# volleys' worth survive). Without this, `get_children()` below can pick
	# up a STALE orb from an earlier volley whose `_t` is already seconds past
	# `unstable_time` — that is exactly what happened on the first run of this
	# test (orb._t measured at 2.15s), and it looks identical to a genuine
	# "redirect never fires" bug unless you notice `_t` is already huge.
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame

	_boss.health = 12
	_boss.set("current_phase", 1)
	var health_before: int = _boss.health

	_boss.call("_throw_shards")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var this_volley: int = int(_boss.get("_volley_id"))
	var orb: Area2D = null
	for child in get_children():
		if child.is_in_group("boss_projectile") and int(child.get("volley_id")) == this_volley:
			orb = child
			break
	_check("_throw_shards spawns a redirectable orb", orb != null,
		"no boss_projectile from the current volley (id=%d) found in the tree" % this_volley)
	if orb == null:
		return

	_check("boss is NOT in VULNERABLE when the volley is thrown",
		int(_boss.current_phase_state) != PHASE_VULNERABLE,
		"state=%d — Forced Distribution is meaningless if it can only land during the existing window" % int(_boss.current_phase_state))

	# CONTACT OFF FOR THIS MEASUREMENT ONLY — same technique as
	# _test_states_reachable_at_runtime() above, for a related but distinct
	# reason. The orb muzzle sits at (BODY/2, BODY*0.21), which is genuinely
	# inside the boss's own (correctly re-centred — see distributor.gd's
	# HURTBOX_SIZE/CENTER) hurtbox: a real player weapon there would ALSO be
	# hitting the boss directly. That's correct in a real fight, but it isn't
	# what THIS test isolates — it wants to prove the ORB redirect path works
	# on its own, not conflate it with the separate direct-hit path (which
	# would additionally call take_damage() -> _end_vulnerable(), stepping on
	# whatever state the redirect path just set). Muted here, restored after.
	var hb := _boss.get_node("Hitbox") as Area2D
	var hb_monitoring_before := hb.monitoring
	hb.monitoring = false

	# A stand-in for a real player attack: same layer (64) and group
	# ("projectile") every real attack in this project uses. This is NOT a
	# call into the orb's private methods — it is a genuine Area2D the
	# physics server must actually detect.
	var attack := Area2D.new()
	attack.add_to_group("projectile")
	attack.collision_layer = 64
	attack.collision_mask = 0
	var acs := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(24, 24)
	acs.shape = arect
	attack.add_child(acs)
	attack.global_position = orb.global_position
	add_child(attack)

	var redirected := false
	for i in 10:
		await get_tree().physics_frame
		if bool(orb.get("_redirected")):
			redirected = true
			break
	_check("a real overlap (layer 64 + group 'projectile') redirects the orb", redirected,
		"orb._redirected never became true — collision mask/group wiring is broken")
	attack.queue_free()
	hb.set_deferred("monitoring", hb_monitoring_before)
	if not redirected:
		return

	# The homing + arrival path is itself real physics, not a call — this is
	# where a wrong distance threshold or a stale owner_boss reference would
	# leave the orb flying forever instead of connecting.
	var landed := false
	for i in 90:
		await get_tree().physics_frame
		if not is_instance_valid(orb):
			landed = true
			break
	_check("redirected orb homes in and is consumed on arrival", landed,
		"orb still alive 1.5s after redirect — homing/arrival math is broken")

	_info("boss health before -> after redirect", "%d -> %d" % [health_before, _boss.health])
	_check("the redirect actually damaged the boss OUTSIDE the vulnerable window",
		_boss.health < health_before,
		"health unchanged at %d — Forced Distribution did not connect under real physics" % _boss.health)

## POOL DRAIN is the volley-clear bonus: redirect every orb in one volley and
## it fires automatically from inside the redirect signal handler — before
## any of them have even arrived. Verified by redirecting all three phase-1
## orbs via the same real-collision path as above, then checking the boss was
## kicked straight into VULNERABLE with the state_timer extension applied.
func _test_pool_drain_under_real_physics() -> void:
	# Clear any stray orbs a previous test left mid-flight so this volley is
	# unambiguous.
	get_tree().call_group("boss_projectile", "queue_free")
	await get_tree().physics_frame

	_boss.health = 12
	_boss.set("current_phase", 1)
	_boss.current_phase_state = PHASE_PATROL
	var health_before: int = _boss.health

	_boss.call("_throw_shards")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var this_volley: int = int(_boss.get("_volley_id"))
	var orbs: Array = []
	for child in get_children():
		if child.is_in_group("boss_projectile") and int(child.get("volley_id")) == this_volley:
			orbs.append(child)
	_check("phase-1 volley spawns exactly 3 orbs", orbs.size() == 3, "spawned %d" % orbs.size())
	if orbs.size() != 3:
		return

	# CONTACT OFF FOR THIS MEASUREMENT ONLY — see the identical note in
	# _test_orb_redirect_under_real_physics(). The orb muzzle sits inside the
	# boss's own (correctly re-centred) hurtbox, so these stand-in attacks
	# would otherwise ALSO land a direct hit on the boss and call
	# take_damage() -> _end_vulnerable(), undoing the very VULNERABLE state
	# this test exists to prove POOL DRAIN sets.
	var hb := _boss.get_node("Hitbox") as Area2D
	var hb_monitoring_before := hb.monitoring
	hb.monitoring = false

	# All 3 stand-in attacks are created up front and freed together at the
	# end, rather than one-at-a-time create/wait/free — a tight sequential
	# churn of physics Area2D objects (create -> queue_free -> immediately
	# create the next) reliably crashed the engine with a SIGSEGV here.
	# Letting physics settle all three overlaps together across shared
	# frames avoids that churn entirely.
	var attacks: Array = []
	for orb in orbs:
		var attack := Area2D.new()
		attack.add_to_group("projectile")
		attack.collision_layer = 64
		attack.collision_mask = 0
		var acs := CollisionShape2D.new()
		var arect := RectangleShape2D.new()
		arect.size = Vector2(24, 24)
		acs.shape = arect
		attack.add_child(acs)
		attack.global_position = orb.global_position
		add_child(attack)
		attacks.append(attack)

	for i in 10:
		await get_tree().physics_frame
		var all_done := true
		for orb in orbs:
			if not bool(orb.get("_redirected")):
				all_done = false
		if all_done:
			break

	for attack in attacks:
		attack.queue_free()
	hb.set_deferred("monitoring", hb_monitoring_before)
	await get_tree().physics_frame

	var all_redirected := true
	for orb in orbs:
		if is_instance_valid(orb) and not bool(orb.get("_redirected")):
			all_redirected = false
	_check("all 3 orbs in the volley were redirected", all_redirected)

	# _pool_drain() fires synchronously from inside the last orb's `redirected`
	# signal — no travel time needed, so this is observable immediately.
	_check("POOL DRAIN forces the boss straight into VULNERABLE",
		int(_boss.current_phase_state) == PHASE_VULNERABLE,
		"state=%d — the volley-clear bonus did not fire" % int(_boss.current_phase_state))
	_info("boss health before -> after pool drain", "%d -> %d" % [health_before, _boss.health])
	_check("POOL DRAIN dealt real damage", _boss.health < health_before,
		"health unchanged at %d" % _boss.health)

## Drives the ordinary vulnerable-window damage path (no redirects) through
## BOTH phase thresholds to an actual death, using the real gated
## `take_damage()` — not a direct health write — so a regression that breaks
## the VULNERABLE gate or the phase math would fail this exactly like a
## player finding the fight impossible to finish, or trivial to no-sell.
func _test_full_damage_cycle_and_death() -> void:
	get_tree().call_group("boss_projectile", "queue_free")
	if is_instance_valid(_boss):
		_boss.queue_free()
	await get_tree().physics_frame

	_boss = DISTRIBUTOR.instantiate() as Node2D
	add_child(_boss)
	_boss.global_position = Vector2(0, 280)
	for i in 10:
		await get_tree().physics_frame
	_check("fresh boss starts at full health", int(_boss.get("health")) == 14,
		str(_boss.get("health")))

	# Drive down to 1 HP first — stop short of the kill so we can assert the
	# phase escalation cleanly before touching die()'s scene-transition side
	# effects (score, StateMachine, SceneRouter) on the final blow.
	# 13 hits to walk 14 HP down to 1; the ceiling is generous so a genuine
	# stall shows up as a failed assertion rather than a hung test.
	var hits := 0
	while int(_boss.get("health")) > 1 and hits < 30:
		_boss.call("_begin_vulnerable")
		_boss.call("take_damage", 1)
		hits += 1
	_check("boss survives down to 1 HP via the gated take_damage() path",
		int(_boss.get("health")) == 1, "health=%d after %d hits" % [_boss.get("health"), hits])
	_check("phase escalates to 3 before death (thresholds [9,4])",
		int(_boss.get("current_phase")) == 3, "current_phase=%d" % int(_boss.get("current_phase")))

	# The killing blow. die() is a coroutine; calling it (indirectly, via
	# take_damage -> _damage -> die) runs synchronously up to its first
	# `await`, so `is_dead` — set on die()'s very first line — is reliably
	# observable right after this call returns, with no extra waiting.
	_boss.call("_begin_vulnerable")
	_boss.call("take_damage", 1)
	_check("the killing blow sets is_dead", bool(_boss.get("is_dead")),
		"is_dead still false after health should have reached 0")
