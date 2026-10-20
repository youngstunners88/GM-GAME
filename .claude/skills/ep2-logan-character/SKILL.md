---
name: ep2-logan-character
description: Turn the founder's Logan (Tripo GLB, Mixamo rig, T-pose reference JPG in the Drive folder) into a small, correctly scaled, animated Godot character for Logan's Lake - measured source facts, pack-safe texture plan, costume read from the image without making him a fisherman, Logan's clip set, proof. TRIGGER on "Logan model", "Logan.glb", "Logan.JPG", "Logan.zip", "the LP face", rigging or importing Logan, or Logan's look, size or animation.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Logan (liquidity-provider face) -> game

This is a delta on `ep2-tripo-folk-to-game` (branch `feat/armory-two-story`: the Rich/Utah pipeline, same Tripo + Mixamo case). Follow it for inspect -> scale -> one skeleton -> decimate keeping weights -> clips -> export -> proof, and use the installed Blender skills headless (`ep2-blender-skills-bridge`: never the GUI, no local GPU, heavy jobs to Runpod via `ep2-cloud-gpu-runpod`). Story use: `ep2-logans-lake`.

## Sources (Drive folder `1q4e5q-UVVOH0Dxu9CnRdXAi_4sLkj25K`, uploaded 2026-10-18)
| File | Drive id | Measured 2026-10-19 |
|---|---|---|
| `Logan.JPG` | `1t-_1l56QsUQGuPTmuqE43TSt11IwfYaD` | 2752x1536, T-pose full body in a bayou setting (viewed) |
| `Logan.glb` | `1wQN_w5Lajmjg8cboFIikdmySi98VGhnl` | 23,925,540 B, Tripo, **52,028 tris** (60,285 verts), **1 mesh, 1 material, 65-bone Mixamo skin**, 0 animations, 1.0 m tall (normalised), 3 textures |
| `Logan.zip` | `1CcU0LjyuAP5DLurSo-X9110EDgFztoGm` | 11,972,197 B, not opened (likely the FBX variant, like `rich.zip`) |
Textures inside the GLB: albedo JPEG 4.2 MB, normal JPEG 1.3 MB, **metallic-roughness PNG 15.0 MB** (the bulk of the file; it will not be read in a flat-lit Godot scene).
Download: the Drive connector refuses files over 10 MB. A public-link `curl -sL "https://drive.google.com/uc?export=download&id=<id>" -o <name>` worked for the GLB (byte count matched); the other session uses `https://drive.usercontent.google.com/download?id=<id>&export=download&confirm=t`. Always into a **fresh scratch directory** (untrusted input), inspect with a stdlib script run `python3 -I` from a different directory, and keep sources out of the repo or under a `.gdignore` folder.

## Look (from `Logan.JPG`; the founder supplied it, so it is the target)
Bearded man in a mossy bucket hat with fibre trim, blue-brown plaid flannel with moss patches on the shoulders and cuffs, olive work overalls with chest pockets (pens, a lure clipped on), brown leather harness belt with buckles and carabiner, coiled rope on the hip, leather satchel, reel and tackle and a net at the hip, rubber boots with leather straps. Mud and wear. Setting: a dock with rowboats and cypress/moss shore.
- **Lock tension:** the lock says "practical, grounded, slightly proprietary about the lake... **not a cartoon fisherman**", and forbids fishing gameplay. The costume reads angler. Keep the founder's design (his image), but never give Logan a rod, never animate casting/reeling, keep tackle as small worn detail, and play him as a lake keeper (rope, markers, crate, satchel). Ask the founder if the lures/reel/net should be trimmed.
- Do not put a "fish" prop in his hands or on the stage post; one-second bank flavour at most.

## Pack budget (this decides the job)
Margin after the 2026-10-18 fixes was ~467 KB (`scripts/pack-gate-fresh.sh`, <= 199,229,440 B). The other session estimates 3-4 MB for the whole armory job. Plan for Logan alone: decimate to ~7-12k tris keeping weights (meshoptimizer `simplify_with_attributes` or `tools/ep2_forge/gltfpack_safe.sh`; never default gltfpack: Godot 4.3 refuses `KHR_mesh_quantization`), **one 1024 albedo**, drop the normal and metal-rough maps (the horse and Rich pipelines do), `.import` tracked lossy (`compress/mode=1`). Expect roughly 0.4-0.7 MB: **already near the whole margin**. Measure, then put the number in front of the founder; do not recover bytes by excluding files without `ship-visual-proof` (the 2026-10-18 white-rifle incident). The 15 MB PNG never enters the repo or the pck.

## Pipeline notes specific to Logan
1. Inspect first: pose a few bones and render before trusting the skin (Tripo skins can tear; `ep2-founder-asset-swap`). No stray `Icosphere` was found in this GLB (Utah had one), but check.
2. Real height: set from the founder's read of the image (~1.80 m with the hat), feet z=0, facing -Y, armature scale 1.
3. Share the Rich/Utah skeleton naming and clip library so `Ep2TownFolk` plays him: `play_clip`, `hold_clip`, `has_clips`, base clip `Idle`. Keep fingers (he hands over and sets a crate), drop twist/leaf/end bones, <= 4 influences.
4. **Logan clip list** (30 fps, loops closed, one action each, never drop a bone channel): `Idle`, `Idle2` (scans the water, adjusts the hat), `Talk` (grounded hand gestures), `Point` (down the outflow toward the river), `Walk`, `Turn`, `Greet` (notices Lil Blunt), `Crouch` + `PlaceCrate` (the stage interaction, shared with Lil Blunt's beat), `Watch` (arms folded, looks at the water level), `Nod` (confirms). No `Cast`, `Reel`, `Catch`.
5. Face: a bearded face under a hat brim; expression mostly from head/jaw and brow bones if the loops exist (`blender-facial-shapekeys`); do not deform the hat.
6. Export `src/episode2/assets/lake/logan.glb` with Godot-safe settings (`use_selection=True`, export fails loudly on unknown kwargs), AnimationPlayer clip names matching `Ep2TownFolk`.

## Proof (all required)
`blender-asset-qa` `qa_check.py --profile game`; `rig_check.py` + `stress_poses.py` renders (no collapse at elbows, knees, shoulders; hat rigid); `mesh_stats.py --budget web`; Godot 4.3 import; every clip rendered in-engine at the lake from the Episode 2 camera, side by side with `Logan.JPG` (the founder is the judge); fresh-clone pack gate + `tools/ep2_forge/texture_ref_probe.gd`; test that `has_clips()` is true and no clip is named cast/reel/catch.
