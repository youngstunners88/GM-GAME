#!/usr/bin/env python3
"""Downscale the embedded textures of a GLB, leaving mesh, skin and clips byte-identical.

    python3 tools/ep2_forge/glb_downscale_textures.py in.glb out.glb [--scale 0.5] [--quality 88]

Why: Godot stores every embedded texture as GPU-compressed data for the web export, so one 2048x2048
map costs ~11 MiB in the .pck however small the JPEG is. The painted Bull carried 2x2048 + 2x1024 maps and
pushed the pack over the 190 MiB gate. Needs ImageMagick (`magick`). Each image is resized to --scale and
re-encoded as JPEG; buffer views are repacked in order, so accessors and skins keep working.
"""
import argparse
import json
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


def read_glb(path: Path):
    b = path.read_bytes()
    if b[:4] != b"glTF":
        sys.exit(f"{path} is not a GLB")
    off = 12
    j = binchunk = None
    while off < len(b):
        n, t = struct.unpack("<II", b[off:off + 8])
        data = b[off + 8:off + 8 + n]
        if t == 0x4E4F534A:
            j = json.loads(data)
        elif t == 0x004E4942:
            binchunk = data
        off += 8 + n
    return j, binchunk


def resize(data: bytes, scale: float, quality: int) -> bytes:
    with tempfile.TemporaryDirectory() as d:
        src, dst = Path(d, "in.img"), Path(d, "out.jpg")
        src.write_bytes(data)
        subprocess.run(["magick", str(src), "-resize", f"{scale * 100:g}%", "-quality", str(quality), str(dst)],
                       check=True)
        return dst.read_bytes()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("--scale", type=float, default=0.5)
    ap.add_argument("--quality", type=int, default=88)
    a = ap.parse_args()
    j, blob = read_glb(a.src)
    image_views = {im["bufferView"] for im in j.get("images", []) if "bufferView" in im}
    out = bytearray()
    for i, bv in enumerate(j["bufferViews"]):
        start = bv.get("byteOffset", 0)
        data = blob[start:start + bv["byteLength"]]
        if i in image_views:
            new = resize(data, a.scale, a.quality)
            print(f"bufferView {i}: {len(data) // 1024} KB -> {len(new) // 1024} KB")
            data = new
        while len(out) % 4:
            out.append(0)
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(data)
        out += data
    for im in j.get("images", []):
        im["mimeType"] = "image/jpeg"
    while len(out) % 4:
        out.append(0)
    j["buffers"][0]["byteLength"] = len(out)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    a.dst.write_bytes(b"glTF" + struct.pack("<II", 2, total)
                      + struct.pack("<II", len(js), 0x4E4F534A) + js
                      + struct.pack("<II", len(out), 0x004E4942) + bytes(out))
    print(f"{a.src.stat().st_size // 1024} KB -> {a.dst.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
