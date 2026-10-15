---
name: ep2-rest-aware-retargeting
description: Retarget or author motion for GM-GAME's 24-joint Bull/bear rigs while preserving non-T rest poses, units, bone lengths, quaternion continuity, planted feet and skin integrity. Use for mismatched library clips, skating, warped arms or frozen-arm workarounds.
---

# Rest-aware motion

Read design/ep2/motion/CHARACTER_MOTION_CONTRACT.md. Inspect source/target GLB skeletons and current Ep2Actor clip loading before changing either.
Use existing founder models and preserve original skin/atlas/approved appearance. A new movement request is not permission to replace the character.

## Establish frames

- Read complete node hierarchy, rest/local/global transforms, skin inverse-bind matrices, units, facing axis, root/hips policy, and bone name map. Handle Spine01 vs Spine1 and neck vs Neck explicitly. Matching bone names does not prove matching rest poses.
- Both inspected Bull and bear GLBs have 24 skin joints and LeftHand/RightHand, with no finger joints. There is no procedural finger curl capability unless it is authored into mesh/rig work.
- Bull rest arms are asymmetric; bears use an A pose. Do not force either to T and rebind blindly. Preserve bone lengths and non-uniform scale constraints.
- First run a neutral-pose identity test: a neutral source maps exactly to the target's own neutral pose. Then test one arm raise, one knee bend, turn and planted stance, each at multiple body headings.
- Use rest-relative rotations with an explicitly declared parent/local basis conversion, or a global aim-vector solve with an anatomical pole. For a local-basis transfer, derive source-rest inverse times source-pose and conjugate by the measured source-to-target basis; apply it under target rest. Verify importer conventions before writing tracks; never paste a formula assuming unknown FBX pre-rotations.
- Preserve quaternion sign/hemisphere continuity and unit length. Derive twist from a stable reference/previous frame; avoid 180-degree flips near collinear limbs.

## Body and feet

- Choose root motion OR room-driven in-place locomotion and document the owner. Match stride frequency to actual displacement, including deceleration/pivot/arrival; full-speed legs while the actor is stationary are not a walk.
- Keep planted contact intervals. Apply root/hips correction and bounded leg IK against actual ground; reject foot skating, penetrating supports and movement that tears knees/coat. Measure in world metres after final scaling.
- Anticipation/weight shift precedes a turn, reach, leap or rise; settle and secondary motion follow. Gaze can lead shoulders/body within safe anatomical limits. Use authored action variants, not entire-model scaling to fake breathing.
- Smooth input joint jitter before retargeting, preserving event timing and fast intentional motion. Loop endpoints match pose and velocity; short shot boundaries need overlap alignment without duplicate playback.
- Keep source tracks/rig reversible. Ep2Actor currently drops non-Hips translations; that alone does not retarget rest rotations. Its animation clock must be reconciled with step(delta), capture stepping, pause and frozen poses before claiming deterministic timing.

## Skin guard and export

The Tripo Bull's sculpted right fist/pouch and elbow webbing already fail under mismatched clips. Test evaluated geometry, not only bones. Capture both elbows, shoulder/coat and hand/pouch over the entire clip; compare edge stretch, inverted faces and silhouette to baseline.
If contact requires an impossible free hand or tears the mesh, repair skin/bridging topology on a recoverable source or use a physically valid restrained action. Never hide the failure with a permanent rest-arm lock, stretched bone or prop teleport.
Build Blender actions headlessly and retain .blend/source settings. Export animation-only resources or a single tested GLB according to the existing loader; avoid duplicating textures/characters per clip. Preserve actual names, required motions, material/skin data and the current web pack gate.
Use only rights-cleared motion. The existing Motion2MixamoRig research separates Apache retarget code from restricted extraction dependencies; inspect it rather than deploying its whole video extraction stack as licensed.

Hand off to ep2-prop-contact-animation before claiming rifle/bow handling; skeletal retargeting alone cannot bind a hand to a prop.
