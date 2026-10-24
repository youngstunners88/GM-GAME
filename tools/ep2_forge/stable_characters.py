#!/usr/bin/env python3
"""Prepare founder stable rigs before gltfpack_safe.sh. No provider calls.

Resize embedded textures without a Blender rebind; preserve skin/rest transforms.
Dude's supplied four-clip export lacks idle: author restrained skeletal breathing
from the first standing pose of his OWN turn clip (no cross-rig pose copying).
"""
import argparse
import copy
import hashlib
import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.spatial.transform import Rotation


class Glb:
    def __init__(self, path):
        b = Path(path).read_bytes()
        assert b[:4] == b"glTF"
        n = struct.unpack_from("<I", b, 12)[0]
        self.doc = json.loads(b[20:20+n])
        self.bin = bytearray(b[28+n:])

    def array(self, idx):
        a = self.doc["accessors"][idx]
        v = self.doc["bufferViews"][a["bufferView"]]
        dtype = {5126: "<f4", 5123: "<u2", 5125: "<u4", 5121: "u1"}[a["componentType"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        stride = v.get("byteStride", np.dtype(dtype).itemsize * width)
        result = np.ndarray((a["count"], width), dtype, self.bin,
                          v.get("byteOffset", 0) + a.get("byteOffset", 0),
                          strides=(stride, np.dtype(dtype).itemsize)).copy()
        if a.get("normalized"):
            result = result.astype(np.float32) / np.iinfo(np.dtype(dtype)).max
        return result

    def blob(self, data):
        self.bin += b"\0" * (-len(self.bin) % 4)
        idx = len(self.doc["bufferViews"])
        self.doc["bufferViews"].append({"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)})
        self.bin += data
        return idx

    def accessor(self, values, kind):
        a = np.asarray(values, dtype="<f4")
        view = self.blob(a.tobytes())
        idx = len(self.doc["accessors"])
        self.doc["accessors"].append({"bufferView": view, "componentType": 5126, "count": len(a),
                                      "type": kind, "min": a.min(axis=0).reshape(-1).tolist(),
                                      "max": a.max(axis=0).reshape(-1).tolist()})
        return idx

    def set_array(self, idx, values):
        a = self.doc["accessors"][idx]
        dtype = {5126: "<f4", 5123: "<u2", 5125: "<u4", 5121: "u1"}[a["componentType"]]
        data = np.asarray(values)
        tolerance = 1e-6
        if a.get("normalized"):
            limit = np.iinfo(np.dtype(dtype)).max
            data = np.rint(np.clip(data, 0, 1) * limit)
            tolerance += 0.5 / limit
        a["bufferView"] = self.blob(np.asarray(data, dtype=dtype).tobytes())
        a.pop("byteOffset", None)
        # A uint8 joint accessor must remain uint8: catch width/stride corruption
        # immediately, before a valid-looking skeleton can mask broken skinning.
        assert np.allclose(self.array(idx), values, atol=tolerance), "serialized accessor changed values"

    def save(self, path):
        self.doc["buffers"][0]["byteLength"] = len(self.bin)
        js = json.dumps(self.doc, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        self.bin += b"\0" * (-len(self.bin) % 4)
        out = struct.pack("<III", 0x46546c67, 2, 28+len(js)+len(self.bin))
        out += struct.pack("<II", len(js), 0x4e4f534a) + js
        out += struct.pack("<II", len(self.bin), 0x004e4942) + self.bin
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_bytes(out)

    def global_matrix(self, i):
        nodes = self.doc["nodes"]
        parents = {c: p for p, n in enumerate(nodes) for c in n.get("children", [])}
        n = nodes[i]
        m = np.eye(4)
        m[:3, :3] = Rotation.from_quat(n.get("rotation", [0, 0, 0, 1])).as_matrix() @ np.diag(n.get("scale", [1, 1, 1]))
        m[:3, 3] = n.get("translation", [0, 0, 0])
        return self.global_matrix(parents[i]) @ m if i in parents else m


def prepare(src, out, role, report):
    g = Glb(src)
    d = g.doc
    original_names = [a["name"] for a in d["animations"]]
    assert len(d["skins"][0]["joints"]) == 65
    textures = []
    for image in d["images"]:
        v = d["bufferViews"][image["bufferView"]]
        raw = g.bin[v.get("byteOffset", 0):v.get("byteOffset", 0)+v["byteLength"]]
        im = Image.open(io.BytesIO(raw)).convert("RGB")
        before = im.size
        im.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
        b = io.BytesIO()
        im.save(b, format="JPEG", quality=80, subsampling=0, optimize=True)
        image["bufferView"] = g.blob(b.getvalue())
        image["mimeType"] = "image/jpeg"
        textures.append({"before": before, "after": im.size, "jpeg_bytes": len(b.getvalue())})
    # The head/hat/cube is one rigid part, not a blend between neck/shoulders.
    skin = d["skins"][0]["joints"]
    names = [d["nodes"][j]["name"] for j in skin]
    head = names.index("mixamorig:Head")
    neck = names.index("mixamorig:Neck")
    neck_y = float(g.global_matrix(skin[neck])[1, 3])
    rigid_count = 0
    rigid_min_y = neck_y + 0.004
    for primitive in d["meshes"][0]["primitives"]:
        attrs = primitive["attributes"]
        pos = g.array(attrs["POSITION"])
        joints = g.array(attrs["JOINTS_0"])
        weights = g.array(attrs["WEIGHTS_0"])
        # Discard sub-percent numerical influences, not meaningful joint blends.
        # They otherwise create artificial skin discontinuities for simplification.
        if role == "dude":
            tiny = weights < 0.005
            weights[tiny] = 0.0
            joints[tiny] = 0
            weights /= np.maximum(weights.sum(axis=1, keepdims=True), 1e-8)
        head_w = np.sum(weights * (joints == head), axis=1)
        rigid = (pos[:, 1] >= rigid_min_y) & (head_w > 0.15)
        weights[rigid] = [1, 0, 0, 0]
        joints[rigid] = [head, 0, 0, 0]
        g.set_array(attrs["JOINTS_0"], joints)
        g.set_array(attrs["WEIGHTS_0"], weights)
        rigid_count += int(rigid.sum())
    authored_idle = False
    if not any(a["name"].lower().startswith("idle") for a in d["animations"]):
        turn = next(a for a in d["animations"] if a["name"].lower().startswith("turn"))
        times = np.linspace(0, 6, 145, dtype="<f4").reshape(-1, 1)
        input_idx = g.accessor(times, "SCALAR")
        idle = {"name": "idle.001", "samplers": [], "channels": []}
        for channel in turn["channels"]:
            node = channel["target"]["node"]
            kind = channel["target"]["path"]
            original = turn["samplers"][channel["sampler"]]
            pose = g.array(original["output"])[0]
            values = np.repeat(pose[None, :], len(times), axis=0)
            bone = d["nodes"][node].get("name", "")
            if kind == "rotation" and bone in ["mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2", "mixamorig:Neck"]:
                phase = times[:, 0] * (2*np.pi/6)
                # Chest-local breathing; no whole-body scale or foot translation.
                amp = 0.45 if "Spine" in bone else 0.7
                delta = Rotation.from_rotvec(np.column_stack([np.sin(phase)*np.deg2rad(amp), np.zeros(len(times)), np.zeros(len(times))]))
                values = (Rotation.from_quat(pose) * delta).as_quat().astype("<f4")
                for i in range(1, len(values)):
                    if np.dot(values[i-1], values[i]) < 0: values[i] *= -1
            idx = g.accessor(values, "VEC4" if kind == "rotation" else "VEC3")
            sampler = len(idle["samplers"])
            idle["samplers"].append({"input": input_idx, "output": idx, "interpolation": "LINEAR"})
            idle["channels"].append({"sampler": sampler, "target": copy.deepcopy(channel["target"])})
        d["animations"].append(idle)
        authored_idle = True
    # Room controller owns ground travel; preserve vertical motion and every clip.
    root = skin[names.index("mixamorig:Hips")]
    root_motion = {}
    for animation in d["animations"]:
        if not animation["name"].lower().startswith(("walk", "run")): continue
        for channel in animation["channels"]:
            if channel["target"] != {"node": root, "path": "translation"}: continue
            idx = animation["samplers"][channel["sampler"]]["output"]
            values = g.array(idx)
            root_motion[animation["name"]] = (values[-1]-values[0]).tolist()
            values[:, 0] = values[0, 0]
            values[:, 2] = values[0, 2]
            g.set_array(idx, values)
    g.save(out)
    result = {"role": role, "source_sha512": hashlib.sha512(Path(src).read_bytes()).hexdigest(),
              "source_bytes": Path(src).stat().st_size, "original_clips": original_names,
              "prepared_clips": [a["name"] for a in d["animations"]], "authored_idle_from_own_turn_pose": authored_idle,
              "textures": textures, "rigid_head_vertices": rigid_count, "rigid_head_min_y": rigid_min_y,
              "joints": 65, "removed_xz_root_travel": root_motion}
    Path(report).write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps(result))


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("source")
    p.add_argument("output")
    p.add_argument("--role", required=True)
    p.add_argument("--report", required=True)
    a = p.parse_args()
    prepare(a.source, a.output, a.role, a.report)
