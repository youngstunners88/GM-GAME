---
name: ep2-lake-investigate
description: Implement and test Logan’s short investigate-liquidity encounter, one distance-gated staging action, conserved inventory and downstream handoff.
---

# ep2-lake-investigate

Read the active lake lock/implementation contract. Logic is LogansLakeChamber, extending Ep2Interlude; entry is gold_town GEARED through Ep2SessionRoot. Do not create an unrelated third-person controller or silently refill/swap weapons.

ARRIVE: E/touch within 3.2 m meets Logan. INVESTIGATE: short lines explain staged depth and outflow, with readable captions. STAGE: one E/touch within 2.8 m checks already staged cargo. HANDOFF: visible confirmation and route up shore. OVERLOOK: visible shipment/outflow establishes day-88 direction. These distances/times are game tuning, never protocol values.

Use the same interaction dispatch for keyboard and touch, respect armory/pause/control state and reject input outside the current beat/range. Repeated input must not duplicate the stage action, mint rewards, debit currency or alter ammo. Avoid long locked cameras; keep the founder's firearm in view. Do not name a random generated voice as Logan's approved voice.

Gate tests/ep2_logans_lake_test.tscn and existing ep2_gold_town_test.tscn. Test illegal early/far interactions, spam, ordinary-movement reachability, stage exactly once, armory snapshot unchanged, slope/water bounds, and actual chain registration. Add a session-level assertion when changing transition payloads. Save/load extensions require save_compat_test and explicit version/default handling; do not pretend current session-only lake state is cross-session persistence.

The future river fight needs its own playable chamber and sniper/bear tests. The present lake's high overlook is the handoff; no end-screen wording should imply a completed battle.
