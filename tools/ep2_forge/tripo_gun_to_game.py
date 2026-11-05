"""A gun-only Tripo GLB -> a real-size, game-weight gun (founder 2026-11-05). Headless only:
  blender -b --factory-startup -P tools/ep2_forge/tripo_gun_to_game.py -- <src.glb> <out.glb> <real_length_m> <tris> <tex> <muzzle: +x|-x|+y|-y> [origin_from_rear=0.36]

Frame out: muzzle game +Z, up +Y, the bore line on y = 0 and x = 0, the origin `origin_from_rear` of the length forward of the rear (borchardt_c93.glb's old frame,
which gold_town's draw is posed in). Tripo meshes are unwelded and shred under a collapse, so they are welded by position first (as meshy_prop_to_game.py `solid`).
The bore is levelled from the muzzle-end slices: the whole-gun PCA of meshy_gun_to_game.py tilts on a pistol because of its grip. Prints ANCHORS in the game frame.
"""
import math
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, LENGTH, TRIS, TEX, MUZZLE = a[0], a[1], float(a[2]), int(a[3]), int(a[4]), a[5]
ORIGIN_K = float(a[6]) if len(a) > 6 else 0.36

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and len(o.data.materials) > 0]
for o in list(bpy.context.scene.objects):
    if o not in meshes:
        bpy.data.objects.remove(o, do_unlink=True)
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.modifiers.clear()
obj.vertex_groups.clear()

# weld (Tripo is unwelded), opaque, textures down
bm = bmesh.new()
bm.from_mesh(obj.data)
ext = max(max(v.co[i] for v in bm.verts) - min(v.co[i] for v in bm.verts) for i in range(3))
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=ext * 1e-5)
bm.to_mesh(obj.data)
bm.free()
for mat in obj.data.materials:
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for l in list(bsdf.inputs['Alpha'].links):
        mat.node_tree.links.remove(l)
    bsdf.inputs['Alpha'].default_value = 1.0
    mat.blend_method = 'OPAQUE'
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            base = any(l.to_socket == bsdf.inputs['Base Color'] for l in n.outputs[0].links)
            s = TEX if base else TEX // 2
            if n.image.size[0] > s:
                n.image.scale(s, s)

# turn the named axis to Blender -Y (= game +Z) about Z, so up stays up (rotation_difference picks an arbitrary axis for a half turn and rolls the gun on its side)
TURNS = {"+x": -math.pi * 0.5, "-x": math.pi * 0.5, "+y": math.pi, "-y": 0.0}
obj.data.transform(Matrix.Rotation(TURNS[MUZZLE], 4, 'Z'))

co = np.array([v.co[:] for v in obj.data.vertices])
along = -co[:, 1]
span = float(along.max() - along.min())
# the bore: mid-height and mid-width of the slices over the muzzle-end third, skipping the sight at the very tip
xs, zs, ms = [], [], []
for t in np.linspace(0.68, 0.92, 9):
    m = np.abs(along - (along.min() + t * span)) < 0.015 * span
    if m.sum() > 8:
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
span = float(along.max() - along.min())
k = LENGTH / span
obj.data.transform(Matrix.Scale(k, 4))
co *= k
along = -co[:, 1]
m = np.abs(along - (along.min() + 0.8 * LENGTH)) < 0.015 * LENGTH
bore = Vector(((co[m, 0].min() + co[m, 0].max()) * 0.5, 0.0, (co[m, 2].min() + co[m, 2].max()) * 0.5))
obj.data.transform(Matrix.Translation(Vector((-bore.x, along.min() + ORIGIN_K * LENGTH, -bore.z))))
obj.data.update()

tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > TRIS:
    mod = obj.modifiers.new("dec", 'DECIMATE')
    mod.ratio = TRIS / tris
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
obj.name = "Gun"
obj.data.name = "Gun"

co = np.array([v.co[:] for v in obj.data.vertices])
g = np.c_[co[:, 0], co[:, 2], -co[:, 1]]
print("ANCHOR aabb_min", g.min(0).round(3).tolist(), "aabb_max", g.max(0).round(3).tolist(), "muzzle_z", round(float(g[:, 2].max()), 3),
      "tris", sum(len(p.vertices) - 2 for p in obj.data.polygons))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False, export_image_format='JPEG', export_jpeg_quality=82,
                          export_apply=True, export_animations=False)
