# Kimi packet: the Colt Gatling must hit what Lil Blunt aims at, and sound intense

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter). Claude reviews your files, runs the
gates and commits them; write production code, not sketches.

## Founder's words (2026-10-27)
"When I use the gatlin gun it doesnt hit any of the targets and it doesnt sound intense enough."
Fix-pack item: "Gatling: must register hits on test targets; SFX more intense."

## What exists (read the included files)
- `src/episode2/actors/ep2_gatling_post.gd` (`Ep2GatlingPost`): a Gatling on a post in the Armory yard. Rounds are hitscan
  (`_shoot_one` -> `_trace` from `muzzle_position()` along `bore_dir()` with SPREAD) against swinging plates (disc radius
  PLATE_RADIUS 0.27 at PLATE_CENTRE under each plate's swing pivot) and bales. Aim: `aim_delta`, `set_aim`, `aim_toward`, clamped arc.
  `eye_position()` is the gunner's eye, above and behind the breech.
- `src/episode2/chamber/gold_town.gd` mounted mode (around `_mount`, `_unmount`, `look`, `_update_camera`, `shoot`): when the player
  is at the crank (`_mounted`), mouse look drives `_gatling.aim_delta(relative)` and the chamber's `_look_yaw/_look_pitch` copy the
  bore's. The plates come from `Ep2GoldTown.GATLING_PLATES` / `GATLING_BALES` (17-36 m out), placed facing the post.
- `tests/ep2_armory_guns_test.gd` proves Utah's DEMONSTRATION rings a plate - but Utah aims the BORE itself (`aim_toward`).
- Likely cause (verify, do not assume): the player's crosshair is the camera ray from the gunner's eye, while rounds leave the
  muzzle along a parallel bore line. With the crosshair on a plate the rounds pass a fixed offset below/beside it (eye-muzzle
  offset) - larger than the 0.27 m plate at 17-31 m. Check what the mounted camera actually does in `_update_camera`.

## Build
1. **Failing test first**: new `tests/ep2_gatling_hits_test.gd` + `.tscn` (root Node, script attached; print
   `EP2_GATLING_HITS: ALL PASS` or `EP2_GATLING_HITS: N FAILURE(S)` and `get_tree().quit(failures)`). Build the real town chamber
   the way `tests/ep2_armory_guns_test.gd` does, get to the mounted state the way a player does (or `_mount()`), then for each plate
   put the PLAYER'S crosshair on the plate centre the way mouse look would (drive the same code path the mouse uses, then read the
   camera's ray), fire a burst through `shoot()` and step the chamber. Assert every plate that is inside the gun's arc rings
   (`targets[i]["hits"] > 0`). Report in your notes whether this failed on the code as given.
2. **Fix** so a plate under the crosshair is hit: rounds converge on the point under the crosshair (trace the camera/eye ray first to
   find the aim point - plate, bale or ground - then fire from the muzzle toward that point), or make the eye ray and the bore the same
   line. Keep SPREAD small but present; Utah's demo and the arc clamp must keep working.
3. **Intensity** (new recordings are already in the repo, streamed with the extras pack - load them only when
   `ResourceLoader.exists(path)`, otherwise keep the current revolver blasts):
   - per round: one of `res://src/episode2/extras/audio/town/gatling_shot_a.ogg`, `_b`, `_c` at random, pitch 0.92-1.06, overlapping
     (a small pool of 4-6 `AudioStreamPlayer3D` or one `AudioStreamPolyphonic`), about +3 dB over the current shot;
   - while the barrels spin: `gatling_crank_loop.ogg` looping, volume following `spin / SPIN_MAX`;
   - when a burst of 6+ rounds ends: `gatling_tail.ogg` once;
   - a short camera kick per round while mounted if the chamber has a hook for it (do not add a new shake system).
4. Keep `tests/ep2_armory_guns_test.gd` passing unchanged unless an assertion is truly about the old behaviour (then say why).

## Rules
GDScript for Godot 4.3: tabs, typed variables, `##` doc comments on public functions, no new autoloads, no `class_name` clashes,
nothing that needs the Forward+ renderer (the web build is Compatibility: no Decals, no SSAO). Only write the allowed files. Answer
with whole files in the required format, then a short note: the cause you found, what the test showed before and after.

@include src/episode2/actors/ep2_gatling_post.gd
@include src/episode2/chamber/gold_town.gd
@include src/episode2/chamber/interlude_base.gd
@include src/episode2/chamber/ep2_gold_town.gd
@include tests/ep2_armory_guns_test.gd
@include tests/ep2_armory_guns_test.tscn
