---
name: ep2-armory-guns
description: The Armory's two hero guns and Rich and Utah's introduction (founder 2026-10-20): the Sharps Model 1874 Buffalo Gun (the long rifle Rich sells) and the Colt Gatling Gun (a mounted gun on a post OUTSIDE the shop, never for sale, Lil Blunt can fire it). TRIGGER on "Sharps", "Buffalo Gun", "Colt Gatling", "Gatling", "introduce Lil Blunt to the guns", "upgrade Rich and Utah", "mounted gun", "Rich holds the rifle", "Utah demonstrates".
---

# Armory guns: Sharps 1874 + Colt Gatling (ep2-armory-guns)

Founder (2026-10-20): "upgrade Rich and Utah ... they introduce Lil Blunt to the Sharps 1874 Buffalo Gun and Colt Gatling Gun." Answers he locked:
Gatling = a **mounted gun Lil Blunt can use** (Utah demonstrates it, then he takes the crank), **outside the Armory store** (never in `Ep2ArmoryState.SHOP`);
Sharps = **the long rifle he buys** (the old generic "LONG RIFLE"/`sniper`); Rich and Utah keep their Tripo designs, made better.

## What exists
| Piece | Where |
|---|---|
| Sharps model (Model 1874 sporting rifle, ~1.21 m, octagon barrel, falling block, hammer, finger lever, set triggers, tang peep sight) | `tools/ep2_blender/armory_kit.py` `sharps()` -> `src/episode2/extras/armory/sharps_1874.glb`; the case copy is `Arm2_Sharps` in `armory2.glb` |
| Gatling post (Gatling_Post -> Gat_Yaw -> Gat_Pitch -> Gat_Barrels, Gat_Crank; Gat_Muzzle/Eye/Eject/Sign; Range_Plate+Range_Swing, Range_Bale) | `armory_kit.py` + `build_sharps_gatling.py` -> `gatling_post.glb` |
| Post logic (arc +-50 deg, 9 rounds/s, **finite drum 150, never refilled**, hitscan on plates, tracers, flash, casings, dust) | `src/episode2/actors/ep2_gatling_post.gd` (`Ep2GatlingPost`) |
| The introduction (Rich lifts the Sharps from the case, names it, offers it, locks it back; Utah leads out, demonstrates, offers the crank) | `src/episode2/actors/ep2_armory_intro.gd`; brains are DIRECTED (`Ep2ArmoryBrain.direct/release`) |
| Mounted mode | `gold_town.gd`: `[E]` at the stand takes/leaves the crank; overrides `look/shoot/_move_player/_fps_camera/_set_eye_view/set_aim/reload/select_weapon` |
| Held rifle | `Ep2TownFolk.attach_prop` (BoneAttachment3D, `HOLD_RICH` = `hand_l` - the hand whose pickaxe was cut; `SHARPS_HOLD_*` tuned by eye) |
| Rich/Utah upgrade | `tools/ep2_motion/strip_props.py` (Rich's fused pickaxe cut out of the body so his hand can hold a gun), clips `Crank` (CMU 15_08) and `HandOver` (CMU 80_06) in `clips_folk.json`; `retarget_bvh.py` + `export_folk.py` |
| Gate | `tests/ep2_armory_guns_test.tscn` (also the other Armory/town gates); shots: `tools/ep2_shots/armory_guns_shot.tscn` |

## Rules (do not break)
- The Gatling is **never stock**: not in `SHOP`, no `purchase_*`, not a quick-switch slot (`IDS` stays 3). The sign on its board says NOT FOR SALE.
- Its ammunition is **finite and free of refills**; no crypto, no soft currency changes. Rich never offers the Sharps free (his line prices it with the shop's own `price`).
- The post stands **outside** (front yard, `Ep2GoldTown.GATLING_POST`, building-local; the Armory faces -z so local +x is world west = open ground, never toward Main Street) and **clear of the grazing horse** at (-27, 1462.5) (founder: "dont replace the horses").
- The mounted camera is the gun's eye (`Gat_Eye`, over the drum); the Winchester viewmodel is hidden meanwhile. Geared handoff waits while he is mounted.
- Everything here is streamed extras (`Ep2Extras.SHARPS/GATLING`); the main pack is untouched. Where the extras are absent nothing breaks (post/intro are skipped).
- Dialogue is timed text; the period facts are: Sharps Model 1874 falling-block, 30 in octagon barrel, double set triggers, tang sight; Colt-built Gatling, six barrels, drum, hand crank, Dr Gatling's patent. No protocol numbers, no yields.

## Rebuild
```
blender -b --factory-startup -P tools/ep2_blender/build_sharps_gatling.py -- --dir src/episode2/extras/armory --shots <dir>   # both guns + review renders
blender -b --factory-startup -P tools/ep2_blender/build_armory2.py -- --out src/episode2/extras/armory/armory2.glb          # the case rifle
# Rich/Utah (sources in the scratchpad: rich_prep.blend / utah_prep.blend from prep_folk.py)
blender -b rich_prep.blend --factory-startup -P tools/ep2_motion/strip_props.py -- --out rich_clean.blend --hands hand_l
blender -b rich_clean.blend --factory-startup -P tools/ep2_motion/retarget_bvh.py -- --spec tools/ep2_motion/clips_folk.json --bvh-dir ~/tools/mocap/cmu --out rich_anim.blend
blender -b rich_anim.blend --factory-startup -P tools/ep2_motion/export_folk.py -- --out src/episode2/extras/folk/rich_armory2.glb
```
Then import with the PINNED 4.3 binary twice (`.godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --import`), `git add -f` the new `.import` files, revert 4.7 `.import` noise.

## Traps found
- `strip_props.py`: Rich's pickaxe is skinned to the FINGER groups (pinky_03_l ...), not the hand bone; a sphere cut for the nugget eats the fingers (kept: the nugget stays in his right hand).
- A mocap clip's hand is not mapped (retarget): prop orientation is tuned per clip by eye - hold clips: `InspectRifle` (muzzle up, reads as presenting).
- `--check-only` fails on autoload names (GameManager); run the test scenes instead. 4.7 prints a harmless `VirtualJoystick hides a native class`.
- Mount: the player's collision circle at the post is 0.72 m; the stand is 1.0 m behind the axis - `[E]` works from `MOUNT_R` = 2.6 m and teleports him onto the stand.
