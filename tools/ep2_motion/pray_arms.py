"""Turn a kneeling clip into a PRAYER (founder 2026-10-25 section 4.4: "Minister Mike Dean praying" by the stranger's body): keep the mocap
body, spine and head, and bring both hands together in front of the chest with arm IK (targets parented to the Chest bone, so the
hands ride the body's sway), baked into the action's arm keys. Works on the game's townfolk rig.
  blender -b <anim.blend> --factory-startup -P pray_arms.py -- --actions Kneel --out-glb out.glb [--forward 0.24] [--down 0.06]
"""
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
acts = argv[argv.index("--actions") + 1].split(",")
RAMP = argv[argv.index("--ramp") + 1].split(",") if "--ramp" in argv else []      # actions whose hands come together over the clip
OUT = argv[argv.index("--out-glb") + 1]
FWD = float(argv[argv.index("--forward") + 1]) if "--forward" in argv else 0.24
DOWN = float(argv[argv.index("--down") + 1]) if "--down" in argv else 0.06

sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == "ARMATURE")
bones = arm.data.bones
chest = bones["Chest"]
# the character faces -Y (Blender): "in front of the chest" is -Y from the chest head, a little below it
targets = {}
for side, dx in (("L", 0.018), ("R", -0.018)):
    e = bpy.data.objects.new("Pray_" + side, None)
    sc.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = "Chest"
    # the empty's location is in the Chest bone's TAIL frame: place it in armature space, then convert
    want = arm.matrix_world @ (chest.head_local + Vector((dx, -FWD, -DOWN)))
    bpy.context.view_layer.update()
    e.matrix_world.translation = want
    targets[side] = e
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for side in ("L", "R"):
    pb = arm.pose.bones["Forearm." + side]
    c = pb.constraints.new("IK")
    c.name = "Pray_IK"
    c.target = targets[side]
    c.chain_count = 2
    c.use_tail = True
report = []
for name in acts:
    act = bpy.data.actions[name]
    arm.animation_data.action = act
    try:
        arm.animation_data.action_slot = act.slots[0]
    except Exception:
        pass
    f0, f1 = [int(v) for v in act.frame_range]
    sc.frame_start, sc.frame_end = f0, f1
    for side in ("L", "R"):                       # full prayer, or (a ramp clip) the hands coming together from free to joined
        c = arm.pose.bones["Forearm." + side].constraints["Pray_IK"]
        if c.id_data.animation_data is None:
            c.id_data.animation_data_create()
        c.influence = 0.0 if name in RAMP else 1.0
        if name in RAMP:
            c.keyframe_insert("influence", frame=f0 + int((f1 - f0) * 0.45))
            c.influence = 1.0
            c.keyframe_insert("influence", frame=f1)
    for pb in arm.pose.bones:
        want_sel = pb.name in ("UpperArm.L", "Forearm.L", "UpperArm.R", "Forearm.R", "Hand.L", "Hand.R")
        if hasattr(pb, "select"):
            pb.select = want_sel                     # Blender 5: selection lives on the pose bone
        else:
            pb.bone.select = want_sel
    bpy.ops.nla.bake(frame_start=f0, frame_end=f1, only_selected=True, visual_keying=True, clear_constraints=False,
                     use_current_action=True, bake_types={"POSE"})
    # the influence keys were only there to drive the bake: drop them from the clip
    try:
        from bpy_extras import anim_utils
        cb = anim_utils.action_ensure_channelbag_for_slot(act, arm.animation_data.action_slot)
        curves = cb.fcurves
    except Exception:
        curves = act.fcurves
    for fc in [fc for fc in curves if "constraints" in fc.data_path]:
        curves.remove(fc)
    report.append((name, f0, f1))
for side in ("L", "R"):
    pb = arm.pose.bones["Forearm." + side]
    for c in list(pb.constraints):
        if c.name == "Pray_IK":
            pb.constraints.remove(c)
bpy.ops.object.mode_set(mode="OBJECT")
for e in targets.values():
    bpy.data.objects.remove(e, do_unlink=True)
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animations=True, export_yup=True)
print("@@", report)
