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

## Engine test result (2026-10-15, Godot 4.7.2 on a throwaway worktree, `bull_close_shot.tscn`)
Pictures: `engine_old_front.png` (shipping Bull) vs `engine_new_front_emis035.png` (candidate). **Verdict: NOT ready to swap.**
- Mapping is correct in the engine once the stale extracted textures are removed (see the trap below).
- Wins: richer clothing detail (bandolier, buckle, pouches, bandana), lamp on the hat, 3.98 MB vs 5.6 MB.
- Losses: the face under the hat is BLACK (aviators and cigar are lost; the old Bull's face reads better), and a
  self-lit lift (emission 0.35) washes the whole figure into fog. Orange dot on the face is the cigar/old lamp glow.
- `engine_swap_wip.patch` holds the three GDScript edits tried (grade off, no texture overrides, no lamp prop, emission).
  Do not apply the emission change. Next: repaint the face region of the albedo (composite from the reference at the
  hat/face UV islands), keep emission 0.0-0.08, then re-run the shot and the reference-match numbers.

## TRAP: the project's `.glb.import` uses `gltf/embedded_image_handling=1` (EXTRACT TEXTURES)
Godot extracts embedded textures to `inferno_bull_rigged_0.jpg` / `_1.jpg` next to the GLB and then REUSES those files.
Swapping in a new GLB keeps showing the OLD textures on the new UVs: a scrambled, shattered look that is NOT a UV bug
(Blender renders the same GLB perfectly). Delete the extracted `_N.jpg` + `.import` files before reimporting. Also keep
the project's original `.import` (generate_lods=false), a fresh Godot 4.7 one adds LODs. Same applies to the bear.

## Face diagnosis follow-up (2026-10-15, later; Poly Haven studio light + 4 engine experiments)
Studio renders (`studio_old_front.png`, `studio_new_front.png`, `studio_new_34.png`, HDRI `studio_small_08`): under neutral softbox the
new Bull's aviators, cigar and bandana read, but fur/face albedo is very dark. In-engine experiments on the worktree, all in
`bull_close_shot.tscn`: (1) emission 0.35: fogs the whole figure; (2) albedo gain 1.7x: no change to the face; (3) warm
OmniLight fill in front of the face: no change; (4) UNSHADED: face still black while clothing shows true colours. **The face albedo
itself is near-black.** Fix = repaint/lift the face UV islands in the albedo (locate islands from the UVs of the head vertices),
then re-run the shot. Earlier note "face is dark because of lighting" is superseded by this.

## v2 (face repaint) engine verdict (2026-10-15, Godot 4.7.2 worktree, `engine_head_compare_old_v1_v2.png`: old | v1 | v2)
Method: reference head camera-projected into the face UV islands (378 faces, 0.28% of the atlas; `tools/ep2_blender/bull_face_repaint.py`),
non-face region unchanged (0.00%). Numbers: face luminance 0.153 -> 0.180, contrast 0.147 -> 0.195, crop SSIM vs reference 0.07 -> 0.41.
**In the engine v2 is better than v1 but still NOT at the shipping Bull's face**: faint brow/rim detail shows, lenses and snout are still
dark, thin seam cracks remain (only camera-facing faces were repainted on a shredded atlas), the orange dot is the old cigar-ember prop
at the `headfront` bone. **Do not swap yet.** Options, best first: (1) regenerate JUST THE HEAD from a face close-up reference
(Hunyuan puts its detail budget on the face; ~$0.5 of GPU) and graft it on the new body; (2) a second repaint pass with all head
faces (not only camera-facing), lenses lifted to reference value, then re-shoot; (3) keep the shipping Bull's head and use the new
body only. Engine edits to carry when this ships: see `engine_swap_wip.patch` (without the emission and fill-light experiments,
which did nothing useful) + delete the extracted `inferno_bull_rigged_0/1.jpg` before reimport (trap above).

## v3 = new HEAD (face close-up regenerate) grafted on the v2 body (2026-10-15)
GLB `design/ep2/blender/character-work/bull_hunyuan_head_v3_rigged_candidate.glb` (6.04 MB; shipping 5.6; pack headroom 0.8 MB: OK only if it
REPLACES the old one). Script `tools/ep2_forge/bull_head_graft.py`. Head: Hunyuan3D-2.1 octree 512 from `head_ref_input.png`
(smoke wisp removed), painted at 512, rigid to the `Head` bone with a 5 cm blend to `neck`. Fit: IoU grid search (scale 0.39, front IoU 0.81).
Face now legible in neutral light AND in the engine (`engine_v3_head_zoom.png`: eyes, nose ring, ears, bandana).

### Left-elbow / transparency (founder request): culling ON vs OFF, magenta background, Idle_02 and walk, both elbows, 3 views
| Case (pixels visible only because back faces show) | v3 | v2 | shipping Bull |
|---|---|---|---|
| idle, arms locked / free | **0** | 2 / 36 | 10,819 |
| walk, arms locked | **0** | 2,099 | 12,685 |
| walk, arms free | 30 | 10,082 | 17,861 |
Interior holes (magenta enclosed in the silhouette): 0, 0, 0, 30 in the same order. So the SHIPPING Bull is the one with see-through
surfaces (single-sided shells, the old "see-through Bull" bug the engine hides with CULL_DISABLED); v3 does not depend on that fix.
Cost of the seam weld: ~150 more stretched edges in the walk (803 mean vs v2 609, shipping 1,366).

### Open items before the swap (engine integration, needs Godot):
1. Skip the old lamp disc and the cigar-ember prop (`_cigar_tip`, bone `headfront`) for the painted model: they sit mid-face on the new head.
2. Seam: visible open rims at the character's right neck/shoulder (75 body + 50 head boundary edges seen from outside); fill or overlap.
3. Delete the extracted `inferno_bull_rigged_0/1.jpg` + `.import` before reimport (trap above); keep the project's original `.glb.import`.
4. Re-shoot with the HUD hidden; run `ep2-reference-match-loop` numbers; ship only after a Godot 4.3 export gate.

## v3 SWAPPED INTO THE ENGINE (2026-10-16, branch `bull-v3-engine-swap`, Godot 4.7.2 worktree shots)
`src/episode2/assets/inferno_bull_rigged.glb` is now the v3 candidate (6.04 MB; same 24 joints, same four clips, same mesh
name, checked against the old file). The old GLB is in git history (`git show 26667644:src/episode2/assets/inferno_bull_rigged.glb`).
Engine edits, all behind one switch `Ep2BullHero.PAINTED_GLB` (set false to restore the old Bull's grade and props):
- `ep2_bull_hero.gd`: albedo grade off (painted albedo is already dark), no rest-pose lamp prop, no separate rifle prop.
- `interlude_base.gd`, `smelting_facility.gd`: no `bull_albedo/metal/normal` texture overrides (own UVs), emission 0.04 (0.35 fogged it).
- `smelting_facility.gd`: no cigar-ember/smoke props (the model's cigar is in its face); the guard-rifle prop is kept for
  the aim code's muzzle point but never drawn, so the baked rifle is not doubled.
- The stale extracted `inferno_bull_rigged_0.jpg(.import)` are deleted; Godot re-extracts on import (trap above).
Pictures: `engine_v3_swapped_front.png`, `engine_v3_swapped_side.png` (aviators, nose ring, bandana, lamp, cigar legible; one
rifle in the fist; the orange glows in frame are room embers, verified by shooting the same view with the Bull hidden).
**Still open:** neck/shoulder seam (75 body + 50 head boundary edges seen from outside; reads as an opaque wall, not a hole),
a Godot 4.3 export gate, and `ep2-reference-match-loop` numbers against `inferno_bull_with_rifle.jpg`.
