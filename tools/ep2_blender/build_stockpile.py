"""THE TOWN STOCKPILE (founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21 + his reference image Mining_depot_building_with_gold):
an open-front depot in the east back lot - gold bars and crates of nuggets inside, a platform scale, two ore carts, a fire pit, a fence.

    blender -b --factory-startup -P tools/ep2_blender/build_stockpile.py -- <stockpile warehouse.glb> <out.glb> [render_dir]

The founder's Tripo model is the shell (roof, STOCKPILE sign, walls, yard props). It came closed: a solid wall flush with the porch
posts and nothing inside. So: its auto-rig skin is stripped, it is scaled x16 (building 13.7 m wide, like the reference), the origin is
the middle of the building's front edge with the front facing glTF +Z (the town kit's frame), the front wall between the corner posts is
cut out, and an interior (plank floor, inner walls, bar pyramids, nugget crates, sacks) is built in CAD behind it. Decimated and its
textures shrunk to the streamed-pack budget (<= ~600 KB).
"""
import bmesh
import bpy
import math
import os
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
RENDER = argv[2] if len(argv) > 2 else ""
S = 16.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
shell = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("tripo"))
mw = shell.matrix_world.copy()
shell.modifiers.clear()
shell.parent = None
shell.matrix_world = mw
for o in list(bpy.context.scene.objects):
    if o != shell:
        bpy.data.objects.remove(o, do_unlink=True)
shell.vertex_groups.clear()
me = shell.data
me.transform(shell.matrix_world)
shell.matrix_world.identity()
# front centre of the building (roof x -0.37..0.49, front edge y ~0): origin there, real size
me.transform(__import__("mathutils").Matrix.Translation(Vector((-0.06, 0.0, 0.0))))
me.transform(__import__("mathutils").Matrix.Scale(S, 4))
shell.name = "Stockpile_Shell"
me.name = "Stockpile_Shell"

bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.004)      # Tripo ships an unwelded triangle soup (106k verts for 50k tris)
bm.faces.ensure_lookup_table()
# THE OPEN FRONT: the closed wall flush with the posts (both skins), between the corner posts, from the floor to under the eave beam
CUT = dict(x0=-6.3, x1=6.4, y0=-0.25, y1=0.6, z0=0.06, z1=float(os.environ.get("SP_EAVE", "3.0")))
kill = []
for f in bm.faces:
    c = f.calc_center_median()
    if abs(f.normal.y) > 0.6 and CUT["x0"] < c.x < CUT["x1"] and CUT["y0"] < c.y < CUT["y1"] and CUT["z0"] < c.z < CUT["z1"]:
        kill.append(f)
print("CUT faces", len(kill))
bmesh.ops.delete(bm, geom=kill, context="FACES")
bm.faces.ensure_lookup_table()


def loose_parts(bm):
    seen = set()
    out = []
    for f in bm.faces:
        if f.index in seen:
            continue
        st = [f]
        seen.add(f.index)
        comp = []
        while st:
            g = st.pop()
            comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        st.append(h)
        vs = [v.co for g in comp for v in g.verts]
        out.append((comp, Vector([min(v[i] for v in vs) for i in range(3)]), Vector([max(v[i] for v in vs) for i in range(3)])))
    return out


PARTS = loose_parts(bm)
if os.environ.get("SP_INSIDE"):
    for comp, mn, mx in PARTS:
        c = (mn + mx) * 0.5
        if c.y > 0.4 and mx.z < 2.9 and len(comp) > 40:
            print("IN", len(comp), [round(x, 2) for x in mn], [round(x, 2) for x in mx])
if os.environ.get("SP_PARTS"):
    for comp, mn, mx in sorted(PARTS, key=lambda p: -len(p[0]))[:30]:
        print("PART", len(comp), [round(x, 2) for x in mn], [round(x, 2) for x in mx])
    print("NPARTS", len(PARTS))
# THE DIORAMA SLAB (the one part spanning the whole 16 x 16 m lot, its dirt berm up to 1.1 m): the town's own ground replaces it, and
# everything that stood on its top (z ~0.47) is lowered onto z = 0
slab = max(PARTS, key=lambda p: (p[2] - p[1]).x * (p[2] - p[1]).y if (p[2] - p[1]).z < 1.3 else 0.0)
print("SLAB faces", len(slab[0]))
bmesh.ops.delete(bm, geom=slab[0], context="FACES")
GROUND = float(os.environ.get("SP_GROUND", "0.47"))
bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0.0, 0.0, -GROUND)))
# THE GOLD (reference: bars stacked in pyramids on pallets, crates heaped with nuggets). The Tripo texture prints it a dull grey-beige,
# so every small boxy piece resting on a pallet or crate inside the depot gets the town's gold (metal, low roughness) instead.
gold_mat = bpy.data.materials.new("Stockpile_Gold")
gold_mat.use_nodes = True
pb = next(n for n in gold_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
pb.inputs["Base Color"].default_value = (0.83, 0.62, 0.22, 1.0)
pb.inputs["Roughness"].default_value = 0.3
pb.inputs["Metallic"].default_value = 1.0
me.materials.append(gold_mat)
n_gold = 0
for comp, mn, mx in PARTS:
    if comp is slab[0]:
        continue
    d = mx - mn
    c = (mn + mx) * 0.5
    inside = 0.0 < c.y < 6.7 and abs(c.x) < 7.0
    piece = 30 <= len(comp) <= 170 and max(d.x, d.y) <= 0.75 and min(d.x, d.y, d.z) >= 0.08 and mn.z > 0.95
    row = 40 <= len(comp) <= 300 and max(d.x, d.y) <= 2.2 and 0.1 <= d.z <= 0.25 and mn.z > 0.68   # a pyramid's fused bottom row
    if inside and (piece or row):
        for f in comp:
            if f.is_valid:
                f.material_index = 1
        n_gold += 1
print("GOLD parts", n_gold)

# WALK BLOCKERS: every solid prop (yard and inside) as a rectangle, overlapping ones merged; the shell's walls are added by the game from
# the building's own size. Written as empties Stockpile_Nav/Block_<n> (centre = position, half extents = scale x/z), like the jail's.
CELL = 0.4
GX0, GY0 = -9.0, -7.5
occ = set()
for comp, mn, mx in PARTS:
    if comp is slab[0] or max((mx - mn).x, (mx - mn).y) > 4.5:
        continue                                # the slab, and the shell's walls / roof (the game adds those from the building's size)
    for f in comp:
        if not f.is_valid:
            continue
        vs = [v.co for v in f.verts]
        n = 2 + int(max((vs[1] - vs[0]).length, (vs[2] - vs[0]).length) / 0.15)
        for i in range(n + 1):
            for j in range(n + 1 - i):
                p = vs[0] + (vs[1] - vs[0]) * (i / n) + (vs[2] - vs[0]) * (j / n)
                if 0.2 < p.z - GROUND < 1.6:          # knee to chest height: what a walker bumps into
                    occ.add((int((p.x - GX0) / CELL), int((p.y - GY0) / CELL)))
# close one-cell gaps (between a barrel and its crate there is no room to walk anyway)
nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
fill = {(c[0] + d[0], c[1] + d[1]) for c in occ for d in nb}
occ |= {c for c in fill if sum(((c[0] + d[0], c[1] + d[1]) in occ) for d in nb) >= 3}
rects = []
left = set(occ)
while left:                                     # greedy cover: the widest run from the lowest cell, grown down while the whole run is filled
    cx, cy = min(left, key=lambda c: (c[1], c[0]))
    x1 = cx
    while (x1 + 1, cy) in left:
        x1 += 1
    y1 = cy
    while all((x, y1 + 1) in left for x in range(cx, x1 + 1)):
        y1 += 1
    for x in range(cx, x1 + 1):
        for y in range(cy, y1 + 1):
            left.discard((x, y))
    rects.append([GX0 + cx * CELL, GY0 + cy * CELL, GX0 + (x1 + 1) * CELL, GY0 + (y1 + 1) * CELL])
rects = [r for r in rects if (r[2] - r[0]) * (r[3] - r[1]) > 0.07]     # lone cells: rope ends, a handle tip
print("CELLS", len(occ), "RECTS", len(rects))
if os.environ.get("SP_RECTS_JSON"):
    import json
    json.dump(rects, open(os.environ["SP_RECTS_JSON"], "w"))
nav = bpy.data.objects.new("Stockpile_Nav", None)
bpy.context.scene.collection.objects.link(nav)
for i, r in enumerate(rects):
    e = bpy.data.objects.new("Block_%d" % i, None)
    e.location = ((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5, 0.0)
    e.scale = ((r[2] - r[0]) * 0.5, (r[3] - r[1]) * 0.5, 1.0)
    e.parent = nav
    bpy.context.scene.collection.objects.link(e)
    if os.environ.get("SP_BLOCKS"):
        print("BLOCK", i, [round(x, 2) for x in r])
bm.to_mesh(me)
bm.free()

# MID-POLY: collapse-decimate to the streamed budget (UV seams and material borders kept)
dec = shell.modifiers.new("dec", "DECIMATE")
dec.ratio = float(os.environ.get("SP_RATIO", "0.13"))
dec.use_collapse_triangulate = True
bpy.context.view_layer.objects.active = shell
bpy.ops.object.modifier_apply(modifier="dec")
print("TRIS", sum(len(p.vertices) - 2 for p in me.polygons))
# TEXTURES: colour only, <= 1024 px (the normal map cost more pack bytes than it showed at back-lot distance: dropped)
for m in me.materials:
    if m is None or not m.use_nodes:
        continue
    for n in list(m.node_tree.nodes):
        if (n.type == "TEX_IMAGE" and n.image is not None and "normal" in n.image.name.lower()) or n.type == "NORMAL_MAP":
            m.node_tree.nodes.remove(n)
for img in bpy.data.images:
    if img.size[0] == 0:
        continue
    side = 512 if "normal" in img.name.lower() else int(os.environ.get("SP_TEX", "1024"))
    if img.size[0] > side:
        img.scale(side, side)
    print("IMG", img.name, img.size[:])
xs = [v.co.x for v in me.vertices]; ys = [v.co.y for v in me.vertices]; zs = [v.co.z for v in me.vertices]
print("BOUNDS", min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))

if OUT != "/dev/null":
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=80,
                              export_apply=True, export_extras=False, export_yup=True)
    print("OUT", OUT, os.path.getsize(OUT))

if RENDER:
    os.makedirs(RENDER, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    sc.render.resolution_x = sc.render.resolution_y = 512
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    next(n for n in w.node_tree.nodes if n.type == "BACKGROUND").inputs[1].default_value = 1.2
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 3.5
    sun.rotation_euler = (0.9, 0.0, -0.5); sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 24
    lamp = bpy.data.objects.new("lamp", bpy.data.lights.new("lamp", "POINT")); lamp.data.energy = 1500
    lamp.location = (0, 2.5, 2.6); sc.collection.objects.link(lamp)
    for name, (pos, tgt) in {"front": ((0, -16, 4), (0, 2, 2)), "front34": ((-10, -13, 6), (0, 2, 1.5)),
                             "inside": ((1, -3, 1.7), (0, 6, 1.2)), "flat": ((0, -12, 2.2), (0, 0, 2.2)), "deep": ((-2, -6, 2.6), (0, 4, 0.8)), "plan": ((0, 0.3, 30), (0, 0.3, 0))}.items():
        cam.location = Vector(pos)
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = f"{RENDER}/{name}.png"
        bpy.ops.render.render(write_still=True)
