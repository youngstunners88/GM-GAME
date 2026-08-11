<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-chase-numbers.md
     files inlined: 2
     tokens: 11336 in / 10927 out
     cost: $0.1979
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# Verdict: DISPROVEN — the boss cannot reliably catch a sprinting player, and at the arena's left edge it *never* can. The founder's report is reproducible from the constants alone.

## 1. Effective pursuit speed per state (cap = HOVER_MAX × scale; HOVER_MAX = 330)

| State | Scale | Cap (px/s) | vs 240 | Margin |
|---|---|---|---|---|
| PATROL | 1.00 | 330.0 | PASS | +90 |
| GRAVITY_TELL | 0.62 | 204.6 | FAIL | −35.4 |
| HOARD_GRAVITY | 0.55 | 181.5 | FAIL | −58.5 |
| SHARD_THROW | 0.70 | 231.0 | FAIL | −9.0 |
| VULNERABLE | brake | 0.0 | FAIL (by design) | −240 |

Note: HOVER_ACCEL = 430 → 0.56 s from rest just to reach 240, 0.77 s to reach 330. Caps overstate in-window speed after every VULNERABLE exit.

## 2. Fraction of one cycle slower than 240 (Phase 1, steady state)

Cycle: PATROL 1.5 → TELL 0.65 → HOARD 1.4 → PATROL 1.5 → THROW 0.45 → VULNERABLE 1.6 = **7.1 s**

| | Seconds |
|---|---|
| ≥240 (PATROL only) | 3.0 |
| <240 (0.65+1.4+0.45+1.6) | 4.1 |
| **Fraction slow** | **4.1 / 7.1 = 57.7%** (≈62% with accel ramps; Phase 3: 4.05/6.45 = 62.8% by caps) |

Net drift vs a player fleeing at 240 in a straight line (Phase 1, caps):
+270 − 23.0 − 81.9 − 4.1 − 384 = **−223 px per cycle** (avg −31 px/s). On an infinite runway the boss falls behind forever. Only the 700 px arena wall makes "catching" possible at all — see §3.

## 3. Reachable x-range: visible centre vs player

Clamp acts on **origin** (top-left): origin.x ∈ [3700+90, 4400−90] = **[3790, 4310]**
Centre = origin.x + 120 → **centre.x ∈ [3910, 4430]**
Player x ∈ [3700, 4400] (arena walls; player collision half-width not provided — flagged below).

| Edge | Arithmetic | Result |
|---|---|---|
| Left pin zone | target.x = player.x < 3790 → origin frozen at 3790 | Player anywhere in **x ∈ [3700, 3790)** pins the boss — a **90 px** column |
| Left untouchable zone | boss body left edge min = 3790; contact needs player_right_edge ≥ 3790 | Player fully left of 3790 − w (w = player width, not provided) can **never** be touched |
| Left centre gap | 3910 − 3700 = **210 px** | Closest the visible centre ever gets to a left-wall player |
| Right overhang | body right edge max = 4310 + 240 = **4550** = end_x + 150; centre max 4430 = end_x + 130 | No dead zone; player at 4400 is inside body span [4310, 4550] → contact ✓, but body clips 150 px into/past the wall |

**Precise "motionless" spot:** player standing at the left wall, x ∈ [3700, 3790). Boss origin clamps at (3790, player.y − 300); x-motion is deleted by the clamp every frame → sprite hangs at a fixed x, 210 px of centre separation, forever. This is the live "boss not moving / not chasing."

Root cause: the ±90 margins were written for a centred origin; the origin is top-left, so the body shifts the effective box 120 px right — 90 < 120 on the left (dead zone), 90 + 240 on the right (overhang).

Vertical, same class of bug: origin.y clamp [180, 620] → body bottom can reach 860, i.e. 260 px below the y=600 floor. Pursuit target (player.y − 300 ≈ 300) never drives it there, so cosmetic risk only.

## 4. Velocity on clamp: NOT zeroed

`_clamp_to_arena()` writes `global_position` only. `velocity` keeps saturating at cap (move_toward holds it at HOVER_MAX × scale) pointing into the boundary.

| Consequence | Number |
|---|---|
| Per-frame attempted penetration, reverted by teleport | 330 px/s ÷ 60 fps = **5.5 px/frame** |
| `is_on_wall()` / slide response from clamp | none (teleport, not collision) |
| Exit from pin when player re-enters range | instant full 330 px/s (no spool-up — the one benign effect) |
| Arrival damping | none — within ~5.5 px of target the boss oscillates ±v·dt; on a clamped axis this reads as frozen, on the free axis as jitter |
| Latent risk | any future velocity-driven cosmetic reads max while visibly still; if `arena_max == ZERO` ever disables the clamp, stored velocity applies in full |

## 5. Minimum numeric changes

| # | Constant | From → To | Why |
|---|---|---|---|
| 1 | `HOVER_MAX` | **330 → 480** | Slowest pursuit state must beat sprint: 240 / 0.55 = 436.4 floor; 480 gives HOARD 264, TELL 297.6, THROW 336, PATROL 480 — all > 240. (Alternative: keep 330, raise scales TELL/HOARD/THROW to 0.80 → 264 each.) |
| 2 | `arena_min.x` / `arena_max.x` (level code) | **3790 → 3700** (`start_x`), **4310 → 4160** (`end_x − BODY`) | Origin clamp that keeps the 240-wide body exactly inside [3700, 4400]: kills the 90 px left dead zone *and* the 150 px right overhang. Centre range becomes [3820, 4280]; every player x is reachable by the body. |
| 3 (recommended) | `HOVER_ACCEL` | 430 → 900 | Reaches 240 in 0.27 s instead of 0.56 s after each VULNERABLE exit |
| 4 (design call) | `pull_speed` | 130 → ≥260 if the pull must beat a sprinter (currently 130–195 < 240: sprint always escapes, all phases) | Otherwise document as intended counter-play |
| 5 (hygiene) | zero the clamped velocity component in `_clamp_to_arena` | — | Removes the 5.5 px/frame wall-pumping and stale-velocity state |

With #1 + #2 alone: every pursuing state outruns 240, and no arena position pins the boss — catch becomes arithmetic, not geography.

## Missing data (not guessed)
- **Player collision width/height and origin offset** — needed to size the exact untouchable strip in §3 (90 px − player width) and to rule on hover contact: body bottom sits at player.y − 60, so if the player origin is at the feet and the collider is taller than 60 px, the hover itself already overlaps the player's head; if not, contact is impossible without a jump or the pull, and no speed value fixes that.
- **Entry-wall x-position** from `arm_boss_arena_seal()` (assumed ≈ start_x = 3700 for the player range above).