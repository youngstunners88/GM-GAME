# Boss 1 (Auditor) — solid spacing platforms + wall-vault chase

**Date:** 2026-08-24
**Branch:** `claude/owner-rage-l1-music-boss1-carts-chase`
**Founder reports (one directive, two halves):**
1. *"Lil Blunt can't land on the thicker solid platforms — he falls through them!"* (P0, screen recording).
2. *"The boss walks through the blocks — nothing Lil Blunt can leverage for distance, fight impossible. Still some flying."* + *"Spacing platforms must block the boss; he must still chase. Keep return path."*

## Root cause (single cause, both halves)

PR #52 made every Level 1 floating platform **one-way** (solid from above, passable
from the side) so the 220px Auditor could stop pinning on them. That one regressed
two things at once:

- **Player falls through** — a one-way plate only catches a body crossing its top
  surface downward; approached rising, clipped on the side, or on a fast fall that
  margin-tunnels the 20px-thick deck, the player passes straight through. That is
  the video.
- **Boss phases the blocks** — with the side collision gone, the two torso-height
  platforms stopped being walls, so the boss walked through them and the player had
  no geometry to gain distance behind.

## Why the tempting shortcut is wrong

Reverting to solid fixes the player instantly (proven: `player_solid_platform_land_test`,
all 8 platforms). But **plain solid strands the boss**: a real-physics probe
(`auditor_full_stage_hunt_test`) measured him pinned at x=1882 (west face against
the breakable block at 1850) for **2532 frames (42s)**, 1732px behind a fled player.
That is exactly the pre-#52 pin the one-way was introduced to cure.

A per-boss **collision exception** on the two walls (the other tempting shortcut)
was rejected on Grok 4.6's audit: *"ignore the two walls for the boss and he walks
through the only walls in the level … leverage is still zero. That is the reject
text."* It re-creates founder complaint #2, and the founder was explicit — the
platforms **must block** the boss.

Grok's ship rule is the real constraint:
> "You cannot have solid torso-height slabs vs a 220 one-shot body without either a
> pin or a traverse."

## The fix — a telegraphed, phasing wall-vault

Platforms go back to **fully SOLID** for everyone (player lands; boss is blocked =
leverage). The boss gets a real traverse:

1. **Wind-up (0.4s):** when a soft spacing platform / breakable block first blocks
   his ground chase, he PLANTS at it and telegraphs. That pause is the founder's
   "leverage for distance" — the wall genuinely stops him, on screen, every time.
2. **Sized vault:** he hops just over the ledge (rise measured by an upward
   full-body probe, capped at 250px so it can never become a sky-climb), with
   horizontal commit FORCED for the whole arc (the half the old leap lacked — the
   old leap's westward velocity was zeroed against the wall face, so at apex he had
   no commit and fell back = the pogo that read as "still flying").
3. **Phase during the arc only:** for the ~0.8s arc he temporarily excepts collision
   with the `boss_soft_platform` group, so his 220px body clears the dense pocket
   geometry (adjacent platforms) instead of clipping their undersides. Collisions
   restore the instant he is back on the ground AND clear of every platform (never
   while overlapping — re-solidifying inside a ledge makes the physics server
   depenetrate-teleport him up onto it; that exact teleport wedged him for 18s in an
   intermediate build and is the reason the un-phase is gated on `not _overlapping_soft`).

## Secondary blockers found by measurement (not guessed)

The full-stage probe surfaced two more walls that had nothing to do with platforms:

- **Mob enemies.** The boss's body `collision_mask` was 13 (World|Enemies|Collectibles),
  so a Tax Collector patrol standing on his lane physically stopped him (pinned at
  x=541 against a TaxCollector at (509,617)). A chasing boss should pass through
  mobs — dropped the Enemies bit from his mask (`set_collision_mask_value(3, false)`).
- **Ray-resolution miss.** The first `_blocking_is_soft` used 4 rays 33px apart,
  which straddled and MISSED the 20px-tall (300,500) platform, so `soft` read false
  and the vault never fired there (pinned at x=400). Rewrote both body probes to
  scan at 10px resolution.

## Incidental obstacles → permanent phase-through

The checkpoint **StandSurface** (invisible) is given a permanent boss exception —
a boss winding up to vault an invisible box reads as random jumping, and it is not
something Lil Blunt can hide behind. Breakable blocks stay `boss_soft_platform`
(he vaults them like a platform).

## Verification (headless real-physics)

| Gate | Before | After |
|---|---|---|
| `player_solid_platform_land_test` (8 platforms) | broken (parse err) / N/A | **ALL PASS** |
| `auditor_full_stage_hunt_test` | FAIL — stuck 2532f, gap 1732 | **ALL PASS** — gap 88, max stuck 93f |
| `auditor_no_sky_float_test` | (one-way) pass | **ALL PASS** — sky 0.0%, feet never above 416 |
| `auditor_solid_wall_traverse_test` (new, ungameable) | — | **PASS** (blocks + closes + no-fly + planted beats) |

The new gate encodes the tension both founder halves impose: it asserts the walls
BLOCK him (planted-at-a-wall beats > 0, measured from observable physics) **and**
that he still CLOSES the fled player **and** never floats — so a future
"collision exception" or "one-way" regression fails it on the leverage half, and a
"plain solid" regression fails it on the pin half.

## Models consulted before the edit (founder-mandated)

- **Kimi K3** — platform classification: exactly 2 torso-height walls, (300,500) &
  (1100,450); clearance arithmetic.
- **Grok 4.6** — the ship rule (pin-or-traverse), the reject of exception-only, and
  the ungameable-gate spec (measure phase, progress, air time — not layer flags).

The shipped design evolved past Grok's original "short kinematic vault" once the
probe showed a pure kinematic hop clips the pocket neighbours: the phasing-during-arc
element is the measured answer to that, kept honest by the gate above.
