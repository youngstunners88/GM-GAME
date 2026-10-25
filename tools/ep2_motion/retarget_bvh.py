"""Retarget CMU BVH mocap onto a prepared folk rig (Mixamo or UE-style names) and bake one game clip per action.
Skill: ep2-runpod-motion-lab. Source clips: tools/ep2_motion/fetch_cmu.sh (commercial use allowed, see that file).

  blender -b rich_prep.blend --factory-startup -P tools/ep2_motion/retarget_bvh.py -- --spec tools/ep2_motion/clips_rich.json \
      --bvh-dir ~/tools/mocap/cmu --out rich_anim.blend

Method (no constraints, no depsgraph per bone): for each mapped bone the source's WORLD rotation change from its rest pose is applied
to the target's rest pose, after a per-limb rest alignment (Rich's rig rests arms-down, CMU rests in a T-pose):
    R_tgt(t) = Yaw @ S(t) @ S_rest^-1 @ C @ R_tgt_rest        (C rotates the target limb's rest direction onto the source's)
then converted to local pose rotations parent-first. Unmapped bones (twists, fingers, toes) follow their parent. The hips get the
source's vertical bob and sway (scaled by leg length); forward travel is removed (in place: Ep2TownFolk moves the node), and its
speed is reported so the walk speed can match the stride. Loops are closed by blending the last frames into the first.
Prints @@{json} with per-clip frames, travel speed and foot slide.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

CMU_TO_MIXAMO = {
    "Hips": "Hips", "LeftUpLeg": "LeftUpLeg", "LeftLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToeBase",
    "RightUpLeg": "RightUpLeg", "RightLeg": "RightLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToeBase",
    "Spine": "LowerBack", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Neck", "Head": "Head",
    "LeftShoulder": "LeftShoulder", "LeftArm": "LeftArm", "LeftForeArm": "LeftForeArm",
    "RightShoulder": "RightShoulder", "RightArm": "RightArm", "RightForeArm": "RightForeArm",
}
# Hands are NOT mapped: CMU's hand bone points along the palm differently from both rigs and turned the hands out flat
# (render 2026-10-19). Hands follow the forearm in their own rest relation instead.
CMU_TO_UE = {
    "pelvis": "Hips", "thigh_l": "LeftUpLeg", "calf_l": "LeftLeg", "foot_l": "LeftFoot", "ball_l": "LeftToeBase",
    "thigh_r": "RightUpLeg", "calf_r": "RightLeg", "foot_r": "RightFoot", "ball_r": "RightToeBase",
    "spine_01": "LowerBack", "spine_02": "Spine", "spine_03": "Spine1", "neck_01": "Neck", "head": "Head",
    "clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm",
    "clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm",
}
## The Meshy auto-rig (24 joints) names its spine bottom-up Spine02 -> Spine01 -> Spine and its neck lower-case.
CMU_TO_MESHY = {
    "Hips": "Hips", "LeftUpLeg": "LeftUpLeg", "LeftLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToeBase",
    "RightUpLeg": "RightUpLeg", "RightLeg": "RightLeg", "RightFoot": "RightFoot", "RightToeBase": "RightToeBase",
    "Spine02": "LowerBack", "Spine01": "Spine", "Spine": "Spine1", "neck": "Neck", "Head": "Head",
    "LeftShoulder": "LeftShoulder", "LeftArm": "LeftArm", "LeftForeArm": "LeftForeArm",
    "RightShoulder": "RightShoulder", "RightArm": "RightArm", "RightForeArm": "RightForeArm",
}
## The game's own 20-joint townfolk rig (tools/ep2_blender/build_armory_folk.py, rig_scan_character.py: the prisoner, Jack Hammer, the
## rigged Minister): Root -> Hips -> Spine -> Chest -> Neck -> Head, Shoulder/UpperArm/Forearm/Hand, Thigh/Shin/Foot (.L / .R).
## Insertion order matters: the leg chain is read up -> low -> foot.
CMU_TO_TOWNFOLK = {
    "Hips": "Hips", "Thigh.L": "LeftUpLeg", "Shin.L": "LeftLeg", "Foot.L": "LeftFoot",
    "Thigh.R": "RightUpLeg", "Shin.R": "RightLeg", "Foot.R": "RightFoot",
    "Spine": "LowerBack", "Chest": "Spine1", "Neck": "Neck", "Head": "Head",
    "Shoulder.L": "LeftShoulder", "UpperArm.L": "LeftArm", "Forearm.L": "LeftForeArm",
    "Shoulder.R": "RightShoulder", "UpperArm.R": "RightArm", "Forearm.R": "RightForeArm",
}
LIMB_SRC = {"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
            "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"}

ap = argparse.ArgumentParser()
ap.add_argument("--spec", required=True)
ap.add_argument("--bvh-dir", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--fps", type=int, default=30)
ap.add_argument("--only", nargs="*", default=[])
ap.add_argument("--glb", default="")                  # import this rigged GLB first (instead of opening a prepared .blend)
ap.add_argument("--export-glb", default="")           # also write the armature + mesh + every clip as a GLB (for append_glb_clips.py)
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
if a.glb:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.glb)
spec = json.load(open(a.spec))

sc = bpy.context.scene
tgt = next(o for o in sc.objects if o.type == "ARMATURE")
assert tgt.matrix_world.to_3x3().is_identity or (tgt.matrix_world.to_3x3() - Matrix.Identity(3)).median_scale < 1e-4, "apply transforms first"
names = {b.name for b in tgt.data.bones}
prefix = "mixamorig:" if any(n.startswith("mixamorig:") for n in names) else ""
if "Spine02" in names and "neck" in names:            # the Meshy rig (the Episode 2 townspeople): Hips -> Spine02 -> Spine01 -> Spine -> neck
    MAP = {k: v for k, v in CMU_TO_MESHY.items() if k in names}
elif "Thigh.L" in names and "Forearm.L" in names:     # the game's townfolk rig (rig_scan_character.py)
    MAP = {k: v for k, v in CMU_TO_TOWNFOLK.items() if k in names}
elif prefix or "Hips" in names:
    MAP = {prefix + k: v for k, v in CMU_TO_MIXAMO.items() if prefix + k in names}
else:
    MAP = {k: v for k, v in CMU_TO_UE.items() if k in names}
hips_t = next(t for t, s in MAP.items() if s == "Hips")
order = []                                    # target bones parent-first
def walk(b):
    order.append(b)
    for c in b.children:
        walk(c)
for b in tgt.data.bones:
    if b.parent is None:
        walk(b)
rest_t = {b.name: b.matrix_local.to_3x3() for b in tgt.data.bones}          # armature space == world (transforms applied)
for pb in tgt.pose.bones:
    pb.rotation_mode = "QUATERNION"


def leg_len(get_head, up, low, foot):
    return (get_head(up) - get_head(low)).length + (get_head(low) - get_head(foot)).length


tl = lambda n: tgt.data.bones[n].head_local
t_leg = leg_len(tl, *[t for t, s in MAP.items() if s in ("LeftUpLeg", "LeftLeg", "LeftFoot")])
report = []

for clip in spec["clips"]:
    if a.only and clip["name"] not in a.only:
        continue
    # --- source -------------------------------------------------------------------------------------------------------
    before = set(bpy.data.objects)
    bpy.ops.import_anim.bvh(filepath=os.path.join(os.path.expanduser(a.bvh_dir), clip["bvh"] + ".bvh"),
                            global_scale=1.0, rotate_mode="NATIVE", update_scene_fps=False, update_scene_duration=False)
    src = next(o for o in bpy.data.objects if o not in before and o.type == "ARMATURE")
    sact = src.animation_data.action
    f0, f1 = [int(v) for v in sact.frame_range]
    src_fps = round(1.0 / float(clip.get("frame_time", 1.0 / 120.0)))
    sw = src.matrix_world.to_3x3()
    rest_s = {b.name: sw @ b.matrix_local.to_3x3() for b in src.data.bones}
    sh = lambda n: src.matrix_world @ src.data.bones[n].head_local
    s_leg = leg_len(sh, "LeftUpLeg", "LeftLeg", "LeftFoot")
    ratio = t_leg / s_leg
    # rest alignment per limb: rotate the target's rest bone direction onto the source's
    corr = {}
    for t, s in MAP.items():
        if s in LIMB_SRC:
            dt = (rest_t[t] @ Vector((0, 1, 0))).normalized()
            ds = (rest_s[s] @ Vector((0, 1, 0))).normalized()
            corr[t] = dt.rotation_difference(ds).to_matrix()
        else:
            corr[t] = Matrix.Identity(3)

    # Bruce Hahne's BVH release prepends a T-pose frame: never start on it (it also fakes the facing yaw to 0)
    s0 = f0 + max(2, int(round(clip.get("start", 0.0) * src_fps)))
    s1 = min(f1, f0 + int(round(clip.get("end", (f1 - f0) / src_fps) * src_fps)))
    step = src_fps / a.fps * float(clip.get("speed", 1.0))      # speed < 1 slows the source (a lean becomes a slow settle)
    frames = []
    k = s0
    while k <= s1:
        frames.append(k)
        k += step

    def src_pose(f):
        sc.frame_set(int(f), subframe=f - int(f))
        rots = {n: sw @ pb.matrix.to_3x3() for n, pb in src.pose.bones.items()}
        mw = src.matrix_world
        return rots, {n: mw @ pb.head for n, pb in src.pose.bones.items()}

    # facing: the hip line (right hip -> left hip) at the clip start should point +X (character faces -Y)
    rots0, pos0 = src_pose(frames[0])
    left = (pos0["LeftUpLeg"] - pos0["RightUpLeg"])
    yaw = math.atan2(left.y, left.x) + math.radians(clip.get("yaw_deg", 0.0))
    Ryaw = Matrix.Rotation(-yaw, 3, "Z")
    hip_ref = Ryaw @ pos0["Hips"]
    samples = []
    for f in frames:
        rots, pos = src_pose(f)
        samples.append((rots, pos))
    # autoloop [min_s, max_s]: cut at the frame whose body pose (joints relative to the hips) best matches the first frame,
    # so a walk loops on a whole stride and an idle loops without a pop
    if clip.get("autoloop"):
        lo_s, hi_s = clip["autoloop"]
        joints = [j for j in ("LeftFoot", "RightFoot", "LeftHand", "RightHand", "Head", "LeftLeg", "RightLeg", "LeftForeArm", "RightForeArm")
                  if j in samples[0][1]]
        def rel(p):
            return [Ryaw @ (p[j] - p["Hips"]) for j in joints]
        r0 = rel(samples[0][1])
        best, best_e = 1e9, len(samples) - 1
        for e in range(int(lo_s * a.fps), min(len(samples), int(hi_s * a.fps) + 1)):
            re_ = rel(samples[e][1])
            dist = sum((x - y).length_squared for x, y in zip(r0, re_))
            if dist < best:
                best, best_e = dist, e
        samples = samples[:best_e + 1]
    if clip.get("reverse"):                                    # PutDown = PickUp backwards
        samples = samples[::-1]
    if clip.get("pingpong"):                                   # a held lean breathes in and out and loops by construction
        samples = samples + samples[-2:0:-1]
    hp = [Ryaw @ p["Hips"] for _, p in samples]
    n = len(hp)
    # remove travel: linear trend in x/y (keeps sway); z keeps the bob around the clip's mean height
    dur = max((n - 1) / a.fps, 1e-6)
    travel = (hp[-1] - hp[0]) * ratio
    zmean = sum(p.z for p in hp) / n

    act = bpy.data.actions.new(clip["name"])
    act.use_fake_user = True
    tgt.animation_data_create()
    tgt.animation_data.action = act
    prev_q = {}
    rest_hips_head = tgt.data.bones[hips_t].head_local
    for i, (rots, pos) in enumerate(samples):
        fr = i + 1
        world = {}
        for b in order:
            t = b.name
            if t in MAP:
                s = MAP[t]
                world[t] = Ryaw @ rots[s] @ rest_s[s].inverted() @ corr[t] @ rest_t[t]
            elif b.parent is not None:
                world[t] = world[b.parent.name] @ (rest_t[b.parent.name].inverted() @ rest_t[t])
            else:
                world[t] = rest_t[t]
        for b in order:
            t = b.name
            pb = tgt.pose.bones[t]
            if b.parent is None:
                q = (rest_t[t].inverted() @ world[t]).to_quaternion()
            else:
                rel = rest_t[b.parent.name].inverted() @ rest_t[t]
                q = (rel.inverted() @ world[b.parent.name].inverted() @ world[t]).to_quaternion()
            if t in prev_q and prev_q[t].dot(q) < 0:
                q.negate()
            prev_q[t] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=fr, group=t)
        # hips translation (world delta -> the hips bone's rest frame, or its parent's posed frame for a root-parented pelvis)
        trend = hp[0] + (hp[-1] - hp[0]) * (i / max(n - 1, 1))
        d = (hp[i] - trend) * ratio
        d.z = (hp[i].z - zmean) * ratio
        if not clip.get("inplace", True):                     # travel clips keep their ground path (root motion)
            d = Vector(((hp[i] - hp[0]).x * ratio, (hp[i] - hp[0]).y * ratio, d.z))
        hb = tgt.data.bones[hips_t]
        frame_rot = rest_t[hips_t] if hb.parent is None else (world[hb.parent.name] @ (rest_t[hb.parent.name].inverted() @ rest_t[hips_t]))
        pbh = tgt.pose.bones[hips_t]
        pbh.location = frame_rot.inverted() @ d
        pbh.keyframe_insert("location", frame=fr, group=hips_t)
    # close loops: blend the last `blend` frames toward frame 1's pose
    if clip.get("loop", False):
        from bpy_extras import anim_utils
        cb = anim_utils.action_ensure_channelbag_for_slot(act, tgt.animation_data.action_slot)
        blend = min(int(clip.get("loop_blend", 8)), n // 3)
        for fc in cb.fcurves:
            kp = fc.keyframe_points
            first = kp[0].co.y
            for j in range(blend):
                idx = len(kp) - blend + j
                w = (j + 1) / blend
                w = w * w * (3 - 2 * w)
                kp[idx].co.y = kp[idx].co.y * (1 - w) + first * w
            fc.update()
    # foot slide on planted frames (world, target scale): foot height < 4 cm above its min and moving
    report.append({"clip": clip["name"], "bvh": clip["bvh"], "frames": n, "seconds": round(dur, 2),
                   "travel_mps": round(travel.length / dur, 3), "leg_ratio": round(ratio, 4), "yaw_deg": round(math.degrees(yaw), 1)})
    # drop the source
    for o in list(bpy.data.objects):
        if o not in before:
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.actions.remove(sact)

tgt.animation_data.action = None
for pb in tgt.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=a.out)
if a.export_glb:
    bpy.ops.export_scene.gltf(filepath=a.export_glb, export_format="GLB", export_animations=True, export_yup=True)
print("@@" + json.dumps({"ok": True, "map": len(MAP), "clips": report, "out": a.out, "glb": a.export_glb}))
