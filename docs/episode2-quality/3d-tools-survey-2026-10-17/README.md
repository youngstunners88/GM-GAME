# meshoptimizer + UniForge3D: what they do for us (surveyed 2026-10-17)

Both repos cloned with every branch (`~/tools-src/`, outside the game repo) and the code read, not just the READMEs. Everything marked VERIFIED was run here.

## 0. The finding that changes the plan: what is actually in the 190 MiB pack
`tools/ep2_forge/pck_report.py` parses the real `index.pck` (197.2 MB, 2,509 files):
| Kind | MB | |
|---|---|---|
| audio (`.mp3str` 57 + `.oggvorbisstr` 25) | 82 | music tracks of 2-3.4 MB each, many alternates |
| textures (`.ctex`) | 58 | lossless imports of big JPG backgrounds (`bear_scene_2.jpg` 5 MB, `tex_floor` 4.9 MB ...) |
| cutscene video (`.ogv`) | 29 | 5 files, 3.8-8.8 MB |
| **all 3D models (`.scn`)** | **22** | Bull 1.95, bear 1.97 |
| scripts, rest | ~6 | |
Source GLBs are NOT in the pck (only Godot's imported `.scn`); dev sources (`.blend`, HDR, `_sources/`) are not either. So **shrinking a source GLB barely moves the pack**, and the "0.35 -> ~5 MiB headroom" estimate from the first gltfpack run was wrong. Real headroom: lossy-import the biggest photographic textures (the Bull fix already proved `compress/mode=1` works) and re-encode the longest music tracks; that is tens of MB, with no character changes.

## 1. meshoptimizer (branches: master, gltf-half, gltf-xuastc, gh-pages)
**Installed:** `gltfpack` built from master with g++ (no cmake/sudo) at `~/.local/bin/gltfpack` (630 KB, v1.3). Python binding in `~/tools-src/venv` (`meshoptimizer` 0.2.30a0: `simplify_with_attributes`, `SIMPLIFY_LOCK_BORDER`, `SIMPLIFY_PRUNE`, `generate_vertex_remap`).
**VERIFIED on the Bull (Godot 4.3.0 headless import):**
- gltfpack's DEFAULT output (the "-36%" in the doc) is **rejected by Godot 4.3**: "required extension KHR_mesh_quantization is not supported". `-noq` is mandatory.
- `-noq -kn -km`: imported scene 2.41 -> 2.25 MB (-7%); joints (24), clips (4) and node names preserved, mesh name lost (restored by our wrapper).
- `-noq -si 0.5 -sv`: 63,565 -> 31,781 triangles, scene 2.41 -> **1.39 MB (-1.0 MB)**; in the engine the face, aviators, cigar, bandana and rifle look the same (`bull_simplify_orig_head.png` vs `bull_simplify_50_head.png`).
- Bear `-si 0.5`: scene 1.97 -> 1.25 MB (prune) or 1.37 MB (`-slb`, keeps the ~870 detached shells such as quiver arrows).
**Branches:** `gltf-half` = half-float positions/UVs (`-vph`), needs the quantization extension in Godot terms: not usable on 4.3. `gltf-xuastc` = XUASTC/KTX2 textures: Godot 4.3 does not read `KHR_texture_basisu` from GLB; the game's textures are `.ctex` anyway. `gh-pages` = the website demo. `js/` = wasm decoder/encoder (browser side, irrelevant to Godot).
**Library features mapped to OUR defects (not yet used, worth a try):**
- `meshopt_simplifyWithAttributes` with skin weights as attributes + `vertex_lock`: decimate rigged meshes without the Blender-decimate-then-transfer-weights step that produced the bear/Bull skinning damage.
- `SimplifyLockBorder`: keeps open borders fixed, i.e. the Bull neck/shoulder rim while it is being repaired.
- `SimplifyPermissive`: collapses across UV seams, for the atlas-shredded Hunyuan meshes.
- `SimplifyPrune` (gltfpack does this unless `-slb`): deletes small disconnected shells. Good for stray junk, harmful for the bear's arrow/fur shells. This is also a ready-made detector for the "needle" class of defect.
- `generate_vertex_remap` / `generatePositionRemap`: position-weld, the same idea as `glb_smooth_skin.py`.
**Decision:** gltfpack is worth it only as `tools/ep2_forge/gltfpack_safe.sh` for a ~1 MB/character saving, never in default mode.

## 2. UniForge3D (single branch `main`, Apache-2.0, 10.7k lines of Python)
What it is: sparse, unposed multi-view images (about 4 per object) -> one textured GLB, built on TRELLIS.2 + VGGT. Stages: structure (flow), shape at 512 then 1024, texture 1024; CuMesh remesh + decimation; UV unwrap and bake to a 2048 texture (`texture_baking.py`). `infer.py` takes `assets/<case>/*.png`, writes `outputs/<case>/prediction.glb`.
What it is NOT: it does not rig, skin or animate. Output is a static mesh, so the skeleton/skinning problem (the real blocker for the bear) is unchanged.
**Requirements (read from `setup.sh`, `pipeline.json`, HF repo):**
- NVIDIA GPU with CUDA 12.4 toolchain: compiles flash-attn 2.7.3, CuMesh, FlexGEMM, nvdiffrast, o-voxel. Not runnable on this PC (GeForce 920MX, 2 GB, sm_50). RunPod only.
- Weights: 27 GB on HuggingFace `xibushu/UniForge3D` (not gated), plus TRELLIS.2 backbone weights, plus two **gated** external models: `facebook/dinov3-vitl16-pretrain-lvd1689m` (needs a HuggingFace token and accepting Meta's license) and `briaai/RMBG-2.0` (background removal; **non-commercial license**, so for a commercial game supply our own cut-out alpha PNGs instead).
- Estimated RunPod cost: A40 48 GB at $0.59/hr, about 1-2 h for install + downloads + one object = **$0.6-1.2**, hard stop $3. Nothing was run; no pod created.
**Where it would help:** the bear. `REF_balaclava-bear-archer_turnaround.jpg` is a real multi-view sheet (crop 3-4 views). A one-piece body+head generation has no head/body seam (the Bull problem). The Bull has no consistent multi-view set (the four `inferno_bull_*.jpeg` are different poses). It would still need our skin-transfer + `glb_smooth_skin.py` pass, and the bear's arm-rig problem (arms ~0.5 m from the skeleton's hands) is a retarget problem it does not solve.
**Decision:** not now. Candidate for one RunPod test on the bear turnaround after you approve spend and a HuggingFace token.

## 3. Recommended order
1. Pack headroom first (free, no art changes): lossy-import the big photographic `.ctex` textures; trim the longest audio. `pck_report.py` shows the list.
2. Optional `gltfpack_safe.sh ... 0.5` on Bull (and bear when it ships): about 1 MB each, must be eyeballed in the poses.
3. Bull hand/pouch fused weights: Blender job, `SimplifyLockBorder`/weld ideas above.
4. Bear arm rig: the blocker; UniForge3D does not remove it.
