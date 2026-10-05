# The Rich ecosystem: one system, one income plan

Prepared 2026-10-05. **This replaces the GoldMine-only view** in `goldmine_revenue_system_doc.md`, which assumed GOLD
stood alone. It doesn't: SMOKE, DIAMONDS and GOLD are three layers of one machine, and the captain's message of
2026-10-05 (Diamond Certificate payouts failed; sweeper bots in 3 weeks; then 100% focus on Smoke Lounge / Bong Party /
NFT sales) confirms where it hurts. Numbers come from `tools/goldmine-model/ecosystem_check.py` and `system_sim.py`.
**Inputs marked ASSUMPTION are mine. Trust the ranking of levers more than any dollar figure. Not financial or legal advice.**

## 1. Bottom line

1. **The three protocols are one stack on a shared base, and the base has gone quiet.** GOLD needs DIAMONDS to mint,
   DIAMONDS needs BLAZE and X28, SMOKE is minted with X28. All of it rides TitanX-family activity. The captain says it
   directly: it "needs a massive TitanX resurgence." That is not a plan anyone controls.
2. **The Diamond Certificates are the template for what goes wrong next.** They were sold for ETH and paid from
   BLAZE-stake ETH the protocol did not control. Inflow was too low, so payouts failed. GoldMine's Claims Office tiers
   promise a share of LP fees from pools that trade about **$1 a day**. They will under-pay the same way.
3. **The planned fixes are necessary but not sufficient.** Sweeper bots *move* ETH between pots; they do not create it.
   NFT sales to the existing community fund a launch, not a business: **measured on-chain, the whole paying base is at
   most 86 wallets who have raised 61 ETH (~$184k at an assumed $3,000/ETH) in total** (section 3b). The next
   buyer has to be a **new wallet**, and the only asset that reaches new wallets is the **game**.
4. **The systematic answer is five parts:** a Funding Ledger (every promise against its real funding), an External
   Spine (one ETH-denominated venue, the Lounge), a Ladder (the game's three levels as the on-ramp), a Governor (a
   published rule for every outside dollar), and Gates with kill rules.

## 2. The ecosystem as one machine

Sources: GitBook pages (read 2026-10-05) and the captain's message. The dApps (`diamonds1111.win`, `mine4gold.app`)
are JavaScript apps that return nothing readable, so on-chain numbers there are **not** verified.

| Layer | What it is | Where ETH actually comes from |
|---|---|---|
| **Base** | TitanX family: X28, BLAZE | Third-party activity. Not controlled. |
| **SMOKE** (culture, front door) | 1 X28 = 1 SMOKE; 50% of X28 buys and burns SMOKE, 40% builds LPs, 5% burns H420, 5% genesis. OG tax token 2.5% (1.5% to marketing/ops); the OFT version is untaxed. | New X28/ETH minters. |
| **DIAMONDS** (ETH rewards) | Mint 1:1 with BLAZE, 50/50 BLAZE/ETH. Of mint ETH: 60% DIAMONDS/X28 LP, 20% Diamond Exchange (weekly ETH to people who crush DIAMONDS), 12% Vault. 8% not accounted for in the docs. 80% of BLAZE from mining is staked in BLAZE, whose ETH feeds the 28-day Certificate pool. Certificate sales (0.028 ETH, permanent) go 100% to the Crusher (buys TITANX/X28, then DIAMONDS, then burns). Holds ~800B X28. | Mint ETH plus **BLAZE-stake ETH** (outside control). |
| **GOLD** (gold/BTC exposure) | Mint 50% DIAMONDS + 50% ETH. 35% Fort Knox wBTC, 25% auctions (XAUT), 15% Treasury, 10% Diamond burn, 5% to 10% liquidity (sources disagree), ~10% ops. Phase 2: NFT tiers, 100% of PAXG/XAUT LP fees to NFT holders. | New miners' ETH. |
| **Lounge** | Smoke Lounge: Gold Nuggets NFT contract, shared revenue venue. "Bong Party": **not documented anywhere I can read.** | NFT sales. |

Dependency chain: **GOLD ← DIAMONDS ← BLAZE/X28 ← TitanX.** Each layer's income is a slice of the layer below's
volume. A weak root makes every layer weak at once.

## 3. How big is it, really? (leads from DexScreener, re-pull before quoting)

| Token | FDV | Pool liquidity | 24h volume |
|---|---|---|---|
| BLAZE | $123k | $10k | $162 |
| DIAMONDS | $73k | $26k | $17 |
| GOLD | $25k | $8k | $1 |
| SMOKE | $41k | $35k | $514 |
| **All four** | **$263k** | **$80k** | **$693 / day** |

- Fees across the **entire ecosystem** at 0.3%: about **$2 a day, $760 a year.**
- Daily volume is 0.9% of liquidity (healthy pools run 10% or more).
- The pulls returned oddities (a "Robinhood" chain for SMOKE, "SMOKE LOUNGE" as a quote token, one future date). Treat as leads.

## 3b. What the chain says (measured 2026-10-05, read-only)

Gathered with `scripts/ecosystem-onchain.mjs` (skill `gm-game-ecosystem-funding-audit`) from Blockscout and a public
RPC. Each line is reproducible; raw numbers are in `tools/ecosystem-audit/findings.json`. Role labels for unverified
contracts are **inferred from the methods called on them**, not read from source.

| Question | Measured answer |
|---|---|
| **Certificates: sold and raised** | **23.67 ETH** from **42 wallets** over 131 purchases (2025-10-22 to 2026-05-30). 22.6 ETH of it landed in the first two months; nothing meaningful since May. |
| **Certificate payout pot** (probable, `0xd3d0…`) | Holds **1.88 ETH**, growing about **0.0058 ETH a day** (~2.1 ETH a year, about **9% a year of what was raised**). 22 wallets have claimed from it. |
| **BLAZE inflow** (the third-party ETH) | BlazeStaking took in **0.75 ETH in Sept 2026** and 0.14 ETH so far in Oct, all from one sender. DiamondHand holds 132 ETH but grows ~0.0056 ETH a day. |
| **GOLD mining** | Launched 2026-06-27. **27.2 ETH all-time from at most 25 wallets.** By month: Jun 14.2, Jul 3.1, Aug 0.09, Sep 9.8, Oct 0.02. **9.81 ETH of September was one week from 5 wallets.** |
| **DIAMONDS mining** | Launched 2026-04-29. **10.4 ETH all-time from at most 19 wallets.** May 7.9, then about 0.5 ETH a month. |
| **Paying base, all three** | At most **86 wallets** (42 + 25 + 19, assuming zero overlap), **61.3 ETH** raised in total. |
| **Where GOLD mint output goes** | wBTC leg: 32.0% Fort Knox, 47.9% swapped to XAUT for the auction, 10.4% DevDistributor, 9.6% a staging contract (supports the GitBook's "10% to liquidity"). ETH leg: 96% swapped, 4% to `0xFB51…`. **DIAMONDS leg: 48.0% to `0xFB51…`, 31.2% to SmokeNftsStaging, 20.8% burned.** The docs say 30% of mint Diamonds go to Treasury and mention no SmokeNftsStaging. |
| **The ~800B X28** | `0x6540…` (unverified, runs `swapTitanX`/`swapEth`) holds 489.9B and DiamondsLpInjector 297.7B: **787.6B, 7.2% of X28 supply**. The top three X28 holders own 66.9%. The X28 owner is a single key with 18 setters, not renounced. |
| **Who controls what** | Diamonds-side contracts: one Safe multisig. Gold-side unverified contracts and SmokeNftsStaging: another Safe. The GOLD and DIAMONDS token contracts: verified. **GOLD: ownership renounced.** All 7 BLAZE contracts: verified, ownership renounced. |
| **Verified source** | **13 of 26 protocol contracts are unverified, all Rich's** (certificates, Fort Knox, auction, treasury staging, the X28 crusher among them). |
| **Is BLAZE Rich's?** | BLAZE contracts were deployed by a **different address** than Diamonds/GOLD/Certificates/SmokeNftsStaging. On-chain evidence that it is a separate project; confirm with the captain. |
| **GOLD supply and price check** | 74,242 GOLD x $0.3418 = ~$25.4k, matching the DexScreener figure (a useful cross-check). 68.95% of GOLD sits in one unverified contract (inferred: Fort Knox). |

**What this changes**
- The certificate "failure" is now quantified: about 9% a year gross yield against a pot funded by ~0.75 ETH a month of
  third-party inflow. A buyer expecting more was never going to be paid more.
- **The base is far smaller than assumed.** My earlier 300-wallet guess was 3.5x too high.
- **Mining is spike-driven.** Without one week of five wallets, September raised about **0.58 ETH (~$1,700)** across both
  protocols. The all-time raise is the number that matters, and it came in launch weeks.
- **Two findings need the captain, not the chain:** why 31% of mint Diamonds flow to SmokeNftsStaging (not in the docs
  I read), and whether the Treasury is meant to be `0xFB51…` (48% of mint Diamonds, 4% of mint ETH).
- **Jev's role:** it judged these numbers. It agreed on certificate yield (<12%, p=0.91), unverified source (p=0.88) and
  do-not-promise-yield (confidence 0.97). On "paying base under 100 wallets" it said *uncertain* (0.31), but the sum
  42 + 25 + 19 = 86 settles it, so the arithmetic wins. On "mining has stalled" it said *uncertain* (0.35), which is
  fair: DIAMONDS has stalled and GOLD shows one spike week, then near zero.

## 4. Three structural failures

**A. Stacked dependency on a quiet base.** Waiting for a TitanX resurgence puts every protocol's income in someone
else's hands. Reserves and income should not be denominated in X28/BLAZE. The ~800B X28 held by the Diamonds
contracts is committed to buy-and-add and buy-and-burn rules, so it is **not runway**. Its value is unknown until
X28's price and depth are checked (X28 did not appear in my market pull).

**B. Promised versus funded.** Certificates promise ETH; the funding depends on BLAZE's inflow. The test for any new
yield promise is simple:

| Fee yield promised on the $50k Claims Office target | Volume needed | Versus whole ecosystem today |
|---|---|---|
| 5% | $2.3k / day | 3.3x |
| 10% | $4.6k / day | 6.6x |
| 20% | $9.1k / day | 13.2x |

GOLD's own pool trades $0.79 a day, so a 10% yield needs 5,780 times that. **No NFT should be sold on a fee-share
yield until the ledger shows volume that covers it.**

**C. Recycled buyers.** Certificate buyers were burned, and the measured base is at most 86 wallets (section 3b). If
30% of them bought again (assumption, ETH at $3,000), one more NFT round raises about **$12k at the Gold Panner price,
or $55k if they repeated their demonstrated average spend of ~$2,100**. At a $5k/month cost that lasts 2 to 11 months,
and at $10k 1 to 5 months. Every sale after that must be a new wallet.

### On the captain's plan
- **Sweeper bots:** sound plumbing. Two conditions: publish exactly which ETH is swept from which pool (it is taken
  from someone else's payout), and tie it to the ledger so the shortfall is made whole from *outside* income over time.
- **100% focus on Smoke Lounge / NFT sales:** right direction, wrong yield. Sell **access, status and utility**
  (events, the Lounge, proof-of-play badges), price in ETH, and make no fee-share promise.

## 5. The system

```
Income = Audience x Monetisation x Credibility - Run-rate
Credibility = Exit depth x Value to buyer x Track record
```
**Track record** is new, and it is where the certificates hurt: it starts at roughly half and recovers only when
promises are visibly kept.

1. **Funding Ledger.** One public table across all three protocols: every payout promise, its funding source, the
   inflow that actually arrived, and the coverage ratio. Publish it monthly, even when coverage is below 1.
2. **External Spine.** Outside money (NFT sales, events, game revenue) goes to **one** ETH-denominated venue, the
   Lounge, never into X28/BLAZE. Mint ETH never counts as outside.
3. **Ladder.** The game already has the three rungs: Level 1 Smoke Realm = SMOKE (culture, cheapest entry), Level 2
   Crystal Caverns = DIAMONDS, Level 3 Gold Rush = GOLD. The six free **soulbound proof-of-play NFTs** (on ICP) are the
   lead capture: a wallet or principal with no payment. The first **paid** rung is a Lounge pass. Measure
   visitor, badge, pass, then protocol.
4. **Governor (outside-income waterfall).** About 30% to operations; then a capped make-whole schedule for the
   Certificate shortfall; then depth for the pool that gates each protocol's entry; then top-ups. Starting values,
   to be tuned by the simulation.
5. **Gates and kill rules.** G1 Truth (every flow, holder and number in section 9 known). G2 Exit (about $80k depth, LP
   locked). G3 Funnel (60 days of measured conversion). G4 Track record (three straight cycles with coverage at or above
   1 before launching any yield-promising product). If income is not rising after G2 and 90 days of data, the audience
   is the problem; cut costs to fit.

## 6. What the numbers say (assumptions, not forecasts)

Base case, 8%/month game audience growth, month-24 operating income per month:

| Policy | Mints / mo | Operating income / mo |
|---|---|---|
| Status quo | $219 | $35 |
| Captain's plan as I read it (storefront on, nothing else) | $219 | $351 |
| Full system | $3,221 | $706 |

- The plan raises income because the storefront sells, but **mints do not move**: credibility is untouched.
- Sensitivity ranking: audience growth ($981 swing), starting audience ($505), game monetisation ($373), conversion and
  ticket ($315), depth ($209). Track record is small at month 24 but matters early: over 24 months cumulative mints are
  about $27k with no recovery, $45k with a published ledger, $50k if never burned.
- **Audience needed to cover a monthly run-rate by month 24:** about 45k (at $2k), 110k ($5k), 212k ($10k).
- New buyers needed per month to cover run-rate with Gold Panners at $450: 4 (at $2k), 11 ($5k), 22 ($10k), meaning
  roughly 220 to 2,200 qualified visitors a month at 1% to 2% conversion.
- So: **grow the audience to that range or shrink the run-rate to fit.** The run-rate figure is a placeholder.

## 7. Sequence (aligned to the 3-week bot build)

| When | Do |
|---|---|
| Weeks 0 to 3 (bots being built) | Build the Funding Ledger and scoreboard (read-only). Answer section 9. Define the Lounge product **without** a yield promise. Instrument the funnel (PostHog is already wired). |
| Weeks 3 to 8 | Launch the free soulbound badge, then the first paid Lounge pass, to **new** wallets via the game. Fund depth for the entry pool; lock the LP. |
| Weeks 8 to 16 | Publish ledger coverage; start the make-whole schedule from outside income. Review G3 and G4. |
| Month 4 onward | Only then consider yield-bearing products or real-asset investments (separate entity, counsel). Apply the kill rules. |

## 8. Risks

- **Securities:** NFTs that pay a share of fees or ETH (Certificates, Claims Office 70/23/7% tiers) invite an
  "expectation of profits from others' efforts" argument, and the failed certificate payouts may create claims. Get
  counsel before more sales.
- **Trust:** a second under-delivering NFT would likely end the ecosystem's ability to sell anything.
- **Brand and platforms:** "Bong Party" and the cannabis theme limit app stores, sponsors and payment processors; keep
  itch.io and web primary, and keep the content chill and positive per the repo's rules.
- **Gambling:** no paid loot boxes or cashable rewards. South Korea needs counsel before token features.
- **Counterparty:** XAUT, PAXG and wBTC are custodial.

## 9. Questions (these decide the design)

Status after the on-chain pass (section 3b): **answered**, **partly answered**, **open (only the captain can answer)**.

1. **Certificates** (**answered**): 42 wallets, 131 purchases, 23.67 ETH. The probable pot accrues ~2.1 ETH a year. *Still open:* the actual payout amounts per cycle (the pot's source is unverified, so its payouts are inferred).
2. **Sweeper bots** (**open**): not deployed yet, so nothing to read. One keeper-like contract (`0x565E…`, one sender, ~10 calls a day) exists; whether it is related is unknown.
3. **Smoke Lounge and Bong Party** (**open**): `SmokeNftsStaging` (verified, Gold-side Safe) holds 21% of DIAMONDS and 14% of GOLD, and receives 31% of mint Diamonds. Two `SMOKE LOUNGE` tokens exist (one with 12 holders and 8.0M supply). "Bong Party" appears nowhere on-chain I can find.
4. **X28** (**partly answered**): the ~800B is `0x6540…` (489.9B) + DiamondsLpInjector (297.7B), 7.2% of supply. BLAZE is a **separate deployer** from the Diamonds/Gold contracts. *Still open:* X28's price and depth (not in my market pull) and the rules inside the unverified `0x6540…`.
5. **Run-rate** (**open**).
6. **Community** (**answered**): at most 86 paying wallets, 61.3 ETH all-time; monthly mining ETH in section 3b and `ecosystem_check.py`.
7. **Splits** (**partly answered**): GOLD's wBTC leg supports **~10%** to a liquidity staging contract. DIAMONDS: the 8% question is *not* answered because the DIAMONDS ETH leg was not traced here (run `tokenflows` on the DIAMONDS token). **New question:** why 31% of mint Diamonds go to SmokeNftsStaging.

## 10. Evidence and confidence

- GitBook text came through a page summariser; the dApps' text was unreadable, but their JavaScript address maps were
  read directly; market data has oddities. The captain's message is one screenshot.
- **On-chain numbers** (section 3b) come from Blockscout and a public RPC, as of 2026-10-05. Etherscan was not used (it
  needs an API key none of this session's environment has). Wallet counts are upper bounds; flows can be truncated on
  heavy contracts and the script says so. Role labels for unverified contracts are inferences from call patterns.
- ETH price ($3,000) is an **assumption**, not read from chain.
- The simulation's behavioural inputs (audience, conversion, ticket, ETH price, wallet counts, run-rate, trust start and
  recovery) are assumptions. The ranking of levers is the output to rely on.
- The "captain's plan" row is my reading of one message, not his spec.
