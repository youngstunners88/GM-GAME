---
name: blaze-rush-lifecycle
description: Static audit of a Blaze-Rush-like secret mode's exit/finish lifecycle — must return the player to the ORIGINATING level+position, never a hardcoded default, and must always offer a visible exit. Run after any edit to a secret-mode exit/checkpoint path, or when a founder reports "finishing/exiting restarts the game."
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Blaze Rush Lifecycle Audit

**This is a static audit.** It reads code and reports; it does not fix.

## The defect that shipped (why this exists)

`blaze_rush.gd::_exit_to_level()` called
`GameManager.save_checkpoint(1, 990 + _level_index, portal_pos)` — the first
argument (`1`) is HARDCODED regardless of which level launched the run.
`save_checkpoint(level, id, pos)`'s first argument is the dictionary KEY that
`LevelBase._spawn_player()` looks up via `get_checkpoint(level_data.
level_index)`. Entering Blaze Rush from Level 2 or 3 silently wrote the
checkpoint into Level 1's slot — so on return the real level found nothing
under its own key and fell through to its default `player_spawn`, reading
exactly like "the game restarted." `gdparse` and a compile check both pass
this happily; it only shows up by actually playing the return path.

## Check 1 — Checkpoint slot matches the launch level

1. Find the exit/finish function (`_exit_to_level`, `_finish_run`, or
   equivalent).
2. Find every `GameManager.save_checkpoint(...)` call inside it.
3. Confirm the first argument is a variable holding the ACTUAL level index
   the run was launched from (e.g. `_level_index`, read from
   `GameManager.dash_return.get("level_index", ...)` at launch) — not a
   literal integer.
4. **FAIL** if the first argument is a hardcoded literal.

## Check 2 — Return path is the originating scene, not a default

1. Find where `return_path` (or equivalent) is read for the exit's
   `SceneRouter.load_scene(...)` call.
2. Confirm it comes from data captured at LAUNCH time (e.g.
   `GameManager.dash_return["scene_path"]`), not a fallback default used
   unconditionally.
3. A `.get(key, "default")` fallback is fine ONLY as a genuine safety net for
   a missing launch record — flag if the fallback is silently reachable in
   the normal finish/exit path (i.e. the launch-time write can be skipped or
   cleared before the read).

## Check 3 — Exit is always available, not just on finish

1. Confirm a visible, always-present exit control (button, ESC handler, or
   both) exists for the ENTIRE run, not only after completion.
2. **FAIL** if the only way out is finishing the course or a hard crash/game-
   over — a despondent player must not be trapped.

## Check 4 — End-to-end trace

Trace one full cycle by reading code only (no execution): portal entry →
launch data captured → run → finish/exit → checkpoint write → return scene
load → that scene's `_spawn_player()` checkpoint lookup. Confirm the KEY
written in the checkpoint save and the KEY read in `_spawn_player()` are
provably the same value on every code path, not just the common case.

## Check 5 — Audio resume on the way back (added 2026-10-23, mobile pass)

The exit must sound like the stage carried on, not like the game restarted. Before the fix `_exit_to_level` called `discard_music_override`: ~0.45 s of silence
under the wipe, then a shuffled track from 0:00 AND the 4-10 s `stageN_intro` voice line replayed on EVERY return.

1. In the normal exit path (`_exit_to_level`, reached by finish, Esc/Q, the pause card's EXIT and focus-out) confirm the music is handed back with
   `_release_music(true)` → `AudioManager.release_music_override_faded(token, MUSIC_RETURN_FADE_S)` (resumes the SAME paused stage player; rebuilds from the saved context if freed) —
   **not** `discard_music_override` / `release_music_override`.
2. Confirm `GameManager.side_return = {"kind": "blaze", "level": _level_index}` is set BEFORE `SceneRouter.load_scene(...)`, with the level index from launch data (never a literal).
3. In all three level scripts (`level_01_smoke_realm.gd`, `level_02_crystal_caverns.gd`, `level_03_gold_rush.gd`) confirm audio starts through `LevelBase._start_stage_audio(paths, voice, force_first)` and
   NOT a bare `AudioManager.play_playlist(...)` + `play_voice(...)`. `_start_stage_audio` must read AND clear `side_return` unconditionally (a stale flag must never suppress the next ordinary load),
   leave a playing stage track alone via `AudioManager.is_playing_playlist(paths)`, and never replay the intro voice on a matching return. **FAIL** if any level path still calls `play_playlist` on a Blaze return
   (that overlaps the resumed track with a fresh one: the founder's "faint second song").
4. Confirm `_exit_tree` keeps the safety net `_release_music()` (default `resume = false` = discard): a route that is NOT the exit has nobody setting `side_return`, and resuming then would create a ~0.8 s overlap.
5. Gate: `tests/level_return_audio_test` (`LEVEL_RETURN_AUDIO`, pins `GameManager` in memory, never `save_session`) and `tests/blaze_lifecycle_e2e_test`.

## Check 6 — Touch exit reaches the SAME path (added 2026-10-23)

A phone has no Esc/Q. Confirm every touch way out funnels into `_exit_to_level()` and nothing else: the pause card's EXIT (`BlazePause.exit_pressed` → `_on_card_exit`), the finish line's 1.2 s timer, and desktop Esc/Q/Backspace.
The written `TAP OUT (Q)` button must be hidden when `TouchUi.keys_shown()` is false, and an always-present exit must still exist on touch (the layout's Pause button → card → EXIT). **FAIL** if a touch-only route calls `SceneRouter.load_scene`
directly (it would skip the checkpoint write, `side_return` and the music resume) or if the run can be left without any visible control on a phone.

## Traps added by the mobile pass

- **`ColorRect` defaults to `mouse_filter = STOP`** in Godot 4.3: the floor band, the candles and the full-screen void rect swallowed taps before `_unhandled_input` (only the ~84 u HUD strip worked on a phone). `_let_taps_through()` fixes the tree once; `blaze_hud_mouse_filter_test` fails on any other STOP (only `BlazePauseField` is allowlisted).
- **`ScreenShake` on a freed camera never decays its duration**: a stale 0.2 s / 6 px request jolted the level on return. The dead call was removed from Blaze; do not re-add a shake without a valid camera.
- **The armed start (touch only)** holds the cube until `SceneRouter.revealed` (1.0 s safety timeout; the watchdog `change_scene_to_file` path never emits it) AND the first tap. Tests that instantiate `blaze_rush.tscn` directly must keep auto-running (`_armed` defaults true off touch).
- **Shared `user://save.json` pollution**: a checkpoint AT the portal (id 991 at 1450,250) and completed-Blaze flags send level tests into Blaze and hang. Fresh `XDG_DATA_HOME`; pin `GameManager` in memory.
- A silent coroutine death inside an awaited test prints `ALL PASS`: pin check counts and grep `SCRIPT ERROR` (see `gm-game-touch-flow-verification`).
- Portal burn is a founder rule (one Blaze run per stage until death/wipe): do not add a refund; the `990 + N` checkpoint is asserted by `blaze_lifecycle_e2e_test` and Check 1.

Full mobile design and gates: `gm-game-blaze-rush-mobile`.
