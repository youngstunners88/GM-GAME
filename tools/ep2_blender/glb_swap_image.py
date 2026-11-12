#!/usr/bin/env python3
"""Swap one embedded image of a GLB for a new file, leaving everything else byte-for-byte (meshes, skin, clips, other images).

    python3 tools/ep2_blender/glb_swap_image.py <in.glb> <image index or name substring> <new image file> <out.glb>

Used for texture-only fixes to founder models (Dude's black sunglasses, 2026-11-11): re-exporting from Blender would rewrite the rig
and the clips. The binary chunk is rebuilt view by view, so the old image's bytes do not stay behind as dead weight in the pack.
"""
import json
import struct
import sys


def main() -> int:
    src, which, new_path, dst = sys.argv[1:5]
    with open(src, "rb") as f:
        magic, version, _length = struct.unpack("<III", f.read(12))
        assert magic == 0x46546C67 and version == 2, "not a glTF 2 binary"
        jlen, jtype = struct.unpack("<II", f.read(8))
        assert jtype == 0x4E4F534A
        doc = json.loads(f.read(jlen))
        blen, btype = struct.unpack("<II", f.read(8))
        assert btype == 0x004E4942
        blob = f.read(blen)
    images = doc["images"]
    index = int(which) if which.isdigit() else next(i for i, im in enumerate(images) if which in im.get("name", ""))
    target_view = images[index]["bufferView"]
    new_bytes = open(new_path, "rb").read()
    images[index]["mimeType"] = "image/png" if new_bytes[:8] == b"\x89PNG\r\n\x1a\n" else "image/jpeg"
    out = bytearray()
    for i, view in enumerate(doc["bufferViews"]):
        assert view.get("buffer", 0) == 0, "only single-buffer GLBs"
        start = view.get("byteOffset", 0)
        data = new_bytes if i == target_view else blob[start:start + view["byteLength"]]
        while len(out) % 4:
            out.append(0)
        view["byteOffset"] = len(out)
        view["byteLength"] = len(data)
        out += data
    while len(out) % 4:
        out.append(0)
    doc["buffers"][0]["byteLength"] = len(out)
    text = json.dumps(doc, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    with open(dst, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(text) + 8 + len(out)))
        f.write(struct.pack("<II", len(text), 0x4E4F534A))
        f.write(text)
        f.write(struct.pack("<II", len(out), 0x004E4942))
        f.write(out)
    # Godot's glTF import (embedded_image_handling=1, "extract") writes each embedded image ONCE, next to the GLB, as
    # <glb stem>_<image name>.<ext>, and renders from that file from then on: it never re-extracts over an existing one. Swapping
    # the image inside the GLB alone therefore changes nothing in the game (2026-11-12: Dude's black sunglasses shipped this way).
    import os
    stem = os.path.splitext(src)[0]
    name = images[index].get("name", "")
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        extracted = "%s_%s%s" % (stem, name, ext)
        if os.path.exists(extracted):
            if ext == (".png" if images[index]["mimeType"] == "image/png" else ".jpg"):
                with open(extracted, "wb") as f:
                    f.write(new_bytes)
                print("GLB_SWAP also updated the extracted texture the engine renders: %s" % extracted)
            else:
                print("GLB_SWAP WARNING: %s is what the engine renders and is a different format: update it by hand" % extracted)
    print("GLB_SWAP image %d (%s): %d -> %d bytes; file %d -> %d bytes" % (index, images[index].get("name", "")[:24],
        doc["bufferViews"][target_view]["byteLength"], len(new_bytes), 12 + 8 + jlen + 8 + blen, 12 + 8 + len(text) + 8 + len(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
