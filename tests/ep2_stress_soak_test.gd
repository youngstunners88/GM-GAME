extends Node
## Seeded soak + adversarial-input gate for the Episode 2 runner↔chamber loop
## (skills: deterministic-stress-harness, ep2-state-transition-audit).
##
## Three suites:
##   S1 soak         — many full loop cycles; assert zero drift in node count,
##                     active-scene count, and economy totals.
##   S2 adversarial  — illegal/out-of-order/spammed input; assert the system
##                     refuses it without crashing and without paying out.
##   S3 failure path — death mid-vest commits NOTHING partial.
##
## Determinism: fixed committed seed; every failure prints a REPRO line.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/ep2_stress_soak_test.tscn

const SEED: int = 20260910
## Cycles are cheap when driven by step() — no rendering, no real frame clock.
## Many short cycles beat few long ones: the loop BOUNDARY is where transition
## bugs live, not the middle of a run.
const CYCLES: int = 2000
const ROOT_SCENE := preload("res://src/episode2/session/ep2_session_root.tscn")

var _rng := RandomNumberGenerator.new()
var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _repro(step: int, why: String) -> void:
	_fail += 1
	print("  REPRO: seed=%d cycle=%d -> %s" % [SEED, step, why])

## A short segment so a cycle is a handful of sim-seconds, with a zip beat and
## one bear, so the soak exercises the real loop rather than a stripped one.
func _plan() -> Array:
	return [{
		"chamber_z": 36.0,
		"obstacles": [],
		"zip_segments": [{"start_z": 12.0, "end_z": 20.0}],
		"gold_principal": 1000,
		"bears": [{"z": 6.0}],
	}]

func _mk_root(commit: bool) -> Node:
	var r: Node = ROOT_SCENE.instantiate()
	add_child(r)
	r.configure(_plan(), commit)
	return r

func _live_children(r: Node) -> int:
	var n := 0
	for c in r.get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			n += 1
	return n

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 STRESS SOAK (seed=%d, cycles=%d):" % [SEED, CYCLES])
	_rng.seed = SEED

	var gm: Node = get_node_or_null("/root/GoldMineSystem")
	if gm:
		gm.reset_session()

	await _s1_soak(gm)
	await _s2_adversarial()
	await _s3_failure_path(gm)

	if gm:
		gm.reset_session()
	print("EP2_STRESS_SOAK: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

# --- S1: soak / drift --------------------------------------------------------

func _s1_soak(gm: Node) -> void:
	print(" S1 soak — %d full runner->chamber cycles:" % CYCLES)

	# commit_to_economy = false: the loop must not mutate the real singleton, so
	# ANY economy drift here is a leak in the commit boundary itself.
	var econ_before: Array = _econ(gm)
	var baseline_nodes: int = -1
	var max_live: int = 0
	var completed: int = 0
	var dt := 1.0 / 60.0

	for cycle in CYCLES:
		var r := _mk_root(false)
		r.start()
		# Runner: 36m at RUN_SPEED 12 == 3s. Step past it to reach the chamber.
		for i in 220:
			r.step(dt)
			if r.get_mode() == Ep2SessionRoot.Mode.CHAMBER:
				break
		if r.get_mode() != Ep2SessionRoot.Mode.CHAMBER:
			_repro(cycle, "never reached CHAMBER mode (mode=%d)" % r.get_mode())
			r.queue_free()
			await get_tree().process_frame
			continue

		var c: Node = r.get_active()
		# Sample the live-scene count HERE, mid-loop, while a chamber is
		# actually resident. Sampling after the cycle resolves would always
		# read 0 (the root has torn down) and the assertion would be vacuous —
		# it would pass even with guard #3 removed.
		max_live = maxi(max_live, _live_children(r))
		# Clear the bear first — left alive it kills the player before any vest
		# accrues, which is the failure path (covered by S3), not the soak path.
		c.start_rig("eth")
		for i in MinerShaftChamber.BEAR_HP:
			c.shoot()
		# Randomised resolve: sometimes early-claim, sometimes ride to full vest.
		if _rng.randi_range(0, 1) == 0:
			for i in 120:
				c.step(dt)
			c.early_claim()
		else:
			for i in int(MinerShaftChamber.VEST_SECONDS_FULL * 60.0) + 30:
				c.step(dt)
		if not c.is_resolved():
			_repro(cycle, "chamber never resolved")

		completed += 1
		max_live = maxi(max_live, _live_children(r))
		r.queue_free()
		await get_tree().process_frame     # queue_free is deferred — count AFTER

		if baseline_nodes < 0:
			baseline_nodes = get_tree().get_node_count()

	await get_tree().process_frame
	var end_nodes: int = get_tree().get_node_count()

	_check("all %d cycles completed the loop (got %d)" % [CYCLES, completed],
		completed == CYCLES)
	# Must be exactly 1, not <= 1: a 0 would mean the sample never caught a live
	# scene and the guard-#3 assertion proved nothing.
	_check("exactly one active scene under the root at all times (max observed=%d)" % max_live,
		max_live == 1, "0 means the probe never observed a live scene — assertion would be vacuous")
	_check("node count does not drift across %d cycles (%d -> %d)"
			% [CYCLES, baseline_nodes, end_nodes],
		end_nodes <= baseline_nodes + 2, "orphaned scenes are the mobile-OOM failure mode")

	var econ_after: Array = _econ(gm)
	_check("economy totals show EXACT zero drift with commit disabled (%s -> %s)"
			% [econ_before, econ_after],
		econ_before == econ_after)

func _econ(gm: Node) -> Array:
	if gm == null:
		return []
	return [
		int(gm.gold_balance), int(gm.auction_gold_pool), int(gm.diamonds_balance),
		int(gm.xaut_balance), int(gm.fort_knox_shares), int(gm.lifetime_gold_mined),
	]

# --- S2: adversarial input ---------------------------------------------------

func _s2_adversarial() -> void:
	print(" S2 adversarial input:")

	# Verb spam in every mode, every frame. The assertion is that NOTHING
	# happens: no crash, no commit, no mode corruption.
	var r := _mk_root(false)
	var commits: Array = []
	r.chamber_committed.connect(func(i, res): commits.append(res))
	r.start()
	var dt := 1.0 / 60.0
	for i in 600:
		r.runner_jump()
		r.runner_duck_start()
		r.runner_switch_lane_left()
		r.runner_switch_lane_right()
		r.runner_duck_end()
		r.chamber_start_rig("eth")
		r.chamber_shoot()
		r.chamber_early_claim()
		r.chamber_take_cover()
		r.chamber_leave_cover()
		r.step(dt)
	_check("verb spam across modes never crashes and never double-commits (commits=%d)"
			% commits.size(), commits.size() <= 1)
	_check("root survives verb spam in a valid mode (mode=%d)" % r.get_mode(),
		r.get_mode() in [Ep2SessionRoot.Mode.IDLE, Ep2SessionRoot.Mode.RUNNER,
			Ep2SessionRoot.Mode.CHAMBER, Ep2SessionRoot.Mode.TRANSITION])
	r.queue_free()
	await get_tree().process_frame

	# Out-of-order chamber verbs: claim before the rig starts, shoot after
	# resolve, start_rig twice.
	var r2 := _mk_root(false)
	var commits2: Array = []
	r2.chamber_committed.connect(func(i, res): commits2.append(res))
	r2.start()
	for i in 220:
		r2.step(dt)
		if r2.get_mode() == Ep2SessionRoot.Mode.CHAMBER:
			break
	var c2: Node = r2.get_active()
	_check("early_claim before the rig starts is refused", not c2.early_claim())
	_check("no commit from a pre-rig claim (commits=%d)" % commits2.size(), commits2.size() == 0)
	c2.start_rig("eth")
	_check("second start_rig is refused", not c2.start_rig("eth"))
	c2.early_claim()
	var after_resolve_commits: int = commits2.size()
	for i in 50:
		c2.shoot()
	c2.early_claim()
	c2.take_cover()
	_check("post-resolve verbs never produce another commit (%d -> %d)"
			% [after_resolve_commits, commits2.size()],
		commits2.size() == after_resolve_commits)
	r2.queue_free()
	await get_tree().process_frame

	# Rapid re-entry: configure/start repeatedly without ever finishing.
	var r3 := _mk_root(false)
	for i in 50:
		r3.configure(_plan(), false)
		r3.start()
		r3.step(dt)
	_check("rapid re-configure/start does not leak scenes (live=%d)" % _live_children(r3),
		_live_children(r3) <= 1)
	r3.queue_free()
	await get_tree().process_frame

# --- S3: failure path commits nothing partial --------------------------------

func _s3_failure_path(gm: Node) -> void:
	print(" S3 failure path — no partial commit:")
	if gm == null:
		print("  [SKIP] GoldMineSystem absent")
		return

	gm.reset_session()
	var before: Array = _econ(gm)

	# commit_to_economy = TRUE here: we are specifically asserting that a FAILED
	# chamber writes nothing to the real ledger.
	var r := _mk_root(true)
	var failed := [false]
	r.session_failed.connect(func(): failed[0] = true)
	r.start()
	var dt := 1.0 / 60.0
	for i in 220:
		r.step(dt)
		if r.get_mode() == Ep2SessionRoot.Mode.CHAMBER:
			break
	var c: Node = r.get_active()
	c.start_rig("eth")
	# Do NOT clear the bear: it reaches the rig and kills the player mid-vest.
	for i in 1200:
		c.step(dt)
		if not c.is_running():
			break

	_check("player died mid-vest (health=%d)" % c.get_health(), c.get_health() == 0)
	_check("session reported failure", failed[0])
	var after: Array = _econ(gm)
	_check("a failed chamber commits NOTHING to the ledger (%s -> %s)" % [before, after],
		before == after, "partial credit on a failure path is a value leak")
	r.queue_free()
	await get_tree().process_frame
	gm.reset_session()
