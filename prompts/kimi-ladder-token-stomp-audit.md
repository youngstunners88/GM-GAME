# Kimi K3 audit — ladder top-exit, token walk-through pickup, stomp absence (findings-first)

Godot 4.3 project. I've already found and fixed ONE confirmed ladder bug
(level_01's second ladder landed short of its target platform because it
never set a custom `top_exit_offset`, unlike level_02's ladders which do).
Audit the rest for the same class of bug, plus the token pickup and stomp
questions below. **Findings first**: SEVERITY — file:line — what's wrong —
concrete fix. No preamble.

## Specific questions

1. **Ladder top-exit mechanism** (`ladder.gd` + the climb code in
   `player.gd`): is `_top_out_ladder()`'s anti-flicker / anti-tunnel logic
   actually correct, or does it have an edge case? Is `top_exit_position()`
   ever called before `_active_ladder` is guaranteed non-null?
2. **Token walk-through** (`coin.gd`, `gold_token.gd`, their `.tscn` files):
   these use `Area2D.body_entered` against the player's main physics body
   (collision_layer 2), not a jump-only check. Is there anything in the
   CODE that would make walking through NOT trigger pickup while jumping
   onto it DOES? (e.g. collision_mask mismatch, monitoring toggled off by
   something else, the Area2D's shape height being placed above where a
   standing/walking player's body shape reaches). If the code path looks
   correct, say so explicitly and note that the bug is most likely LEVEL-
   DATA token height placement, not a code defect — don't force a code
   finding that isn't there.
3. **Stomp**: confirm there is NO existing head-stomp/jump-attack mechanic
   anywhere (I believe there isn't). If you find ANY existing partial
   implementation I missed, point to it exactly.
4. **Regression check**: given `player.gd`'s `_on_hurtbox_body_entered`
   already special-cases boulders (pickaxe) and hazards, would adding a
   stomp check there risk double-firing with the boulder/hazard paths for
   any enemy type? Name the enemy types that could collide.

## Files

@include src/level/ladder.gd
@include src/player/player.gd
@include src/collectibles/coin.gd
@include src/collectibles/coin.tscn
@include src/collectibles/gold_token.gd
@include src/collectibles/gold_token.tscn
@include src/enemies/enemy_base.gd
