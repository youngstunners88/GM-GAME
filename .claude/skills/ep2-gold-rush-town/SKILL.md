---
name: ep2-gold-rush-town
description: Make the ride OUT of the woods and the GoldMine town look like the founder's town visualization - a golden-hour Wild West gold-rush town (false-front timber buildings with painted signs, Fort Knox's stone castle on the hill, dusty street, horses and wagons, desert hills and mesas) with the mine under it. Muapi reference stills -> headless Blender building kit -> Godot slices with draw distances -> graded captures. TRIGGER on "the style of the environment", "town", "Gold Mine town", "Wild West", "gold rush", "riding out of the woods", "desert", "mesa", building signs (CERTIFICATES, RESERVE, AUCTIONS, STOCKPILE, TREASURY, STATS, FORT KNOX).
---

# Target

`artifacts/episode2-gold-mine/references/founder_2026-10-13_town/goldmine_town_target.jpg` (the GoldMine site's hero art). Read it as:
- **Light**: low golden-hour sun, warm amber sky with soft cloud, long shadows, dusty haze; deep warm browns in shade (not grey).
- **Land**: dry tan dirt, scrub, low rocky hills and mesas to the horizon; a few dark pines only near the woods edge.
- **Buildings**: weathered timber, false fronts, porches with posts, shingle / tin roofs, big painted sign boards in cream-on-brown or gold
  lettering; a white clapboard church; Fort Knox = a stone castle-fort with flags on the rise behind the town; the STOCKPILE = an open
  timber shed over a heap of glowing gold; the TREASURY = a sandstone bank front.
- **Life**: people in period dress, horses at rails, wagons, crates and barrels.
- **Below**: the mine (timbered adits, lamps, carts) - our existing mine art.

# The ride out of the woods (spec beat 1b)

One continuous road (the existing quad path keeps going): the old growth thins over ~150 m (fewer giants, lower density, more light),
then open gold-rush country - scrub, boulders, dry grass cards, mesa silhouettes, the town and Fort Knox on the horizon getting closer.
Change the WorldEnvironment gradually along the road (sky warmer, fog thinner and warmer) - interpolate by road distance, never a cut.
Keep the forest-slice system (`woods_quad.gd` `_build_forest_chunk`, draw distances) and add desert slices the same way.

# Pipeline (reuse, do not reinvent)

1. **References** - `ep2-hyperreal-scene-pipeline`: add briefs to `tools/ep2_forge/fort_knox_refs.json` (a "gold_rush_town" set: street
   view from the town edge, certificate office front + interior, saloon front + interior, desert road out of the pines, mesa skyline,
   sign boards) and generate with `tools/ep2_forge/muapi_ref.py` (MUAPI key from env, never printed).
2. **Kit** - headless Blender (`blender-headless-render-safety`; bpy runs as `python3`): a false-front building generator (width, storeys,
   porch, sign board, roof type) + props (hitching rail, barrel, crate, wagon wheel, water trough, lamp post); one GLB with named pieces,
   triplanar wood / tin / sandstone materials; sign text as small textures (not 3D text). Hero pieces (Fort Knox, stockpile, saloon
   interior) may be Tripo/Meshy via `tools/ep2_forge/muapi_3d.py` -> `ep2-tripo-mesh-surgery`.
3. **Godot** - MultiMesh per piece per slice with `visibility_range_end`; the street is a corridor you walk, not a skybox; buildings you
   enter are their own chambers (built behind, `ep2-no-blackouts`).
4. **Prove** - first-person captures on one board with the target (`ep2-reference-match-loop`), `tools/ep2_forge/ref_metrics.py` numbers,
   Jev/Microsoft decisions on the numbers (text-only), an Astra review only for the final art pass.

# Traps

- The low warm sun lights the held rifle by direction: keep `Ep2Viewmodel.set_own_light` on in every outdoor room
  (`ep2-rifle-always-visible`).
- No DIAMONDS sign / mine in Episode 2 (`ep2-fort-knox-arc` rule 4) until the founder opens it.
- Pack budget (index.pck < 190 MiB, 2026-10-13 ~188.6 MiB): new textures 1K jpg, reuse materials, measure before committing.
