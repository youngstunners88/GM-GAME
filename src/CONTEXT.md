# Src Workspace (the Godot 4.3 game)

Everything the web build loads. Coding standards are in `src/CLAUDE.md`; the file map for a task is in
`.claude/context-manifests/default.md` (+ `shooter.md` for Episode 2). Read those, not the whole tree. (Workspace pattern: founder's
coach, "The Lesson 3.1"; kept current by skill `context-md-upkeep`.)

## Shape of the game
- Episodes 1 (2-D platformer: Smoke Realm, Blaze, Gold Rush) and Episode 2 (FIRST-PERSON shooter: runner -> cliff film -> hideout
  range -> mine lift -> bear woods -> quad -> spy point). Keep the equipped firearm in first person; personal armory rules are in `CLAUDE.md`.
- Episode 2 story rooms extend `Ep2Interlude` (`src/episode2/chamber/interlude_base.gd`): viewmodel, HUD, beats, `step(delta)`
  (deterministic; tests and capture rigs drive it). New per-room systems are stepped from the room's `_tick`, never `_process`.

## Touch controls (phones + tablets: Episode 1, Blaze Rush, Episode 2 Part 1)
Analog stick, thumb buttons and the finger-movement controls (tap field, swipe pad, look pad) live in `src/input/mobile/` and reach gameplay only as InputMap actions (`TouchActions`; the look pad's delta goes through `add_look`/`take_look`).
Autoload `MobileLayoutManager` decides when they show (touch device, PLAYING, a platformer `Player` or group `touch_controls_wanted`) and WHICH set: a node in that group answers `touch_profile()`
(`platformer`, `blaze`, `ep2_runner`, `ep2_foot`, `ep2_film`, `ep2_end`, `ep2_rotate`, `none`). Game UI that names a key is gated on `TouchUi.keys_shown()`; a phone shows no words.
Skills: `gm-game-mobile-touch-experience` (contract), `gm-game-blaze-rush-mobile`, `ep2-mobile-touch`, `gm-game-mobile-seamless-transitions`, `gm-game-touch-flow-verification`.
Gates: `tests/mobile_touch_controls_test.tscn`, `tests/touch_controls_profiles_test.tscn`, `tests/blaze_rush_touch_test.tscn`, `tests/ep2_touch_controls_test.tscn`; browser `scripts/touch-playtest.mjs`, `scripts/mobile-transition-probe.mjs`.

### Mobile pass 2026-10-23 - new files and where they live
| what | file |
|---|---|
| the one "is this a touch player" question | `src/input/mobile/touch_ui.gd` (`TouchUi.keys_shown()`) |
| tap field / swipe pad / look pad / rotate cue | `src/input/mobile/virtual_tap_field.gd`, `virtual_swipe_pad.gd`, `virtual_look_pad.gd`, `virtual_rotate_cue.gd` (+ `.tscn`) |
| the 18 profile layouts | `src/input/mobile/layouts/<profile>_<phone_landscape\|tablet_landscape\|phone_portrait>.tscn` (registered in `PROFILE_SCENES`, NOT `LAYOUT_SCENES`) |
| Blaze pause card / tap cue / framing / rotate cue | `src/dashmode/blaze_pause.gd`, `blaze_tap_cue.gd`, `blaze_framing.gd`, `blaze_rotate_cue.gd` |
| Episode 2 pause card + portrait HOME icon | `src/episode2/ep2_touch_overlay.gd` (opened by `Ep2Entry`); profile source `Ep2SessionRoot.touch_profile()`, run-over profile `Ep2Entry.touch_profile()` |
| hand-off cover / card / freeze / abort | `src/autoload/transition_director.gd`; menu divert + `revealed` signal in `src/autoload/scene_router.gd` |
| return audio from Blaze | `AudioManager.release_music_override_faded`, `GameManager.side_return`, `LevelBase._start_stage_audio` |
| test-harness hooks (compiled out of the shipped build by the `gm_harness` feature tag) | `src/debug/harness_hooks.gd`; beacon in `src/autoload/debug_overlay.gd`; `GM_HARNESS=1 bash scripts/ep2-local-export.sh` |
| browser tooling | `scripts/lib/pw.mjs`, `scripts/cdp-touch-probe.mjs`, `scripts/mobile-transition-probe.mjs`, `scripts/check-harness-hooks.py` |
| founder's plain-words device checklist | `docs/MOBILE_TEST_STEPS_2026-10-23.md` |
Indentation is per file: `src/input/mobile/*`, `blaze_rush.gd`, `level_base.gd`, `transition_director.gd`, `ep2_entry.gd` use TABS; `scene_router.gd`, `audio_manager.gd`, `game_manager.gd`, `state_machine.gd`, `level_01_smoke_realm.gd`, `hud.gd` use 4 SPACES (a mixed file passes gdparse and fails the export).

## Where things are (Episode 2)
| what | file |
|---|---|
| Logan's Lake (town gear → staging → river overlook) | `src/episode2/chamber/logans_lake.gd`; active lock: `design/ep2/lake/LOGANS_LAKE_LOCK.md`; skill `ep2-logans-lake` |
| viewmodel rifle + hands | `src/episode2/chamber/ep2_view_hands.gd` (loads `assets/weapons/winchester_1886_founder.glb`) |
| mine lift | `src/episode2/chamber/mine_lift.gd` |
| bear woods (forest, wind, birds, mine exit, golden-hour grade) | `src/episode2/chamber/woods_quad.gd`, `ep2_wildlife.gd`, `art/ep2_foliage_wind.gdshader` |
| characters (Bull, bears) | `src/episode2/actors/` (`ep2_actor.gd`, `ep2_bear_arms_down.gd`) |
| movement / grip workflow | `.claude/skills/ep2-character-performance/SKILL.md` + `design/ep2/motion/CHARACTER_MOTION_CONTRACT.md`; separate guide timing, rig rest, prop contacts and whole-clip evidence |
| story arc rules | `.claude/skills/ep2-fort-knox-arc/SKILL.md` + `tests/ep2_fort_knox_arc_test.tscn` |

## Rules that bite
- Never touch the front-page-locked files (`scripts/front-page-lock.sh list`).
- Web export stays non-threaded. Compatibility renderer: no volumetric fog (fake haze with cards), keep MultiMesh for vegetation.
- Tests: `godot --headless --path . res://tests/<name>.tscn`; captures: `tools/ep2_shots/*` under `xvfb-run`.
- Ship every change: STATUS.md -> commit -> push -> `scripts/ship-to-master.sh` -> prove the itch deploy.
