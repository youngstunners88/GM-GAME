<!-- dispatched: moonshotai/kimi-k3
     prompt: artifacts/dispatch_2026-08-22_boss13/01_KIMI.md
     files inlined: 0
     tokens: 930 in / 6732 out
     cost: $0.1038
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Rise at g=980 (rise = v²/2g = v²/1960)

| velocity | rise (px) |
|---|---|
| -620 | 196.1 |
| -630 | 202.5 |
| -560 | 160.0 |
| -570 | 165.8 |

| combo (leap + air) | total rise |
|---|---|
| -620 + -560 | 356.1 |
| -620 + -570 | 361.9 |
| -630 + -570 | 368.3 |

Note: air jump is allowed at v.y > -120. If it fires at that threshold instead of apex, the leap's remaining 120²/1960 ≈ 7.3 px is discarded → totals 348.8 / 354.6 / 361.0.

## 2. Boss 1, Level 1 — feet at y=650, single leap only

| obstacle | top y | rise needed | -620 (196.1) | -630 (202.5) | flag |
|---|---|---|---|---|---|
| platform (300,500,100,20) | 500 | 150 | ✓ | ✓ | |
| platform (500,400,100,20) | 400 | 250 | ✗ | ✗ | |
| platform (750,350,120,20) | 350 | 300 | ✗ | ✗ | |
| **platform (1100,450,100,20)** | 450 | **200** | **✗ short 3.9** | **✓ margin 2.5** | ⚑ flips |
| platform (1400,350,100,20) | 350 | 300 | ✗ | ✗ | |
| platform (1700,400,150,20) | 400 | 250 | ✗ | ✗ | |
| platform (2100,300,100,20) | 300 | 350 | ✗ | ✗ | |
| platform (2600,350,100,20) | 350 | 300 | ✗ | ✗ | |
| breakables ×5 (850/950/1350/1750/1850, 500) | 500 | 150 | ✓ | ✓ | |
| checkpoints ×2 (1100/2200, 500) | 500 | 150 | ✓ | ✓ | |

(1100,450) is the **only** obstacle where -620 vs -630 changes the answer. With air jump added (≥356 total), everything on this list clears regardless of either constant.

## 3. Boss 3, Level 3 east wall

| | arithmetic | result |
|---|---|---|
| (a) overlap? | body x-span at clamp = [4376−140, 4376+140] = [4236, 4516]; wall x-span = [4390, 4410]. 4516 > 4390 → body protrudes 4516−4390 = **126 px past the wall face**; the wall's full 20 px thickness sits inside the body | **Yes, necessarily overlaps** |
| (b) is_on_wall() every frame? | while centre ≥ 4250 (right edge ≥ 4390) the bodies interpenetrate, so each move_and_slide() depenetrates against a horizontal-normal contact and reports a wall hit | **Yes, on every frame while overlapped** (grounded or not) |
| (c) does -630 change it? | hop velocity is vertical; clamp, body width, wall x-span are horizontal | **No** — 196.1 vs 202.5 rise doesn't touch x-geometry |

## 4. Verdicts

| change | verdict |
|---|---|
| -620 → **-630** (LEAP / HOP) | **JUSTIFIED** — platform (1100,450): needs 200, -620 gives 196.1 (short 3.9), -630 gives 202.5 (clears). For Boss 3's flat arena: no obstacle in the 196–202 band and wall top (y=100) needs 550 — no effect there. |
| -560 → **-570** (AIR_JUMP / AIR_HOP) | **JUSTIFIED only in the late-trigger case** — platform (2100,300) needs 350: if air jump fires at the v.y=-120 threshold, (-620,-560) totals 348.8 (fails) vs (-620,-570) 354.6 (clears). Fired at apex, (-620,-560) already clears (356.1 ≥ 350) → no measurable effect. |