# GoldMine Train — Level 3 asset drop

Source refs (founder Drive): photoreal black+brass 4-4-0 steamer, GM medallion cab, GOLD MINE tender.
Kept as `train_reference.png` for fidelity checks.

## Game sprites (use these in scenes)
- `src/assets/sprites/sprite_prop_train-goldmine.png` — 1024px trimmed transparent, main prop
- `src/assets/sprites/sprite_prop_train-goldmine_512.png` — mid LOD
- `src/assets/sprites/sprite_prop_train-goldmine_256.png` — small / UI LOD
- `src/assets/sprites/sprite_train_goldmine_blender-render.png` — stylized Blender side render (alt / placeholder for animation tests)

Suggested wiring (Level 3 Gold Rush): StaticBody2D prop or ParallaxBackground layer,
TextureFilter NEAREST to match pixel-art, or keep LINEAR for the photoreal 1024 sprite.

## Blender source
- `src/assets/models/goldmine_train/goldmine_train.blend` — low-poly procedural 4-4-0 (boiler, cab, tender, drivers, track), Cycles-ready
- `src/assets/models/goldmine_train/goldmine_train.glb` — GLB export for Godot 4.3 import / future 3D
- Re-render: `blender --background goldmine_train.blend --python load_polyhaven_hdri.py`
  (script at /tmp/train_work/load_polyhaven_hdri.py — move into scripts/ if this becomes a pipeline)

## Poly Haven lighting (CC0, commercial OK, no key)
- HDRI: `studio_small_09_2k.hdr` — "Studio Small 09", large octabox softbox setup, category Studio/Photo Studios/Softbox & Lamp Setups
- API used: `GET https://api.polyhaven.com/assets?t=hdris` → pick slug → `GET https://api.polyhaven.com/files/{slug}` → `hdri.{res}.hdr.url`
- This drop used 2K HDR (6 MB). For final renders swap to 4K (`studio_small_09_4k.hdr`, ~25 MB).
- Reusable pattern for any asset: same `/assets` + `/files` calls work for `textures`, `models`, `all`. Docs: https://api.polyhaven.com
- Attribution not required (CC0) but keeping the slug + author (Sergej Majboroda) recorded here for provenance.
