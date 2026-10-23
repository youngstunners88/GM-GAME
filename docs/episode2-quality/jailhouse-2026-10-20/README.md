# Jailhouse + accomplice + "who brought the bears" (founder lock 2026-10-20)

Drive doc "Jail House" (`PROMPT_EPISODE2_JAILHOUSE_BEARS_INVESTIGATION`) + "make sure the jail house is a little bit further away from the town".

## What was built
| Piece | Where |
|---|---|
| Jailhouse (grey stone, 7.4 x 8.6 m, hole-cut barred windows, open plank door, brass star, JAILHOUSE sign, office + 2-cell block) | `tools/ep2_blender/build_jailhouse.py` -> `src/episode2/extras/jail/jailhouse.glb` (3.8k tris, 210 KB), sign 7 KB packed |
| Placement | `Ep2GoldTown.LAYOUT` row `["Bldg_Jail", -26.0, 1399.0, 1]`: Sheriff/Certificates side (x < 0), out at the south edge of town west of the road, ~26 m from the drop-off (0, 1403) and clear of Main Street and the Armory lane; yard has a lamp post, a hitching rail and a bench; scatter clearing `JAIL_CLEAR` |
| The accomplice (one person, hatless, rough, rope at his belt) | `build_townfolk.py --only accomplice` -> `src/episode2/extras/people/prisoner_accomplice.glb` (190 KB), held in cell A behind solid bars |
| Story | `Beat.JAIL_TIP` (Sheriff walks ahead, objective names the jail) -> `Beat.JAIL` (six-line exchange; the hunt opens) -> `Beat.TIP` (Armory) as before; handoff carries `jail_visited`, `investigation` |
| Streaming | everything is in `src/episode2/extras/` (ADR-0005); without the extras nothing is drawn and the beats are skipped |

## The lines (partial truth only; no celebrity prisoner, no invented protocol, culprit unnamed)
Sheriff presents the caught helper; the accomplice: "All I did was open a gate. Somebody paid me to bring them in." / "Never saw a face. Coin, and an order: soften the
claims before the vault locks." / "They want Fort Knox first. Watch the lake outflow, the river... the trains." Sheriff: "Find who brought the bears, Lil Blunt."

## Proof
- `tests/ep2_gold_town_test.tscn` ALL PASS (73 checks) including: the jail is >= 22 m from the drop-off on the Sheriff side, he walks out and in through the
  doorway, the accomplice is in his cell, the exchange opens the investigation, the lines name bears/claims/Fort Knox/lake/river/trains, then the Armory tip follows.
- Real-renderer captures (`tools/ep2_shots/jail_shot.tscn`): 1_from_the_drop (it stands apart), 2_road_approach, 3_door, 4_side_with_town, 5_inside_office, 6_the_cell.

## Not claimed
Voice (lines are timed text like the Armory tip), the accomplice's name/look/VO, clue props, the culprit (downstream by the lock). The accomplice is the on-box
stylised figure (the ship-now path); a Runpod Hunyuan3D + Mixamo-rig upgrade is documented in skill `ep2-mixamo-pipeline`.
