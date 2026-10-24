#!/usr/bin/env python3
"""Stamp the founder's neon-green ring on a square piece of art (skill gm-game-nft-green-ring).

The six existing NFT plates (design/nft/drive/*.png, 1254x1254) are circular medallions: the art is cropped to a circle and
framed by two neon-green tubes with white-hot cores, a dark-green gap between them, an inner green glow that fades into the
art, and a thin outer halo on a transparent background. Image models cannot draw a clean circle, so the art is generated as a
centred square and this tool crops it to the circle and draws the ring - the same profile on every piece.

    python3 tools/nft/ring_frame.py <art.png|jpg|webp> <out.png> [--size 1254] [--preview-webp 1024]
    python3 tools/nft/ring_frame.py --check <framed.png>      # does an image look like our ring? (exit 1 if not)

Needs numpy and ImageMagick (`magick`); no PIL. The profile numbers were measured from the founder's plates along a horizontal
line through the centre (d = pixels inward from the outer edge, at 1254 px).
"""
import argparse
import subprocess
import sys

import numpy as np

REF = 1254.0
# d (px inward from the outer edge at 1254 px), then R, G, B, overlay alpha
PROFILE = np.array([
    [-7.0, 43, 242, 13, 0.00],
    [-3.0, 43, 242, 13, 0.30],
    [0.0, 43, 242, 13, 0.92],
    [2.0, 42, 239, 14, 1.0],
    [6.0, 60, 248, 40, 1.0],
    [8.0, 244, 254, 246, 1.0],      # outer tube, white-hot core
    [10.0, 60, 248, 40, 1.0],
    [13.0, 32, 246, 10, 1.0],
    [15.0, 4, 139, 0, 1.0],         # dark-green gap
    [21.0, 1, 141, 0, 1.0],
    [24.0, 24, 230, 5, 1.0],
    [26.0, 140, 250, 120, 1.0],
    [28.0, 251, 253, 251, 1.0],     # inner tube, white-hot core
    [30.0, 140, 250, 110, 1.0],
    [32.0, 33, 250, 3, 1.0],
    [35.0, 3, 200, 1, 1.0],
    [40.0, 3, 123, 0, 0.97],        # inner glow fading into the art
    [45.0, 5, 76, 0, 0.85],
    [50.0, 21, 58, 3, 0.55],
    [57.0, 19, 33, 3, 0.0],
])


def read_rgba(path, size):
    out = subprocess.run(["magick", path, "-background", "none", "-resize", f"{size}x{size}!", "-depth", "8", "rgba:-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(out, np.uint8).reshape(size, size, 4).astype(np.float32)


def write_png(arr, path):
    h, w = arr.shape[:2]
    data = np.clip(arr + 0.5, 0, 255).astype(np.uint8).tobytes()
    subprocess.run(["magick", "-size", f"{w}x{h}", "-depth", "8", "rgba:-", path], input=data, check=True)


def frame(art_path, size=1254):
    art = read_rgba(art_path, size)
    k = size / REF
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2.0
    r = np.hypot(xx - c, yy - c)
    outer = size / 2.0 - 7.0 * k                       # leave room for the outer halo
    d = (outer - r) / k                                # inward distance in 1254-px units
    cols = [np.interp(d, PROFILE[:, 0], PROFILE[:, i]) for i in range(1, 5)]
    oa = cols[3]
    inside = np.clip(d + 0.5, 0.0, 1.0)                # antialiased circle edge for the art
    art_a = inside * (art[..., 3] / 255.0)
    out_a = oa + art_a * (1.0 - oa)
    rgb = np.zeros((size, size, 3), np.float32)
    for i in range(3):
        rgb[..., i] = (cols[i] * oa + art[..., i] * art_a * (1.0 - oa)) / np.maximum(out_a, 1e-6)
    return np.dstack([rgb, out_a * 255.0])


def check(path):
    """True when the image is a transparent-cornered circle with the neon ring (loose: for hygiene, not an authenticity proof)."""
    a = read_rgba(path, 1254)
    corners_clear = all(a[y, x, 3] < 8 for y, x in ((3, 3), (3, 1250), (1250, 3), (1250, 1250)))
    mid = a[627, 20:44]                                # along the ring at the left edge
    bright_green = float(np.mean((mid[:, 1] > 180) & (mid[:, 0] < 120) & (mid[:, 3] > 200)))
    white_core = float(np.max(np.minimum(np.minimum(mid[:, 0], mid[:, 1]), mid[:, 2])))
    ok = corners_clear and bright_green > 0.3 and white_core > 200
    print(f"corners_clear={corners_clear} bright_green={bright_green:.2f} white_core={white_core:.0f} -> {'RING OK' if ok else 'NO RING'}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?")
    ap.add_argument("out", nargs="?")
    ap.add_argument("--size", type=int, default=1254)
    ap.add_argument("--preview-webp", type=int, default=0, help="also write <out>.webp at this size")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        sys.exit(0 if check(a.src) else 1)
    if not a.src or not a.out:
        ap.error("src and out are required")
    write_png(frame(a.src, a.size), a.out)
    if a.preview_webp:
        subprocess.run(["magick", a.out, "-resize", f"{a.preview_webp}x{a.preview_webp}", "-quality", "88", a.out.rsplit(".", 1)[0] + ".webp"], check=True)
    print("ring framed ->", a.out)


if __name__ == "__main__":
    main()
