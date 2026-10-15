# Src Workspace (the Godot 4.3 game)

Everything the web build loads. Coding standards are in `src/CLAUDE.md`; the file map for a task is in
`.claude/context-manifests/default.md` (+ `shooter.md` for Episode 2). Read those, not the whole tree. (Workspace pattern: founder's
coach, "The Lesson 3.1"; kept current by skill `context-md-upkeep`.)

## Shape of the game
- Episodes 1 (2-D platformer: Smoke Realm, Blaze, Gold Rush) and Episode 2 (FIRST-PERSON shooter: runner -> cliff film -> hideout
  range -> mine lift -> bear woods -> quad -> spy point). Keep the equipped firearm in first person; personal armory rules are in `CLAUDE.md`.
- Episode 2 story rooms extend `Ep2Interlude` (`src/episode2/chamber/interlude_base.gd`): viewmodel, HUD, beats, `step(delta)`
  (deterministic; tests and capture rigs drive it). New per-room systems are stepped from the room's `_tick`, never `_process`.

## Touch controls (Episode 1, phones + tablets)
Analog stick + thumb buttons live in `src/input/mobile/` and reach gameplay only as InputMap actions (`TouchActions`).
Autoload `MobileLayoutManager` decides when they show (touch device, PLAYING, a platformer `Player` or group
`touch_controls_wanted`). Skill `gm-game-mobile-touch-experience`; gate `tests/mobile_touch_controls_test.tscn`;
browser check `scripts/touch-playtest.mjs`. Episode 2 first-person rooms do NOT opt in (they need a look-stick).

## Where things are (Episode 2)
| what | file |
|---|---|
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
