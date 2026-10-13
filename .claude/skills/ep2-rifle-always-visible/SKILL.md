---
name: ep2-rifle-always-visible
description: Lil Blunt's rifle must ALWAYS be visible in his hands in Episode 2 first person (hip, carry/low-ready while Inferno leads, sprint). Measure on-screen coverage per pose before and after any viewmodel pose change, and let Jev + microsoft-decision-1 pick on the numbers. TRIGGER on "the rifle is invisible / gone / missing", "I can't see the gun", any edit to VM_LOW_* / VM_SPRINT_* / VM_HIP_* in smelting_facility.gd or ep2_viewmodel.gd, or a spyglass/binocular/lowered pose change.
---

# Rifle always visible (founder 2026-10-11: "Why is the rifle invisible!!!")

## What went wrong once
The woods spyglass fix dropped `VM_LOW_POS` below the frame (right for the spyglass). The same constant name in
`smelting_facility.gd` is the hideout CARRY pose used for the whole "Follow Inferno Bull to the firing line" walk
(`_lesson == LEAD or DEMO`). Copying the spyglass value there left only the muzzle tip on screen.

**Rule: the two poses are different things.**
- `src/episode2/chamber/ep2_viewmodel.gd` `VM_LOW_*` = spyglass ONLY (woods `_viewmodel_lowered()`), below the frame.
- `src/episode2/chamber/smelting_facility.gd` `VM_LOW_*` = carry, IN FRAME lower right, out of the aim window.
- `VM_SPRINT_*` in both = in frame.
Gate: `tests/ep2_range_lesson_test.tscn` (`_carry_pose_in_frame`, y >= -0.32).

## Measure (never eyeball, never guess)
```
xvfb-run -a -s "-screen 0 960x540x24" .godot-cache/Godot_v4.3-stable_linux.x86_64 --rendering-driver opengl3 \
  --rendering-method gl_compatibility --resolution 960x540 --path . res://tools/ep2_shots/range_lesson_shot.tscn -- out=.farm/carry carry=1
```
Prints `VM carry on_screen=… central=… area=…` (every rifle vertex projected through the game camera) and saves `carry.png`.
2026-10-11: broken 0.231 / area 0.018; pre-spyglass 0.582 / central 0.016; shipped carry 0.710 / area 0.152 / central 0.
Targets: on_screen >= 0.5, central (aim window) ~0, lower_right ~1.

## Decide
Hand the numbers (text, never the image - Jev is text-only) to `node scripts/jev.mjs --state … --choice …` and the same with
`JEV_MODEL=microsoft/microsoft-decision-1`. 2026-10-11: both chose the new carry pose (0.99 / 0.93). The script prints
"BLOCK" for any choice that is not literally named ship - read the choice, not that line.

## Blender / Tripo?
An invisible viewmodel is a POSE/camera problem first. Only reach for the model pipeline when the mesh itself is wrong
(holes, logo, see-through): `ep2-founder-weapon-glb` (Blender build of the founder GLB), `ep2-rifle-realism` +
`blender-headless-render-safety` (headless Blender), `ep2-tripo-mesh-surgery` / `ep2-hyperreal-scene-pipeline`
(Tripo via Muapi), `ep2-solid-models` (see-through).

## The forearm extension never shows on the kick (founder 2026-10-13)
"Bring the arm closer so that when the rifle kicks up we don't see that green extension. Don't make things worse." The founder rifle's
arm ends in a cut hidden by a flat-green `ArmSleeve` (`ep2_view_hands.gd`). The kick, the lever roll (rot.z +0.34) and the reload used
to turn the rifle about its own origin, so the forearm end swung up and the sleeve showed bottom-left (measured 0.185 % of the frame at
+316 ms). Now both copies of the viewmodel step (`ep2_viewmodel.gd`, `smelting_facility.gd`) turn about the FOREARM END
(`rifle.get_meta("arm_pivot")` = HandsModel position + SLEEVE_CUT): `pos += B(rot_hold)*piv - B(rot)*piv`. The hip look is untouched.
- Measure: `tools/ep2_shots/vm_sleeve_probe.tscn` (renders the real viewmodel, sleeve in magenta, through a shot and a look sweep, run at
  1725x993 / 1280x720 / 2560x1080 / 1024x768) and `tools/ep2_shots/vm_kick_shot.tscn` (the real woods). Gate: `_arm_stays_put` in
  `tests/ep2_range_lesson_test`.
- Moving the hip CLOSER also hides it but blows the GM logo up and cuts it at the frame edge: rejected (do not change the approved look).
- Do not "improve" the sleeve material on the side: the founder read the shared-material change as the gun getting darker. Reverted.
