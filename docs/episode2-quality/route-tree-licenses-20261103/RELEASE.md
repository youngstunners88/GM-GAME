# Route blockers + license wall - 2026-11-03 (founder follow-up)

## 1. Invisible wall on the way to Logan's Lake
**Cause.** Out of Dude's ranch the horse roams free (`LakeTrailChamber._move_departure_area`) until the trail takes over. The hand-off
needed him within **2 m** of the road's centre line, but the visible road is **5.8 m** wide. Riding on its edge (or a little off it), he
was never handed over and rode into the departure bound (`z = -80` local, ~116 m out), which stopped him dead: the invisible wall.

**Repro (before, old `lake_trail.gd`, `tests/ep2_lake_trail_test.gd::_test_departure_never_walls`):**
`riding 2.8 m off the road ... route 128 m` FAIL, `riding 8.0 m off ... route 128 m` FAIL (stuck at the bound).

**Fix.** Capture radius 3.6 m (the whole road + the horse), and wherever the bound would stop him within 16 m of the road the bound
becomes the trail's way in. The real lateral offset is kept and eased onto the +-2.2 m lane at 3 m/s (no sideways snap).
After: all three rides (2.8, -2.8, 8.0 m off) pass 150 m on the trail lane.

## 2. Tree in the road as Inferno approaches Dude's ranch
**Cause.** 2026-11-02 (`b58da5c`) moved two ranch pines from (1, 1207) / (0, 1199) to (9, 1201) / (9, 1192) to clear Dude's patch -
onto Inferno's quad road (`WoodsQuadChamber.RIDE_TRAIL`): 1.2 m and 2.0 m from its centre line.
**Fix.** Now (-4, 1186) and (-12, 1186): >= 10 m from the quad road, the lake road and the town-return road, < 45 m from the stable,
clear of the patch. Gate: `tests/ep2_ranch_test.gd` (every ranch trunk >= 6 m from the quad road; nearest is now 6.9 m).
Capture: `ranch_road_tree_before_after.jpg` (left: the old pine in the road line; right: the road open to the town).

## 3. License wall
Moved to the wall opposite Mike Dean's desk (right wall, x +3.86), on the clear stretch behind the side window, reading left to right
Prospector's -> Mine Owner's with a slight rise. Prints: GPT Image 2 via Muapi ($0.24 for four; Gemini image models are 0/day on
the free tier). Streamed in `ep2_extras.pck` (`src/episode2/extras/town/licenses/`), placards until it mounts.
Mike Dean: "...talk to my good friend Dude at the stables. Tell him I sent you." (re-recorded, voice `CfxYdK3WmF3bmrvyLAiU`).
Captures: `license_prints.jpg`, `license_wall_in_game.jpg` (`tools/ep2_shots/license_wall_shot.tscn`, real renderer).
