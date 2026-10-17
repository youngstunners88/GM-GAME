#!/usr/bin/env python3
"""Read-only GLB 2.0 inventory. No provider calls or external dependencies."""
import argparse
import json
import re
import struct
from pathlib import Path


def inspect(path):
    raw = path.read_bytes()
    if len(raw) < 20:
        raise ValueError("file too short for GLB")
    magic, version, length = struct.unpack_from("<4sII", raw)
    if magic != b"glTF" or version != 2 or length != len(raw):
        raise ValueError("expected a complete GLB 2.0 file")
    size, chunk_type = struct.unpack_from("<II", raw, 12)
    if chunk_type != 0x4E4F534A or 20 + size > length:
        raise ValueError("missing or truncated JSON chunk")
    doc = json.loads(raw[20:20 + size])
    nodes = doc.get("nodes", [])
    accessors = doc.get("accessors", [])
    joint_ids = sorted({j for s in doc.get("skins", []) for j in s.get("joints", [])})
    joints = [nodes[j].get("name", f"node_{j}") for j in joint_ids]
    finger = re.compile(r"finger|thumb|index|middle|ring|pinky|little", re.I)
    triangles = 0
    modes = {}
    weighted = 0
    primitive_count = 0
    for mesh in doc.get("meshes", []):
        for p in mesh.get("primitives", []):
            primitive_count += 1
            mode = p.get("mode", 4)
            modes[str(mode)] = modes.get(str(mode), 0) + 1
            attrs = p.get("attributes", {})
            weighted += int("JOINTS_0" in attrs and "WEIGHTS_0" in attrs)
            idx = p.get("indices", attrs.get("POSITION"))
            count = accessors[idx]["count"] if idx is not None else 0
            if mode == 4:
                triangles += count // 3
            elif mode in (5, 6):
                triangles += max(0, count - 2)
    return {
        "path": str(path.resolve()), "bytes": len(raw),
        "nodes": [n.get("name", f"node_{i}") for i, n in enumerate(nodes)],
        "skins": len(doc.get("skins", [])), "joints": joints,
        "finger_joint_candidates": [n for n in joints if finger.search(n)],
        "animations": [{"name": a.get("name", f"clip_{i}"),
                        "channels": len(a.get("channels", []))}
                       for i, a in enumerate(doc.get("animations", []))],
        "meshes": len(doc.get("meshes", [])), "primitives": primitive_count,
        "weighted_primitives": weighted, "primitive_modes": modes,
        "triangles_per_mesh_definition": triangles,
        "images": len(doc.get("images", [])),
        "materials": len(doc.get("materials", [])),
        "limits": "Inventory only; counts exclude instancing. Joint names do not prove finger weights or working contact."
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path, nargs="+")
    args = parser.parse_args()
    try:
        print(json.dumps([inspect(p) for p in args.model], indent=2))
    except (OSError, ValueError, KeyError, IndexError, struct.error) as exc:
        parser.exit(2, f"GLB inspection failed: {exc}\n")


if __name__ == "__main__":
    main()
