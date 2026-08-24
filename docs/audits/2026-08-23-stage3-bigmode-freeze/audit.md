# Audit — Stage 3 "frozen after big mode, music continues" (2026-08-23, P0)

**Founder (2nd occurrence)**: "After getting into big mode on Stage 3 the game is
completely frozen while the music continues."

## Root cause — a stranded global `Engine.time_scale`

The hitstop juice sets the **global** `Engine.time_scale = 0.05` and restores
`1.0` only on the line **after** an `await`:

- `player.gd::_hitstop()` — `Engine.time_scale = 0.05` → `await` a 0.06s timer → `= 1.0`
- `axe.gd::_boss_hitstop()` — same pattern

On Stage 3 any boss touch is `GameManager.boss_contact_restart()`, which reloads
the level through `SceneRouter.load_scene`. If a hit lands (hitstop starts) and
contact fires within that ~0.06s window, the player/axe node is **freed
mid-await**, its restore line never runs, and `Engine.time_scale` stays pinned
at 0.05. It is a global on the Engine, so it **survives the reload**: the fresh
scene runs `_physics_process`/`_process` at 5% while the audio server
(unaffected by `time_scale`) plays at full rate — exactly "frozen, but the music
continues". Intermittent ("2nd time") because it needs the hitstop-during-contact
race.

Corroborating evidence already in the tree: `blaze_rush.gd` has two comments
explicitly defending its own timers against "a stuck `Engine.time_scale`" — the
team was working around this symptom without fixing the root cause.

## Why it's `time_scale`, not a paused tree (DeepSeek's #1)

DeepSeek's dispatch ranked "paused tree never cleared" as most likely and argued
a hung `await` "does not freeze the main thread". Both points were checked:

- **Paused tree is already handled.** `load_scene` calls
  `StateMachine.change_state(TRANSITIONING)`, and `state_machine.gd` sets
  `get_tree().paused = (state == State.PAUSED)` — so a transition already clears
  any stranded pause. (An explicit `get_tree().paused = false` was still added
  next to the time_scale reset to make the invariant self-documenting.)
- **The await reasoning missed the nuance.** A hung coroutine alone doesn't
  freeze the thread — correct. But here the global `time_scale` is set *before*
  the await, so a freed node doesn't "hang the thread", it **strands a global
  that then throttles the whole next scene**. That is the measured mechanism.

## Fix

1. `SceneRouter.load_scene` resets `Engine.time_scale = 1.0` (and `paused =
   false`) as its first act — every transition/respawn/boss-restart passes
   through here, so a stranded hitstop self-heals on the next load and can never
   persist into a new scene. Also stops the fade timer (not `ignore_time_scale`)
   running at 5% and stretching 0.3s into 6s.
2. `level_base._ready()` resets `time_scale = 1.0` (belt-and-braces for any
   scene entered outside `load_scene`, e.g. first boot).
3. `player.gd::_hitstop` and `axe.gd::_boss_hitstop` now restore off the
   tree-owned SceneTreeTimer's `timeout` signal instead of the coroutine resume,
   so the restore fires even if the node is freed — the strand is prevented at
   source, not only healed after.

## Proof

`tests/time_scale_recovers_on_scene_load_test.gd` reproduces the exact stranded
state (`time_scale = 0.05`) then calls `SceneRouter.load_scene` and asserts
recovery to `1.0`. **Verified to FAIL without the fix** (stays 0.050) and pass
with it. Player/axe/boss gates (stage3_defence, claim_jumper_pressure,
auditor_full_stage_hunt, blaze_lifecycle_e2e) still pass.

Model: DeepSeek v4 (soft-lock trace — right about the class, corrected on the
specific global; see above).
