---
name: ep2-3d-tools
description: Use before shrinking a character GLB, reading why the web pack is over 190 MiB, or considering meshoptimizer/gltfpack or UniForge3D for the Bull/bear. Carries the verified Godot 4.3 traps and the exact commands.
---

# Episode 2 3D tools (surveyed 2026-10-17)

Full evidence: `docs/episode2-quality/3d-tools-survey-2026-10-17/README.md`.

## 1. Pack too big? Look inside first
`python3 tools/ep2_forge/pck_report.py web_verify/game/index.pck` (the fresh-clone pack gate prints it on failure).
Real split of a 197 MB pck: audio 82 MB, textures (`.ctex`) 58 MB, cutscene video 29 MB, **all 3D models 22 MB**. Source GLBs and dev sources are not in the pck, so do not expect a smaller source GLB to fix the pack. Biggest safe wins: lossy-import big photographic JPG textures (`compress/mode=1`, tracked `.import`, like `inferno_bull_rigged_*.jpg.import`) and re-encode long music.
Measure on a FRESH clone (`scripts/pack-gate-fresh.sh`): a warm `.godot` cache hid 15 MB of re-extracted Bull textures once.

## 2. gltfpack (installed at `~/.local/bin/gltfpack`, built from zeux/meshoptimizer master)
- NEVER run it in default mode on a game asset: output uses `KHR_mesh_quantization`, which **Godot 4.3 refuses to import**.
- Use `tools/ep2_forge/gltfpack_safe.sh in.glb out.glb 0.5` (`-noq -kn -km -si R -sv`, restores the mesh name, checks joints/clips, import-tests in Godot 4.3, prints scene sizes). Bull at 0.5: scene 2.41 -> 1.39 MB, looks identical in the engine.
- Bear: `BORDERS=lock` (`-slb`) so its ~870 detached shells (quiver arrows) are not pruned.
- A simplified skinned mesh must be swapped in as a COPY, re-shot in every pose and pushed through `scripts/ci-gates-local.sh`; never swap blind.
- Branch `gltf-half` (half-float) and `gltf-xuastc` (KTX2) are unusable on Godot 4.3.

## 3. meshoptimizer library ideas (Python: `~/tools-src/venv`, `import meshoptimizer`)
`simplify_with_attributes` (carry skin weights through decimation instead of Blender decimate + weight transfer), `SIMPLIFY_LOCK_BORDER` (keep the Bull neck rim fixed), `SIMPLIFY_PRUNE` (drops small disconnected shells: a stray-needle detector, but it deletes the bear's arrows), `generate_vertex_remap` (position weld).

## 4. UniForge3D (xibushu/UniForge3D, Apache-2.0)
Multi-view images -> static textured GLB (TRELLIS.2 + VGGT). No rigging. Needs CUDA 12.4 + compiles flash-attn/CuMesh/nvdiffrast, 27 GB weights, gated DINOv3 (HF token) and RMBG-2.0 (non-commercial: supply our own alpha cut-outs). RunPod only (A40 $0.59/hr, about $0.6-1.2 per test, stop at $3, log the pod ID). Best fit: the bear turnaround `REF_balaclava-bear-archer_turnaround.jpg`. Does not fix the bear's arm-rig/paw-contact blocker. Needs the user's go for spend and a token.
