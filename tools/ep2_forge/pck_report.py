#!/usr/bin/env python3
"""List what is inside a Godot 4.3 web-export index.pck (header format 2): totals by file kind and by folder, top files.

    python3 tools/ep2_forge/pck_report.py web_verify/game/index.pck [--top 15]

Why: the 190 MiB pack gate (199,229,440 B) kept failing with no idea what was big. 2026-10-17 breakdown of a 197 MB pck:
audio 82 MB (mp3/ogg), textures 58 MB (.ctex), cutscene video 29 MB, ALL 3D models 22 MB (.scn). Source GLBs are NOT in the
pck (only Godot's imported .scn), so shrinking a source GLB barely changes the pack.
"""
import argparse
import collections
import os
import struct


def entries(path):
    with open(path, "rb") as f:
        d = f.read(1 << 22)
    if d[:4] != b"GDPC" or struct.unpack_from("<I", d, 4)[0] != 2:
        raise SystemExit("not a Godot 4.x pck with header format 2")
    n, = struct.unpack_from("<I", d, 96)
    off, out = 100, []
    for _ in range(n):
        ln, = struct.unpack_from("<I", d, off)
        off += 4
        name = d[off:off + ln].rstrip(b"\0").decode()
        off += ln
        _, size = struct.unpack_from("<QQ", d, off)
        off += 36
        out.append((size, name))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pck")
    ap.add_argument("--top", type=int, default=15)
    a = ap.parse_args()
    ents = entries(a.pck)
    total = sum(s for s, _ in ents)
    print(f"{len(ents)} files, payload {total / 1e6:.1f} MB, file {os.path.getsize(a.pck) / 1e6:.1f} MB (gate 199.2 MB)")
    kind = collections.Counter()
    for s, p in ents:
        kind[os.path.splitext(p)[1].lower() or "(none)"] += s
    print("by kind (MB):", {k: round(v / 1e6, 1) for k, v in kind.most_common(8)})
    print("meaning: .ctex=textures, .mp3str/.oggvorbisstr=audio, .ogv=video, .scn=3D models, .gdc=scripts")
    top = [(s, p) for s, p in ents]
    print(f"top {a.top} files:")
    for s, p in sorted(top, reverse=True)[:a.top]:
        print(f"  {s / 1e6:6.2f} MB  {p.replace('res://', '')}")


if __name__ == "__main__":
    main()
