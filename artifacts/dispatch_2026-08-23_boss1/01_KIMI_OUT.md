<!-- dispatched: moonshotai/kimi-k3
     prompt: artifacts/dispatch_2026-08-23_boss1/01_KIMI.md
     files inlined: 0
     tokens: 944 in / 7920 out
     cost: $0.1216
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Boss body band [430, 650] — all solids overlapping it in the ground lane

| Solid | x-range | y-span | Over ground? | Hard block? |
|---|---|---|---|---|
| platform (300,500,100,20) | 300–400 | 500–520 | yes (seg 0–400) | **YES** — under-clearance 130px < 220 |
| platform (1100,450,100,20) | 1100–1200 | 450–470 | yes (seg 900–1300) | **YES** — under-clearance 180px < 220 |
| checkpoint (1100,500,32,48) | 1100–1132 | 500–548 | yes | yes |
| checkpoint (2200,500,32,48) | 2200–2232 | 500–548 | overhangs gap 2200–2300 | yes |
| breakable (850,500) | 850–882 | 500–532 | over gap 800–900 | yes |
| breakable (950,500) | 950–982 | 500–532 | yes | yes |
| breakable (1350,500) | 1350–1382 | 500–532 | over gap 1300–1400 | yes |
| breakable (1750,500) | 1750–1782 | 500–532 | yes | yes |
| breakable (1850,500) | 1850–1882 | 500–532 | over gap 1800–1900 | yes |
| secret walls ×3 | — | 586–618 | yes | (removed) |

**Answer: No.** Platforms **(300,500)** and **(1100,450)** are also hard vertical obstacles — both are solid, both intersect [430,650], neither can be ducked under. Platforms (500,400) and (1700,400) clear his head by exactly 10px (bottom 420 vs head 430) — not blockers.

## 2. After one-way checkpoints + smashable breakables — remaining blockers?

| Obstacle | Blocker? |
|---|---|
| checkpoint (1100,500) | No — one-way, passable horizontally |
| checkpoint (2200,500) | No — one-way |
| breakable (850,500) | No — smashed |
| breakable (950,500) | No — smashed |
| breakable (1350,500) | No — smashed |
| breakable (1750,500) | No — smashed |
| breakable (1850,500) | No — smashed |
| **platform (300,500,100,20)** | **YES** — still solid, 500–520 in band |
| **platform (1100,450,100,20)** | **YES** — still solid, 450–470 in band |

**Yes, two remain.** Both platforms must also go one-way (which also enables the Q3 mount-through-from-below) or the westward ground lane is sealed at x=300–400 and x=1100–1200.

## 3. Exact LEAP for 200px, and stacked total

| Quantity | Formula | Value |
|---|---|---|
| LEAP for exactly 200px | √(2·980·200) = √392000 | **−626.1** (−626 → 199.94px, −627 → 200.58px) |
| Rise to air-jump threshold (v.y = −120) | (626.1² − 120²)/1960 = 377600/1960 | 192.65px |
| Air-jump rise (−560) | 560²/1960 | 160.00px |
| **Stacked total (fired at threshold)** | 192.65 + 160 | **352.65px** |
| Stacked ceiling (fired at apex, v.y=0 still > −120) | 200 + 160 | 360.00px |

Flag: −626.1 sits inside the 6.4px window between "misses by 4px" (196.1) and the regressed −630 (202.5). The regression was geometry (pockets), not arithmetic — exact-200 doesn't guarantee avoidance. Conditional mounting (leap only when player is on 1100,450) is the safe trigger; the number above is just the clearance math.

## 4. Player (28px, band [622,650]) walking west x=3350 → x=100, no jump

| Check | Result |
|---|---|
| Platforms (lowest bottom: 520) | no overlap |
| Breakables (bottom 532) | no overlap — 118px clearance |
| Checkpoints (bottom 548) | no overlap — 102px clearance |
| Secret walls (586–618) | no overlap even before removal (618 < 622) — they only ever blocked the boss |
| Ground tops (650) | feet rest on top, no overlap |

**Yes — free of solid blockers. Remaining solid blockers: none.**
Non-solid caveat: five 100px ground gaps at x 400–500, 800–900, 1300–1400, 1800–1900, 2200–2300 interrupt a pure no-jump walk (pits, not solids).