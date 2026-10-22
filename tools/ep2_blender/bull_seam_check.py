"""Seam audit of the head-grafted Bull GLB: boundary (open) edges of each primitive near the head/body seam and how many
of them are VISIBLE from outside (ray from 26 directions reaches the edge midpoint unblocked within 1.5 mm, rays start 1.5 m away so interiors are not "seen").

  blender -b --python tools/ep2_blender/bull_seam_check.py -- <glb> [--y0 1.78 --y1 2.06]
"""
import sys, itertools
import numpy as np
sys.path.insert(0, "/tmp/claude-1000/w")
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import json, struct
argv = sys.argv[sys.argv.index("--") + 1:]
glb = argv[0]
def opt(n, d): return float(argv[argv.index(n) + 1]) if n in argv else d
Y0, Y1 = opt("--y0", 1.78), opt("--y1", 2.06)
CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32}; NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
raw = open(glb, "rb").read(); jl, _ = struct.unpack_from("<II", raw, 12); j = json.loads(raw[20:20 + jl]); off = 20 + jl
bl, _ = struct.unpack_from("<II", raw, off); b = raw[off + 8:off + 8 + bl]
def acc(i):
    a = j["accessors"][i]; bv = j["bufferViews"][a["bufferView"]]; n = NC[a["type"]]
    return np.frombuffer(b, CT[a["componentType"]], count=a["count"] * n, offset=bv.get("byteOffset", 0) + a.get("byteOffset", 0)).reshape(a["count"], n).astype(np.float64)
prims = []
for pr in j["meshes"][0]["primitives"]:
    prims.append((acc(pr["attributes"]["POSITION"]), acc(pr["indices"]).astype(np.int64).reshape(-1, 3)))
verts = np.vstack([p for p, _ in prims]); tri = np.vstack([t + (0 if k == 0 else len(prims[0][0])) for k, (_, t) in enumerate(prims)])
tag = np.concatenate([np.full(len(t), k) for k, (_, t) in enumerate(prims)])
bvh = BVHTree.FromPolygons([Vector(v) for v in verts], [tuple(t) for t in tri])
dirs = [np.array(d, float) / np.linalg.norm(d) for d in itertools.product((-1, 0, 1), repeat=3) if any(d)]
names = ["body", "head"]
for k, (P, T) in enumerate(prims):
    _, wid = np.unique(np.round(P * 1e4).astype(np.int64), axis=0, return_inverse=True); wid = wid.reshape(-1)
    e = np.sort(np.vstack([np.c_[wid[T[:, 0]], wid[T[:, 1]]], np.c_[wid[T[:, 1]], wid[T[:, 2]]], np.c_[wid[T[:, 2]], wid[T[:, 0]]]]), 1)
    ue, inv, cnt = np.unique(e, axis=0, return_inverse=True, return_counts=True)
    bnd = ue[cnt == 1]
    first = np.zeros(wid.max() + 1, np.int64); first[wid] = np.arange(len(wid))
    A, B = P[first[bnd[:, 0]]], P[first[bnd[:, 1]]]
    mid = (A + B) / 2
    near = (mid[:, 1] > Y0) & (mid[:, 1] < Y1) & (np.abs(mid[:, 0]) < 0.45) & (mid[:, 2] > -0.12)
    vis = 0; ex = []; vm = []
    for m in mid[near]:
        seen = False
        for d in dirs:
            o = Vector(m + d * 1.5)
            hit = bvh.ray_cast(o, Vector(-d), 2.0)
            if hit[0] is not None and (Vector(hit[0]) - Vector(m)).length < 0.0015:
                seen = True; break
        vis += seen
        if seen: vm.append(m)
        if seen and len(ex) < 3: ex.append(m.round(3).tolist())
    if vm:
        vm = np.array(vm); print("  visible rim bbox", vm.min(0).round(3), vm.max(0).round(3), "x hist", np.histogram(vm[:, 0], bins=[-0.5, -0.3, -0.2, -0.1, 0, 0.1, 0.2, 0.3, 0.5])[0].tolist(), "z hist(-.2..0.6 step .2)", np.histogram(vm[:, 2], bins=[-0.2, 0, 0.2, 0.4, 0.6])[0].tolist())
    print("SEAM %-4s boundary_edges_total=%d near_seam=%d visible=%d  e.g. %s" % (names[k], len(bnd), int(near.sum()), vis, ex))
