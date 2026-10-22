#!/usr/bin/env python3
"""Pin small detached pieces to one bone on an already-skinned GLB; nothing else changes.

    python3 tools/ep2_forge/glb_pin_pieces.py in.glb out.glb mask.npz:bone:maxverts

mask.npz holds a bool array `red` (one entry per original vertex). Every detached piece (connected component over
position-welded vertices) of at most maxverts welded vertices that contains a masked vertex gets weight 1.0 on `bone`. maxverts 0 pins only the masked vertices.
Used for the bear's stray arrow needle (see docs/episode2-quality/seam-needle-eval-2026-10-16/README.md).
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
from glb_smooth_skin import read_glb, read_acc, write_acc  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("mask", help="mask.npz:bone:maxverts")
    a = ap.parse_args()
    raw = a.src.read_bytes()
    j, blob, blob_off = read_glb(raw)
    f, bone, mx = a.mask.rsplit(":", 2)
    red, mx = np.load(f)["red"], int(mx)
    joints = j["skins"][0]["joints"]
    names = [j["nodes"][i]["name"] for i in joints]
    b = names.index(bone)
    for m in j["meshes"]:
        for prim in m["primitives"]:
            at = prim["attributes"]
            pos = read_acc(j, blob, at["POSITION"]).astype(np.float64)
            wa = j["accessors"][at["WEIGHTS_0"]]
            idx = read_acc(j, blob, prim["indices"]).astype(np.int64).ravel()
            key = np.round(pos / 1e-5).astype(np.int64)
            _, inv = np.unique(key, axis=0, return_inverse=True)
            inv = inv.ravel()
            u = inv.max() + 1
            parent = np.arange(u)

            def find(x):
                while parent[x] != x:
                    parent[x] = parent[parent[x]]
                    x = parent[x]
                return x
            for t in idx.reshape(-1, 3):
                r = find(inv[t[0]])
                for v in t[1:]:
                    parent[find(inv[v])] = r
            root = np.array([find(i) for i in range(u)])
            size = np.bincount(root, minlength=u)
            hit = np.zeros(u, bool)
            hit[root[inv[red]]] = True
            pick = red.copy() if mx == 0 else hit[root[inv]] & (size[root[inv]] <= mx)
            jn = read_acc(j, blob, at["JOINTS_0"]).copy()
            wt = read_acc(j, blob, at["WEIGHTS_0"]).copy()
            jn[pick] = 0
            jn[pick, 0] = b
            wt[pick] = 0
            wt[pick, 0] = np.iinfo(wt.dtype).max if wa["componentType"] != 5126 else 1.0
            write_acc(j, blob, at["JOINTS_0"], jn)
            write_acc(j, blob, at["WEIGHTS_0"], wt)
            print(f"pinned {int(pick.sum())} vertices ({len(np.unique(root[inv][pick]))} pieces) to {bone}")
    out = bytearray(raw)
    out[blob_off:blob_off + len(blob)] = blob
    a.dst.write_bytes(bytes(out))
    print("wrote", a.dst)


if __name__ == "__main__":
    main()
