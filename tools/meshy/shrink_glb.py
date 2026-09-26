#!/usr/bin/env python3
"""Downscale + re-encode the textures embedded in a GLB, in place of Meshy's 2k minimum.

Usage:  python3 tools/meshy/shrink_glb.py <in.glb> <out.glb> [--max 1024] [--quality 82]

Why: a Meshy GLB is ~90% texture by bytes (one 2048px JPEG ~4 MB vs ~0.5 MB of 8k-tri
geometry), and the web pack has single-digit MiB of headroom under the itch gate.
A runner prop seen at speed does not need 2k. Geometry, UVs, materials and node
structure are copied byte-for-byte; only image bufferViews are rewritten.

Needs Pillow. Pure stdlib otherwise — GLB is parsed with struct.
"""
from __future__ import annotations

import argparse
import io
import json
import struct
import sys

from PIL import Image

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


def _pad(b: bytes, fill: bytes) -> bytes:
    return b + fill * ((4 - len(b) % 4) % 4)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--max", type=int, default=1024, help="max texture edge in px")
    ap.add_argument("--quality", type=int, default=82)
    ap.add_argument("--aux-max", type=int, default=512,
                    help="max edge for NON-base-colour maps (normal, metallic-roughness, AO)")
    a = ap.parse_args()

    raw = open(a.src, "rb").read()
    magic, _ver, _len = struct.unpack_from("<III", raw, 0)
    if magic != GLB_MAGIC:
        raise SystemExit("not a GLB")
    jlen, jtype = struct.unpack_from("<II", raw, 12)
    assert jtype == CHUNK_JSON
    gltf = json.loads(raw[20:20 + jlen])
    boff = 20 + jlen
    blen, btype = struct.unpack_from("<II", raw, boff)
    assert btype == CHUNK_BIN
    binbuf = raw[boff + 8: boff + 8 + blen]

    views = gltf["bufferViews"]
    image_views = {img["bufferView"]: i for i, img in enumerate(gltf.get("images", [])) if "bufferView" in img}
    # Which images are base colour? Those keep --max; PBR detail maps (normal,
    # metallic-roughness, occlusion) get --aux-max — they read fine at lower res
    # and are most of a PBR GLB's bytes.
    tex = gltf.get("textures", [])
    base_imgs = set()
    for m in gltf.get("materials", []):
        bc = (m.get("pbrMetallicRoughness") or {}).get("baseColorTexture")
        if bc is not None and bc.get("index", -1) < len(tex):
            src = tex[bc["index"]].get("source")
            if src is not None:
                base_imgs.add(src)

    # Rebuild the BIN chunk view by view, preserving order and 4-byte alignment.
    out = bytearray()
    before = after = 0
    for vi, v in enumerate(views):
        start = v.get("byteOffset", 0)
        data = binbuf[start: start + v["byteLength"]]
        if vi in image_views:
            im = Image.open(io.BytesIO(data))
            im.load()
            w, h = im.size
            limit = a.max if image_views[vi] in base_imgs else a.aux_max
            scale = min(1.0, limit / max(w, h))
            if scale < 1.0:
                im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
            if im.mode not in ("RGB", "L"):
                # JPEG has no alpha. Meshy base-colour maps are opaque; flatten defensively.
                im = im.convert("RGB")
            enc = io.BytesIO()
            im.save(enc, "JPEG", quality=a.quality, optimize=True, progressive=False)
            before += len(data)
            data = enc.getvalue()
            after += len(data)
            gltf["images"][image_views[vi]]["mimeType"] = "image/jpeg"
            print(f"  image {image_views[vi]}: {w}x{h} -> {im.size[0]}x{im.size[1]}")
        while len(out) % 4:
            out += b"\x00"
        v["byteOffset"] = len(out)
        v["byteLength"] = len(data)
        out += data

    gltf["buffers"][0]["byteLength"] = len(out)
    jbytes = _pad(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    bbytes = _pad(bytes(out), b"\x00")
    total = 12 + 8 + len(jbytes) + 8 + len(bbytes)
    with open(a.dst, "wb") as f:
        f.write(struct.pack("<III", GLB_MAGIC, 2, total))
        f.write(struct.pack("<II", len(jbytes), CHUNK_JSON)); f.write(jbytes)
        f.write(struct.pack("<II", len(bbytes), CHUNK_BIN)); f.write(bbytes)
    print(f"{a.dst}: {len(raw):,} B -> {total:,} B  (textures {before:,} -> {after:,})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
