# Flame quad: engine capture vs the Muapi reference (2026-10-10)

Loop step 6 of `ep2-hyperreal-scene-pipeline`. Subject: `src/episode2/assets/vehicles/flame_quad.glb`
(headless Blender, `tools/ep2_blender/build_flame_quad.py`) against
`artifacts/episode2-gold-mine/references/fort_knox_prep/flame_quad/hero_3q.jpg`.
Capture: `tools/ep2_shots/glb_hero_shot.tscn ... studio=1` (the grey seamless backdrop the object references use, same camera framing).

## Numbers (`tools/ep2_forge/ref_metrics.py`)

| capture | closeness | lum EMD | palette | saturation ref/cap | warmth ref/cap | edge ratio |
|---|---|---|---|---|---|---|
| woods sky + grass backdrop | 0.39 | 0.068 | 0.104 | 0.12 / 0.44 | 1.12 / 1.80 | 0.56 |
| grey studio backdrop (apples to apples) | **0.69** | 0.145 | 0.073 | 0.12 / 0.10 | 1.12 / 1.09 | **0.58** |

Lesson: compare the SUBJECT on the reference's own backdrop. The woods backdrop alone drove saturation and warmth off by 3-4x
and made a fair model look "wrong" (0.39). Edge density 0.58 says the model is smoother than the photo (detail still missing).

## DeepSeek V4.1 Flash triage (a lead, not a verdict) - rubric `tools/ep2_forge/rubrics/flame_quad.md`

silhouette PARTIAL, red paint PARTIAL (flat, no clear-coat gloss), flames PARTIAL (thin, rear fender bare), **chrome FAIL** (reads white plastic
under a bright grey sky), tyres PASS, rims PARTIAL, **seat FAIL** (thin slab), **mud FAIL** (panels clean), geometry FAIL (rack looks floating,
smear on the front fender crown), overall PARTIAL. Cost $0.0027.

Claude's own read of the board agrees on the content: the crown "wood grain" is a real bug (the crown UVs collapse onto ONE texture row, so a
per-pixel flake noise is stretched 10:1 across the fender width), the chrome is only white under the studio sky (silver in the woods), and the
flames never reach the fender crowns because the paint is side-planar only.

## Jev (`~typesafe/jev-latest`, numbers only)

good_enough_to_ship 0.36 (uncertain), needs_polish_next 0.75, verdict polish_first 0.67 vs ship_then_polish 0.33 (confidence 0.34).
Decision taken by Claude: SHIP this version (it replaces a primitive box quad, tests and real-render captures are green) and polish in the
next increment, as the FOUNDER SHIP RULE says gate votes steer work and never stall a ship.

## Polish list (next increment, in this order)

1. Baked paint: per-panel loft UVs, texels painted from 3D position (traced side flames + procedural crown flames + isotropic flake + mud).
2. Seat: thicker bench with a visible padded roll.
3. Chrome: darker base so a bright sky does not wash it to white.
4. Rack mounts + handlebar column so nothing reads as floating.
