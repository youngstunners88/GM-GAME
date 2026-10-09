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
| Hero vehicle / prop (hard surface, paint) | flame quad | GPT hero + side + rear -> **Meshy multi-image-to-3D** (`meshy_multi_image_to_3d`, meshy-6, textured ~30 credits; ASK first: `ep2-meshy-studio`, balance was ~40) -> `meshy_remesh` -> headless Blender cleanup (pivot at the ground between the wheels, +Z forward, 2.4 m long, double-sided, name nodes) -> GLB | <= 25k tris, 1K textures, GLB <= 1.5 MB |
| Character | AwesomeX, bears, Bull | Meshy image-to-3D + `meshy_rig` (`ep2-meshy-studio`, `ep2-bull-handoff-walk`); clips by `ep2-motion-emotion`; the rig must not read as a muppet (compare against the design board) | <= 30k tris, 2K body texture |
| Architecture / terrain | decoy building, vault approach, spy ridge, return trail | **headless Blender (bpy 4.2 via pip)**: kit-bash from boxes/extrudes + tiling PBR (Muapi/Flux seamless textures, `tools/ep2_forge/forge_runner_assets.py`), bevel everything, vertex-colour AO baked in (compat renderer has no SSAO), modular pieces (a wall, a corner, a door bay) instanced in Godot | <= 400k visible tris per region |
| Destruction | the exploding building | TWO meshes (intact, wreck) + Godot CPU particles (fireball, embers, smoke) + a light flash + camera shake; the wreck swaps in on the flash frame | particles <= 300 |
| Tripo | when credits > 0 | Tripo image-to-3D for props with fine relief (see `ep2-tripo-mesh-surgery`); credits were 0 on 2026-10-09 | - |

Blender rules that cost hours already: never the GUI (`blender-headless-render-safety`); `import bpy` before `bmesh`; glTF export `export_apply=True`;
baked textures live NEXT TO the .glb (never delete them); Tripo/Meshy meshes are shell soups - split the FINAL glb into connected components
(`trimesh`) to find floaters before blaming the renderer (a 6 mm tetrahedron "thorn" on the rifle was a decimate artifact only visible that way).

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
