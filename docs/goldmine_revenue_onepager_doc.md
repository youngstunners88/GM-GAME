# GoldMine income: one page for the captain

**Problem.** GoldMine's income depends entirely on new miners, and there are almost none. Stakers are paid from
new miners' ETH, there is no outside revenue, and GOLD has no real market to sell into.

**Correction to the first research.** GoldMine is not missing a design. The GitBook already describes weekly
liquidity matching, a Strategic Bitcoin Reserve and a Phase 2 treasury with NFT tiers. Phase 2 is not deployed yet,
so the revenue design can still be changed there.

## What is actually wrong
1. **Mining loses money for the average miner.** The whitepaper snapshot returns 60% of mint ETH to participants.
   Only max-term stakers who also burn GOLD (the Melt bonus) come out ahead, by taking share from everyone else.
2. **Nobody can exit.** GOLD's market cap is about $25k and its only pool holds about $8k, with under $1 of daily
   volume. A $500 buy moves the price 25%. (Figures from one DexScreener pull: re-check on-chain.)
3. **Every planned inflow is still new-entrant money.** NFT sales and mint shares are primary sales. Only game
   revenue, outside LP fees and real-asset income are truly external.

## The fix, in order
1. **Make exit possible first.** Build about $80k of pool depth, using the $50k NFT presale and the protocol's idle
   GOLD placed above the current price. No marketing spend works in a pool this thin.
2. **Sell things people want.** Gold Nugget NFTs and cosmetics through the Lil Blunt game, with a fixed, published
   share of revenue going to the treasury. Cosmetics only, no loot boxes, no cashable rewards.
3. **Let assets earn.** LP fees are small at today's scale. Real-asset income (Bitcoin mining, gold streaming) is
   the only large yield, and it needs capital and a separate legal entity. Gate it behind the first two steps.
4. **Publish one honest number every month:** outside income divided by miner payouts. Mint ETH never counts as
   outside income. It starts at 0%; the goal is 25% in 12 months.

## What the game can do
It is a funnel and a storefront, not a treasury. At 10,000 monthly players it adds about $800 a month to the
treasury and lifts miner payback from 60% to about 68%. Reaching $5k a month needs about 61,000 players.
Keep the game fully playable with no crypto.

## What to build first
A read-only on-chain analytics server. It answers the unknowns below with real numbers, carries no on-chain risk,
and sizes every later decision. Contracts come only after that data.

## Questions for Rich (these decide the design)
1. Does 5% or 10% of mint ETH go to liquidity? The whitepaper and the live page disagree.
2. Who holds the GOLD/wBTC LP tokens, and can they be locked?
3. Is the treasury contract deployed, and can it accept outside funds?
4. Do the mint and staking contracts have an owner or upgrade key? What did the audit cover?
5. How many wallets have minted, and how much ETH per month for the last six months?
6. May the $50k presale go to pool depth first?

**Caveats.** Scenario inputs are my assumptions. The mint split is unconfirmed, because the GitBook query
endpoint errored. Not financial or legal advice; routing revenue to holders has securities risk and South Korea
needs counsel. Full detail: `docs/goldmine_revenue_solution_doc.md`, model: `tools/goldmine-model/revenue_model.py`.
