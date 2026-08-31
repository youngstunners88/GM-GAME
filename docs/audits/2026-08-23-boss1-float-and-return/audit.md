# Audit — Stage 1: Auditor float + player stage-end soft-lock (2026-08-23)

Founder, hard-refresh: (1) "The 1st boss is still fucking floating" — unfightable.
(2) NEW: "Lil Blunt goes to the end of Stage 1 and gets stuck, cannot return."
Model tier: Fable (architecture + level geometry, not another constant).

## P0b — player soft-lock at stage end (fixed first, independent)

Measured with a walking (no-jump) player driven west from the stage end:
he walls at **exactly x=2800** against a 32x32 StaticBody2D at (2768,586),
World layer — a `secret_wall`. Level 1 places three flavour "smoke tip" secret
walls at (468,586)(1368,586)(2768,586). They floated at **y=586 — head height —
straddling the ground corridor** of a full-stage-HUNT level (no seal), so any
player without Blaze/pickaxe to smash them was blocked from returning west. The
Auditor already carried explicit collision exceptions for these same walls (the
boss half of the same mistake).

Fix: raised the three walls 586 -> 500, the same overhead height as this level's
breakable_blocks, which the player has walked under both directions for ~50
sessions with no report. The shimmer secret stays discoverable/smashable; it no
longer gates the corridor. Gate `level1_return_path_test` — proven to FAIL at
y=586 (walled at 2800) and PASS at y=500 (walking player reaches the return
target, walled_at=inf).

## P0a — Auditor "floating / unfightable"

### The trap (why every prior round failed)
On live master the checkpoint carried a solid `StandSurface` and LEAP was -620.
Prior rounds proved, by measurement, an unwinnable set of partial fixes:
- StandSurface solid → pins the boss at checkpoint x=2200, he pogos with feet
  above every platform = "floating" (parked-player case, ~46.8s frozen).
- StandSurface removed → strands him at a breakable block (hunt FAIL).
- LEAP -620→-630 (fix the 4px platform-clear deficit) → he climbs into pockets;
  BOTH gates regressed (hunt stuck 1335 frames, sky-float 2.8%→7.1%).

### The missing piece (Kimi K3, this round)
Given the raw level rectangles, Kimi found that even with the checkpoint and
breakable blocks handled, **two real floating platforms remain hard WALLS** to
the 220px boss on the ground chase lane: **(300,500)** and **(1100,450)** —
under-clearance 130px and 180px, both far less than his 220px body, so he can
neither duck under nor reliably mount them. Nobody had addressed the platforms
themselves.

### The fix — one-way collision, no arithmetic bump
Floating platforms and the checkpoint StandSurface are now **one-way**:
landable from above, passable horizontally and from below. Idiomatic platformer
behaviour. It removes every horizontal wall on the boss's ground lane without
deleting a single standable surface for the player, and lets the boss still
mount a platform from above to chase a player up top. Ground segments stay fully
solid. LEAP stays -620; the height cap is unchanged.

Grok 4.6 reviewed the set and ranked one-way StandSurface as load-bearing for
BOTH gates; the platform one-way is the same principle applied to Kimi's two
remaining walls. The proposed smash/vault additions turned out unnecessary —
one-way geometry alone greens both gates.

### Proof (both gates, real level_01)
| Gate | Metric | Result |
|---|---|---|
| sky-float (parked player) | sky frames | **0 / 3600** |
| | boss travel | **1992px** (start 2978 → 986) |
| | gap to parked player | **14px** (he reaches and catches) |
| | max freeze en route (>250px away) | **1.63s** (was ~46.8s) |
| hunt (fleeing player, whole route) | final gap | **15px** |
| | max stuck streak | 2.5s (< 5s bar) |

`auditor_no_sky_float_test` was upgraded from "PARTIALLY OPEN" to asserting all
three properties, including no-freeze-en-route (post-catch camping on a reached
parked player is excluded via a distance guard).

## Scope / risk
One-way floating platforms is a GLOBAL change (all levels). High-risk subset
(auditor platform-intelligence / real-arena-climb, distributor behaviour +
phase2 chase, claim_jumper moves, blaze lifecycle) all pass; full suite run
before ship. No LEAP change, no boss-smash, no vault — smaller blast radius than
any prior attempt.
