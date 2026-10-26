---
name: ep2-town-cad-furniture
description: The town's CAD interior furniture (saloon bar/back bar/bentwood chairs/piano/chandelier, the certificate office's counter/pigeonholes/desk/stove/safe, the jail's small things). Use when furnishing or changing a town room, adding a CAD prop to the town, or when the founder says the interiors look cheap, empty or like boxes.
---

# The town's CAD furniture (founder 2026-10-25, P1 "Town interiors - more furnished furniture and subtle details")

## Pipeline
1. `TOWN_CAD_OUT=<dir> [TOWN_CAD_ONLY=chair,table] [TOWN_CAD_DEBUG=1] freecadcmd tools/ep2_cad/town_interior_cad.py` - real solids at real size,
   one OBJ per (piece, material). `TOWN_CAD_DEBUG=1` prints every shape's triangle count (find what to coarsen).
2. `blender -b --factory-startup -P tools/ep2_blender/build_town_interior_kit.py -- --cad <dir> [--out src/episode2/extras/town/town_furniture.glb] [--shots <dir>]`
   - one `Twn_<Piece>` root per piece at the origin; materials named as the town kit names them, at the town kit's values.
3. `tools/ep2_blender/review_kit.py -- --glb <glb> --out <dir> Twn_Chair:34 ...` for isolated ortho reviews.
4. Engine: `Ep2Extras.TOWN_FURNITURE`; `Ep2KitProps` serves it (`Twn_*` = this kit, dressed AS SHOWN; `Kit_*` = the smelter kit,
   intended tone). `Ep2GoldTown._furnish`: `CAD_FURNITURE` (kit piece -> Twn piece, same transform, old piece stands in via `_cad_piece`),
   `ROOM_DETAIL` (new pieces: building, prop, local pos, yaw, floor footprint, lean), `HANGING` (chandelier on a chain, harp lamps on a rod,
   flames at the existing lights), `Ep2Pendulum` swings the clocks. `Ep2Interlude.step` polls `Ep2KitProps.upgrade_pending()`.
5. Proof: `tools/ep2_shots/interiors_shot.tscn -- out=<dir>` (opengl3, 1600x900 SubViewport). For "before", copy the script into a master
   worktree for the run only and delete it after. Gate: `tests/ep2_town_furniture_test` (CI).

## The street's trim (part 4)
- `build_town_kit.py --cad-trim` writes `town_kit2` with PostAnchor / CorbelAnchor / HoodAnchor / BalusterAnchor empties instead of the
  box posts, cornice brackets, 0.95 m window heads and balcony balusters (`Piece.trim_anchor` applies the current placement and yaw). The
  default build (the shipped `town_kit.glb`) must stay byte-identical - rebuild into the scratchpad and `cmp` before trusting any change.
- `Ep2GoldTown._collect_trim` / `_build_trim`: one MultiMesh per piece for the whole street, mesh from `Ep2KitProps.raw_mesh` (the geo
  node's own transform baked in), surfaces swapped to the kit's Trim / PaintWhite (`_tex_mat`, world triplanar). Box stand-ins if the
  CAD pack cannot be loaded.
- Headless (dummy renderer) does NOT keep MultiMesh instance transforms - tests read `Ep2GoldTown.trim_placed`.
- Instanced by the dozen: keep each trim piece small (no chamfers on prisms; turned parts lod 2). Street total ~48k triangles.

## Rules
- Replacements keep the old piece's origin, footprint and heights (bar top 1.20, counter top 1.125, table top 0.785, chair seat 0.48):
  seats (`saloon_seats`), drink poses (`Ep2DrinkPose`), counter walls and story marks depend on them.
- Keep the room's tone. Measure before/after on the real renderer (ImageMagick crop mean) - office counter front was 56/20/2, saloon bar
  82/34/8, saloon frame mean 111/69/35. The walnut (GunWood) is toned by `TOWN_TONE`; DarkWood is untoned.
- New floor detail goes ON the boards: the kit rooms' floors are 0.06 above the street, the jail's 0.05 (`ROOM_FLOOR` / `KIT_FLOOR`).
  The old furniture stands at 0 (feet in the boards, as approved) - do not move it.
- Nothing new on a story mark, the Minister's panic run ((3.2,-5.4) -> (3.2,-3.4) -> (0.6,-2.0) in the office), a drinker's place or
  route, a jail stand point, or (Armory) any line between two of Rich's / Utah's ground-floor waypoints - the test checks every one.
  Floor pieces get walk footprints (`props`). The Armory floor is 0.05 (`ROOM_FLOOR`).
- Two-storey rooms are 7.2 m tall inside (ceiling 7.16): anything hung needs a chain or rod to the ceiling.

## Traps (cost real time)
- OCC's mesher cuts curves about 2x finer than `AngularDeflection` (0.5 rad gave 25 segments; a small torus was 1.4k triangles). Use
  1.0 rad (~12 segments) for furniture, 1.5 for small things, 0.5 only for big turned bodies. First pass was 192k triangles; now 92.7k.
- `Ep2Pbr.dress(kit)` in `build()` sets surface OVERRIDES on the whole town kit, so `_texture_dark_wood` (which sets the mesh's surface
  material) has NOT shown on the saloon or the walk-in shops since 2026-10-25 part 1. Their furniture shows Ep2Pbr dark wood. (The jail
  is not dressed, so its timber grain does show.)
- A tone that darkens a large flat dark surface picks up the sky's specular sheen (table tops went slate-blue) - match by measurement.
- `blender ... obj_import` puts the axis conversion on the object, not the mesh: a contact-sheet layout must read world bounds after
  `view_layer.update()`.
- Root names come from the piece name (`back_bar` -> `Twn_BackBar`); re-making a material K already made gives `Leather.001` - remove the
  old one first.
