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

## Fidelity pass candidate (2026-10-15)

The editable source is Blender **5.2** format. Use Blender 5.2+; Blender 4.3
cannot read its header. Reproduce with:

```sh
blender -b src/assets/models/goldmine_train/goldmine_train.blend --python tools/ep2_blender/train_fidelity_pass.py
```

The pass adds open framed cab windows, a flared funnel/mouth, thirteen separate
pilot slats, spoked drivers and pilot/tender wheels, both coupling rods with
offset crank pins, tender coal and lettering. GLB: 15,300 triangles, 287 mesh
objects. The supplied 2K HDRI is loaded and packed into the source. The Blender
sprite is still an alternate/base; all three photoreal sprites, distant train
rig, riders, 3200 span and 0.18 parallax remain unchanged. This is a static model;
no articulated wheel/rod animation is claimed.

The previous `/tmp/train_work/load_polyhaven_hdri.py` command is historical;
the checked-in script above now owns reproduction. Engine import and release
verification are pending; see `design/train-revolver-pass/REPORT.md`.
