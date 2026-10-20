---
name: ep2-side-lane-build
description: Build a real side street (a lane, a second block) into the shared Episode 2 gold-town layout so it shows up in BOTH the woods ride and the town chamber - LAYOUT rows, reused kit facades, collision walls, lane dressing, walkable bounds, scrub exclusion, tests. TRIGGER on "add a street", "second street", "side lane", "avenue", "the town is one block", "build the lane", editing LAYOUT/FOOTPRINT in ep2_gold_town.gd, or any change that adds buildings to the town.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Building a side lane into the shared town

Plan first with `ep2-town-streets` (proposal geometry) and score with `ep2-sightline-proof`; this skill is the runtime pass. `src/episode2/chamber/ep2_gold_town.gd` is built by BOTH `woods_quad.gd:2540` (`build(_visuals, false)`, the town grows out of the desert as the quad rides in) and `gold_town.gd:173` (`build(_visuals, true)`, the chamber with interiors). **Edit the shared builder once; never fork a town copy.** The handover between them must keep identical world coordinates.

## What actually makes a street here
There is no road mesh. The ground is one `DesertFloor` plane (1400 x 1300) and a street is **two fronts facing a corridor, plus dressing**. So a lane is: `LAYOUT` rows, props, lamps, hitch rails and worn-ground cues; "a painted strip alone is not an avenue" (`ep2-town-streets`). Pure paint will not pass the founder's "second street visible on hard refresh".

## Zero-byte facades
- Reuse kit pieces already in `town_kit.glb` (`Bldg_A..F`, `Church`, props `HitchRail`, `Trough`, `Wagon`, `LampPost`, `Bench`, `Boardwalk4m`, barrels and crates). Repeating a piece in `LAYOUT` is safe for **building**; `kit.find_child` + `duplicate()` per row.
- Caveats found in the code: `entry(piece)` returns the **first** row with that name, so anything scripted by name (Certificates, Saloon, Armory, interiors via `_furnish`, `_in_room`, the tests) must stay unique; fillers must not be looked up by name.
- Every duplicate re-hangs its sign (`_hang_signs` reads `SignAnchor_*` from the kit piece: GENERAL/ASSAY/STATS/HOTEL/RESERVE/AUCTIONS). A lane lined with repeated STATS boards looks like a bug. Pick fillers whose signs differ from the Main Street neighbours, or add an optional 5th `LAYOUT` field (`"plain"`) that skips `_hang_signs`. Existing consumers read indices 0-3 only; `armory_offmain_probe.py` already tolerates extra fields.
- New facade variants or textures cost pack bytes. The margin is thin (~467 KB after the 2026-10-18 fixes): measure with `scripts/pack-gate-fresh.sh` before and after, and prefer transforms.

## Checklist (do all, in this order)
1. **`LAYOUT`** rows `[piece, front-plane x, front-centre z, side]` (+1 faces +x, -1 faces -x, 0 faces -z). Add a matching `FOOTPRINT` entry only for a new piece name. Collision comes free: `build()` appends `_walls_of(piece, xform)` per row.
2. **Bounds.** `GoldTownChamber._collide` clamps the player to x in [-40, 40], z in [`TOWN_Z`-60, `TOWN_Z`+95] (`gold_town.gd` ~905). A lane whose west fronts reach x=-39 is inside; going further needs the clamp widened (and the camera/fog still reading). Walkable town ends at z 1495; the river (z 1522) and railway (1546) behind it are scenery.
3. **Desert scrub / rocks.** `build_desert` keeps scrub off the road and "in_town"; wider streets or yards need the exclusion reconciled (around x = +-26, see `ep2-town-streets` step 5). No shrub through a lane, no lane running into the fort hill.
4. **Lane dressing** goes in the `dress` array, which is in world coordinates: lamps at both mouths, hitch rails, a trough, crates/barrels, a fence or boardwalk piece on the fronts. The armory's old staging lives there and must move with it: `LampPost (-10, 1450)`, `Arm_PowderKeg x2`, `River_Crate`, `River_Skiff`. Each `dress` entry also appends a collision circle to `props`, so keep walking room (>= 1.2 m each side of the path).
5. **Opening the lane.** The left-row buildings have ~1-2 m gaps; make the entrance deliberate: a cross-lane mouth at a row end (north of `Bldg_E` ends z~1450.5, south of `Bldg_Certificates` starts z~1408), with the lamp and a worn-ground cue. Do not move Certificates, Saloon, Treasury or the duel lane.
6. **Living town.** `Ep2TownLife.HORSES`, `WALK_FROM/TO`, river and train sit near the lane. Keep horses (founder: never replace them) but move any that fall inside a new footprint; keep the walker's path clear.
7. **Story hooks.** `LANE_MARK` and the TIP beat's `face_point`/`look_toward` (`gold_town.gd` ~76, ~587), and the objective text. Keep "lane" in the objective (a test asserts it).
8. **Tests.** Update the waypoint chain in `tests/ep2_gold_town_test.gd` (~207-215): `_walk_to` steers straight lines only, so give it every corner (drop-off -> row end -> lane mouth -> `LANE_MARK` -> `door_world("Bldg_Armory", 2.2)` -> `ARMORY_SPOT`). Add checks that are new capabilities, not loosened old ones: the lane fronts exist, no filler overlaps another footprint, the walk works, the path length is recorded.
9. **Run** the pinned Godot 4.3 headless (`.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless res://tests/ep2_gold_town_test.tscn`, a new `class_name` needs `--headless --editor --quit` first), then `scripts/ci-gates-local.sh`, then the probe, then captures.

## Godot 4.7 traps (this box)
Importing with 4.7 dirties ~190 tracked `.import` files and creates `.uid` files: revert before committing (`git diff -z --name-only | xargs -0 git checkout --`; delete untracked `*.uid`). Never `git add -f` a new `.import` unless a sibling is already tracked (CI's 4.3 rewrites it and the export commit step fails, skipping the itch deploy). `*.gd` files edited by script: `smelting_facility.gd` is CRLF (not this job, but do not touch).
