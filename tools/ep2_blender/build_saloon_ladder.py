"""THE SALOON'S SIDE LADDER (founder 2026-11-21: the two old regulars drink OUTSIDE on the saloon's balcony and there was no way up;
"a LADDER on the outside side wall, not an interior staircase"; skill ep2-saloon-roof-access).

    blender -b --factory-startup -P tools/ep2_blender/build_saloon_ladder.py -- [--out src/episode2/extras/town/saloon_ladder.glb]

One GLB root `Saloon_Ladder` at REAL size. Ladder-local frame (Ep2SaloonLadder places it): origin on the ground midway between the rails,
rungs along X, the climbing side +Z (the climber stands at +Z and faces -Z), the saloon's corner and balcony toward -Z. Two surfaces:
`LadderWood` (rails, rungs, sill, top step) and `LadderIron` (wall stays, roof hooks, bolt heads, foot pins); the game dresses both in its
own timber / iron, the same materials as the procedural stand-in it replaces when the streamed pack mounts. Prints @@{json}.

Numbers the game relies on (Ep2SaloonLadder): rail centres x = +-0.25, rail section 0.05 x 0.08, rails 0 -> 4.98 (1 m above the balcony
boards at 3.98), 13 rungs at y = 0.30 ... 3.90, the top step's upper face at 3.98 reaching 0.47 toward -Z (over the porch roof edge onto
the balcony's end), the wall stays on the -X rail ending on the saloon's corner board at (-0.30, y, -0.42).
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/town/saloon_ladder.glb"

RAIL_X = 0.25
RAIL_W, RAIL_D = 0.05, 0.08
TOP = 4.98
DECK = 3.98
RUNGS = [round(0.30 * (i + 1), 2) for i in range(13)]          # 0.30 ... 3.90
RUNG_R = 0.018
CORNER = Vector((-0.30, 0.0, -0.42))                            # the saloon's front corner board, ladder-local
STAYS_Y = [0.95, 2.15, 3.35]

bpy.ops.wm.read_factory_settings(use_empty=True)
WOOD = bpy.data.materials.new("LadderWood")
WOOD.diffuse_color = (0.42, 0.33, 0.24, 1.0)
IRON = bpy.data.materials.new("LadderIron")
IRON.diffuse_color = (0.16, 0.15, 0.14, 1.0)
PARTS = {"LadderWood": [], "LadderIron": []}


def _obj(bm, mat):
    me = bpy.data.meshes.new("part")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("part", me)
    bpy.context.scene.collection.objects.link(ob)
    PARTS[mat].append(ob)
    return ob


def box(size, centre, mat, bevel=0.0, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5)
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(centre), verts=bm.verts)
    return _obj(bm, mat)


def cyl_between(a, b, r, mat, segs=10):
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=d.length)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.transform(bm, matrix=q.to_matrix().to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(a + b) * 0.5, verts=bm.verts)
    return _obj(bm, mat)


def strap(a, b, w, t, mat):
    """A flat iron bar from a to b, `w` wide (vertical) and `t` thick."""
    a, b = Vector(a), Vector(b)
    d = b - a
    yaw = math.atan2(d.x, d.z)
    rot = Matrix.Rotation(yaw, 4, "Y")
    return box((t, w, d.length), (a + b) * 0.5, mat, rot=rot)


# --- the two rails: weathered 2x3 stiles, chamfered, a little rounded off at the top --------------------------------------------
for sx in (-1, 1):
    box((RAIL_W, TOP - 0.02, RAIL_D), (sx * RAIL_X, (TOP - 0.02) * 0.5, 0.0), "LadderWood", bevel=0.008)
    box((RAIL_W * 0.86, 0.04, RAIL_D * 0.86), (sx * RAIL_X, TOP - 0.02, 0.0), "LadderWood", bevel=0.012)
# --- the rungs: round oak dowels through the rails (their end grain shows on the outside faces) ---------------------------------
for y in RUNGS:
    cyl_between((-RAIL_X - RAIL_W * 0.5 - 0.004, y, 0.0), (RAIL_X + RAIL_W * 0.5 + 0.004, y, 0.0), RUNG_R, "LadderWood", segs=8)
# --- the foot: a timber sill the rails are let into, spiked to the ground ------------------------------------------------------------
box((0.74, 0.07, 0.20), (0.0, 0.035, 0.0), "LadderWood", bevel=0.01)
for sx in (-1, 1):
    cyl_between((sx * 0.33, 0.075, 0.06), (sx * 0.33, 0.085, 0.06), 0.014, "LadderIron", segs=8)
    cyl_between((sx * 0.33, 0.075, -0.06), (sx * 0.33, 0.085, -0.06), 0.014, "LadderIron", segs=8)
# --- the top step: a plank from the rails over the porch roof's edge onto the end of the balcony (its upper face is the deck) -----
box((0.56, 0.05, 0.52), (0.0, DECK - 0.025, -0.21), "LadderWood", bevel=0.006)
for sx in (-1, 1):
    box((0.07, 0.09, 0.07), (sx * 0.20, DECK - 0.095, -0.40), "LadderWood", bevel=0.006)   # cleats under it, on the balcony's joist
    # iron hooks over the porch roof fascia, bolted through the rails
    strap((sx * RAIL_X, DECK - 0.32, -0.04), (sx * RAIL_X, DECK - 0.32, -0.30), 0.04, 0.008, "LadderIron")
    strap((sx * RAIL_X, DECK - 0.32, -0.30), (sx * RAIL_X, DECK - 0.42, -0.30), 0.04, 0.008, "LadderIron")
    cyl_between((sx * RAIL_X - 0.03, DECK - 0.32, -0.02), (sx * RAIL_X + 0.03, DECK - 0.32, -0.02), 0.009, "LadderIron", segs=6)
# --- the wall stays: flat iron from the -X rail back into the saloon's corner board, two bolts each end ---------------------------
for y in STAYS_Y:
    a = Vector((-RAIL_X, y, -RAIL_D * 0.5))
    b = Vector((CORNER.x, y, CORNER.z))
    strap(a, b, 0.045, 0.008, "LadderIron")
    box((0.06, 0.07, 0.01), (b.x, y, b.z + 0.005), "LadderIron")                         # the plate on the corner board
    for dy in (-0.02, 0.02):
        cyl_between((b.x, y + dy, b.z + 0.008), (b.x, y + dy, b.z + 0.02), 0.008, "LadderIron", segs=6)
        cyl_between((-RAIL_X - 0.034, y + dy * 0.5, -0.01), (-RAIL_X - 0.026, y + dy * 0.5, -0.01), 0.008, "LadderIron", segs=6)
# the +X rail is tied to the -X one under the step by a diagonal iron brace (the ladder does not rack)
strap((RAIL_X, 3.10, -RAIL_D * 0.5 - 0.005), (-RAIL_X, 3.70, -RAIL_D * 0.5 - 0.005), 0.03, 0.007, "LadderIron")

# --- join per material into one mesh with two surfaces -------------------------------------------------------------------------
root = bpy.data.objects.new("Saloon_Ladder", None)
bpy.context.scene.collection.objects.link(root)
geo_parts = []
for name, obs in PARTS.items():
    for ob in obs:
        ob.data.materials.append(WOOD if name == "LadderWood" else IRON)
    geo_parts.extend(obs)
bpy.ops.object.select_all(action="DESELECT")
for ob in geo_parts:
    ob.select_set(True)
bpy.context.view_layer.objects.active = geo_parts[0]
bpy.ops.object.join()
geo = bpy.context.view_layer.objects.active
geo.name = "Saloon_Ladder_geo"
geo.data.name = "Saloon_Ladder_geo"
# merge only coincident verts of the same part, then smooth by angle (sharp CAD-like edges kept)
bm = bmesh.new()
bm.from_mesh(geo.data)
# authored in the GAME's frame (y up); Blender is z up and the glTF exporter turns its z back into y: game (x, y, z) = Blender (x, -z, y)
bmesh.ops.transform(bm, matrix=Matrix.Rotation(math.radians(90.0), 4, "X"), verts=bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
for f in bm.faces:
    f.smooth = True
bm.to_mesh(geo.data)
bm.free()
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35.0))
except (AttributeError, RuntimeError, TypeError):
    geo.data.use_auto_smooth = True
# no UVs: the game dresses it in world-triplanar timber and iron (the same materials as its procedural stand-in)
geo.parent = root

os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_normals=True, export_texcoords=False, export_materials="EXPORT")
tris = sum(len(p.vertices) - 2 for p in geo.data.polygons)
bb = [geo.matrix_world @ Vector(c) for c in geo.bound_box]
print("@@" + json.dumps({"out": OUT, "bytes": os.path.getsize(OUT), "tris": tris,
                         "min": [round(min(v[i] for v in bb), 3) for i in range(3)],
                         "max": [round(max(v[i] for v in bb), 3) for i in range(3)]}))
