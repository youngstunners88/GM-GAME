extends Node
## Gate for the Gold Mine economy's value-conservation and name-matches-behavior
## invariants (skill: goldmine-economy-invariants).
##
## The economy is a free-to-play SIMULATION today — no real funds move. This
## gate exists because it is the value-accounting foundation that on-chain
## wiring will inherit: a conservation bug that is harmless in a simulation is
## a mint exploit the day it is connected to real value.
##
## Every assertion here was written FAILING-FIRST against the pre-fix code, so
## each one is proven to catch its bug rather than merely passing.
##
## Invariant classes (see SKILL.md):
##   I1 conservation · I2 name-matches-behavior · I3 clamp direction
##   I4 sign discipline · I5 untrusted caller input
##
## Run: .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless \
##        res://tests/goldmine_economy_invariants_test.tscn

var _fail: int = 0
var _gm: Node = null

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])

## Total simulated value that must be conserved by non-mint/non-burn ops.
## Deliberately sums the GOLD-denominated ledgers only — mixing XAUT/wBTC/shares
## into one scalar would hide a bug by letting one unit offset another.
func _gold_total() -> int:
	return int(_gm.gold_balance) + int(_gm.auction_gold_pool)

func _snap() -> Dictionary:
	return {
		"gold": int(_gm.gold_balance),
		"pool": int(_gm.auction_gold_pool),
		"diamonds": int(_gm.diamonds_balance),
		"wbtc": int(_gm.wbtc_balance),
		"xaut": int(_gm.xaut_balance),
		"shares": int(_gm.fort_knox_shares),
		"dshares": int(_gm.diamond_shares),
		"blaze": int(_gm.blaze_diamonds),
		"life_mined": int(_gm.lifetime_gold_mined),
		"life_burned": int(_gm.lifetime_diamonds_burned),
		"gold_total": _gold_total(),
	}

## Reset between cases — GoldMineSystem is an autoload singleton and leaks
## state across cases otherwise.
func _reset() -> void:
	_gm.reset_session()

func _ready() -> void:
	await get_tree().process_frame
	print("GOLDMINE ECONOMY INVARIANTS:")

	_gm = get_node_or_null("/root/GoldMineSystem")
	if _gm == null:
		print("  [FAIL] GoldMineSystem autoload not present — cannot audit")
		get_tree().quit(1)
		return

	_t_sign_discipline()
	_t_award_wbtc_pool_contract()
	_t_melt_bonus_from_constants()
	_t_melt_conservation()
	_t_forfeit_name_matches_behavior()
	_t_settle_auction_bounds()
	_t_stake_guards()
	_t_vesting_reconciliation()
	_t_save_load_validation()
	_t_burn_ledger()

	print("GOLDMINE_ECONOMY_INVARIANTS: %s" % ("ALL PASS" if _fail == 0 else "%d FAILURE(S)" % _fail))
	get_tree().quit(_fail)

# --- I4: sign discipline -----------------------------------------------------
# A negative amount through an unguarded `-=` is a MINT. Every public
# value-moving entry point must refuse or clamp negatives, and no lifetime
# counter may ever decrease.

func _t_sign_discipline() -> void:
	print(" I4 sign discipline:")

	_reset()
	_gm.mine_gold(-500)
	_check("mine_gold(-500) does not reduce gold (got %d)" % _gm.gold_balance,
		int(_gm.gold_balance) >= 0)
	_check("mine_gold(-500) does not reduce lifetime_gold_mined (got %d)" % _gm.lifetime_gold_mined,
		int(_gm.lifetime_gold_mined) >= 0)

	_reset()
	_gm.collect_diamonds(-100)
	_check("collect_diamonds(-100) does not reduce diamonds (got %d)" % _gm.diamonds_balance,
		int(_gm.diamonds_balance) >= 0)
	_check("collect_diamonds(-100) does not reduce lifetime burn (got %d)" % _gm.lifetime_diamonds_burned,
		int(_gm.lifetime_diamonds_burned) >= 0)

	_reset()
	_gm.award_wbtc(-100, "short")
	_check("award_wbtc(-100) does not reduce wbtc (got %d)" % _gm.wbtc_balance,
		int(_gm.wbtc_balance) >= 0)

	_reset()
	var before_melt: Dictionary = _snap()
	_gm.melt_gold(-100, 50)
	_check("melt_gold(-100, 50) mints no GOLD (%d -> %d)" % [before_melt["gold"], _gm.gold_balance],
		int(_gm.gold_balance) <= int(before_melt["gold"]))
	_check("melt_gold(-100, 50) mints no shares (%d -> %d)" % [before_melt["shares"], _gm.fort_knox_shares],
		int(_gm.fort_knox_shares) <= int(before_melt["shares"]))

	_reset()
	var before_ff: Dictionary = _snap()
	_gm.forfeit_to_auction(-250)
	_check("forfeit_to_auction(-250) mints no GOLD (%d -> %d)" % [before_ff["gold"], _gm.gold_balance],
		int(_gm.gold_balance) <= int(before_ff["gold"]))
	_check("forfeit_to_auction(-250) never drives the pool negative (got %d)" % _gm.auction_gold_pool,
		int(_gm.auction_gold_pool) >= 0)

	_reset()
	var before_stake: Dictionary = _snap()
	_gm.stake_in_fort_knox(-1000, 288)
	_check("stake_in_fort_knox(-1000) mints no GOLD (%d -> %d)" % [before_stake["gold"], _gm.gold_balance],
		int(_gm.gold_balance) <= int(before_stake["gold"]))
	_check("stake_in_fort_knox(-1000) never yields negative shares (got %d)" % _gm.fort_knox_shares,
		int(_gm.fort_knox_shares) >= 0)

	_reset()
	_gm.distribute_treasury_revenue(-10000)
	_check("distribute_treasury_revenue(-10000) mints nothing (xaut=%d pool=%d)"
			% [_gm.xaut_balance, _gm.auction_gold_pool],
		int(_gm.xaut_balance) >= 0 and int(_gm.auction_gold_pool) >= 0)

# --- I2/I3: award_wbtc pool contract ----------------------------------------
# The docstring says the pool param "chooses 60/40 split". An unrecognised pool
# must NOT fall through to an unscaled 100% award — that pays MORE than either
# legitimate pool.

func _t_award_wbtc_pool_contract() -> void:
	print(" I2 award_wbtc pool contract:")

	_reset(); _gm.award_wbtc(100, "short")
	var short_amt: int = int(_gm.wbtc_balance)
	_check("short pool pays 60%% of 100 (got %d)" % short_amt, short_amt == 60)

	_reset(); _gm.award_wbtc(100, "long")
	var long_amt: int = int(_gm.wbtc_balance)
	_check("long pool pays 40%% of 100 (got %d)" % long_amt, long_amt == 40)

	_reset(); _gm.award_wbtc(100, "not-a-pool")
	var bogus_amt: int = int(_gm.wbtc_balance)
	_check("unknown pool never pays more than the largest valid pool (got %d, short=%d)"
			% [bogus_amt, short_amt],
		bogus_amt <= short_amt)

# --- I2: melt bonus derives from the constants, not a magic number -----------

func _t_melt_bonus_from_constants() -> void:
	print(" I2 melt bonus vs constants:")
	_reset()
	_gm.mine_gold(3000)
	# Melt at exactly MAX_MELT_RATIO x the stake -> bonus must equal
	# MAX_MELT_BONUS_PCT exactly, or the hardcoded multiplier has desynced
	# from the constants it is supposed to express.
	var staked: int = 1000
	var bonus: float = _gm.melt_gold(staked * int(_gm.MAX_MELT_RATIO), staked)
	_check("melt at MAX_MELT_RATIO yields MAX_MELT_BONUS_PCT (got %.2f, expected %.2f)"
			% [bonus, float(_gm.MAX_MELT_BONUS_PCT)],
		is_equal_approx(bonus, float(_gm.MAX_MELT_BONUS_PCT)))

	# And the ratio must be capped: melting far beyond the cap earns no more.
	_reset()
	_gm.mine_gold(100000)
	var over: float = _gm.melt_gold(staked * 50, staked)
	_check("melting far above the cap earns no more than the cap (got %.2f)" % over,
		over <= float(_gm.MAX_MELT_BONUS_PCT) + 0.001)

# --- I1: melt conservation ---------------------------------------------------

func _t_melt_conservation() -> void:
	print(" I1 melt conservation:")
	_reset()
	_gm.mine_gold(1000)
	var pre: Dictionary = _snap()
	var melted: int = 400
	_gm.melt_gold(melted, 500)
	# melt is a designated BURN of `melted` GOLD: the balance drops by exactly
	# that much and the pool is untouched.
	_check("melt burns exactly the melted amount (%d -> %d, expected -%d)"
			% [pre["gold"], _gm.gold_balance, melted],
		int(_gm.gold_balance) == int(pre["gold"]) - melted)
	_check("melt does not touch the auction pool (%d -> %d)" % [pre["pool"], _gm.auction_gold_pool],
		int(_gm.auction_gold_pool) == int(pre["pool"]))

	# Over-melt must be refused outright, not partially applied.
	_reset()
	_gm.mine_gold(100)
	var pre2: Dictionary = _snap()
	var r: float = _gm.melt_gold(100000, 500)
	_check("over-melt is refused and changes nothing (bonus=%.2f, gold %d -> %d)"
			% [r, pre2["gold"], _gm.gold_balance],
		is_zero_approx(r) and int(_gm.gold_balance) == int(pre2["gold"]))

# --- I1/I2: forfeit_to_auction ----------------------------------------------
# The archetype. This function is a TRANSFER out of the player's balance, not a
# pool credit. Conservation must hold exactly, and the clamp must never destroy
# value.

func _t_forfeit_name_matches_behavior() -> void:
	print(" I1/I2 forfeit_to_auction:")
	_reset()
	_gm.mine_gold(1000)
	var pre: Dictionary = _snap()
	_gm.forfeit_to_auction(400)
	_check("forfeit conserves GOLD total (%d -> %d)" % [pre["gold_total"], _gold_total()],
		_gold_total() == int(pre["gold_total"]))
	_check("forfeit credits the pool by exactly the forfeited amount (%d -> %d)"
			% [pre["pool"], _gm.auction_gold_pool],
		int(_gm.auction_gold_pool) == int(pre["pool"]) + 400)

	# The clamp: forfeiting more than held moves everything the player has and
	# destroys nothing. This is the clamp that silently swallowed Episode 2's
	# early-claim payout when it was called for GOLD never held.
	_reset()
	_gm.mine_gold(300)
	var pre2: Dictionary = _snap()
	_gm.forfeit_to_auction(999999)
	_check("over-forfeit conserves total (%d -> %d)" % [pre2["gold_total"], _gold_total()],
		_gold_total() == int(pre2["gold_total"]))
	_check("over-forfeit moves exactly the held amount, no more (pool %d -> %d)"
			% [pre2["pool"], _gm.auction_gold_pool],
		int(_gm.auction_gold_pool) == int(pre2["pool"]) + int(pre2["gold"]))

# --- I5: settle_auction bounds ----------------------------------------------
# `user_contribution / total_pool` is caller-supplied and on a web export that
# means attacker-supplied. It must be bounded to [0, 1].

func _t_settle_auction_bounds() -> void:
	print(" I5 settle_auction bounds:")

	_reset()
	_gm.mine_gold(1000)
	_gm.forfeit_to_auction(1000)
	var honest: int = _gm.settle_auction(1000, 1000)   # full share

	_reset()
	_gm.mine_gold(1000)
	_gm.forfeit_to_auction(1000)
	var cheat: int = _gm.settle_auction(1000000, 1)    # multiplier 1e6 if unbounded
	_check("contribution > pool cannot mint more XAUT than a full share (honest=%d, cheat=%d)"
			% [honest, cheat],
		cheat <= honest)

	_reset()
	_gm.mine_gold(1000)
	_gm.forfeit_to_auction(1000)
	var neg: int = _gm.settle_auction(-1000, 1000)
	_check("negative contribution wins no XAUT (got %d)" % neg, neg <= 0)
	_check("negative contribution leaves a non-negative balance (got %d)" % _gm.xaut_balance,
		int(_gm.xaut_balance) >= 0)

# --- I3: stake guard symmetry ------------------------------------------------
# stake_diamonds() clamps correctly; stake_in_fort_knox() historically guarded
# only the upper bound. Sibling functions must be equally hardened.

func _t_stake_guards() -> void:
	print(" I3 stake guard symmetry:")

	_reset()
	_gm.mine_gold(1000)
	var s_over: int = _gm.stake_in_fort_knox(999999, 288)
	_check("fort knox refuses a stake above holdings (shares=%d)" % s_over, s_over == 0)

	_reset()
	_gm.collect_diamonds(1000)
	var d_over: int = _gm.stake_diamonds(999999, 288)
	var held_after: int = int(_gm.diamonds_balance)
	_check("stake_diamonds clamps to holdings and never over-stakes (shares=%d, held=%d)"
			% [d_over, held_after],
		held_after >= 0 and d_over >= 0)

	# Term bonus: 288 days = base, 2888 days = 2x (MAX_TERM_BONUS_PCT = 100%).
	_reset(); _gm.mine_gold(1000)
	var base_shares: int = _gm.stake_in_fort_knox(1000, 288)
	_reset(); _gm.mine_gold(1000)
	var max_shares: int = _gm.stake_in_fort_knox(1000, 2888)
	_check("288d yields base shares (got %d for 1000 staked)" % base_shares, base_shares == 1000)
	_check("2888d yields exactly 2x base (got %d, base %d)" % [max_shares, base_shares],
		max_shares == base_shares * 2)

	# Beyond the max lock the bonus must not keep growing.
	_reset(); _gm.mine_gold(1000)
	var over_shares: int = _gm.stake_in_fort_knox(1000, 99999)
	_check("lock beyond 2888d earns no more than the cap (got %d, cap %d)"
			% [over_shares, max_shares],
		over_shares <= max_shares)

# --- Vesting reconciliation (white paper) ------------------------------------

func _t_vesting_reconciliation() -> void:
	print(" vesting reconciliation:")
	_check("MINER_VESTING_DAYS is 100 (got %d)" % _gm.MINER_VESTING_DAYS,
		int(_gm.MINER_VESTING_DAYS) == 100)
	_check("DIAMOND_BURN_PCT is 20%% (got %.2f)" % _gm.DIAMOND_BURN_PCT,
		is_equal_approx(float(_gm.DIAMOND_BURN_PCT), 0.20))

	# 1%/day linear over the full term reconciles to the whole principal.
	var principal: int = 10000
	var total: int = 0
	for day in int(_gm.MINER_VESTING_DAYS):
		total += principal / int(_gm.MINER_VESTING_DAYS)
	_check("100 days at 1%%/day reconciles to the principal (got %d of %d)" % [total, principal],
		total == principal)

	# The 20% burn keeps exactly 80%.
	_reset()
	var kept: int = _gm.collect_diamonds(1000)
	_check("collect_diamonds(1000) keeps 800 and burns 200 (kept=%d burned=%d)"
			% [kept, _gm.lifetime_diamonds_burned],
		kept == 800 and int(_gm.lifetime_diamonds_burned) == 200)

# --- Trust boundary: save/load validation ------------------------------------
# load_save_data() assigns balances straight from an untrusted dict. On a web
# export the save is player-editable, so this bypasses every function-level
# guard the economy has. It must at minimum refuse impossible values.

func _t_save_load_validation() -> void:
	print(" trust boundary — save/load validation:")
	_reset()
	_gm.load_save_data({
		"gold": -999999,
		"diamonds": -50,
		"wbtc": -1,
		"xaut": -1,
		"fort_knox_shares": -22000,
		"gold_certificates": -5,
		"diamond_shares": -10,
		"blaze_diamonds": -10,
		"lifetime_gold_mined": -1,
		"lifetime_diamonds_burned": -1,
	})
	_check("a tampered save cannot set a negative GOLD balance (got %d)" % _gm.gold_balance,
		int(_gm.gold_balance) >= 0)
	_check("a tampered save cannot set negative diamonds (got %d)" % _gm.diamonds_balance,
		int(_gm.diamonds_balance) >= 0)
	_check("a tampered save cannot set negative shares (got %d)" % _gm.fort_knox_shares,
		int(_gm.fort_knox_shares) >= 0)
	_check("a tampered save cannot set negative certificates (got %d)" % _gm.gold_certificates,
		int(_gm.gold_certificates) >= 0)
	_check("a tampered save cannot set negative lifetime counters (mined=%d burned=%d)"
			% [_gm.lifetime_gold_mined, _gm.lifetime_diamonds_burned],
		int(_gm.lifetime_gold_mined) >= 0 and int(_gm.lifetime_diamonds_burned) >= 0)

	# Blaze diamonds have a hard stack limit; a save must not exceed it.
	_reset()
	_gm.load_save_data({"blaze_diamonds": 999999})
	_check("a tampered save cannot exceed BLAZE_DIAMOND_STACK_LIMIT (got %d, limit %d)"
			% [_gm.blaze_diamonds, _gm.BLAZE_DIAMOND_STACK_LIMIT],
		int(_gm.blaze_diamonds) <= int(_gm.BLAZE_DIAMOND_STACK_LIMIT))

# --- I1: burn ledger ---------------------------------------------------------
# settle_auction() zeroes the pool. Without a counter recording what was
# destroyed, conservation across settlement is unverifiable by construction.

func _t_burn_ledger() -> void:
	print(" I1 burn ledger:")
	_reset()
	_gm.mine_gold(1000)
	_gm.forfeit_to_auction(1000)
	var pooled: int = int(_gm.auction_gold_pool)
	var settled_before: int = int(_gm.lifetime_gold_settled) if "lifetime_gold_settled" in _gm else -1
	_gm.settle_auction(1000, 1000)
	_check("auction settlement zeroes the pool (got %d)" % _gm.auction_gold_pool,
		int(_gm.auction_gold_pool) == 0)
	if settled_before >= 0:
		_check("settlement records the destroyed GOLD in a burn ledger (%d -> %d, pooled %d)"
				% [settled_before, _gm.lifetime_gold_settled, pooled],
			int(_gm.lifetime_gold_settled) == settled_before + pooled)
	else:
		_check("a burn ledger exists so settlement conservation is verifiable "
			+ "(lifetime_gold_settled missing)", false,
			"settle_auction destroys GOLD with no counter recording it")
