"""THE FOUNDER'S BOW -> GAME PIECES (founder 2026-10-20, Drive "medieval bow 3d model" Tripo zip/glb; skill ep2-founder-bow).

  blender -b --factory-startup -P tools/ep2_blender/build_founder_bow.py -- --src tripo_convert_*.fbx --tex-dir <the .fbm dir> \
      --out src/episode2/extras/bow/founder_bow.glb [--shots <dir>] [--tris 22000]

The Drive file is ONE fused Tripo mesh of the whole pose at FULL DRAW: Lil Blunt's left arm (green sleeve, studded bracer, glove fist) gripping the
riser, two separate limbs, a nocked arrow with fletching, his right hand pinching the arrow's tail, and a thin rod where the string would be. The
rig it carries is a default auto-rig that does not fit - ignored. What this script makes of it (all coordinates in the BOW frame the game uses:
x = archer's right, y = up along the limbs, z = the way the arrow flies, origin = the grip, metres):
  BowArm     the riser, glove fist, bracer, sleeve and every small part nearest to them (static; the left arm never leaves the grip)
  Limb_Up / Limb_Low   the two limbs, subdivided, each with a `draw` shape key (tip pulled toward the archer, a quadratic bend from the limb root)
  RightHand  the string hand; its origin is the arrow's tail = the NOCK, so moving the node is drawing the string
  Arrow      shaft + steel head + fletching; origin = its tail (nock end), flying +z
  empties    Nock_Rest (where the string sits unstrung), Nock_Full (where the founder's pose has it), Tip_Up / Tip_Low (string anchors at rest),
             Grip, ArrowRest; custom properties on the root carry the bend numbers the game's string uses.
The string itself is built by the game (two segments tip -> nock), never a baked rod. The mesh frames are found from the geometry, not guessed: the limb
axis is tip to tip, the flight axis is arrow head minus tail (they are 89.9 degrees apart in the source).
Prints @@{json}.
"""
import argparse
import json
import math
import os
import struct
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True)
ap.add_argument("--tex-dir", default="")
ap.add_argument("--out", required=True)
ap.add_argument("--shots", default="")
ap.add_argument("--tris", type=int, default=22000)
ap.add_argument("--albedo", type=int, default=2048)
ap.add_argument("--aux", type=int, default=1024)
ap.add_argument("--bend", type=float, default=0.13, help="metres the limb tip travels toward the archer at full draw")
ap.add_argument("--rest-z", type=float, default=-0.20, help="nock z unstrung (string at rest)")
ap.add_argument("--full-z", type=float, default=-0.52, help="nock z at full draw (the string hand's distance behind the grip)")
ap.add_argument("--pinch-z", type=float, default=-0.31, help="the shaft is cut here (game z), just behind the founder hand's pinch")
ap.add_argument("--badge-debug", action="store_true")
ap.add_argument("--emblem-color", default="artifacts/episode2-gold-mine/references/founder_2026-10-10b/emblem/gm_emblem_color.jpg")
ap.add_argument("--emblem-emit", default="artifacts/episode2-gold-mine/references/founder_2026-10-10b/emblem/gm_emblem_emit.png")
ap.add_argument("--badge", nargs=3, type=float, default=[0.0, 0.133, -0.076], help="game-frame centre of the riser's gold pin heads (x y z)")
ap.add_argument("--badge-r", type=float, default=0.040, help="the disc covers the whole gold pin head (~7 cm across), like the rifle emblem (radius 37.6 mm)")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=a.src)
for o in list(bpy.data.objects):
    if o.type == "ARMATURE":
        for c in o.children:
            c.parent = None
        bpy.data.objects.remove(o)
src = next(o for o in bpy.data.objects if o.type == "MESH" and len(o.data.polygons) > 1000)
src.modifiers.clear()
mat = src.data.materials[0]

# ---- 1. islands -> objects
bpy.context.view_layer.objects.active = src
src.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="LOOSE")
bpy.ops.object.mode_set(mode="OBJECT")
parts = sorted([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: -len(o.data.vertices))


def pts(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def centroid(ps):
    return sum(ps, Vector()) / len(ps)


def bbox(ps):
    return Vector(min(p[i] for p in ps) for i in range(3)), Vector(max(p[i] for p in ps) for i in range(3))


# ---- 2. identify the big roles from geometry (source frame)
big = {id(o): pts(o) for o in parts}
riser = parts[0]
arrow = max(parts, key=lambda o: (bbox(big[id(o)])[1] - bbox(big[id(o)])[0]).length if len(o.data.vertices) < 600 else 0)
# the arrow is the longest thin island; the string rod is the second longest thin one
thin = sorted([o for o in parts if len(o.data.vertices) < 600 and o is not riser], key=lambda o: -(bbox(big[id(o)])[1] - bbox(big[id(o)])[0]).length)
arrow, rod = thin[0], thin[1]
hand = parts[1]
rest = [o for o in parts if o not in (riser, hand, arrow, rod)]
# limbs: the two islands (150-260 verts) farthest from the riser centroid
cr = centroid(big[id(riser)])
limbs = sorted([o for o in rest if 100 < len(o.data.vertices) < 300], key=lambda o: -(centroid(big[id(o)]) - cr).length)[:2]
ca = centroid(big[id(arrow)])
a_far = max(big[id(arrow)], key=lambda p: (p - ca).length)
a_other = max(big[id(arrow)], key=lambda p: (p - a_far).length)
# head = the end with fewer vertices around it (a point), tail = the blunt end
n_far = sum(1 for p in big[id(arrow)] if (p - a_far).length < 0.04)
n_oth = sum(1 for p in big[id(arrow)] if (p - a_other).length < 0.04)
head, tail = (a_far, a_other) if n_far < n_oth else (a_other, a_far)
lt = [max(big[id(l)], key=lambda p: (p - cr).length) for l in limbs]
lr = [min(big[id(l)], key=lambda p: (p - cr).length) for l in limbs]
# the upper limb is the one on the +Y side of the grip after the frame is built; build the frame first
Yv = (lt[0] - lt[1]).normalized()
Zd = (head - tail).normalized()
Yd = (Yv - Zd * Yv.dot(Zd)).normalized()
Xd = Yd.cross(Zd).normalized()
GRIP = (lr[0] + lr[1]) / 2
frame_err = math.degrees(abs(math.acos(max(-1, min(1, Yv.dot(Zd)))) - math.pi / 2))
R = Matrix(((Xd.x, Xd.y, Xd.z), (Yd.x, Yd.y, Yd.z), (Zd.x, Zd.y, Zd.z)))      # source -> (right, up, flight) game frame


def to_game(p):
    d = R @ (p - GRIP)
    return Vector((d.x, d.y, d.z))


def to_blender(g):
    return Vector((g.x, -g.z, g.y))                                             # game (glTF y-up) -> blender z-up export frame


up_limb, low_limb = (limbs[0], limbs[1]) if to_game(centroid(big[id(limbs[0])])).y > 0 else (limbs[1], limbs[0])

# ---- 3. every other island joins the nearest big group
groups = {"BowArm": [riser], "RightHand": [hand], "Arrow": [arrow], "Limb_Up": [up_limb], "Limb_Low": [low_limb]}
trees = {}
for name, objs in groups.items():
    ps = [p for o in objs for p in big[id(o)]]
    t = KDTree(len(ps))
    for i, p in enumerate(ps):
        t.insert(p, i)
    t.balance()
    trees[name] = t
members = {k: list(v) for k, v in groups.items()}
# the green sleeve is its own island: the longest one hanging below the grip (game frame y < -0.25); its axis and cut end are measured now
sleeve_src = max((o for o in rest if o not in (up_limb, low_limb) and to_game(centroid(big[id(o)])).y < -0.25 and len(o.data.vertices) < 400),
                 key=lambda o: (bbox(big[id(o)])[1] - bbox(big[id(o)])[0]).length)
SL = [to_game(p) for p in big[id(sleeve_src)]]
slc = sum(SL, Vector()) / len(SL)
slax = Vector((0, 0, 0))
cov = [[sum((p[i] - slc[i]) * (p[j] - slc[j]) for p in SL) for j in range(3)] for i in range(3)]
import numpy as _np
_w, _V = _np.linalg.eigh(_np.array(cov))
slax = Vector(tuple(_V[:, 2]))
if slax.y > 0:
    slax = -slax                                          # pointing down the arm, toward the cut end
slproj = [(p - slc).dot(slax) for p in SL]
sl_end = slc + slax * max(slproj)
sl_r = sum(((p - slc) - slax * (p - slc).dot(slax)).length for p, d in zip(SL, slproj) if d > max(slproj) - 0.05) / max(1, sum(1 for d in slproj if d > max(slproj) - 0.05))
print("SLEEVE_SRC", len(SL), [round(x, 3) for x in sl_end], [round(x, 3) for x in slax], round(sl_r, 3))
for o in rest:
    if o in (up_limb, low_limb):
        continue
    ps = big[id(o)]
    sample = ps[:: max(1, len(ps) // 40)]
    best = min(trees, key=lambda n: min(trees[n].find(p)[2] for p in sample))
    members[best].append(o)
bpy.data.objects.remove(rod)

# ---- 4. join per group, move into the game frame
joined = {}
for name, objs in members.items():
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name + "_mesh"
    joined[name] = ob
for ob in joined.values():
    for v in ob.data.vertices:
        v.co = to_blender(to_game(ob.matrix_world @ v.co))
    ob.matrix_world = Matrix.Identity(4)
    ob.data.update()

# ---- 4b. the open ends (sleeve cut, wrist cut) measured while the mesh is still the clean original: largest boundary loops
def boundary_loops(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.edges.ensure_lookup_table()
    used, loops = set(), []
    for e in bm.edges:
        if not e.is_boundary or e.index in used:
            continue
        stack, comp = [e], []
        used.add(e.index)
        while stack:
            c = stack.pop()
            comp.append(c)
            for v in c.verts:
                for n in v.link_edges:
                    if n.is_boundary and n.index not in used:
                        used.add(n.index)
                        stack.append(n)
        vs = {v.index: v.co.copy() for c in comp for v in c.verts}
        cen = sum(vs.values(), Vector()) / len(vs)
        rad = sum((p - cen).length for p in vs.values()) / len(vs)
        # plane normal by the smallest-variance direction (cross of two spread vectors)
        pl = list(vs.values())
        n = Vector((0, 0, 0))
        for i in range(0, len(pl) - 2, max(1, len(pl) // 12)):
            n += (pl[i] - cen).cross(pl[(i + len(pl) // 4) % len(pl)] - cen)
        loops.append({"edges": len(comp), "centre": cen, "radius": rad, "normal": n.normalized() if n.length > 1e-6 else Vector((0, 0, 1))})
    bm.free()
    return sorted(loops, key=lambda L: -L["edges"])


import numpy as np


def pca(ob):
    P = np.array([tuple(v.co) for v in ob.data.vertices])
    c = P.mean(0)
    w, V = np.linalg.eigh(np.cov((P - c).T))
    return c, V[:, ::-1], w[::-1], P


# ---- 5. decimate the dense parts (UVs kept), smooth normals
tot = lambda: sum(len(p.vertices) - 2 for ob in joined.values() for p in ob.data.polygons)
before = tot()
keep = {"Limb_Up": 1.0, "Limb_Low": 1.0, "Arrow": 1.0}
dense = {n: ob for n, ob in joined.items() if n not in keep}
dense_tris = sum(len(p.vertices) - 2 for ob in dense.values() for p in ob.data.polygons)
budget = a.tris - sum(len(p.vertices) - 2 for n in keep for p in joined[n].data.polygons) * 1.2 - 1200
ratio = min(1.0, budget / max(dense_tris, 1))
for n, ob in dense.items():
    m = ob.modifiers.new("Decimate", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    m.use_collapse_triangulate = True
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier=m.name)


# ---- 5b. the two cut sleeve ends run off-screen: a tapered sleeve is grown from each flat cut along the arm's own axis, UVs taken from a patch of the
#          founder's own green sleeve texture (so it is the same cloth, not a flat colour)
def sleeve_cloth(ob, near):
    """A plain cloth material whose colour is the mean of the real sleeve's texels around `near` (the grown sleeve reads as the same stuff)."""
    import numpy as np
    img = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs["Color"].links))
    W, H = img.size
    arr = np.empty(W * H * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    arr = arr.reshape(H, W, 4)
    uv = ob.data.uv_layers.active.data
    cols = []
    for poly in ob.data.polygons:
        c = sum((ob.data.vertices[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
        if (c - near).length < 0.16:
            u = sum(uv[l].uv.x for l in poly.loop_indices) / len(poly.loop_indices)
            v = sum(uv[l].uv.y for l in poly.loop_indices) / len(poly.loop_indices)
            t = arr[min(H - 1, int(v * H)), min(W - 1, int(u * W)), :3]
            if t[1] > t[0] * 1.08 and t[1] > t[2] * 1.2:                    # the green cloth only: not the bracer's leather or the glove
                cols.append(t)
    m = np.array([0.030, 0.056, 0.020])                                # linear: a dark olive, the sleeve's own shade (the sampled lit texels read far too pale)
    cloth = bpy.data.materials.new("SleeveCloth")
    cloth.use_nodes = True
    bs = next(n for n in cloth.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value = (float(m[0]), float(m[1]), float(m[2]), 1.0)
    print("SLEEVE_CLOTH", [round(float(x), 3) for x in m], len(cols))
    bs.inputs["Roughness"].default_value = 0.92
    bs.inputs["Metallic"].default_value = 0.0
    return cloth


def grow_sleeve(ob, start, axis, r0, length, cloth, segs=14, taper=1.12):
    """A frustum from `start` (blender frame) along `axis`; joined into `ob`."""
    ob.data.materials.append(cloth)
    mi = len(ob.data.materials) - 1
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.verify()
    axis = axis.normalized()
    t1 = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    t2 = axis.cross(t1).normalized()
    rings = []
    for k in range(4):
        f = k / 3
        c = start + axis * length * f
        r = r0 * (1 + (taper - 1) * f)
        rings.append([bm.verts.new(c + (t1 * math.cos(2 * math.pi * i / segs) + t2 * math.sin(2 * math.pi * i / segs)) * r) for i in range(segs)])
    for k in range(3):
        for i in range(segs):
            j = (i + 1) % segs
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            f.material_index = mi
            for l in f.loops:
                l[uv].uv = (0.5, 0.5)
    bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()


arm = joined["BowArm"]
cloth = sleeve_cloth(arm, to_blender(sl_end))
grow_sleeve(arm, to_blender(sl_end), to_blender(slax) - to_blender(Vector((0, 0, 0))), max(sl_r * 1.1, 0.05), 0.30, cloth)
rh = joined["RightHand"]
hcen, hV, hw, hP = pca(rh)
pinch = Vector((-0.01, 0.29, 0.06))                       # the ring the arrow passes through (measured: the hand's only mid-size hole)
hax = Vector(tuple(hV[:, 0]))
if hax.dot(Vector(tuple(hcen)) - pinch) < 0:
    hax = -hax
hpr = (hP - hcen) @ _np.array(tuple(hax))
hend = Vector(tuple(hcen)) + hax * float(hpr.max())
hr = float(sum(_np.linalg.norm((hP[i] - hcen) - _np.array(tuple(hax)) * hpr[i]) for i in range(len(hP)) if hpr[i] > hpr.max() - 0.04) / max(1, int((hpr > hpr.max() - 0.04).sum())))
grow_sleeve(rh, hend, hax, max(hr * 1.1, 0.04), 0.32, cloth)
cut_l, r_l, axis_l, cut_r, r_r, axis_r = to_blender(sl_end), sl_r, slax, hend, hr, hax
print("SLEEVES", [round(x, 3) for x in cut_l], round(r_l, 3), [round(x, 3) for x in axis_l], "|", [round(x, 3) for x in cut_r], round(r_r, 3), [round(x, 3) for x in axis_r])

# ---- 6. limbs: subdivide for a smooth bend, then the draw shape key
LIMB_ROOT = {"Limb_Up": None, "Limb_Low": None}
for n in ("Limb_Up", "Limb_Low"):
    ob = joined[n]
    dm = ob.modifiers.new("Decimate", "DECIMATE")
    dm.decimate_type = "COLLAPSE"
    dm.ratio = 0.5
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.modifier_apply(modifier=dm.name)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(ob.data)
    bm.free()
    ys = [abs(v.co.z) for v in ob.data.vertices]           # blender z = game y
    LIMB_ROOT[n] = min(ys)
    tip = max(ys)
    ob.shape_key_add(name="Basis")
    sk = ob.shape_key_add(name="draw")
    sign = 1.0 if n == "Limb_Up" else -1.0
    for i, v in enumerate(ob.data.vertices):
        gy = v.co.z
        s = max(0.0, min(1.0, (abs(gy) - LIMB_ROOT[n]) / max(tip - LIMB_ROOT[n], 1e-4)))
        gz = -a.bend * (s ** 1.8)                           # toward the archer (game -z)
        gy2 = gy - sign * 0.02 * s * s                      # the limb shortens as it curls
        sk.data[i].co = Vector((v.co.x, v.co.y - gz, gy2))  # blender y = -game z
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
for n, ob in joined.items():
    if n not in ("Limb_Up", "Limb_Low"):
        ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))

# ---- 7. arrow + hand origins at the nock (the arrow's tail), arrow along +z
tail_g = to_game(tail)


def set_origin(ob, g):
    off = to_blender(g)
    for v in ob.data.vertices:
        v.co -= off
    ob.location = off


# the founder's hand pinches the shaft 0.26 m AHEAD of its tail: the shaft behind the fingers is cut away so the string, the nock and the pinch are one point
PINCH_Z = a.pinch_z
arrow_ob = joined["Arrow"]
bm = bmesh.new()
bm.from_mesh(arrow_ob.data)
bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=to_blender(Vector((0, 0, PINCH_Z))), plane_no=Vector((0, -1, 0)), clear_inner=True, clear_outer=False)
bm.to_mesh(arrow_ob.data)
bm.free()
tail_g = Vector((tail_g.x, tail_g.y, PINCH_Z))
set_origin(joined["Arrow"], tail_g)
set_origin(joined["RightHand"], tail_g)

# ---- 8. empties
root = bpy.data.objects.new("FounderBow", None)
bpy.context.scene.collection.objects.link(root)
for ob in joined.values():
    ob.parent = root
tipu = max(joined["Limb_Up"].data.vertices, key=lambda v: v.co.z).co
tipl = min(joined["Limb_Low"].data.vertices, key=lambda v: v.co.z).co
marks = {"Grip": Vector((0, 0, 0)), "Nock_Full": Vector((tail_g.x, tail_g.y, a.full_z)), "Nock_Rest": Vector((tail_g.x, tail_g.y, a.rest_z)),
         "Tip_Up": Vector((tipu.x, tipu.z, -tipu.y)), "Tip_Low": Vector((tipl.x, tipl.z, -tipl.y)), "ArrowRest": Vector((tail_g.x, tail_g.y, 0.0))}
for k, g in marks.items():
    e = bpy.data.objects.new(k, None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = root
    e.location = to_blender(g)
root["bend"] = a.bend
root["limb_root_up"] = LIMB_ROOT["Limb_Up"]
root["limb_root_low"] = LIMB_ROOT["Limb_Low"]

# ---- 8b. (debug) where is the gold badge? vertices whose albedo is gold, clustered
if "--badge-debug" in sys.argv:
    import numpy as np
    img = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and any(l.to_socket.name == "Base Color" for l in n.outputs["Color"].links))
    W, H = img.size
    arr = np.empty(W * H * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    arr = arr.reshape(H, W, 4)
    ob = joined["BowArm"]
    uvl = ob.data.uv_layers.active.data
    gold = []
    for poly in ob.data.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            u, v = uvl[li].uv
            r, g_, b = arr[min(H - 1, int(v * H)), min(W - 1, int(u * W)), :3]
            if r > 0.55 and g_ > 0.40 and b < 0.30 and r > b * 2.2:
                gold.append(tuple(ob.data.vertices[vi].co))
    gp = np.array(gold)
    print("GOLD verts", len(gp))
    if len(gp):
        # cluster by coarse grid
        keys = {}
        for p_ in gp:
            keys.setdefault(tuple((p_ * 20).astype(int)), []).append(p_)
        top = sorted(keys.values(), key=lambda v: -len(v))[:6]
        for c in top:
            c = np.array(c)
            print("GOLDCL", len(c), [round(float(x), 3) for x in c.mean(0)], "bbox", [round(float(x), 3) for x in (c.max(0) - c.min(0))])

# ---- 8c. THE GM EMBLEM, clear, like the rifle's (skill ep2-winchester-logo: the logo disc only, flush, no brown ring, no bezel). The riser carries two small gold
#          pin heads (one each side); a thin flat disc carrying the rifle's own emblem art is laid over each, found by a ray from outside so it sits ON the riser.
from mathutils.bvhtree import BVHTree


def make_emblems():
    arm = joined["BowArm"]
    bm = bmesh.new()
    bm.from_mesh(arm.data)
    bvh = BVHTree.FromBMesh(bm)
    cb = to_blender(Vector(a.badge))
    em = bpy.data.materials.new("GM_Emblem")
    em.use_nodes = True
    nt = em.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = 0.35
    bsdf.inputs["Roughness"].default_value = 0.42
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = bpy.data.images.load(os.path.abspath(a.emblem_color))
    tc.image.colorspace_settings.name = "sRGB"
    nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    te = nt.nodes.new("ShaderNodeTexImage")
    te.image = bpy.data.images.load(os.path.abspath(a.emblem_emit))
    nt.links.new(te.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.6
    me = bpy.data.meshes.new("Emblem_mesh")
    me.materials.append(em)
    bm2 = bmesh.new()
    uvl = bm2.loops.layers.uv.new("UVMap")
    info = []
    for side in (1, -1):
        hit, normal, idx, dist = bvh.ray_cast(Vector((side * 0.4, cb.y, cb.z)), Vector((-side, 0, 0)))
        if hit is None:
            hit, normal = Vector((side * 0.0205, cb.y, cb.z)), Vector((side, 0, 0))
        n = normal.normalized()
        if n.dot(Vector((side, 0, 0))) < 0:
            n = -n
        up = (Vector((0, 0, 1)) - n * n.dot(Vector((0, 0, 1)))).normalized()
        right = (-n).cross(up).normalized()
        r = a.badge_r
        base = hit + n * 0.0016
        ring_top = [bm2.verts.new(base + (right * math.cos(2 * math.pi * i / 48) + up * math.sin(2 * math.pi * i / 48)) * r) for i in range(48)]
        ring_low = [bm2.verts.new(base - n * 0.0030 + (right * math.cos(2 * math.pi * i / 48) + up * math.sin(2 * math.pi * i / 48)) * r) for i in range(48)]
        ctr = bm2.verts.new(base + n * 0.0003)
        side_faces = []
        for i in range(48):
            j = (i + 1) % 48
            f = bm2.faces.new((ctr, ring_top[i], ring_top[j]))
            for l in f.loops:
                d = l.vert.co - base
                l[uvl].uv = (0.5 + d.dot(right) / (2 * r), 0.5 + d.dot(up) / (2 * r))
            g = bm2.faces.new((ring_top[i], ring_low[i], ring_low[j], ring_top[j]))
            for l in g.loops:
                l[uvl].uv = (0.03, 0.03)
            side_faces += [f, g]
        for f in side_faces:                                  # outward: the top fan faces along n, the rim faces away from the axis
            f.normal_update()
            want = n if len(f.verts) == 3 else (sum((v.co for v in f.verts), Vector()) / 4 - base - n * 0.001)
            if f.normal.dot(want) < 0:
                f.normal_flip()
        info.append((round(hit.x, 4), [round(x, 3) for x in n]))
    bm2.to_mesh(me)
    bm2.free()
    bm.free()
    ob = bpy.data.objects.new("Emblem", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = root
    return info


EMBLEM = make_emblems()
print("EMBLEM", EMBLEM)

# ---- 9. textures: shrink and re-point, then export
imgs = {}
for n in mat.node_tree.nodes:
    if n.type == "TEX_IMAGE" and n.image is not None:
        imgs[n.name] = n
for n in mat.node_tree.nodes:
    if n.type == "TEX_IMAGE" and n.image is not None:
        w = a.albedo if n.outputs["Color"].is_linked and any(l.to_socket.name == "Base Color" for l in n.outputs["Color"].links) else a.aux
        if n.image.size[0] > w:
            n.image.scale(w, w)

if a.shots:
    os.makedirs(a.shots, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = 800
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.2, 0.22, 0.25)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.5
    ctr = Vector((0, 0, 0))                                 # blender frame: x right, y = -game z, z up
    for name, d in (("right", (1, 0, 0)), ("behind", (0, 1, 0)), ("top", (0, 0, 1)), ("three", (0.8, 0.9, 0.5)), ("left", (-1, 0, 0))):
        dv = Vector(d).normalized()
        cam.location = ctr + dv * 4
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(a.shots, name + ".png")
        bpy.ops.render.render(write_still=True)
    # the full draw: apply the shape keys at 1 and shoot again
    for n in ("Limb_Up", "Limb_Low"):
        joined[n].data.shape_keys.key_blocks["draw"].value = 1.0
    bpy.context.view_layer.update()
    sc.render.filepath = os.path.join(a.shots, "drawn_right.png")
    cam.location = ctr + Vector((4, 0, 0))
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
    for n in ("Limb_Up", "Limb_Low"):
        joined[n].data.shape_keys.key_blocks["draw"].value = 0.0

for o in bpy.context.scene.objects:
    o.select_set(True)
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", export_apply=False, export_yup=True, use_selection=False, export_morph=True,
                          export_skins=False, export_animations=False, export_cameras=False, export_lights=False,
                          export_image_format="JPEG", export_jpeg_quality=90)
raw = open(a.out, "rb").read()
jl = struct.unpack_from("<I", raw, 12)[0]
gl = json.loads(raw[20:20 + jl])
print("@@" + json.dumps({"ok": True, "out": a.out, "bytes": len(raw), "frame_error_deg": round(frame_err, 2), "tris_before": before, "tris": tot(), "ratio": round(ratio, 3),
                         "nodes": [n.get("name") for n in gl["nodes"]], "images": len(gl.get("images", [])), "limb_roots": LIMB_ROOT, "parts_tris": {n: sum(len(p.vertices) - 2 for p in ob.data.polygons) for n, ob in joined.items()}, 
                         "head": [round(x, 3) for x in to_game(head)], "tail": [round(x, 3) for x in tail_g], "hand_axis_game": [round(float(hax.x), 3), round(float(hax.z), 3), round(float(-hax.y), 3)]}))
