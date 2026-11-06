"""Lil Blunt's canon gun hand on its own (founder 2026-11-05): the founder's hand-and-revolver with the revolver taken away, so every new pistol or rifle is held by the
SAME glove, bracer and vine arm as the Golden Remington (skill golden-revolver-hand, canon lock). Headless only:
  blender -b --factory-startup -P tools/ep2_forge/founder_gun_hand.py -- <golden_revolver_founder.glb> <golden_revolver_gun.glb> <out.glb>

The two models share a frame. A face goes when it lies on the gun-only model AND its texture is not glove (green / olive / brown leather read as channel ratios: the
glove touches the gun, so distance alone would eat the fingers). Crumbs left behind are dropped. The frame is unchanged: Ep2RemingtonView's FOUNDER_TURN and FOUNDER_OFFSET still place it.
"""
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

NEAR_GUN = 0.016         # metres from the gun-only surface, in the model's own (1.4x life) size
CRUMB_FACES = 60         # an island smaller than this is a leftover of the gun

a = sys.argv[sys.argv.index("--") + 1:]
SRC, GUN, OUT = a[0], a[1], a[2]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GUN)
gun_bm = bmesh.new()
for o in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    me = o.data.copy()
    me.transform(o.matrix_world)
    gun_bm.from_mesh(me)
tree = BVHTree.FromBMesh(gun_bm)
for o in list(bpy.context.scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)

bpy.ops.import_scene.gltf(filepath=SRC)
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
keep_names = {obj.name}
for o in list(bpy.context.scene.objects):
    if o.name not in keep_names:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

mat = obj.data.materials[0]
bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
img = next(n.image for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and any(l.to_socket == bsdf.inputs['Base Color'] for l in n.outputs[0].links))
W, H = img.size
px = np.empty(W * H * 4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(H, W, 4)


def glove_colour(rgb) -> bool:
    """Green sleeve, olive glove, brown bracer. The gun is saturated gold (r well over g, b near nothing) or grey steel (channels equal)."""
    r, g, b = float(rgb[0]), float(rgb[1]), float(rgb[2])
    if g >= r * 0.92 and g > b * 1.2:
        return True
    return r > b * 1.25 and r < g * 1.75 and max(r, g, b) < 0.28


bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)      # Tripo is unwelded: without this every face is its own "island" and the crumb pass eats the hand
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.active
kill = []
for f in bm.faces:
    u = sum((l[uv].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
    x = min(W - 1, max(0, int(u.x * W)))
    y = min(H - 1, max(0, int(u.y * H)))
    rgb = px[y, x, :3]
    # gold is the gun wherever it is: the gun-only model has no surface inside the fist, so the grip's hidden scraps are too far from it to be caught by distance
    gold = rgb[0] > 0.3 and rgb[0] > rgb[1] * 1.3 and rgb[1] > rgb[2] * 1.5
    hit = tree.find_nearest(f.calc_center_median())
    if gold or (hit[3] is not None and hit[3] <= NEAR_GUN and not glove_colour(rgb)):
        kill.append(f)
print("HAND faces %d, gun faces removed %d" % (len(bm.faces), len(kill)))
bmesh.ops.delete(bm, geom=kill, context='FACES')
bm.faces.index_update()

# crumbs
seen = set()
drop = []
for start in bm.faces:
    if start.index in seen:
        continue
    island = []
    stack = [start]
    seen.add(start.index)
    while stack:
        f = stack.pop()
        island.append(f)
        for e in f.edges:
            for n in e.link_faces:
                if n.index not in seen:
                    seen.add(n.index)
                    stack.append(n)
    # the mesh is a soup of chunks, so a small island alone proves nothing: it is a crumb of the gun only if it also sits on the gun
    if len(island) < CRUMB_FACES:
        d = tree.find_nearest(sum((f.calc_center_median() for f in island), Vector((0, 0, 0))) / len(island))[3]
        if d is not None and d < NEAR_GUN * 1.5:
            drop.extend(island)
print("HAND crumb faces dropped %d" % len(drop))
bmesh.ops.delete(bm, geom=drop, context='FACES')
bm.to_mesh(obj.data)
bm.free()
obj.data.update()
obj.name = "GunHand"
obj.data.name = "GunHand"
co = np.array([v.co[:] for v in obj.data.vertices])
g = np.c_[co[:, 0], co[:, 2], -co[:, 1]]
print("HAND tris", sum(len(p.vertices) - 2 for p in obj.data.polygons), "min", g.min(0).round(3).tolist(), "max", g.max(0).round(3).tolist())
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False, export_image_format='JPEG', export_jpeg_quality=82,
                          export_apply=True, export_animations=False)
