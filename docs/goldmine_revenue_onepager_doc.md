# GoldMine income: one page for the captain (v2, system view)

**Problem.** GoldMine's income depends on new miners and there are almost none. Stakers are paid from new miners'
ETH, there is no outside revenue, and GOLD has no market to sell into. The protocol is not insolvent, because
payouts come from funded pots. It is a **demand problem**: the average miner gets back about 60% of what they pay.

## The system in one line
```
Income = Audience x Monetisation x Credibility - Run-rate
```
- **Credibility** ("can I get value out if I put money in?") is about **0.04 out of 1** today: the pool holds
  ~$8k and miners get back ~60%. We control this, it is cheap, and fixing it multiplies everything else.
- **Audience** is the dominant lever and the unknown. Financial design cannot create it.
- **Run-rate** (monthly cost) sets how much audience is needed.

## What the simulation says (assumptions, not a forecast)
- Fixing credibility (depth first, bonuses funded only by outside income) gives **5x to 25x** more income than doing nothing.
- Even then the base case is only about **$700 a month** at month 24. Audience growth is the biggest lever.
- Audience needed to cover costs by month 24: **~45k** (at $2k/mo), **~110k** ($5k/mo), **~210k** ($10k/mo).
- So there is a fork: **grow the audience to that range, or shrink the costs to fit.** Measured data picks the branch.

## The operating system: four loops
1. **Measure:** one weekly scoreboard (audience, funnel, mints, depth, outside income, miner payback, run-rate coverage).
2. **Gate:** no audience spending until the truth is known (G1), depth is about $80k and LP is locked (G2), and 60 days of conversion data exist (G3).
3. **Allocate:** every dollar of outside income follows a published rule: depth first, then staker top-ups, then reserve. Never pay bonuses from new-miner ETH.
4. **Review:** quarterly kill rules. If income isn't rising once depth is funded and measured, it is an audience problem, and costs get cut to fit.

## The game's role
The audience engine and monetisation point. "Cosmetics" means visual-only items (skins, hats, cart effects) that never
change gameplay. They are the one thing a game can sell without pay-to-win or promising returns, and they are small money.

## Build first
The scoreboard: a read-only on-chain and funnel analytics server. It clears the unknowns and runs the whole system.

## Questions for Rich
1. What is the real monthly cost of running GoldMine and its team?
2. How many people visit the mining app each month, and how many wallets have minted? What was monthly mint ETH for six months?
3. Does 5% or 10% of mint ETH go to liquidity? Who holds the LP tokens?
4. May the $50k presale go to pool depth first?
5. Do the mint and staking contracts have an owner or upgrade key?

**Caveats.** Inputs are assumptions and the run-rate is a placeholder. Not financial or legal advice. Detail:
`docs/goldmine_revenue_system_doc.md`; model: `tools/goldmine-model/system_sim.py`.
