# Geometry audit — Lil Blunt Adventure, Stage 3 layout fairness + distinctness

BUDGET DISCIPLINE: answer question-by-question, a few sentences + numbers each.
Emit partial results rather than deliberating silently.

## What the game is
Godot 4.3 HTML5 platformer. I'm redesigning Stage 3's platform layout. You verify
JUMP FAIRNESS, WALKABILITY, DISTINCTNESS vs Stage 2, and that set-piece anchors
land on solid ground. You are NOT designing feel (another model does that) — you
are the math/collision checker.

## Player physics (exact — do not "correct")
- walk_speed 200, sprint ×1.2 → top speed 240 px/s.
- jump_force -430, gravity 1000 rising / 1650 falling (fall_gravity_mult 1.65),
  double_jump_force -370, max_fall_speed 720.
- Single-jump apex ≈ 92px; same-height horizontal reach ≈ 184px (240 × ~0.765s
  airtime). Double jump adds ~+130px horizontal but is NOT allowed to be required
  on the main path.
- Main ground surface y=650 (a platform's Vector4 is x,y,width,height; the
  walkable surface is at y, collision spans y..y+height).

## Rule set
1. **Main-path pit ≤ ~170px** (single-jump-legal from the lip, with margin). Flag
   any gap that needs a double jump on the main path.
2. **Main path walkable**: contiguous flat y=650 runs must have no invisible
   blocker. (Blockers come from level script props, not the data — call out if a
   listed set-piece x would sit as a collider ON a flat run.)
3. **Distinctness vs L2**: geometry >70% coordinate-shared with L2 = FAIL.
4. **Anchors on solid ground**: plate 1180, ladder base 1465, timed gate 1520
   (gap-edge OK, it's a pass-through door), vault door 2690 (bridged pit
   2620–2760), reserve 3420, boss arena 3700–4400, secret walls 868/2468/3068.

## Stage 2 ground_segments (for distinctness compare)
0..400 | 500..800 | 900..1400 | 1500..1900 | 2000..2400 | 2500..3000 | 3100..3500 | 3700..4400

## Current Stage 3 ground_segments (being replaced)
0..400 | 520..840 | 1020..1500 | 1600..1980 | 2200..2620 | 2760..3220 | 3380..3480 | 3700..4400
gaps: 120,180,100,220,140,160,220

## CANDIDATE Stage 3 ground_segments (verify this)
0..560 | 700..1180 | 1320..1520 | 1660..2200 | 2340..2620 | 2760..3300 | 3300..3560 | 3700..4400
(note 3300..3300 means 2760..3300 and 3300..3560 are CONTIGUOUS = one long 2760..3560 run)
gaps: 700-560=140 | 1320-1180=140 | gate gap 1660-1520=140 | 2340-2200=140 | vault pit 2760-2620=140 | (contiguous) | 3700-3560=140

## Questions
1. Compute each CANDIDATE main-path gap and confirm ≤170 and single-jump-legal at
   240px/s from the lip. Flag any that fail. Is 140px comfortable or tight?
2. Confirm every anchor x (1180,1465,1520,2690,3420,868,2468,3068) sits on a solid
   candidate segment (or, for 1520, correctly at the gate gap edge). List any that
   fall in a gap.
3. Distinctness: is the CANDIDATE <70% coordinate-shared with L2 (segment starts
   AND widths)? Give a rough shared-% and PASS/FAIL.
4. The candidate has 2760..3300 and 3300..3560 as separate entries but they touch
   (both y=650) → one continuous 2760..3560 (800px) run into a single 140px pit
   then the 3700..4400 arena. Confirm that reads as a "wide safe runway" and has
   no hidden 1px seam/overlap problem when two StaticBody segments abut exactly.
5. Any risk that abutting/exact-touching segments (e.g. 3300 shared endpoint)
   create a double-collider seam the player catches on? Recommend a safe gap or
   overlap convention.

## Output
Q1–Q5, numbers + PASS/FAIL each. Rank any fairness/walkability blockers first.
