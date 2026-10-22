# Rich & Utah's two-storey Armory (founder brief 2026-10-19)

Brief: Rich and Utah own the Armory; make it a double-storey building with crazy weaponry, both working in it, moving properly with
detailed movements and good autonomy; add windows, a proper entry and detail/character; no horse inside. Use Runpod and the machine's
tools; install EL4CTEO/blender-skills and build skills from it. Logan is parked.

## What was built
| Piece | Where | Numbers |
|---|---|---|
| Building + fit-out | `tools/ep2_blender/build_armory2.py` -> `src/episode2/extras/armory/armory2.glb` | shell 6,210 tris, fit-out 17,616 tris, 1.26 MB |
| Rich (founder Tripo FBX, UE rig) | `tools/ep2_motion/prep_folk.py` -> `retarget_bvh.py` -> `export_folk.py` | 59.0k -> 16.0k tris, 1.80 m, 1K textures, 14 clips, 2.93 MB |
| Utah (founder Tripo GLB, Mixamo rig) | same | 66.9k -> 16.0k tris, 1.85 m, 1K textures, 14 clips, 2.66 MB |
| Motion | CMU mocap (free for commercial use, `tools/ep2_motion/fetch_cmu.sh`), windows in `clips_folk.json` | Idle, Walk, StairsUp, Greet, Point, Talk, Carry, PickUp, PutDown, WipeRifle, InspectRifle, Reach, Counter, CigarPuff |
| Autonomy | `src/episode2/actors/ep2_armory_brain.gd` | waypoint graph from the GLB, weighted work tasks on both floors, stair reservation, greet on entry |
| Streaming | `src/episode2/ep2_extras.gd`, `tools/ep2_extras/pack_extras.gd`, CI | `index.pck` 198,808,080 B (gate 199,229,440, margin 421,360); `ep2_extras.pck` 3.7 MB |
| Horse | `Ep2TownLife.HORSES` | the grazing horse moved from inside the Armory (-24, 1472) to (-27, 1462.5) |

## Proof
- `tests/ep2_armory_two_story_test.tscn`: EP2_ARMORY2 ALL PASS (29 checks: two floors, clear glass, door gap, counter solid, waypoints,
  blockers, lamps, no horse in any building, Treasury untouched, Rich > 55% at his counter, Utah on both floors, never both on the
  stair, never inside a blocker, >= 6 clips in 100 s, Rich greets within 1.2 s). `ep2_gold_town_test`, `ep2_town_life_test`,
  `ep2_personal_armory_test`, `ep2_fort_knox_arc_test` ALL PASS.
- Streaming, engine level: an EMPTY Godot 4.3 project mounts `ep2_extras.pck` and loads the Armory (with its nav data) and Rich and
  Utah (14 clips each, textured).
- Streaming, real web build (fresh clone, pinned 4.3 export, Chromium): `GET ep2_extras.pck -> 200`, console `[EP2] extras ready (http 200)`.
- Captures below: the real Compatibility renderer, Lil Blunt's eye height, the town built by the game's own `Ep2GoldTown.build`,
  Rich and Utah running their brains (`tools/ep2_shots/armory2_shot.tscn`).

| File | What it shows |
|---|---|
| `1_lane_approach.png` | the two-storey front from the lane: false front, "RICH & UTAH ARMS", balcony rail, shuttered windows, porch; the horse grazing outside |
| `2_porch_door.png` | the entry: steps, posts and brackets, the hanging sign, both door leaves open, barred display windows, lanterns, posters |
| `3_counter_rich.png` | Rich greeting at his counter; the rifle walls on green baize on both floors; ammunition shelves; the glass case |
| `4_gallery_utah.png` | Utah crossing the shop floor between tasks |
| `5_racks_gatling.png` | the gallery with its rail, the Gatling, the mounted long guns, the back racks |
| `rich_clips_strip.png`, `rich_utah_game_meshes.png` | the game meshes and Rich's clips (Walk, Greet, Counter, CigarPuff, WipeRifle, InspectRifle) in Blender |

## Open / not claimed
- Faces: both men wear sunglasses; no facial rig was added (the founder's "expression" meant the building's character).
- Rich holds his nugget and pickaxe in every clip: they are part of the founder's Tripo mesh (removable by island surgery if wanted).
- Stairs down use the Walk clip (no clean CMU descend clip).
- Runpod: pod `pqcfms6z98llt8` (A40, $0.59/h) ran ~78 min (about $0.77), now STOPPED; its 60 GB volume is kept.
