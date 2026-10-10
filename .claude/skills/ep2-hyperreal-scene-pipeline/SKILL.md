---
name: ep2-hyperreal-scene-pipeline
description: The Episode 2 pipeline for HIGH-QUALITY, HYPER-REALISTIC scenes and props - reference stills from Muapi GPT Image 2, then a 3D build in headless Blender and/or Meshy/Tripo, then an engine capture graded against the reference with numbers for Jev, cheap vision triage from DeepSeek and a final art review from Astra. TRIGGER when the founder asks for "hyper realism", "high quality scenes", "reference images", "use Muapi / ChatGPT image", a new set piece (spy point, decoy building, vault approach, return trail, AwesomeX, the quad, rescue mark), "make it look real / less cheap / less grey box", or any Fort Knox prep asset.
---

# Why this exists

2026-10-09 the founder, after the Fort Knox arc document: "Use Muapi to use chatgpt image to create the necessary reference images to
then create the 3D render on blender or/and tripo ... you need to start working more intelligently and create the necessary skills to
create amazing high quality hyper realism scenes." and "Remember we also have Jev and other models in Openrouter to help us."
The 10-04 / 09-29 failures were all the same: a model "loaded" (files existed, tests green) but nobody compared the picture with a
picture. This skill is the loop that makes the picture the gate. It sits INSIDE `ep2-layered-production` (layers 1, 3, 4) and uses
`ep2-reference-match-loop`, `see-it-yourself`, `ep2-meshy-studio`, `blender-headless-render-safety`; the arc rules are `ep2-fort-knox-arc`.

# The loop (one set piece at a time; never skip a gate)

```
0 ARC      read ep2-fort-knox-arc: is this prep allowed? (prep = references, models, dressing, geometry tests; never the playable claim)
1 BRIEF    one entry in tools/ep2_forge/fort_knox_refs.json: id, constraints (metres, sightlines, "reads as X"), views
2 REFERENCE python3 tools/ep2_forge/muapi_ref.py gen <id>      -> artifacts/episode2-gold-mine/references/fort_knox_prep/<id>/<view>.jpg
            python3 tools/ep2_forge/muapi_ref.py board <id>    -> _board.jpg   LOOK AT IT (Read the png). Reject and re-prompt, don't "make do".
3 TRIAGE   DeepSeek Flash reads the board against the brief's constraints (cheap, a lead not a verdict)  [section Models]
4 BUILD    route by asset class [table below] -> GLB / scene script, web budgets
5 CAPTURE  the REAL player camera (first person eye 1.55 m, FOV 78) with a tools/ep2_shots/*_shot.gd rig under xvfb; LOOK at every png
6 MATCH    python3 scripts/ref_compare.py <ref.jpg> <capture.png> <board.jpg> --grade     (board + DeepSeek rubric grade)
            python3 tools/ep2_forge/ref_metrics.py <ref.jpg> <capture.png> --state         (numbers)
            node scripts/jev.mjs --state "<that paragraph>" --bool "close=Is the capture's overall look close to the reference?" ...
7 REVIEW   ONE Astra pass on a board of the 3-4 best captures when the set piece is done (~$0.15)       [section Models]
8 SHIP     tests + pck gate + STATUS.md + scripts/ship-to-master.sh + live-build-proof
```
Claude owns every verdict: a DeepSeek / Astra / Jev answer is a LEAD or a number. Say "matches" only after looking at the board yourself.

# Step 2 - Muapi GPT Image 2 (verified 2026-10-09 against `GET /api/v1/models`, 765 models)

| Endpoint | Use | Cost |
|---|---|---|
| `gpt-image-2-text-to-image` | hero stills; quality `high`, resolution `2K` | $0.09 (1K $0.06) |
| `gpt-image-2-image-to-image` | SAME subject again: turnaround views, "after the explosion", a scene built from a character sheet (`images_list` up to 16) | $0.09 |
| `gpt-image-1.5` / `-edit` | cheaper drafts | $0.054 |
| `nano-banana-pro(-edit)` | the film's keyframe tool (`ep2-seedance-film`) | $0.12 |
| `tripo3d-h31-multiview-to-3d`, `meshy-6/7-multi-image-to-3d` | the 3D model from the stills (section below) | $0.2-1.7 |

- Submit `POST https://api.muapi.ai/api/v1/<endpoint>` header `x-api-key: $MUAPI_API_KEY`, body `{prompt, aspect_ratio, resolution, quality, images_list?}`;
  poll `GET /api/v1/predictions/<id>/result` until `completed`; image URL = `outputs[0]`. `tools/ep2_film/muapi_film.py` is the one client (balance, upload, run).
- **The published schema lies about aspect ratios.** It lists 3:2 / 2:3 / 5:4 / 4:5, the API answers HTTP 422 `Input should be 'auto', '1:1', '16:9', '9:16', '4:3' or '3:4'`.
  Use 16:9 for scenes and 4:3 for objects. (`/models/<name>/estimate-cost` accepts anything: it validates nothing.) `auto` is 1K only; 1:1 cannot do 4K.
- Style is locked by `style_lock_env` / `style_lock_object` / `style_lock_scene` in the JSON, prepended to every prompt: western Modern Warfare grade (warm low sun key,
  teal shadow fill, thin haze, PBR materials, 35 mm at 1.6 m eye height, no text/logos/UI). Objects go on a plain grey seamless backdrop (that is what image-to-3D wants).
- Consistency: a turnaround is an **i2i of the hero**, never a second t2i (a second t2i is a different object). Characters the founder already owns (Inferno Bull,
  bears) go in as `refs` (repo image paths; uploaded once, cached by hash) so GPT draws HIM, not a lookalike.
- Environments are references for MOOD, SCALE and COMPOSITION - the engine scene is built to match them, not pixel-copied. Objects are references for GEOMETRY and PAINT.
- Reject a reference that breaks the brief's constraints (road too narrow, sightline blocked, door shown when the door is the Pascal spec, a corpse where Bull must be alive).
  Re-prompt with the failure named ("the road must be 4-5 m wide, straight for 100 m").
- ~$1.2 buys the whole first batch (13 views). `balance` prints before/after; never paste the key; `.farm/` is gitignored.

# Step 4 - build route by asset class

| Class | Examples | Route | Budget |
|---|---|---|---|
| Hero vehicle / prop (hard surface, paint) | flame quad | **Muapi image-to-3D** (`tools/ep2_forge/muapi_3d.py`; Tripo H3.1 multiview ~$1, Meshy-6 ~$0.5, Meshy-7 ~$1.7; pay-per-call on the Muapi balance, NOT the native Meshy/Tripo credits) from GPT front/side/back stills -> `tools/ep2_forge/ai_vehicle_to_game.py` -> lossy texture imports. Recipe + numbers in the section below. Kit-bashing a vehicle in Blender scored 4/10 against its photo, the Tripo model 6/10 and reads as a real vehicle in-game. | <= 60k tris, ONE 1024 base + 256 metal-rough, ~1 MB packed |
| Character | AwesomeX, bears, Bull | Meshy image-to-3D + `meshy_rig` (`ep2-meshy-studio`, `ep2-bull-handoff-walk`); clips by `ep2-motion-emotion`; the rig must not read as a muppet (compare against the design board) | <= 30k tris, 2K body texture |
| Architecture / terrain | decoy building, vault approach, spy ridge, return trail | **headless Blender (bpy 4.2 via pip)**: kit-bash from boxes/extrudes + tiling PBR (Muapi/Flux seamless textures, `tools/ep2_forge/forge_runner_assets.py`), bevel everything, vertex-colour AO baked in (compat renderer has no SSAO), modular pieces (a wall, a corner, a door bay) instanced in Godot | <= 400k visible tris per region |
| Destruction | the exploding building | TWO meshes (intact, wreck) + Godot CPU particles (fireball, embers, smoke) + a light flash + camera shake; the wreck swaps in on the flash frame | particles <= 300 |
| Tripo | when credits > 0 | Tripo image-to-3D for props with fine relief (see `ep2-tripo-mesh-surgery`); credits were 0 on 2026-10-09 | - |

Blender rules that cost hours already: never the GUI (`blender-headless-render-safety`); `import bpy` before `bmesh`; glTF export `export_apply=True`;
baked textures live NEXT TO the .glb (never delete them); Tripo/Meshy meshes are shell soups - split the FINAL glb into connected components
(`trimesh`) to find floaters before blaming the renderer (a 6 mm tetrahedron "thorn" on the rifle was a decimate artifact only visible that way).

# AI image-to-3D through Muapi (found 2026-10-10: the route that took the quad from 4/10 to 6/10)

`GET https://api.muapi.ai/api/v1/models` lists category **Image to 3D**: `tripo3d-h31-multiview-to-3d` ($0.2 base), `tripo3d-h31-image-to-3d`, `meshy-6-(multi-)image-to-3d` ($0.5),
`meshy-v7-(multi-)image-to-3d` ($1.7), text-to-3D variants. They bill the SAME Muapi balance as GPT Image 2 - so the native pools (Meshy 40 credits, Tripo 0 on 2026-10-10) are not the limit.
`python3 tools/ep2_forge/muapi_3d.py models | estimate | run` is the client (uploads repo images once, polls, downloads every output, writes a receipt).

**Recipe (hard-surface prop or vehicle)**
1. Stills first: the hero (t2i) then `front`, `side`, `back` as GPT **i2i of the hero** (`fort_knox_refs.json` views, $0.09 each): consistent paint and parts, straight-on elevations.
2. `python3 tools/ep2_forge/muapi_3d.py run tripo3d-h31-multiview-to-3d --images front.jpg side.jpg back.jpg --out .farm/3d/<id> --set texture=true --set pbr=true
   --set texture_quality='"detailed"' --set geometry_quality='"detailed"' --set face_limit=60000`   (~6 min, **$1.00 actual** although `estimate` said $0.5; `.farm/` is gitignored).
   Tripo returns ONE fused mesh (57k tris / 38k verts), 4096 base colour + ORM + a nearly flat normal map (12 MB GLB), nose along +X, bounds centred. Meshy-6 took >25 min on the same inputs.
3. `python3 tools/ep2_forge/ai_vehicle_to_game.py --src out_0.glb --out src/episode2/assets/vehicles/<name>.glb [--nose=-x]` does the clean-up: finds the four wheels FROM THE MESH
   (ground-contact clusters, then a circle fit to the lowest point of each x-bin = the tyre's bottom silhouette; the half-width/hub-height slab method DIVERGES - do not use it), turns the nose to +Z,
   scales the tyre to 1.0 m, stands it on the ground with the origin between the axles, cuts `Wheel_FL/FR/RL/RR` (face centroid in a cylinder; faces whose corners reach beyond 1.08 R go back to the
   body, floating pieces < 150 tris are dropped - weld by POSITION before counting pieces, AI meshes split every UV island into its own vertices), re-encodes textures (1024 base, 256 metal-rough,
   normal DROPPED), writes one material / five meshes. It does NOT decimate: AI UV atlases are confetti, collapsing edges tears the texture.
4. Verify without importing anything: `glb_hero_shot.tscn -- glb=<file.glb> auto=1 studio=1 spin=40` loads the GLB at run time, orbits it, and `spin` turns the wheels (a loose shard or a body bit riding the wheel shows at once).
5. Import for the web pack (**this is where the megabytes are**): track `<name>.glb.import` with `meshes/generate_lods=false`, `create_shadow_meshes=false`, `ensure_tangents=false`, and for each extracted
   texture `<name>_BaseColor.jpg.import` / `_MetalRough.jpg.import` set `compress/mode=1` (lossy WebP), `compress/lossy_quality=0.75`, `detect_3d/compress_to=0`; `git add -f` all three.
   Packed: scn 0.84 MB + base colour 0.20 MB (lossless/VRAM was 1.65 MB) + metal-rough 0.02 MB = **1.06 MB** for the whole quad.
6. Landmarks for riders / seats are MEASURED on the mesh (seat top 1.37-1.42, rack deck 1.43, grips x +-0.5 y 1.72 z 0.5 for the quad), then the constants in the chamber are set and a
   capture from outside (`interlude_shot.gd` woods_6b/6c) + the interlude test prove the seating.
7. Grade it like everything else (metrics, DeepSeek, one Astra pass): kit-bashed 4/10 -> Tripo 6/10; Astra's remaining notes (soft tyres, plain rear fender, flat lacquer, no grime) are texture-level
   and can be fixed in the atlas without extra bytes. DeepSeek's grade of the same board was unreliable (called the seat "a short thin pad" and the model "showroom clean") - trust your own look + Astra.

Characters (AwesomeX) go the same way but need `meshy_rig` afterwards (Meshy-7 can rig + animate in the same call: `enable_rigging`, `rigging_height_meters`). Kit-bashing stays for ARCHITECTURE and destruction.

# What reads as hyper-real in Godot 4.3 Compatibility / web (the checklist for step 5)

1. **Lighting**: one warm directional (energy ~1.3, shadows on) + hemisphere/colour ambient (0.6-0.8) + filmic tonemap (`tonemap_white` ~6) + glow (`hdr_threshold` 1.2)
   + depth fog (density ~0.01, warm). Flat fill and no fog = grey box. No SSAO/SSR/volumetrics in Compatibility: fake them (baked AO, fog cards, dust particles).
2. **Materials**: albedo + roughness + normal at 1K, roughness VARIES (never one constant), metals dark unless lit by sky (a bright sky turns metal cream - the rifle needed
   `viewmodel_exposure` 0.82), rust/dirt in the albedo not in the colour factor, triplanar for rock/gravel with scale breakup.
3. **Silhouette + scale**: person 1.7 m, Lil Blunt 1.6 m, Inferno Bull 2.9 m, quad 2.4 x 1.6 m, road 4.5 m, trail 8-10 m. Check at the FIRST-PERSON camera: the shape must read at 60 m.
4. **Imperfection**: nothing perfectly straight, nothing symmetrical, props lean, edges chip, ground has leaf litter / ruts / puddles (decals or small meshes), trees vary.
5. **Colour grade**: warm key / teal shadows (western Modern Warfare); keep Lil Blunt's leaf-green and the AwesomeX green as the only saturated greens.
6. **Budgets**: pck < 190 MiB (`scripts/ep2-local-export.sh` prints it), <= 400k tris per region, CPU particles only, < 1000 MultiMesh instances per node (godot#96968).
7. **Never**: floating props, black fills, repeating tile seams, a "grey box" explosion, a model that loaded but was never looked at.

# Models (OpenRouter + Muapi) - who does what in this loop

| Model | Role here | How | Cost |
|---|---|---|---|
| **GPT Image 2** (Muapi) | the references | `tools/ep2_forge/muapi_ref.py` | $0.09 / image |
| **Tripo H3.1 / Meshy 6-7** (Muapi) | stills -> textured 3D model | `tools/ep2_forge/muapi_3d.py` + `ai_vehicle_to_game.py` | $0.5-1.7 / model |
| **DeepSeek V4.1 Flash** | triage of boards/captures against the brief's constraints; reads many frames cheaply | `python3 scripts/ref_compare.py ref.jpg cap.png board.jpg --grade` or `node scripts/or-call.mjs deepseek/deepseek-v4.1-flash prompt.md out.md --image board.jpg` | ~$0.001 |
| **Jev** (`~typesafe/jev-latest`) | ship / iterate / pick-one DECISIONS on NUMBERS (it is text-only: never hand it an image) | `python3 tools/ep2_forge/ref_metrics.py ref cap --state` -> `node scripts/jev.mjs --state "<paragraph>" --bool "name=question"` / `--choice "verdict=ship:..|iterate:.."` | ~$0.00002 |
| **GPT-6 Astra** (`openai/gpt-6-astra`) | the ONE art-direction review of a finished set piece's board (images in) | `node scripts/or-call.mjs openai/gpt-6-astra prompt.md out.md --image board.jpg` (skill `art-direction-fidelity-check`) | ~$0.15 |
| Claude | owns the repo, the build, every verdict and every "matches" | looks at the pngs | - |

`ref_metrics.py` is COARSE: closeness 0.55-0.70 is a good game-frame-vs-still match, < 0.35 is wrong, and it catches gross errors (too dark, wrong palette, a flat box with 10% of the
reference's edge detail). It never replaces looking. Record the numbers and the verdict in `docs/model-responses/<date>-<id>.md`.
CLAUDE.md FOUNDER SHIP RULE: no gate vote blocks a ship and none is reported to the founder - these numbers steer the work, they do not stall it.

# Definition of done for a set piece

1. The brief's constraints are satisfied IN THE ENGINE (sightline test, road width, scale) - assert them in a headless test where you can.
2. A capture from the player's camera sits on a board beside its reference and you have looked at it.
3. Numbers recorded (closeness, edge ratio); Astra reviewed the final board once.
4. Web budgets met; GLB + textures committed; `.import` files force-added where Godot needs them.
5. `ep2-fort-knox-arc` status table updated; STATUS.md; shipped to master; proven live.

# Lessons from the first built piece (the flame quad, kit-bashed in Blender first, 2026-10-10; it was then REPLACED by the AI model above) - these still apply to anything you kit-bash

1. **THE PCK IS THE BINDING BUDGET.** CI printed `index.pck = 187 MB` for master (gate 190 MiB = 199,229,440 B). A new prop gets ~1 MB, not 3. What the pck stores is the
   IMPORTED data, not the GLB: VRAM-compressed textures cost ~1 byte per pixel (a 2048x600 paint = 1.26 MB, a 512^2 map = 0.2-0.3 MB) and the default GLB import
   adds LODs + shadow meshes (+60 % on the scn). So: paint big, SHIP small (`SHIP_DIV` in `build_flame_quad.py`: 1024x300 paint, 256^2 rubber/rim, 128^2 steel), and track a
   `<model>.glb.import` with `meshes/generate_lods=false` + `meshes/create_shadow_meshes=false` (`git add -f`, `*.import` is ignored; the hideout GLBs do the same).
   The quad went 2.86 MB -> 0.83 MB with no visible change. Measure with `.godot/imported/<name>*` sizes; the LOCAL export reads ~5 MiB higher than CI (stale local imports), so
   the truth is a branch push: CI logs `index.pck = N MB`.
2. **Grade the SUBJECT on the reference's own backdrop.** `glb_hero_shot.tscn ... studio=1` renders the GLB on the grey seamless backdrop with the same framing: closeness 0.39 (woods
   backdrop) -> 0.69 (studio). A coloured backdrop alone drives saturation/warmth off by 3-4x and makes a fair model look wrong.
3. **Compatibility renderer + chrome**: only the SKY is reflected. A fully metallic part in a sky-less room renders BLACK, and under a bright uniform sky it renders WHITE. Chrome is
   `metal 0.8 rough 0.2` and reads silver in the woods sky; judge chrome in the game sky, not in the studio.
4. **Paint projected onto a curved loft smears - bake it from 3D position instead.** The first quad used one side-planar UV map; the fender crowns (normal up) were slid onto a single
   texture ROW, so per-pixel flake noise stretched 10:1 into "wood grain" and the flames never reached the crowns. `build_flame_quad.py` now does it properly (`bake_paint`): each red panel
   is a loft with its OWN UVs (u = along f, v = fold distance from the crown; left and right share one half), all three in ONE 1024x320 atlas at 5 mm/texel; every texel asks "where in 3D
   am I and which way do I face?" (bilinear patch of the loft grid + outward normal) and is painted from that: traced side flames weighted by |n.x|, procedural forked crown flames weighted
   by n.z (blend in MASK space, never UV space), `cellnoise` flake and `vnoise` mud keyed to 3D position so grain is isotropic. Reuse this for any lofted/curved hero prop.
5. **Seat riders with a probe, not by eye**: `tools/ep2_shots/rider_probe.tscn` prints hips/feet/hands/head of each seated clip in actor space; `woods_quad.gd` constants (`BULL_HIPS`,
   `BULL_SEAT_F`, `GRIP_*`, `BULL_LEAN`, `BACK_F/BACK_SIDE/BACK_EYE`) come from it. The seated clip alone sits him bolt upright against a chair back (his back is 0.5 m from the
   passenger's eye = a wall of texture): lean him onto the grips with `reach(..., lean)` (radians) and put the passenger a little to the side so he looks PAST the driver's shoulder.
6. **A defined function nobody calls is not a feature.** `_bull_mount()` existed for a whole session and was never called; only an outside-camera capture
   (`interlude_shot.gd` woods_6b/6c) and an assertion (`current_clip() == BULL_SIT_CLIP`) exposed it. Every new hook gets a test that observes its EFFECT.
7. **Triage numbers**: DeepSeek's board grade (rubric `tools/ep2_forge/rubrics/flame_quad.md`) found the same defects Claude saw (chrome, seat, mud, flame coverage) for $0.003; Jev
   returned `polish_first 0.67 / ship_then_polish 0.33` at confidence 0.34 - low-confidence advice; the ship rule decides (ship the verified improvement, polish next).
8. **DRAW CALLS, not triangles, are what a web build runs out of.** The first quad export was 164 loose meshes (every tube, bolt and rib its own node) = 164 draw calls, x2 with the shadow
   pass, for ONE parked vehicle. `merge_parts()` in `build_flame_quad.py` bakes curves/modifiers (`bpy.data.meshes.new_from_object`), then joins by material: 164 -> 29 meshes, same
   32k triangles, smaller file. Keep only what must move (the four `Wheel_*` hubs keep their names and origins). Give the baked copies their original names back (Blender suffixes `.001`
   while the originals still exist) and check the node tree with a tiny GLB-JSON dump before importing.
