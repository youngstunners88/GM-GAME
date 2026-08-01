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
