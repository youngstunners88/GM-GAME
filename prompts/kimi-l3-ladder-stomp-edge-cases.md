# Kimi K3 audit — Level 3 ladder fix verification + stomp edge cases (findings-first)

Godot 4.3 project. Two independent things to audit. **Findings first**:
SEVERITY — file:line — issue — fix. No preamble.

## Part A — verify the Level 3 ladder fix

I just applied `ladder.top_exit_offset = Vector2(75, 50)` to the Level 3
ladder at `global_position=(1465,350)`, height=300, computed as: nearest
platform `Vector4(1480,420,120,20)` (x,y,width,height — top-left + size),
target = `(platform.x + width/2, platform.y - 20)` = `(1540,400)`,
offset = target - ladder_pos = `(75, 50)`. Confirm this arithmetic is
correct, confirm `(1540,400)` genuinely falls within the platform's
reachable surface, and confirm this is really the platform the level design
intends ("ladder up to the timed gate's approach ledge, escape from the cart
run" — the gate is at `(1520,530)`; ground has a gap between x=1500 and
x=1600 right where the gate sits). If a DIFFERENT platform/ledge is a better
match than the one I picked, say so and show your arithmetic.

## Part B — stomp edge cases: boss exclusion + one-way platforms

`_try_stomp()` in `player.gd` excludes bosses (`body.is_in_group("boss")` →
return false) so a stomp never bypasses a boss's own VULNERABLE-window
damage contract. Confirm:

1. Every current boss scene (`auditor.tscn` at minimum — check others if
   provided) is actually IN the `"boss"` group, not just conceptually a
   boss. If any boss scene is missing `add_to_group("boss")`, the exclusion
   silently doesn't apply to it.
2. One-way platforms: can a stomp fire while the player is passing THROUGH
   a one-way platform from below (mid-jump, before landing) and hit an
   enemy standing on that platform, in a way that reads as unfair (stomping
   an enemy you haven't visually "landed above" yet)? Trace the Y-margin
   check (`global_position.y < body.global_position.y - STOMP_Y_MARGIN`,
   margin=8px) against a typical one-way platform's thickness.
3. Ladder interaction: can `_try_stomp()` fire while the player is in the
   `_climbing` state (vertical movement, `velocity.y` driven by climb input,
   not gravity)? If so, is a stomp during a climb sensible, or should climb
   state also exclude stomp?
4. `_ground_pounding` interaction: confirm the stomp path and the Big Mode
   ground-pound path (`_resolve_ground_pound`) can't BOTH apply damage to
   the same enemy from the same landing (the stomp code sets
   `_ground_pounding = false` on success — confirm this actually prevents
   the pound's OWN damage application from also running this frame, not
   just cosmetically resetting a flag after the pound already dealt damage).

## Files

@include src/level/level_03_gold_rush.gd
@include src/resources/level_03_data.tres
@include src/player/player.gd
@include src/boss/auditor.tscn
