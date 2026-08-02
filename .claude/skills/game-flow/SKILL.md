---
name: game-flow
description: "Improve game flow for Lil Blunt: The Smoke Realm (Godot 4.3 GDScript platformer). Use when asked to enhance state transitions, level progression, menu systems, scene routing, pause/resume, game over/restart loops, or player onboarding. Covers the StateMachine, SceneRouter, level sequence, victory/defeat flow, and UX polish."
license: MIT
compatibility: "Godot 4.3+ with GDScript. Non-threaded HTML5 web export. Works with existing autoload architecture."
metadata:
  version: '1.0'
  author: Young Stunners
  game: "Lil Blunt: The Smoke Realm"
---

# Game Flow

## Founder overrides (2026-08)

These three rules were fixed and proven end-to-end on 2026-08-08 after the
founder reported the game-flow defaults below (Continue → highest_unlocked_level,
full wipe → main menu) as live bugs. **They override anything below that
contradicts them — do not re-derive the old behavior from first principles:**

- **Blaze Rush finish or ESC** → return to the **entry stage** (the level the
  player was on when they entered via the portal), never forced to Level 1,
  never a full game reboot. Both paths share one function
  (`_exit_to_level()` in `blaze_rush.gd`) so they cannot drift apart again.
- **Full life wipe** (`lives` hits 0) → restart at the **beginning of the
  current level** (e.g. a wipe on Level 2 restarts Level 2), NOT the
  mid-level checkpoint where the last life was lost, and NOT the main menu.
- **Checkpoint respawn** only applies when a death happens and **lives
  remain** afterward. A death that empties `lives` to 0 always uses the
  full-wipe rule above instead, regardless of how close a checkpoint is.

See `docs/session-logs/2026-08-08b-blaze-rush-e2e-and-wipe.md` for the
end-to-end proof method (real SceneRouter + real handlers, not a data check).

## When to Use This Skill

Use when the user asks to:
- Fix or improve state transitions (menu → playing → paused → game over → etc.)
- Modify level progression, level select, or continue flow
- Improve menu systems (main menu, pause, victory, settings)
- Fix scene loading or transition issues
- Improve the game over → restart loop
- Add or modify onboarding flows
- Fix soft-locks or state machine dead-ends
- Improve pacing between levels or boss fights

## State Machine

### Architecture (`src/autoload/state_machine.gd`):
The `StateMachine` autoload is the single source of truth for game state. It replaces scattered booleans (is_dead, boss_spawned, game_over) with a centralized enum.

```gdscript
enum State { MENU, PLAYING, PAUSED, GAME_OVER, LEVEL_COMPLETE, TRANSITIONING }
```

### Allowed Transitions:
```
MENU          → TRANSITIONING
PLAYING       → PAUSED, GAME_OVER, LEVEL_COMPLETE, TRANSITIONING
PAUSED        → PLAYING, TRANSITIONING
GAME_OVER     → PLAYING, TRANSITIONING
LEVEL_COMPLETE → TRANSITIONING
TRANSITIONING → MENU, PLAYING, GAME_OVER, LEVEL_COMPLETE
```

### Key Rules:
1. **Same-state transitions are rejected** — `change_state()` returns false if `from == to`
2. **Invalid transitions log a warning** and return false — never silently pass
3. **PAUSED is the only state that pauses the tree** — `_apply_side_effects()` sets `get_tree().paused`
4. **Recovery hatch**: `recover_from_transition()` reverts to `_previous` if stuck in TRANSITIONING (for failed scene loads)
5. **Web beacon**: every state change posts `{type:"state", value:<name>}` to the parent page via `postMessage` — powers the browser-verify gate

### Common Flow Bugs to Avoid:
1. **Death during LEVEL_COMPLETE**: `Player.take_damage()` guards with `if not StateMachine.is_playing(): return` — this prevents dying during the victory window from wedging the state machine
2. **Double MENU enter**: `MENU → MENU` warning on boot is the guard doing its job (cosmetic, pre-existing)
3. **Boss victory → death race**: `Player.die()` checks `if not StateMachine.change_state(StateMachine.State.GAME_OVER): return` — if the boss just won (LEVEL_COMPLETE), the death sequence is skipped
4. **Transition stuck**: if a scene fails to load, `SceneRouter` should call `StateMachine.recover_from_transition()`

## Scene Router

### Architecture (`src/autoload/scene_router.gd`):
`SceneRouter` handles all scene changes with transition effects.

### API:
- `SceneRouter.load_scene(path, transition)` — load a scene with a visual transition
- `SceneRouter.Transition.FADE` — fade to black and back
- Transitions use `SceneTransition` autoload for the visual effect

### Scene Flow:
```
main_menu.tscn → level_01_smoke_realm.tscn → [boss fight] → victory_screen.tscn
                                                         → level_02_crystal_caverns.tscn → ...
                                                         → level_03_gold_rush.tscn → ...
                                                         → game_complete
```

### Level Sequence (`GameManager.LEVEL_SEQUENCE`):
```gdscript
const LEVEL_SEQUENCE: Array[String] = [
    "res://src/level/level_01_smoke_realm.tscn",
    "res://src/level/level_02_crystal_caverns.tscn",
    "res://src/level/level_03_gold_rush.tscn",
]
```

### Progression:
- `GameManager.next_level_scene(cleared_level_index)` — returns the next scene path or MENU_SCENE
- `GameManager.highest_unlocked_level` — persisted, gates Continue and level select
- `GameManager.mark_level_completed(level_index)` — idempotent, appends to progression_state
- Completing all 3 levels unlocks the shooter mode (`progression_state["shooter_unlocked"]`)

## Level Lifecycle

### LevelBase._ready() Flow:
1. Record `level_start_ms` for pacing metrics
2. Connect `DifficultyManager.tuning_ready` (one-shot) for adaptive difficulty
3. Connect boss trigger Area2D
4. `_setup_background()` — parallax art
5. `_setup_geometry()` — platforms and ground
6. `_setup_parallax()` — fallback color bands (skipped if painted backdrop exists)
7. `_setup_kill_zone()` — pit death detection
8. `_setup_entities()` — spawn enemies, collectibles, power-ups, checkpoints, mine carts
9. `_setup_boss_arena()` — arena walls
10. `_spawn_player()` — at checkpoint or spawn point
11. `_setup_hud()` — pause menu
12. `_apply_token_perks()` — wallet-gated bonuses
13. `StateMachine.change_state(StateMachine.State.PLAYING)`

### Player Spawn Logic:
1. Check `GameManager.secret_return` — if returning from a secret realm, drop at the entry door
2. Check `GameManager.get_checkpoint(level_index)` — resume at last checkpoint
3. Fall back to `PlayerSpawn` marker
4. Fall back to `Vector2(100, 500)`

## Death and Respawn Flow

### Health Death (`Player.die()`):
**State ownership lives entirely in `Player.die()`** (2026-08-08 fix) — it no
longer races `GameManager.take_damage()` for who sets GAME_OVER. The old
order (GameManager set the state, then `die()` checked `is_dead()` and bailed
immediately) meant the respawn sequence never ran at all — a full freeze.
Never reintroduce a `StateMachine.change_state(GAME_OVER)` call from
`GameManager.take_damage()`.
1. Guard: `if _dying: return` — prevents re-entry from multiple lethal hits in one frame
2. Take GAME_OVER here (refused only if the boss just won LEVEL_COMPLETE — abort, don't wedge the SM)
3. Attribute death to boss or enemy via `Web3Bridge.report_event("death", ...)`
4. Play death animation (scale to zero + fade)
5. Both health death and pit death route through one shared
   `Player._respawn_or_game_over()` — see Founder overrides above and Pit
   Death below. There is no more "no checkpoint → reload_current_scene()"
   branch; the full-wipe rule replaced it.

### Pit Death (`Player.pit_death()`):
1. Guard: `if StateMachine.is_dead() or _dying: return`
2. Play fall sound + heavy screen shake
3. Report pit death metric
4. Routes into the same `_respawn_or_game_over()` health death uses (see
   Founder overrides above) — pit and health death cannot diverge.
5. If lives remain after this death: respawn at the level's checkpoint with invincibility (1.5s)
6. **If this was the LAST life (full wipe)**: `GameManager.clear_checkpoint(current_level)`
   + `GameManager.refill_run()` (lives/health back to max) + reload the
   CURRENT level from its start via `SceneRouter.load_scene(GameManager.level_scene(current_level))`.
   NOT the main menu, NOT the mid-level checkpoint.

### Lives System:
- `GameManager.lives` starts at 3 (max 3)
- Pit falls AND health deaths both cost a life via the shared respawn helper
- **Out of lives = restart the CURRENT level from its start marker** (checkpoint
  cleared first) — see Founder overrides. This is NOT "to main menu."
- Lives persist in save file (reloading mid-run does NOT refill); a full wipe
  explicitly refills them for the fresh level attempt.

## Boss Victory Flow

1. Boss `take_damage()` reduces HP
2. On HP 0: `BossBase.die()` → `EnemyBase.die()` → `queue_free()`
3. Boss scene/subclass should: `StateMachine.change_state(StateMachine.State.LEVEL_COMPLETE)`
4. `GameManager.mark_level_completed(level_index)`
5. `GameManager.mark_boss_defeated(boss_id)`
6. Show victory screen (score, badge claim, share)
7. Victory screen → `GameManager.next_level_scene()` or main menu

### Critical: Boss Transition Guard
Boss death and player death can race. The guards in `Player.die()` and `Player.take_damage()` ensure that if the boss wins first, the player's death is suppressed. Never remove these guards.

## Menu Systems

### Main Menu (`src/ui/main_menu.gd`):
- Play (new game — resets session)
- Continue (loads save — resumes `current_level`, the LAST level actually played; NOT `highest_unlocked_level`, see Founder overrides)
- Quit
- Wallet Connect button
- Social links (X, Telegram)
- "NEW TO CRYPTO?" onboarding screen

### Pause Menu (`src/ui/pause_menu.gd`):
- Resume → `StateMachine.change_state(StateMachine.State.PLAYING)`
- Restart → reload current scene
- Quit → main menu
- Created by `LevelBase._setup_hud()` — added as child of the level scene
- Pause only freezes the tree in PAUSED state (process_mode = PROCESS_MODE_ALWAYS on autoloads)

## Transition Effects

### SceneTransition (`src/autoload/scene_transition.tscn`):
- Fade transitions between scenes
- Uses a shader wipe (`src/effects/transition_wipe.gdshader`) for themed transitions
- SMOKE (green) and DIAMOND (cyan) color variants

### Improvement Opportunities:
1. **Add transition variety** — different wipe directions, shapes, or patterns per level theme
2. **Transition speed tuning** — current fades should be 0.3-0.5s (not jarring, not slow)
3. **Loading indicator** — show a spinner or progress bar during heavy scene loads
4. **Boss intro transition** — dramatic zoom or flash when entering boss arena
5. **Level intro card** — show level name + subtitle for 2s before play starts

## Onboarding Flow

### Current:
- "NEW TO CRYPTO?" screen with privacy copy + Learn More modal
- Analytics events for viewed/clicked/dismissed
- No tutorial for game mechanics

### Improvements:
1. **First-time player tutorial** — teach movement (jump, double-jump, dash) in Level 1
2. **Contextual hints** — "Press SPACE to jump" prompts near gaps on first play
3. **Power-up introduction** — first pickup of each type shows a brief tooltip
4. **Boss intro cards** — show boss name + silhouette before the fight starts

## Pacing Guidelines

1. **Level length**: 3-5 minutes per level for a first-time player
2. **Checkpoint spacing**: every 30-45 seconds of expected play
3. **Boss fight length**: 2-4 minutes for a skilled player, 4-6 for a new player
4. **Power-up frequency**: at least 2 per level, placed before challenges that benefit
5. **Breather moments**: after intense sections, include a safe area to collect coins
6. **Difficulty curve**: Level 1 teaches mechanics, Level 2 combines them, Level 3 challenges mastery

## Game Flow Checklist

Before shipping flow changes:
- [ ] All StateMachine transitions are in the allowed list
- [ ] No soft-locks: every state has a path back to MENU or PLAYING
- [ ] Scene transitions use SceneRouter (not raw `get_tree().change_scene()`)
- [ ] Pause menu appears in every level
- [ ] Checkpoints save correctly and respawn the player at the right position
- [ ] Pit death AND health death both cost a life via `_respawn_or_game_over()`
- [ ] Out of lives → restart CURRENT level from its start marker (checkpoint cleared, lives refilled) — NOT main menu
- [ ] Victory screen shows after boss defeat, not before
- [ ] Continue from save resumes `current_level` (last level played), not `highest_unlocked_level`
- [ ] Blaze Rush finish and ESC both return to the entry stage via `_exit_to_level()`
- [ ] Secret realm return places player at the entry door
