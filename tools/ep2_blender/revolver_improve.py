"""Improve the founder's Tripo golden revolver (hand + gun) headless.

blender -b --python tools/ep2_blender/revolver_improve.py -- <in.glb> <out.glb> <hero|game> [<renderdir>]

hero: 2048 textures, gold regraded + polished, clean arm cut, full mesh. Not shipped in the pack.
game: ~14k tris, 1024 albedo + normal, metallic 0 (the web Compatibility renderer draws
      reflection-less metals black, see runner_view.brighten_hero), gold baked bright in the albedo.
Muzzle stays at -X, up stays +Z in Blender (glTF export keeps muzzle -X, up +Y), centred on the
barrel, muzzle-to-arm-end length 1.0, so runner_view's bbox-based scaling still works.
"""
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import revolver_lib as L  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, MODE = args[0], args[1], args[2]
RENDER = args[3] if len(args) > 3 else ""
HERO = MODE == "hero"
TEX = 2048 if HERO else 1024
GOLD_ENC = np.array([1.0, 0.72, 0.30], dtype=np.float32)   # sRGB-encoded gold tint

obj = L.load_main_mesh(SRC)
mat = obj.data.materials[0]
nodes = mat.node_tree.nodes
tex = {n.image.name.split("_")[0] + ("_orm" if "metallic" in n.image.name else ""): n
       for n in nodes if n.type == "TEX_IMAGE"}
alb_n = [n for n in nodes if n.type == "TEX_IMAGE" and "rgb" in n.image.name][0]
orm_n = [n for n in nodes if n.type == "TEX_IMAGE" and "metallic" in n.image.name][0]
nrm_n = [n for n in nodes if n.type == "TEX_IMAGE" and "normal" in n.image.name][0]


def get(img, size):
    img.scale(size, size)
    a = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(size, size, 4)


def put(name, arr, data):
    size = arr.shape[0]
    im = bpy.data.images.new(name, size, size, alpha=False)
    im.colorspace_settings.name = "Non-Color" if data else "sRGB"
    im.pixels.foreach_set(np.clip(arr, 0, 1).reshape(-1))
    im.pack()
    return im


# ---- textures ---------------------------------------------------------------------------------
alb = get(alb_n.image, TEX)
orm = get(orm_n.image, TEX)
metal = orm[..., 2]
mask = np.clip((metal - 0.22) / 0.35, 0, 1)
mask = (mask * mask * (3 - 2 * mask))[..., None]
lum = (alb[..., :3] * np.array([0.3, 0.55, 0.15], dtype=np.float32)).sum(-1, keepdims=True)
ref = max(float((lum * mask).sum() / max(mask.sum(), 1.0)), 1e-3)
rel = np.clip(lum / ref, 0.0, 2.2)                         # keeps the engraving + wear detail
gold = np.clip(GOLD_ENC * (0.42 + 0.50 * rel), 0, 1)
if not HERO:
    gold = np.clip(gold * 0.96 + 0.02, 0, 1)                # no reflections in-game: bake the shine in
new_alb = alb.copy()
new_alb[..., :3] = alb[..., :3] * (1 - 0.82 * mask) + gold * (0.82 * mask)
alb_im = put("rev_albedo", new_alb, False)
alb_n.image = alb_im

if HERO:
    new_orm = orm.copy()
    new_orm[..., 1] = np.clip(orm[..., 1] * (1 - 0.35 * mask[..., 0]), 0.14, 1.0)   # polish the gold
    new_orm[..., 2] = np.where(mask[..., 0] > 0.5, 1.0, orm[..., 2])                  # fully metal on gold
    orm_n.image = put("rev_orm", new_orm, True)
nrm = get(nrm_n.image, TEX)
nrm_n.image = put("rev_normal", nrm, True)
for im in list(bpy.data.images):
    if im.users == 0:
        bpy.data.images.remove(im)

# ---- shading + clean arm end -------------------------------------------------------------------
bpy.context.view_layer.objects.active = obj
bpy.ops.object.shade_smooth()
me = obj.data
bm = bmesh.new()
bm.from_mesh(me)
d = Vector((0.8, 0.0, -0.6)).normalized()           # arm runs +X and down from the grip
proj = [v.co.dot(d) for v in bm.verts]
cut = max(proj) - 0.035
geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=d * cut, plane_no=d, clear_outer=True, use_snap_center=False)
rim = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
if rim:
    filled = bmesh.ops.holes_fill(bm, edges=rim, sides=0)
    uv = bm.loops.layers.uv.active
    # sample UV of the vine-arm surface just under the cut so the cap matches the sleeve
    near = [l[uv].uv.copy() for f in bm.faces for l in f.loops
            if abs(l.vert.co.dot(d) - cut) < 0.01 and l.vert.co.dot(d) <= cut + 1e-4]
    pick = near[len(near) // 2] if near else Vector((0.5, 0.5))
    for f in filled["faces"]:
        for l in f.loops:
            l[uv].uv = pick
bm.to_mesh(me)
bm.free()
me.update()

# ---- recentre: muzzle -X, barrel line on the origin, length 1.0 -------------------------------
lo, hi = L.bbox(obj)
for v in me.vertices:
    v.co.x = (v.co.x - lo.x) / (hi.x - lo.x) - 0.5          # keep native scale ratio per axis
    v.co.y = v.co.y / (hi.x - lo.x)
    v.co.z = v.co.z / (hi.x - lo.x)
lo, hi = L.bbox(obj)
bore_z = 0.0
print("final bbox", tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi))

if not HERO:
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = 14000.0 / max(sum(len(p.vertices) - 2 for p in me.polygons), 1)
    bpy.ops.object.modifier_apply(modifier="dec")
    bsdf = [n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"][0]
    for l in list(mat.node_tree.links):
        if l.to_socket.name in ("Metallic", "Roughness"):
            mat.node_tree.links.remove(l)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.42
    for n in [n for n in mat.node_tree.nodes if n.type in ("SEPARATE_COLOR",) or n is orm_n]:
        mat.node_tree.nodes.remove(n)
    print("game tris", sum(len(p.vertices) - 2 for p in me.polygons))

if RENDER:
    L.studio()
    L.render_views(MODE, RENDER, views=["side", "tq", "emblem"], samples=24)

for o in [o for o in bpy.data.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o, do_unlink=True)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="JPEG",
                          export_jpeg_quality=82 if HERO else 68, export_apply=True)
print("export done", OUT, os.path.getsize(OUT))
