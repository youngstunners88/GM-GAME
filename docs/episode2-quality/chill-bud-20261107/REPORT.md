# Dude's purple-haze plants and actual healing bud — 2026-11-07

## Result

Replace the fragment-like bed foliage with a textured, rooted three-plant grove from the founder's original purple-haze reference. The same accepted generation supplies the shop's smaller Frost showcase and taller growth behind the bed. One grove is placed in the bed: the source already contains three plants. The tree variants stand farther back to keep their larger roots out of the bed. A low, irregular textured earth mound replaces the box; short boundary stakes replace the crown-height rails.

Foliage uses instance-local materials, non-metallic rough surfaces, supplied normals and albedo-multiplied emission. The old additive white emission washed out the texture. The soil, stems, green leaf fans and purple flowers remain textured. This is a stylized game model, not a claim of photographic reference fidelity.

Tabs uses an actual transparent render of the supplied `Dude Buds.glb`, rather than its generic leaf symbol, with a larger view when selected. The preview is opposite the close button and does not replace weapon controls. The image streams with `Ep2Extras`; the existing icon holds its place only until that pack mounts. All original inventory, payment, full-three-heart healing, pause, save, keyboard and touch transactions are unchanged.

## Provenance and spend

- Brief: https://drive.google.com/file/d/14UKze9iUyTJahWJp1vVIil6oh31xcHQ6/view
- Source folder: https://drive.google.com/drive/folders/1a0rtGR_dFvtDRQ3XJqEpPCS0vukqbkBe
- Plant reference: `Purple_haze_weed_on_stalk_cee4cf27_2K.jpg`, Drive `1mNQOYJcOCL2TYfsKn2qeXph6oFg-SIde`.
- Actual harvested bud: `Dude Buds.glb`, Drive `1fLs_htE5ds86DYrzXQUB-lnpaIUpT3t9`. Original is 342,726,024 bytes / 7,373,606 triangles, kept outside game resources; the icon is rendered directly from that original, not the unsuccessful simplification experiment.
- One Tripo image-to-model call, CLI alias `tripo-v3.1`, API value `v3.1-20260211`, face limit 15,000, textured PBR. Task `5fe79f47-5c7b-4753-8976-c390edbef6b8`: **30 credits billed**. Total **30**, remaining **5**, frozen **0**. No paid conversion, UV step, rigging or reroll. `generation.json` contains the sanitized receipt.
- The CLI submitted successfully before its default history directory failed to write. The task was recovered through `tripo usage` and resumed with `task watch`; it was never resubmitted. Subsequent CLI state is workspace-local.
- Preparation: `tools/ep2_blender/prepare_purple_haze.py`; standard GLB, retained UVs, 1024px albedo, 512px normal, 256px ORM. Nineteen tiny overlapping/coplanar faces removed. Grove and tall variants: **13,489 triangles** each; the Frost showcase is **11,870**, under its existing 12,500-triangle gate. Each has one material. Visible patch geometry changes from 82,867 to **40,467 triangles**.
- QA: pass, no same-facing coplanar overlap, floating parts, degenerate faces, inconsistent normals or non-manifold edges. One opposing-face contact in the taller variant is accepted on its folded, double-sided foliage; it is not same-facing flicker. Duplicate-position vertices remain deliberately at source UV/normal seams; the open leaf surfaces are intentional, double-sided foliage. Old extracted textures were removed only after finding no runtime references; Git retains the old source.
- Reproduce icon: `tools/ep2_blender/render_chill_bud_icon.py ORIGINAL.glb src/episode2/extras/patch/chill_bud.png` through Blender `-b -P ... --`.

## Verification

Local release validation and public deployment proof are recorded below as they complete. Do not read a local render or source commit as a public release.

- Existing healing transaction test: 14 checks / 0 failures before the final streaming-path change; final recheck pending.
- Actual woods-host screenshot transaction: 1 heart → 3 hearts, exactly one bud consumed, panel remains paused.
- Founder front-page lock: 5 files unchanged. Green-VFX check: pass. Security sentinel: no high-severity blockers; final staged rerun pending.
- Full native suite, fresh non-threaded export, pack/texture presence and public build verification: pending.
- Not tested on a physical phone; not founder-verified.
