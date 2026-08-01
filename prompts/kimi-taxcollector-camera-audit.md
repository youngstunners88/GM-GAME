# Kimi K3 audit — Tax Collector/Auditor boss AI + Stage 2/3 camera (findings-first)

Godot 4.3 project. I've already found and fixed ONE confirmed camera bug:
`player.tscn`'s Camera2D ships with a hardcoded `limit_right = 3400`
(matching Level 1's width by coincidence), but Level 2 and Level 3 are BOTH
4400px wide with their boss arenas at x=3700-4400 — entirely past the old
clamp. Fixed by adding `LevelBase._setup_camera_limits()` which now sets
`cam.limit_right = level_data.bounds.x` etc. after player spawn. **Audit
whether this fix is complete and correct**, plus the boss AI questions below.
Findings first: SEVERITY — file:line — issue — fix. No preamble.

## Specific questions

1. **Camera fix completeness**: given the code below, does
   `_setup_camera_limits()` run at the RIGHT time relative to
   `_setup_boss_arena()` (which raises a wall at `boss_arena.end_x`) and the
   secret-realm early-return path in `_spawn_player()`? Is there any level-
   load order where the camera node isn't found yet (e.g. `get_first_node_in_
   group("player")` racing the `add_child(player)` call)? Is `limit_smoothed
   = true` (set in player.tscn) going to visibly "catch up" awkwardly right
   at the moment a boss arena wall raises and the background swaps, or is
   that a non-issue?
2. **Auditor boss obstacle**: the founder reports "a useless obstacle blocks
   [boss] chase" in the Stage 1 arena. Search `auditor.tscn` (if provided)
   and `auditor.gd` for any static obstacle, wall, or placed body in the
   boss's own arena setup that could interrupt movement. If genuinely not
   findable from what's provided, say so plainly.
3. **Auditor CHARGE state**: `current_state == State.CHARGE` moves toward
   `charge_target`, a Vector2 captured ONCE when charge begins
   (`charge_target = p.global_position`). Confirm: does this ever get
   updated again before CHARGE ends? Trace exactly how stale this position
   can get (charge duration is `state_timer = 1.4`).
4. **Regression risk**: if PATROL/CHARGE are merged into a continuous chase
   state (a change I'm about to review from another engineer), what
   existing behaviour reads risk breaking — the phase-based `patrol_speed`
   scaling, the `hop_timer` reposition hop, the diamond-shard/gold-platform
   token spectacle timers, or the VULNERABLE transition trigger
   (`is_on_wall()` OR `state_timer <= 0`)? Name the specific coupling.

## Files

@include src/level/level_base.gd
@include src/boss/auditor.gd
@include src/boss/auditor.tscn
@include src/enemies/tax_collector.gd
