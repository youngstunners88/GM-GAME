---
name: ep2-blender-props
description: Build Episode 2 hands, target plaques and the plank wall in headless Blender (bpy) instead of Godot primitives, export GLBs, wire them with a primitive fallback, and prove them with the range capture rig. TRIGGER when the founder says hands/targets/wall "look like shit/trash/cheap", before adding any hand-made prop built from capsules and boxes, or when editing tools/blender/build_fp_hands.py / build_range_props.py.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Blender props for the range (hands, plaques, wall)

Primitives (capsules, boxes) will never pass the founder's eye. Author the mesh in `bpy`, export a GLB, load it with a fallback.

## Setup / run
```bash
pip install "bpy==4.2.0"          # works headless; import bpy BEFORE bmesh
python3 tools/blender/build_fp_hands.py src/episode2/assets/fp_hands.glb
python3 tools/blender/build_range_props.py src/episode2/assets/hideout   # range_wall.glb + range_plaque.glb
rm the textures/ dir the script leaves next to the output - the GLB embeds them (pck budget!)
```
No EGL here: `--preview` renders fail. Judge in-engine instead (below).

## Rules
- Blender is Z-up: Godot +Z (toward the player) = Blender -Y. Rifle-local (x,y,z) -> Blender (x,-z,y).
- Deterministic: index arithmetic, no RNG. Textures via PIL, seeded.
- Wire each GLB with `ResourceLoader.exists` + the old primitive path as fallback; keep node names tests rely on (`Hands/HandsModel`, `Logo`, `Ring`, `Holes`).
- pck gate is 190 MB with ~1 MB headroom: GLBs here total < 1.1 MB; check `ls -l` of the export before adding more.
- Never delete GLB-dependency textures next to existing `.glb`s.

## Prove
```bash
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
$G --headless --import
xvfb-run -a -s "-screen 0 960x540x24" $G --rendering-driver opengl3 --rendering-method gl_compatibility \
  --resolution 960x540 res://tools/ep2_shots/range_lesson_shot.tscn -- out=.farm/range
```
Open r10_hip_loaded.png and r11_ads.png and LOOK. Then run ep2_range_v3_test / ep2_range_lesson_test / ep2_smelting_facility_test (`$G --headless res://tests/<t>.tscn`).

## Known limits
Organic characters (the Bull) are NOT a Blender job: use Meshy (`ep2-meshy-studio`), which needs credits (balance 40 on 2026-10-05; a full regen + rig ~40).
