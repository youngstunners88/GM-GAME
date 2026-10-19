---
name: ep2-town-people
description: Build and place townsmen and townswomen for the Episode 2 gold-rush town - rigged on-box people (clerk, old-timer, rancher, dressmaker, lady), their routes, pauses and greetings, streamed with the Episode 2 extras. TRIGGER on "townsmen", "townswomen", "the town is empty", "no people", "NPCs on the street", "add a townsperson", or editing build_townfolk.py / ep2_town_people.gd.
---

# Town people (founder 2026-10-19: "we're lacking townsmen and townswomen ... full discretion")

## Pieces
| Piece | Where |
|---|---|
| Bodies | `tools/ep2_blender/build_townfolk.py` (built on `build_armory_folk.py`: one skeleton drives mesh + armature; clips Idle/Walk/Greet/Point/Carry) -> `src/episode2/extras/people/*.glb` (~0.2 MB each, 3-4.6k tris) |
| Behaviour | `src/episode2/actors/ep2_town_people.gd` (`Ep2TownPeople`: `ROSTER` with routes, speeds, pauses; `step(delta, player_world)`) on top of `Ep2TownFolk` |
| Placement | `gold_town.gd` builds it after the Armory pair and ticks it in `_tick_people` |
| Gate | `tests/ep2_town_people_test.tscn` (routes clear of every wall/prop at 0.35 m, 120 s of walking, no lock-step, greet + cooldown) |
| Capture | `tools/ep2_shots/town_fronts_shot.tscn` shots 9 and 10 |

## Rules learned
- Routes stay in the open middle of Main Street (x within +-2.9, z 1408-1445): hitching rails/troughs/lamps/benches sit at |x| >= 6, horses at x +-4.5, wagons z > 1452, and porches are 0.44 m above the street (people would sink).
  Any new route must pass the test's `Ep2GoldTown.collide` sweep against the real wall and prop lists.
- The Compatibility renderer under the desert grade washes colour out; cloth and leather are built darker (x0.66). Check any new person against the street, not Blender.
- Streamed (ADR-0005): everything is under `src/episode2/extras/`; `Ep2TownPeople.build` places whoever loads and nobody if the extras are not mounted. Never load a person without `Ep2Extras.has()`.
- The women's skirt is skinned to Hips/Thigh/Shin/Spine bones (distance weighting); it flares with the stride. If it tears, add a skirt bone chain rather than shrinking the skirt.
- Heights 1.66-1.84 m; each silhouette must differ (hat, coat, dress colour) so five people do not read as clones.
- For hero-quality faces/outfits, the founder's Tripo pipeline (`ep2-tripo-folk-to-game`, `ep2-runpod-motion-lab`) is the upgrade path: Tripo mesh -> `tools/ep2_motion/prep_folk.py` -> mocap retarget. It needs a reference image per person and spends credits.

## Next ideas (not built)
Sitting on benches, a woman sweeping, a boy with a hoop, a dog; Utah/Rich-style mocap clips for the town people (retarget_bvh.py works on the on-box rig only after a rest-pose map).
