#!/usr/bin/env python3
"""Last step for a Tripo auction person: rename the preset clips to the game's names and, for a rig-only person, borrow clips from
another person on the same Tripo mixamo rig (rotation tracks only, matched by bone name; bodies differ, so no translations).

  python3 tools/tripo/install_person.py <final.glb> <out.glb> [--rename idle=Idle,greet_01=Greet] [--borrow <donor.glb> Idle,Play=Idle]
"""
import argparse
import json
import struct


def read(p):
    b = open(p, "rb").read()
    jl = struct.unpack_from("<I", b, 12)[0]
    off = 20 + jl
    bl = struct.unpack_from("<I", b, off)[0]
    return json.loads(b[20:20 + jl]), bytearray(b[off + 8:off + 8 + bl])


def write(p, js, binc):
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * ((4 - len(j) % 4) % 4)
    binc += b"\0" * ((4 - len(binc) % 4) % 4)
    js["buffers"][0]["byteLength"] = len(binc)
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * ((4 - len(j) % 4) % 4)
    open(p, "wb").write(struct.pack("<III", 0x46546C67, 2, 28 + len(j) + len(binc)) + struct.pack("<II", len(j), 0x4E4F534A) + j
                        + struct.pack("<II", len(binc), 0x004E4942) + bytes(binc))


ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--rename", default="")
ap.add_argument("--borrow", nargs=2, metavar=("DONOR", "CLIPS"))
a = ap.parse_args()
js, binc = read(a.src)
names = dict(kv.split("=") for kv in a.rename.split(",") if kv)
for an in js.get("animations", []):
    an["name"] = names.get(an.get("name"), an.get("name"))
if a.borrow:
    dj, db = read(a.borrow[0])
    by_name = {n.get("name"): i for i, n in enumerate(js["nodes"])}
    acc = {}

    def copy(i):
        if i not in acc:
            ac = dict(dj["accessors"][i])
            bv = dj["bufferViews"][ac["bufferView"]]
            data = bytes(db[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
            binc.extend(b"\0" * ((4 - len(binc) % 4) % 4))
            nbv = {"buffer": 0, "byteOffset": len(binc), "byteLength": len(data)}
            if "byteStride" in bv:
                nbv["byteStride"] = bv["byteStride"]
            js["bufferViews"].append(nbv)
            binc.extend(data)
            ac["bufferView"] = len(js["bufferViews"]) - 1
            js["accessors"].append(ac)
            acc[i] = len(js["accessors"]) - 1
        return acc[i]

    for want in a.borrow[1].split(","):
        slot, donor = (want.split("=") + [want])[:2]
        src = next(x for x in dj["animations"] if x.get("name") == donor)
        samplers, channels = [], []
        for ch in src["channels"]:
            node = dj["nodes"][ch["target"]["node"]].get("name")
            if ch["target"]["path"] != "rotation" or node not in by_name:
                continue
            sm = src["samplers"][ch["sampler"]]
            samplers.append({"input": copy(sm["input"]), "output": copy(sm["output"]), "interpolation": sm.get("interpolation", "LINEAR")})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": by_name[node], "path": "rotation"}})
        js.setdefault("animations", []).append({"name": slot, "samplers": samplers, "channels": channels})
write(a.out, js, binc)
print(a.out, [(x["name"], len(x["channels"])) for x in js.get("animations", [])])
