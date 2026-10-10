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

## Increment 2 (same day): paint baked per panel + seat + chrome + steering column

`build_flame_quad.py` now gives each red panel its own loft UVs (u along the length, v folded at the crown) in ONE 1024x320 atlas at 5 mm per texel and paints
the texels from 3D position (`bake_paint`): the flames traced from the side elevation where the surface faces sideways, procedural forked crown flames where it faces up
(mirrored left/right), isotropic 3D-noise flake, mud thick low on the panels and behind each wheel. The padded bench overhangs the tub, the chrome base is darker
(0.62, metal 0.92), a black steering column joins the bars to the tank, the rack legs got visible brackets.

| capture (grey studio backdrop, same framing) | closeness | edge ratio | note |
|---|---|---|---|
| v1 side-planar paint | 0.69 | 0.58 | flames only on the side panels, crowns plain, "wood grain" streaks |
| v2 baked paint | **0.70** | **0.63** | flames across both fender crowns, tub and rear fender; chrome reads silver |

Cost: the paint atlas imports to 364 KB (the v1 paint was 276 KB); the whole quad is ~0.9 MB in the pack. Branch CI (run 562) printed `index.pck = 188 MB` for v1
(master 187 MB, gate 190 MiB).

Still open (not blocking): the reference's fine detail (chrome reflections, mud micro-detail, engine block visible between the wheels, the nose flames), an MR map
so mud is rough while the lacquer stays glossy, and a Meshy/Tripo image-to-3D comparison if the founder wants to spend credits on it.

## Astra art-direction review (one pass, $0.059; raw answer in `2026-10-10-flame-quad-astra-review.md`)

Verdict: **fidelity 4/10, "would a player believe it? no"** - it reads as a flame-painted quad at five metres but still as a toy-like prop. Its five fixes and what happened:

| Astra fix | Done in the same session? |
|---|---|
| Sculpted body: raised sloping cowl, thinner fender lips, deeper arch returns instead of inflated pods | **No** - a real shape redesign; this is what an image-to-3D model (Meshy / Tripo) buys from the reference |
| Flames: fewer, longer, cleanly tapered tongues, more uninterrupted red | **Yes** - 6 long tongues + 1 fork each, S-curve, red breathing room |
| Tyres/rims: more rubber, recessed dished rim, matte charcoal rubber (not shiny brown) | **Yes** - rim radius 0.30 -> 0.268, dish 0.07 m deep, rubber 3x less mud and charcoal |
| Bumper: rounded loop + slotted skid plate instead of a fence of bars | **Yes** - loop + mid bar + angled slotted skid plate |
| Separate glossy red / rough steel / matte vinyl, lower-body dust and abrasion | **Partly** - mud + chrome + seat done; an MR map (rough mud vs glossy lacquer) is the open part |

Final engine capture on the grey backdrop: closeness 0.70, edge ratio 0.63 (see `ref_metrics.py`). The remaining gap to a photographic quad is mostly SHAPE, which procedural kit-bashing
cannot cheaply close: that is the honest case for spending Meshy credits (40 available) on this prop - or saving them for AwesomeX, who cannot be kit-bashed at all.

## Increment 3 (same day): the kit-bashed quad is REPLACED by Tripo H3.1 multi-view image-to-3D (Muapi)

Muapi turned out to sell Tripo H3.1 / Meshy 6-7 pay-per-call (`GET /api/v1/models`, category "Image to 3D"). Inputs: the GPT stills `front`, `side`, `back` (i2i of the hero, $0.18);
Tripo H3.1 multiview, texture + PBR, detailed, face_limit 60000: **$1.00, ~6 minutes**, one fused mesh (57k tris), 4096 base/ORM/normal (12.3 MB GLB). `ai_vehicle_to_game.py` cleaned it
(wheels found from the mesh, four `Wheel_*` nodes cut for spin, 1024 base / 256 metal-rough JPEG, normal map dropped, no decimation). Packed with lossy-WebP texture imports: scn 0.84 MB + base 0.20 MB +
metal-rough 0.02 MB = **1.06 MB** (the kit-bashed one was 0.88 MB and is retired from the pack).

| | closeness | edge ratio | Astra | in-game |
|---|---|---|---|---|
| kit-bashed Blender quad (v2, baked paint) | 0.70 | 0.63 | **4/10** "toy-like, no" | reads as a painted prop |
| Tripo H3.1 multiview quad | 0.70 | 0.51 | **6/10** "a player would believe it: yes" | reads as a real vehicle at 5 m, Inferno seated convincingly |

Astra's remaining notes (raw: `2026-10-10-flame-quad-astra-review-ai.md`): flames "blurry, tangled", rear fender mostly plain red, lacquer flat, tyres soft, headlamp a cloudy disc, lower-body grime too clean -
all texture-level. DeepSeek's grade of the same board was unreliable (it called the long bench "a short thin pad" and the model "showroom clean"); trust the pictures + Astra.
The edge-density number fell because the web textures are lossy and 1024 (the 4096 original is sharper) - closeness is the same; it is a coarse metric, the pictures decide.
