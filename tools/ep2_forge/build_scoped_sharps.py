"""The founder's Sharps with a period telescopic sight (2026-11-05). Headless only:
  blender -b --factory-startup -P tools/ep2_forge/build_scoped_sharps.py -- <founder sharps.glb> <out.glb> [--ref <side.jpg>] [--case <diagonal.glb>] [--tris 40000] [--tex 1024]
      [--tube-len 0.56] [--rings 0.07,0.27]
Founder 2026-11-07, "the scope is too long": shipped with --tube-len 0.36 --rings -0.09,0.045. The eyepiece (Z_EYE) and the axis height do not move, so the
first-person eye anchor is unchanged; the tube ends over the receiver instead of halfway down the barrel, on a wrist mount and a receiver mount.

Body: his Tripo Sharps (the rifle in Rich's tab), laid along the case diagonal, turned to muzzle game +Z, up +Y, bore on y = 0, 1.21 m, origin at the trigger.
Sight: a long thin tube of the 1870s (Malcolm / Vollmer pattern) built here, not generated: 0.56 m, 22 mm tube, a flared eyepiece, a slightly larger objective, two brass
ring mounts on raised posts and no rail, so the optical axis is known exactly and sits clear of the hammer and the comb. Prints the anchors for Ep2ArmoryGunView.
"""
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
REF = a[a.index("--ref") + 1] if "--ref" in a else ""
CASE = a[a.index("--case") + 1] if "--case" in a else ""     # also write a copy laid along the case diagonal, for meshy_prop_to_game.py ... solid -> showcase/sharps.glb
TRIS = int(a[a.index("--tris") + 1]) if "--tris" in a else 40000
TEX = int(a[a.index("--tex") + 1]) if "--tex" in a else 1024
LENGTH = 1.21
TUBE_R = 0.011
TUBE_LEN = float(a[a.index("--tube-len") + 1]) if "--tube-len" in a else 0.56
RINGS = [float(v) for v in a[a.index("--rings") + 1].split(",")] if "--rings" in a else [0.07, 0.27]   # game z of the two ring mounts
CLEARANCE = 0.012        # eyepiece underside over the highest thing beneath it
LADDER_Z = (0.13, 0.30)  # game z along the barrel
LADDER_OVER = 0.027      # game y: just over the barrel's top flat (+0.023)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and len(o.data.materials) > 0]
for o in list(bpy.context.scene.objects):
    if o not in meshes:
        bpy.data.objects.remove(o, do_unlink=True)
obj = meshes[0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for mat in obj.data.materials:
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            base = any(l.to_socket == bsdf.inputs['Base Color'] for l in n.outputs[0].links)
            s = TEX if base else TEX // 2
            if n.image.size[0] > s:
                n.image.scale(s, s)

# the case diagonal -> muzzle -Y (= game +Z)
obj.data.transform(Matrix.Rotation(math.pi * 0.25, 4, 'Z'))
co = np.array([v.co[:] for v in obj.data.vertices])
along = -co[:, 1]
span = float(along.max() - along.min())
xs, zs, ms = [], [], []
for t in np.linspace(0.70, 0.92, 9):
    m = np.abs(along - (along.min() + t * span)) < 0.012 * span
    if m.sum() > 6:
        ms.append(along.min() + t * span)
        zs.append((co[m, 2].min() + co[m, 2].max()) * 0.5)
        xs.append((co[m, 0].min() + co[m, 0].max()) * 0.5)
pitch = math.atan(np.polyfit(ms, zs, 1)[0])
yaw = math.atan(np.polyfit(ms, xs, 1)[0])
print("BORE tilt deg: pitch %.2f yaw %.2f" % (math.degrees(pitch), math.degrees(yaw)))
obj.data.transform(Matrix.Rotation(pitch, 4, 'X'))           # along = -y, so a positive slope is undone by a positive turn about X
obj.data.transform(Matrix.Rotation(-yaw, 4, 'Z'))

co = np.array([v.co[:] for v in obj.data.vertices])
along = -co[:, 1]
k = LENGTH / float(along.max() - along.min())
obj.data.transform(Matrix.Scale(k, 4))
co *= k
along = -co[:, 1]
rear = float(along.min())
m = np.abs(along - (rear + 0.8 * LENGTH)) < 0.012 * LENGTH
bore = Vector(((co[m, 0].min() + co[m, 0].max()) * 0.5, 0.0, (co[m, 2].min() + co[m, 2].max()) * 0.5))
# game z = 0 at 0.38 of the length from the butt: the trigger of a 1874 (13 5/8 in pull on a 47 in rifle is ~0.29, the rest is the receiver)
obj.data.transform(Matrix.Translation(Vector((-bore.x, rear + 0.38 * LENGTH, -bore.z))))
obj.data.update()

# the raised ladder sight stands 0.11 m off the barrel, right under the tube: a scoped rifle does not carry it (a face whose middle is over the barrel's top flat, there)
bm = bmesh.new()
bm.from_mesh(obj.data)
ladder = [f for f in bm.faces if LADDER_Z[0] < -f.calc_center_median().y < LADDER_Z[1] and f.calc_center_median().z > LADDER_OVER]
print("LADDER faces removed", len(ladder))
bmesh.ops.delete(bm, geom=ladder, context='FACES')
bm.to_mesh(obj.data)
bm.free()
obj.data.update()

co = np.array([v.co[:] for v in obj.data.vertices])
g = np.c_[co[:, 0], co[:, 2], -co[:, 1]]
print("BODY min", g.min(0).round(3).tolist(), "max", g.max(0).round(3).tolist())
for z0 in np.arange(g[:, 2].min(), g[:, 2].max(), 0.08):
    m = (g[:, 2] >= z0) & (g[:, 2] < z0 + 0.08)
    if m.any():
        print(" z%+.2f y[%+.3f %+.3f] x[%+.3f %+.3f]" % (z0, g[m, 1].min(), g[m, 1].max(), g[m, 0].min(), g[m, 0].max()))

tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
print("BODY tris", tris)
if tris > TRIS - 3000:
    mod = obj.modifiers.new("dec", 'DECIMATE')
    mod.ratio = (TRIS - 3000) / tris
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
obj.name = "Gun"
obj.data.name = "Gun"


def material(name: str, rgb: tuple, metal: float, rough: float) -> bpy.types.Material:
    mt = bpy.data.materials.new(name)
    mt.use_nodes = True
    b = next(n for n in mt.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*rgb, 1.0)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    return mt


BLUED = material("ScopeBlued", (0.035, 0.04, 0.05), 0.85, 0.42)
BRASS = material("ScopeBrass", (0.62, 0.42, 0.14), 0.9, 0.36)
LENS = material("ScopeLens", (0.02, 0.05, 0.09), 0.2, 0.08)


def lathe(name: str, profile: list, mat: bpy.types.Material, segs: int = 28) -> bpy.types.Object:
    """A solid of revolution about the bore-parallel axis: profile = [(game z, radius)], closed at both ends."""
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        rings.append([bm.verts.new((r * math.cos(TAU * i / segs), -z, r * math.sin(TAU * i / segs))) for i in range(segs)])
    for p, q in zip(rings, rings[1:]):
        for i in range(segs):
            bm.faces.new((p[i], p[(i + 1) % segs], q[(i + 1) % segs], q[i]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    return o


def box(name: str, size: tuple, at: tuple, mat: bpy.types.Material) -> bpy.types.Object:
    """A box given in game axes (x, y, z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(size[0], size[2], size[1]), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(at[0], -at[2], at[1]), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    return o


TAU = math.tau
# the tube's reach: eyepiece 0.09 m behind the receiver (its rear is at z -0.13), objective out over the barrel
Z_EYE = -0.22
Z_OBJ = Z_EYE + TUBE_LEN
BELL_EYE = 0.0185
BELL_OBJ = 0.0165
under = (g[:, 2] > Z_EYE - 0.02) & (g[:, 2] < Z_OBJ + 0.02) & (np.abs(g[:, 0]) < BELL_EYE + 0.01)
top = float(g[under, 1].max())
at_top = g[under][np.argmax(g[under, 1])]
AXIS = max(top + BELL_EYE + CLEARANCE, 0.055)
print("SIGHT highest thing under the tube y %.3f at z %.3f; axis height %.3f" % (top, at_top[2], AXIS))

parts = []
tube = lathe("ScopeTube", [
    (Z_EYE, 0.0), (Z_EYE, BELL_EYE - 0.003), (Z_EYE + 0.006, BELL_EYE), (Z_EYE + 0.05, BELL_EYE), (Z_EYE + 0.07, TUBE_R + 0.0015), (Z_EYE + 0.075, TUBE_R),
    (Z_OBJ - 0.075, TUBE_R), (Z_OBJ - 0.05, BELL_OBJ), (Z_OBJ - 0.004, BELL_OBJ), (Z_OBJ, BELL_OBJ - 0.002), (Z_OBJ, 0.0)], BLUED)
parts.append(tube)
# brass collars at the eyepiece, the objective and the focus draw
for i, z in enumerate([Z_EYE + 0.052, Z_EYE + 0.14, Z_OBJ - 0.056]):
    r = (BELL_EYE if i == 0 else (TUBE_R if i == 1 else BELL_OBJ)) + 0.0012
    parts.append(lathe("ScopeCollar%d" % i, [(z - 0.005, r - 0.0012), (z - 0.005, r), (z + 0.005, r), (z + 0.005, r - 0.0012)], BRASS))
# the two lenses: set just inside the rims, a dark glass disc
parts.append(lathe("ScopeLensEye", [(Z_EYE - 0.0005, 0.0), (Z_EYE - 0.0005, BELL_EYE - 0.0045)], LENS))
parts.append(lathe("ScopeLensObj", [(Z_OBJ + 0.0005, 0.0), (Z_OBJ + 0.0005, BELL_OBJ - 0.004)], LENS))
# two ring mounts on raised posts, feet on the receiver ring (ahead of the hammer) and on the barrel, no rail
for i, z in enumerate(RINGS):
    assert Z_EYE + 0.083 <= z <= Z_OBJ - 0.06, "ring %d at z %.3f is off the tube" % (i, z)
    parts.append(lathe("ScopeRing%d" % i, [(z - 0.008, TUBE_R), (z - 0.008, TUBE_R + 0.004), (z + 0.008, TUBE_R + 0.004), (z + 0.008, TUBE_R)], BRASS))
    near = (np.abs(g[:, 2] - z) < 0.006) & (np.abs(g[:, 0]) < 0.012)     # a narrow window: a wide one reads the hammer's nose, and the foot floats
    foot = float(g[near, 1].max()) if near.any() else 0.012
    h = AXIS - TUBE_R - foot + 0.004
    parts.append(box("ScopePost%d" % i, (0.009, h, 0.014), (0.0, foot + h * 0.5 - 0.002, z), BRASS))
    parts.append(box("ScopeFoot%d" % i, (0.018, 0.005, 0.03), (0.0, foot + 0.001, z), BLUED))
for p in parts:
    if not p.name.startswith("ScopePost") and not p.name.startswith("ScopeFoot"):
        p.location = (0.0, 0.0, AXIS)

print("ANCHOR scope_eye", [0.0, round(AXIS, 4), round(Z_EYE, 4)], "objective_z", round(Z_OBJ, 4), "muzzle_z", round(float(g[:, 2].max()), 3))
print("ANCHOR lens_radius eye", round(BELL_EYE - 0.0045, 4), "total tris", sum(sum(len(pl.vertices) - 2 for pl in o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH'))

for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False, export_image_format='JPEG', export_jpeg_quality=82,
                          export_apply=True, export_animations=False)

if CASE:
    for o in bpy.context.scene.objects:
        o.matrix_world = Matrix.Rotation(-math.pi * 0.25, 4, 'Z') @ o.matrix_world
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=CASE, export_format='GLB', use_selection=False, export_image_format='JPEG', export_jpeg_quality=82,
                              export_apply=True, export_animations=False)
    for o in bpy.context.scene.objects:
        o.matrix_world = Matrix.Rotation(math.pi * 0.25, 4, 'Z') @ o.matrix_world
    bpy.context.view_layer.update()

if REF:
    s = bpy.context.scene
    ids = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    s.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in ids else 'BLENDER_EEVEE_NEXT'
    s.render.resolution_x, s.render.resolution_y = 1600, 800
    s.render.image_settings.file_format = 'JPEG'
    s.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (.8, .8, .8, 1)
    s.world = w
    cam = bpy.data.cameras.new("c")
    cam.type = 'ORTHO'
    cam.ortho_scale = LENGTH * 1.08
    co_cam = bpy.data.objects.new("c", cam)
    s.collection.objects.link(co_cam)
    s.camera = co_cam
    centre_y = -(float(g[:, 2].max()) + float(g[:, 2].min())) * 0.5
    co_cam.location = (3.0, centre_y, 0.0)      # from +X: muzzle (-Y) to the image's left
    co_cam.rotation_euler = Vector((-1, 0, 0)).to_track_quat('-Z', 'Y').to_euler()
    s.render.filepath = REF
    bpy.ops.render.render(write_still=True)
