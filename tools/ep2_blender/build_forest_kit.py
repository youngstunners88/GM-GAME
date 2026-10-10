"""OLD-GROWTH FOREST KIT (skill ep2-set-piece-forge; founder target artifacts/episode2-gold-mine/references/founder_2026-10-10/woods_exterior_target.jpg).

Headless bpy. One small GLB of pieces the woods chamber instances with MultiMesh:
  Trunk   a giant conifer trunk, height 1.0 (scaled per instance to 30-45 m), base radius 1.0 with a lobed ROOT FLARE, tapering to 0.45;
          no UVs needed (the bark is world-triplanar so scaled trunks never stretch it). Material "Bark".
  Crown   a fir crown in METRES for a 40 m tree: whorls of drooping branch CARDS from 16 m to the tip (UVs = the whole branch texture),
          material "Branch" (alpha-cut + wind shader in the chamber). Vertex y is the height, which the wind shader uses as the bend weight.
  Fern    a sword fern: 7 arching cards round a centre, 1.3 m across, material "Fern".
  Snag    a fallen log 6 m long, 0.5 m radius (material "Bark").
Frame: Blender z-up -> glTF y-up.

    python3 tools/ep2_blender/build_forest_kit.py -- --out src/episode2/assets/woods/forest_kit.glb
"""
import math
import random
import sys

import bpy  # bpy before bmesh: the bmesh module only exists once bpy is loaded
import bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/assets/woods/forest_kit.glb"
rng = random.Random(42)
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)
    return m


BARK, BRANCH, FERN = mat("Bark", (0.35, 0.22, 0.15)), mat("Branch", (0.15, 0.3, 0.12)), mat("Fern", (0.2, 0.4, 0.15))


def obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# --- Trunk: rings of 14 verts; radius r(h) with a root flare of 7 lobes in the bottom 6 %
bm = bmesh.new()
SIDES, RINGS = 14, 18
rings = []
for ri in range(RINGS + 1):
    t = ri / RINGS
    h = t ** 1.6                                                     # denser rings near the base where the flare is
    rings.append(h)
vs = []
for h in rings:
    row = []
    for si in range(SIDES):
        a = si * math.tau / SIDES
        r = 1.0 - 0.55 * h ** 0.8
        if h < 0.06:
            k = 1.0 - h / 0.06
            r *= 1.0 + 0.55 * k * k * (0.6 + 0.4 * math.cos(7 * a))
        r *= 1.0 + 0.03 * math.sin(5 * a + h * 30)
        row.append(bm.verts.new((r * math.cos(a), r * math.sin(a), h)))
    vs.append(row)
for ri in range(RINGS):
    for si in range(SIDES):
        bm.faces.new((vs[ri][si], vs[ri][(si + 1) % SIDES], vs[ri + 1][(si + 1) % SIDES], vs[ri + 1][si]))
top = bm.verts.new((0, 0, 1.0))
for si in range(SIDES):
    bm.faces.new((vs[-1][si], vs[-1][(si + 1) % SIDES], top))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
ob = obj("Trunk", bm, [BARK])
for p in ob.data.polygons:
    p.use_smooth = True

# --- Crown: branch cards in whorls, for a 40 m tree. Each branch is TWO cards crossed along its axis (one lying, one on edge), so it
# has volume from below and from the side - a single tilted card reads as a flat stripe (first capture, 2026-10-10).
bm = bmesh.new()
uv = bm.loops.layers.uv.new()
H0, H1 = 14.0, 40.5
n_whorl = 19


def card(base, tip, side_vec, width):
    p0, p1 = base - side_vec * width * 0.5, base + side_vec * width * 0.5
    p2, p3 = tip + side_vec * width * 0.5, tip - side_vec * width * 0.5
    f = bm.faces.new([bm.verts.new(p) for p in (p0, p1, p2, p3)])
    for lp, (u, v) in zip(f.loops, ((0, 1), (1, 1), (1, 0), (0, 0))):      # stem (image top = Blender v 1) at the trunk, tip at the image bottom
        lp[uv].uv = (u, v)


for wi in range(n_whorl):
    t = wi / (n_whorl - 1)
    z = H0 + (H1 - H0) * t + rng.uniform(-0.4, 0.4)
    length = 6.4 * (1.0 - t) ** 0.85 + 1.1                            # long low branches, short near the tip
    width = 0.6 * length + 0.6
    count = 8 if t < 0.6 else (6 if t < 0.85 else 4)
    rot0 = rng.uniform(0, math.tau)
    for ci in range(count):
        a = rot0 + ci * math.tau / count + rng.uniform(-0.25, 0.25)
        droop = math.radians(rng.uniform(10, 30))
        ln = length * rng.uniform(0.8, 1.1)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        side = Vector((-math.sin(a), math.cos(a), 0.0))
        base = Vector((0, 0, z)) + d * 0.5
        tip = base + d * ln * math.cos(droop) - Vector((0, 0, ln * math.sin(droop)))
        axis = (tip - base).normalized()
        up = side.cross(axis).normalized()
        tilt = math.radians(rng.uniform(-20, 20))
        flat = (side * math.cos(tilt) + up * math.sin(tilt)).normalized()
        card(base, tip, flat, width)                                   # the lying card (seen from below)
        card(base, tip, up, width * 0.7)                               # the card on edge (seen from the side)
obj("Crown", bm, [BRANCH])

# --- Fern: three crossed upright cards carrying the whole fern picture (base at the image bottom), 1.4 m across, 1.0 m tall
bm = bmesh.new()
uv = bm.loops.layers.uv.new()
for ci in range(3):
    a = ci * math.pi / 3
    d = Vector((math.cos(a), math.sin(a), 0.0)) * 0.7
    f = bm.faces.new([bm.verts.new(p) for p in (-d, d, d + Vector((0, 0, 1.0)), -d + Vector((0, 0, 1.0)))])
    for lp, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        lp[uv].uv = (u, v)
obj("Fern", bm, [FERN])

# --- Snag: a fallen log
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.55, radius2=0.42, depth=6.0)
bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.45))
obj("Snag", bm, [BARK])

for o in bpy.data.objects:
    o.select_set(True)
import os
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_materials="EXPORT", export_texcoords=True)
print("forest kit", OUT, os.path.getsize(OUT) // 1024, "KB", [(o.name, len(o.data.polygons)) for o in bpy.data.objects])
