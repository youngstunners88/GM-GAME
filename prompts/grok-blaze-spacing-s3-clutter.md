# Task A: Blaze Rush band spacing audit (Levels 2 and 3)

The founder says: "large empty real estate = money left on the table." The purple
Blaze Rush band carries protocol badges + wide art + a world title card + an end
banner. On L2/L3 there are large empty spans between pieces.

Rules that must NOT be broken:
- No two pieces may overlap (a shared reservation ledger `_band_reservations` enforces this).
- No piece may sit over a void/gap in the course floor.
- Scale must stay proportional (no stretching to fill).
- The end banner must stay near the course end; the world title card stays at its anchor.

@include src/dashmode/blaze_rush.gd

## Deliver
1. Trace the placement maths and list, per level (1/2/3), the expected sequence of
   x positions each of the 10 `BR_ART_ORDER` entries lands on, and the empty span
   (px) between consecutive pieces. Flag every span > 500 px.
2. Explain specifically WHY L2 and L3 end up sparser than L1 (course length? slot
   stride? landmark start x? early bail from the slot finder?).
3. Give a concrete reflow strategy: exact constants to change (names + old -> new)
   so the pieces distribute evenly across the whole usable band without overlap and
   without landing over voids. Prefer a proportional distribution (piece i at
   fraction i/(n+1) of usable length) with a nearest-free-slot fallback, if that fits
   the existing code shape.
4. Name any silent-drop path where a piece can vanish without a warning.

# Task B: Stage 3 visual clutter

Founder: Stage 3 design "still shitty". Remove functionless clutter. If a prop is
unclear, REMOVE it rather than invent lore for it. Do NOT touch the GoldMine
protocol tokens (he likes those).

@include src/level/level_03_gold_rush.gd

## Deliver
5. A list of every decorative/prop spawn in Stage 3 that has NO gameplay function,
   with file line refs, classified: KEEP (reads clearly + fits Wild West gold-rush
   palette) / CUT (functionless or unclear).
6. Any prop whose colour clashes with the gold/brown palette (e.g. leftover orange
   or green from another realm), with the specific line.

Be concrete and cite line numbers. No filler.
