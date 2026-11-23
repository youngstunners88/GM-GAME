"""The founder's new Inferno (2026-11-22 "Inferno New.glb" + its T-pose sheet) on the EXISTING Inferno skeleton. Headless only:
  blender -b --factory-startup -P tools/ep2_blender/rig_inferno_new.py -- <Inferno New.glb> <tpose_ref.jpg> <old inferno_bull_rigged.glb> <out.glb>
      [--tris 42000] [--tex 2048] [--voxel 0.018] [--sheet <prefix>]

Why the old skeleton: every Bull clip (the four baked in the GLB, the walk/run/sit clip files and the retargeted CMU/Meshy clips) stores ABSOLUTE local
bone rotations for the Meshy 24-joint rig and its own rest frames. A new rig with other bone rolls would break all of them. So:
  1. the new mesh (256 Tripo parts, 1 m, T-pose, no material) is joined, scaled to the old Bull's 2.40 m and centred on its Hips;
  2. it is painted by projecting the founder's T-pose sheet from the front (the sheet and the mesh line up: arms at the same height, aspect within 2%);
     faces turned away take the plain fur / denim / leather from the silhouette's own side at that height, so the face is never printed on his back;
  3. a copy of the old armature is POSED into the T-pose (each arm bone turned onto the mesh's own elbow / wrist / hand), that pose applied as rest;
  4. weights: bone heat on a watertight voxel proxy, transferred to the real mesh (heat fails on 256 loose shells), normalised, max 4;
  5. the copy is posed back into the OLD rest pose and the mesh deformed into it; then the mesh is bound to the ORIGINAL armature with those weights.
Prints a report (bone fit, weight coverage, stress angles) and optional render sheets.
"""
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
NEW, SHEET_IMG, OLD, OUT = a[:4]
def arg(k, d): return type(d)(a[a.index(k) + 1]) if k in a else d
TRIS = arg("--tris", 42000)
TEX = arg("--tex", 2048)
VOXEL = arg("--voxel", 0.018)
SHEET = arg("--sheet", "")
HEIGHT = 2.40
# the sheet's character box (measured: tools-side, white background < 0.92) in pixels of the 2048 image, top-left origin
IMG_BOX = (46, 23, 2012, 2027)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mode(m):
    if bpy.context.object is not None and bpy.context.object.mode != m:
        bpy.ops.object.mode_set(mode=m)


def only(o):
    mode('OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


# ---------------------------------------------------------------- old skeleton and clips
bpy.ops.import_scene.gltf(filepath=OLD)
ARM = next(o for o in scene.objects if o.type == 'ARMATURE')
OLD_MESHES = [o for o in scene.objects if o.type == 'MESH']
if ARM.animation_data:
    ARM.animation_data.action = None
for pb in ARM.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
bpy.context.view_layer.update()
def head(bn, arm=ARM):
    return arm.matrix_world @ arm.data.bones[bn].head_local
REST = {b.name: (ARM.matrix_world @ b.matrix_local) for b in ARM.data.bones}
print("OLD skeleton", len(ARM.data.bones), "bones; Hips", [round(v, 3) for v in head("Hips")], "actions", [x.name for x in bpy.data.actions])

# ---------------------------------------------------------------- the new mesh
before = set(scene.objects)
bpy.ops.import_scene.gltf(filepath=NEW)
parts = [o for o in scene.objects if o not in before and o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.join()
MESH = bpy.context.view_layer.objects.active
MESH.name = "Inferno"
MESH.data.name = "Inferno"
only(MESH)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
co = np.array([v.co[:] for v in MESH.data.vertices])
k = HEIGHT / float(co[:, 2].max() - co[:, 2].min())
# pelvis centre (x, y) at the belt height of the sheet (0.47 - 0.52 of the height)
z0 = co[:, 2].min()
zr = co[:, 2].max() - z0
band = (co[:, 2] - z0 > 0.47 * zr) & (co[:, 2] - z0 < 0.52 * zr)
pel = co[band]
cx, cy = float((pel[:, 0].min() + pel[:, 0].max()) * 0.5), float((pel[:, 1].min() + pel[:, 1].max()) * 0.5)
hx, hy = head("Hips").x, head("Hips").y
MESH.data.transform(Matrix.Translation(Vector((-cx, -cy, -z0))))
MESH.data.transform(Matrix.Scale(k, 4))
MESH.data.transform(Matrix.Translation(Vector((hx, hy, 0.0))))
MESH.data.update()
co = np.array([v.co[:] for v in MESH.data.vertices])
print("NEW mesh", len(MESH.data.vertices), "verts", sum(len(p.vertices) - 2 for p in MESH.data.polygons), "tris; scaled x%.3f; bounds" % k,
      co.min(0).round(3).tolist(), co.max(0).round(3).tolist())
# merge the loose duplicate seams the Tripo parts carry, so the proxy and the decimate see one surface where they touch
bm = bmesh.new()
bm.from_mesh(MESH.data)
n0 = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008)
bm.to_mesh(MESH.data)
bm.free()
print("merged", n0 - len(MESH.data.vertices), "duplicate verts")

# ---------------------------------------------------------------- joints of the new mesh (T-pose), measured from its own shape
co = np.array([v.co[:] for v in MESH.data.vertices])
H = HEIGHT
def slab_x(z, half=0.02, xmin=-9, xmax=9):
    m = (np.abs(co[:, 2] - z) < half) & (co[:, 0] > xmin) & (co[:, 0] < xmax)
    return co[m]
# arm line: the height band where the silhouette is widest
zs = np.linspace(0.55 * H, 0.85 * H, 60)
wid = [np.ptp(slab_x(z)[:, 0]) if len(slab_x(z)) else 0 for z in zs]
arm_z = float(zs[int(np.argmax(wid))])
J = {}
for side, s in (("Left", 1.0), ("Right", -1.0)):
    # along the arm: for x outward from the shoulder, the centre of the arm's cross-section
    xs = np.linspace(abs(head(side + "Arm").x - hx) + 0.02, 1.15, 40)
    cent = []
    for x in xs:
        m = (np.abs(co[:, 0] - hx - s * x) < 0.015) & (np.abs(co[:, 2] - arm_z) < 0.25)
        if m.sum() > 10:
            cent.append((x, float(np.median(co[m, 1])), float((co[m, 2].min() + co[m, 2].max()) * 0.5), float(np.ptp(co[m, 2]))))
    cent = np.array(cent)
    tip = float(cent[:, 0].max())
    # the wrist: the narrowest section in the outer 35-75% between shoulder and the finger tips; the elbow: halfway shoulder - wrist
    sh = abs(head(side + "Arm").x - hx)
    sel = cent[(cent[:, 0] > sh + 0.45 * (tip - sh)) & (cent[:, 0] < sh + 0.85 * (tip - sh))]
    wr = sel[int(np.argmin(sel[:, 3]))]
    el_x = sh + (wr[0] - sh) * 0.52
    el = cent[int(np.argmin(np.abs(cent[:, 0] - el_x)))]
    J[side + "ForeArm"] = Vector((hx + s * el[0], el[1], el[2]))
    J[side + "Hand"] = Vector((hx + s * wr[0], wr[1], wr[2]))
    J[side + "HandTip"] = Vector((hx + s * (tip - 0.02), wr[1], wr[2]))
    print("JOINTS %s arm_z %.3f shoulder %.3f elbow %s wrist %s tip %.3f" % (side, arm_z, sh, [round(v, 3) for v in J[side + "ForeArm"]], [round(v, 3) for v in J[side + "Hand"]], tip))

# ---------------------------------------------------------------- paint: front projection of the sheet
img = bpy.data.images.load(SHEET_IMG)
iw, ih = img.size
x0i, y0i, x1i, y1i = IMG_BOX
xmin, xmax = float(co[:, 0].min()), float(co[:, 0].max())
pix = np.array(img.pixels[:]).reshape(ih, iw, 4)[::-1]          # row 0 = top
sil = pix[:, :, :3].min(2) < 0.92
def uv_front(x, z):
    u = (x0i + (x - xmin) / (xmax - xmin) * (x1i - x0i)) / iw
    v_top = (y0i + (1.0 - z / H) * (y1i - y0i))                # pixel row from the top
    return u, 1.0 - v_top / ih, int(v_top)
# per image row: the torso's own side column (plain fur / denim / leather), used for faces turned away
side_col = {}
def back_u(row, x):
    row = min(max(row, 0), ih - 1)
    if row not in side_col:
        r = np.nonzero(sil[row])[0]
        mid = iw * (x0i + (hx - xmin) / (xmax - xmin) * (x1i - x0i)) / iw
        runs = r[np.abs(r - mid) < 0.12 * iw] if len(r) else r
        if len(runs) == 0:
            side_col[row] = None
        else:
            lo, hi = runs.min(), runs.max()
            side_col[row] = (lo + 0.10 * (hi - lo), hi - 0.10 * (hi - lo))
    c = side_col[row]
    if c is None:
        return None
    return (c[0] if x < hx else c[1]) / iw
me = MESH.data
uvl = me.uv_layers.new(name="UVMap")
me.calc_normals_split() if hasattr(me, "calc_normals_split") else None
NECK_Z = head("neck").z
BACK_STRIP = 0.075 * H
n_back = 0
for poly in me.polygons:
    nrm = poly.normal
    for li in poly.loop_indices:
        vco = me.vertices[me.loops[li].vertex_index].co
        u, v, row = uv_front(vco.x, vco.z)
        if nrm.y > 0.35:                                             # facing away (the model faces -Y)
            if vco.z > NECK_Z:                                       # the back of his head and hat: the fur / hat at the head's own side
                bu = back_u(row, vco.x)
                if bu is not None:
                    u = bu
                    n_back += 1
            elif abs(vco.x - hx) < BACK_STRIP:                       # the buckle / chest badge column: sample the straps beside it
                xs = hx + (BACK_STRIP if vco.x >= hx else -BACK_STRIP)
                u, _, _ = uv_front(xs, vco.z)
                n_back += 1
        uvl.data[li].uv = (u, v)
print("PAINT front projection; %d loops take the side colour (faces turned away)" % n_back)
# the sheet's white background bleeds in where the mesh's side faces sample the outline: grow the character's own colours outward
small = min(TEX, iw)
if img.size[0] > small:
    img.scale(small, small)
sw, sh = img.size
px = np.array(img.pixels[:]).reshape(sh, sw, 4)
filled = px[:, :, :3].min(2) < 0.90
# the anti-aliased rim is half background: drop 3 px of it so the fill starts from true character colour
for _ in range(3):
    filled = filled & np.roll(filled, 1, 0) & np.roll(filled, -1, 0) & np.roll(filled, 1, 1) & np.roll(filled, -1, 1)
# fill every background pixel from the character: solve on a 1/8 grid until full, upsample, paste behind the character
f8 = 8
gh, gw = sh // f8, sw // f8
blk = px[:gh * f8, :gw * f8, :3].reshape(gh, f8, gw, f8, 3)
# seed the fill from his body colours only (fur, denim, leather), never the rim highlights, horns or brass: a grey fill reads as a bare patch
lum = px[:, :, :3] @ np.array([0.299, 0.587, 0.114])
seed = filled & (lum < 0.30)
msk = seed[:gh * f8, :gw * f8].reshape(gh, f8, gw, f8)
cnt0 = msk.sum((1, 3))
low = (blk * msk[..., None]).sum((1, 3)) / np.maximum(cnt0, 1)[..., None]
lf = cnt0 > 0
while not lf.all():
    acc = np.zeros_like(low); cnt = np.zeros(lf.shape)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        acc += np.roll(np.roll(low * lf[..., None], dy, 0), dx, 1); cnt += np.roll(np.roll(lf, dy, 0), dx, 1)
    grow = (~lf) & (cnt > 0)
    low[grow] = acc[grow] / cnt[grow][:, None]
    lf = lf | grow
up = np.repeat(np.repeat(low, f8, 0), f8, 1)
full = np.zeros((sh, sw, 3)); full[:gh * f8, :gw * f8] = up
px[~filled, :3] = full[~filled]
# and pull the outline itself in a little: the anti-aliased rim is half background
px[:, :, 3] = 1.0
img.pixels[:] = px.ravel()
img.update()
print("PAINT sheet %dx%d, background filled from the character's own edge colours" % (sw, sh))
mat = bpy.data.materials.new("InfernoNew")
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = img
mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
bsdf.inputs['Roughness'].default_value = 0.78
bsdf.inputs['Metallic'].default_value = 0.0
me.materials.clear()
me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True

# ---------------------------------------------------------------- the T-pose copy of the old armature
only(ARM)
bpy.ops.object.duplicate()
ART = bpy.context.view_layer.objects.active
ART.name = "ArmT"
bpy.context.view_layer.update()
mode('POSE')
def aim(bone, child_head_now, target):
    """turn `bone` about its head so the point `child_head_now` (armature space) goes onto the direction of `target`."""
    pb = ART.pose.bones[bone]
    h = pb.head.copy()
    q = (child_head_now - h).rotation_difference(target - h)
    pb.matrix = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()
inv = ART.matrix_world.inverted()
for side in ("Left", "Right"):
    aim(side + "Arm", ART.pose.bones[side + "ForeArm"].head.copy(), inv @ J[side + "ForeArm"])
    aim(side + "ForeArm", ART.pose.bones[side + "Hand"].head.copy(), inv @ J[side + "Hand"])
    err_e = (ART.matrix_world @ ART.pose.bones[side + "ForeArm"].head - J[side + "ForeArm"]).length
    err_w = (ART.matrix_world @ ART.pose.bones[side + "Hand"].head - J[side + "Hand"]).length
    print("FIT %s elbow off %.3f m, wrist off %.3f m (bone lengths are the old Bull's)" % (side, err_e, err_w))
bpy.ops.pose.armature_apply(selected=False)
mode('OBJECT')

# ---------------------------------------------------------------- weights from the OLD Bull, posed into the same T
# The old painted Bull is the same character at the same proportions and its weights are proven with every clip on this odd Meshy chain
# (the spine runs Hips -> Spine02 -> Spine01 -> Spine DOWNWARD, the bone tails are metres off, so bone heat on it puts his hat on the Hips).
# Pose the old armature into the T rest of ArmT, bake the old meshes into that pose, and transfer their weights by nearest surface.
only(ARM)
mode('POSE')
for b in ARM.data.bones:
    ARM.pose.bones[b.name].matrix = ART.data.bones[b.name].matrix_local.copy()
    bpy.context.view_layer.update()
mode('OBJECT')
src = []
dg = bpy.context.evaluated_depsgraph_get()
for o in OLD_MESHES:
    me_t = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    c = bpy.data.objects.new(o.name + "_T", me_t)
    scene.collection.objects.link(c)
    c.matrix_world = o.matrix_world.copy()
    for vg in o.vertex_groups:
        if c.vertex_groups.get(vg.name) is None:
            c.vertex_groups.new(name=vg.name)
    src.append(c)
print("OLD vgroups on the T copies", [len(c.vertex_groups) for c in src], "weighted verts", [sum(1 for v in c.data.vertices if len(v.groups)) for c in src])
for o in OLD_MESHES:
    bpy.data.objects.remove(o, do_unlink=True)
only(src[0])
for c in src[1:]:
    c.select_set(True)
bpy.ops.object.join()
OLDT = bpy.context.view_layer.objects.active
OLDT.name = "OldBullT"
only(OLDT)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
oc = np.array([v.co[:] for v in OLDT.data.vertices])
print("OLD mesh in T", len(oc), "verts, bounds", oc.min(0).round(3).tolist(), oc.max(0).round(3).tolist())
only(ARM)
mode('POSE')
for pb in ARM.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)
mode('OBJECT')
only(MESH)
for b in ART.data.bones:
    if MESH.vertex_groups.get(b.name) is None:
        MESH.vertex_groups.new(name=b.name)
dt = MESH.modifiers.new("dt", 'DATA_TRANSFER')
dt.object = OLDT
dt.use_vert_data = True
dt.data_types_verts = {'VGROUP_WEIGHTS'}
dt.vert_mapping = 'POLYINTERP_NEAREST'
dt.layers_vgroup_select_src = 'ALL'
dt.layers_vgroup_select_dst = 'NAME'
bpy.ops.object.modifier_apply(modifier=dt.name)
# smooth the seams the nearest-face transfer leaves between a far-reaching arm and the torso, then clamp
bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=0.5, repeat=2)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
# any vertex the transfer left thin takes the weights of its nearest well-weighted neighbour (a zero-weight vertex would collapse to the origin)
from mathutils.kdtree import KDTree
good = [v for v in MESH.data.vertices if sum(g.weight for g in v.groups) >= 0.5]
thin = [v for v in MESH.data.vertices if sum(g.weight for g in v.groups) < 0.5]
kd = KDTree(len(good))
for i, v in enumerate(good):
    kd.insert(v.co, i)
kd.balance()
for v in thin:
    _, gi, _ = kd.find(v.co)
    src_v = good[gi]
    for g in list(v.groups):
        MESH.vertex_groups[g.group].remove([v.index])
    for g in src_v.groups:
        MESH.vertex_groups[g.group].add([v.index], g.weight, 'REPLACE')
print("WEIGHTS filled", len(thin), "thin verts from their nearest neighbour")
bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
unweighted = sum(1 for v in MESH.data.vertices if sum(g.weight for g in v.groups) < 0.5)
nm = {g.index: g.name for g in MESH.vertex_groups}
tot = {}
for v in MESH.data.vertices:
    for g in v.groups:
        tot[nm[g.group]] = tot.get(nm[g.group], 0.0) + g.weight
print("WEIGHTS from the old Bull; unweighted verts", unweighted, "of", len(MESH.data.vertices), "; per bone", {k: int(v) for k, v in sorted(tot.items(), key=lambda kv: -kv[1])})
bpy.data.objects.remove(OLDT, do_unlink=True)

# ---------------------------------------------------------------- deform into the OLD rest pose, bind to the ORIGINAL armature
only(MESH)
am = MESH.modifiers.new("arm", 'ARMATURE')
am.object = ART
only(ART)
mode('POSE')
for b in ART.data.bones:            # parents first (bones are stored in hierarchy order)
    ART.pose.bones[b.name].matrix = ART.matrix_world.inverted() @ REST[b.name]
    bpy.context.view_layer.update()
mode('OBJECT')
only(MESH)
bpy.ops.object.modifier_apply(modifier=am.name)
MESH.parent = None
am2 = MESH.modifiers.new("Armature", 'ARMATURE')
am2.object = ARM
MESH.parent = ARM
MESH.matrix_parent_inverse = ARM.matrix_world.inverted()
bpy.data.objects.remove(ART, do_unlink=True)
n = sum(len(p.vertices) - 2 for p in MESH.data.polygons)
if n > TRIS:
    only(MESH)
    d2 = MESH.modifiers.new("dec", 'DECIMATE')
    d2.ratio = TRIS / n
    d2.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier=d2.name, index=0)
    bpy.ops.object.modifier_apply(modifier=d2.name)
print("FINAL tris", sum(len(p.vertices) - 2 for p in MESH.data.polygons))

# ---------------------------------------------------------------- stress test: each clip at a few frames, worst stretched edge
def edge_stretch(frame_action, frames):
    ARM.animation_data_create()
    ARM.animation_data.action = frame_action
    dg = bpy.context.evaluated_depsgraph_get()
    base = np.array([v.co[:] for v in MESH.data.vertices])
    ed = np.array([e.vertices[:] for e in MESH.data.edges])
    l0 = np.linalg.norm(base[ed[:, 0]] - base[ed[:, 1]], axis=1) + 1e-6
    worst = 0.0
    for f in frames:
        scene.frame_set(int(f))
        ev = MESH.evaluated_get(bpy.context.evaluated_depsgraph_get())
        cur = np.array([v.co[:] for v in ev.data.vertices])
        l1 = np.linalg.norm(cur[ed[:, 0]] - cur[ed[:, 1]], axis=1)
        worst = max(worst, float(np.percentile(l1 / l0, 99.9)))
    return worst
for act in bpy.data.actions:
    fr = act.frame_range
    w = edge_stretch(act, np.linspace(fr[0], fr[1], 6))
    print("STRESS %-28s 99.9th pct edge stretch %.2fx" % (act.name, w))
ARM.animation_data.action = bpy.data.actions[0] if bpy.data.actions else None
scene.frame_set(1)

bpy.ops.object.select_all(action='DESELECT')
ARM.select_set(True)
MESH.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True, export_image_format='JPEG', export_jpeg_quality=85,
                          export_animations=True, export_animation_mode='ACTIONS', export_skins=True, export_def_bones=False)
import os
print("WROTE", OUT, os.path.getsize(OUT))
if SHEET:
    bpy.ops.wm.save_as_mainfile(filepath=SHEET + ".blend")
