---
name: ep2-character-motion-qa
description: Verify whole-clip Bull/bear movement, final-pose prop contacts, feet, transitions and runtime timing with baseline/candidate captures and measurements. Use before calling motion fluid, hands gripping, retargeting successful or a character fix ready to ship.
---

# Whole-clip proof

Read design/ep2/motion/CHARACTER_MOTION_CONTRACT.md. Keep static structure checks, timed skeletal evidence, skin/contact measurements, player-camera review and real release proof separate.

## Capture contract

Pin source SHA, exact character/prop/animation hashes, camera/viewport, world positions, frame rate/time step, input/seed and readiness. Baseline and candidate use the same scenario.
Use current tools/ep2_shots/bear_poses_shot.tscn, woods_life_shot.tscn, interlude_shot.tscn, bull_props_shot.tscn, bull_close_shot.tscn and range_lesson_shot.tscn only where their scope fits. Extend a minimal rig to emit timed contact/foot data when existing stills cannot prove motion.
Record actual game timing: existing capture _run() loops call step(delta) while AnimationPlayer advances on the engine clock. Do not sample hundreds of simulated actor steps with an unchanged animation pose and claim a full-clip test. Resolve the single clock owner and modifier/attachment sampling order before measuring.

## Required samples and measurements

Sample entire actions at their authored time step, all hold/contact intervals, both ends and 0.25/0.5/0.75 blend positions. Include idle->walk->stop/turn, carry->fire->recovery, read->wake/move, draw->release, mount->ride->dismount and interrupted/retried interactions.
Record maximum and percentile hand-to-independent-grip error, palm orientation, reach shortfall, planted-foot slip/ground gap, pelvis/support contact, frame-to-frame joint discontinuity and skin stretch/inversion. Use the contract's provisional tolerance profiles; declare any exception before comparing results.
Contact samples must be after the final skeleton modifiers and BoneAttachment update, in world metres. Include pawn/prop debug overlays for diagnostics and overlay-free player frames for review. Check torso/weapon occlusion and hands from front/side/back as well as the actual first-person camera.
Produce a short timed video/sequence for motion, not only a favorable still. Review the guide, approved character reference and result together. No invented visual score or machine metric is a substitute for looking.

## Useful tests and evidence limits

Preserve applicable ep2_interlude, ep2_smelting_facility, ep2_hideout_corrections, ep2_range_lesson, ep2_runner_motion, ep2_glb_pipeline and ep2_fort_knox_arc scene gates plus script_compile. Existing gates do not measure every grip or phase: add meaningful regressions when implementing the missing invariants.
Future acceptance names and contact markers in this package are planned, not existing runtime tests. Plan validation exit 0 says only that the plan is structurally sound.
With game-dev installed and authorized, use its declarative adapter and sealed baseline/candidate bundles; preserve receipts. If absent, record that and use available native Godot captures. A Blender render or Godot headless dummy renderer is not a real Godot pixel capture; absent Xvfb/display/GPU is a capture blocker, not a passing image.
Do not disable assertions, collision, tutorial locks, TLS verification or authorization checks to turn missing capability into a pass.

## Review and publication

Jev and Microsoft Decision receive the measured candidate tables as text when configured/reachable; no images or invented playtest counts. Retain actual responses/errors and disagreements. Use the requested visual reviewer only on actual images/reference pairs. Stop repeated calls on unchanged access denial.
Runtime work needs correct native outcomes, Godot 4.3 nonthreaded Compatibility web export under the current gate and loaded browser checks, then smokerealm-ship and a matching public BUILD/upload. Skills-only work checks metadata/links/templates/checker and source preservation, updates STATUS, commits and merges; it does not trigger a runtime release.
