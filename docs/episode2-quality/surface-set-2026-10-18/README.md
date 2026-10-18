# Episode 2 surface set (founder 2026-10-18)

Founder prompt: `PROMPT_EPISODE2_HORSES_STABLE_TRAIN_LAKE_WRONG_STAGE.md` (Drive). The horse, stable, train and lake were built into the
Episode 1 Level 3 backdrop, which the founder never sees. They now stand in **Episode 2**, on the desert approach after Lil Blunt and
Inferno leave the forest.

- Code: `src/episode2/chamber/ep2_surface_set.gd` (class `Ep2SurfaceSet`), water shader `src/episode2/art/lake_water.gdshader`.
- Built by `Ep2GoldTown.build()` (`src/episode2/chamber/ep2_gold_town.gd`), which both the bear woods ride
  (`src/episode2/chamber/woods_quad.tscn`, z 960 -> 1400) and the town room (`gold_town.tscn`) call at the same coordinates.
- Where: rails x 34 and the lake x 42..184 beyond them, z 1030..1385, on the left of the road; the stable at x -16, z 1222 on the right.
- Assets: only what already ships (15 horse frames, `sprite_prop_stable.png`, `sprite_prop_train-goldmine_512.png`). No new Runpod spend,
  no 3D horse in the pack.
- Episode 1 Level 3 was NOT touched.
- Gate: `tests/ep2_surface_set_test.tscn` (`EP2_SURFACE_SET: ALL PASS`), a CI step in `export-game.yml`.

## Captures (REAL Episode 2 render: `WoodsQuadChamber`, RIDE beat, the quad's own first-person camera, 1600x900)
- `ep2_ride_approach_lake_town.png`: looking down the road at z 1210: lake + rail line on the left, Fort Knox and the town ahead.
- `ep2_ride_train_and_lake.png`: looking left at z 1070: the GoldMine locomotive on the rails, the lake behind it.
- `ep2_ride_stable_and_horses.png`: looking right at z 1210: the stall and corral, three horses (graze / stand / walk).
- `ep2_surface_shot.gd.txt`: the throwaway capture script (rename to `.gd` inside `tools/ep2_shots/` with a `.tscn` to rerun).

## Not verified here
Live itch build and a hard refresh (founder acceptance). The pack gate and the CI run for the shipping commit decide the rest.
