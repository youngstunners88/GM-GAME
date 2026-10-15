---
name: ep2-founder-model-bake
description: Turn the founder's own Drive models (Jake.glb, donkey cart 3d model.glb - 30+ MB, 4K textures) and fresh Tripo characters into pack-sized game GLBs - transform baking, T-pose to A-pose / gun-arm pose by vertex maths, UV-safe decimation, 1K textures, two-pose models - plus the traps that cost an hour each. TRIGGER on "Jake.glb", "donkey cart", a Drive folder of models, "T-pose", "too big for the pack", "model looks like shards", "arm pose", or any Tripo character going into the town.
---

# Founder model bake (2026-10-14)

Pack budget first: `index.pck` must stay < 190 MiB (it sat at ~187 MiB). A 34 MB Drive GLB becomes ~1.2 MB: 14-16k faces + 1024 JPEG base + normal.

## Get the files
Drive folder -> `mcp__Google_Drive__search_files parentId = '<folder>'` for the ids, then `curl -L -o f.bin "https://drive.usercontent.google.com/download?id=<id>&export=download&confirm=t"`
(NOT `download_file_content`: it base64s 34 MB into the context). Rename to `.glb` before importing (`bpy` picks the importer from the extension).

## The tool: `tools/ep2_blender/prep_founder_town_models.py` (needs the `bpy` pip module; CPU, ~10 s)
```
prep_founder_town_models.py jake  in.glb out.glb 16000              # arms lowered (pitch 55 deg each) - the founder's Jake
prep_founder_town_models.py cart  in.fbx out.glb 14000              # FBX, rig applied at rest and dropped
prep_founder_town_models.py duo   in.glb out.glb 16000 rotz=-90 auto=1 a:pitch_l=50 a:pitch_r=50 b:pitch_l=50 b:pitch_r=4 b:swing_r=86
                                                                     # two arm poses as child meshes "Idle" / "Draw" sharing ONE texture set
```
It writes `<out>.json` with the gun-hand position of each pose (glTF axes) for the prop. Shared maths: `tools/ep2_blender/town_pose.py` (`fit_arms` finds the shoulder height from
the farthest-out vertices and scales every number by body height, so any Tripo scale works). In game: `Ep2TownFolk` (`src/episode2/actors/ep2_town_folk.gd`) scales to a height,
stands on its feet, walks with a stride bob, `set_pose("idle"/"draw")`, `fall_dead()`.

## Traps (each one cost time)
1. **A rigged Tripo GLB can skin to shards** (the donkey cart: ~51k faces exploding in Godot and Blender). The same job's **FBX in the zip is clean** - look there first.
2. **Tripo multiview characters face +X, arms along Z** (the cowboy) while Jake faces +Z. `bake_object_transforms()` then `rotz=-90` (set `rotation_mode='XYZ'` first: glTF imports are QUATERNION and
   `rotation_euler` is silently ignored). Check with `tools/ep2_shots/glb_preview.tscn` (4 angles, `hide=Draw` to see one pose) BEFORE trusting a pose.
3. Plain `Decimate` smears the 4K unwrap into white seam streaks: `delimit={'UV'}` keeps the island borders. A fresh smart-UV re-bake (`bake_lowpoly.py`) looked WORSE at 1K (blocky coat, speckled hair).
4. FBX imports have the texture nodes unlinked: rebuild one Principled material from base colour + normal.
5. `.import` files are gitignored but the CI export needs your texture settings: `git add -f` the `.import` of anything you set to `compress/mode=1` (lossy) - the pack budget depends on it.
6. A model that is not centred drifts when two poses are visible at once: `Ep2TownFolk.setup(..., center_xz=false)` for duo models.

## GPU
Everything above is CPU-light. The Runpod GPU (`ep2-cloud-gpu-runpod`) earns its cost for 4K/8K Cycles bakes and turnaround renders (`tools/ep2_blender/bake_lowpoly.py` runs on it as written).
