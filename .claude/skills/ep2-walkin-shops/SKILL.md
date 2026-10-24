---
name: ep2-walkin-shops
description: Open and furnish the GoldMine town's shops so they can be walked into (founder 2026-10-24 "the interiors of the buildings in the town ... aren't detailed enough ... differences in the buildings and interiors thereof are particular") - the general store, hotel and assay office kit pieces, door gaps, lamps, porch heights, the fallback-kit rule. TRIGGER on shop/store/hotel/assay interiors, "make the buildings different inside", opening another building, or adding interior props to the town kit.
---

# Walk-in shops

- Kit: `tools/ep2_blender/build_town_kit.py` - `building(..., door_open=True, interior=True)` for Bldg_A (GENERAL), Bldg_B (HOTEL), Bldg_C (ASSAY); pieces `Gen_Counter/Gen_Shelves/Gen_FloorGoods`, `Hotel_Desk/Hotel_Stairs/Hotel_Lounge`, `Assay_Counter/Assay_Furnace/Assay_Shelves` (front along +z; `CustomerSpot`/`KeeperSpot` anchors). Note `Piece.cyl` ignores `place()` offsets.
- Build ONLY the streamed kit: `blender -b --factory-startup -P tools/ep2_blender/build_town_kit.py -- --out src/episode2/extras/town/town_kit2.glb` (main pack has ~1 MB margin; never rebuild town_kit.glb for this).
- Game: `Ep2GoldTown.WALKIN_SHOPS` (piece -> trade, counter offset), `FOOTPRINT` door 0.75 - but `_walls_of` keeps the door SHUT when `kit_v2` is false (the fallback kit has shut doors). `_furnish` rooms + one lamp per shop (kit_v2 only). `shop_spots(piece)` (out/porch/door/counter/face) and `shop_floor_y(piece, p)` (porch 0.44, steps, shop floor 0.06).
- Each shop must read its trade from the doorway: colour (tins, sacks, brass, brick) and silhouette (shelves, grille, stair, furnace), not text.
- Open: shopkeepers (needs new character models - Meshy/Tripo), saloon stairs/balcony access.
