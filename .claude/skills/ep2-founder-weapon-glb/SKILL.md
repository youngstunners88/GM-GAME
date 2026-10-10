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


## 6. SHIPPED PATH (2026-10-05): the Cowork rifle, rebuilt headless and wired as the first-person viewmodel
The Cowork (desktop Blender) session cannot commit, and a GLB cannot carry its shader graph. The repo's scripts reproduce the same
rifle headless (bpy 4.2, CPU only, ~1 min): surgery (second hand, broken barrel replaced, GM logo decal) from `rifle_surgery.py`, graded
materials from `rifle_hero.py`, then `rifle_export_game.py` bakes colour / roughness / metallic with Cycles CPU, packs glTF metal-rough
(256 px), re-creates the logo alpha+emission with PIL, decimates to 12k tris, centres the lateral axis on the BARREL (not the bounding box:
the gloved forearm drags it off-axis), turns it to muzzle +Z / up +Y and exports `winchester_1886_founder.glb` (~0.9 MB).
```bash
python3 - <<'PY'
import sys,runpy
sys.argv=["x","--","--glb","/tmp/w.glb","--align","--flipx","--pre","tools/ep2_blender/rifle_surgery.py","--logo",
 "artifacts/episode2-gold-mine/references/founder_2026-10-06/GOLD_LOGO.png","--tex","1024",
 "--post","tools/ep2_blender/rifle_export_game.py","--game-out","src/episode2/assets/weapons/winchester_1886_founder.glb"]
runpy.run_path("tools/ep2_blender/rifle_hero.py",run_name="__main__")
PY
```
Then delete `src/episode2/assets/weapons/textures_tmp/` (embedded in the GLB). Wiring: `Ep2ViewHands.attach` prefers this GLB (hides the forge rifle meshes in the viewmodel, matches the sight top,
`FOUNDER_Z_SHIFT 0.34`, `FOUNDER_DROP 0.045`); the rack, Bull and hand-over still use the forge rifle. Pack budget: CI pck was 188 MiB of 190 -
the normal map (1 MB) is OFF (`--normal` to enable); the superseded Blender hands GLB was deleted to pay for this one.
Open: a right hand is not in the model (only the left glove + forearm), no lever animation, receiver not brass.

## 7. SHIPPED (2026-10-10): the founder's "rifle 3d.glb" IS Lil Blunt's rifle
Drive 1X09DLG2prOs_B-AuNc15AohVZ8lyfAzS (Tripo, 61.6k verts, 4K albedo, Mixamo default rig - ignore it). Logo fixed with
`ep2-winchester-logo` (third pass), then `tools/ep2_blender/lil_blunt_rifle_to_game.py`: the gun axis is measured by PCA of the
verts above the hanging arm (the model is turned ~22 deg in plan - a flat 90 deg turn put the logo 0.39 m off the barrel), the thin
end is the muzzle, scaled to 1.2 m, barrel on x = 0, logo on +X at z -0.246, decimated to 22k tris, albedo 2048 / MR + normal 1024 /
emission 512. Viewmodel: `Ep2ViewHands.founder_z_shift = 0.05` (forward until the GM logo reads in the hip view; 0.15 hid the arm).
The previous build is in `.farm/retired/winchester_1886_founder_prev.glb`. Pack +~1.3 MB.
