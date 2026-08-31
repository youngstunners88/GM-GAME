# DeepSeek — FSM TRACE ONLY. Do not change code. Output a frame table.

Godot 4.3. Boss 3 "Claim Jumper", BODY=280, origin is collision-box TOP-LEFT,
HALF_BODY=140. Level 3 boss arena: arena_min.x=3700, arena_max.x=4400.
ARENA_EDGE_MARGIN=24, so `_clamp_to_arena()` clamps his CENTRE to [3724, 4376]
and sets velocity.x = 0 on any frame it actually clamps.

A solid World-layer wall (20 wide, 600 tall) is centred at x=4400 → spans 4390..4410.
patrol_speed 290. hop cooldown 0.7s. hop airtime ~1.27s. gravity 980.

PATROL order of operations each frame:
  1. at_ledge = _ground_chase(delta, patrol_speed, CHASE_SEPARATION=200)
       -> sets direction from player, eases velocity.x toward target,
          applies gravity, move_and_slide(), then _clamp_to_arena()
  2. reference_y / already_high_enough height gate
  3. if is_on_floor() and _hop_cooldown <= 0 and not already_high_enough:
         want_hop = is_on_wall() or (at_ledge and _gap_crossable(direction))
         if player is >80px above and _higher_ground_ahead: want_hop = true
         if want_hop: velocity.y = HOP_VELOCITY; velocity.x = sized commit; _hop_cooldown = 0.7
  4. air-hop if _air_hop_ready and airborne and velocity.y > -120
  5. throw dynamite when throw_timer <= 0

## Scenario to trace
Boss has chased EAST and is now at the east clamp: centre_x = 4376 (origin 4236,
right edge 4516). Player is WEST at x = 3900, same y. Boss is grounded.

Deliver a 10-frame table with columns:
frame | origin_x | centre_x | right_edge | is_on_wall() | direction | target_vx |
velocity.x after move_and_slide | did _clamp_to_arena fire | want_hop | _hop_cooldown

Then answer:
1. On frame 1 the player is WEST, so `direction` should be -1 and he should move away
   from the wall. Does he? Or does the clamp/wall interaction prevent it?
2. Is `is_on_wall()` true at the east clamp given his right edge is 126px past the
   wall face? Explain what Godot reports when a body is clamped by CODE (direct
   global_position assignment) rather than by physics.
3. Does `_clamp_to_arena()` zeroing velocity.x on a frame where he is trying to move
   WEST (away from the wall) incorrectly cancel legitimate escape motion? This is the
   key question — answer it precisely.
4. Same trace but at the WEST boundary (centre 3724, player EAST). Any asymmetry?
