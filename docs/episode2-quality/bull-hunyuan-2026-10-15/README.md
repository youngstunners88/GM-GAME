# Inferno Bull - Hunyuan3D-2.1 regenerate (2026-10-15, Runpod RTX 5090)

**Result so far: SHAPE ONLY, good.** `design/ep2/blender/character-work/bull_hunyuan21_shape_2026-10-15.glb`
(677k faces, untextured, 1.2 x 0.94 x 2.0 units). From `reference.jpg` in 67 s on a 5090. It has the horned
miner's hat, bandolier, belt buckle, pouches, boots, rifle and cigar - far more detail than the soft Tripo sculpt
(see `shape_front.png`, `shape_side.png`). Missing from the shape: aviators, helmet lamp, nose ring (texture work).

**Update 2026-10-15 (later):** texture/PBR DONE (Hunyuan3D-Paint, 72 s), skinned onto the game skeleton DONE
(`bull_hunyuan_painted_rigged_candidate.glb`, 40k faces, 3.98 MB, Idle_02 0 stretched edges). Still NOT done: engine
wiring/grading (no Godot on the laptop). See 'Integration checklist'.

## Pipeline that worked (pod: runpod-torch-v280, Python 3.12, torch 2.8.0+cu128)
1. Clone `Tencent-Hunyuan/Hunyuan3D-2.1`; the repo's pinned requirements.txt does NOT install on py3.12.
   Install loosely, then pin: `transformers==4.46.0 diffusers==0.30.0 huggingface-hub==0.30.2`, plus `timm`,
   and keep **numpy 2.1-2.3** (numpy<2 breaks scipy 1.18). `pip install -e hy3dshape --no-deps`.
2. `tools/ep2_runpod/hunyuan/gen.py`: BackgroundRemover -> `Hunyuan3DDiTFlowMatchingPipeline` (50 steps, octree 384).
3. Paint: needs `custom_rasterizer` (TORCH_CUDA_ARCH_LIST=12.0 for the 5090), `compile_mesh_painter.sh`
   (needs `python3-dev`; `python3-config` was missing) and `RealESRGAN_x4plus.pth`. Not yet confirmed working.
4. Rig/skin: reuse `tools/ep2_forge/build_bull_from_tripo_rig.py`, `retarget_bull.py`, `rig_tools.py`.

## Next steps
- Re-create a pod (the old one is pinned to a host with no free GPUs), run `run_all.sh`, read `run_all.log`.
- Fallback texture: project the reference onto the mesh in Blender and paint the rest, or bake from Tripo.
- Then decimate to ~12-20k faces, 1K maps, skin transfer from the current Bull, `ep2-reference-match-loop`.
- Pack budget is 189.2/190 MiB: the new Bull must replace, not add to, `inferno_bull_rigged.glb` (5.4 MB).

## Pod operating notes
- No SSH key was registered on the account, so everything went through Jupyter (`pod.py`/`up.py`/`dl.py`,
  password read from the pod env; never committed).
- Always arm `watchdog.sh` (stops the pod after 50 min). Stopped pods still bill disk (~$0.20/GB/month).

## Integration checklist (do on a machine with Godot; engine-test before shipping)
1. Keep the old GLB: `git mv`/copy `src/episode2/assets/inferno_bull_rigged.glb` -> `.farm/retired/`.
2. Copy `design/ep2/blender/character-work/bull_hunyuan_painted_rigged_candidate.glb` to
   `src/episode2/assets/inferno_bull_rigged.glb` (same node/bone names; clips load by bone name).
3. `src/episode2/actors/ep2_bull_hero.gd`: the material grade (albedo x 0.60,0.66,1.04) was tuned for the OLD texture;
   the painted albedo is already dark - drop/relax it or the Bull goes black. Keep the rest-arm locks (Ep2BullRestArm).
4. A rifle is baked into the left fist: hide/skip the separate `Ep2BullHeroRifle` prop, or it doubles.
5. The face under the hat is dark: lift it with the hideout fill light / a fresnel-free albedo curve; measure with
   `ref_metrics.py` against `inferno_bull_with_rifle.jpg`, then Jev + Astra (`ep2-reference-match-loop`).
6. Pack gate: the new GLB is smaller (3.98 vs 5.6 MB), so the budget improves.
