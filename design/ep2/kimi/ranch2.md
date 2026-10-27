# Kimi packet (follow-up): write the missing Ep2RanchPose module the ranch code already calls, and run the gates

You are working in a Godot 4.3 GDScript project (Episode 2 of a first-person Western shooter, web export, Compatibility
renderer). Claude reviews every hunk, runs the gates and commits; write production code, not sketches.

## Situation
Your previous round on Dude's ranch was applied EXCEPT two blocks that the runner refused (they were outside the writable list):
the NEW file `src/episode2/actors/ep2_ranch_pose.gd` and an edit to `tests/ep2_stable_yard_test.gd`. Both are writable now. The
applied `src/episode2/chamber/ep2_stable_yard.gd` (included below, as it is now) calls:
- `Ep2RanchPose.install_ride(ap, skel, fwd, up, unit)`, `install_brush(...)`, `install_carry(...)` from `_install_poses()` (the same
  arguments `Ep2DrinkPose.install` takes: `fwd` / `up` are the character's forward and up IN SKELETON SPACE, `unit` = metres per
  skeleton unit), and
- the clip names `Ep2RanchPose.RIDE`, `Ep2RanchPose.BRUSH`, `Ep2RanchPose.CARRY` (held with `hold_clip`; CARRY is also the walk clip
  while the assistant carries hay).

## Build
1. `src/episode2/actors/ep2_ranch_pose.gd`, `class_name Ep2RanchPose`, `extends RefCounted`, static only, built the way
   `src/episode2/actors/ep2_drink_pose.gd` builds SitDrink/StandDrink (aim each bone from its rest direction, two-bone reach for the
   arms, key the result as an ordinary looping Animation in the player's default library; return false when the rig lacks the bones;
   never change the model). The rigs are Tripo/Mixamo (`mixamorig:Hips`, `Spine`, `Spine1`, `Spine2`, `Neck`, `Head`,
   `LeftShoulder/LeftArm/LeftForeArm/LeftHand`, `LeftUpLeg/LeftLeg/LeftFoot`, right likewise) - find bones by suffix like
   `Ep2DrinkPose._find` does.
   - RIDE: seated astride - thighs forward and apart (~25-30 deg each side), knees bent ~80-95 deg, feet in stirrup position under the
     knees, upright back with a small sway, both hands forward at the reins in front of the belly; a gentle 2-3 s loop (rider's bob).
   - BRUSH: standing at a horse's flank, the right arm strokes forward and back at chest height (a long ~0.45 m stroke, 1.6-2.2 s per
     stroke), the left hand resting forward as if on the horse, small torso follow-through; loop.
   - CARRY: both arms forward and down, hands ~0.35 m apart at waist height in front holding a hay bale, elbows slightly bent, a tiny
     bob; it must look right both standing and as the walk clip (legs keep their rest/walk), loop.
2. `tests/ep2_stable_yard_test.gd`: change ONLY assertions that are about the old behaviour this pack replaced on purpose (the old
   five-horse layout, the placeholder greeting) and keep every other assertion as it is. Explain each change in NOTES.
3. Check the rest of your previous change set compiles and the gates below pass; fix what does not (EDIT blocks only).

## Rules
GDScript for Godot 4.3: typed variables, `##` doc comments on public functions, no new autoloads, no project.godot edits, nothing that
needs Forward+. Never change dialogue text, line ids or voice ids. Change existing files only with exact SEARCH/REPLACE edits; the new
module as a whole FILE block. Then a short NOTES line: what each pose does and what you changed in the stable-yard test and why.

@include src/episode2/chamber/ep2_stable_yard.gd
@include src/episode2/actors/ep2_drink_pose.gd
@include tests/ep2_stable_yard_test.gd
@include tests/ep2_ranch_test.gd
