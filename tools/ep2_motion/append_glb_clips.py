#!/usr/bin/env python3
"""Copy named animations from one GLB into another that shares its skeleton, touching NOTHING else (founder 2026-10-25 post-draw rewrite:
"townspeople celebrate ... then dance together"; the supplied townspeople's meshes, textures and existing clips stay byte-identical).

    python3 -I tools/ep2_motion/append_glb_clips.py --src retargeted.glb --dst person.glb --clips Cheer,Clap,DanceA,DanceB [--out person.glb]

The source is the person's own GLB round-tripped through Blender with the new clips baked on its armature (tools/ep2_motion/retarget_bvh.py
--glb ... --export-glb ...); Blender's glTF round trip keeps every joint's rest transform (measured: 3e-7 m, 4e-8 rotation), so the clips'
node-local channels are valid on the original joints as they are. Channels are re-targeted by NODE NAME; every sampler's input/output
accessor is copied (component type, count, min/max) into new accessors whose bytes are APPENDED to the destination's BIN chunk (4-byte
aligned). A clip already present in the destination is replaced. Prints @@{json}.
"""
import argparse
import json
import struct
import sys

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
COMP_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


def read_glb(path):
    b = open(path, "rb").read()
    magic, version, length = struct.unpack_from("<III", b, 0)
    if magic != GLB_MAGIC or version != 2:
        sys.exit("not a glTF 2 GLB: " + path)
    off = 12
    js, binc = None, b""
    while off < length:
        clen, ctype = struct.unpack_from("<II", b, off)
        data = b[off + 8: off + 8 + clen]
        if ctype == CHUNK_JSON:
            js = json.loads(data)
        elif ctype == CHUNK_BIN:
            binc = data
        off += 8 + clen
    return js, bytearray(binc)


def write_glb(path, js, binc):
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jb += b" " * ((4 - len(jb) % 4) % 4)
    binc = bytes(binc) + b"\x00" * ((4 - len(binc) % 4) % 4)
    total = 12 + 8 + len(jb) + 8 + len(binc)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, total))
        f.write(struct.pack("<II", len(jb), CHUNK_JSON))
        f.write(jb)
        f.write(struct.pack("<II", len(binc), CHUNK_BIN))
        f.write(binc)


def accessor_bytes(js, binc, idx):
    acc = js["accessors"][idx]
    bv = js["bufferViews"][acc["bufferView"]]
    n = TYPE_N[acc["type"]] * COMP_SIZE[acc["componentType"]]
    stride = bv.get("byteStride", n)
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = bytearray()
    for i in range(acc["count"]):
        out += binc[start + i * stride: start + i * stride + n]
    return acc, bytes(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--dst", required=True)
    ap.add_argument("--clips", required=True)
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    want = [c.strip() for c in a.clips.split(",") if c.strip()]
    sj, sbin = read_glb(a.src)
    dj, dbin = read_glb(a.dst)
    before_len = len(dbin)
    dnode = {n.get("name", ""): i for i, n in enumerate(dj["nodes"])}
    dj.setdefault("animations", [])
    dj.setdefault("accessors", [])
    dj.setdefault("bufferViews", [])
    report = {"copied": [], "skipped_channels": 0}
    for name in want:
        src = next((x for x in sj.get("animations", []) if x.get("name") == name), None)
        if src is None:
            sys.exit("clip %s not in %s" % (name, a.src))
        dj["animations"] = [x for x in dj["animations"] if x.get("name") != name]
        new = {"name": name, "samplers": [], "channels": []}
        acc_map = {}

        def copy_acc(si):
            if si in acc_map:
                return acc_map[si]
            acc, data = accessor_bytes(sj, sbin, si)
            pad = (4 - len(dbin) % 4) % 4
            dbin.extend(b"\x00" * pad)
            bv = {"buffer": 0, "byteOffset": len(dbin), "byteLength": len(data)}
            dbin.extend(data)
            dj["bufferViews"].append(bv)
            na = {"bufferView": len(dj["bufferViews"]) - 1, "componentType": acc["componentType"], "count": acc["count"], "type": acc["type"]}
            for k in ("min", "max", "normalized"):
                if k in acc:
                    na[k] = acc[k]
            dj["accessors"].append(na)
            acc_map[si] = len(dj["accessors"]) - 1
            return acc_map[si]

        sampler_map = {}
        for ch in src["channels"]:
            tnode = ch["target"].get("node")
            tname = sj["nodes"][tnode].get("name", "") if tnode is not None else ""
            if tname not in dnode:
                report["skipped_channels"] += 1
                continue
            si = ch["sampler"]
            if si not in sampler_map:
                s = src["samplers"][si]
                new["samplers"].append({"input": copy_acc(s["input"]), "output": copy_acc(s["output"]),
                                        "interpolation": s.get("interpolation", "LINEAR")})
                sampler_map[si] = len(new["samplers"]) - 1
            new["channels"].append({"sampler": sampler_map[si], "target": {"node": dnode[tname], "path": ch["target"]["path"]}})
        dj["animations"].append(new)
        report["copied"].append({"clip": name, "channels": len(new["channels"])})
    dj["buffers"][0]["byteLength"] = len(dbin)                 # the chunk itself is padded to 4 bytes on write
    out = a.out or a.dst
    write_glb(out, dj, dbin)
    report.update({"ok": True, "bin_before": before_len, "bin_after": len(dbin), "out": out})
    print("@@" + json.dumps(report))


if __name__ == "__main__":
    main()
