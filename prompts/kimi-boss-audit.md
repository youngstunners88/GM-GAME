# Kimi K3 — audit Distributor (R1/R7) + Auditor facing (R6). Findings-first.

Godot 4.3. The founder reports, live: (R1) the Distributor "does not lose
HP / does not impact Lil Blunt"; (R7) the Distributor "fell into a gap and
the fight became unrecoverable"; (R6) the Tax Auditor "shows his back to the
player". Verify each against the REAL code inlined below. For each: is it a
real bug in THIS code, the exact file:line, and the minimal fix.

1. R1 both-way damage: trace player→boss (does an axe/flame/stomp reduce
   `health`? is take_damage gated only to VULNERABLE, and is there any
   vulnerable window reachable?) AND boss→player (does `_on_hitbox_body_entered`
   fire and call player.take_damage while `monitoring` is on?). State whether
   both directions actually work or which is broken.
2. R7 pit fall: the boss applies `velocity.y += 980*delta; move_and_slide()`
   every phase and only flips at walls. Confirm there is NO arena-bounds
   clamp and NO floor guarantee, so a pit in the L2 arena lets him fall out
   permanently. Give the minimal clamp/float fix.
3. R6 facing: the Auditor sets `sprite.scale.x = 1.0/-1.0`. Determine whether
   the facing is (a) not updated toward the player during the state the
   founder sees (PATROL faces patrol_direction, which can be away from the
   player for the whole non-chase portion of the fight), and/or (b) inverted
   vs the source art's native orientation. State which, with the fix.

Findings-first: SEVERITY — file:line — issue — fix. Be terse.

## Files
@include src/boss/distributor.gd
@include src/boss/auditor.gd
@include src/boss/boss_sprite.gd
@include src/player/combat_handler.gd
