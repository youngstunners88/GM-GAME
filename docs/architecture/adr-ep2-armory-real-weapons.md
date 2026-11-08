# ADR: The Armory's stock is the founder's own weapon GLBs

Date: 2026-11-08. Status: accepted (founder brief `PROMPT_EPISODE2_ARMORY_REAL_WEAPONS_DISPLAY_2026-11-08.md`). Not founder-verified.

## Context
Every gun in Rich & Utah's two-storey Armory was a box-primitive "stick" baked into `Arm2_Fit` by `tools/ep2_blender/build_armory2.py`
(`rifle()` / `revolver()`, ~130 pieces), and so was the Gatling at the gallery rail. The founder supplied real weapon GLBs (showcase,
held and asset copies) and wants both floors stocked with them. The founder GLBs run 6k-24k triangles each, and the web build's
Compatibility renderer in Godot 4.3 ignores imported mesh LODs (measured: a 24k-triangle gun draws 24k at 0.8 m and at 16 m). 130 guns at
full detail would add over 1.5 M triangles to the frame.

## Decision
- `build_armory2.py` emits no primitive guns. It writes `Arm2_Guns`: one empty per gun, `Gun_<Rack|Near>_<family>_<n>`, its full
  placement (racked butt-down on a shelf, flat on case felt, hung on a pegboard, mounted on the fascia). Brass pegs under hung and
  mounted guns are the only new furniture.
- `tools/ep2_blender/build_rack_guns.py` cuts each founder model to a budget: Rack (~1.4k long guns, ~0.7k sidearms) and Near (~4k /
  ~2.5k for cases, counter, benches, fascia). All are on one axis (muzzle +x, top +y) at real length, in `extras/armory/rack_guns.glb`,
  geometry only (no images).
- `Ep2ArmoryRacks.fill` (`src/episode2/actors/ep2_armory_racks.gd`) puts the matching piece on every slot. Each piece wears its SOURCE
  GLB's own materials, the same resources the Tabs showcase loads, so no texture is stored twice. Pieces are shared meshes, with no
  shadows, and draw within 45 m.
- Sources: `showcase/` Winchester 1886, Sharps (scoped), coach shotgun, golden Tommy, machine gun, Borchardt, gold Remington, plus
  `assets/weapons/armory/` Bergmann MP18, golden revolver, Remington 1875 gold and bear longbow, and `assets/hideout/gatling.glb`.
  The `meshy/` copies are not used: they include Lil Blunt's gloved hand.

## Consequences
- 130 founder guns (72 racked, 12 in barrels, 13 in the cases and counter tray, 25 on the gallery pegboards, longbow, Gatling,
  3 on the fascia, 3 on the benches). They total ~195k triangles. The worst armory frame in the capture script went from 248k to 270k
  triangles, with about 130 more draw calls.
- Rich's lit-case Sharps (`Ep2SharpsCase`), the Tabs showcase, prices, the Shipment chain and the brains are untouched.
- Gate `tests/ep2_armory_real_weapons_test` (in CI); `ep2_armory_two_story_test` counts the guns in the fit-out density check.
- Rebuild order: `build_rack_guns.py` (writes `rack_guns_dims.json`), then `build_armory2.py`.
