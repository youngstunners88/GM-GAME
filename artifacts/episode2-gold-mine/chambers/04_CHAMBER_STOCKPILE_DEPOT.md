# Chamber 4 — Stockpile Depot (Gold Stockpile / Liquidity)

**White-paper element:** GOLD Stockpile liquidity — the only protocol
liquidity pool is the **GOLD/wBTC pair on Ethereum**. Forfeited GOLD is
matched with wBTC and either burned or injected as LP. (WP §Fund Allocation —
5% to Stockpile liquidity; §Key Details — wBTC pair is the sole LP.)

**Real constants (`goldmine_system.gd`):** `STOCKPILE_LP_MATCH_PCT = 0.10`
(10% of BTC mining → wBTC for the LP match), `RESERVE_FORFEIT_SPLIT = 0.50`
(50/50 split between Melt and Strategic Reserve for forfeited GOLD).

## The 3D shooter/RPG encounter

A cavernous warehouse depot: pallets of GOLD, wBTC crates, a central
**Pairing Rig** and two output chutes labelled **BURN** and **LP INJECT**.
1. **Match (real mechanic):** interact with the Pairing Rig → pair forfeited
   GOLD (from earlier chambers' early-claims, via `auction_gold_pool`/reserve)
   with wBTC at the `STOCKPILE_LP_MATCH_PCT` ratio.
2. **Burn vs LP decision (real mechanic):** route each matched batch down
   BURN (deflation, supply reduction) or LP INJECT (deepens the GOLD/wBTC
   pool). The `RESERVE_FORFEIT_SPLIT = 0.50` is the WP's default 50/50 — the
   player's routing choice dramatizes that split as agency.
3. **Defend the depot (proposed):** while batches process, thieves try to
   raid pallets; the player defends (pickaxe/ranged) to avoid losing GOLD
   before it's paired.

**Reward on exit:** LP depth and/or burn totals updated; supply-reduction
contributes to any deflation-based scoring (OPEN QUESTION).

## Enemies / threats (PROPOSED — not in WP)
Depot raiders on a spawn timer. Combat-required vs optional: OPEN QUESTION.

## Open questions
- Does the burn/LP choice have a mechanical payoff to the player, or is it
  purely protocol-flavour? (WP frames it as protocol behaviour, not a user
  reward — must not invent a reward that isn't there.)
