# Design brief — Lil Blunt Adventure, Stage 3 "Gold Rush" layout + identity

## What the game is
Godot 4.3 HTML5 2D platformer marketing three crypto protocols. Stage 3 is the
**Gold Rush / GoldMine** stage (Wild-West gold-mine theme, dark brown/rust body,
gold lip, Bitcoin-orange accents, gold-dust motes, mine-cart + Fort Knox). The
founder has REPEATEDLY rejected Stage 3's platform layout as "shitty" — his core
complaint is that it reads as **Stage 2 (Crystal Caverns) crystal-stepping with
gold paint**, not its own Gold-Rush rhythm.

## The problem, concretely
Stage 3 and Stage 2 both use 8 ground segments + 11 floating platforms with the
same alternating up/down "stepping" cadence and near-identical spacing. It's a
mild reskin. Your job: define a Gold-Rush **rhythm** that is unmistakably its own
thing, while keeping fixed set-piece anchors and jump fairness.

## Fixed facts you must NOT change or "correct"
- Godot 4.3. Main ground surface is y=650; level width (bounds.x) = 4400.
- Player: top speed 240 px/s (walk 200 × sprint 1.2); single-jump apex ~92px,
  same-height horizontal reach ~184px; has a double jump (~+130px more) but the
  MAIN PATH must be clearable with a SINGLE jump from the lip (double jump is for
  optional/secret routes only). So **main-path pits must be ≤ ~170px**.
- Set-piece anchors that MUST stay on solid ground and reachable (do not move
  their x): pressure plate x≈1180, timed Gold Gate x≈1520 (sits at a gap edge —
  you run through it), ladder base x≈1465, Fort Knox vault door x≈2690 (a bridged
  pit 2620–2760), Gold Rush Reserve room x≈3420, boss arena x=3700–4400.
- Secret walls sit at x≈868, 2468, 3068 (need ground beneath).
- Keep every gameplay object functional; no new art.

## Current Stage 3 geometry (the thing being replaced)
ground_segments (x, y=650, width, h=70):
0..400 | 520..840 | 1020..1500 | 1600..1980 | 2200..2620 | 2760..3220 | 3380..3480 | 3700..4400
(gaps: 120,180,100,220,140,160,220 — two 220px gaps EXCEED single-jump reach = unfair)
platforms: 11 floating decks alternating y 250–480, evenly ~300px apart (L2-like stepping).

## My CANDIDATE redesign — critique + improve it (don't rubber-stamp)
Goal rhythm: long walkable "claim-road" runs, purposeful height changes that
serve set-pieces (timed-gate climb, vault descent), and a WIDE safe runway into
the boss arena so the chase reads.

Candidate ground_segments (all y=650, h=70), gaps kept ≤160:
- 0..560 (560) opening claim road  | gap 140
- 700..1180 (480) mine road → plate at 1180 at its end | gap 140
- 1320..1520 (200) timed-gate approach (rises via platforms) | gate gap 1520..1660
- 1660..2200 (540) post-gate claim trail | gap 140
- 2340..2620 (280) vault approach ledge | vault pit 2620..2760 (bridged, door 2690)
- 2760..3300 (540) post-vault mine straight | gap 140
- 3300..3560 (260) reserve landing (reserve at 3420) | final pit 3560..3700 (140)
- 3700..4400 (700) boss arena (wide runway)

Floating platforms: FEWER, purposeful — a climbing cluster only where a set-piece
needs height (timed-gate approach ~1180–1520 rising to ~350; a couple over the
post-gate trail for coin/token rewards), NOT an even 11-deck stair across the
whole stage.

## Questions (answer each in 2–5 sentences, concrete numbers)
1. **Rhythm**: Does the candidate read as Gold Rush vs L2 stepping? What single
   change would most increase the "mine road / claim trail" feel? Give concrete
   segment/width tweaks.
2. **Height purpose**: Where should the ONLY meaningful height changes be, and
   how high (y), so climbs serve the timed gate + vault and don't feel decorative?
3. **Boss runway**: Is 2760..3560 (long flat) + a single 140px pit then the
   3700..4400 arena a clear "wide approach"? Improve if not.
4. **Identity/palette**: Beyond body=rust/lip=gold/BTC-orange accents + gold dust,
   name 2–3 concrete, no-new-art ways to make it read as a gold MINE (e.g. how to
   use existing mine-cart, one-way gold lane, Fort Knox door) without cyan leftovers.
5. **Clutter**: Anything in the candidate that's decorative-without-function to cut?

## Output format
Numbered 1–5, concrete numbers. End with a 2-line "DISTINCTNESS RISK" note on
whether the candidate is still too close to L2 and the cheapest fix.
