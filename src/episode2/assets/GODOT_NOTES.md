# Episode 2 Scene Kit — Godot import notes & per-asset generator provenance

Created 2026-09-22 to satisfy the founder's asset-generator lock
(`artifacts/PROMPT_EPISODE2_3D_AI_ROUNDUP_TAKEAWAYS.md` §3.3: *"When generating
or commissioning a mesh, write the tool choice into the scene kit"*).

**Rule: no Episode 2 mesh is done until it has a row in the table below.**
Generator choice is not free — it is locked per asset class in
`artifacts/episode2-gold-mine/spec/ASSET_PIPELINE.md` §LOCK (2026-09-22).

---

## Generator selection (the short version)

| If the asset is… | Use | Never use |
|---|---|---|
| Parametric hard-surface (rails, beams, crates, nuggets) | **Path E — headless `bpy`** via `tools/blender/build_asset.py` | — |
| Organic / sculpted / detail-dense prop | **Tripo P2 + Smart UV** → GLB | Hunyuan Studio UV as primary (slow, unstable) |
| Hero sculpt (Inferno Bull, Fort Knox plates) | **Meshy 7.1 Ultra 4K** → decimate → GLB | Raw Ultra 4K dropped into the runner |
| Animation on an existing GLB | **Astra**, after the GLB exists | Astra as a mesh generator |
| Rigged hero character | Human Blender pass | Image-to-3D alone (drifts off-model) |

---

## Shipping assets

| Asset | File | Generator | Parts | Gate status |
|---|---|---|---|---|
| Mine cart | `minecart.glb` (23,708 B) | **Path E — `bpy`** (`tools/blender/build_asset.py`) | **7 meshes** (hull / rim / wheels / emblem) | ✅ `tests/ep2_glb_pipeline_test.gd` — imports, and asserts ≥5 parts |
| Rail segment | `rail_segment.glb` (13,828 B) | **Path E — `bpy`** | 9 meshes | ✅ same gate |
| Gold nugget | `gold_nugget.glb` (3,448 B) | **Path E — `bpy`** | 1 mesh — correct, no moving parts | ✅ same gate |
| **Lil Blunt** (runner hero) | `lil_blunt.glb` (748,224 B) | **Meshy image-to-3D** (`latest`), task `01a0cc5b-1022-7174-a519-ba45dd82999b`, from a crop of IMG_2492. 8,349 tris. Texture 2048→1024 JPEG via `tools/meshy/shrink_glb.py` | 1 mesh, static pose (not rigged) | ✅ imports; seen in a real browser build 2026-09-23 |
| **Bear archer** (runner enemy) | `bear_archer.glb` (589,648 B) | **Meshy image-to-3D** (`latest`), task `01a0cc5b-1023-7620-b102-833aeb6d6144`, from REF_balaclava-bear-archer_turnaround.jpg. 8,231 tris. Texture 2048→512 | 1 mesh, static draw pose | ✅ same |

**Why Meshy for these two, not Tripo:** both are organic characters (the asset lock
routes organic/hero work to Meshy, props to Tripo), and `MESHY_API_KEY` is the key
the founder provided — no Tripo key exists in this environment. Regenerate with
`tools/meshy/meshy_gen.py <image> <raw.glb>` then `tools/meshy/shrink_glb.py`.

**Runner carts are procedural, not `minecart.glb`.** The bpy cart is a closed box, and
in a browser build Lil Blunt read as poking out of a crate. `runner_view.gd` builds an
open ore cart from parts (floor, four walls, iron bands, four spinning wheels) — same
"parametric hard-surface is free and scripted" rule. `minecart.glb` stays as the GLB
pipeline gate's fixture.

**How the textures ship:** `*.import` is gitignored, so CI imports with defaults. Godot
extracts each embedded texture (`*_Image_0.jpg`, also gitignored — derived) and, stable
across two import passes, stores it **lossless, not VRAM-compressed**. That is the right
outcome here: the export preset has `vram_texture_compression/for_mobile=false`, so a
VRAM texture would not render on phones; lossless works on every GPU.

All three are **script-reproducible**: re-run `tools/blender/build_asset.py`
under the `bpy` PyPI wheel (5.0.1, Python 3.11) to regenerate byte-for-byte.
That reproducibility is why `bpy` stays the default for parametric props rather
than routing them through a paid external generator.

---

## Pending assets — generator pre-committed, parts required

| Asset | Assigned generator | Part requirement | Why parts matter |
|---|---|---|---|
| **Inferno Bull** (hero) | **Meshy 7.1 Ultra 4K** → decimate → Smart UV → GLB. Rig needs a human pass | Separable head / limbs / cigar / Winchester hand | Astra animation targets (idle, cigar, Winchester hand-off) need independent limbs |
| **Winchester 1886** | **Tripo P2 + Smart UV** | **Lever separate from receiver** — mandatory | The lever must animate independently for the First Chamber hand-off beat (V3 story). A welded blob cannot cycle |
| **Smelting furnace** | **Tripo P2 + Smart UV** (ornamental plates → Meshy) | **Doors separate from body** — mandatory | Doors open/close as a hazard and set-piece beat |
| Lanterns, pickaxe, crates | Tripo P2 + Smart UV, or `bpy` if genuinely parametric | Per-asset | — |

**When any pending asset lands, it must:**
1. Add its row to "Shipping assets" above with its real part count.
2. Get a part-count assertion in `tests/ep2_glb_pipeline_test.gd`, matching the
   `>= 5` pattern already guarding the minecart. A part requirement that isn't
   gated will silently regress the first time the mesh is re-exported.
3. Keep the web-export pack budget in view — and it is tighter than it sounds.
   **Re-measured 2026-09-23 after the runner build (real local export, same preset as
   CI): `index.pck` = 195,166,512 B against the 199,229,440 B gate — ~3.9 MiB left.**
   The two Meshy characters cost ~3.1 MiB (lossless textures ~2.5 MiB + scenes ~0.65).
   Earlier note, for the record:
   **Measured 2026-09-22 (CI run 323): `index.pck` = 191,899,440 B = 183 MiB
   against a 190 MiB CI gate — roughly 7 MiB of headroom**, before a single 3D
   chamber asset lands. The gate exists because itch.io rejects the whole HTML
   embed if any zipped file exceeds 200 MB, so this is a hard ship blocker, not
   a warning. **Budget every incoming GLB against that 7 MiB**, and expect to
   re-encode existing media (`tools/reencode_media.sh`) before the Bull, the
   Winchester and the furnace can all ship. This is the outstanding risk
   ADR-0001 flagged under "Negative / accepted trade-offs".

---

## Standing import rules

- **Parts, not welded blobs.** Anything with a moving or separately-animated
  component imports as distinct `MeshInstance3D` nodes. Gate it.
- **Decimate before Godot.** Hero-tier 4K geometry is a sculpt/displacement
  source, never runtime geometry in the runner.
- **Smart UV unless a human unwrap is justified.**
- **Kai Ninja / Snap3D part-splitting is not adopted** — model not fully
  public, license unclear. Author parts separately in Tripo or `bpy`; do not
  wait on public weights.
- **Runtime is Godot 4.3.** GLB is the only handoff format. PlayCanvas /
  Three.js / Pascal are authoring- or preview-side only (ADR-0001 §3).
