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
3. Keep the web-export pack budget in view — the `index.pck` size gate
   (190 MB) tightens as 3D assets land, per ADR-0001.

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
