# Task: prove or disprove that the Stage 2 boss can catch a sprinting player

You are auditing a Godot 4.3 2D platformer. The founder reports: "Stage 2 boss
still not moving / not chasing." A previous fix raised speeds and it STILL fails live.

## Hard numbers you must use
- Player `walk_speed = 200.0`, `SPRINT_MULTIPLIER = 1.2` -> top speed **240 px/s**.
- Boss node origin is **TOP-LEFT**; `BODY = 240.0` so the body centre is origin + (120,120).
- Level 2 arena from level_02_data.tres: `start_x = 3700`, `end_x = 4400`, `spawn = (4050, 500)`.
- Level code sets: `arena_min = Vector2(start_x + 90, spawn_y - 320)`,
  `arena_max = Vector2(end_x - 90, spawn_y + 120)` and these clamp the boss's
  **global_position** (i.e. its TOP-LEFT origin), not its centre.
- Ground floor in the arena is about y = 600.

## Files
@include src/boss/distributor.gd
@include src/level/level_02_crystal_caverns.gd

## Deliver, as a table
1. For EVERY state (PATROL, GRAVITY_TELL, HOARD_GRAVITY, SHARD_THROW, VULNERABLE):
   the boss's effective pursuit speed in px/s, and PASS/FAIL vs 240 px/s.
2. The fraction of one full attack cycle the boss spends slower than 240.
3. Work out the exact world-x range the boss's **visible centre** can occupy,
   given the clamp applies to the origin. Compare it to the x range the player
   can occupy inside the arena. State precisely where the player can stand such
   that the boss is pinned by `_clamp_to_arena()` and therefore appears
   motionless. Show the arithmetic.
4. Whether velocity is zeroed when the clamp bites (and what happens if it is not).
5. Minimum numeric changes required so the boss closes distance on a sprinting
   player from anywhere in the arena. Give concrete constants.

Be numeric and terse. No prose padding. No code rewrite — numbers and verdicts.
