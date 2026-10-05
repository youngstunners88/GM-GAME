# GoldMine income: the system view

Prepared 2026-10-05. Supersedes the idea list in `goldmine_revenue_solution_doc.md`, which stays as the evidence
file. Numbers come from `tools/goldmine-model/system_sim.py` (run it). **The simulation is not a forecast.** Its
behavioural inputs are assumptions, so trust the *ranking* of levers more than any dollar figure.

## 1. The one equation

```
Income  =  Audience  x  Monetisation  x  Credibility   -   Run-rate
```

| Term | Meaning | Today |
|---|---|---|
| **Audience** | People who reach GoldMine each month (game, SmokeRing, DIAMONDS, organic) | unmeasured |
| **Monetisation** | Dollars per person: the mint ticket plus outside sales, fees and yield | small |
| **Credibility** | "If I put money in, can I get value out?" = exit depth x payback to miners | **~0.04 of 1.0** |
| **Run-rate** | Monthly cost of running the whole effort | unknown, ask Rich |

Credibility today: pool depth $8.3k gives an exit factor of 0.09, and 60% payback gives a value factor of 0.44.
Their product is about 0.04. Every dollar of audience is multiplied by 0.04.

## 2. What the simulation says moves income

Base case, month-24 operating income, each input changed by +/-50% (ranked by swing):

| Rank | Lever | Swing |
|---|---|---|
| 1 | Audience growth rate | $984/mo |
| 2 | Starting audience | $507/mo |
| 3 | Game monetisation (pay rate, ARPPU, treasury share, each) | $373/mo |
| 4 | Mint conversion and ticket size | $324/mo |
| 5 | Pool depth requirement | $213/mo |
| 6 | Ecosystem/organic visitors | $189/mo |
| 7 | Game-to-mine funnel | $134/mo |

Three conclusions:
1. **Credibility is a multiplier you control, and it is cheap.** Depth-first versus not, same audience: monthly mints
   $3.3k vs $0.7k (5x). Status quo versus the full policy: 5x to 25x more operating income.
2. **But it multiplies a small number.** Even the full policy reaches only about $700/mo of operating income at 8%
   monthly game growth. Financial engineering cannot create audience.
3. **Break-even is an audience number, set by the run-rate.** Game audience needed by month 24 to cover costs:

| Monthly run-rate | Audience needed (MAU-equivalent) |
|---|---|
| $2,000 | ~45,000 |
| $5,000 | ~110,000 |
| $10,000 | ~210,000 |

So the plan has a fork, and the data should pick the branch, not opinion: **either grow the audience to that range,
or shrink the run-rate to what the audience supports.**

## 3. The operating system: four loops

### Loop 1: Measure (weekly scoreboard, seven numbers)
1. Audience: visitors to the mining app per month, by source.
2. Funnel: visitor, wallet connect, mint (three percentages).
3. Mints in dollars per month.
4. Pool depth, and the sell-pressure ratio: GOLD unlocking per month divided by depth.
5. External income in dollars, and **External Revenue Coverage** (outside income / participant payouts, with mint ETH never counted).
6. Payback to miners (60% mint-funded plus externally funded top-ups).
7. Run-rate coverage: operating income / run-rate.

Pair the ratio in item 5 with absolute dollars: a ratio alone looks great when payouts collapse to zero.

### Loop 2: Gate (credibility before spend)
No audience spending until these pass:
- **G1 Truth:** the true mint split, LP-token holders, contract powers and monthly mint history are known.
- **G2 Exit:** depth of at least $80k, or a $1k buy moves price at most 5%; LP locked.
- **G3 Funnel:** at least 60 days of measured visitor-to-mint conversion.

### Loop 3: Allocate (the governor)
Every dollar of outside income splits by rule, not mood:
1. About 30% funds operations.
2. While depth is under $200k: 60% of the rest goes to depth, 20% to staker top-ups, 20% to reserve.
3. After that: 10% depth, 50% top-ups, 40% reserve.
4. **Top-ups come only from outside income.** Never pay bonuses or referrals from new-miner ETH.
5. Real-asset investments (Bitcoin mining, gold streaming) only after the reserve exceeds a threshold Rich sets
   with counsel, and only through the separate legal entity.

### Loop 4: Review (quarterly, with kill rules)
- Operating income not rising after depth is funded and 90 days measured: the audience is the problem. Stop adding
  mechanisms and decide the fork in section 2.
- Run-rate coverage below 25% at month 12 on the base path: cut the run-rate to fit, or wind down to a lean mode.
- Any month where the sell-pressure ratio exceeds the gate: pause incentives until depth catches up.

## 4. The game's role inside the system

The game is the **audience engine and the monetisation point**, in that order.
- **Audience:** the GOLD protocol room, Level 3 Gold Rush and Episode 2 are an education funnel. Instrument it first
  (PostHog is wired); without conversion numbers no forecast means anything.
- **Monetisation:** "cosmetics" here means purely visual items (skins, hats, cart and trail effects) that never change
  how the game plays. They are the one thing a game can sell without becoming pay-to-win or promising returns.
  They are small money: in the model, game revenue is a minor part of income until the audience is large.
- **Sink:** Gold Nugget NFTs from forfeited GOLD (already in the protocol's design) give GOLD a use.
- Keep the game fully playable with no crypto, and keep the six soulbound NFT ids unchanged.

## 5. What to build

1. The scoreboard: a read-only on-chain and funnel analytics server. It supplies Loop 1 and clears G1.
2. The depth plan and LP lock (G2).
3. The governor as a published rule plus a multisig and monthly report. A contract only after an audit.
4. The game funnel and storefront, once G3 data exists.

## 6. Risks and limits

- **Model limits:** audience, conversion, ticket and monetisation are assumptions. The real mint history and player
  numbers must replace them before the dollar figures mean anything.
- **Run-rate is a placeholder** ($2k, $5k, $10k shown). Rich must give the real number.
- **Securities and gambling:** routing revenue to holders strengthens an "efforts of others" argument. No APY marketing,
  no paid loot boxes, no cashable rewards. South Korea needs counsel. Not legal or financial advice.
- **Unverified inputs:** the 5% versus 10% liquidity split, depth of $8.3k (one DexScreener pull with an impossible
  pair date), and the whitepaper allocation snapshot.
