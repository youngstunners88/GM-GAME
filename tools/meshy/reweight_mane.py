#!/usr/bin/env python3
"""reweight_mane.py - re-skin Lil Blunt's leaf mane off the ARM bones onto the neck/upper spine.

  python3 tools/meshy/reweight_mane.py src/episode2/assets/lil_blunt_hero.glb [--dry-run]

Why (founder 2026-09-30, "Lil Blunt is still looking trash"): Meshy's auto-rig weighted ~6,000 mane-leaf
vertices around the shoulders AND the top of the head (next to the raised pickaxe forearm) to the shoulder,
upper-arm and FOREARM bones. In the bind pose (the zipline hang, pickaxe arm straight up) that is invisible; the moment RunnerArmRest seats him and
lowers the pickaxe arm, the arm drags a clump of leaves up over his hat - from the chase camera he read
as "a bush with a hat brim through it". Measured with the see-it-yourself orbit rig.

What it does: a vertex is MANE if its texture colour is leaf-green AND its dominant joint is a shoulder/
arm bone AND it sits farther from that arm's bone line than the arm's own skin (> ~0.11 m; the arm skin
radius measures 0.07-0.10 m). Its weights are blended (smoothstep over 0.10-0.14 m, so there is no seam)
toward the torso: neck near the head, Spine near the shoulders. Positions, UVs and the bind pose are
untouched - the model looks identical until an arm moves; then the leaves stay with his body.
Idempotent: a vertex that already carries a neck/Spine weight is skipped, so re-runs never compound.
"""
import io
import json
import struct
import sys

import numpy as np
from PIL import Image

ARM_BONES = ("RightShoulder", "RightArm", "RightForeArm", "LeftShoulder", "LeftArm", "LeftForeArm")
D0, D1 = 0.10, 0.14


def main(path, dry):
    raw = open(path, "rb").read()
    jlen = struct.unpack("<I", raw[12:16])[0]
    j = json.loads(raw[20:20 + jlen])
    bin_off = 20 + jlen + 8
    buf = bytearray(raw)

    def view(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        dt = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}[a["componentType"]]
        assert not bv.get("byteStride") or bv["byteStride"] == np.dtype(dt).itemsize * n, "interleaved buffers not handled"
        off = bin_off + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return off, np.frombuffer(bytes(buf[off:off + a["count"] * n * np.dtype(dt).itemsize]), dtype=dt).reshape(a["count"], n)

    prim = j["meshes"][0]["primitives"][0]["attributes"]
    _, P = view(prim["POSITION"])
    _, UV = view(prim["TEXCOORD_0"])
    joff, J = view(prim["JOINTS_0"])
    woff, W = view(prim["WEIGHTS_0"])
    P = P.astype(float)
    J = J.astype(int).copy()
    W = W.astype(float).copy()
    img = j["images"][j["textures"][0]["source"]]
    bv = j["bufferViews"][img["bufferView"]]
    ib = bin_off + bv.get("byteOffset", 0)
    T = np.asarray(Image.open(io.BytesIO(bytes(buf[ib:ib + bv["byteLength"]]))).convert("RGB")).astype(float)
    h, w = T.shape[:2]
    col = T[np.clip((UV[:, 1] % 1) * h, 0, h - 1).astype(int), np.clip((UV[:, 0] % 1) * w, 0, w - 1).astype(int)]
    green = (col[:, 1] > col[:, 0] * 1.15) & (col[:, 1] > col[:, 2] * 1.3)

    skin = j["skins"][0]
    names = [j["nodes"][i]["name"] for i in skin["joints"]]
    _, ibm = view(skin["inverseBindMatrices"])
    ibm = ibm.reshape(-1, 4, 4).transpose(0, 2, 1)
    jp = {n: np.linalg.inv(ibm[i])[:3, 3] for i, n in enumerate(names)}
    idx = {n: i for i, n in enumerate(names)}

    def segdist(p, a, b):
        ab = b - a
        t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
        return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)

    dom = J[np.arange(len(J)), W.argmax(1)]
    moved = 0
    for bone in ARM_BONES:
        side = "Right" if bone.startswith("Right") else "Left"
        sel = np.nonzero(green & (dom == idx[bone]))[0]
        if sel.size == 0:
            continue
        d = np.minimum(np.minimum(segdist(P[sel], jp[side + "Arm"], jp[side + "ForeArm"]),
                                  segdist(P[sel], jp[side + "Shoulder"], jp[side + "Arm"])),
                       segdist(P[sel], jp[side + "ForeArm"], jp[side + "Hand"]))
        t = np.clip((d - D0) / (D1 - D0), 0.0, 1.0)
        alpha = t * t * (3.0 - 2.0 * t)
        # neck near the head, Spine (upper chest) at shoulder height
        yn = np.clip((P[sel, 1] - jp["Spine"][1]) / max(jp["neck"][1] - jp["Spine"][1], 1e-3), 0.0, 1.0)
        torso = (idx["neck"], idx["Spine"])
        for k, v in enumerate(sel):
            # already re-skinned by an earlier run (it carries a torso weight): leave it, so re-runs never compound
            if alpha[k] < 0.15 or any(J[v, s] in torso and W[v, s] > 0 for s in range(4)):
                continue
            acc = {}
            for s in range(4):
                if W[v, s] > 0:
                    acc[J[v, s]] = acc.get(J[v, s], 0.0) + W[v, s] * (1.0 - alpha[k])
            acc[idx["neck"]] = acc.get(idx["neck"], 0.0) + alpha[k] * yn[k]
            acc[idx["Spine"]] = acc.get(idx["Spine"], 0.0) + alpha[k] * (1.0 - yn[k])
            top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
            tot = sum(x for _, x in top)
            J[v] = 0
            W[v] = 0.0
            for s, (jj, ww) in enumerate(top):
                J[v, s] = jj
                W[v, s] = ww / tot
            moved += 1
        print("%-14s leaf verts %5d  candidates %5d" % (bone, sel.size, int((alpha > 0).sum())))
    print("total re-skinned:", moved)
    if dry or moved == 0:
        return 0
    jb = J.astype(np.uint8).tobytes()
    wb = W.astype(np.float32).tobytes()
    buf[joff:joff + len(jb)] = jb
    buf[woff:woff + len(wb)] = wb
    open(path, "wb").write(bytes(buf))
    print("wrote", path)
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], "--dry-run" in sys.argv))
