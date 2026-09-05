# Chamber 2 — Fort Knox Vault (Staking + Melt Bonus)

**White-paper element:** Fort Knox Staking. Stake GOLD into 88-day and
288-day pools to earn wBTC; **Melt** (voluntary burn of extra GOLD) raises
your share multiplier. (WP §Fund Allocation — 35% to Fort Knox pools.)

**Real constants (`goldmine_system.gd`):** `FORT_KNOX_SHORT_POOL_PCT = 0.60`
(day-88 pool), `FORT_KNOX_LONG_POOL_PCT = 0.40` (day-288 pool),
`MAX_TERM_BONUS_PCT = 1.00` (up to +100% for max lock length),
`MAX_MELT_RATIO = 3` (burn up to 3× staked GOLD), `MAX_MELT_BONUS_PCT = 9.00`
(+900% at 3× melt). Note framing: +900% *bonus* on top of the base share = a
**~1000% of-shares** multiplier, which is the founder table's "up to 1,000%
share multiplier." Same number, bonus-vs-total wording.

## The 3D shooter/RPG encounter

A massive fortified vault: blast doors, a central **Staking Terminal**, and a
**Melt Furnace** dominating the room.
1. **Stake (real mechanic):** interact with the terminal → deposit GOLD,
   choose lock length (short 88 / long 288). Longer lock = higher term bonus
   toward `MAX_TERM_BONUS_PCT`. Pools pay wBTC per the 60/40 split.
2. **Melt-under-fire (proposed):** feed extra GOLD into the Melt Furnace to
   climb the melt multiplier toward 3×/+900%. Each feed step is a commitment
   (burned GOLD is gone — real deflation). While feeding, the vault is under
   combat pressure (raiders trying to breach the blast door / interrupt the
   furnace), so pushing for the full 3× melt is a genuine risk.
3. **Hold the vault** until the stake locks in, then exit.

**Reward on exit:** wBTC credited per pool split × term bonus × melt
multiplier, all from the real constants. Burned GOLD removed from supply.

## Enemies / threats (PROPOSED — not in WP)
Vault raiders (breach the door on a timer); the furnace as a hazard if
overfed. Combat-required vs optional is an OPEN QUESTION.

## Open questions
- Map 88/288-day locks to what in-encounter duration?
- Does melt multiplier persist to the run's scoring, or only affect this
  chamber's wBTC payout?
