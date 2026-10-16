# Bull seam / bear needle: can ComfyUI + Blender + RunPod beat AssetFurnace/Pixal3D? (2026-10-16)

Branch `bear-v2-engine-swap` @ `94ced40d` (contains the Bull v3 swap). Nothing generated, no paid call made.
Reports below come from `mesh_shell_report.py` and `red_shell_report.py` (Blender 5.2.1, `blender -b -P <script> -- <glb>`; JSON outputs next to them).

## What the two defects are (measured on the shipping-branch GLBs)
| | Bull `inferno_bull_rigged.glb` | Bear `bear_rigged.glb` |
|---|---|---|
| Shells after position weld | 4: body 36,043 faces, head 27,493, plus 12 and 10 | 968 (855 under 50 faces; top shell 16,308) |
| Boundary edges | 563 (clusters at z 1.85-1.95: the neck) | 16,653 (detached fur/leather shells) |
| Defect | head is a separate shell grafted on the body: the neck/shoulder seam is the gap between two open rims | needle = a thin red arrow shell not carried by the Spine02 pin; 24 small red shells (under 120 faces), top ones at x +-0.45..0.53, z 1.7..1.85, i.e. head height |
| Class | **geometry** (two open loops need a collar or bridge) | **geometry/skin** (delete or pin one or two tiny shells) |

Neither is a texture-quality defect, so a better generated texture cannot fix either one.

## Can the three tools beat the current output?
- **ComfyUI + SD1.5: no, and not runnable usefully here.** `~/ComfyUI/.venv` torch 2.14.1+cu130 supports sm_75 and up; the box GPU is a GeForce 920MX (2 GB, sm_50): a CUDA matmul fails with "no kernel image is available". CPU only, about 1 GB of 7 GB RAM free. SD1.5 is txt2img/inpaint on 2D pixels: it cannot close a mesh gap or remove a shell. Its only possible job is inpainting a small texture patch, and a collar can copy texels from the neighbouring fur in Blender for free. The checkpoint download (about 1.6 of 4.3 GB when checked) can finish or stop; it is not on the critical path.
- **Local Blender 5.2: yes, this is the tool for both fixes.** Free, scriptable, keeps the existing 24-joint skeleton, 4 or 7 clips and mesh name, so the rig contract and Bull clip GLBs stay valid.
- **RunPod (A40 $0.59/hr, cap $25, about $3.4 spent, no pod alive): not first.** Regenerating re-rolls the whole shape: the Bull face that now reads in the engine could be lost, Pixal3D/Hunyuan output is a static unskinned mesh that needs re-skinning again (the failure class that made the bear need smoothing), and the pod disk was wiped on the last key reset so a fresh install costs about 1 h. Only a fallback.

## Smallest tests, in order
**Test A, bear needle (geometry, local, $0, about 20 min).** Identify the shell in the sit_read shot (render the 4-5 candidate shells highlighted), then delete shells that are red, under 20 faces and above z 1.7 unless pinned, or extend `glb_smooth_skin.py --pin-mask` to them. Re-run the recipe in `bear-regenerate-2026-10-15/PLAN.md`, re-shoot run/sit_read/aim/shot/leap.
- Gates: needle absent in sit_read and no new one in the other four poses; mesh/skeleton/clips otherwise unchanged; Godot 4.3 `script_compile_test` PASS; GLB stays at or under 3.12 MB (shipping 4.7 MB, so the pack can only shrink).

**Test B, Bull seam (geometry plus copied texels, local, $0, about 1 h).** In Blender: select the body neck-hole boundary loop and the head neck-rim loop (the boundary clusters at z 1.85-1.95 in `bull_shell_report.json`), `bridge_edge_loops` into a collar of a few hundred triangles, copy skin weights from the nearest vertices of both rims (blend Head/neck), set the collar UVs onto an existing fur/bandana texel region so no new texture is needed. Fallback if the rims do not match in size: a sleeve that overlaps the rim by 2-3 cm. Re-export with the existing tools (`glb_downscale_textures.py` unchanged).
- Gates: 0 visible rim from front, side and 3/4 gameplay-camera shots (HUD hidden); walk stretched-edge mean not above 803 (v3) by more than 5%; **pack under 190 MiB = 199,229,440 B; Bull branch measured 198,798,912 B, margin 430,528 B**, and a few hundred triangles (tens of KB) fit, a new texture does not; Godot 4.3 `script_compile_test` PASS; local web export `scripts/ep2-local-export.sh` re-run because the margin is under 0.5 MiB.

**Escalation only if B fails:** regenerate the head alone with a flared neck cap on a RunPod A40 (Pixal3D/Hunyuan head only, about 4 min of GPU plus install, estimate $0.5-1.5, hard stop at $3), then graft with `tools/ep2_forge/bull_head_graft.py`. Stop the pod and log its ID the moment the GLB is downloaded.

## Verdict
Texture-generation (ComfyUI) does not apply, regeneration (RunPod) is the expensive path and is not needed first. Geometry edits in local Blender are the smallest test and cost nothing. Tests A and B are proposed, not run.

## Test A result (run 2026-10-16): PASS
The 12 needle vertices sit at glTF x -0.48, y 1.78-1.80, z 0.08: exactly on the `--mask-z-max 0.08` cut of the old recipe (the arrow tip's red vertices had z just past it, so the pin missed them). `mkmask.py` rebuilds the red mask (and the extra-vertex set); `needle_vertices.npz` is the exact 12-vertex set. A rebuilt mask does NOT reproduce the committed weights (the original `red.npz` is lost and a regenerated one pins different pieces and tears brown quiver shards), so the fix is a patch on the committed GLB: `python3 tools/ep2_forge/glb_pin_pieces.py in.glb out.glb needle_vertices.npz:Spine02:0` (pins only those 12 vertices to Spine02; the rest of the file is byte-identical, 3,119,283 B unchanged).
Pictures: `testA_before_sit_read.png`, `testA_after_sit_read.png`, `testA_after_poses.png` (run, sit_read, sleep, aim, shot, leap). Needle gone in sit_read, no change elsewhere. Godot 4.3 compile gate: see work log.
Test B (Bull seam) NOT run, by the user's choice.
