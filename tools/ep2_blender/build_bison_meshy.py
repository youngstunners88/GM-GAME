"""The real American bison for the one-time stampede (founder 2026-11-02): Meshy's mesh on the game's horse bone names, with a baked gallop.
Meshy's rigger is humanoid-only, so the rig is done here: the horse.glb armature's bones (root/FL_/FR_/HL_/HR_/spine/neck1/neck2/head/tail)
are moved onto the bison's measured anatomy, the mesh is skinned by region + distance (Meshy shells are not watertight, heat weights fail),
and two clips are authored: `run` (a gallop, real-time at the herd's 10.5 m/s) and `stand`.
Headless:  blender -b --factory-startup -P tools/ep2_blender/build_bison_meshy.py -- <horse.glb> <meshy_bison_remesh.glb> <out bison.glb> [tex]
"""
import bpy, sys, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

a = sys.argv[sys.argv.index("--") + 1:]
HORSE, SRC, OUT = a[0], a[1], a[2]
TEX = int(a[3]) if len(a) > 3 else 1024
K = 1.27                 # measured model 1.376 m at the hump -> 1.75 m, a big bull's shoulder height
CYCLE = 0.56             # one gallop stride (s): about 5.9 m at 10.5 m/s
FPS = 24

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=HORSE)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH':
        bpy.data.objects.remove(o, do_unlink=True)
for act in list(bpy.data.actions):
    bpy.data.actions.remove(act)
if arm.animation_data:
    arm.animation_data_clear()
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=SRC)
obj = next(o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH')
for o in bpy.context.scene.objects:
    o.select_set(o == obj)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o not in before and o != obj:
        bpy.data.objects.remove(o, do_unlink=True)
obj.name = "BisonMesh"
arm.name = "BisonRig"
me = obj.data

# the head (Meshy -Y) onto the rig's +X, feet on z = 0, centred; the bones and the weights below are in this measured (unscaled) frame
me.transform(Matrix.Rotation(math.radians(90.0), 4, 'Z'))
mn = Vector((min(v.co.x for v in me.vertices), min(v.co.y for v in me.vertices), min(v.co.z for v in me.vertices)))
mx = Vector((max(v.co.x for v in me.vertices), max(v.co.y for v in me.vertices), max(v.co.z for v in me.vertices)))
me.transform(Matrix.Translation(Vector((-(mn.x + mx.x) / 2.0, -(mn.y + mx.y) / 2.0, -mn.z))))
me.update()

# bones: name -> (head, tail), measured against slices of the mesh
B = {
    "root": ((-0.25, 0, 0.85), (0.05, 0, 0.85)),
    "spine": ((-0.1, 0, 0.95), (0.3, 0, 1.0)),
    "neck1": ((0.34, 0, 0.88), (0.58, 0, 0.84)),
    "neck2": ((0.58, 0, 0.84), (0.74, 0, 0.76)),
    "head": ((0.74, 0, 0.76), (0.94, 0, 0.56)),
    "tail1": ((-0.92, 0, 0.9), (-0.95, 0, 0.62)),
    "tail2": ((-0.95, 0, 0.62), (-0.95, 0, 0.33)),
    "FL_up": ((0.28, 0.16, 0.82), (0.3, 0.17, 0.26)), "FL_lo": ((0.3, 0.17, 0.26), (0.28, 0.19, 0.12)), "FL_ho": ((0.28, 0.19, 0.12), (0.33, 0.2, 0.0)),
    "FR_up": ((0.24, -0.16, 0.82), (0.2, -0.17, 0.26)), "FR_lo": ((0.2, -0.17, 0.26), (0.14, -0.2, 0.12)), "FR_ho": ((0.14, -0.2, 0.12), (0.17, -0.2, 0.0)),
    "HL_up": ((-0.58, 0.16, 0.82), (-0.74, 0.15, 0.42)), "HL_lo": ((-0.74, 0.15, 0.42), (-0.71, 0.16, 0.12)), "HL_ho": ((-0.71, 0.16, 0.12), (-0.65, 0.18, 0.0)),
    "HR_up": ((-0.54, -0.16, 0.82), (-0.68, -0.15, 0.42)), "HR_lo": ((-0.68, -0.15, 0.42), (-0.65, -0.2, 0.12)), "HR_ho": ((-0.65, -0.2, 0.12), (-0.59, -0.22, 0.0)),
}
bpy.context.view_layer.objects.active = arm
for o in bpy.context.scene.objects:
    o.select_set(o == arm)
bpy.ops.object.mode_set(mode='EDIT')
for eb in arm.data.edit_bones:
    h, t = B[eb.name]
    eb.use_connect = False
for eb in arm.data.edit_bones:
    h, t = B[eb.name]
    eb.head = Vector(h)
    eb.tail = Vector(t)
    eb.roll = 0.0
bpy.ops.object.mode_set(mode='OBJECT')


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def seg_dist(p, name):
    h, t = (Vector(B[name][0]), Vector(B[name][1]))
    u = t - h
    k = max(0.0, min(1.0, (p - h).dot(u) / max(u.dot(u), 1e-9)))
    return (p - (h + u * k)).length


def blend(p, names, power=4.0):
    w = {n: 1.0 / max(seg_dist(p, n), 0.015) ** power for n in names}
    s = sum(w.values())
    return {n: x / s for n, x in w.items()}


def weights(p):
    # the tail: the thin strand behind the rump
    if p.x < -0.885 and abs(p.y) < 0.06:
        return blend(p, ["tail1", "tail2"])
    out = {}
    # neck and head own everything ahead of the shoulder, the beard included (it must not follow the front legs)
    nk = smooth(0.3, 0.46, p.x)
    if nk > 0.0:
        for n, x in blend(p, ["neck1", "neck2", "head"]).items():
            out[n] = out.get(n, 0.0) + x * nk
    rest = 1.0 - nk
    if rest <= 0.0:
        return out
    # a leg owns what hangs below the belly in its quarter; the upper end melts into the body
    front = -0.08 < p.x < 0.56
    hind = -0.95 < p.x <= -0.36
    legk = smooth(0.66, 0.44, p.z) if (front or hind) else 0.0
    if front:
        legk *= smooth(0.03, 0.11, abs(p.y))     # the chest between the forelegs stays on the body, or it stretches into a slab when they pass
    if legk > 0.0:
        side = ("FL" if p.y >= 0.0 else "FR") if front else ("HL" if p.y >= 0.0 else "HR")
        # by height, not by distance: the shaggy chaps are far wider than the bone and shear if they are shared, so they ride the upper bone whole
        knee = B[side + "_up"][1][2]
        lo = smooth(knee + 0.03, knee - 0.03, p.z)
        ho = smooth(0.13, 0.09, p.z)
        out[side + "_up"] = out.get(side + "_up", 0.0) + legk * rest * (1.0 - lo)
        out[side + "_lo"] = out.get(side + "_lo", 0.0) + legk * rest * lo * (1.0 - ho)
        out[side + "_ho"] = out.get(side + "_ho", 0.0) + legk * rest * lo * ho
    body = rest * (1.0 - legk)
    if body > 0.0:
        sp = smooth(-0.3, 0.1, p.x)
        out["spine"] = out.get("spine", 0.0) + body * sp
        out["root"] = out.get("root", 0.0) + body * (1.0 - sp)
    return out


groups = {b.name: obj.vertex_groups.new(name=b.name) for b in arm.data.bones}
for v in me.vertices:
    for n, x in weights(v.co).items():
        if x > 0.002:
            groups[n].add([v.index], x, 'REPLACE')

# real size: mesh and bones together
me.transform(Matrix.Scale(K, 4))
me.update()
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='EDIT')
for eb in arm.data.edit_bones:
    eb.head *= K
    eb.tail *= K
bpy.ops.object.mode_set(mode='OBJECT')
mod = obj.modifiers.new("Armature", 'ARMATURE')
mod.object = arm
obj.parent = arm
for poly in me.polygons:
    poly.use_smooth = True
me.update()

# textures: 1K base, half that for normal / metal-rough
for mat in me.materials:
    if mat is None or not mat.use_nodes:
        continue
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is not None:
        bsdf.inputs['Metallic'].default_value = 0.0
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            is_base = bsdf is not None and any(l.to_socket == bsdf.inputs['Base Color'] for l in n.outputs[0].links)
            s = TEX if is_base else TEX // 2
            if n.image.size[0] > s:
                n.image.scale(s, s)
            if is_base:
                # Meshy's coat is a bright tan that reads gold under the desert sun; the brief is a dark brown bison
                px = np.array(n.image.pixels[:], dtype=np.float32).reshape(-1, 4)
                luma = (px[:, :3] * (0.2126, 0.7152, 0.0722)).sum(axis=1, keepdims=True)
                px[:, :3] = (luma + (px[:, :3] - luma) * 0.72) * (0.5, 0.42, 0.38)
                n.image.pixels.foreach_set(px.ravel())
                n.image.update()

# clips. Forward is +X, up +Z, so a rotation about +Y swings a hanging leg BACK (-X); forward is negative.
sc = bpy.context.scene
sc.render.fps = FPS
arm.animation_data_create()
frames = int(round(CYCLE * FPS))


def pose_axis(pb, axis_world, angle):
    """Rotation of `angle` about a world axis, expressed in the bone's own rest frame."""
    local = (pb.bone.matrix_local.to_3x3().inverted() @ axis_world).normalized()
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = Quaternion(local, angle)


Y = Vector((0, 1, 0))
PHASE = {"HL": 0.0, "HR": 0.13, "FR": 0.52, "FL": 0.65}   # a transverse gallop: the hinds drive, the fronts land, then the moment of suspension


def key_all(frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    arm.pose.bones["root"].keyframe_insert("location", frame=frame)


def set_run(u):
    for leg, ph in PHASE.items():
        s = 2.0 * math.pi * (u + ph)
        fore = leg[0] == "F"
        reach = ((0.3 if math.sin(s) > 0.0 else 0.1) if fore else 0.55) * math.sin(s)           # + = forward of the hip
        lift = max(0.0, math.cos(s)) ** 1.5                       # the leg is coming forward: fold it clear of the ground
        pose_axis(arm.pose.bones[leg + "_up"], Y, -reach)
        # the shaggy foreleg barely swings at the shoulder: the shin does the reaching
        pose_axis(arm.pose.bones[leg + "_lo"], Y, (0.95 * lift - 0.35 * math.sin(s)) if fore else -0.85 * lift)
        pose_axis(arm.pose.bones[leg + "_ho"], Y, (0.5 if fore else 0.8) * lift)
    t = 2.0 * math.pi * u
    pose_axis(arm.pose.bones["root"], Y, 0.05 * math.sin(t + 0.6))
    pose_axis(arm.pose.bones["spine"], Y, 0.05 * math.sin(t + 2.2))
    pose_axis(arm.pose.bones["neck1"], Y, 0.07 * math.sin(t + 3.4))
    pose_axis(arm.pose.bones["neck2"], Y, 0.05 * math.sin(t + 3.9))
    pose_axis(arm.pose.bones["head"], Y, 0.05 * math.sin(t + 4.4))
    pose_axis(arm.pose.bones["tail1"], Y, 0.55 + 0.14 * math.sin(t))
    pose_axis(arm.pose.bones["tail2"], Y, 0.25 + 0.22 * math.sin(t - 0.9))
    arm.pose.bones["root"].location = (0.0, 0.0, 0.0)


run = bpy.data.actions.new("run")
run.use_fake_user = True
arm.animation_data.action = run
for f in range(frames + 1):
    set_run(float(f) / float(frames))
    key_all(f + 1)

stand = bpy.data.actions.new("stand")
stand.use_fake_user = True
arm.animation_data.action = stand
for pb in arm.pose.bones:
    pb.rotation_mode = 'QUATERNION'
    pb.rotation_quaternion = Quaternion()
    pb.location = (0, 0, 0)
key_all(1)
key_all(24)
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.rotation_quaternion = Quaternion()

for o in bpy.context.scene.objects:
    o.select_set(o in (arm, obj))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_image_format='JPEG', export_jpeg_quality=82,
                          export_animations=True, export_animation_mode='ACTIONS', export_skins=True, export_yup=True, export_apply=False)
print("BISON_OK", OUT, "tris", sum(len(p.vertices) - 2 for p in me.polygons), "clips", [x.name for x in bpy.data.actions],
      "frames", frames, "unweighted", sum(1 for v in me.vertices if not v.groups))
