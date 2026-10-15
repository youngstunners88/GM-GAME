"""MINE LIFT WALKWAY KIT (skill ep2-set-piece-forge; founder target artifacts/episode2-gold-mine/references/founder_2026-10-10/lift_walkway_target.jpg).

Headless bpy (python3 with the bpy module, or blender -b --python). Writes ONE small GLB of modular pieces the chamber script places:
  Deck2m      2.4 m wide x 2.0 m long plank walkway section: boards ACROSS the walkway with gaps, height/tilt jitter, two stringers
              under it, rusted iron edge straps with rivet heads           (origin: centre of the deck top, deck top at y = 0)
  Post        timber rail post 1.15 m with an iron band               (origin: foot)
  Rail2m      the top hand rail between two posts 2 m apart            (origin: the post-1 end, runs along +z)
  Chain2m     a sagging iron chain between two posts 2 m apart          (origin: the post-1 end, runs along +z, sag 0.32 m)
  Beam4m      a heavy square shaft timber 0.32 m x 4 m                 (origin: centre, runs along +x)
Materials are NAMED (Planks / Timber / RustIron) and carry no textures: the chamber script assigns triplanar textures
(src/episode2/assets/mine_lift/tex_lift_*.jpg) so the GLB stays tiny and one texture serves every instance.
Frame: Blender z-up is exported as glTF y-up; Blender -y becomes glTF +z.

    python3 tools/ep2_blender/build_lift_kit.py [--out src/episode2/assets/mine_lift/mine_lift_kit.glb]
"""
import math
import random
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/assets/mine_lift/mine_lift_kit.glb"
rng = random.Random(1886)

bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


PLANKS = mat("Planks", (0.30, 0.25, 0.20), 0.9)
TIMBER = mat("Timber", (0.33, 0.24, 0.16), 0.85)
IRON = mat("RustIron", (0.35, 0.18, 0.10), 0.75, 0.3)


def box(bm, size, centre, rot=(0.0, 0.0, 0.0), bevel=0.0):
    """Add a (bevelled) box to bm; returns its faces."""
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
    if bevel > 0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect="EDGES")
    m = Matrix.Translation(Vector(centre)) @ Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    bmesh.ops.transform(tmp, matrix=m, verts=tmp.verts)
    me = bpy.data.meshes.new("t")
    tmp.to_mesh(me)
    tmp.free()
    n0 = len(bm.faces)
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bm.faces.ensure_lookup_table()
    return bm.faces[n0:]


def rivet(bm, centre, normal_axis="z", r=0.018):
    tmp = bmesh.new()
    bmesh.ops.create_uvsphere(tmp, u_segments=6, v_segments=3, radius=r)
    bmesh.ops.scale(tmp, vec=Vector((1, 1, 0.55)), verts=tmp.verts)
    rot = {"z": Matrix.Identity(4), "x": Matrix.Rotation(math.pi / 2, 4, "Y"), "y": Matrix.Rotation(math.pi / 2, 4, "X")}[normal_axis]
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(Vector(centre)) @ rot, verts=tmp.verts)
    me = bpy.data.meshes.new("t")
    tmp.to_mesh(me)
    tmp.free()
    n0 = len(bm.faces)
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    bm.faces.ensure_lookup_table()
    return bm.faces[n0:]


def make_obj(name, bm, slots):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in slots:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def assign(faces, idx):
    for f in faces:
        f.material_index = idx


# --- Deck2m: Blender x = across (2.4 m), Blender -y = along the walk (2 m), z up. Deck top at z = 0.
bm = bmesh.new()
z = -1.0
while z < 0.99:
    w = 0.24 + rng.uniform(-0.02, 0.03)
    w = min(w, 1.0 - z)
    cz = z + w * 0.5
    jit = rng.uniform(-0.008, 0.006)
    tilt = rng.uniform(-0.02, 0.02)
    ln = 2.4 + rng.uniform(-0.06, 0.04)
    assign(box(bm, (ln, w - 0.014, 0.06), (rng.uniform(-0.03, 0.03), -cz, -0.03 + jit), (tilt, 0.0, rng.uniform(-0.012, 0.012)), 0.006), 0)
    z += w
for sx in (-0.85, 0.85):                                             # stringers under the boards
    assign(box(bm, (0.16, 2.0, 0.22), (sx, 0.0, -0.17), bevel=0.01), 1)
for sx in (-1.0, 1.0):                                               # rusted edge straps + rivets along both edges
    assign(box(bm, (0.09, 2.0, 0.012), (1.13 * sx, 0.0, 0.003)), 2)
    assign(box(bm, (0.012, 2.0, 0.12), (1.215 * sx, 0.0, -0.05)), 2)
    for k in range(7):
        yy = -0.86 + k * 0.287
        assign(rivet(bm, (1.13 * sx, yy, 0.009)), 2)
make_obj("Deck2m", bm, [PLANKS, TIMBER, IRON])

# --- Post
bm = bmesh.new()
assign(box(bm, (0.18, 0.18, 1.15), (0.0, 0.0, 0.575), bevel=0.012), 0)
assign(box(bm, (0.2, 0.2, 0.06), (0.0, 0.0, 0.92)), 1)
for k in range(4):
    a = k * math.pi / 2
    assign(rivet(bm, (0.101 * math.cos(a), 0.101 * math.sin(a), 0.92), "x" if k % 2 == 0 else "y", 0.012), 1)
make_obj("Post", bm, [TIMBER, IRON])

# --- Rail2m: top rail, slightly rounded, runs along -y (glTF +z)
bm = bmesh.new()
assign(box(bm, (0.13, 2.02, 0.11), (0.0, -1.0, 1.12), bevel=0.02), 0)
make_obj("Rail2m", bm, [TIMBER])

# --- Chain2m: a catenary of alternating links, 0.32 m sag, hung 0.82 m up
bm = bmesh.new()
n = 26
for i in range(n):
    t = (i + 0.5) / n
    y = -2.0 * t
    zc = 0.82 - 0.32 * (1.0 - (2.0 * t - 1.0) ** 2)
    slope = 0.32 * 2.0 * (2.0 * t - 1.0) * 2.0 / 2.0
    tmp = bmesh.new()
    bmesh.ops.create_circle(tmp, segments=8, radius=0.045)
    me0 = bpy.data.meshes.new("t")
    tmp.to_mesh(me0)
    tmp.free()
    # a link = torus from a lathe of a small circle (cheap: 8 x 4)
    tor = bmesh.new()
    seg, ring = 8, 4
    verts = []
    for a_i in range(seg):
        a = a_i * math.tau / seg
        cx, cy = math.cos(a) * 0.03, math.sin(a) * 0.05
        row = []
        for b_i in range(ring):
            b = b_i * math.tau / ring
            rr = 0.009
            p = Vector((cx + math.cos(a) * math.cos(b) * rr, cy + math.sin(a) * math.cos(b) * rr, math.sin(b) * rr))
            row.append(tor.verts.new(p))
        verts.append(row)
    for a_i in range(seg):
        for b_i in range(ring):
            tor.faces.new((verts[a_i][b_i], verts[(a_i + 1) % seg][b_i], verts[(a_i + 1) % seg][(b_i + 1) % ring], verts[a_i][(b_i + 1) % ring]))
    bpy.data.meshes.remove(me0)
    rot = Matrix.Rotation(math.atan(slope), 4, "X") @ (Matrix.Rotation(math.pi / 2, 4, "Y") if i % 2 else Matrix.Identity(4))
    bmesh.ops.transform(tor, matrix=Matrix.Translation(Vector((0.0, y, zc))) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ rot, verts=tor.verts)
    me = bpy.data.meshes.new("t")
    tor.to_mesh(me)
    tor.free()
    n0 = len(bm.faces)
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
make_obj("Chain2m", bm, [IRON])

# --- Beam4m: heavy shaft timber with iron end plates
bm = bmesh.new()
assign(box(bm, (4.0, 0.32, 0.32), (0.0, 0.0, 0.0), bevel=0.015), 0)
for sx in (-1.0, 1.0):
    assign(box(bm, (0.04, 0.36, 0.36), (1.85 * sx, 0.0, 0.0)), 1)
    for dy in (-0.11, 0.11):
        for dz in (-0.11, 0.11):
            assign(rivet(bm, (1.872 * sx, dy, dz), "x", 0.016), 1)
make_obj("Beam4m", bm, [TIMBER, IRON])

for ob in bpy.data.objects:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True, export_materials="EXPORT", export_texcoords=False)
import os
print("kit written", OUT, os.path.getsize(OUT) // 1024, "KB", [(o.name, len(o.data.polygons)) for o in bpy.data.objects])
