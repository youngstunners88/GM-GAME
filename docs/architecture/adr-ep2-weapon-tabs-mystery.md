# ADR: Episode 2 weapon tabs follow possession; Rich's case hand-over (2026-11-07)

## Status
Accepted

## Context
Founder brief 2026-11-07:
- the weapon tabs showed every gun, owned or not (the "mystery" rule);
- the pickaxe had no tab;
- the counter's Sharps sat below guns it unlocks;
- the bow's string forearm looked like a plastic pole;
- the Sharps scope was too long;
- Rich's take-out of the Sharps from the glass case was "tacky".

Skill: `ep2-build-logic`. Gate: `tests/ep2_weapons_test.tscn`. Evidence: `docs/episode2-quality/weapon-tabs-2026-11-07/REPORT.md`.

## Decision

1. **One possession rule for tabs.**
   - `Ep2ArmoryShop.tab_owned(state, tab)` decides every tab at Rich's counter. A gun counts while it is owned and not held by the Sheriff. A "_held" tab follows its gun. The pickaxe counts always.
   - `Ep2ArmoryShop._tabs()` returns only those tabs, and only when the model is loadable. Buttons are made per shown tab, and short rows are centred.
   - `Ep2WeaponSelector.shown_ids()` applies the same rule to the personal armory's cards. A card keeps its slot's quick-switch key, wherever it lands in the grid. Nothing is drawn for an unowned gun.
2. **The pickaxe is owned from the start.** It is a tab with no shop row (`row: ""`): it fills the case and leaves the highlight alone. No shop row or save id is added.
3. **The counter's order is data.** `Ep2ArmoryState.SHOP` rows moved: Shipment, the Sharps and its cartridges, then each gun over its ammunition, in story order. Ids are pinned by the gate.
4. **The case and its rifle are one system (`Ep2SharpsCase`).**
   - The Armory GLB's case glass is split into walls and a hinged lid (`Arm2_CaseLid`, `Hinge_case`).
   - The case holds the same rifle Rich holds (`Ep2ArmoryPose.make_rifle`).
   - A pure function of the intro's stage clock (`Ep2ArmoryIntro.stage_time`, constants `REACH_S`, `IN_HAND_AT`, `BACK_S`, `OUT_OF_HAND_AT`) poses the lid, the rifle and his arms. The arms use `Ep2ArmIK`, which now takes explicit bone names for UE rigs.
   - `sharps_lifted` keeps its meaning: the rifle on or off the hand bone.
5. **The bow forearm is built at load time.** `Ep2BowView._founder_forearm` drops the build's grown `SleeveCloth` surface and grows a cuffed, tapered, folded cloth forearm on the same axis. No asset changes.

## Consequences
- A confiscated gun's card and tab disappear until he buys it back or the irons return. The jail screen says "THE SHERIFF HOLDS YOUR IRONS".
- The take-out is 0.7 s longer, and the put-back 0.9 s longer.
- The kit's procedural Sharps in `armory2.glb` is hidden in game, and still carries the old long tube.
- `ep2_town_law_test` (HELD cards) and `ep2_armory_chain_test` / `ep2_weapon_consistency_test` (nine tabs, the long tube) were changed to the new rules.

## ADR Dependencies
ADR-0005 (streamed Episode 2 extras): every new model is under `src/episode2/extras/`.

## Engine Compatibility
Godot 4.3, Compatibility renderer. It uses `SkeletonModifier3D` (`Ep2ArmIK`), `SurfaceTool`, `NoiseTexture2D` and `ArrayMesh.add_surface_from_arrays`.

## GDD Requirements Addressed
Founder brief 2026-11-07 (items 1-4 plus the scope and the take-out). `design/ep2/armory/WEAPON_CONSISTENCY.md` (the scope length) is superseded on that point.
