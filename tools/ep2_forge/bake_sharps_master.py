"""THE Sharps (founder 2026-11-23: "Sharps Improved" is the master for all three uses). Headless only:
  blender -b --factory-startup -P tools/ep2_forge/bake_sharps_master.py -- <Sharps Improved.glb> <out_dir> [--probe] [--scope-len 0.30]
      [--tris-held 22000] [--tris-low 2400] [--tex 1024]
Writes, all from the one mesh, so the held rifle, the lit case and Rich's hand are the same gun (same silhouette, scope, wood and metal):
  <out_dir>/sharps_scoped.glb    Lil Blunt's first-person rifle: muzzle game +Z, up +Y, bore on y = 0, 1.21 m, origin at the trigger
  (the lit case and Rich's hand load sharps_scoped.glb itself: one file, so it cannot drift)
  <out_dir>/sharps_1874.glb      a low LOD laid muzzle +X (the shop's fallback case piece)
The founder's rifle carries its own brass scope, so no sight is generated. --scope-len shortens the tube by squeezing its middle along the bore (the bells,
rings and mounts keep their shape) so the eyepiece sits forward of the eye. Prints ANCHOR lines for Ep2ArmoryGunView / Ep2ArmoryPose (game frame).
"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1].rstrip("/")
PROBE = "--probe" in a
def arg(k, d): return type(d)(a[a.index(k) + 1]) if k in a else d
SCOPE_LEN = arg("--scope-len", 0.0)
TRIS_HELD = arg("--tris-held", 13000)
TRIS_LOW = arg("--tris-low", 1600)
TEX = arg("--tex", 1024)
LENGTH = 1.21

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and len(o.data.materials) > 0)
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 2M tris: a first collapse to ~150k keeps every edge the bake needs and makes the rest fast
def decimate(o, target):
    n = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if n > target:
        m = o.modifiers.new("dec", 'DECIMATE')
        m.ratio = target / n
        m.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)
    return sum(len(p.vertices) - 2 for p in o.data.polygons)
print("SRC tris", decimate(obj, 150000) if not PROBE else sum(len(p.vertices) - 2 for p in obj.data.polygons))

# laid along the case diagonal like his first Sharps -> muzzle -Y (= game +Z)
obj.data.transform(Matrix.Rotation(math.pi * 0.25, 4, 'Z'))
def game():
    co = np.array([v.co[:] for v in obj.data.vertices])
    return np.c_[co[:, 0], co[:, 2], -co[:, 1]]      # game x, y, z
g = game()
if (g[:, 2].max() - np.median(g[:, 2])) < (np.median(g[:, 2]) - g[:, 2].min()):
    pass
span = g[:, 2].max() - g[:, 2].min()
# which end is the muzzle: the thin end. Slice thickness near each end.
def thick(z0, z1):
    m = (g[:, 2] >= z0) & (g[:, 2] <= z1)
    return (g[m, 1].max() - g[m, 1].min()) if m.any() else 9.0
lo, hi = g[:, 2].min(), g[:, 2].max()
if thick(lo, lo + 0.08 * span) < thick(hi - 0.08 * span, hi):
    obj.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
    print("FLIP muzzle was at -Z")
    g = game()
# the bore from the barrel's UNDERSIDE and width (the scope rides above the barrel, so slice mid-heights lie)
def bore_fit(g):
    span = g[:, 2].max() - g[:, 2].min()
    zs, ys, xs = [], [], []
    for t in np.linspace(0.72, 0.95, 10):
        z = g[:, 2].min() + t * span
        m = np.abs(g[:, 2] - z) < 0.006 * span
        if m.sum() < 8:
            continue
        sl = g[m]
        low = sl[:, 1].min()
        ring = sl[sl[:, 1] < low + 0.045]                  # the barrel only: within 4.5 cm of its underside
        w = ring[:, 0].max() - ring[:, 0].min()
        zs.append(z); ys.append(low + w * 0.5); xs.append((ring[:, 0].max() + ring[:, 0].min()) * 0.5)
    return np.array(zs), np.array(ys), np.array(xs)
zs, ys, xs = bore_fit(g)
pitch = math.atan(np.polyfit(zs, ys, 1)[0])
yaw = math.atan(np.polyfit(zs, xs, 1)[0])
print("BORE tilt deg: pitch %.2f yaw %.2f" % (math.degrees(pitch), math.degrees(yaw)))
# game y up = blender z; game z = -blender y. Undo pitch (rotate about X) and yaw (about blender Z)
obj.data.transform(Matrix.Rotation(pitch, 4, 'X'))     # game y = blender z, game z = -blender y: a rising barrel (dy/dz > 0) is undone by +pitch about X
obj.data.transform(Matrix.Rotation(-yaw, 4, 'Z'))
g = game()
zs, ys, xs = bore_fit(g)
print("BORE after: dy/dz %.4f dx/dz %.4f" % (np.polyfit(zs, ys, 1)[0], np.polyfit(zs, xs, 1)[0]))
k = LENGTH / float(g[:, 2].max() - g[:, 2].min())
obj.data.transform(Matrix.Scale(k, 4))
g = game()
zs, ys, xs = bore_fit(g)
rear = float(g[:, 2].min())
bore_y, bore_x = float(np.mean(ys)), float(np.mean(xs))
# game z = 0 at 0.38 of the length from the butt (the trigger), bore on y = 0, axis on x = 0
obj.data.transform(Matrix.Translation(Vector((-bore_x, rear + 0.38 * LENGTH, -bore_y))))
obj.data.update()
g = game()
print("BODY min", g.min(0).round(3).tolist(), "max", g.max(0).round(3).tolist(), "barrel r %.4f" % (float(np.mean(ys)) - 0.0 if False else 0.0))

def profile(g, step=0.04):
    for z0 in np.arange(g[:, 2].min(), g[:, 2].max(), step):
        m = (g[:, 2] >= z0) & (g[:, 2] < z0 + step)
        if m.any():
            hi_ = g[m & (g[:, 1] > 0.03)]
            print(" z%+.2f y[%+.3f %+.3f] x[%+.3f %+.3f] above3cm n=%d%s" % (z0, g[m, 1].min(), g[m, 1].max(), g[m, 0].min(), g[m, 0].max(), len(hi_),
                  (" y[%+.3f %+.3f]" % (hi_[:, 1].min(), hi_[:, 1].max())) if len(hi_) else ""))

# the scope: everything above the barrel/receiver top. Find the tube's axis from the highest band's slices
def scope_axis(g):
    zz, cy, top, bot = [], [], [], []
    for z0 in np.arange(-0.4, 0.75, 0.01):
        m = (np.abs(g[:, 2] - z0) < 0.005) & (np.abs(g[:, 0]) < 0.04)
        if m.sum() < 6:
            continue
        sl = g[m]
        t = sl[:, 1].max()
        band = sl[sl[:, 1] > t - 0.05]
        zz.append(z0); top.append(t)
    return np.array(zz), np.array(top)
zz, top = scope_axis(g)
print("TOP line (z, top y):", " ".join("%.2f:%.3f" % (z, t) for z, t in zip(zz[::3], top[::3])))
def mounts(g, tube_bottom):
    for z0 in np.arange(-0.30, 0.40, 0.01):
        m = (np.abs(g[:, 2] - z0) < 0.005) & (np.abs(g[:, 0]) < 0.03) & (g[:, 1] > 0.065) & (g[:, 1] < tube_bottom - 0.004)
        m = (np.abs(g[:, 2] - z0) < 0.005) & (np.abs(g[:, 0]) < 0.03) & (g[:, 1] > -0.01)
        h = np.histogram(g[m, 1], bins=24, range=(-0.01, 0.11))[0]
        print(" occ z%+.2f %s" % (z0, "".join("#" if c > 0 else "." for c in h)))
if PROBE:
    profile(g)
    mounts(g, float(np.median(top[(zz > -0.15) & (zz < 0.3)])) - 0.03)
    sys.exit(0)

# --- the founder's scope (measured 2026-11-23 on Sharps Improved): a 0.54 m brass tube, eyepiece z -0.22, objective +0.32, axis y ~0.077,
# r ~0.022, on three posts (z ~ -0.14, 0.00, +0.13) standing on the receiver/barrel top (y <= 0.025). The founder called a long tube "too long" and
# one 3 cm from the eye "would take a person's eye out": cut the posts, shorten the PLAIN tube (the two bells keep their shape), slide it so the
# eyepiece is at EYEPIECE_Z, and stand it on two new brass posts.
RIFLE_TOP = 0.025          # receiver / barrel top: below this nothing is the scope
TUBE_FLOOR = 0.04          # after the posts go, every vertex over this (inside the scope's z span) is the tube
EYEPIECE_Z = arg("--eyepiece-z", -0.14)
over = top > 0.06
runs, start = [], None
for i, f in enumerate(over):
    if f and start is None: start = i
    if (not f or i == len(over) - 1) and start is not None:
        runs.append((start, i if not f else i + 1)); start = None
r0, r1 = max(runs, key=lambda r: r[1] - r[0])
z_eye, z_obj = float(zz[r0]) - 0.005, float(zz[r1 - 1]) + 0.005
print("SCOPE z[%.3f %.3f] len %.3f" % (z_eye, z_obj, z_obj - z_eye))
import bmesh
bm = bmesh.new()
bm.from_mesh(obj.data)
G = lambda co: (co.x, co.z, -co.y)
def in_span(z): return z_eye - 0.01 < z < z_obj + 0.01
posts = []
for f_ in bm.faces:
    c = f_.calc_center_median()
    x, y, z = G(c)
    if in_span(z) and abs(x) < 0.035 and RIFLE_TOP < y < 0.052:
        posts.append(f_)
print("SCOPE post faces cut", len(posts))
bmesh.ops.delete(bm, geom=posts, context='FACES')
tube = [v for v in bm.verts if in_span(G(v.co)[2]) and G(v.co)[1] > TUBE_FLOOR and abs(G(v.co)[0]) < 0.045]
ty = np.array([G(v.co)[1] for v in tube])
axis_y = float((ty.min() + ty.max()) * 0.5)
r_tube = float((ty.max() - ty.min()) * 0.5)
L = z_obj - z_eye
if SCOPE_LEN > 0.0 and L > SCOPE_LEN:
    bell_e, bell_o = 0.06, 0.045          # eyepiece and objective bells, rigid
    a0, a1 = z_eye + bell_e, z_obj - bell_o
    s_mid = (SCOPE_LEN - bell_e - bell_o) / (a1 - a0)
    def zmap(z):
        if z <= a0: q = z - z_eye
        elif z <= a1: q = bell_e + (z - a0) * s_mid
        else: q = bell_e + (a1 - a0) * s_mid + (z - a1)
        return EYEPIECE_Z + q
else:
    def zmap(z): return EYEPIECE_Z + (z - z_eye)
for v in tube:
    v.co.y = -zmap(-v.co.y)
bm.to_mesh(obj.data)
bm.free()
obj.data.update()
z_eye, z_obj = zmap(z_eye), zmap(z_obj)
print("SCOPE now z[%.3f %.3f] len %.3f axis y %.4f r %.4f (%d tube verts)" % (z_eye, z_obj, z_obj - z_eye, axis_y, r_tube, len(tube)))
g = game()

# two brass posts and blued feet, as on a period Malcolm mount: one over the receiver ring, one a hand ahead, both clear of the bells
brass = None
for mat in obj.data.materials:
    brass = mat
def post_mesh(name, size, at):
    bm2 = bmesh.new()
    bmesh.ops.create_cube(bm2, size=1.0)
    bmesh.ops.scale(bm2, vec=(size[0], size[2], size[1]), verts=bm2.verts)
    bmesh.ops.translate(bm2, vec=(at[0], -at[2], at[1]), verts=bm2.verts)
    me = bpy.data.meshes.new(name)
    bm2.to_mesh(me)
    bm2.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o
mt = bpy.data.materials.new("ScopeMountBrass")
mt.use_nodes = True
b_ = next(n for n in mt.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
b_.inputs['Base Color'].default_value = (0.55, 0.38, 0.13, 1.0)
b_.inputs['Metallic'].default_value = 0.9
b_.inputs['Roughness'].default_value = 0.38
extra = []
for i, zp in enumerate([z_eye + 0.075, z_obj - 0.07]):
    near = (np.abs(g[:, 2] - zp) < 0.006) & (np.abs(g[:, 0]) < 0.012) & (g[:, 1] < RIFLE_TOP + 0.005)
    foot = float(g[near, 1].max()) if near.any() else 0.015
    tb = (np.abs(g[:, 2] - zp) < 0.004) & (g[:, 1] > TUBE_FLOOR)
    r_here = float(np.max(np.hypot(g[tb, 0], g[tb, 1] - axis_y))) if tb.any() else 0.022     # the tube's own radius under this ring
    h = (axis_y - r_here) - foot + 0.006
    p_ = post_mesh("ScopePost%d" % i, (0.010, h, 0.014), (0.0, foot + h * 0.5 - 0.003, zp))
    p_.data.materials.append(mt)
    ring = bpy.data.meshes.new("ScopeRing%d" % i)
    bm3 = bmesh.new()
    bmesh.ops.create_cone(bm3, cap_ends=False, segments=24, radius1=r_here + 0.0025, radius2=r_here + 0.0025, depth=0.012)
    bmesh.ops.rotate(bm3, verts=bm3.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi * 0.5, 3, 'X'))
    bmesh.ops.translate(bm3, vec=(0.0, -zp, axis_y), verts=bm3.verts)
    bm3.to_mesh(ring)
    bm3.free()
    ro = bpy.data.objects.new("ScopeRing%d" % i, ring)
    bpy.context.scene.collection.objects.link(ro)
    ring.materials.append(mt)
    extra += [p_, ro]
    print("SCOPE post %d z %.3f foot y %.3f h %.3f tube r %.4f" % (i, zp, foot, h, r_here))
# the mount (posts + rings) is one object, the founder's tube another (tests and the aimed view measure it), the rifle the third
bpy.ops.object.select_all(action='DESELECT')
for o in extra: o.select_set(True)
bpy.context.view_layer.objects.active = extra[0]
bpy.ops.object.join()
mount = bpy.context.view_layer.objects.active
mount.name = "ScopeMount"
bpy.ops.object.select_all(action='DESELECT')
bm = bmesh.new()
bm.from_mesh(obj.data)
for v in bm.verts:
    x, y, z = G(v.co)
    v.select = z_eye - 0.012 < z < z_obj + 0.012 and y > TUBE_FLOOR and abs(x) < 0.045
for f_ in bm.faces:
    f_.select = all(v.select for v in f_.verts)
bm.to_mesh(obj.data)
bm.free()
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_mode(type='FACE')
bpy.ops.mesh.separate(type='SELECTED')
bpy.ops.object.mode_set(mode='OBJECT')
tube_obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and o not in (obj, mount))
tube_obj.name = "ScopeTube"
tube_obj.data.name = "ScopeTube"
g = game()

# --- textures: base colour TEX, the rest TEX/2
for mat in obj.data.materials:
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            base = any(l.to_socket == bsdf.inputs['Base Color'] for l in n.outputs[0].links)
            s = TEX if base else TEX // 2
            if n.image.size[0] > s:
                n.image.scale(s, s)
    # the founder's file asks for a glass volume (KHR_materials_volume): a rifle is opaque
    for inp in ("Transmission Weight", "Transmission"):
        if inp in bsdf.inputs:
            bsdf.inputs[inp].default_value = 0.0

# anchors (game frame)
def slice_(z, w=0.008):
    return g[np.abs(g[:, 2] - z) < w]
muzzle_z = float(g[:, 2].max())
wr = slice_(-0.11)
wr = wr[wr[:, 1] < 0.02]
grip = Vector((0.0, float((wr[:, 1].min() + wr[:, 1].max()) * 0.5), -0.11))
fe_z = 0.22
fe = slice_(fe_z)
fe = fe[fe[:, 1] < 0.0]
fore = Vector((0.0, float(fe[:, 1].min()) + 0.01 if len(fe) else -0.04, fe_z))
eye = Vector((0.0, axis_y, z_eye - 0.10))     # 10 cm behind the eyepiece (founder: 3 cm "would take a person's eye out")
print("ANCHOR muzzle", [0.0, 0.0, round(muzzle_z, 4)])
print("ANCHOR eye", [0.0, round(axis_y, 4), round(eye.z, 4)], "eyepiece_z", round(z_eye, 4), "objective_z", round(z_obj, 4), "tube_len", round(z_obj - z_eye, 4), "lens_r", round(r_tube, 4))
print("ANCHOR grip", [round(v, 4) for v in grip], "wrist y[%.3f %.3f]" % (wr[:, 1].min(), wr[:, 1].max()))
for zf in (0.15, 0.24):
    sl = slice_(zf)
    sl = sl[sl[:, 1] < 0.0]
    if len(sl): print("ANCHOR forend z %.2f y[%.4f %.4f] centre %.4f" % (zf, sl[:, 1].min(), sl[:, 1].max(), (sl[:, 1].min() + sl[:, 1].max()) * 0.5))
print("ANCHOR fore", [round(v, 4) for v in fore], "fore-end underside y %.4f" % (float(fe[:, 1].min()) if len(fe) else 0.0))

obj.name = "Gun"
obj.data.name = "Gun"
def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=False, export_image_format='JPEG', export_jpeg_quality=82,
                              export_apply=True, export_animations=False, export_materials='EXPORT')
    import os
    print("WROTE", path, os.path.getsize(path))

parts = [obj, tube_obj]
total = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in parts)
for o in parts:
    n = sum(len(p.vertices) - 2 for p in o.data.polygons)
    decimate(o, max(400, int(n * (TRIS_HELD - 300) / total)))
print("HELD tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH'))
export(OUT + "/sharps_scoped.glb")
for o in parts:
    decimate(o, max(160, int(sum(len(p.vertices) - 2 for p in o.data.polygons) * TRIS_LOW / 13000)))
print("LOW tris", sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH'))
for mat in obj.data.materials:
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None and n.image.size[0] > 128:
            n.image.scale(128, 128)
for o in bpy.context.scene.objects:
    o.matrix_world = Matrix.Rotation(math.pi * 0.5, 4, 'Z') @ o.matrix_world      # the shop's fallback lays long guns muzzle +X, butt behind the origin
bpy.context.view_layer.update()
export(OUT + "/sharps_1874.glb")
