# GoldMine — the income problem and a staged solution

Prepared 2026-10-05 for the GoldMine founder (Rich). Companion model: `tools/goldmine-model/revenue_model.py`
(run it; every number in section 5 comes from it). **Nothing here is financial or legal advice.**

## 1. Bottom line

1. **GoldMine's income is the 10% ops cut of mint ETH, so today it is close to zero.** Every dollar of income
   (his, the treasury's, the stakers') is a fraction of new mints, and mints are near zero.
2. **That is not a marketing problem, it is a design problem with two halves.**
   - *Nobody can exit.* GOLD's market cap is about $25k and its only pool holds about $8k. A $500 buy moves the price 25%.
   - *Mining is negative-sum for the average miner.* The whitepaper returns 60% of mint ETH to participants.
     The other ~40% goes to treasury, burns, liquidity and ops. A rational miner needs to believe they will be a
     *winner* (max-term + Melt staker) or that GOLD will appreciate. With no market, neither is credible.
3. **The game cannot fix this alone.** At the base scenario the game adds about $800 a month to the treasury. It lifts
   miner payback from 60% to about 68%. It is real, small, and best used as a funnel and storefront.
4. **Phase 2 is not deployed, so it can still be designed.** The "immutable core" argument applies to the mint and
   Fort Knox contracts. The Treasury, Claims Office and Auction are not live (Day 88 gating, a $50k presale target).
   Fixes belong *there*.
5. **The fix is a stack, in order:** (A) make exit possible, (B) sell things people actually want, (C) let assets
   earn, (D) publish one honest KPI that proves the income is real. Details in section 4.

## 2. What the protocol actually does (corrected)

The first-pass research believed there was no liquidity, no burn and no Phase 2 design. The GitBook says otherwise.
Sources: GitBook subpages (read 2026-10-05), `docs/whitepapers/GoldMine.md` (snapshot 2026-05-07).

| Flow | Detail | Confidence |
|---|---|---|
| Mint cost | 50% Diamonds + 50% ETH (or all ETH); 20% of Diamonds used are burned; 30% of mint Diamonds go to Treasury | live page |
| Allocation of mining proceeds | 35% Fort Knox wBTC pools, 25% weekly auctions (XAUT), 15% Treasury/SWF, 10% Diamond burn, 5% stockpile LP, 3% marketing, 3% founder, 3% build, 1% maintenance | **whitepaper snapshot only** |
| Liquidity | Live Stockpile page says **10%** of mining ETH becomes wBTC for weekly GOLD/wBTC LP. The snapshot says 5%. They disagree. | conflict, verify on-chain |
| Staking | 288 to 2,888 day locks, 60% of rewards at day 88, 40% at day 288, +100% max-term, Melt up to 3x for 1,000% total | live page |
| Strategic Bitcoin Reserve | Gets half of surplus GOLD, stakes it weekly, reinvests rewards 60/40. Cannot Melt. | live page |
| Phase 2 | Sovereign Wealth Fund (52-week rolling payout), Claims Office NFTs (Gold Panner 0.15 ETH, Prospector 0.005 wBTC, Sovereign 0.03 wBTC), gated auction paying wBTC, forfeited GOLD to Smoke Lounge "Gold Nuggets" NFTs | live page |
| Fee trio | wBTC/PAXG, wBTC/XAUT, wBTC/ETH. **100% of PAXG/XAUT fees go to NFT holders (7/23/70)** | live page |
| Not documented | Contract mutability, admin keys, audit scope, LP-token ownership, the Diagram page ("too complex") | unknown |

Market state, from DexScreener through a summariser (re-pull before quoting): GOLD/WBTC pool $8.3k, 24h volume $0.79,
FDV $25k. DIAMONDS: pools of $19.5k (X28) and $6.6k (WETH), FDV $72k. One returned pair-creation date is in the
future (December 2026), so treat the whole pull as unverified.

## 3. Why income is zero (three causes)

**Cause 1: the yield is funded by the people it is advertised to.** Participants receive 60% of what miners pay.
The average miner loses ~40% in value terms before any GOLD price. Only the committed (long lock + Melt) win,
by taking share from everyone else. That is a tontine. It is transparent and pays in hard assets, which is better
than a Ponzi, but it only recruits people who believe they will be the winner.

**Cause 2: no price, no exit, no volume.** Depth needed so a $1,000 buy moves price at most 5% is about $81k, and
for 2% about $201k. The pool has about $8k. No marketing spend can work in a pool this thin, because buys just
spike the price and then reverse.

**Cause 3: every inflow is new-entrant money.** Even Phase 2's inflows (NFT sales, Gold Nugget proceeds, treasury share
of mints) are primary sales to new participants. Only three things in the design are *external*: LP fees from outside
traders, yield on reserve assets, and real-asset income (BTC mining, gold streaming). All three scale with capital
and volume the protocol does not yet have.

## 4. The solution: a four-layer revenue stack

### A. Make exit possible (weeks 0 to 8). Prerequisite for everything else.
- Target depth of **$80k** (5% impact on $1k) staged toward **$200k**. Do not run buy programs before this.
- **Capital-light depth:** place the protocol's idle GOLD (Reserve and Xaut Sweep surplus) as **single-sided Uniswap v3
  ranges above the current price**. The pool gets deeper without new wBTC and the protocol *earns wBTC* as GOLD is bought.
- Spend the $50k NFT presale on depth first, not on marketing.
- Keep GOLD/wBTC as the canonical pair (that is Rich's design). Decide whether a GOLD/ETH pool is wanted, because most
  casual buyers arrive with ETH.
- Whoever holds the LP tokens must be public. Lock or timelock them.

### B. Sell things people want (weeks 4 to 24). The only scalable external income.
1. **Gold Nuggets NFTs at the Smoke Lounge.** The design already routes proceeds 50% SWF / 30% Liquidity Manager /
   20% GOLD/wBTC LP. Price in ETH for revenue, and let the GOLD-forfeit route be the sink. The Lil Blunt game is a
   natural storefront (section 6).
2. **Claims Office tiers**, with honest framing: they are a *primary sale* (capital), not recurring income.
3. **Game cosmetics and an Episode 2 season pass**, fiat or ETH, cosmetics only, with a *published fixed share* of
   net revenue (suggest 40%) to the SWF.
4. **Do not** add paid loot boxes or cashable play-to-earn emissions (Axie and Pixels history, plus gambling law).

### C. Let assets earn (months 3 to 12)
- Fee trio and Diamonds/ETH spread capture. At realistic volumes this is small (model: ~$1k/yr conservative,
  ~$11k/yr base on $100k TVL). Note the PAXG/XAUT fees belong to NFT holders, so they pay NFT buyers, not the protocol.
- Reserve wBTC lending or liquid staking yields very little. Do not count on it.
- **Real-asset income (BTC mining, gold streaming)** is the only route to a meaningful yield, and it needs real capital
  and the separate legal entity the docs describe. Gate it: do not start before the SWF holds a meaningful reserve.
  I have no verified yield numbers for it, so do not promise any.

### D. One honest KPI: External Revenue Coverage (ERC)
`ERC = external income (trailing 90 days) / participant payouts (trailing 90 days)`
- External = game, NFT/Nugget sales, LP fees retained, asset yield. **Mint ETH is never external.**
- Publish it monthly from day one, even when it is 0%. Suggested path: 0% now, 10% by month 3, 25% by month 12.
  At 100% the protocol no longer needs new miners.
- Any bonus paid to stakers ("season bonus") is funded **only** from external income. Never pay referrals or bonuses
  out of new-miner ETH. That would deepen the Ponzi shape.
- Cheap first version: a multisig as the single external-revenue destination, plus a public ledger. A small splitter
  contract can come later, after an audit.

## 5. What the numbers say (model output, assumptions not forecasts)

| Scenario | Game gross / mo | to SWF / mo | LP fees / yr | NFT-holder yield | Payback to miners |
|---|---|---|---|---|---|
| Conservative (1.5k MAU, 2% pay, $6) | $180 | $61 | $1.1k | 7% | 60% to 63% |
| Base (10k MAU, 3% pay, $8) | $2.4k | $816 | $11k | 22% | 60% to 68% |
| Stretch (50k MAU, 4% pay, $10) | $20k | $6.8k | $110k | 73% | 60% to 71% |

- Reaching $5k a month into the SWF needs about 61k monthly players at 3% paying and $8. Reaching $20k needs about 245k.
- Even stretch only lifts payback to ~71%. Getting miners to **100% payback would need external income equal to 40%
  of mint inflow.** The honest conclusion is that mining stays a *commitment product*, not a safe yield. The goal is
  coverage that rises over time, and a market where GOLD itself has a price.
- The NFT-holder yield column is what makes the Claims Office pitch credible or not: 22% needs $100k TVL turning over
  10% a day, which a pool this size has not shown. Do not market it before the volume exists.

## 6. The game's role (repo-grounded)

What already exists: `src/autoload/goldmine_system.gd` (a simulation of mining, Fort Knox and auctions), the GOLD protocol
room with a quiz, Level 3 Gold Rush, `web/web3.js` + `web3_bridge.gd` (wallet connect, read-only balances, one
user-signed mint), `config.json` with the verified GOLD address, PostHog funnel events, and an ICP `nft_ledger`.

| Move | What it does | Effort | Guardrail |
|---|---|---|---|
| Instrument the funnel first | `ui_gold_mine_click` + UTM on the mine4gold.app link; measure room to click to mint. No promise is credible without it. | days | PostHog is wired; no PII |
| GOLD room to mining CTA | Convert the protocol-room quiz pass into a deep link | days | explain, never imply returns |
| Gold Nuggets storefront in the Smoke Lounge | The only direct sales path, built on the protocol's own NFT contract | 2 to 4 wks + audit | **separate collection**: the six soulbound ids in `docs/nft/NFT_CONTRACT.md` must not change |
| Season pass / cosmetics | Fiat or ETH revenue with a published share to SWF | 2 to 3 wks | cosmetic only, no wallet gate on play |
| Proof-of-play attestation | Reuse ICP canister to gate points/referrals against bots | 3 to 4 wks | not "cheat-proof" (client-authoritative game) |
| Referral from the existing 3% marketing line | CAC capped by construction | needs mint-contract check | pay only from the marketing bucket |

Keep the game fully playable with zero crypto. The `goldmine-economy-invariants` skill already lists real defects in the
simulation (unbounded `melt_gold`, an unused 50/50 reserve split). Fix them before any on-chain Proof-of-Play work.

## 7. Roadmap with kill criteria

| Window | Do | Gate to continue |
|---|---|---|
| 0 to 30 days | Answer section 9's questions; on-chain truth dashboard (read-only MCP server); publish ERC at 0%; instrument funnel | We can state the true mint split and who holds LP |
| 30 to 60 | Fund depth to $80k (single-sided ranges + presale); lock LP | 5% impact on $1k buy |
| 60 to 120 | Gold Nuggets and season pass in the game; first externally funded stakers' bonus | ERC above 5% |
| 120 to 365 | Fee trio at volume; decide on real-asset entity | ERC above 25%, or stop adding product and reassess |

If depth is funded and 90 days later monthly mints and game revenue are still flat, the distribution is the problem and
the answer is audience (SmokeRing and DIAMONDS communities), not more mechanism.

## 8. Risks

- **Securities:** routing business revenue to holders strengthens an "efforts of others" argument. Prefer burns, owned
  liquidity and cosmetics over "dividends". The SEC's 2025 staff statements do not cover app-level staking. No APY marketing.
- **Gambling:** direct-purchase cosmetics only. If boxes ever exist, disclose odds. South Korea (the TC team's base) has
  specific rules, so geofence token features pending counsel.
- **Brand:** the cannabis theme limits app stores and sponsors. Keep itch.io and web primary.
- **Counterparty:** XAUT, PAXG and wBTC are custodial. Disclose it.
- **Honesty:** say plainly that rewards so far were mint-funded and what external share is planned. Do not use a burn as a price promise.

## 9. Questions for Rich (these decide the design)

1. Where does the full 100% of mint ETH go today, 5% or 10% to liquidity? Is the whitepaper snapshot stale?
2. Who holds the GOLD/wBTC LP tokens, and can they be locked?
3. Is the Treasury/SWF contract deployed, and can it accept outside wBTC/ETH/XAUT?
4. Do the mint and Fort Knox contracts have an owner, proxy or setter? Is the audit scope the mint only?
5. How many wallets have minted, and what is the monthly mint ETH for the last 6 months?
6. Is the $50k presale committed, and may it go first to depth?
7. Which entity would hold real-asset investments, and is counsel engaged?

## 10. Evidence and confidence

- GitBook text was read through a page summariser and `?ask=` queries returned HTTP 500, so the exact split and the
  mint-price curve are **not confirmed**. The audit PDF was not opened.
- Market figures come from one DexScreener pull with an impossible pair date. Re-pull on-chain before quoting.
- Scenario inputs are the author's assumptions. Challenge them; the model is built for that.
- Earlier research in this thread (Hyperliquid, Aave, Pixels and others) was **not re-verified** here.
