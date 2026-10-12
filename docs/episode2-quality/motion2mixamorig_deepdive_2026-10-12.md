# Motion2MixamoRig deep dive (founder request 2026-10-12)

Repo: https://github.com/MaxLiu22/Motion2MixamoRig (v0.1.0, "experimental", Apache-2.0 code, ~6k lines Python). Cloned and read in full
(`pipeline.py`, `extract.py`, `mixamo/{retarget,kinematics,tpose_calibration,ybot_retarget,animation,gltf,fbx_skeleton}.py`, the Blender add-on,
AGENTS.md, NOTICE.md). NOT run: it needs ~5 GB of weights, a gated SMPL-X file and ~10 min of CPU per 30 s clip; none of that is in this container.

## What it does
`video (or one photo)` -> **GVHMR** (monocular, world-grounded human mesh recovery; YOLOv8 person detect, RTMPose 2D) -> 24 SMPL joints per frame
(`skeleton_motion.npz`) -> **retarget** onto a Mixamo skeleton -> `mixamo_rotations.npz` (per-bone quaternions, wxyz) + a skinned `.glb` with the clip.

Retarget core (the part that is useful to us, independent of GVHMR):
1. Per bone: aim the bone's rest axis at the direction between two human joints (`SWING_TARGETS`), chest frame for Spine2, special neck/head and foot/hand frames.
   Twist is chosen closest to the previous frame, quaternion signs kept continuous (`continue_quaternion`).
2. Convention `local = T * Rpre * R_anim` (Mixamo FBX PreRotation); bone lengths are NEVER scaled, no IK, no foot-contact, **no temporal smoothing**.
3. Second stage `ybot_retarget.py`: "rest-relative" transfer onto any other Mixamo-named rig: `delta = inv(rest_skel) * frame_skel`, applied through a basis change `C`
   derived from the two rigs' T-pose frames. It REQUIRES both rigs to rest in a T-pose.
Controlled bones: Hips, Spine/1/2, Neck, Head, both Shoulder/Arm/ForeArm/Hand, UpLeg/Leg/Foot/ToeBase. No fingers, no props.
The Blender add-on is only a UI that shells out to the same CLI in an external venv.

## Fit with our characters
- Our rigs (Lil Blunt, Inferno Bull, bears; Meshy skeleton, all 24 joints) carry the SAME bone set as the controlled list. Names differ only by prefix/case:
  `mixamorig:Spine1` vs `Spine01`, `Neck` vs `neck`, `HeadTop_End` vs `head_end`. Trivial map.
- **Rest pose is the problem.** Measured from the shipped GLBs' inverse-bind matrices (arm direction, upper arm to hand): bear A-pose symmetric (45 deg down), Bull asymmetric
  (left arm 37 deg from vertical, right arm 20 deg), hero rig in a different frame (needs an axis check). Stage 3 above assumes T-pose; with these rests every arm would land a
  rest-offset away from the human's. Fix = replace stage 3 with the same aim-vector method used in stage 1 (works from any rest pose, ~150 lines), or re-pose each rig to T in Blender (re-bind risk, the Bull's sculpted fist is already fragile).
- Rig input is an FBX Binary parser; ours are GLB. Needs a glTF rig reader (T = node translation, Rpre = rest rotation) or a Blender FBX export. ~100 lines.
- Output is quaternions per bone: easy to write into a Godot `Animation` (same track paths as the existing clips, `Armature/Skeleton3D:<bone>`) or a Blender action.

## Blockers and risks (read before spending anything)
1. **LICENSE.** The repo's own NOTICE.md says the end-to-end pipeline is effectively non-commercial: GVHMR = non-commercial research only, SMPL-X = non-commercial unless a separate
   commercial licence, YOLOv8 = AGPL-3.0. This game promotes a token, so treat it as commercial. Options: (a) buy the SMPL-X / GVHMR commercial licences (MPI / Meshcapade), (b) keep ONLY the
   Apache-2.0 retarget core and feed it joints from a licence-clean source: Mixamo's animation library (Adobe permits use in shipped games), our own Blender-keyed or BVH mocap, or a permissive
   pose estimator (e.g. MediaPipe Pose, Apache-2.0, noisier). (b) is the safe default.
2. **Capture quality.** Monocular video gives jitter (no smoothing here), foot sliding (no contact/IK), no hand-prop contact (rifle, bow, quad grips). A clip needs one person, head to toe in frame the whole time.
   Someone has to film each action. Add a smoothing pass (One-Euro / Savitzky-Golay on joints) and foot-lock IK on our side.
3. **It will not fix skinning.** The tears we fixed on the Bull (arm IK, sculpted fist fused to the flask pouch, the seated clip dragging the elbow) are mesh/skin problems. New motion on the same
   mesh can still tear. Non-human proportions (Bull 2.4 m, huge shoulders; bears) retarget fine as rotations but arms can intersect the chest.
4. Setup: SMPL-X needs a registered account (the founder's), Python 3.10+, chumpy build quirk, CPU 8-15 min per 30 s clip (GPU much faster), not runnable on the web build (offline tool only).

## Where our movement is actually bad (so the tool is pointed at the right thing)
- Clips are Meshy-library animations baked on bodies they were not made for (Tripo bodies retargeted onto the Meshy skeleton): the seated ride clip twists the Bull's arms, the talk clips curl them into his coat.
- Lil Blunt's body only has walk/run; Bull has idle/drink/talk/gun-gesture/sit; bears have archery/stomp/leap. Nothing for: Bull riding with hands on grips, pulling the lever, hand-over, hopping the lava, brushing leaves; bear patrol/read/sleep, draw-bow.
- The rest is procedural acting + arm IK + rest-arm locks (hacks that cost us the torn elbow).

## Recommended path
- **Phase 0 (no licence risk, ~1 session):** `tools/ep2_motion/` = our own retarget adapter: the aim-vector retarget (stage 1 maths from this repo, Apache-2.0, keep the notice) driving OUR 24-bone rigs from any joint source (BVH / Mixamo FBX via Blender export), a glTF rig reader, a smoothing + foot-lock pass, a Godot `Animation` writer, and a capture rig proving each clip on Bull / bear / hero from 3 angles. This alone lets us use the Mixamo library properly (matched, looped, no IK hacks).
- **Phase 1:** the founder decides the licence route (a or b above) and who films. Then wire GVHMR (or the permissive estimator) in front of Phase 0.
- **Clip list in priority order:** Bull seated-ride (hands on grips), lever pull, hand-over, lava hop, talk loops, lean on crate idle; bear patrol walk, read, sleep, draw-bow, stagger; Lil Blunt rifle-low walk, jump, victory.
