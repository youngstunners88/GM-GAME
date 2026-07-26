# Evidence — E. Ladder top-out

## Root cause
`src/level/ladder.gd` (climb up/down + jump-off) had NO top-out: reaching the
top and pressing up just ran the player into the platform underside — "climbs
underneath and cannot get onto it."

## Fix
- ladder.gd: explicit geometry API — `top_y()`, `bottom_y()`, and a
  data-driven `top_exit_offset` export → `top_exit_position()`. Offset
  platforms handled per-instance via scene data, NOT hardcoded player coords.
- player.gd `_update_climb`: when climbing up (vertical<0) AND at/above the
  ladder top, calls `_top_out_ladder()` — places the player at the exit
  position, then a BOUNDED move_and_collide un-stick nudges upward if the
  point overlaps geometry (never a raw teleport into a collider; a fully
  blocked exit just stays put per the brief). Tracks the active ladder node
  (`enter/exit_ladder_zone(ladder)`) so top-out has geometry to target.
- Existing behaviours preserved: press-down-at-bottom exit, jump-off,
  leaving-zone exit, one-way platforms (separate system), mobile (uses the
  same move_up/move_down actions).

## Verification
Compiles + boots in the real export. Runtime top-out confirmation per ladder
is a human-playtest step (the sandbox harness can't script per-ladder climbs);
steps in the report. PASS (code + boot); per-ladder human tick pending.
