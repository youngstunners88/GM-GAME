#!/usr/bin/env python3
"""Replace every mesh in a GLB with a one-triangle stub, keeping skeleton, skin and animations intact.

    python3 tools/ep2_forge/glb_strip_mesh.py in.glb out.glb

For clip-library GLBs: the game instantiates them, copies the AnimationPlayer's clips onto another rig and
frees the scene (Ep2Actor.add_all_clips), so their meshes are never drawn but still cost pack space.
Unreferenced accessors and buffer views are dropped and the rest repacked; indices are remapped.
"""
import json
import struct
import sys
from pathlib import Path


def read_glb(b: bytes):
    off, j, blob = 12, None, b""
    while off < len(b):
        n, t = struct.unpack("<II", b[off:off + 8])
        d = b[off + 8:off + 8 + n]
        if t == 0x4E4F534A:
            j = json.loads(d)
        elif t == 0x004E4942:
            blob = d
        off += 8 + n
    return j, blob


def main(src: str, dst: str) -> None:
    j, blob = read_glb(Path(src).read_bytes())
    # 1. new stub geometry appended to the blob: 3 verts, joint 0, weight 1
    stub = bytearray()
    pos = struct.pack("<9f", 0, 0, 0, 0.001, 0, 0, 0, 0.001, 0)
    jnt = struct.pack("<12H", *([0, 0, 0, 0] * 3))
    wgt = struct.pack("<12f", *([1.0, 0, 0, 0] * 3))
    idx = struct.pack("<3H", 0, 1, 2) + b"\0\0"
    parts = {}
    for name, data in (("pos", pos), ("jnt", jnt), ("wgt", wgt), ("idx", idx)):
        parts[name] = (len(blob) + len(stub), len(data))
        stub += data
    blob = blob + bytes(stub)

    def add_view(name):
        j["bufferViews"].append({"buffer": 0, "byteOffset": parts[name][0], "byteLength": parts[name][1]})
        return len(j["bufferViews"]) - 1

    def add_acc(view, ctype, comp, count, **kw):
        j["accessors"].append({"bufferView": view, "componentType": comp, "count": count, "type": ctype, **kw})
        return len(j["accessors"]) - 1

    a_pos = add_acc(add_view("pos"), "VEC3", 5126, 3, min=[0, 0, 0], max=[0.001, 0.001, 0])
    a_jnt = add_acc(add_view("jnt"), "VEC4", 5123, 3)
    a_wgt = add_acc(add_view("wgt"), "VEC4", 5126, 3)
    a_idx = add_acc(add_view("idx"), "SCALAR", 5123, 3)
    for m in j["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {"POSITION": a_pos, "JOINTS_0": a_jnt, "WEIGHTS_0": a_wgt}
            p["indices"] = a_idx
            p.pop("targets", None)
        m.pop("weights", None)
    # 2. prune unreferenced accessors / buffer views
    used = set()
    for m in j["meshes"]:
        for p in m["primitives"]:
            used |= set(p["attributes"].values()) | {p["indices"]}
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            used.add(s["inverseBindMatrices"])
    for an in j.get("animations", []):
        for sm in an["samplers"]:
            used |= {sm["input"], sm["output"]}
    acc_map = {old: new for new, old in enumerate(sorted(used))}
    accs = [j["accessors"][o] for o in sorted(used)]
    views_used = {a["bufferView"] for a in accs if "bufferView" in a}
    views_used |= {im["bufferView"] for im in j.get("images", []) if "bufferView" in im}
    view_map = {old: new for new, old in enumerate(sorted(views_used))}
    out = bytearray()
    new_views = []
    for o in sorted(views_used):
        v = dict(j["bufferViews"][o])
        d = blob[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        out += b"\0" * (-len(out) % 4)
        v["byteOffset"], v["byteLength"] = len(out), len(d)
        out += d
        new_views.append(v)
    for a in accs:
        if "bufferView" in a:
            a["bufferView"] = view_map[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = view_map[im["bufferView"]]
    for m in j["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {k: acc_map[v] for k, v in p["attributes"].items()}
            p["indices"] = acc_map[p["indices"]]
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            s["inverseBindMatrices"] = acc_map[s["inverseBindMatrices"]]
    for an in j.get("animations", []):
        for sm in an["samplers"]:
            sm["input"], sm["output"] = acc_map[sm["input"]], acc_map[sm["output"]]
    j["accessors"], j["bufferViews"] = accs, new_views
    out += b"\0" * (-len(out) % 4)
    j["buffers"] = [{"byteLength": len(out)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    Path(dst).write_bytes(b"glTF" + struct.pack("<II", 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
                          + struct.pack("<II", len(out), 0x004E4942) + bytes(out))
    print(f"{Path(src).stat().st_size // 1024} KB -> {Path(dst).stat().st_size // 1024} KB")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
