"""Cut the props that are fused into a Tripo character's hands out of the skinned body, so the hand can hold a gun instead (Rich's pickaxe and gold
nugget). Skill: ep2-tripo-folk-to-game, ep2-armory-guns.

  blender -b rich_prep.blend --factory-startup -P tools/ep2_motion/strip_props.py -- --out rich_clean.blend [--r 0.13] [--min-weight 0.55]

A vertex belongs to a hand prop when its weight on the HAND bone (not the fingers) is high and it lies farther from that bone's head than `--r` metres
(the fist itself stays). Both hands are tested. Prints @@{json} with the vertices removed per hand and the tris left.
"""
import argparse
import json
import sys

import bmesh
import bpy

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--r", type=float, default=0.17)
ap.add_argument("--min-weight", type=float, default=0.55)
ap.add_argument("--hands", nargs="+", default=["hand_l"], help="hand bones whose fused prop is cut (a prop is skinned to the hand AND finger groups)")
ap.add_argument("--sphere", nargs=4, type=float, action="append", default=[], metavar=("X", "Y", "Z", "R"), help="also delete every vertex inside this world-space sphere (a prop cupped in an open hand)")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH")
vg = {g.index: g.name for g in body.vertex_groups}
M = body.matrix_world
kill = set()
report = {}
for hb in a.hands:
    head = arm.matrix_world @ arm.data.bones[hb].head_local
    side = hb.split("_")[-1]
    group_set = {hb} | {g for g in vg.values() if g.endswith("_" + side) and g.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb")}
    n = 0
    for v in body.data.vertices:
        w = sum(g.weight for g in v.groups if vg[g.group] in group_set)
        if w >= a.min_weight and (M @ v.co - head).length > a.r:
            kill.add(v.index)
            n += 1
    report[hb] = n
from mathutils import Vector
for sx, sy, sz, sr in a.sphere:
    c = Vector((sx, sy, sz))
    n = 0
    for v in body.data.vertices:
        if (M @ v.co - c).length < sr and v.index not in kill:
            kill.add(v.index)
            n += 1
    report["sphere_%g_%g_%g" % (sx, sy, sz)] = n
bm = bmesh.new()
bm.from_mesh(body.data)
bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in kill], context="VERTS")
bm.to_mesh(body.data)
bm.free()
body.data.update()
report["tris"] = sum(len(p.vertices) - 2 for p in body.data.polygons)
bpy.ops.wm.save_as_mainfile(filepath=a.out)
print("@@" + json.dumps(report))
