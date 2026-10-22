"""Run in Blender: geometric subtraction must retain area, UVs and normalized skin."""
import sys
from pathlib import Path
import bmesh
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools/ep2_blender'))
from logan_mesh_repair import subtract

def fixture(cover_points):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new('UVMap')
    deform = bm.verts.layers.deform.new()
    target = bm.faces.new([bm.verts.new(p) for p in [(0,0,0),(2,0,0),(0,2,0)]])
    cover = bm.faces.new([bm.verts.new(p) for p in cover_points])
    for f in bm.faces:
        for loop in f.loops:
            loop[uv].uv = Vector((loop.vert.co.x / 2, loop.vert.co.y / 2))
            loop.vert[deform][0] = 0.25
            loop.vert[deform][1] = 0.75
    bm.normal_update()
    return bm, target, cover, uv, deform

bm, target, cover, uv, deform = fixture([(0,0,0),(1,0,0),(0,1,0)])
assert subtract(bm, target, cover)
remaining = [f for f in bm.faces if f != cover]
assert abs(sum(f.calc_area() for f in remaining) - 1.5) < 1e-6
for f in remaining:
    for loop in f.loops:
        v = loop.vert
        assert abs(sum(v[deform].values()) - 1) < 1e-6
        assert len(v[deform]) <= 4
        assert (loop[uv].uv - Vector((v.co.x / 2, v.co.y / 2))).length < 1e-6
bm.free()
bm, target, cover, *_ = fixture([(3,0,0),(4,0,0),(3,1,0)])
assert not subtract(bm, target, cover)
assert target.is_valid and abs(target.calc_area() - 2) < 1e-6
bm.free()
bm, target, cover, *_ = fixture([(-1,-1,0),(5,-1,0),(-1,5,0)])
assert subtract(bm, target, cover) and len(bm.faces) == 1
bm.free()
print('LOGAN_REPAIR: ALL PASS (area, UV, skin, disjoint, complete cover)')
