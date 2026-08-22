<!-- dispatched: moonshotai/kimi-k3
     prompt: artifacts/boss1_float_dispatch/01_KIMI.md
     files inlined: 0
     tokens: 829 in / 7267 out
     cost: $0.1115
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**1. Yes.** `position=(110,110)` minus half-extent (110,110) puts the box at (0,0)→(220,220) relative to the body origin, so the bottom edge is `origin.y + 220`.

**2.** Rise₁ = 620² / (2·980) ≈ **196 px**. Rise₂ = 560² / (2·980) ≈ **160 px**. Total ≈ **356 px** (the `vy > -120` gate fires late on the up-arc, so nearly the full second rise counts). Block top 500 vs ground top 650 = only **150 px** needed — he clears it easily, even on jump₁ alone. Something other than rise is failing.

**3.** His body band at feet=650 is y ∈ [430, 650]. Blockers (y-range overlapping the band):

- platform (300,500): spans x 300–400 → stop **x = 80** (→) / **x = 400** (←)
- block (850,500): spans 850–882 → **630** (→) / **882** (←)
- block (950,500): spans 950–982 → **730** (→) / **982** (←)
- checkpoint+platform at 1100: spans 1100–1200 → **880** (→) / **1200** (←)
- block (1350,500): spans 1350–1382 → **1130** (→) / **1382** (←)
- block (1750,500): spans 1750–1782 → **1530** (→) / **1782** (←)
- block (1850,500): spans 1850–1882 → **1630** (→) / **1882** (←)
- checkpoint (2200,500): spans 2200–2232 → **1980** (→) / **2232** (←)

Platforms (500,400), (750,350), (1400,350), (1700,400) bottom at 420 < 430, and (2100,300), (2600,350): he walks **under** those — no stop. (Moving right, stop when `origin.x = obstacle.left − 220`; moving left, when `origin.x = obstacle.right`. Your logged "2200" looks like a right-edge/contact-edge value, not origin-x.)

**4.** Each candidate:
- 400–500 (100 px): **No fall-in.** 220-wide body always overlaps a floor edge across a 100-px gap.
- 800–900 (100 px): **No fall-in.** Same reason.
- 1300–1400 (100 px): **No fall-in.** Same reason.
- 1800–1900 (100 px): **No fall-in.** Same reason.
- 2200–2300 (100 px): **No fall-in.** Same reason.
- x=2800: **No gap** — segments join contiguously.

All gaps are 100 px < 220 px body width, so corner-support keeps him up; the 215 px/s walk speed doesn't change that.