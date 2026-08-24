# DeepSeek — SOFT-LOCK TRACE ONLY. Godot 4.3. No code changes.

Symptom (founder, live web/itch build, 2nd occurrence): on STAGE 3 (Claim
Jumper gold-mine arena), after entering "big mode" (a scale/Blaze-related large
form; HUD shows "BIG MODE"/"PURPLE POWER"/"Blaze Rush"), the ENTIRE GAME
FREEZES — no input, no movement, no physics — but the MUSIC KEEPS PLAYING.

In Godot 4, audio runs on its own thread, so "music continues, everything else
frozen" means the MAIN THREAD is blocked: either an infinite loop / unresolved
`await` on the main thread, or `get_tree().paused = true` with no unpause path,
or `set_physics_process(false)` with no restore.

Known code facts:
- Big mode = GameManager power-up "big"; player_up_handler._update_scale() sets
  player.scale = 1.5. No await/tween/pause there.
- get_tree().paused = true is set by: companion_panel, crypto_onboarding,
  lore_panel, oracle_panel, state_machine (State.PAUSED). Each has an unpause
  path EXCEPT possibly one that can be opened but whose close is gated.
- Stage 3 boss contact = GameManager.boss_contact_restart() = full run reset
  (reloads level). If that fires DURING a scale change or a modal, ordering
  could strand a paused tree.
- "Blaze Rush" is a secret bonus mode with its own enter/exit lifecycle that
  must return the player to the originating level+position.

## Deliver (conceptual, no repo access needed — reason from the patterns):
1. Rank the 4 mechanisms (infinite loop / await-never-resolves / paused-never-
   cleared / physics-disabled-never-restored) by likelihood for "music on, sim
   off, triggered by entering big mode on stage 3, intermittent (2nd time)".
2. For a paused-tree cause: what sequence (open a pause-triggering panel, then a
   scene reload / boss restart / state change fires) could leave paused=true
   with the closing node freed before it clears the pause? Name the ordering.
3. For an await cause: what `await tween.finished` / `await timer.timeout` on a
   scale or transform, if the node is freed or the tween killed mid-transform
   (e.g. boss_contact_restart reloads the scene during the grow tween), hangs
   the awaiting coroutine forever? Is that a freeze or just a dropped coroutine?
4. Give the 6-line checklist to instrument to catch it in a headless repro
   (what to read each frame: get_tree().paused, player.can_process(),
   Engine.time_scale, player.global_position delta, is_instance_valid checks).
