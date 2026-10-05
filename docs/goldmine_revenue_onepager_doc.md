# Rich's ecosystem: income, one page for the captain (v4, with on-chain facts)

**Problem.** SMOKE, DIAMONDS and GOLD are one stack on a shared base: GOLD needs DIAMONDS, DIAMONDS needs BLAZE/X28, all
of it rides TitanX activity. Every layer's income is new-entrant money and the base has gone quiet.

## What the chain says (read-only, 2026-10-05, from Blockscout; re-runnable)
| | Measured |
|---|---|
| **Diamond Certificates** | 23.67 ETH raised from **42 wallets** (131 purchases); 22.6 ETH of it in the first two months |
| **Certificate payout pot** (probable) | 1.88 ETH, growing ~0.0058 ETH/day: **~9% a year of what was raised** |
| **BLAZE ETH inflow** (separate deployer) | **0.75 ETH in September**, 0.14 so far in October |
| **GOLD mining** | 27.2 ETH all-time, **at most 25 wallets**. Sept = 9.8 ETH, but **9.81 ETH was one week from 5 wallets**. Oct so far: 0.02 ETH |
| **DIAMONDS mining** | 10.4 ETH all-time, at most 19 wallets, about 0.5 ETH a month since May |
| **Whole paying base** | **At most 86 wallets, 61.3 ETH (~$184k at $3,000/ETH) ever** |
| **The ~800B X28** | Two Diamonds contracts, 787.6B (7.2% of supply); one of them is unverified |
| **Verification** | **13 of 26 protocol contracts unverified**, all on the Diamonds/Gold side; all 7 BLAZE contracts verified and renounced |

Without that one September week, the ecosystem raised **about 0.6 ETH (~$1,700)** last month.

## What this means for the plan
- **Do not sell the next NFT on a yield.** The certificates paid about 9% a year gross because the funding was ~0.75 ETH a
  month of third-party inflow. The Claims Office fee-share needs 6.6x the *whole ecosystem's* volume to pay 10%.
- **The existing buyers cover one more round, not a business:** about $12k to $55k once if 30% buy again. After that every
  sale must be a **new wallet**, and only the game reaches new wallets.
- **Sweeper bots** move ETH between pots; they create none. Publish which pot loses.
- **Verify the source** of the 13 unverified contracts. Buyers cannot check a promise against code they cannot read.

## The system
```
Income = Audience x Monetisation x Credibility - Run-rate
Credibility = Exit depth x Value to buyer x Track record
```
1. **Funding Ledger:** every promise across the three protocols against its real, measured funding, monthly.
2. **External Spine:** outside money goes to one ETH-denominated venue (the Lounge), never into X28/BLAZE.
3. **Ladder:** the game's three levels are the on-ramp; free soulbound badges capture new wallets; the first paid rung is a Lounge pass.
4. **Governor:** a published rule for each outside dollar: ops, capped make-whole for certificate holders, pool depth, top-ups.
5. **Gates and kill rules:** no yield-promising product until three straight cycles with payouts fully funded.

## What the simulation says (assumptions, not a forecast)
Depth, a ledger and the ladder give about 15x more mints than the current path. Covering costs by month 24 needs ~45k
monthly players at $2k/mo, ~110k at $5k, ~212k at $10k: **grow the audience or shrink costs to fit.**

## Questions only the captain can answer
1. Why do **31% of mint Diamonds** go to SmokeNftsStaging? (The docs say 30% to Treasury and mention neither.)
2. Which ETH do the sweeper bots take, from whom, on what rule?
3. What are Smoke Lounge and Bong Party (product, price, supply, split)? I cannot find Bong Party on-chain.
4. The real monthly run-rate, and X28's price and depth.
5. Are `0x0A23…` (Fort Knox?), `0x33b3…` (auction?) and `0x6540…` (X28 crusher?) what I inferred? Their source is unverified.

**Caveats.** Chain numbers are read-only from Blockscout and a public RPC; Etherscan was not used (no key); wallet counts are
upper bounds; unverified-contract roles are inferred from call patterns. ETH price, wallet repeat rate and run-rate are
assumptions. Not financial or legal advice. Detail: `docs/goldmine_ecosystem_system_doc.md` (section 3b). Re-run:
skill `gm-game-ecosystem-funding-audit`.
