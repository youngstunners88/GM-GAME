---
name: ep2-bear-design
description: Design an Episode 2 bear enemy end to end — its ROLE in the level (the verb it forces), silhouette and signature prop (bow, shovel, ...), three-stage telegraph (see / hear / feel), voice (growl, attack, death groan), placement, sim rule, and the tests that prove the player's only answer works. TRIGGER when the founder asks for a new bear, bear behaviour, "bears with shovels", bears that block or attack, bear sounds, a zipline/hazard puzzle built around bears, or a bear looks generic or unreadable.
---

# Episode 2 bear design

Founder, 2026-09-30: "the bears should have shovels ready to smack Lil Blunt", "a row of bears and jumping on the
zipline becomes the ONLY solution", "bears express their death groans when shot and their growls when they attack".

## 1. Start from the VERB, not the model
A bear exists to force one decision. Write it as `hazard -> the only answer`, then build the look around it.

| Bear | Forces | Answer | Sim | View / audio |
|---|---|---|---|---|
| **Archer** (ledge, bow drawn) | duck or shoot | DUCK / SHOOT | obstacle `arrow` + `archers[]` | static "Mine Bear Archer" statue tracks the cart; creak windup, attack growl, death groan |
| **Boarder** (leaps into the cart) | swipe | PICKAXE | obstacle `boarder` | rigged bear, `leap`/`stomp`/`flinch` clips |
| **Shovel line** (row of 3, one per rail) | leave the rails | **ZIPLINE** (nothing else) | obstacle `shovels` x3 lanes, `_is_cleared -> _ziplining` | rigged bears on the ties, procedural shovel, alert/growl/swing/smack |
| _next ideas_ | | | | Foreman (boss), Lantern-bear (blinds), Tunnel-digger (rail gap) — pick a verb first |

Rule: an answer nobody else can give. If jumping, ducking or hopping also clears it, the zipline (or the pickaxe) has no
purpose. The gate proves it: `ep2_runner_carts_test::_shovels` (plain rails hit, jump hit, zipline untouched).

## 2. Silhouette and prop (readable at 20 m in a dark tunnel)
- One signature prop per role, larger than life: shovel = 1.9 m timber handle + 0.5x0.62 m steel blade + brass collar, raised behind
  the shoulder. Props are procedural (`_build_shovel_bears`) or Meshy; never bake a weapon into a rigged clip.
- Bears share the rigged Mine Bear (helmet, lamp, red bandana). Differentiate by prop + stance, not by re-modelling.
- Bear height 2.6-2.7 m so the row reads as a wall next to a 1.9 m hero; zipline cable clears them (5.85 m).

## 3. Three-stage telegraph (every bear, every time)
1. **See** - label ("BEAR LINE - JUMP TO THE ZIPLINE!"), shovels quiver overhead inside `SHOVEL_WINDUP` 16 m, swing down inside `SHOVEL_SWING` 7 m.
2. **Hear** - Lil Blunt's alert line at 34 m (`shovel_alert`), attack growl at 18 m, swing whoosh at 7.5 m.
3. **Feel** - smack + hit reaction (`ep2_shovel_smack`, `hit` bark, camera shake) if it lands; taunt (`shovel_pass`) if he flies over.

## 4. Voice (ElevenLabs sfx, ids in `assets/ep2-voice-bank.json` -> `tools/ep2_voice/build_bank.py --generate`)
`ep2_bear_growl_1-3` (idle, distance-scaled), `ep2_bear_attack_1-3` (when attacking: archer loose, shovel row), `ep2_bear_death_1-3`
(groan when shot), `ep2_bear_roar` (first sight), `ep2_bow_creak` (windup), `ep2_shovel_swing`, `ep2_shovel_smack`.
3D `AudioStreamPlayer3D` at the bear, louder as the cart closes in (`RunnerVoice.bear_db`). Three takes per sound so no two bears
sound the same in a row. Nobody here can hear: judge by the founder's ear, regenerate one id with `--force <id>`.

## 5. Placement
- Rows go INSIDE a zipline segment (`shovels` z within `zip_segments[i].start_z..end_z`), with >= 40 m of clear track before it
  and the previous hazard already resolved, so the player has time to jump for the cable (`ZIP_CATCH_MIN_Y`).
- Shipped rows: Descent z=452 (cable 430-470), Deeper z=880 (cable 860-900).
- One pressure source at a time: no arrow volley or boulder within 40 m of a shovel row.

## 6. Checklist before shipping a new bear
1. Verb + only-answer written (table row above). 2. Sim rule + `Episode2Tracks` data. 3. View build/update with the 3-stage
telegraph. 4. Sounds generated + wired in `RunnerVoice` + covered by `ep2_runner_voice_test`. 5. Solvability: the autopilot must
still clear every leg (`ep2_runner_carts_test`). 6. Capture from the game camera AND a `cam=` close-up
(`bash tools/ep2_shots/shoot.sh out 0 44 700,300 shovels "" 0,4.5,0,0,1.0,14`). 7. STATUS.md entry.
