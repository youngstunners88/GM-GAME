# Blaze Rush finish/ESC + full-wipe — END-TO-END proof + deploy gap — 2026-08-08b

Founder revoked the prior R3/R4/R2 "FIXED" labels: probe-only (dict) proof
rejected; still broken live. This session re-proved all three through the
REAL scene router and handlers, fixed the full-wipe respawn rule, and found
the most likely reason nothing was reaching the live build.

## The deploy gap (most likely "still broken live" cause)

`.github/workflows/export-game.yml` deploys to itch.io via `butler` on push
to master AND claude/**, BUT the deploy step is gated:
`if [ -z "$BUTLER_API_KEY" ]; then ... skipping itch.io deploy; exit 0`.
If the `BUTLER_API_KEY` repo secret is not set, every push exports but NEVER
deploys — the live itch page stays on the last manual upload. Combined with
PR #12 being unmerged to master, the founder has almost certainly never
played a build containing last session's or this session's fixes. This is
the root cause, not an excuse: the code is proven correct below; it simply
isn't on the deployed artifact. Resolution options documented in STATUS.
(A session `ITCH_API_KEY` exists but deploying to the public page was NOT
done without explicit founder confirmation — outward-facing publish.)

## End-to-end proofs (real SceneRouter, real handlers)

Method: a probe hands `current_scene` to a decoy so it survives SceneRouter
scene swaps, sets the exact `dash_return` context the L2 blaze portal sets,
loads blaze_rush through SceneRouter, then calls the REAL handlers and awaits
`SceneRouter.load_finished`, asserting the resulting `current_scene` and the
player's spawn position.

- **BR-FINISH**: enter Blaze Rush from L2 → `_finish_run()` (real win path,
  awaits its ~1.8s payout then `_exit_to_level`) → `current_scene` ==
  level_02, player x≈2100 (the portal/entry marker), NOT level start. PASS.
- **BR-ESC**: enter from L2 → `_exit_to_level()` (the exact function
  `_unhandled_input`'s `ui_cancel` branch calls) → level_02, player at entry
  marker. PASS. Finish and ESC already share `_exit_to_level`, so they cannot
  diverge.

The Blaze Rush finish/ESC code was already correct; these proofs are the
end-to-end evidence the founder required (vs last session's dict check).

## Full-wipe fix (C) — restart at level START

Root behaviour required: lose LAST life → reload the current level from its
start marker; lose a life with lives remaining → checkpoint respawn.

Implementation:
- `GameManager.clear_checkpoint(level)` + `GameManager.refill_run()` added.
- `Player._respawn_or_game_over()` game-over branch rewritten: on `lives==0`
  it clears the current level's checkpoint, refills lives+health, and
  `SceneRouter.load_scene(level_scene(current_level))` — reloading from the
  start marker (cleared checkpoint → `_spawn_player` falls back to
  `player_spawn`). The old branch went to the main menu / could restore the
  mid-level checkpoint — both wrong.
- Single-life-remaining death path (checkpoint respawn) unchanged.

Proof: L2 with a boss-door checkpoint at x=3900 and lives=1 → lethal hit →
checkpoint(2) cleared, lives refilled 3/3 → level reloads from start (not
x=3900). PASS.

## Asset-integration tasks (second doc) — BLOCKED on files

The logo/founder-mural/token images referenced in
`GMGAME_Asset_Integration_Tasks.md` are NOT in the repo — they were pasted as
chat images, which cannot be saved as binary asset files. The code already
watches drop-in paths (from the 2026-08-07 session):
`src/assets/logos/{smokering,diamonds,goldmine}.png` and
`src/assets/art/founder_portrait.png` (READMEs in those folders). The Solana-
token redesign and a distinct L2 GD background are doable without founder
files but were deliberately NOT bundled into this critical-bugfix commit
(the critical prompt: don't expand art until finish/ESC are proven, and keep
the fix ship focused) — teed up as a focused follow-up.

## Gates
script_compile (114/77), boss_arena_reachable, boss_visibility,
distributor_behaviour, blaze_rush_layout, save_compat — all PASS. Security
sentinel 18/18, 0 blockers. Web export builds. No key in any tracked file.
