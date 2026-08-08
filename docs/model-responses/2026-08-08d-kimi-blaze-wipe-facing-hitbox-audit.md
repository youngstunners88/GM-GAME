<!-- dispatched: moonshotai/kimi-k3
     prompt: /tmp/claude-0/-home-user-GM-GAME/a77cc0d7-ba64-5875-85a6-fe6f7aa41b68/scratchpad/prompts/kimi-blaze-wipe-facing-hitbox-audit.md
     files inlined: 10
     tokens: 51089 in / 24000 out
     cost: $0.5133
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Blaze Rush L1/L3 entry contexts

**NO BUG FOUND — code is correct.** The chain is structurally identical to the proven L2 path for all three levels:

- `level_01_smoke_realm.gd:12` and `level_03_gold_rush.gd:8` pass hardcoded `level_index` 1 and 3 into `LevelBase._setup_blaze_portal()`, which assigns `portal.level_index` **before** `add_child()` — so `blaze_portal.gd::_ready()` → `_refresh_state()` already sees the correct index.
- `blaze_portal.gd::_on_body_entered()` writes `dash_return = {scene_path: get_tree().current_scene.scene_file_path, position, level_index}` verbatim. For L1/L3 the scene paths resolve to the correct .tscn files.
- `blaze_rush.gd::_ready()` reads `_level_index = int(GameManager.dash_return.get("level_index", 1))` → 1 or 3. `BlazeRushLayouts.get_layout()` routes 3 → `_level_3()`, 1 → `_level_1()` via the default arm.
- The `_:` default arm can only misfire for an index no portal produces — the only three call sites pass 1/2/3, and `dash_return` is written on every portal entry and cleared only in `_exit_to_level()` (after it's consumed) and `reset_session()`. There is no live path where L1 or L3 resolves `_level_index`, `return_path`, or the `save_checkpoint(_level_index, 990+_level_index, portal_pos)` write differently than L2. The only empty-`dash_return` case is running blaze_rush.tscn standalone in the editor, which defaults harmlessly to L1.

## 2. L1-specific full-wipe divergence

**NO BUG FOUND in the provided code — the reported symptom matches the pre-R9 build exactly; this points to a stale deployment.** Reasoning:

- `_respawn_or_game_over()`'s wipe branch (`player.gd`) is level-agnostic: `wipe_level = GameManager.current_level` → `clear_checkpoint(wipe_level)` → `refill_run()` → `level_scene(wipe_level)`. Nothing in it, `lose_life()`, `clear_checkpoint()`, or `refill_run()` branches on level number.
- `GameManager.current_level` cannot be stale while standing in level_01: **every** path into level_01_smoke_realm.tscn (new game, continue, Blaze Rush return, secret-realm return, wipe reload) runs `LevelBase._ready()`, whose R9 block force-writes `GameManager.current_level = level_data.level_index` and saves. That write completes before any death can occur — physics ticks don't interleave with `_ready()`, and the kill zone can only fire during physics.
- New-game vs. existing-save converges: `load_session()`'s early return (no file) leaves the default `current_level = 1`; a loaded save is overwritten on L1 entry by R9 anyway. Note `reset_session()` does **not** reset `current_level` — a real latent omission, but fully masked by the R9 entry-write for any level actually loaded.
- The founder's exact symptom ("wipe works on stage 2, not stage 1") is what the **pre-R9** code produced: `current_level` was then only set on level *clear*, so a player whose save said `current_level=2` and who was playing L1 would wipe with `wipe_level=2` — clearing L2's checkpoint and reloading **Level 2** instead of restarting L1. R9 in the provided `level_base.gd` fixes precisely that. If the live build still exhibits it, the live build predates R9.

To close this 100% I need two files not provided: `src/resources/level_01_data.tres` (to confirm `level_index == 1` so the R9 guard `level_data.level_index >= 1` actually fires) and the main-menu/new-game flow (to confirm nothing reads `current_level` before any `LevelBase._ready()` runs).

## 3. Auditor facing (C1) and chase/jump (C2)

**NO FUNCTIONAL BUG FOUND in PATROL/ALERT/PURSUE; one bounded no-facing window remains in VULNERABLE, and one visual-pivot question is unverifiable from the provided files.**

- **PATROL** (`auditor.gd`): R6 re-faces the live player every frame (`sprite.scale.x = 1.0 if pl.global_position.x > global_position.x else -1.0`); movement still uses `patrol_direction`; `_throw_clipboard()` aims at the live player via `direction_to()`. Correct.
- **ALERT**: facing is set once at entry and frozen for `alert_time` (0.6s) — this is the documented telegraph ("a frozen beat facing the player"), not a defect.
- **PURSUE**: re-reads the player every frame (`as CharacterBody2D` cast present), `velocity.x = toward * pursue_speed * speed_scale * ramp` is always nonzero toward the player (min ~93 px/s at ramp floor 0.55), facing updates every frame, gravity always applies, and `state_timer` guarantees exit to VULNERABLE in ≤4s — no stall path. Jump gating (`is_on_floor()`, cooldown, `wants_up or blocked`, `absf(dx) <= max_jump_gap * ramp`) is sound: he closes distance before jumping, and jump apex (~94px at jump_force −430 / g 980) caps ledge reach with aimed clipboards as the ranged answer. The only theoretical not-jump (player above but beyond `110 * ramp`) self-resolves as he closes horizontal distance.
- **VULNERABLE — the one literal residual**: no