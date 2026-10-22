# Blender revolver and western selector (2026-10-15)

The founder supplied a square image of an engraved golden Remington 1875 with curved walnut grip, long barrel, ejector/web and Bitcoin medallions. It is visible in the conversation but has no local uploaded-file path. Geometry was authored in Blender against that visual reference; this is not a downloaded reference image or a paid Tripo/Meshy result. The founder explicitly requested Blender.

`remington_1875_gold.blend` preserves the high detail source: real bore, fluted cylinder, curved frame/grip, trigger/guard/hammer/sights, floral curves and raised medallions. `remington_grip_hand.blend` preserves the fitted right hand and sewn bracer. The current hand is a fixed contact pose, not an articulated reload/finger animation. The founder Winchester mesh/textures are unchanged; its icon includes its original integrated hand.

Reproduce, from repo root, in separate headless Blender processes:

```sh
blender -b --python tools/ep2_blender/build_remington.py
blender -b --python tools/ep2_blender/bake_remington_game.py
blender -b --python tools/ep2_blender/build_remington_hand.py
blender -b --python tools/ep2_blender/render_winchester_icon.py
```

The first command authors the editable high source and gun icon; the bake command produces the compact runtime GLB (9,556 triangles, three meshes). Floral geometry bakes into portable colour/normal textures. Metallic base colour is baked through emission, avoiding the black panels caused by a diffuse-only metallic bake. Runtime hand: 4,307 triangles, four meshes. Finite position/normal and hash checks are in `game-asset-validation.json`. Source and game axes: +Z muzzle, +Y up, metres. FPS carry exposes the side; ADS and muzzle remain separately aligned.

The dedicated PNG import presets use high quality WebP, preserving alpha; mesh presets disable unnecessary LOD/shadow copies. The Latin Bookman subset uses MSDF for portrait scaling, with original license in FONT-LICENSE.txt. Recreate the subset with:

```sh
pyftsubset /usr/share/fonts/opentype/urw-base35/URWBookman-Demi.otf --unicodes=U+0020-007E,U+00B7,U+2013-2014 --output-file=src/episode2/assets/weapons/armory/western_bookman.otf
```

Actual Godot Compatibility renders are in `../captures/`; the studio PNG is source-art evidence only. Baked micro-engraving is intentionally less detailed than the editable source to fit web delivery. No claim of an exact photographic match or live deployment follows from the Blender render.

# Rich & Utah, the Armory's shopkeepers (2026-10-17)

The founder lock (`PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md`) needs the two men actually behind the
counter, and the Tripo/Meshy route was unavailable (balance 0), so both bodies are authored on-box in
Blender, headless, with no external service and no paid model. `tools/ep2_blender/build_armory_folk.py`
lofts each figure from measured profiles into **one multi-material mesh** and writes the armature and the
skinning itself: **one shared skeleton drives both the mesh and the rig** (limbs are lofted along the
joints, so the rig always fits), with procedural **distance-weighted skinning** — Godot's `ARMATURE_AUTO`
is not used. **20 bones** per man. Clothing and props are layered over the body (Rich: duster, miner's
helmet with a brass headlamp, aviator shades, cigar, neckerchief, suspenders, GM medallion, tool belt,
chaps, tall boots, and the claim book + brass stamp bound to `Hand.L`; Utah: felt hat, shades, goatee,
open jacket with a star, vest, tooled belt with twin low-slung holsters, rope coil, two-tone boots).

Reproduce, from repo root, in a headless Blender:

```sh
blender -b --python tools/ep2_blender/build_armory_folk.py -- --dir src/episode2/assets/town [--only rich|utah]
```

Outputs `rich_armory.glb` (1.86 m) and `utah_armory.glb` (authored 1.80 m; the town chamber stands him at
1.74 m) — ~450 KB each, palette materials only, so they add no textures to the pack. Each GLB carries
**authored clips baked in** (24 fps): Rich `Counter / Greet / Idle / Point / Walk`, Utah `Carry / Greet /
Idle / Point / Walk`; `Ep2TownFolk` plays them (`has_clips()`, `hold_clip()`) and skips the statue sway for
rigged folk. Frame matches the town kit: feet at z = 0, up = +z, front = −y.

Judgment renders (idle / greet / counter / walk for Rich; idle / side / greet / carry for Utah) are in
`../captures/rich_*.png` and `utah_*.png`, graded against `rich_the_claim_recorder.png` and `utah_ref.jpg` (the
founder's Drive reference). They are Blender renders, not in-game gameplay-camera captures; the in-game capture
waits on a box with xvfb. Notes for the next run: the MCP addon can leave an Icosphere in a fresh scene, so the
export is selection-only; `PART_DEBUG=1` prints per-part bounding boxes; Blender 5.2 renames
`blend_method` → `surface_render_method` and actions expose no `.fcurves` (use `action_fcurves()`).
