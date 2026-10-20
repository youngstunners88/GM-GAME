---
name: ep2-jailhouse
description: Build and maintain the Episode 2 jailhouse - the Sheriff's small stone jail out at the south edge of town with one occupied cell, the caught accomplice who admits the bears were brought in for early claims and Fort Knox pressure, the Sheriff's ask, and the investigation hook onto the existing lake -> river -> train -> Fort Knox path. Founder lock PROMPT_EPISODE2_JAILHOUSE_BEARS_INVESTIGATION (Drive "Jail House", 2026-10-20). TRIGGER on "jailhouse", "jail", "accomplice", "who brought the bears", "investigation", "Sheriff's prisoner", editing Beat.JAIL_TIP/JAIL, Bldg_Jail or build_jailhouse.py.
---

# Jailhouse + accomplice + "who brought the bears" (founder lock 2026-10-20)

## The lock in one line
The jailhouse holds a caught accomplice who admits the bears were brought in for early claims and Fort Knox pressure. The Sheriff asks
Lil Blunt to investigate. The hunt runs along the existing lake -> river -> train -> Fort Knox path. No detective open-world, no celebrity
prison museum, no prison-break, no invented jail/enforcement protocol, Fort Knox stays the climax, the culprit is NOT staged this pass.
Founder placement rule: the jailhouse is a little way out of town, not beside it.

## Where things are
| Piece | File |
|---|---|
| Building + cells + nav (streamed extras) | `tools/ep2_blender/build_jailhouse.py` -> `src/episode2/extras/jail/jailhouse.glb` (Bldg_Jail, Jail_Nav: Spot_*, Block_*, LightAnchor_*) |
| Painted sign | `tools/ep2_forge/paint_town_signs.py JAIL --out src/episode2/extras/jail` (run with `uv run --with pillow`) |
| The accomplice | `tools/ep2_blender/build_townfolk.py --only accomplice` -> `src/episode2/extras/people/prisoner_accomplice.glb` |
| Placement + collision | `Ep2GoldTown`: `LAYOUT` row `["Bldg_Jail", -26.0, 1399.0, 1]`, `FOOTPRINT`, `_load_jail()`, `_blocks_to_walls()`, `JAIL_CLEAR` (scatter) |
| Story | `gold_town.gd`: `Beat.JAIL_TIP`, `Beat.JAIL`, `JAIL_LINES`, `_build_jail_folk()`, handoff keys `jail_visited`, `investigation` |
| Gate | `tests/ep2_gold_town_test.tscn` (jail walk-through + line content check) |

## Rules learned
- Placement: Sheriff/Certificates side = left (x < 0), at the south edge of town: front plane x = -26, z = 1399 (door faces +x toward the road), ~26 m
  from the drop-off (0, 1403), clear of the Armory lane. If the row is moved, keep >= 22 m from the drop-off and update `JAIL_CLEAR`.
  Walkable bounds are x +-40, z 1340-1495.
- Streamed (ADR-0005, `ep2-streamed-extras-web`): nothing under `extras/` is in `index.pck`; when the extras are not mounted the layout row draws
  nothing and the story skips JAIL_TIP/JAIL (`Ep2GoldTown.jail_v1`). Never load the jail without `Ep2Extras.has()`.
- Beat order: WON -> JAIL_TIP (Sheriff walks ahead, objective names the jail) -> JAIL (enter) -> TIP (Armory) -> ARMORY -> GEARED -> DONE.
  The lines are timed toasts (the HUD has no subtitle bar; VO waits on a voice key like the Armory's). Keep lines <= ~90 chars.
- Accomplice = bargaining, partial truth only: bears brought in, early claims, Fort Knox first, "watch the lake outflow, the river, the trains".
  Never a full map of bear spawns, never a name from the real world.
- Cell block is solid: `Block_bars` spans the whole bar line, the accomplice stands inside at `Spot_accomplice`; the player stands at `Spot_visit`.
- Test paths must walk STRAIGHT through the doorway (door_world(..., -0.9)) before turning; a diagonal clips the 0.75 m half-door.
- Windows are hole-cut (`wall_holes`) like every other building (skill `gm-game-episode2-town-windows-doors`).

## Open (founder, from the lock)
Accomplice name, look and VO; the one or two clue props (letter, brand, token, map scrap); when the culprit is first seen; whether a background
archetype cell is built (only the empty cell B exists now).
