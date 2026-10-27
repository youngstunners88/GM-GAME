# Kimi packet: the town feels alive - no backwards walking, a saloon that is never empty, drinkers with their own rhythm, people and horse sounds, bump reactions, a real train

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter, web export, Compatibility
renderer). Claude reviews every hunk, runs the gates and commits; write production code, not sketches.

## Founder's words (2026-10-27)
- "The people in the town are behaving strangely. They're walking backwards at times and being super random."
- "There should be people sitting in the bar so that its not empty."
- "The men who are drinking on the top of the bar have the exact same rhythm. This automatic vibe just kills the request of
  having them autonomous and they could be smoking and laughing."
- "We need more people sounds. The town is too dead at the moments. We need horse sounds to."
- "If Lil Blunt walks into a horse or anyone for that instance they should react. The horse could even kick Lil Blunt."
- "Also the sound of the train is trash!!! It sounds so fake."

## What exists (verified by Claude - read the included files)
- **Walking** - `Ep2TownFolk.step()` (`src/episode2/actors/ep2_town_folk.gd`): the body translates toward `_goal` at full speed at
  once, while `facing` lerps toward the move heading at 8/s and `rotation.y` lerps toward `facing` at 7/s. A new path leg that
  reverses direction is therefore walked backwards for ~0.5 s. Separately, `face_point()` / `face_yaw()` overwrite `facing` even
  while walking; `Ep2TownPeople` (`src/episode2/actors/ep2_town_people.gd`) calls `face_point` from many states (greeting,
  celebration, shopping, danger...). Any call made while a person walks turns the body away from its travel: sideways or
  backwards walking. Measure this first (see the gate) - do not assume these are the only causes.
- **"Super random"**: `_choose()` picks activities; check how often a walker turns around or re-targets mid-street without a
  reason (danger, a greeting, a shop queue). Measure, then damp it (minimum commitment to a chosen destination, no re-plan
  while a plan is progressing).
- **Saloon** - `Ep2GoldTown.saloon_seats()` (tables, bar rail, balcony rail); `BALCONY_REGULARS` ("grandfather", "oldtimer")
  are seated by `_seat_regulars()` at build, `_start_drinking()` holds one baked clip. The clip comes from
  `src/episode2/actors/ep2_drink_pose.gd`: `SitDrink` / `StandDrink`, ONE fixed `LOOP` of 6.4 s and fixed `BEATS` - every
  drinker sips on the same clock (both regulars start together): the founder's "exact same rhythm". Other people only visit
  the saloon now and then, so it is often empty.
- **Ambient audio** - `Ep2TownSoundscape` (`src/episode2/audio/town_soundscape.gd`: `town_wind`, `town_saloon` loops, greetings,
  the draw bell) and the train in `Ep2TownLife` (`src/episode2/chamber/ep2_town_life.gd`): `town_train_run.ogg` (SYNTHESIZED by
  a script - the "fake" sound) looping on the locomotive, `town_train_whistle.ogg` (also synthesized). The train crosses
  x 170 -> -230 at 7 m/s (~57 s), the track ~106 m from mid-street; it dips under speech via
  `AudioManager.is_speech_ducking()`. Horses: `HORSES` tied at hitch rails + one roaming horse (`_walker`), solid props.
- **New recordings** (streamed extras, already in the repo; load only when `ResourceLoader.exists(path)`, else keep today's
  behaviour) in `res://src/episode2/extras/audio/town/`:
  `town_people_loop.ogg` (16 s loop, street murmur), `saloon_laughter.ogg`, `bar_glasses_clink.ogg`, `man_laugh_a.ogg`,
  `man_laugh_b.ogg`, `woman_laugh.ogg`, `cigar_exhale.ogg`, `spurs_jingle.ogg`, `bump_grunt_m.ogg`, `bump_grunt_f.ogg`,
  `horse_whinny.ogg`, `horse_snort.ogg`, `horse_blow.ogg` (startled), `horse_kick.ogg`, `horse_hooves_loop.ogg`,
  `train_steam_loop.ogg` (20 s seamless distant steam run), `train_passby.ogg` (14 s close pass-by, NOT a loop),
  `train_whistle_steam.ogg` (5 s, two chime blasts).
- **The player** in the town is `GoldTownChamber` (`src/episode2/chamber/gold_town.gd`, extends `Ep2Interlude`): `_player_pos`,
  movement + `_collide()` (2D walls/props from `Ep2TownNavigation`), `_tick_people()` steps `_people` (Ep2TownPeople) and the
  town audio. The town has no hearts (`_shows_health()`); there is a view-kick hook (`_vm.cam_kick`).

## Build
1. **Walk forward, always.** In `Ep2TownFolk`: never translate while the body faces more than ~35 deg away from the travel
   direction - turn in place first (a quick, natural turn: ~300 deg/s cap, ease-out), then walk; while walking the travel
   heading owns the body. `face_point()` / `face_yaw()` called while walking set a pending look that applies when the person
   stops (keep their public signatures and their effect on a STANDING person exactly as today - story scenes rely on it).
   Armory folk use `use_height` (stairs) - keep that path working.
2. **Less random.** In `Ep2TownPeople`: a person keeps a chosen destination until it is reached or a real reason interrupts
   (danger, a greeting the player triggers, a reserved spot taken); no direction reversal mid-leg otherwise.
3. **The saloon is never empty, and nobody shares a clock.**
   - At least three people sit at saloon tables at any time while the town runs, plus the two balcony regulars. Use the
     roster's own people as "saloon regulars" (long stays, they leave and come back now and then; never a duplicated face).
   - `Ep2DrinkPose`: build per-person variants - loop length 5.0-8.5 s, sip timing, glass height - from a per-person seed;
     start each clip at a random phase; and add two more seated actions: **laugh** (lean back, head up, shoulders shake,
     a `man_laugh_*` / `woman_laugh` / `saloon_laughter` 3D sound at the person) and **smoke** (a small cigar prop in the
     free hand raised to the mouth, a soft grey CPUParticles3D puff on the exhale, `cigar_exhale.ogg` quietly). Each seated
     drinker cycles sip / idle / laugh / smoke at its own random timing (seeded, deterministic for tests). Glass clinks
     (`bar_glasses_clink.ogg`) now and then. Cigars are tobacco (period saloon), never weed.
4. **People and horse sounds** (all 3D, all dip under speech like the train does, none in the woods or other chambers):
   - the street bed `town_people_loop.ogg` around mid-street (quiet; it must not mask dialogue), the saloon bed + laughter and
     clinks inside the saloon;
   - occasional `spurs_jingle.ogg` on some walking men near the player (not every step);
   - every horse (hitch rails + the roaming one) snorts or whinnies now and then (12-30 s apart per horse, never two horses
     within 3 s), the roaming horse plays `horse_hooves_loop.ogg` while it walks.
5. **Bump reactions.** When Lil Blunt walks into a townsperson (his capsule reaches theirs, moving toward them), the person
   reacts once (cooldown ~4 s): stops, turns to him, plays an "Alert" or similar clip, `bump_grunt_m/f` by the person's sex
   (use the roster data; default male); they step aside. A horse walked into from the side or the front: `horse_blow.ogg`,
   it shies a step. Walked into from behind (rear 70 deg arc): it KICKS: `horse_kick.ogg`, Lil Blunt is knocked back ~1.5 m
   (through the chamber's movement/collision, never into a wall), a short view kick, no damage (the town has no hearts),
   cooldown ~6 s. Put the detection in a small new module (e.g. `src/episode2/actors/ep2_town_bumps.gd`, `class_name
   Ep2TownBumps`) and call it from `gold_town.gd` with at most two small hunks (build it, step it with the player's position
   and motion, apply the knockback). Do not touch the draw, the beats, the shop, the Gatling or the stable yard.
6. **The train sounds real.** In `Ep2TownLife`: the run loop is `train_steam_loop.ogg` (fallback: the old file); the whistle is
   `train_whistle_steam.ogg` (fallback: the old one); `train_passby.ogg` plays once per crossing, timed so the loudest part of
   the clip lands when the locomotive is closest to mid-street (find the loudest second of the clip at load time with
   `AudioStreamOggVorbis` length + a fixed offset you measure and document; a constant is fine). Keep the speech dip.
7. **Gate** `tests/ep2_town_feel_test.gd` + `.tscn` (root Node, script attached; print `EP2_TOWN_FEEL: ALL PASS` or
   `EP2_TOWN_FEEL: N FAILURE(S)`; `get_tree().quit(failures)`). Build the real town chamber the way `tests/ep2_town_autonomy_test`
   builds the people (read it), then:
   - simulate >= 5 town minutes; sample every walking person each frame: the angle between body forward (`rotation.y`, forward
     = (sin y, 0, cos y)) and actual displacement; FAIL if any sample with speed > 0.3 m/s exceeds 100 deg, or if fewer than
     98% of moving samples are within 35 deg. Print the measured numbers (also run it on the unfixed code and say in NOTES
     what it measured there);
   - count mid-leg reversals (> 150 deg change of travel heading between consecutive 1 s windows, no danger/greeting active):
     print per-person and total; FAIL above 1 per person per 5 minutes on average;
   - at minutes 1, 3 and 5: >= 3 people seated at saloon tables;
   - two drinkers' sip/laugh/smoke timelines differ (their clips are not phase-locked: compare the times of their first five
     "mouth" moments);
   - a bump into a person makes exactly one reaction within 0.3 s and none during the cooldown; a bump into a horse's rear
     kicks (player displaced >= 1 m, kick sound played when the stream exists); a front bump does not kick;
   - the train's run stream is `train_steam_loop.ogg` and the pass-by fires once per crossing near the closest point (+-15 m).
8. Keep `tests/ep2_town_people_test`, `tests/ep2_town_autonomy_test`, `tests/ep2_town_life_test`, `tests/ep2_town_audio_test` and
   `tests/ep2_gold_town_test` passing unchanged. If one asserts the old behaviour itself (e.g. an exact clip length), say which
   and why in NOTES instead of editing it.

## Rules
GDScript for Godot 4.3: typed variables, `##` doc comments on public functions, no new autoloads, no project.godot edits,
nothing that needs Forward+ (no Decals, no SSAO, no volumetric fog). Keep every existing public signature. Keep each file's
indentation (tabs). Never change dialogue text, voice ids or line ids. Change existing files only with exact SEARCH/REPLACE
edits; new files as whole files. Then a short NOTES line: the causes you measured, what changed per file, the gate's numbers
before and after.

@include src/episode2/actors/ep2_town_folk.gd
@include src/episode2/actors/ep2_town_people.gd
@include src/episode2/actors/ep2_drink_pose.gd
@include src/episode2/actors/ep2_town_navigation.gd
@include src/episode2/audio/town_soundscape.gd
@include src/episode2/chamber/ep2_town_life.gd
@include src/episode2/chamber/gold_town.gd
@include src/episode2/chamber/interlude_base.gd
@include tests/ep2_town_autonomy_test.gd
@include tests/ep2_town_life_test.gd
@include tests/ep2_town_audio_test.gd
