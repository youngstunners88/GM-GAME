# Boss 1 (Auditor) — "walks through everything" (PR #53 regression), fixed by removing runtime phasing

**Date:** 2026-08-25
**Founder report (live hard-refresh):** "Lil Blunt lands on the platforms (good). The first boss now walks through EVERYTHING. Spacing is dead — worse than before."

## What PR #53 shipped, and why it was wrong

PR #53 made the floating platforms solid and gave the Auditor a **phasing wall-vault**: during a vault it added collision *exceptions* to the platforms so his 220px body could arc over the dense pocket geometry, then restored them. Every variant of that runtime collision-toggle failed, because **a 220px body cannot have its collision flipped mid-motion against 20px platforms without an artefact:**

Measured with a real-physics probe (body-vs-platform overlap, driving a fleeing player the whole stage):

| Phasing variant | Result |
|---|---|
| Phase the whole group for the arc | body inside a platform **26%** of the fight (ghosts the level) |
| Phase only the target ledge | **wedged inside a neighbour** he arced into — runaway downward velocity |
| Phase only while airborne, drain on land | unphased the instant he touched a deck → **sealed inside** it |

The shipped gates missed all of this because they measured **raycasts** (which ignore collision exceptions) and gap — so they went green while the live boss phased through platforms. That is exactly the founder's "gates pass, live is broken."

## Root reframe (from the measurement)

The Auditor's only real chase-lane **walls** are the three platforms whose band reaches his grounded body (feet 650, head 430): **(1100,450), (300,500), and the breakable block (1850,500).** Everything else sits **above his head** — a grounded boss never touches them; he only ever *clips their undersides mid-jump* (his east shoulder catching (2100,300) as he vaults the block was the original stall that drove the whole phasing idea).

## The fix — no runtime phasing at all

1. **Walls stay SOLID at all times.** They block him — that block *is* the founder's spacing/leverage — and there is now, by construction, **zero ground-level walk-through** of the platforms Lil Blunt hides behind.
2. **Overhead platforms get a one-time collision exception at spawn** (`_ready`), classified by geometry (bottom above his grounded head). They never affect his ground chase, and excepting them lets his jump-arc clear the walls without clipping their undersides and stalling.
3. **The vault is a purely SOLID sized jump** onto/over the wall (telegraphed wind-up first = the spacing beat), with forced horizontal commit. No collision is toggled during motion, so he can neither ghost the level nor wedge inside a deck.

All the fragile phasing machinery (`_phase_targets`, `_manage_vault_phasing`, `_overlapping_targets`, per-frame exception juggling) was **deleted**.

## Verification (real body-vs-wall collision, fleeing player)

| Metric | Broken (PR #53 live) | Now |
|---|---:|---:|
| Grounded body inside a spacing WALL | 26-83% | **0.0%** |
| Walls block him (planted beats) | — | **92** |
| Gap to a fled player | (ghosted) | **40px** |
| Wedge (runaway vy) | yes | none (max |vy| 617) |

Gates green: **auditor_solid_wall_traverse** (rewritten to measure the boss's actual BODY overlap against the real walls — a boss that ghosts them now FAILS, unlike the old raycast gate), auditor_full_stage_hunt, auditor_no_sky_float, auditor_no_runaway_climb, auditor_platform_intelligence, auditor_real_arena_climb, level1_return_path, player_solid_platform_land, time_scale_recovers, plus claim_jumper (Boss 3) regression checks.

## Honest limit

Overhead platforms are excepted, so when the boss **jumps**, his body passes through an overhead platform he is leaping past (reads as jumping, not ground-walking). He also cannot currently *stand on* an overhead platform to chase a player who climbs onto one — he pressures them with ranged clipboards instead. If the founder reports "he can't reach me on the high ledge," that is the next, separate piece of work; it is deliberately out of scope here, where the P0 is the ground-lane walk-through.
