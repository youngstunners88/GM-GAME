# GoldMine Protocol — Game Mechanic Translation

**Source**: GoldMine whitepaper (v2 — May 2026)  
**Game Module**: `src/autoload/goldmine_system.gd`  
**Status**: Implemented (Phase 1 — core token economy)

---

## Translation Philosophy

The GoldMine whitepaper describes a DeFi protocol with four major pillars (Mining,
Fort Knox Staking, Gold Rush Auctions, Treasury/Stockpile/Reserve). This is a 2D
platformer, so the protocol is **translated into game mechanics** rather than
literally simulated. The goal is for players to *feel* the protocol's incentive
loops through gameplay decisions, not to operate as a DeFi participant.

---

## Pillar 1 — GOLD Mining

**Whitepaper**: Mint GOLD with ETH+Diamonds. 100-day linear vesting at 1% per day.
Early claim forfeits unvested tokens. Permanent 20% Diamond burn on every mint.

**Game Translation**:
- `gold_token` collectible (visible as bright gold nugget) represents a fully-vested miner output.
- Player picks up gold tokens during levels → `GoldMineSystem.mine_gold()`.
- On player death, 50% of unsaved GOLD is forfeited to auction pool — mirrors early-claim forfeiture.
- `diamond_shard` powerup (already provides invincibility shield) now also
  triggers the 20% Diamond burn via `GoldMineSystem.collect_diamonds()`.
  Player gets 5 raw Diamonds, 1 is permanently burned, 4 added to balance.

**Constants** (from whitepaper):
- `DIAMOND_BURN_PCT = 0.20`
- `MINER_VESTING_DAYS = 100`

---

## Pillar 2 — Fort Knox Staking Vault

**Whitepaper**: Stake GOLD for wBTC rewards. 288 to 2,888-day commitment.
60% of rewards on day 88 (short pool), 40% on day 288 (long pool).
Max term bonus = 100%. Melt up to 3× staked GOLD for up to 1000% total bonus.

**Game Translation**:
- `wbtc` collectible awards wBTC via `GoldMineSystem.award_wbtc(amount, pool)`.
- Pool param can be "short" (60%) or "long" (40%) — placed at strategic level points.
- `melt_gold(amount, staked)` API exists for future "shrine" or sacrifice mechanic
  where players burn GOLD for a temporary buff multiplier.
- `stake_in_fort_knox(amount, days)` API generates Fort Knox shares with max-term scaling.

**Constants** (from whitepaper):
- `FORT_KNOX_SHORT_POOL_PCT = 0.60`
- `FORT_KNOX_LONG_POOL_PCT = 0.40`
- `MAX_TERM_BONUS_PCT = 1.00`
- `MAX_MELT_RATIO = 3` / `MAX_MELT_BONUS_PCT = 9.00`

---

## Pillar 3 — Gold Rush Auctions

**Whitepaper**: Weekly 7-day auctions. Players burn GOLD into the pool; XAUT
distributed pro-rata by contribution at week end. Resets weekly.

**Game Translation**:
- Boss defeat (claim_jumper, end of Level 3) triggers the auction settlement.
- `GoldMineSystem.forfeit_to_auction(amount)` adds player GOLD to pool.
- `GoldMineSystem.settle_auction(user_contribution, total_pool)` calculates XAUT payout.
- Strategic Reserve provides baseline enemy contribution (50 GOLD) for competition.
- Base XAUT pool = 10% of total auction pool — mirrors whitepaper rate.

**Constants**:
- Base XAUT rate: 0.1 XAUT per GOLD in pool

---

## Pillar 4 — Gold Stockpile + Strategic Reserve + Sovereign Wealth Fund

**Whitepaper**: 10% of BTC mining proceeds → Stockpile (wBTC for weekly LP match).
Remaining forfeited GOLD splits 50/50 between Melt (burn) and Strategic Reserve.
Treasury revenue split: 50% NFT holders, 20% auction supplement, 20% SWF reinvest, 10% founder.

**Game Translation**:
- `distribute_treasury_revenue(total)` splits revenue per whitepaper percentages.
- Triggered by boss defeats as "Treasury revenue distribution" beat.
- 50% NFT share → adds to player's XAUT balance.
- 20% auction share → adds to next-level's auction pool.

**Constants**:
- `STOCKPILE_LP_MATCH_PCT = 0.10`
- `RESERVE_FORFEIT_SPLIT = 0.50`
- `TREASURY_NFT_PCT = 0.50`
- `TREASURY_AUCTION_PCT = 0.20`
- `TREASURY_SWF_PCT = 0.20`
- `TREASURY_FOUNDER_PCT = 0.10`

---

## Pillar 5 — Gold Claim Certificates (Phase 2)

**Whitepaper**: Non-transferable NFT. 0.5 XAUT to mint. Requires 22,000 Fort Knox
shares per Certificate. Holders receive 50% of SWF revenue in XAUT, distributed
proportionally.

**Game Translation**:
- `GoldMineSystem.gold_certificates` counter tracks earned certs.
- Auto-awarded when `fort_knox_shares >= (gold_certificates + 1) * 22,000`.
- Each certificate awards +1000 score and HUD toast.
- Long-term progression goal across all 3 levels.

**Constants**:
- `CERT_SHARES_REQUIRED = 22000`
- `CERT_PRICE_XAUT = 0.5`

---

## HUD Display

Player visibility (in order):
1. SCORE: total game score
2. Health (hearts)
3. 🪙 Coin count (generic)
4. 💍 Ethereum ring count (ETH metaphor)
5. **GOLD** balance (mined GOLD tokens)
6. **wBTC** balance (Fort Knox rewards)
7. **XAUT** balance (auction payouts)
8. **💎** Diamond balance (post-burn)
9. Active power-up indicator

Special toasts:
- **GOLD RUSH AUCTION** — on boss defeat, shows XAUT won + % share
- **GOLD CLAIM CERTIFICATE** — when 22,000 Fort Knox shares threshold crossed

---

## Decision Loops Created by the Translation

| Whitepaper Loop | In-Game Loop |
|-----------------|--------------|
| Collect ETH → mint GOLD | Collect ethereum_ring → no direct mint, but ETH theme |
| Mine GOLD over 100 days | Pick up gold_token across level (each = vested miner) |
| Stake for wBTC, melt for bonus | Future feature: shrine to burn GOLD for short-term buff |
| Forfeit GOLD to auction | Boss defeat auto-burns held GOLD into pool |
| Hold cert for SWF revenue | Earn certs at 22k shares; toast on threshold |
| Avoid loss to Tax Collectors | Death forfeits 50% of held GOLD to auction pool |

---

## Verification Checklist

- [x] All whitepaper constants represented in GoldMineSystem
- [x] gold_token collectible exists and registers with EntitySpawner
- [x] wbtc.gd routes to GoldMineSystem (not just score)
- [x] diamond_shard.gd applies 20% burn before activating shield
- [x] GameManager save/load preserves GoldMineSystem state
- [x] Player death triggers GoldMineSystem.on_player_death() forfeiture
- [x] Level 3 (GoldMine Rush) has 9 gold_token, 2 wbtc spawns
- [x] claim_jumper boss triggers auction settlement on defeat
- [x] HUD displays GOLD/wBTC/XAUT/Diamond counters
- [x] HUD toasts for auction and certificate events

---

## Future Extensions (Phase 2)

1. **Fort Knox Shrine** — interactive object in Level 2/3 where player can stake
   GOLD for temporary stat boost (mimics 288-2888 day commitment via speedrun timer).
2. **Melt Altar** — sacrifice 3× GOLD for a screen-clearing shockwave (whitepaper's
   melt bonus translated to a one-shot ultimate ability).
3. **Strategic Reserve Enemy** — boss minion that "stakes" alongside the player
   in the auction, creating real competition for the XAUT pool.
4. **Gold Certificate Visual** — small UI icon next to score showing certificates
   earned, tooltip explains 22k Fort Knox share threshold.
5. **Treasury Revenue Cinematic** — short animation on boss defeat showing the
   50/20/20/10 split flowing to NFT holders, auction, SWF, and founder buckets.

