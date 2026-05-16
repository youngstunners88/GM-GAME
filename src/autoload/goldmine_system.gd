extends Node
## GoldMine protocol system — translates the GoldMine whitepaper economy into game mechanics.
## Tracks GOLD, Diamonds, wBTC, XAUT and implements protocol-inspired bonuses.
##
## Whitepaper reference: see /tmp/whitepaper.txt or design/goldmine_protocol_design.md
##
## In-game mappings:
##   GOLD     = mined via gold_token collectibles (1% per "day" / per collectible)
##   Diamonds = diamond_shard powerup (20% burn applied on pickup)
##   wBTC     = Fort Knox reward (paid out on level milestones — 60% mid, 40% end)
##   XAUT     = boss-defeat auction payout (pro-rata to GOLD held vs. forfeited)

signal gold_changed(new_amount: int)
signal diamonds_changed(new_amount: int)
signal wbtc_changed(new_amount: int)
signal xaut_changed(new_amount: int)
signal melt_triggered(melted_gold: int, bonus_pct: float)
signal auction_complete(xaut_won: int, multiplier: float)
signal certificate_earned(count: int)

# Whitepaper constants
const DIAMOND_BURN_PCT: float = 0.20             # 20% Diamond burn on mint
const MAX_TERM_BONUS_PCT: float = 1.00           # 100% bonus at max stake length
const MAX_MELT_RATIO: int = 3                    # Burn up to 3× staked GOLD
const MAX_MELT_BONUS_PCT: float = 9.00           # 900% melt bonus at 3× melt
const FORT_KNOX_SHORT_POOL_PCT: float = 0.60     # 60% of rewards on day 88
const FORT_KNOX_LONG_POOL_PCT: float = 0.40      # 40% of rewards on day 288
const TREASURY_NFT_PCT: float = 0.50             # 50% to Gold Claim Cert holders
const TREASURY_AUCTION_PCT: float = 0.20         # 20% to weekly auction supplement
const TREASURY_SWF_PCT: float = 0.20             # 20% reinvested in Sovereign Wealth Fund
const TREASURY_FOUNDER_PCT: float = 0.10         # 10% to founder/operations
const STOCKPILE_LP_MATCH_PCT: float = 0.10       # 10% of BTC mining → wBTC for LP match
const RESERVE_FORFEIT_SPLIT: float = 0.50        # 50/50 melt vs. Strategic Reserve
const CERT_SHARES_REQUIRED: int = 22000          # Fort Knox shares per Gold Cert
const CERT_PRICE_XAUT: float = 0.5               # XAUT cost per Gold Cert
const MINER_VESTING_DAYS: int = 100              # 100-day GOLD miner

# In-game state
var gold_balance: int = 0
var diamonds_balance: int = 0
var wbtc_balance: int = 0
var xaut_balance: int = 0
var fort_knox_shares: int = 0
var gold_certificates: int = 0

# Per-level forfeit pool — feeds boss auction payout
var auction_gold_pool: int = 0
var lifetime_gold_mined: int = 0
var lifetime_diamonds_burned: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Mine GOLD by collecting gold_token (analogue to starting a miner).
## Each token represents "vested" gold from a completed miner.
func mine_gold(amount: int) -> void:
	gold_balance += amount
	lifetime_gold_mined += amount
	gold_changed.emit(gold_balance)
	GameManager.add_score(amount * 25)

## Collect Diamonds — auto-applies the permanent 20% burn from the whitepaper.
## Returns the net Diamonds added after burn.
func collect_diamonds(raw_amount: int) -> int:
	var burned: int = int(round(raw_amount * DIAMOND_BURN_PCT))
	var kept: int = raw_amount - burned
	diamonds_balance += kept
	lifetime_diamonds_burned += burned
	diamonds_changed.emit(diamonds_balance)
	return kept

## Award wBTC — represents Fort Knox staking payout.
## Pool param chooses 60/40 split: "short" (day 88) or "long" (day 288).
func award_wbtc(amount: int, pool: String = "short") -> void:
	var scaled: int = amount
	if pool == "short":
		scaled = int(round(amount * FORT_KNOX_SHORT_POOL_PCT))
	elif pool == "long":
		scaled = int(round(amount * FORT_KNOX_LONG_POOL_PCT))
	wbtc_balance += scaled
	wbtc_changed.emit(wbtc_balance)
	GameManager.add_score(scaled * 10)

## Melt GOLD — voluntary burn to gain melt bonus multiplier (whitepaper Fort Knox).
## Returns the bonus % earned (0.5 = 50%, 9.0 = 900%).
func melt_gold(amount_to_melt: int, staked_amount: int) -> float:
	if amount_to_melt > gold_balance:
		return 0.0
	if staked_amount <= 0:
		return 0.0
	gold_balance -= amount_to_melt
	var melt_ratio: float = float(amount_to_melt) / float(staked_amount)
	melt_ratio = clampf(melt_ratio, 0.0, float(MAX_MELT_RATIO))
	# Linear interpolation: 1× melt = 100% bonus, 3× melt = 900% bonus
	var bonus_pct: float = melt_ratio * 3.0
	fort_knox_shares += int(staked_amount * (1.0 + bonus_pct))
	gold_changed.emit(gold_balance)
	melt_triggered.emit(amount_to_melt, bonus_pct)
	return bonus_pct

## Forfeit GOLD to auction pool (whitepaper Gold Rush Auction).
## 50% of remainder after LP match goes to Strategic Reserve, 50% is melted.
func forfeit_to_auction(amount: int) -> void:
	if amount > gold_balance:
		amount = gold_balance
	gold_balance -= amount
	auction_gold_pool += amount
	gold_changed.emit(gold_balance)

## Settle the weekly Gold Rush Auction — call at boss defeat or level transition.
## XAUT is awarded pro-rata based on user's contribution vs. total pool.
func settle_auction(user_contribution: int, total_pool: int) -> int:
	if total_pool <= 0 or user_contribution <= 0:
		auction_complete.emit(0, 0.0)
		return 0
	var multiplier: float = float(user_contribution) / float(total_pool)
	# Base XAUT pool scales with auction_gold_pool — 1 GOLD = 0.1 XAUT base reward
	var base_xaut: int = int(round(auction_gold_pool * 0.1))
	var xaut_won: int = int(round(base_xaut * multiplier))
	xaut_balance += xaut_won
	xaut_changed.emit(xaut_balance)
	GameManager.add_score(xaut_won * 100)
	auction_complete.emit(xaut_won, multiplier)
	# Reset weekly pool — whitepaper specifies no carry-over
	auction_gold_pool = 0
	return xaut_won

## Stake GOLD into Fort Knox vault — generates shares for Gold Claim Cert eligibility.
## Returns total shares (with max term bonus if commitment is full 2,888 days).
func stake_in_fort_knox(amount: int, days_committed: int) -> int:
	if amount > gold_balance:
		return 0
	gold_balance -= amount
	# Linear scale: 288 days = base shares, 2,888 days = 2× shares (100% max term bonus)
	var term_ratio: float = clampf((float(days_committed) - 288.0) / 2600.0, 0.0, 1.0)
	var shares: int = int(round(amount * (1.0 + (term_ratio * MAX_TERM_BONUS_PCT))))
	fort_knox_shares += shares
	gold_changed.emit(gold_balance)
	# Check if any Gold Claim Certs unlocked
	_check_certificates()
	return shares

## Internal: check if Fort Knox shares cross the 22,000-per-Cert threshold.
func _check_certificates() -> void:
	var new_certs: int = fort_knox_shares / CERT_SHARES_REQUIRED
	if new_certs > gold_certificates:
		var earned: int = new_certs - gold_certificates
		gold_certificates = new_certs
		certificate_earned.emit(earned)
		GameManager.add_score(earned * 1000)

## Treasury distribution — splits incoming revenue per whitepaper percentages.
## Used when boss defeats trigger "Treasury revenue distribution" cinematic.
func distribute_treasury_revenue(total_revenue: int) -> Dictionary:
	var nft_share: int = int(round(total_revenue * TREASURY_NFT_PCT))
	var auction_share: int = int(round(total_revenue * TREASURY_AUCTION_PCT))
	var swf_share: int = int(round(total_revenue * TREASURY_SWF_PCT))
	var founder_share: int = int(round(total_revenue * TREASURY_FOUNDER_PCT))
	xaut_balance += nft_share
	auction_gold_pool += auction_share
	xaut_changed.emit(xaut_balance)
	return {
		"nft": nft_share,
		"auction": auction_share,
		"swf": swf_share,
		"founder": founder_share
	}

## Reset transient state on player death — gold balance is forfeited (whitepaper miner forfeiture).
func on_player_death() -> void:
	# Whitepaper: early claim forfeits unvested portion. Translate to losing half of unsaved gold.
	var forfeited: int = gold_balance / 2
	gold_balance -= forfeited
	auction_gold_pool += forfeited
	gold_changed.emit(gold_balance)

## Reset all state on new game.
func reset_session() -> void:
	gold_balance = 0
	diamonds_balance = 0
	wbtc_balance = 0
	xaut_balance = 0
	fort_knox_shares = 0
	gold_certificates = 0
	auction_gold_pool = 0
	lifetime_gold_mined = 0
	lifetime_diamonds_burned = 0

## Save snapshot for persistence layer.
func get_save_data() -> Dictionary:
	return {
		"gold": gold_balance,
		"diamonds": diamonds_balance,
		"wbtc": wbtc_balance,
		"xaut": xaut_balance,
		"fort_knox_shares": fort_knox_shares,
		"gold_certificates": gold_certificates,
		"lifetime_gold_mined": lifetime_gold_mined,
		"lifetime_diamonds_burned": lifetime_diamonds_burned,
	}

func load_save_data(data: Dictionary) -> void:
	gold_balance = int(data.get("gold", 0))
	diamonds_balance = int(data.get("diamonds", 0))
	wbtc_balance = int(data.get("wbtc", 0))
	xaut_balance = int(data.get("xaut", 0))
	fort_knox_shares = int(data.get("fort_knox_shares", 0))
	gold_certificates = int(data.get("gold_certificates", 0))
	lifetime_gold_mined = int(data.get("lifetime_gold_mined", 0))
	lifetime_diamonds_burned = int(data.get("lifetime_diamonds_burned", 0))
	gold_changed.emit(gold_balance)
	diamonds_changed.emit(diamonds_balance)
	wbtc_changed.emit(wbtc_balance)
	xaut_changed.emit(xaut_balance)
