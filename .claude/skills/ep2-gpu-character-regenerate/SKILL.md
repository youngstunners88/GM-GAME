---
name: ep2-gpu-character-regenerate
description: Regenerate an Episode 2 character (Inferno Bull, the bears) at high detail on a Runpod GPU - reference image -> Hunyuan3D-2.1 shape -> paint -> decimate -> skin onto the EXISTING 24-bone game skeleton -> engine capture graded against the reference - with the cost gates, version pins and traps already paid for. TRIGGER on "regenerate the Bull/bears", "higher detail", "still trash", "use the GPU", "Hunyuan", "turn on the gpu", or any character whose Tripo/Meshy sculpt is soft next to the founder's reference.
---

# GPU character regeneration (verified 2026-10-15)

Founder verdict that triggered this: Bull "still trash" - the soft Tripo sculpt is the ceiling, lighting cannot fix it.
Hunyuan3D-2.1 from his reference image gave a far sharper shape in 67 s (hat, bandolier, buckle, pouches, boots, rifle, cigar).
Companion skills: `ep2-cloud-gpu-runpod` (pod facts, cost rules), `runpod-signin` (connect Runpod), `ep2-bull-repose-hero`
(old Bull history), `ep2-reference-match-loop` (proof), `ep2-asset-forge`. Scripts: `tools/ep2_runpod/hunyuan/`.

## Money rules (the founder pre-approved these for the build; keep them anyway)
1. A pod bills from creation. Arm the 70-minute self-stop FIRST (`watchdog.sh`, `runpodctl stop pod $RUNPOD_POD_ID`).
2. Report GPU, minutes and $ at the end. Terminate when done; a stopped pod still bills disk (~$0.20/GB/month) and
   its host may have no free GPU, so it often cannot be restarted. Download results BEFORE stopping.
3. Capacity is LOW: 5090 EU-RO-1 and 4090 EUR-IS-2 were the only stock. One fallback attempt, no retry loops.

## Pipeline
| Step | Where | Notes |
|---|---|---|
| Reference | repo | background-remove first (`hy3dshape.rembg.BackgroundRemover`). Front 3/4 view, full body. |
| Shape | pod | `gen.py`: 50 steps, octree 384, seed fixed. 677k faces. |
| Decimate | pod | `decim.py` quadric to 60k for the paint model (pymeshlab). |
| Paint (PBR) | pod | `paint.py` (max_num_view 6, res 512). Needs custom_rasterizer + mesh painter + RealESRGAN. |
| Game mesh | laptop | decimate to 12-20k, UVs, 1K maps; `tools/ep2_forge/bull_hunyuan_to_rig.py` transfers the OLD skeleton/weights. |
| Proof | laptop | `bull_game_inspect.py --stretch`, then capture vs reference (`ep2-reference-match-loop`), Jev numbers. |

## Version pins (the repo's requirements.txt does NOT install on Python 3.12)
`transformers==4.46.0 diffusers==0.30.0 huggingface-hub==0.30.2` + `timm` + `numpy>=2.1,<2.4`.
Latest transformers -> "Error(s) in loading state_dict for SingleImageEncoder". `numpy<2` -> scipy 1.18 "no attribute long".
`hy3dshape` installs with `pip install --no-deps -e`. Paint: `TORCH_CUDA_ARCH_LIST="8.9;12.0"` (4090 + 5090),
`python3-dev` (else `python3-config: command not found`), `libopengl0` (pymeshlab Qt plugin spam), `ninja`, `pybind11`.

## Operating traps
- No SSH key on the Runpod account -> use Jupyter (`pod.py` exec, `up.py`/`dl.py` files). Password comes from the pod env
  via the Runpod MCP; pass it in env `PODPW`, never commit it. Raw TCP from the cloud container is blocked.
- `cd /workspace && nohup x & nohup y &` runs `y` in the WRONG directory (the `&` backgrounds the whole `&&` list). Use `;`.
- The `runpod-key` MCP is invisible to a session started before it was added: call it through `claude -p ... --allowedTools mcp__runpod-key`.
- Hunyuan output is untextured/ungrouped, not rigged: skin from the OLD game Bull so walk/run/sit clip GLBs (matched by
  bone name) keep working. Never IK arms to shoulder height (Tripo skin webs); keep rest-arm locks until a rest-aware clip is proven.
- Pack budget 189.2/190 MiB: the new GLB must REPLACE `inferno_bull_rigged.glb` (5.4 MB) / `bear_rigged.glb` (4.7 MB).
- Do not claim "fixed" from a render alone: grade the engine capture against the founder's image with numbers.
- **Extracted-texture trap (cost an hour):** `.glb.import` has `gltf/embedded_image_handling=1`; Godot reuses the old
  `<name>_0.jpg/_1.jpg` it extracted last time, so a new GLB shows the old atlas on new UVs (shattered). Delete those files
  + their `.import` before reimport. Verify a GLB's UVs with a Blender import round-trip, not just the pre-export scene.
- Local engine test: `godot --path <git worktree> --rendering-driver opengl3 res://tools/ep2_shots/bull_close_shot.tscn -- out=DIR`
  (Godot 4.7.2 at `~/.local/bin/godot`; the project is 4.3, so do not commit its re-import changes).
- Hunyuan paint leaves the FACE dark: plan a face repaint pass; never lift with emission (it fogs the figure).
