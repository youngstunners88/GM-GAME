#!/usr/bin/env python3
"""Fix a parallax backdrop's tile-WRAP seam the way Fable 5.1 diagnosed it
(2026-09-18): the plate is <= viewport wide, so with motion_mirroring = width the
wrap join is on screen at every camera position, and it cuts through a big dark
structure (tree trunk / cloud pillar). A tone cross-fade ("edge heal") only turns
the hard butt-join into a smooth textureless column — that smooth column is the
"sellotape sliver" the founder keeps circling.

Correct fix, per Fable:
  1. roll the plate by W//2 so its NEW edges are formerly-adjacent columns
     (594|595) — the wrap is now natively seamless, zero processing.
  2. the OLD discontinuity (old 1188|0) is now an INTERIOR band at ~W//2;
     REPAINT it with real continued structure (Poisson seamlessClone of a donor
     strip of the same material from ~150px away, shifted so no repeat reads),
     never a cross-fade.
  3. save; motion_mirroring stays = width; Godot unchanged.

Usage: python3 scripts/repaint-wrap-seam.py <src_original> <dst_path> \
          --roll <px> --band <x0> <x1> --donor-dx <px> [--donor-dy <px>]
"""
import argparse
import numpy as np
import cv2
from PIL import Image


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--roll", type=int, required=True)
    ap.add_argument("--band", type=int, nargs=2, required=True)  # x0 x1 in ROLLED space
    ap.add_argument("--donor-dx", type=int, default=160)  # donor strip horizontal offset
    ap.add_argument("--donor-dy", type=int, default=0)    # vertical shift (clouds)
    ap.add_argument("--quality", type=int, default=95)
    a = ap.parse_args()

    rgb = np.asarray(Image.open(a.src).convert("RGB"))
    h, w, _ = rgb.shape
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

    rolled = np.roll(bgr, a.roll, axis=1)
    x0, x1 = a.band
    bw = x1 - x0

    # Donor: a same-material strip shifted horizontally (and optionally vertically)
    # so it carries continuous structure with NO discontinuity, and no obvious repeat.
    src_x0 = x0 - a.donor_dx
    donor = np.roll(rolled, -a.donor_dx, axis=1)          # bring donor content into [x0,x1]
    if a.donor_dy:
        donor = np.roll(donor, a.donor_dy, axis=0)
    patch = donor[:, x0:x1].copy()                         # h x bw

    # Mask: white over the patch, feathered at left/right so Poisson blends the
    # borders into the surrounding painting (top/bottom stay full-height).
    mask = np.full((h, bw), 255, np.uint8)
    feather = min(40, bw // 4)
    for k in range(feather):
        val = int(255 * (k + 1) / (feather + 1))
        mask[:, k] = val
        mask[:, bw - 1 - k] = val

    center = (x0 + bw // 2, h // 2)
    # NORMAL_CLONE (not MIXED): MIXED preserves the strongest gradient from EITHER
    # source, which keeps the underlying discontinuity's hard edge alive (the
    # residual line). NORMAL fully imposes the donor's continuous structure over
    # the band, so the old butt-join vanishes. Validated on L2: seam-band step
    # ratio 3.1x (MIXED) -> 1.6x (NORMAL), i.e. down to plate baseline.
    out = cv2.seamlessClone(patch, rolled, mask, center, cv2.NORMAL_CLONE)

    out_rgb = cv2.cvtColor(out, cv2.COLOR_BGR2RGB)
    Image.fromarray(out_rgb).save(a.dst, quality=a.quality, subsampling=0)

    # Report: interior-step scan (should show no spike at the seam) + edge tile check
    p = out_rgb.astype(np.float32)
    d = np.abs(np.diff(p, axis=1)).mean(axis=(0, 2))
    seam_region = d[max(0, x0 - 10):x1 + 10]
    edge = float(np.abs(p[:, 0] - p[:, -1]).mean())
    print("[repaint] %s -> %s roll=%d band=%d-%d donor_dx=%d dy=%d" %
          (a.src, a.dst, a.roll, x0, x1, a.donor_dx, a.donor_dy))
    print("[repaint] seam-band max step=%.1f (plate median=%.2f, ratio=%.1fx)  wrap edge_diff=%.2f"
          % (seam_region.max(), np.median(d), seam_region.max() / np.median(d), edge))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
