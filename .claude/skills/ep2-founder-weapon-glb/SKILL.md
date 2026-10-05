---
name: ep2-founder-weapon-glb
description: Pull the founder's Winchester GLB from his Drive folder, inspect it, shrink it to the web budget and install it at src/episode2/assets/weapons/winchester_1886_founder.glb as THE rifle (the forge/Meshy rifle is retired once it loads). TRIGGER on PROMPT_EPISODE2_WINCHESTER_BLENDER, "the Drive GLB is the design", "bolt-action rifle", a Drive folder link containing a .glb, or before swapping any weapon mesh.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Founder weapon GLB: intake -> shrink -> install

## 1. Download (do NOT use the Drive MCP download)
`mcp__Google_Drive__download_file_content` returns base64 into the context; a 24 MB GLB is ~32 MB of tokens. Use the file id from `search_files` (`parentId = '<folder id>'`, `excludeContentSnippets: true`) and curl the public link:
```bash
curl -sSL -m 120 -o /tmp/w.glb "https://drive.usercontent.google.com/download?id=<FILE_ID>&export=download&confirm=t" -w "%{http_code} %{size_download}\n"
```
Check the byte count equals Drive's `fileSize` and the first 4 bytes are `glTF`. If it is a login HTML page, the folder is not link-shared: say so, do not guess.

## 2. Inspect before touching (measured 2026-10-05, `bolt-action+rifle+3d+model_Clone1_Clone1.glb`)
- 23.9 MB; ONE Tripo mesh, 31 084 verts / 50 062 tris, three **4096x4096** images (normal, rgb, metallic-roughness).
- Carries a 65-bone **Mixamo humanoid** skin and an Icosphere helper; the mesh is a rifle (not a character). Dimensions come out ~0.88 x 0.89 x 0.74 m in raw import, so the rest scale/orientation is NOT metres/muzzle +Z: measure the barrel axis from the vertex bounds, do not trust node scale.
- Headless `bpy` import works (`bpy.ops.import_scene.gltf`); the process segfaults on interpreter exit - harmless, print results first and ignore exit 139.

## 2b. What the file REALLY is (rendered 2026-10-05, see docs/episode2-quality/founder-rifle/)
- It is **not a bolt-action**: it is already a lever-action Winchester with engraved receiver, walnut stock and a lever loop - no bolt-to-lever conversion needed.
- It is a **pose/design reference**: a rifle with Lil Blunt's arms baked into the same mesh (green forearms, brown leather gloves, red-and-brass studded cuffs with a leaf badge). The right glove grips the wrist of the stock; the left glove cups the fore-end; the left forearm hangs down toward the stock.
- The 65-bone Mixamo skeleton is a ~0.2 m default auto-rig that does NOT match the mesh. Ignore it; do not animate through it.
- Used raw as the first-person viewmodel it fails: the left forearm lies in the rifle's vertical plane, so from the camera behind the stock it fills the middle of the screen and in ADS the right glove hides the sights (tried Z shifts 0.24/0.52/0.85, all bad). Do not wire it as the viewmodel. Use it as the **reference for hand placement** and take the rifle geometry from it.
- `tools/ep2_blender/shrink_founder_rifle.py` bakes it to a 567 KB skin-less GLB (10k tris, 1024/512 textures), oriented muzzle +Z / up +Y (verified by `tools/ep2_shots/glb_axes_shot.tscn`). It is NOT committed because nothing uses it yet (pack headroom ~1 MB).

## 2c. Realism upgrade (2026-10-06)
For the hero/marketing render of this rifle use skill `ep2-rifle-realism` (`tools/ep2_blender/rifle_hero.py`); render only headless (`blender-headless-render-safety`).

## 3. Budget (hard)
| Limit | Value |
|---|---|
| Game GLB | < 8 MB (founder); **real constraint: web pck is ~188.9 MB of a 190 MB gate** |
| Textures | <= 2048 (founder says 2K max, never 4K); use 1024 albedo + 512 normal/MR unless the closeup demands more |
| Tris | <= 12k for the viewmodel (decimate 50k -> ~10k, keep silhouette, stock, barrel, grip) |
Retiring the forge/Meshy rifle (`winchester_1886.glb` + its textures) and any other unreferenced file must pay for the new GLB. Measure with a real export size, not an estimate. Never delete GLB-dependency textures next to other `.glb`s.

## 4. Install
- Original (unshrunk) is NOT committed. Commit only the shrunk file at `src/episode2/assets/weapons/winchester_1886_founder.glb` (one copy, no alias). Record source id, original size, shrink settings in `docs/episode2-quality/provenance.json`.
- Re-point `RIFLE_MODEL` in `smelting_facility.gd` and `RIFLE` in `hideout_dressing.gd`; keep the forge path as a fallback only until the new GLB loads, then delete the forge rifle.
- Orientation contract the code expects: muzzle +Z, stock -Z, centred, ~1.2 m long (`ep2-handoff-props`). Normalise in Blender, not in GDScript.

## 5. Next step (not done)
Separate the rifle from the arms (delete arm/glove faces below the receiver line, keep the lever loop; check no hole in the stock wrist) for the rack/hand-over/viewmodel rifle, and rebuild gloves + cuffs to match the reference in `tools/blender/build_fp_hands.py`, posed from `ep2-blender-handling-clips`. Never swap in a different gun.

## Prove
`node scripts/glb-shot.mjs <glb> sheet.png` (look for loose parts), then the range capture rig (`ep2-blender-props`), then the three range tests.
