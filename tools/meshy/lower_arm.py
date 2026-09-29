#!/usr/bin/env python3
"""Lower the founder hero's raised pickaxe arm in place (skill: ep2-runner-camera-light).
Founder 2026-09-29: "I don't like that his left hand just remains up." The Meshy hero is a posed
zipline figure; its pickaxe arm+pick sit in a back slab (z < SLAB_Z). Vertices in that slab are dropped
by up to DROP with a smoothstep over height, so the shoulder stays attached, the arm bunches at the
elbow and the hand rests at chest height with the pick upright beside the hat (target art).
  python3 tools/meshy/lower_arm.py <in.glb> <out.glb> [--drop 0.36] [--dry]
Edits POSITION bytes in the binary chunk, so textures and file size are untouched.
"""
import json, struct, sys
import numpy as np
SLAB_Z, MAX_X, Y0, Y1 = -0.30, 0.12, 0.05, 0.50

def main():
    a = sys.argv[1:]
    drop = float(a[a.index("--drop") + 1]) if "--drop" in a else 0.36
    data = bytearray(open(a[0], "rb").read())
    jlen, _ = struct.unpack_from("<II", data, 12)
    js = json.loads(bytes(data[20:20 + jlen]))
    boff = 20 + jlen + 8
    for mesh in js["meshes"]:
        for prim in mesh["primitives"]:
            acc = js["accessors"][prim["attributes"]["POSITION"]]
            bv = js["bufferViews"][acc["bufferView"]]
            off = boff + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
            n = acc["count"]; stride = bv.get("byteStride", 12)
            v = np.array([struct.unpack_from("<3f", data, off + i * stride) for i in range(n)])
            sel = (v[:, 2] < SLAB_Z) & (v[:, 0] < MAX_X) & (v[:, 1] > Y0)
            t = np.clip((v[:, 1] - Y0) / (Y1 - Y0), 0, 1); w = t * t * (3 - 2 * t)
            v2 = v.copy(); v2[sel, 1] -= drop * w[sel]
            print(f"{sel.sum()} of {n} vertices lowered up to {drop} m")
            if "--dry" in a:
                continue
            for i in range(n):
                struct.pack_into("<3f", data, off + i * stride, *v2[i])
            acc["min"] = v2.min(0).tolist(); acc["max"] = v2.max(0).tolist()
    if "--dry" not in a:
        new = json.dumps(js, separators=(",", ":")).encode()
        new += b" " * ((4 - len(new) % 4) % 4)
        assert len(new) == jlen or len(new) <= jlen, "json grew"
        new = new.ljust(jlen, b" ")
        data[20:20 + jlen] = new
        open(a[1], "wb").write(data)
        print("wrote", a[1])
main()
