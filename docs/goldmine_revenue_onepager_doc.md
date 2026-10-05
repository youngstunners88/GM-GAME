# Rich's ecosystem: income, one page for the captain (v3)

**Problem.** SMOKE, DIAMONDS and GOLD are one stack: GOLD needs DIAMONDS, DIAMONDS needs BLAZE/X28, all of it rides
TitanX activity. Income in every layer is new-entrant money, and the base has gone quiet. The Diamond Certificates
failed because payouts depended on BLAZE-stake ETH nobody controls. Waiting for a TitanX resurgence is not a plan.

**Scale (leads, re-check on-chain).** All four tokens together: ~$263k market cap, ~$80k pool liquidity, ~$700 of daily
volume. LP fees across the whole ecosystem: about **$2 a day**.

## What this means for the plan
- **Sweeper bots** are fine plumbing, but they move ETH between pots; they don't create it. Publish which pot loses.
- **Smoke Lounge / Bong Party / NFT sales** is the right direction, with one change: **do not sell on a fee-share yield.**
  To pay a 10% yield on the $50k Claims Office target the pools need ~$4.6k/day of volume, 6.6x the *entire* ecosystem today.
  That is how the certificates failed. Sell access and status instead.
- **The existing community can absorb about $40k of NFTs once** (assuming 300 active wallets). After that every sale must
  be a **new wallet**, and only the game reaches new wallets.

## The system
```
Income = Audience x Monetisation x Credibility - Run-rate
Credibility = Exit depth x Value to buyer x Track record
```
1. **Funding Ledger:** every promise across all three protocols against its real funding, published monthly.
2. **External Spine:** all outside money goes to one ETH-denominated venue (the Lounge), never into X28/BLAZE.
3. **Ladder:** the game's three levels are the on-ramp (Smoke Realm to SMOKE, Crystal Caverns to DIAMONDS, Gold Rush to GOLD).
   Free soulbound proof-of-play badges capture new wallets; the first paid rung is a Lounge pass.
4. **Governor:** a published rule for each outside dollar: ops, then a capped make-whole for certificate holders, then
   pool depth, then top-ups.
5. **Gates and kill rules:** no yield-promising product until three straight cycles with payouts fully funded.

## What the simulation says (assumptions, not a forecast)
- The captain's plan lifts income but not mints: nothing yet fixes credibility. Adding depth, a ledger and the ladder
  gives about 15x more mints (month 24: $219 to $3,221 a month).
- Audience is still the biggest lever. To cover costs by month 24 needs ~45k monthly players at $2k/mo, ~110k at $5k,
  ~212k at $10k. **Either grow the audience or shrink costs to fit.**
- Cover a $5k/mo cost with Gold Panners ($450) = about 11 new buyers a month.

## Questions for the captain
1. Certificates: how many sold, ETH raised, ETH paid per 28-day cycle for six cycles?
2. What exactly do the sweeper bots sweep, from which pool, on what rule?
3. What are Smoke Lounge and Bong Party (product, price, supply, split)?
4. X28's price and depth, and the rules binding the ~800B X28? Is BLAZE Rich's own?
5. The real monthly run-rate, active wallet count, and six months of mint ETH per protocol?

**Caveats.** Inputs are assumptions; the run-rate is a placeholder. The captain's plan row is my reading of one message.
NFT revenue-share has securities risk; get counsel. Not financial or legal advice.
Detail: `docs/goldmine_ecosystem_system_doc.md`. Models: `tools/goldmine-model/ecosystem_check.py`, `system_sim.py`.
