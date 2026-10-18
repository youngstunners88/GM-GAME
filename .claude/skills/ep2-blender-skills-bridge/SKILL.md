---
name: ep2-blender-skills-bridge
description: How to use the installed EL4CTEO/blender-skills library (22 blender-* skills, ~/tools/blender-skills) inside GM Game - which skill owns which Episode 2 job, the exact headless commands that work on this Linux box, and where this repo's rules OVERRIDE the library (headless only, Godot 4.3 import, pack budget, texture extraction). TRIGGER on any Blender, bpy, GLB, kit piece, prop, rig, clip, lane/facade, render or "use the blender skills" work for GM Game, before calling blender-core.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Blender skills x GM Game

The library is installed (symlinks in `~/.claude/skills` -> `~/tools/blender-skills/skills`, v1.1.0, commit `71d031d`, MIT). Read its `blender-core` first for any task; this page says how it plugs into the repo and where the repo wins.

## Run it (verified on this box: Blender 5.2.1 LTS at `/usr/bin/blender`, Linux, CPU/EEVEE only)
```
S=~/.claude/skills
python3 $S/blender-core/scripts/run_in_blender.py $S/blender-core/scripts/env_report.py          # first call of a session
python3 $S/blender-core/scripts/run_in_blender.py --blend in.blend $S/blender-asset-qa/scripts/qa_check.py -- --objects A B --profile game
python3 $S/blender-core/scripts/run_in_blender.py --expr "import bpy; print(len(bpy.data.objects))"
```
Each script prints one JSON result and documents its flags in its docstring: **run them, don't read them**. Every `.py` in this repo's `tools/ep2_blender/` is built the same way (a build script in the repo, run with `blender -b -P ... -- args`, idempotent, output to a log file).

## Repo rules that OVERRIDE the library
1. **Headless only.** The library prefers the MCP `look`/`execute_blender_code`. Here, never render or build large scenes through the GUI MCP (8 GB RAM, 920MX: it froze and lost a scene, 2026-10-05). GUI MCP = inspect and tiny edits. Use `blender-asset-qa/scripts/review_shots.py` (Workbench contact sheets) or a log-redirected Cycles/EEVEE run (`blender-headless-render-safety`: `> .farm/run.log 2>&1`, small first, scale 4096 textures to 2048). No usable local GPU: heavy bakes/renders/AI generation go to Runpod (`ep2-cloud-gpu-runpod`, `ep2-runpod-motion-lab`), with the $25 spend cap and logged pod IDs.
2. **Scripts live in the repo**, not in the live scene: `tools/ep2_blender/<thing>.py` (see `build_town_kit.py`, `build_armory_folk.py`). A scene that only exists in RAM is a scene you will lose.
3. **Do not use `export_asset.py --preset godot/web` as the final step blindly.** Our rules: export with `use_selection=True` (the MCP addon plants an Icosphere), unknown `export_*` kwargs must fail loudly, front = -Y / feet z=0, and **GLB textures are NOT free**: Godot extracts embedded textures into loose files the imported scene uses; the 2026-10-18 pack trim that excluded them turned the rifle, lift cage, quad and town cast white. Measure with `scripts/pack-gate-fresh.sh`; prove invisibility with `ship-visual-proof` + `tools/ep2_forge/texture_ref_probe.gd`. The web preset's meshopt/WebP are three.js features; they are not what the Godot 4.3 import consumes. Shrinking recipes: `ep2-3d-tools` (`gltfpack_safe.sh`, `pck_report.py`).
4. **Pack gate is hard:** fresh-import `index.pck` <= 199,229,440 B (190 MiB). A source-GLB shrink barely moves the pack; loose textures do. Budgets from `blender-game-optimization` (web: 10-30k tris hero, 2048 max textures) are ceilings, not targets. Town kit pieces are far smaller; match neighbours.
5. **Never loosen a gate** and never ship a look change nobody asked for (founder: "Why are you doing shit I didn't ask for"). Library "improvements" (re-lighting, new materials, re-grading) need a request.
6. **Blender 5.2 quirks already paid for:** `blend_method` -> `surface_render_method`; actions have no `.fcurves` (channelbags; `build_armory_folk.py` has `action_fcurves()`); glTF imports use quaternion mode (set `rotation_mode='XYZ'` before assigning Euler); keep glTF actions linked or they export nothing; clips must key every bone a previous clip touched or Godot keeps stale poses (`export_optimize_animation_keep_anim_armature=True`, never drop a bone channel).

## Which library skill for which GM Game job
| Job | Library skill(s) | Repo skill that owns the decision |
|---|---|---|
| Town facade / lane piece / prop (kit pieces) | `blender-hardsurface-modeling` (mid-poly, bevel + weighted normals), `blender-scene-setup` (names, origins, scale), `blender-asset-qa` | `ep2-side-lane-build`, `ep2-living-town`, `ep2-town-facades` |
| Repeat/scatter fences, rails, lane clutter | `blender-geometry-nodes` (`gn_builder.py`) - keep instances, realize late | `ep2-side-lane-build` |
| Tripo/Meshy character (Rich, Utah, Logan) cleanup, retopo, UV | `blender-retopology-uv`, `blender-game-optimization` (`mesh_stats`, decimate), `blender-asset-qa` | `ep2-tripo-folk-to-game`, `ep2-tripo-mesh-surgery` |
| Rig + skin to the game skeleton | `blender-character-rigging` (`bind_mesh.py` proxy fallback for AI meshes, `rig_check.py`, `stress_poses.py`) | `ep2-tripo-folk-to-game` |
| Clips: work routines, greet, point, carry; retarget mocap | `blender-animation` (`bake_action.py`, constraints retarget), `blender-pipeline-automation` | `ep2-runpod-motion-lab`, `ep2-armory-npc-autonomy`, `ep2-character-performance` |
| Materials / texture sets | `blender-pbr-materials` (OpenGL normals for Godot, ORM = R AO G rough B metal), `blender-texture-baking` | `ep2-blender-props`, `ship-visual-proof` |
| Lighting judge / dusk look of a lane | `blender-lighting-lookdev`, `blender-time-of-day` (`--mood desert`, golden), `blender-rendering` | `ep2-reference-match-loop`, `see-it-yourself`. The shipped look is the Godot capture, never the Blender one |
| Batch QA / convert whole `design/` or `src/.../assets` | `blender-pipeline-automation` (`batch_process.py --op script --script qa_check.py`) | `ep2-3d-tools` |
| Weather, simulation, sculpting, facial shape keys, add-on dev | `blender-weather-fx`, `blender-simulation`, `blender-sculpting`, `blender-facial-shapekeys`, `blender-addon-development` | out of scope for Episode 2 town work unless the founder asks (no rain, no faces, no add-ons) |

## Done means (extends `blender-asset-qa`)
`qa_check.py --profile game` passes (or each warning is accepted with a reason), `review_shots.py` sheet looked at (`--mode random` finds detached parts, `--mode wire` topology), export file exists and is non-zero, then **Godot import + engine capture** (`ep2-sightline-proof` / `ship-visual-proof`). A green Blender QA is not a shipped look.

## Open: Logan
The Drive folder `1q4e5q-UVVOH0Dxu9CnRdXAi_4sLkj25K` also holds `Logan.JPG`, `Logan.glb` (23.9 MB), `Logan.zip` (12 MB), uploaded 2026-10-18 14:36 UTC next to Rich/Utah. Nothing in the repo or vault says who Logan is or where he stands (the 2026-10-19 log says "Logan parked"). Do not invent a role. Ask the founder, then route him through `ep2-founder-intake` -> `ep2-tripo-folk-to-game`; treat the 23.9 MB GLB like Utah's 67k-tri one: decimate, 1K textures, one shared clip set, and measure the pack before adding.
