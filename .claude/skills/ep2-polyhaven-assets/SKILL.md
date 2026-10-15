---
name: ep2-polyhaven-assets
description: Use Poly Haven's free CC0 library (api.polyhaven.com, NO API key, commercial use OK; 2,387 assets = 997 HDRIs, 869 PBR textures, 521 models) for Episode 2 neutral studio lighting, hero/review renders, set-dressing materials and props. Search/download tool, headless Blender studio render, provenance log, and the pack-budget rules. TRIGGER on "studio lighting", "softbox", "HDRI", "neutral light", "Poly Haven", "free model/material/texture", "is it the texture or the lighting", or a review render that needs a fair light.
---

# Poly Haven (CC0) - lighting, materials, props

API facts (verified 2026-10-15, no key): `GET api.polyhaven.com/assets?t=hdris|textures|models&c=<category>`, `/info/<id>`,
`/files/<id>` (tree: format -> resolution -> {url,size,md5}), `/categories/<type>`, `/types`. Send an identifying User-Agent.
All assets are **CC0**: commercial use OK, attribution not required. Still record the source id (provenance log).

## Tool: `tools/polyhaven/ph.py` (plain Python, no dependencies)
```bash
python3 tools/polyhaven/ph.py search --type hdris --cat studio --tag softbox     # 29 matches; studio_small_08 = low-contrast softbox
python3 tools/polyhaven/ph.py info studio_small_08
python3 tools/polyhaven/ph.py get studio_small_08 --res 1k --fmt hdr              # -> ~/.cache/gm-game/polyhaven/<id>/ (NOT the repo)
python3 tools/polyhaven/ph.py sources                                             # provenance log (id, date, CC0, files)
```
Textures/models: `get <id> --type-hint textures|models --res 1k --fmt jpg|gltf` (models bring several files; check the tree first).

## Render a GLB under neutral studio light (headless Blender; never the GUI MCP on this laptop)
```bash
blender -b --python tools/ep2_blender/studio_turntable.py -- model.glb ~/.cache/gm-game/polyhaven/studio_small_08/studio_small_08_1k.hdr out/prefix --views front,34,back
```
Standard view transform, EEVEE, 900x1100. Why it matters: removing the engine's forge lighting separates "dark texture" from
"dark light". Always render OLD and NEW with the same HDRI.

## What it taught us on the Bull (2026-10-15)
Studio renders `docs/episode2-quality/bull-hunyuan-2026-10-15/studio_{old,new}_front.png`: the new Bull's aviators/cigar/bandana read
under softbox, but the fur and face albedo are near-black. In-engine, a fill light, albedo gain 1.7x and emission all failed to
open the face; an UNSHADED render still shows it dark. Conclusion: repaint the face UV islands (or lift them in the albedo),
do not chase lighting.

## Rules
- HDRIs 1k are 1-2 MB: fine for renders. Do not put HDRIs/textures/models in `src/` unless a pack budget check passes (190 MiB,
  currently 189.2) and the asset is listed in the provenance log and `STATUS.md`.
- Blender MCP has `search_assets` / `import_asset` (Poly Haven, Sketchfab) for the GUI session; on this 8 GB machine drive
  Blender headless (`blender-headless-render-safety`) and use this tool instead.
- For scene look-dev, pair with `ep2-hyperreal-scene-pipeline` (Muapi reference stills -> Blender -> engine capture graded with numbers).
