---
name: ep2-asset-forge
description: Make Episode 2 look like the founder's reference art instead of grey boxes — Meshy image-to-3D WITH PBR (colour + normal + roughness), MuAPI seamless surface textures, ElevenLabs SFX — in one command, sized for the web pack. Use when any Episode 2 model, texture or sound is missing, placeholder, flat-coloured, or the founder says the stage looks cheap/grey.
---

# Episode 2 asset forge

One command builds every textured runner asset in parallel:

```bash
python3 tools/ep2_forge/forge_runner_assets.py                 # everything
python3 tools/ep2_forge/forge_runner_assets.py --only pickaxe,gold_vein
```

- **Models** → `src/episode2/assets/<name>.glb` via Meshy image-to-3D with `--pbr`, then
  `tools/meshy/shrink_glb.py` (base colour at `--max`, normal/roughness at `--aux-max`).
- **Textures** → `src/episode2/assets/textures/tex_<name>.jpg`, MuAPI Flux, made seamless by
  `make_tileable()`; apply in Godot with `uv1_triplanar` so they tile on procedural geometry.
- **Provenance** → `src/episode2/assets/forge_manifest.json` (Meshy task id, source, sizes).
- **SFX** → add an entry to `assets/audio-manifest.json` `sfx`, then
  `python3 scripts/generate_audio.py --force <id>` → `src/assets/sounds/<id>.mp3`.

Add an asset by adding one line to `MODELS` or `TEXTURES` in the forge script. Keys are read from
the environment (see `gm-game-tool-roster`); never print or ask for them.

## Source stills — the part that goes wrong

Meshy builds **whatever is in the picture**. Learned the expensive way:
- A reference that shows Lil Blunt *holding* the revolver produced a whole cowboy Lil Blunt, not a gun.
- A crop of IMG_2492 around a boulder caught part of a cart; the rock came back with crates fused on.
- Fix: one object, isolated, on white. When the founder art has no clean still of the object, use a
  `muapi:` source (generate the still first). Crops are fine only when nothing else is in the box.

**Always look at the Meshy thumbnails before wiring a model in** (grid them — one image read).

## Checks before use

- Read the GLB's AABB (the forge's bbox dump): Meshy normalises size, and the long axis / facing
  differ per model (the cart's long axis is X; the revolver's muzzle points −X). Put those numbers in
  the code brief — never assume 1.0 or +Z.
- Pack budget: `index.pck` must stay under 190 MiB (199,229,440 B). Godot stores these textures
  lossless (correct: the preset has no mobile VRAM compression), so ~4× the JPEG size. Measure with
  `bash scripts/ep2-local-export.sh`.
- ElevenLabs sound generation rejects durations under 0.5 s.
- Any name you replace is overwritten in place; delete retired GLBs — every file under res:// ships.
