"""Author bear-specific combat + locomotion clips on the shipping bear rig (headless Blender).

blender -b --python tools/ep2_blender/build_bear_combat_clips.py -- <bear_rigged.glb> <out_clips.glb> [stills_dir]

Clips (30 fps, armature-only GLB, same bone names + rest as bear_rigged.glb so Ep2Actor.add_all_clips merges them):
  Bear_Walk   loop 1.2 s  lumbering shuffle: hips sway, heavy stride, counter-swinging arms, head roll
  Bear_Run    loop 0.6 s  charge: torso pitched forward, forelimbs reach and bound with the legs, head low
  Bear_Swipe  one-shot    rear up, cock the striking paw high, then a fast diagonal claw slash with a body twist
  Bear_Bite   one-shot    draw back, lunge head-first with paws grabbing, shake the head side to side, release

Authoring frame (world axes of the armature, character faces -Y, up +Z, character left = +X, T-pose rest):
every bone gets an extra world-axes rotation `d` (Euler ZYX degrees: Z first, then Y, then X) on top of its parent's
accumulated rotation, converted to the bone's local frame: L = R^-1 (Wp^-1 d Wp) R  (R = bone rest rotation).
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[0], args[1]
STILLS = args[2] if len(args) > 2 else ""
FPS = 30

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS            # glTF timestamps = frame / scene fps; Godot plays them in seconds
bpy.context.scene.render.fps_base = 1.0
bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
for o in [o for o in bpy.data.objects if o.type == "MESH" and o.name != "char1"]:
    bpy.data.objects.remove(o, do_unlink=True)          # the stray Icosphere
body = bpy.data.objects.get("char1")
for a in list(bpy.data.actions):
    bpy.data.actions.remove(a)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
PB = arm.pose.bones
REST = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
PARENT = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
ORDER = []                                  # parents before children
for b in arm.data.bones:
    if b.parent is None:
        ORDER.append(b.name)
i = 0
while i < len(ORDER):
    for c in arm.data.bones[ORDER[i]].children:
        ORDER.append(c.name)
    i += 1


def d_mat(v):
    return Euler((math.radians(v[0]), math.radians(v[1]), math.radians(v[2])), "ZYX").to_matrix()


def apply_pose(pose, hips_cm=(0.0, 0.0, 0.0)):
    """pose: bone -> (rx, ry, rz) world-axes degrees. Children inherit the parent's accumulated rotation."""
    W = {}
    for n in ORDER:
        p = PARENT[n]
        Wp = W[p] if p else Matrix.Identity(3)
        d = d_mat(pose.get(n, (0, 0, 0)))
        W[n] = d @ Wp
        local = REST[n].inverted() @ (Wp.inverted() @ d @ Wp) @ REST[n]
        pb = PB[n]
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = local.to_quaternion()
        if n == "Hips":
            pb.location = REST[n].inverted() @ Vector(hips_cm)


def key(frame):
    for n in ORDER:
        PB[n].keyframe_insert("rotation_quaternion", frame=frame)
    PB["Hips"].keyframe_insert("location", frame=frame)


def make_action(name, frames, fn, loop):
    act = bpy.data.actions.new(name)
    arm.animation_data_create().action = act
    for f in frames:
        pose, hips = fn(f)
        apply_pose(pose, hips)
        key(f)
    act.use_fake_user = True
    act["loop"] = loop
    return act


def lerp(a, b, t):
    return a + (b - a) * t


def blend(p, q, t):
    out = {}
    for n in set(p) | set(q):
        a, b = p.get(n, (0, 0, 0)), q.get(n, (0, 0, 0))
        out[n] = tuple(lerp(a[i], b[i], t) for i in range(3))
    return out


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---- stand pose: hunched, arms hanging forward a little, elbows soft -------------------------------------------
def stand():
    return {
        "Spine02": (5, 0, 0), "Spine01": (5, 0, 0), "Spine": (4, 0, 0),
        "neck": (-7, 0, 0), "Head": (-3, 0, 0),
        "LeftArm": (-12, 68, 0), "RightArm": (-12, -68, 0),
        "LeftForeArm": (-26, 0, 0), "RightForeArm": (-26, 0, 0),
    }


def add(p, n, v):
    a = p.get(n, (0, 0, 0))
    p[n] = (a[0] + v[0], a[1] + v[1], a[2] + v[2])


# ---- Bear_Walk ---------------------------------------------------------------------------------------------------
def walk(f):
    t = f / 36.0
    s, c = math.sin(2 * math.pi * t), math.cos(2 * math.pi * t)
    p = stand()
    for side, sg, arm_sg in (("Left", 1.0, 1.0), ("Right", -1.0, -1.0)):
        ss, cc = s * sg, c * sg                         # right leg runs half a cycle behind
        hip = 30.0 * ss                                 # forward swing (deg)
        knee = 10.0 + 44.0 * max(0.0, cc) ** 2
        p[side + "UpLeg"] = (-hip, 0, 0)
        p[side + "Leg"] = (knee, 0, 0)
        p[side + "Foot"] = (hip - knee + 6.0 * max(0.0, -ss), 0, 0)
        # arms counter-swing: the arm opposite the forward leg comes forward
        add(p, side + "Arm", (16.0 * ss, 0, 0))
        add(p, side + "ForeArm", (-6.0 * max(0.0, -ss), 0, 0))
    add(p, "Spine02", (0, 0, -9 * s))
    add(p, "Spine01", (0, 0, -3 * s))
    add(p, "Hips", (0, 3.0 * s, 5.0 * s))
    add(p, "neck", (0, 0, 4 * s))
    add(p, "Head", (2.0 * math.cos(4 * math.pi * t), 0, 0))
    hips = (-2.2 * s, 0.0, -1.0 - 2.0 * math.cos(4 * math.pi * t))
    return p, hips


# ---- Bear_Run (all-fours charge feel) ----------------------------------------------------------------------------
def run(f):
    t = f / 18.0
    s, c = math.sin(2 * math.pi * t), math.cos(2 * math.pi * t)
    p = {
        "Hips": (14 + 3 * c, 0, 3 * s),
        "Spine02": (13, 0, -4 * s), "Spine01": (12, 0, -3 * s), "Spine": (10, 0, 0),
        "neck": (-26 - 3 * c, 0, 0), "Head": (-8 + 3 * c, 0, 0),
    }
    for side, sg in (("Left", 1.0), ("Right", -1.0)):
        # forelimbs bound together (reach forward and down, sweep back), a touch of left/right offset
        reach = 0.5 + 0.5 * c                            # 1 = full reach forward
        a = lerp(50, 82, reach)                          # forepaw swing toward the front (Z about world up)
        p[side + "Arm"] = (lerp(88, 52, reach), 0, -sg * a)
        p[side + "ForeArm"] = (lerp(-6, -22, reach), 0, 0)
        # hind legs drive in anti-phase with the arms, slight L/R stagger
        ph = 2 * math.pi * t + (0.5 if side == "Right" else 0.0) * 0.5
        hipsw = 30.0 * math.cos(ph + math.pi)
        p[side + "UpLeg"] = (-hipsw + 10, 0, 0)
        p[side + "Leg"] = (24 + 26 * max(0.0, math.sin(ph)), 0, 0)
        p[side + "Foot"] = (hipsw - 24 - 10, 0, 0)
    hips = (0.0, -4.0 * c, -12.0 + 5.0 * math.cos(4 * math.pi * t))
    return p, hips


# ---- Bear_Swipe ----------------------------------------------------------------------------------------------------
def swipe_keys():
    base = stand()
    rear = stand()                                       # rear up, cock the right paw high and back
    for n, v in (("Spine02", (-9, 0, -4)), ("Spine01", (-10, 0, -5)), ("Spine", (-8, 0, -4)),
                 ("neck", (9, 0, 4)), ("Head", (8, 0, 0)), ("Hips", (-4, 0, -3)),
                 ("RightArm", (-35, 100, 0)), ("RightForeArm", (-30, 0, 0)),
                 ("LeftArm", (22, 0, -62)), ("LeftForeArm", (-20, 0, 0)),
                 ("RightUpLeg", (0, 0, 0)), ("LeftUpLeg", (0, 0, 0))):
        rear[n] = v
    hit = stand()                                        # the slash lands: forward and down across the front
    for n, v in (("Spine02", (13, 0, 7)), ("Spine01", (14, 0, 8)), ("Spine", (12, 0, 7)),
                 ("neck", (14, 0, -4)), ("Head", (12, 0, -2)), ("Hips", (8, 0, 4)),
                 ("RightArm", (58, 0, 96)), ("RightForeArm", (-12, 0, 0)),
                 ("LeftArm", (-18, 52, 0)), ("LeftForeArm", (-30, 0, 0)),
                 ("LeftUpLeg", (-14, 0, 0)), ("LeftLeg", (18, 0, 0)), ("LeftFoot", (-4, 0, 0)),
                 ("RightUpLeg", (10, 0, 0)), ("RightLeg", (10, 0, 0)), ("RightFoot", (-20, 0, 0))):
        hit[n] = v
    return base, rear, hit


def swipe(f):
    base, rear, hit = swipe_keys()
    # 0-9 rise + cock, 9-11 hold, 11-15 strike, 15-19 impact hold, 19-36 recover
    if f <= 9:
        p, h = blend(base, rear, smooth(f / 9.0)), (0, lerp(0, 4, smooth(f / 9.0)), lerp(0, -3, smooth(f / 9.0)))
    elif f <= 11:
        p, h = rear, (0, 4, -3)
    elif f <= 15:
        t = (f - 11) / 4.0
        p, h = blend(rear, hit, t ** 1.6), (0, lerp(4, -14, t), lerp(-3, -6, t))
    elif f <= 19:
        p, h = hit, (0, -14 - (f - 15) * 0.6, -6)
    else:
        t = smooth((f - 19) / 17.0)
        p, h = blend(hit, base, t), (0, lerp(-16, 0, t), lerp(-6, 0, t))
    return p, h


# ---- Bear_Bite -------------------------------------------------------------------------------------------------------
def bite(f):
    base = stand()
    draw = stand()
    for n, v in (("Spine02", (-7, 0, 0)), ("Spine01", (-8, 0, 0)), ("Spine", (-6, 0, 0)),
                 ("neck", (20, 0, 0)), ("Head", (12, 0, 0)), ("Hips", (-3, 0, 0)),
                 ("LeftArm", (-6, -52, -8)), ("RightArm", (-6, 52, 8)),          # paws raised, elbows folded: a bear rearing to bite
                 ("LeftForeArm", (-35, 0, -45)), ("RightForeArm", (-35, 0, 45))):
        draw[n] = v
    lunge = stand()
    for n, v in (("Spine02", (8, 0, 0)), ("Spine01", (9, 0, 0)), ("Spine", (7, 0, 0)),
                 ("neck", (20, 0, 0)), ("Head", (14, 0, 0)), ("Hips", (4, 0, 0)),
                 ("LeftArm", (18, 0, -52)), ("RightArm", (18, 0, 52)),
                 ("LeftForeArm", (-14, 0, 0)), ("RightForeArm", (-14, 0, 0)),
                 ("LeftUpLeg", (-16, 0, 0)), ("LeftLeg", (20, 0, 0)), ("LeftFoot", (-2, 0, 0)),
                 ("RightUpLeg", (8, 0, 0)), ("RightLeg", (12, 0, 0)), ("RightFoot", (-18, 0, 0))):
        lunge[n] = v
    if f <= 9:
        t = smooth(f / 9.0)
        return blend(base, draw, t), (0, lerp(0, 6, t), lerp(0, -2, t))
    if f <= 13:
        t = (f - 9) / 4.0
        return blend(draw, lunge, t ** 1.5), (0, lerp(6, -17, t), lerp(-2, -7, t))
    if f <= 27:
        k = f - 13                                       # worry the bite: fast head shake, torso shudder
        yaw = 24.0 * math.sin(k * math.pi * 0.62) * (1.0 - k / 22.0)
        p = dict(lunge)
        p["Head"] = (14 + 4 * math.sin(k * 1.9), 0, yaw)
        p["neck"] = (20, 0, yaw * 0.55)
        p["Spine"] = (7, 0, yaw * -0.18)
        p["Spine01"] = (9, 0, yaw * -0.12)
        return p, (0.8 * math.sin(k * 1.9), -17, -7)
    t = smooth((f - 27) / 9.0)
    return blend(lunge, base, t), (0, lerp(-17, 0, t), lerp(-7, 0, t))


CLIPS = [("Bear_Walk", range(0, 37), walk, True), ("Bear_Run", range(0, 19), run, True),
         ("Bear_Swipe", range(0, 37), swipe, False), ("Bear_Bite", range(0, 37), bite, False)]
for name, frames, fn, loop in CLIPS:
    make_action(name, frames, fn, loop)
    print("clip", name, len(frames))

# ---- stills for visual review -----------------------------------------------------------------------------------------
if STILLS:
    os.makedirs(STILLS, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 480, 480
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.18, 0.2, 0.25)
    cam_d = bpy.data.cameras.new("c")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = 2.9
    cam = bpy.data.objects.new("c", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    shots = [("Bear_Swipe", [0, 9, 13, 17, 28]), ("Bear_Bite", [0, 9, 13, 18, 22]),
             ("Bear_Walk", [0, 9, 18, 27]), ("Bear_Run", [0, 5, 9, 14])]
    for clip, fr in shots:
        arm.animation_data.action = bpy.data.actions[clip]
        for f in fr:
            sc.frame_set(f)
            for view, loc, rot in (("side", (-6.0, 0, 1.1), (math.pi / 2, 0, -math.pi / 2)),
                                   ("front", (0, -6.0, 1.1), (math.pi / 2, 0, 0))):
                cam.location = Vector(loc)
                cam.rotation_euler = rot
                sc.render.filepath = os.path.join(STILLS, "%s_%02d_%s.png" % (clip, f, view))
                bpy.ops.render.render(write_still=True)
    print("stills done")

# ---- export armature-only animation GLB ------------------------------------------------------------------------------
if body is not None:
    bpy.data.objects.remove(body, do_unlink=True)
for a in bpy.data.actions:
    a.use_fake_user = True
bpy.ops.object.mode_set(mode="OBJECT")
arm.animation_data.action = list(bpy.data.actions)[0]
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animations=True,
                          export_animation_mode="ACTIONS", export_skins=True, export_apply=False,
                          export_force_sampling=True, export_optimize_animation_size=False,
                          export_anim_single_armature=True)
print("export done", OUT, os.path.getsize(OUT))
