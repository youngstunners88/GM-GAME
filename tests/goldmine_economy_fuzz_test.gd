extends Node
## Seeded economy fuzz gate (skill: deterministic-stress-harness).
##
## Drives randomized-but-bounded sequences across EVERY value-moving function in
## GoldMineSystem — including the hostile end of each domain (negatives, zero,
## amounts above holdings, int extremes) — and re-asserts the structural
## invariants after every single operation.
##
## Bounded in MAGNITUDE, never bounded to VALID values only: the sign-discipline
## and untrusted-input bugs this suite exists to catch live precisely in the
## inputs a "sensible" fuzzer would never generate.
##
## Determinism contract: the seed is fixed and committed, so CI replays the
## identical sequence every run. On any violation the gate prints a REPRO line
## carrying the seed, the step index and the exact call — enough to replay it
## and promote it to a permanent named case.
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/goldmine_economy_fuzz_test.tscn

## Fixed, committed seed. Randomizing this turns a regression gate into a flaky
## one — if you want a different sequence, add a second named seed below.
const SEED: int = 20260910
const STEPS: int = 4000

var _rng := RandomNumberGenerator.new()
var _gm: Node = null
var _fail: int = 0
var _violations: Array = []

## Monotonic counters: these may never decrease, under any operation sequence.
var _last_life_mined: int = 0
var _last_life_burned: int = 0
var _last_life_settled: int = 0
var _last_certs: int = 0

func _violation(step: int, op: String, why: String) -> void:
	_fail += 1
	if _violations.size() < 12:   # cap the noise; the first few are what matter
		_violations.append("REPRO: seed=%d step=%d op=%s\n         -> %s\n         state: %s"
			% [SEED, step, op, why, _state_str()])

func _state_str() -> String:
	return "gold=%d pool=%d diamonds=%d wbtc=%d xaut=%d shares=%d dshares=%d blaze=%d certs=%d mined=%d burned=%d settled=%d" % [
		_gm.gold_balance, _gm.auction_gold_pool, _gm.diamonds_balance, _gm.wbtc_balance,
		_gm.xaut_balance, _gm.fort_knox_shares, _gm.diamond_shares, _gm.blaze_diamonds,
		_gm.gold_certificates, _gm.lifetime_gold_mined, _gm.lifetime_diamonds_burned,
		_gm.lifetime_gold_settled,
	]

## Structural invariants that must hold after EVERY operation, whatever the
## sequence. Nothing here depends on which op just ran — that is the point.
func _assert_invariants(step: int, op: String) -> void:
	if int(_gm.gold_balance) < 0:
		_violation(step, op, "gold_balance went negative (I1/I4: value created or destroyed)")
	if int(_gm.auction_gold_pool) < 0:
		_violation(step, op, "auction_gold_pool went negative")
	if int(_gm.diamonds_balance) < 0:
		_violation(step, op, "diamonds_balance went negative")
	if int(_gm.wbtc_balance) < 0:
		_violation(step, op, "wbtc_balance went negative")
	if int(_gm.xaut_balance) < 0:
		_violation(step, op, "xaut_balance went negative")
	if int(_gm.fort_knox_shares) < 0:
		_violation(step, op, "fort_knox_shares went negative")
	if int(_gm.diamond_shares) < 0:
		_violation(step, op, "diamond_shares went negative")
	if int(_gm.gold_certificates) < 0:
		_violation(step, op, "gold_certificates went negative")

	# Blaze diamonds are a bounded stack by design.
	var blaze: int = int(_gm.blaze_diamonds)
	if blaze < 0 or blaze > int(_gm.BLAZE_DIAMOND_STACK_LIMIT):
		_violation(step, op, "blaze_diamonds %d outside [0, %d]" % [blaze, _gm.BLAZE_DIAMOND_STACK_LIMIT])

	# Lifetime counters are monotonic by definition.
	if int(_gm.lifetime_gold_mined) < _last_life_mined:
		_violation(step, op, "lifetime_gold_mined DECREASED %d -> %d"
			% [_last_life_mined, _gm.lifetime_gold_mined])
	if int(_gm.lifetime_diamonds_burned) < _last_life_burned:
		_violation(step, op, "lifetime_diamonds_burned DECREASED %d -> %d"
			% [_last_life_burned, _gm.lifetime_diamonds_burned])
	if int(_gm.lifetime_gold_settled) < _last_life_settled:
		_violation(step, op, "lifetime_gold_settled DECREASED %d -> %d"
			% [_last_life_settled, _gm.lifetime_gold_settled])
	if int(_gm.gold_certificates) < _last_certs:
		_violation(step, op, "gold_certificates DECREASED %d -> %d"
			% [_last_certs, _gm.gold_certificates])

	_last_life_mined = int(_gm.lifetime_gold_mined)
	_last_life_burned = int(_gm.lifetime_diamonds_burned)
	_last_life_settled = int(_gm.lifetime_gold_settled)
	_last_certs = int(_gm.gold_certificates)

## Deliberately hostile amount generator: roughly a third of draws are invalid
## (negative / zero / absurd), because that is where the bugs were.
func _amt() -> int:
	var roll: int = _rng.randi_range(0, 9)
	match roll:
		0: return -_rng.randi_range(1, 100000)      # negative
		1: return 0                                  # zero
		2: return _rng.randi_range(1, 1000000000)    # far above any holding
		_: return _rng.randi_range(1, 5000)          # plausible

func _days() -> int:
	var roll: int = _rng.randi_range(0, 5)
	match roll:
		0: return -_rng.randi_range(1, 5000)
		1: return 0
		2: return _rng.randi_range(2889, 100000)     # beyond the 2,888-day cap
		_: return _rng.randi_range(288, 2888)

func _ready() -> void:
	await get_tree().process_frame
	print("GOLDMINE ECONOMY FUZZ (seed=%d, steps=%d):" % [SEED, STEPS])

	_gm = get_node_or_null("/root/GoldMineSystem")
	if _gm == null:
		print("  [FAIL] GoldMineSystem autoload not present")
		get_tree().quit(1)
		return

	_rng.seed = SEED
	_gm.reset_session()
	_last_life_mined = 0
	_last_life_burned = 0
	_last_life_settled = 0
	_last_certs = 0

	var ops := [
		"mine_gold", "collect_diamonds", "award_wbtc", "melt_gold",
		"forfeit_to_auction", "settle_auction", "stake_in_fort_knox",
		"stake_diamonds", "add_blaze_diamonds", "crush_blaze_diamonds",
		"distribute_treasury_revenue", "on_player_death",
	]
	var counts := {}
	for o in ops:
		counts[o] = 0

	for step in STEPS:
		var op: String = ops[_rng.randi_range(0, ops.size() - 1)]
		counts[op] = int(counts[op]) + 1
		var desc: String = op
		match op:
			"mine_gold":
				var a := _amt(); desc = "mine_gold(%d)" % a
				_gm.mine_gold(a)
			"collect_diamonds":
				var a := _amt(); desc = "collect_diamonds(%d)" % a
				_gm.collect_diamonds(a)
			"award_wbtc":
				var a := _amt()
				var pools := ["short", "long", "bogus", ""]
				var pool: String = pools[_rng.randi_range(0, pools.size() - 1)]
				desc = "award_wbtc(%d, '%s')" % [a, pool]
				_gm.award_wbtc(a, pool)
			"melt_gold":
				var a := _amt(); var st := _amt()
				desc = "melt_gold(%d, %d)" % [a, st]
				_gm.melt_gold(a, st)
			"forfeit_to_auction":
				var a := _amt(); desc = "forfeit_to_auction(%d)" % a
				_gm.forfeit_to_auction(a)
			"settle_auction":
				var c := _amt(); var t := _amt()
				desc = "settle_auction(%d, %d)" % [c, t]
				_gm.settle_auction(c, t)
			"stake_in_fort_knox":
				var a := _amt(); var d := _days()
				desc = "stake_in_fort_knox(%d, %d)" % [a, d]
				_gm.stake_in_fort_knox(a, d)
			"stake_diamonds":
				var a := _amt(); var d := _days()
				desc = "stake_diamonds(%d, %d)" % [a, d]
				_gm.stake_diamonds(a, d)
			"add_blaze_diamonds":
				var n := _rng.randi_range(-5, 10)
				desc = "add_blaze_diamonds(%d)" % n
				_gm.add_blaze_diamonds(n)
			"crush_blaze_diamonds":
				var n := _rng.randi_range(-5, 30)
				desc = "crush_blaze_diamonds(%d)" % n
				_gm.crush_blaze_diamonds(n)
			"distribute_treasury_revenue":
				var r := _amt()
				desc = "distribute_treasury_revenue(%d)" % r
				_gm.distribute_treasury_revenue(r)
			"on_player_death":
				desc = "on_player_death()"
				_gm.on_player_death()

		_assert_invariants(step, desc)

	print("  ops exercised: %d distinct, %d calls" % [ops.size(), STEPS])
	if _fail == 0:
		print("  [PASS] %d fuzzed operations, no invariant violated" % STEPS)
	else:
		print("  [FAIL] %d invariant violation(s):" % _fail)
		for v in _violations:
			print("    " + v)
		if _fail > _violations.size():
			print("    ... and %d more (capped)" % (_fail - _violations.size()))

	# Conservation spot-check on a clean, deterministic sequence: a mine then a
	# full forfeit must move value, never create or destroy it.
	_gm.reset_session()
	_gm.mine_gold(12345)
	var total_before: int = int(_gm.gold_balance) + int(_gm.auction_gold_pool)
	_gm.forfeit_to_auction(12345)
	var total_after: int = int(_gm.gold_balance) + int(_gm.auction_gold_pool)
	if total_before != total_after:
		_fail += 1
		print("  [FAIL] conservation broken across mine->forfeit (%d -> %d)"
			% [total_before, total_after])
	else:
		print("  [PASS] conservation holds across mine->forfeit (%d)" % total_after)

	_gm.reset_session()
	print("GOLDMINE_ECONOMY_FUZZ: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)
