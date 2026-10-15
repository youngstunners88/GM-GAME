# HANDOFF — RunPod AssetFurnace horse run (for Claude Code on founder's Omarchy box)
Date: 2026-10-16 · From: opencode session (no GPU here) · To: Claude Code (has the key)

## Objective
Generate a photoreal RIGGED horse GLB with AssetFurnace on a rented RunPod GPU,
return it to this repo. The in-repo procedural horse
(`src/assets/models/horse/`, 8 walk + 6 graze frames) stays as fallback.

## Auth (same box — this just works)
```bash
set -a; source ~/.config/gm-game/runpod-env; set +a   # never cat/print it
```

## 1. Create the pod (console or API — console is fine)
- GPU: RTX 4090 / RTX 5000 Ada / A5000 — **24 GB VRAM minimum** (Hunyuan paint needs ~21 GB)
- Image: RunPod PyTorch + CUDA (2.x) template, Python 3.11
- Storage: 60 GB+ container disk (weights 15–20 GB + workspace)
- Cost check FIRST, tell the founder $/hr and confirm. **Stop the pod when done.**

## 2. On the pod (SSH in)
```bash
git clone https://github.com/Bingeljell/image-to-3dlab && cd image-to-3dlab
curl -fsSL https://assetfurnace.com/install.sh | bash -s -- --yes --dir ~/lab
# Setup & Status page (./lab prints the URL): set up Pixal3D first (8.4 GB).
# If Pixal3D build fails on the pod GPU: python scripts/bootstrap_pixal3d.py --compile --yes
```

## 3. Input picture (order of preference)
1. Founder-supplied side-profile horse photo (legs separated, head up, plain background).
2. Otherwise our render: `src/assets/models/horse/` reference frame (stylized — expect stylized output).
3. Otherwise text prompt in the studio (Qwen-Image): "side view bay horse, all four legs visible, white background".

Pre-masked RGBA PNG skips background removal and keeps pixel match exact.

## 4. Generate + finish
- Backend: Pixal3D first; TRELLIS.2 if fidelity disappoints (beware colour drift on flat art — use photos).
- Finish chain: retopo (~40k faces) → Pixel Match ON → compress. Raw 30 MB GLB never ships.
- Quadruped check: `docs/quadruped-pipeline.md` — feet must stay planted. Sliding rig = keep MESH, re-rig with our Blender rig instead.

## 5. Return to repo (new branch `assetfurnace/horse-v1`, push it)
```
src/assets/models/horse/assetfurnace/
  source.png  horse.glb  horse_finished.glb  provenance.json  RUN_NOTES.md (backend, seed, pod type, cost, license class)
```
- License: record backend + weight licenses (Hunyuan weights NOT EU/UK/SK — flag it).
- Do NOT edit game code/scenes. Do NOT touch `src/level/*`, `STATUS.md`, or front-page files.
- Reply here with: branch name, turntable screenshot path, byte sizes, total GPU cost.

## 6. What happens next (opencode session picks up)
Godot 4.3 GLB import → side-view frame renders (transparent, feet-planted shared
canvas) → SpriteFrames loops in `stable_horses.gd` → live capture proof.
