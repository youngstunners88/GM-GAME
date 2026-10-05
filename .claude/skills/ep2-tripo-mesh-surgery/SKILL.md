---
name: ep2-tripo-mesh-surgery
description: Fix GEOMETRY defects in a Tripo/Meshy GLB (duplicate hands baked in, a broken/hollow barrel, truncated parts, floating fragments) by aligning the mesh, colour-coding its connected islands, deleting/shifting/stretching islands and building procedural replacement parts - all headless in Blender. TRIGGER when the founder circles part of a render and says "wrong hand", "the gun is supposed to be a long gun", "it is cut off / broken / too short", "remove the second hand", or any Tripo mesh defect that materials cannot fix. Proven on the founder's Winchester 1886 (2026-10-06).
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

# Tripo mesh surgery (measure -> cut -> rebuild -> look)

Tools (all in `tools/ep2_blender/`): `rifle_hero.py` (driver), `rifle_surgery.py` (the edits), `rifle_post_islandviz.py`, `rifle_pre_slice.py`, `rifle_pre_platemap.py`, `run_rifle.sh`.
Read `blender-headless-render-safety` first (never in the GUI), then `ep2-rifle-realism` for materials.

## Why it works
A Tripo export is **hundreds of disconnected islands** (the rifle GLB: 511). Hands, fingers, cuffs, rings and sights are separate bodies that merely overlap the gun.
So a duplicate hand can be removed by deleting islands - no hole appears in the rifle, because the rifle never shared vertices with it.
(Check first: island count + bboxes from `rifle_pre_inspect.py`. If the part you want gone is merged into the main island, this method does not apply.)

## The loop (each step ~25 s at 960x540)
1. **Align**: `--align --flipx`. PCA puts the barrel on X; `--flipx` was right for this GLB (muzzle +X, upright). Judge the sign by looking at an ortho render (`--view oside`), not by logic: flips interact (flipx alone = 180 deg about Y; adding flipz turned the gun upside down again).
2. **Roll-check with a depth map** (`rifle_pre_platemap.py`): ray-cast from -Y over the receiver and print first-hit y. A flat side plate must give a **constant y**. Here y rose ~1.05 per unit z => the PCA frame was rolled **46.4 deg** (the diagonal forearm skews PCA's cross-section axes). `--roll 46.4` (default) fixes it. If you add or remove big parts, re-run the map.
3. **See the islands**: `--post rifle_post_islandviz.py --neutral --view oside` colours the 14 largest islands and prints `colour -> idx -> bbox`. Match colours to parts. Island ids are stable for the same GLB.
4. **Slice report** (`rifle_pre_slice.py`) lists per-island bbox inside an X slice (barrel/fore-end cross-section) and small "floaters".
5. **Edit** in `rifle_surgery.py` (runs on the aligned mesh via `--pre`): delete islands (`bmesh.ops.delete(context='FACES')`, then orphan verts), stretch/shift islands (move all verts of an island; islands share none), add primitives (`create_cone`, `create_cube`) with `material_index=1`.
6. **Look at it** (`--view oside` neutral, then `--view fps`). Never trust the numbers alone.

## What was done to the Winchester (indices for `bolt-action+rifle+3d+model_Clone1_Clone1.glb`)
| Defect the founder circled | Cause | Fix |
|---|---|---|
| Second (left) hand gripping trigger guard / stock | islands 201, 291 (glove paddle), 199, 200, 204 (knuckles) | deleted; lever loop and wrist wood are intact underneath |
| Floating strap ribbon behind the butt | islands 303, 304, 469, 470 | deleted |
| Muzzle was a flat hollow slab, gun read as a stubby carbine | islands 137, 152, 161-166 (stub + sight) | deleted; octagonal barrel (R 0.031), magazine tube, tube cap, barrel band, dovetail + blade front sight built procedurally to x = 1.035 |
| Fore-end too short | wood islands 100, 435 | stretched x>0.50 by 2.31 (cap 0.63 -> 0.80); cap pieces 138-142, 147, 153, 434 shifted +0.17 |

New parts live in material slot 1 `Barrel_Steel` (procedural, no UVs needed). The driver only smooths slot 0 so the octagon flats stay hard.

## Traps
- **Frame first, constants second.** Barrel axis (y 0.323, z 0.278) was measured in the PCA frame; after the roll it becomes (0.021, 0.426). The hook derives it from `ROLL`; any hard-coded y/z must be rotated the same way or the tube hangs diagonally.
- **`bmesh.ops.create_cone` is built along Z**: rotate 90 deg about Y to lay it along X; add 22.5 deg about its axis for flats-up octagons.
- **Long heredocs in the Bash tool can die with "unexpected EOF"**. Write Python with the Write tool and keep the shell lines short.
- Do not stretch islands that hands overlap: the front glove ends at x 0.48, so stretching from x>0.50 never moves it.
- A stretched wood island stretches its grain texture 2.3x along the barrel. Acceptable for walnut; do not do it to engraved metal.

## Still open on this rifle (do not claim parity)
- The stock is the original faceted wedge butt with no crescent buttplate; it needs a real stock/buttplate (new geometry or a re-sculpt).
- Receiver is not brass; forearm is cartoon green; wood has no figure (see `ep2-rifle-realism`).
- New parts have no UVs, so they cannot be exported to a game GLB with the same material until a texture bake or UV pass is done (`ep2-founder-weapon-glb` budget: < 8 MB, <= 2048 px).
