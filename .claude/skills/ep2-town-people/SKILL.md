---
name: ep2-town-people
description: Build and place townsmen and townswomen for the Episode 2 gold-rush town - rigged on-box people (clerk, old-timer, rancher, dressmaker, lady), their routes, pauses and greetings, streamed with the Episode 2 extras. TRIGGER on "townsmen", "townswomen", "the town is empty", "no people", "NPCs on the street", "add a townsperson", or editing build_townfolk.py / ep2_town_people.gd.
---

# Town people (founder 2026-10-19: "we're lacking townsmen and townswomen ... full discretion")

## Pieces
| Piece | Where |
|---|---|
| Street bodies | `tools/ep2_blender/rebuild_street_people.py` -> the same five `src/episode2/extras/people/*.glb` paths. Reference-led anatomical heads/hands, layered clothing, UVs and embedded PBR; same 20-joint rig and Idle/Walk/Greet/Point/Carry |
| Editable source and recovery | `design/ep2/town/people-rebuild-20261021/`: `.blend` files, texture maps, owner references, CC0 anatomical source/license, original GLBs and baseline SHA. `build_townfolk.py` is the recoverable legacy generator and still owns the separate accomplice; do not run it over the five replacements |
| Behaviour | `src/episode2/actors/ep2_town_people.gd` (`Ep2TownPeople`: `ROSTER` with routes, speeds, pauses; `step(delta, player_world)`) on top of `Ep2TownFolk` |
| Placement | `gold_town.gd` builds it after the Armory pair and ticks it in `_tick_people` |
| Gate | `tests/ep2_town_people_test.tscn` (routes clear of every wall/prop at 0.35 m, 120 s of walking, no lock-step, greet + cooldown) |
| Capture | `tools/ep2_shots/town_fronts_shot.tscn` shots 9 and 10 |
| Replacement proof | `review_street_people.py --person ID --render` (installed mesh/rig QA + whole-clip edge measurements + Blender multiview); `audit_street_people.py` (independent plain-GLB check); `tests/ep2_street_people_assets_test.tscn` (Godot import/material/skin/clip gate) |
| Matched real gameplay | `tools/ep2_shots/street_people_play.tscn -- variant=before|after`: actual GoldTown chamber, unchanged routes/greetings, its own 1.55m eye/78-degree camera, HUD and Winchester. Fixed 1280x720 SubViewport prevents desktop tiling from changing comparison framing |

## Rebuild safely

Use `gm-blender-godot` and the installed rig/material/baking/animation/export/QA skills. Run separate background processes with
`ALSOFT_DRIVERS=null blender -b --factory-startup -t 2 --python-exit-code 1 -P tools/ep2_blender/rebuild_street_people.py -- --only ID`.
The audio setting prevents background PulseAudio shutdown hangs on this PC; it does not change the open Blender session.
Run one or two processes at a time on the 8GB machine. Keep logs; read semantic `pass`, not only process exit status.

- Voxel-weld cloth in an open A-pose, then return it to bind pose. Welding hanging sleeves against the torso fuses wrist to waist.
- Preserve torso/left-arm/right-arm semantics through the weld and smooth weights over connected topology. Nearest-bone weighting over the whole shirt gave extreme stretching despite normalized weights.
- Hand topology has explicit wrist bridges into the cuff. Real folded cuffs, buttons and stitches must contact their support surfaces.
- Keep mesh and bind-joint normalization together. The legacy Figure helper rescales only geometry; cancel that before fitting the rig.
- Do not accept studio pictures alone. Compare the actual player-camera before/after against the reference, and review all five clips and every angle. Check image save return codes; disk-quota failures once left an incomplete Carry sequence.
- New textures stay with the streamed extras. Commit the Godot 4.3 extracted maps and their `.import` presets; run two import passes and both pack-size/presence gates.

## Rules learned
- Routes stay in the open middle of Main Street (x within +-2.9, z 1408-1445): hitching rails/troughs/lamps/benches sit at |x| >= 6, horses at x +-4.5, wagons z > 1452, and porches are 0.44 m above the street (people would sink).
  Any new route must pass the test's `Ep2GoldTown.collide` sweep against the real wall and prop lists.
- The Compatibility renderer under the desert grade washes colour out; cloth and leather are built darker (x0.66). Check any new person against the street, not Blender.
- Streamed (ADR-0005): everything is under `src/episode2/extras/`; `Ep2TownPeople.build` places whoever loads and nobody if the extras are not mounted. Never load a person without `Ep2Extras.has()`.
- The replacement skirts use pelvis/spine/thigh weights rather than ankle attraction; authored folds hold their volume during the stride. If future clips tear them, add a proven skirt chain rather than shrinking the skirt.
- Heights 1.66-1.84 m; each silhouette must differ (hat, coat, dress colour) so five people do not read as clones.
- Current heads/hands use the retained CC0 anatomical base plus the owner's reference images; no paid generation was needed. Tripo/RunPod remain optional higher-fidelity routes, with a concrete spending plan and authorization when required; lake-specific GPU authorization is not blanket town-cast authorization.

## Next ideas (not built)
Sitting on benches, a woman sweeping, a boy with a hoop, a dog; Utah/Rich-style mocap clips for the town people (retarget_bvh.py works on the on-box rig only after a rest-pose map).
