"""Split the founder revolver into a gun-only GLB by dropping glove/arm islands (non-metal, green/leather).
blender -b --python tools/ep2_blender/revolver_gun_only.py -- <hero.glb> <out.glb> [metal_cut=0.45] [render_png|-] [game]
Island = connected faces; kept when the mean metallic (ORM blue) at its vertex UVs >= metal_cut, OR when it is a
wood-grip piece: low metal but dark brown (r>g>b, value<0.45) AND inside the grip box (x in [-0.20,0.14], z<0.33).
"""
import os
import sys

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import revolver_lib as L  # noqa: E402

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
CUT = float(a[2]) if len(a) > 2 else 0.45
PNG = a[3] if len(a) > 3 and a[3] != "-" else ""
GAME = len(a) > 4 and a[4] == "game"
obj = L.load_main_mesh(SRC)
mat = obj.data.materials[0]
orm_img = [n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and "orm" in n.image.name.lower()][0]
alb_img = [n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and "albedo" in n.image.name.lower()][0]


def arr(im):
    w, h = im.size
    p = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(p)
    return p.reshape(h, w, 4), w, h


orm, w, h = arr(orm_img)
alb, _, _ = arr(alb_img)
me = obj.data
bm = bmesh.new()
bm.from_mesh(me)
uv = bm.loops.layers.uv.active
seen, drop = set(), []
kept = dropped = 0
for f in bm.faces:
    if f.index in seen:
        continue
    stack, isl = [f], []
    seen.add(f.index)
    while stack:
        c = stack.pop()
        isl.append(c)
        for e in c.edges:
            for n in e.link_faces:
                if n.index not in seen:
                    seen.add(n.index)
                    stack.append(n)
    mm, cols, cs = [], [], []
    for c in isl:
        for lp in c.loops:
            u, v = lp[uv].uv
            px, py = int(np.clip(u, 0, 0.9999) * w), int(np.clip(v, 0, 0.9999) * h)
            mm.append(orm[py, px, 2])
            cols.append(alb[py, px, :3])
            cs.append(lp.vert.co)
    metal = float(np.mean(mm))
    col = np.mean(cols, axis=0)
    ctr = np.mean([[c.x, c.z] for c in cs], axis=0)
    wood = (metal < CUT and col[0] > 1.25 * col[1] > 1.25 * col[2] and col.max() < 0.45
            and -0.18 <= ctr[0] <= 0.06 and ctr[1] < 0.33 and len(isl) >= 160)
    inside = ctr[0] <= 0.12 and ctr[1] >= 0.16                  # gun region: drops the brass leaf concho + bracer bits
    if (metal >= CUT and inside):
        kept += len(isl)
    else:
        drop.extend(isl)
        dropped += len(isl)
bmesh.ops.delete(bm, geom=drop, context="FACES")
loose = [v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm, geom=loose, context="VERTS")
bm.to_mesh(me)
bm.free()
print("faces kept", kept, "dropped", dropped)
# ---- clean walnut grip (the Tripo grip panels were baked under the glove) -----------------------------------
gm = bpy.data.meshes.new("grip")
top_z, bot_z = 0.345, 0.095
vs = [(-0.098, -0.020, top_z), (-0.004, -0.020, top_z), (-0.004, 0.042, top_z), (-0.098, 0.042, top_z),
      (-0.066, -0.023, bot_z), (0.044, -0.023, bot_z), (0.044, 0.045, bot_z), (-0.066, 0.045, bot_z)]
fs = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
gm.from_pydata(vs, [], fs)
gm.update()
grip = bpy.data.objects.new("WalnutGrip", gm)
bpy.context.scene.collection.objects.link(grip)
wm = bpy.data.materials.new("walnut")
wm.use_nodes = True
wb = [n for n in wm.node_tree.nodes if n.type == "BSDF_PRINCIPLED"][0]
wb.inputs["Base Color"].default_value = (0.075, 0.03, 0.013, 1)
wb.inputs["Roughness"].default_value = 0.34
gm.materials.append(wm)
bv = grip.modifiers.new("bev", "BEVEL")
bv.width, bv.segments = 0.02, 4
bpy.context.view_layer.objects.active = grip
bpy.ops.object.modifier_apply(modifier="bev")
bpy.ops.object.shade_smooth()

if GAME:
    # web Compatibility renderer: reflection-less metal draws black, so ship non-metal + 1024 textures + ~6k tris
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            n.image.scale(1024, 1024)
    bsdf = [n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"][0]
    for lk in list(mat.node_tree.links):
        if lk.to_socket.name in ("Metallic", "Roughness"):
            mat.node_tree.links.remove(lk)
    for n in [n for n in mat.node_tree.nodes if n.type == "SEPARATE_COLOR" or (n.type == "TEX_IMAGE" and n.image == orm_img)]:
        mat.node_tree.nodes.remove(n)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.42
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = min(1.0, 6000.0 / max(tris, 1))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier="dec")
    print("game tris", sum(len(p.vertices) - 2 for p in obj.data.polygons))
if PNG:
    L.studio()
    L.VIEWS["gside"] = (-90.0, 6.0)
    L.render_views("gun", os.path.dirname(PNG) or ".", views=["side", "tq"], samples=24, target=obj)
for o in [o for o in bpy.data.objects if o.type != "MESH"]:
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="JPEG",
                          export_jpeg_quality=75, export_apply=True)
print("export done", OUT, os.path.getsize(OUT))
