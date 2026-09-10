extends Node
## Headless gate for the Episode 2 runner↔chamber session root.
##
## Every assertion here maps to one of the five guards architecture rail #5
## names for the loop (see the header of src/episode2/session/ep2_session_root.gd):
##   1. double-triggered rewards   -> tests 6-8
##   2. stale input                -> tests 9-11
##   3. duplicate player           -> tests 3-5
##   4. wrong resume position      -> tests 12-14
##   5. mobile memory              -> tests 4-5 (outgoing scene is freed, not hidden)
##
## The whole loop is driven with `commit_to_economy = false` so this gate never
## mutates the real GoldMineSystem singleton and leaks GOLD into another test
## in the same headless run. The commit path itself is asserted separately in
## test 15 against a fresh, explicitly-read baseline.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_session_root_test.tscn

const ROOT_SCENE := preload("res://src/episode2/session/ep2_session_root.tscn")

var _fail: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

func _mk(plan: Array, commit: bool = false) -> Node:
	var r: Node = ROOT_SCENE.instantiate()
	add_child(r)
	r.configure(plan, commit)
	return r

func _run(r: Node, seconds: float) -> void:
	var dt := 1.0 / 60.0
	for i in int(round(seconds / dt)):
		r.step(dt)

## One short segment: chamber entrance 60m in, one overhead zip-line beat
## (the IMG_2479 traversal, FOUNDER_PROMPT §Mode A / V2 addendum), one bear
## waiting in the chamber.
##
## The zip segment is deliberately part of the DEFAULT plan rather than a
## special case: the mechanic was already implemented and unit-tested in
## runner_graybox.gd, but nothing had ever driven it through the actual
## runner→chamber loop, so "built" and "reachable in a session" were still
## two different claims. Test 16 closes that gap.
func _plan_one(principal: int = 1000) -> Array:
	return [{
		"chamber_z": 60.0,
		"obstacles": [],
		"zip_segments": [{"start_z": 20.0, "end_z": 32.0}],
		"gold_principal": principal,
		"bears": [{"z": 6.0}],
	}]

func _ready() -> void:
	await get_tree().process_frame
	print("EP2 SESSION ROOT:")

	# 1-2. Starts in the runner, with a live runner scene under the root.
	var r1 := _mk(_plan_one())
	r1.start()
	_check("session starts in RUNNER mode", r1.get_mode() == Ep2SessionRoot.Mode.RUNNER)
	_check("a runner scene is active", r1.get_active() is RunnerGraybox)

	# 3-5. Reaching the chamber swaps modes: chamber in, runner GONE (guards 3+5).
	_run(r1, 6.0)   # 60m at RUN_SPEED 12 = 5s, plus margin
	_check("reaching the entrance swaps to CHAMBER mode", r1.get_mode() == Ep2SessionRoot.Mode.CHAMBER)
	_check("the active scene is now the chamber", r1.get_active() is MinerShaftChamber)
	await get_tree().process_frame   # let queue_free() settle
	var runners := 0
	var chambers := 0
	for ch in r1.get_children():
		if ch is RunnerGraybox and is_instance_valid(ch):
			runners += 1
		if ch is MinerShaftChamber and is_instance_valid(ch):
			chambers += 1
	_check("no runner scene survives the swap (found %d)" % runners, runners == 0)
	_check("exactly one chamber scene exists (found %d)" % chambers, chambers == 1)

	# 6-8. Double-reward guard.
	#
	# Note on what is NOT tested here: connecting `chamber_cleared` to
	# `_on_chamber_cleared` a second time is not a reachable failure mode —
	# Godot refuses a duplicate connection of the same callable outright
	# ("Signal is already connected to given callable"), so the guard can
	# never be reached that way. The reachable duplicates are a re-entrant or
	# late emit, which is what the two probes below drive directly.
	var committed: Array = []
	r1.chamber_committed.connect(func(i, res): committed.append(res))
	var chamber: Node = r1.get_active()
	chamber.start_rig("eth")
	chamber.early_claim()
	_check("one commit after the chamber resolves (got %d)" % committed.size(),
		committed.size() == 1)
	var totals: Dictionary = r1.get_totals()
	# The principal is 1000, so any double-count shows up as >1000 banked.
	_check("totals were not inflated by the duplicate (gold_awarded=%d, forfeited=%d)"
			% [totals["gold_awarded"], totals["gold_forfeited"]],
		int(totals["gold_awarded"]) + int(totals["gold_forfeited"]) == 1000)

	# A late duplicate arriving AFTER the segment advanced must also be ignored.
	# This is the case that keying the guard on `_segment` would have missed:
	# _advance_segment() has already moved on, so the stale payout would have
	# been filed under the next segment's index and paid out again.
	r1._on_chamber_cleared({
		"gold_awarded": 999, "gold_forfeited": 1,
		"diamonds_burned": 0, "vest_fraction": 1.0, "early": false,
	})
	_check("a post-advance stale chamber_cleared does NOT commit (got %d)" % committed.size(),
		committed.size() == 1)
	_check("stale duplicate did not inflate totals (gold_awarded=%d)" % r1.get_totals()["gold_awarded"],
		int(r1.get_totals()["gold_awarded"]) < 999)

	# White-box probe of the `_rewarded_chambers` branch specifically. The stale
	# probe above is caught by the `owner_segment < 0` branch, so restore the
	# owning-segment slot to prove the per-chamber flag independently blocks a
	# second payout for a chamber that has already paid.
	r1._chamber_segment = 0
	r1._on_chamber_cleared({
		"gold_awarded": 777, "gold_forfeited": 0,
		"diamonds_burned": 0, "vest_fraction": 1.0, "early": false,
	})
	_check("_rewarded_chambers blocks a re-payout for an already-paid chamber (got %d)"
			% committed.size(), committed.size() == 1)
	_check("re-payout attempt did not inflate totals (gold_awarded=%d)" % r1.get_totals()["gold_awarded"],
		int(r1.get_totals()["gold_awarded"]) < 777)
	r1.queue_free()

	# 9-11. Stale input: chamber verbs are no-ops in RUNNER mode and vice versa.
	var r2 := _mk(_plan_one())
	r2.start()
	_check("chamber_start_rig is a no-op during RUNNER mode", not r2.chamber_start_rig("eth"))
	_check("chamber_early_claim is a no-op during RUNNER mode", not r2.chamber_early_claim())
	_run(r2, 6.0)
	# Now in CHAMBER mode: runner verbs must not reach the chamber. If they
	# leaked through they would hit a missing method and crash the frame, so
	# surviving these calls with the chamber intact IS the assertion.
	r2.runner_jump()
	r2.runner_switch_lane_left()
	r2.runner_duck_start()
	_check("runner verbs during CHAMBER mode are safely ignored",
		r2.get_mode() == Ep2SessionRoot.Mode.CHAMBER and r2.get_active() is MinerShaftChamber)
	r2.queue_free()

	# 12-14. Resume position: cumulative distance must survive the chamber and
	#        keep climbing on the next segment, never restart at 0.
	var two_segments := _plan_one() + _plan_one()
	var r3 := _mk(two_segments)
	r3.start()
	_run(r3, 6.0)
	var banked: float = r3.get_total_distance()
	_check("distance is banked at chamber entry (%.1f >= 60)" % banked, banked >= 60.0)
	var c3: Node = r3.get_active()
	c3.start_rig("eth")
	c3.early_claim()          # resolves -> advances to segment 1
	_check("second segment starts in RUNNER mode", r3.get_mode() == Ep2SessionRoot.Mode.RUNNER)
	_check("total distance did NOT reset on the new segment (%.1f)" % r3.get_total_distance(),
		r3.get_total_distance() >= banked)
	_run(r3, 2.0)
	_check("total distance keeps climbing across segments (%.1f > %.1f)" % [r3.get_total_distance(), banked],
		r3.get_total_distance() > banked)
	r3.queue_free()

	# 15. The economy commit path actually writes, and writes the right split.
	var gm: Node = get_node_or_null("/root/GoldMineSystem")
	if gm:
		var gold0: int = int(gm.gold_balance) if "gold_balance" in gm else -1
		var pool0: int = int(gm.auction_gold_pool)
		var r4 := _mk(_plan_one(1000), true)   # commit_to_economy = TRUE here
		var committed4: Array = []
		r4.chamber_committed.connect(func(i, res): committed4.append(res))
		r4.start()
		_run(r4, 6.0)
		var c4: Node = r4.get_active()
		c4.start_rig("eth")
		# Clear the bear FIRST. Left alive it reaches the rig in ~4.4s and lands
		# a hit every 2s, so the player is dead ~8.4s in — well before a 22.5s
		# half-vest — and the chamber correctly resolves as FAILED with no
		# payout, which is not the path this test is trying to measure.
		for i in MinerShaftChamber.BEAR_HP:
			c4.shoot()
		_run(c4, MinerShaftChamber.VEST_SECONDS_FULL * 0.5)
		_check("player survived to the half-vest (health %d, vest %.2f)"
				% [c4.get_health(), c4.get_vest()],
			c4.get_health() > 0 and c4.get_vest() > 0.4)
		c4.early_claim()
		var res: Dictionary = committed4[0] if committed4.size() == 1 else {}
		var aw: int = int(res.get("gold_awarded", -1))
		var fo: int = int(res.get("gold_forfeited", -1))
		_check("early claim committed exactly one result", committed4.size() == 1)
		# The pool receives EXACTLY the unvested remainder — no more, no less.
		_check("auction_gold_pool gained exactly the forfeited remainder (%d -> %d, expected +%d)"
				% [pool0, int(gm.auction_gold_pool), fo],
			int(gm.auction_gold_pool) == pool0 + fo)
		if gold0 >= 0:
			# THE REGRESSION THIS TEST EXISTS FOR: the player must still HOLD the
			# GOLD they earned after the forfeit is routed. The first version of
			# the commit used gm.forfeit_to_auction(), which is a transfer out of
			# gold_balance (clamped to it), so this landed at exactly 0 — a
			# successful early claim paid the player nothing.
			_check("awarded GOLD was credited AND retained (%d -> %d, expected +%d)"
					% [gold0, int(gm.gold_balance), aw],
				int(gm.gold_balance) == gold0 + aw)
			_check("the player did not end the claim empty-handed (balance=%d)" % int(gm.gold_balance),
				int(gm.gold_balance) > 0)
		r4.queue_free()
	else:
		print("  [SKIP] GoldMineSystem autoload not present — commit path unverified")

	# 16. The zip-line beat is actually reachable inside the loop, and the run
	#     survives it — not just green in the runner's own isolated unit test.
	#     Stepping in small increments so the 20-32m window can't be skipped
	#     over by a coarse step (at RUN_SPEED 12 the window is ~1s wide).
	var r5 := _mk(_plan_one())
	r5.start()
	var saw_zip := false
	var zip_dist := 0.0
	var dt := 1.0 / 60.0
	for i in 360:                     # 6s: covers the 60m to the chamber
		r5.step(dt)
		var a: Node = r5.get_active()
		if a is RunnerGraybox and a.is_ziplining():
			saw_zip = true
			zip_dist = a.get_distance()
	_check("the zip-line segment is traversed during a real session (at %.1fm)" % zip_dist,
		saw_zip)
	_check("the session still reaches the chamber after ziplining",
		r5.get_mode() == Ep2SessionRoot.Mode.CHAMBER)
	r5.queue_free()

	print("EP2_SESSION_ROOT: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
