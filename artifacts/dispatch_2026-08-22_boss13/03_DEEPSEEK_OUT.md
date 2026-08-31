<!-- dispatched: deepseek/deepseek-v4-pro
     prompt: artifacts/dispatch_2026-08-22_boss13/03_DEEPSEEK.md
     files inlined: 0
     tokens: 748 in / 6323 out
     cost: $0.0058
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
### Frame Table (delta = 1/60 s, instant velocity change)

| frame | origin_x | centre_x | right_edge | is_on_wall() | direction | target_vx | velocity.x after move_and_slide | did _clamp_to_arena fire | want_hop | _hop_cooldown |
|-------|----------|----------|------------|--------------|-----------|-----------|--------------------------------|--------------------------|----------|---------------|
| 1     | 4231.17  | 4371.17  | 4511.17    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 2     | 4226.33  | 4366.33  | 4506.33    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 3     | 4221.50  | 4361.50  | 4501.50    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 4     | 4216.67  | 4356.67  | 4496.67    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 5     | 4211.83  | 4351.83  | 4491.83    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 6     | 4207.00  | 4347.00  | 4487.00    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 7     | 4202.17  | 4342.17  | 4482.17    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 8     | 4197.33  | 4337.33  | 4477.33    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 9     | 4192.50  | 4332.50  | 4472.50    | false        | -1        | -290      | -290                           | false                    | false    | 0             |
| 10    | 4187.67  | 4327.67  | 4467.67    | false        | -1        | -290      | -290                           | false                    | false    | 0             |

*Initial state (before frame 1): origin_x=4236, centre_x=4376, right_edge=4516, velocity.x=0 (from previous clamp), is_on_wall()=false, _hop_cooldown=0. All frames assume grounded, gravity applied but neutralised by floor.*

---

### Answers

1. **Yes, he moves away from the wall.** On frame 1, `direction` = -1 (player is west), so `target_vx` = -290. Velocity.x becomes -290 and he shifts left. The clamp does not fire because centre_x = 4376 is exactly at the boundary, so no zeroing occurs. He escapes freely.

2. **`is_on_wall()` is false.** Godot’s `is_on_wall()` only reports collisions detected during the last `move_and_slide()`. When the boss is clamped by direct `global_position` assignment, the engine does not register a wall contact unless a subsequent `move_and_slide()` actually pushes the body into the wall. In this scenario, the boss is either stationary (velocity.x = 0) or moving away from the wall, so no wall collision is generated—even though his right edge overlaps the wall by 126 px.

3. **No, it does not cancel legitimate escape motion in this exact case.** `_clamp_to_arena()` only fires and zeroes velocity.x when the centre is **strictly outside** [3724, 4376]. Because centre_x = 4376 is exactly the upper bound, the clamp does **not** activate. Velocity.x remains -290, and the boss moves west unimpeded. The design is fragile: if centre_x were even slightly greater than 4376 (e.g., due to floating‑point drift), the clamp would fire and incorrectly kill the westward velocity, trapping the boss.

4. **No asymmetry at the west boundary.** With centre_x = 3724 (exact minimum) and player east, `direction` = +1, `target_vx` = +290. Clamp does not fire, velocity.x stays +290, and the boss moves east. The same logic applies symmetrically.