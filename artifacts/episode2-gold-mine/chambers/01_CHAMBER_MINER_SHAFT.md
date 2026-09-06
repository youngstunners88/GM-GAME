# Chamber 1 — Miner Shaft (GOLD Mining)

**White-paper element:** GOLD Mining. Start a fixed **100-day Miner**, pay with
ETH (optionally Diamonds), earn GOLD at **1%/day**, may claim early forfeiting
the unvested remainder. (WP `docs/whitepapers/GoldMine.md` §Overview.)

**Real constants (from `src/autoload/goldmine_system.gd` — do not invent):**
`MINER_VESTING_DAYS = 100`, earn rate 1%/day, `DIAMOND_BURN_PCT = 0.20` (20%
of Diamonds paid are permanently burned), early claim forfeits unvested GOLD
into the per-level `auction_gold_pool`.

## The 3D shooter/RPG encounter

A working industrial mine shaft: drill rigs, ore chutes, a central **Miner
Rig** console. Lil Blunt enters from the runner track.

**Objective:** start a Miner and keep it running to a claim point.
1. **Interact** with the Miner Rig → choose payment (ETH, or ETH+Diamonds for
   a faster/heavier miner). This is a real protocol choice, dramatized.
2. **Vesting-under-pressure (proposed):** while the rig spins up its yield
   bar (a compressed stand-in for the 100-day / 1%-day vest — 1 in-game bar =
   the 100-day curve), the chamber applies pressure the player must survive:
   collapsing supports, ore-cart hazards, and/or Tax-Collector-lineage
   enemies trying to sabotage the rig (pickaxe melee + ranged weapon).
3. **Claim decision (real mechanic):** an **Early Claim** lever is always
   available. Pull early = take partial GOLD now, **forfeit the unvested
   remainder** (visibly dumped into the auction pool). Hold to full vest =
   full GOLD, but longer under pressure. This is the white paper's actual
   early-claim-forfeit tradeoff made into a risk/reward combat decision.

**Reward on exit:** GOLD credited to the shared balance per how far the vest
bar filled; any forfeited portion routed to `auction_gold_pool` (feeds
Chamber 3). 20% of any Diamonds spent are burned per `DIAMOND_BURN_PCT`.

## Enemies / threats (PROPOSED — not in WP; for founder review)
Sabotage drones or Tax-lineage grunts; environmental (support collapse, ore
carts). Whether combat is mandatory or optional is an OPEN QUESTION.

## Open questions
- Time-compression ratio for the 100-day vest into one encounter.
- Is combat required, or can a pacifist player just defend the rig?
