#!/usr/bin/env python3
"""Make Inferno Bull's sculpted rifle RIGID to his left fist, in place (motion fix T1, skill ep2-bull-weapon-motion).

The painted Hunyuan Bull (`src/episode2/assets/inferno_bull_rigged.glb`, live since 2026-10-16) has its Winchester
sculpted INTO the one skinned body mesh, vertical in the left fist. Its skin weights were auto-generated: the barrel
was weighted to Head / neck / Spine02 and the broad stock to LeftUpLeg. Any arm, head or leg motion therefore
stretched the rifle like taffy - the "melted / webbed arm" the founder kept seeing, and the reason every earlier fix
(which moved an INVISIBLE rifle prop, `Ep2BullHero.PAINTED_GLB`) changed nothing on screen.

This rewrites only JOINTS_0 / WEIGHTS_0 of the rifle's vertices to 100 % LeftHand. Positions, UVs, textures, the
rig and the clips are untouched and the file keeps its exact byte size, so the rest pose renders identically.

The rifle is selected geometrically in the Blender-axis frame of the 2.4 m native model (x = his left, -y = his front,
z = up), the frame the selection was authored and checked in (red-highlight renders, 2026-11-21):
  * barrel + sling: within 0.12 m of the fist->muzzle segment, above z 1.47;
  * stock (sculpted as a broad flat blade): x > 0.40, y < -0.04, 0.78 < z <= 1.47;
  * never within 0.07 m of the forearm segment (the wrist keeps its blend).

  python3 tools/ep2_forge/bull_rifle_rigid.py <in.glb> <out.glb>      (prints @@{json})
"""
import json
import struct
import sys

import numpy as np

GLB_MAGIC, CHUNK_JSON, CHUNK_BIN = 0x46546C67, 0x4E4F534A, 0x004E4942
COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
# Blender-axis landmarks of the 2.4 m model (metres).
MUZZLE = np.array([0.555, -0.64, 2.27])
FIST = np.array([0.51, -0.38, 1.42])
FOREARM = (np.array([0.417, 0.117, 1.431]), np.array([0.537, -0.113, 1.353]))


def read(path):
    b = open(path, "rb").read()
    magic, _ver, _total = struct.unpack_from("<III", b, 0)
    assert magic == GLB_MAGIC
    jl, jt = struct.unpack_from("<II", b, 12)
    assert jt == CHUNK_JSON
    js = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl, bt = struct.unpack_from("<II", b, off)
    assert bt == CHUNK_BIN
    return b, js, off + 8, bl


def accessor(js, binbuf, base, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    fmt, size = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    start = base + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", size * n)
    return a, fmt, size, n, start, stride


def _unused_node_world(js, idx):
    parent = {c: p for p, nd in enumerate(js["nodes"]) for c in nd.get("children", [])}
    m = np.eye(4)
    while idx is not None:
        nd = js["nodes"][idx]
        if "matrix" in nd:
            local = np.array(nd["matrix"]).reshape(4, 4).T
        else:
            t = np.array(nd.get("translation", [0, 0, 0]))
            x, y, z, w = nd.get("rotation", [0, 0, 0, 1])
            r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
            s = np.array(nd.get("scale", [1, 1, 1]))
            local = np.eye(4)
            local[:3, :3] = r * s
            local[:3, 3] = t
        m = local @ m
        idx = parent.get(idx)
    return m


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    b, js, base, _bl = read(src)
    out = bytearray(b)
    mesh_node = next(i for i, nd in enumerate(js["nodes"]) if "skin" in nd and "mesh" in nd)
    skin = js["skins"][js["nodes"][mesh_node]["skin"]]
    names = [js["nodes"][j].get("name", "") for j in skin["joints"]]
    lh = names.index("LeftHand")
    # glTF ignores a skinned mesh node's own transform; the inverse-bind matrices cancel the 0.01 "Armature" node, so the
    # raw POSITION values already are the 2.4 m model in metres (checked: z max 2.40).
    world = np.eye(4)
    total = 0
    for prim in js["meshes"][js["nodes"][mesh_node]["mesh"]]["primitives"]:
        at = prim["attributes"]
        a, fmt, size, n, start, stride = accessor(js, b, base, at["POSITION"])
        pos = np.array([struct.unpack_from("<3f", b, start + k * stride) for k in range(a["count"])])
        g = (np.c_[pos, np.ones(len(pos))] @ world.T)[:, :3]
        co = np.c_[g[:, 0], -g[:, 2], g[:, 1]]               # glTF (y up) -> Blender axes (z up)
        upper = (seg_dist(co, FIST, MUZZLE) < 0.12) & (co[:, 2] > 1.47)
        lower = (co[:, 0] > 0.40) & (co[:, 1] < -0.04) & (co[:, 2] > 0.78) & (co[:, 2] <= 1.47)
        sel = (upper | lower) & (co[:, 0] > 0.36) & (seg_dist(co, *FOREARM) > 0.07)
        ja, jfmt, jsize, jn, jstart, jstride = accessor(js, b, base, at["JOINTS_0"])
        wa, wfmt, wsize, wn, wstart, wstride = accessor(js, b, base, at["WEIGHTS_0"])
        one = {"f": 1.0, "B": 255, "H": 65535}[wfmt]
        for k in np.nonzero(sel)[0]:
            struct.pack_into("<4" + jfmt, out, jstart + int(k) * jstride, lh, 0, 0, 0)
            struct.pack_into("<4" + wfmt, out, wstart + int(k) * wstride, one, 0, 0, 0)
        total += int(sel.sum())
        print("@@" + json.dumps({"verts": len(co), "rifle_verts": int(sel.sum()), "zmax": round(float(co[:, 2].max()), 3),
                                 "joints_fmt": jfmt, "weights_fmt": wfmt, "LeftHand_joint": lh}))
    open(dst, "wb").write(out)
    print("@@" + json.dumps({"out": dst, "bytes": len(out), "same_size": len(out) == len(b), "rifle_verts": total}))


if __name__ == "__main__":
    main()
