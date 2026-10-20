---
name: ep2-townfolk-presence
description: Verify the Episode 2 town people, Rich and Utah, the jailhouse and Logan's Lake are spawned, wired into the player flow and present in the exported packs - with the headless gates that fail CI when one is missing. TRIGGER on "town people are absent", "Rich and Utah are puppets", "lake is missing/unreachable", "Gail house", before claiming any town cast or lake work is live.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash
---

# Town cast and lake presence

| Thing | Source of truth | Spawned by | Streamed file(s) | Gate |
|---|---|---|---|---|
| Five townspeople | `src/episode2/actors/ep2_town_people.gd` `ROSTER` | `Ep2TownPeople.build` from `GoldTown` | `extras/people/townsman_*.glb`, `townswoman_*.glb` | `tests/ep2_town_people_test.tscn` (`EP2_TOWN_PEOPLE: ALL PASS`) |
| Real windows/doors | `Ep2Extras.TOWN_KIT` | `Ep2GoldTown` picks `town_kit2` when `Ep2Extras.has()` | `extras/town/town_kit2.glb` | same test (rays through openings) |
| Rich & Utah (Blender-authored, rigged, mocap clips) | `Ep2Extras.RICH/UTAH`; old puppets `RICH_MODEL/UTAH_MODEL` in `gold_town.gd` are the FALLBACK | `GoldTown` (`armory_v2` and both extras present) | `extras/folk/rich_armory2.glb`, `utah_armory2.glb` | `tests/ep2_armory_two_story_test.tscn` |
| Jail + accomplice | `Ep2Extras.JAIL/PRISONER` | `Ep2GoldTown`, Beat.JAIL | `extras/jail/*`, `extras/people/prisoner_accomplice.glb` | `ep2_gold_town_test` |
| Logan's Lake | `src/episode2/chamber/logans_lake.gd/.tscn` | `Ep2SessionRoot.CHAMBER_SCENES["logans_lake"]`, reached from `gold_town` Beat.DONE `next_chamber` | `extras/lake/logan.glb` (+ textures) | `tests/ep2_logans_lake_test.tscn` |
| Jailhouse (the founder once wrote "Gail house" - it is the JAILHOUSE) | `Ep2GoldTown` `Bldg_Jail`, `Ep2Extras.JAIL` | `Ep2GoldTown`; `GoldTown` Beat.JAIL_TIP/JAIL | `extras/jail/jailhouse.glb`, `sign_JAIL.png` | `check-ep2-extras-pack.sh` + `ep2_gold_town_test` |

## Verify in this order
1. `bash scripts/check-ep2-extras-pack.sh web/game` - every extras path is inside `ep2_extras.pck`; town + lake scenes inside `index.pck`; town->lake hand-off still wired. (CI step "Export game to Web".)
2. Headless engine: `godot --headless res://tests/ep2_town_people_test.tscn` / `ep2_armory_two_story_test.tscn` / `ep2_logans_lake_test.tscn` must print ALL PASS and no `[FAIL]`.
3. Live: `node scripts/live-itch-probe.mjs --expect <sha> --extras --logan` (build tag, extras ready, Logan 65 bones + 4 clips).
4. A picture: warp with `?ep2=1&ep2chamber=1` (town) or `&ep2chamber=lake` (needs the access code, `EP2_CODE`) and screenshot. A description of a screenshot is not a screenshot.

## Rich and Utah: what "still puppets" can mean
(a) the pack did not mount -> the fallback `rich_armory.glb`/`utah_armory.glb` shows (step 1 + 3); (b) the v2 bodies are shown but are not the founder's designs: v2 are Blender-authored from `design/ep2/armory/captures/utah_ref.jpg`; the higher-fidelity route is the "quality-character track" (SDXL reference -> Hunyuan3D on Runpod -> `rig_scan_character.py`, skill `ep2-mixamo-pipeline`), which costs GPU money and needs the founder's reference art and a go-ahead.
