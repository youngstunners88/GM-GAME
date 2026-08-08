<!-- dispatched: qwen/qwen3-vl-235b-a22b-thinking
     prompt: prompts/qwen-static-review.md
     files inlined: 3
     tokens: 15609 in / 1739 out
     cost: $0.0132
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
- **WRONG BOSS FACING**: src/boss/auditor.gd:175-177 — During PATROL state, `sprite.scale.x` flips based on `patrol_direction` (wall collision), not player position. Boss may face away from player while patrolling.
- **CAMERA CLAMP**: src/dashmode/blaze_rush.gd:275-276 — Camera position set to `_player.position.x + 240.0` with no clamping. May exceed level bounds if player approaches course edges.
- **BLAZE RUSH EXIT**: src/dashmode/blaze_rush.gd:506-512 — `GameManager.dash_return` data used for return path; if corrupted/missing, may load incorrect level. No validation on `return_path` before loading.