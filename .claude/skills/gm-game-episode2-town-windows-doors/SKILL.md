---
name: gm-game-episode2-town-windows-doors
description: Make the Episode 2 town's windows and doors real - openings cut as holes in the wall, framed glass, shutters, panelled/double/batwing doors, side and back windows - in tools/ep2_blender/build_town_kit.py, streamed as town_kit2.glb. The Drive prompt PROMPT_EPISODE2_TOWN_WINDOWS_DOORS_EXISTING.md names this skill. TRIGGER on "windows", "doors", "blank boards", "no windows", "buildings look empty", "openings", or editing window()/shell()/door_unit()/false_front().
---

# Town windows and doors (founder prompt `PROMPT_EPISODE2_TOWN_WINDOWS_DOORS_EXISTING.md`, 2026-10-19)

Scope lock (from the prompt): improve the EXISTING kit buildings only; no new `Bldg_*` names; the Armory stays off Main Street; quality over quantity.

## The root cause (found 2026-10-19, do not re-learn it)
`false_front()` used to build a full-height slab (ground to cornice) at z = +0.02 IN FRONT of the real wall, so every window and door of every
two-storey and false-front building was hidden behind a solid board (the Treasury, which has no false front, was the only one that showed
windows). It now starts at `y0` = the wall top. If fronts go blank again, check for any full-height slab in front of the wall first.

## How openings are built
- `wall_holes(p, mat, u0, u1, h, holes, place)` builds a wall in boxes AROUND its holes (columns split at every hole edge). A hole is
  `(centre_u, centre_v, w, h)`. Front, side and back walls all use it; a material swap or a glass quad over a solid wall is NOT an opening.
- `window()`: pale reveal frame lining the hole, recessed `GlassDay` pane, muntins, projecting sill and head, open shutters (`Shutter`),
  optional dark backing for buildings with no interior. `door_unit()`: frame, threshold, and by style `open` / `shut` (panelled leaf, knob,
  transom) / `double` (Treasury: two leaves, brass pulls, fan-light) / `batwing` (Saloon).
- Side/back windows come from `Piece.place(yaw, offset)` so the same `window()` works on any wall.
- Materials: frames use `PaintWhite` (the town skins it pale), glass `GlassDay`, shutters `Shutter`, room behind `Dark`.

## Shipping rule (pack gate!)
The rebuilt kit is ~1.96 MB; the main pack had 0.42 MB of margin, so it is written to `src/episode2/extras/town/town_kit2.glb` and STREAMED
(ADR-0005, `Ep2Extras.TOWN_KIT`); `Ep2GoldTown.build` draws it when mounted and the shipped `town_kit.glb` otherwise. Rebuild:
`blender -b --factory-startup -P tools/ep2_blender/build_town_kit.py -- --out src/episode2/extras/town/town_kit2.glb`
then import with the pinned Godot 4.3 (`.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --path . --import`, twice) and commit the
extras `.import` files in THAT format (force-add; 4.7 ones dirty CI's tree).

## Gates and proof
- `tests/ep2_town_people_test.tscn` (openings half): a ray through each window and doorway centre meets no wall triangle, glass/frames exist,
  and a control ray at a wall-only point DOES hit (the check can fail). Plus `ep2_gold_town_test`, `ep2_armory_two_story_test`.
- Captures: `tools/ep2_shots/town_fronts_shot.tscn` (Main Street rows, Saloon, Treasury, Certificates, church, Armory lane, up the street) from
  eye height through the real Compatibility renderer. Before/after in `docs/episode2-quality/town-people-windows-2026-10-19/`.
- Two-storey Armory (`tools/ep2_blender/build_armory2.py`) uses the same hole-cutting.
