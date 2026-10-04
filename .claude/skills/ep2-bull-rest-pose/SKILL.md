---
name: ep2-bull-rest-pose
description: Inferno Bull is at REST in the hideout - no IK, no follow, no liquid arm, no idle sips - until an action beat (grab, hand-over). TRIGGER on "liquid / noodle arm", "he keeps moving his arm", "he follows Lil Blunt", edits to _animate_bull, _follow_player_in_fps, facility_show.gd steps, or Ep2ArmIK.
---
# Rules (founder 2026-10-02)
- Arm IK (`Ep2ArmIK.reaching`) runs only inside `reach` .. `release` steps of `FacilityShow`. Idle/walk = the clip's own arms (Idle_02 swings <= 9 degrees).
- The whiskey is a separate glass: in his hand while seated, then `_set_glass_on_table()` when he stands. No idle sip loop while standing.
- He does not trail Lil Blunt: after the helmet he walks to `BULL_REST` and stays. `_follow_player_in_fps` only moves him on the EXIT beat.
- He DOES turn in place to face Lil Blunt at rest (`_face_player_at_rest`, slack 0.45 rad) so his rifle and whiskey stay on the player's side of his body (skill ep2-bull-props-visible). Turning is not following.
- Target practice is a STUB (lane strip + "RANGE LOCKED" sign); do not invent the range look.
# Gate
`tools/ep2_shots/show_shot.tscn`: frames `15_rest_a` and `16_rest_b` (5 s apart) show the same arm pose.
