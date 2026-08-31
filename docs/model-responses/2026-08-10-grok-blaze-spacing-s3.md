<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-blaze-spacing-s3-clutter.md
     files inlined: 2
     tokens: 23199 in / 4230 out
     cost: $0.0718
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## Task A — Band spacing audit

**Missing for exact per-level X tables:** `BlazeRushLayouts` (course `length` + gap list per level) and runtime texture sizes for wide/founder art (`half_w`). Below is the placement model from `blaze_rush.gd` only; numeric X/spans need those inputs.

### Placement order (reservations)
1. `_build_world_card()` — anchor `WORLD_CARD_X = 400`, then `_find_band_slot` + `_reserve_band_span`
2. `_build_lounge_banner()` — anchor near finish (`_course_length + FINISH_TRIGGER_OFFSET - FINISH_CLEARANCE`), search + reserve
3. `_build_protocol_landmarks()` — `BR_ART_ORDER` lattice; each success reserves

### Landmark maths (`_landmark_slot_x`, ~L556–591)
```
span  = max(course_length - 300 - 700, 1)   # LANDMARK_END_MARGIN, LANDMARK_START_X
pitch = span / count                        # count = available art (~10)
ideal = 700 + pitch * (i + 0.5)
min_sep = max(190 * 1.15, pitch * 0.6)      # BAND_ART_SIZE
```
Search: ideal, then ±0.25·pitch … (±2·pitch). Reject if over gap, `!_band_span_free`, or within `min_sep` of a placed X. Else INF → fallback `_find_band_slot(700, half_w)`.

### 1) Expected sequence (structural)

| # | BR_ART_ORDER entry | Ideal X (no gaps/collisions) |
|---|--------------------|------------------------------|
| WC | world card (not in list) | ~400 (fixed anchor + nudge) |
| 0 | badge_lilblunt | `700 + pitch·0.5` |
| 1 | badge_diamonds | `700 + pitch·1.5` |
| 2 | br_robinhood (wide) | `700 + pitch·2.5` |
| 3 | badge_smokering | `700 + pitch·3.5` |
| 4 | badge_hood | `700 + pitch·4.5` |
| 5 | br_diamond_certificate (wide) | `700 + pitch·5.5` |
| 6 | blaze_diamond_correct | `700 + pitch·6.5` |
| 7 | badge_goldmine | `700 + pitch·7.5` |
| 8 | badge_h420 | `700 + pitch·8.5` |
| 9 | br_smoke_lounge_car (wide)* | `700 + pitch·9.5` |
| EB | lounge banner (not in list) | near `course_length+30 − half_w` |

\*Dropped from landmarks if `LOUNGE_BANNER_ART` exists (L779–781).

**Gap between consecutive lattice centers ≈ `pitch`.**  
Empty clear air ≈ `pitch − half_w_i − half_w_{i+1}` (plus `BAND_ART_PAD` only in reservation tests).

**Flag `pitch > 500` (center span > 500 always):**

| Level | Condition | pitch | spans > 500 |
|-------|-----------|-------|-------------|
| L1 | comment: length **5450** → span `4450` | **445** | center pitch OK; edge WC→#0 and #last→banner can still exceed 500 after reserves/gaps |
| L2 | unknown length L | `(L−1000)/n` | **all consecutive pairs** if `L > 1000 + 500·n` (n=10 → **L > 6000**) |
| L3 | same | same | same |

Without `BlazeRushLayouts.get_layout(2/3)` lengths/gaps, exact X lists and per-pair px empties cannot be honest numbers.

### 2) Why L2/L3 read sparser than L1
1. **Stride scales with course length** — same `count`, fixed `LANDMARK_START_X`/`LANDMARK_END_MARGIN`; longer L2/L3 ⇒ larger `pitch` ⇒ larger empty band between pieces (no density cap).
2. **Fixed end-piece anchors** — title @ ~400 and banner @ finish bite reservations; lattice still spans full `[700, length−300]`, so interior pitch does not tighten when ends are claimed.
3. **Gap displacement** — more/longer voids ⇒ ± search + `min_sep` pushes pieces off lattice; fallback `_find_band_slot` from **700** packs **left**, leaving a **long empty tail** before the banner (classic “sparse end”).
4. **Not** an early shared bail on L2/L3 specifically — same code path; sparsity is length + gaps + leftward fallback, not a level branch.

### 3) Reflow strategy (fit existing shape)

**A. Cap lattice pitch (minimal diff)** in `_landmark_slot_x`:
- After `pitch = span / count`, add e.g. `pitch = minf(pitch, 420.0)` and recompute `span_used = pitch * count`, center the block in `[LANDMARK_START_X, course_length - LANDMARK_END_MARGIN]`  
  - or set `LANDMARK_END_MARGIN` dynamically so usable span = `min(old_span, pitch_cap * count)`.

**B. Prefer proportional + nearest-free (as requested)** — replace ideal line (~L561–562):
```gdscript
# old: ideal = LANDMARK_START_X + pitch * (float(i) + 0.5)
# new: usable band after world-card/banner already reserved
var usable_lo := LANDMARK_START_X  # or first free > world card right
var usable_hi := _course_length - LANDMARK_END_MARGIN
ideal = usable_lo + (usable_hi - usable_lo) * (float(i) + 1.0) / float(count + 1)
```
Keep gap / `_band_span_free` / `min_sep` search; keep INF → `_find_band_slot`.

**C. Constants (only if you want denser pack without pitch cap code):**

| Constant | Old | New | Effect |
|----------|-----|-----|--------|
| `LANDMARK_START_X` | `700.0` | `520.0` | starts after title sooner (watch world-card half_w + pad) |
| `LANDMARK_END_MARGIN` | `300.0` | `180.0` | lattice reaches closer to banner (banner still reserved) |
| `BAND_ART_PAD` | `26.0` | keep | do not shrink enough to allow overlap |
| `min_sep` factor `pitch * 0.6` | in `_landmark_slot_x` | `minf(pitch*0.6, 280.0)` or `pitch*0.45` | less false “crowded” on long pitches |

Do **not** stretch sprites (`scale` stays height/box fit). Do **not** move banner off end anchor or title off early anchor — only free-slot nudge as now.

**D. Fallback direction:** change last-resort `_find_band_slot(LANDMARK_START_X, …)` to `_find_band_slot(ideal, …)` so displaced pieces stay near their fraction instead of all stacking from 700 (fixes empty right half on gappy L2/L3).

### 4) Silent-drop paths (no `push_warning`)
| Location | Condition |
|----------|-----------|
| `_build_world_card` L615–616 | missing `WORLD_CARD_ART` |
| L617–619 | `load` null |
| L625–626 | `_find_band_slot` → INF |
| `_build_lounge_banner` L708–709 | `_find_band_slot` → INF |
| `_build_protocol_landmarks` L774–775 | `ResourceLoader.exists` false — skip entry |
| L779–781 | legacy lowrider skipped when founder banner exists (intentional) |
| L786–788 | `load` null |
| L804–812 | only path with **warning**; double-INF continues |

---

## Task B — Stage 3 clutter (`level_03_gold_rush.gd` only)

**Missing for full stage prop audit:** `level_03_data.tres` / `LevelBase` tile/deco spawns. Below = this file only.

### 5) Decorative / prop spawns

| What | Lines | Gameplay? | Verdict |
|------|-------|-----------|---------|
| Ambient dust `CPUParticles2D` ×6 | 24–45 (`_setup_ambient_dust`) | No — pure VFX | **KEEP** — gold dust, fits canyon; only atmosphere here |
| `GoldGate` timed_door | 58–61 | Yes | KEEP (not deco) |
| Pressure plate | 65–68 | Yes | KEEP |
| One-way platforms ×4 | 69–76 | Yes | KEEP |
| `coin` ×8 | 77–78 | Yes | KEEP |
| `coin_goldmine` ×4 | 82 | Yes — **do not touch** | KEEP |
| Ladder | 90–94 | Yes | KEEP |
| Secret walls ×3 | 96–99 | Yes (explorer) | KEEP |
| Fort Knox `hall_of_blaze` | 105–108 | Yes (gated room) | KEEP |
| Boss spawn path | 110–138 | Yes | KEEP |

**CUT candidates in this file:** none mandatory. Only functionless spawns are dust → keep.  
If the stage still feels “shitty”, clutter is almost certainly in **level data / LevelBase props**, not this script — that file set was not provided.

### 6) Palette clashes in this file
- Dust color `Color(1.0, 0.82, 0.35, 0.22)` L44 — gold; OK  
- Deck tint `Color(0.95, 0.8, 0.3, 1.0)` L76 — gold; OK  
- No orange/green/magenta leftover realm colors in this file.

---

**Bottom line:** L2/L3 sparsity is almost certainly **pitch ∝ course length** plus **left-packing fallback** after gaps, not missing art config. Wire proportional `ideal` + search-from-`ideal` fallback (and optional pitch cap). Exact 10-wide X/span tables need `BlazeRushLayouts` + asset pixel sizes. Stage 3 script has no functionless props worth cutting except optional dust (recommend keep); broader declutter needs level data.