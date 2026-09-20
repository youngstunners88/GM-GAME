#!/usr/bin/env python3
"""MAKE A PARALLAX PLATE SEAMLESS (offset-then-heal).

Why
---
Every backdrop drawn on a ParallaxLayer with motion_mirroring repeats forever.
Where one copy ends the next begins, so the plate's RIGHT edge sits directly
against its own LEFT edge. If those two edges do not match, that butt-join is a
hard vertical line on screen — the "dividing line" the founder has circled over
and over. Measured mismatch before this ran: bg_l1_forest.jpg wrapD=14.7.

Overlapping the tiles does NOT hide this. It stamps the mismatched left edge on
top of the right edge, which makes the join MORE visible, not less. That was a
real regression (live: L1 seam at x=1216, exactly the mirror period).

Method: offset-then-heal (not an edge cross-fade)
-------------------------------------------------
  1. np.roll the plate by W/2. The NEW outer edges are two columns that were
     already adjacent in the original art, so the wrap boundary becomes
     seamless by construction — zero processing, zero ghosting at the edges.
  2. The OLD mismatched boundary is now an interior band at the centre. Heal
     just that band with a cosine-weighted blend between the content either
     side of it.

An edge cross-fade was rejected: it permanently ghosts BOTH outer edges of the
art, and those edges are exactly what the player sees at the wrap. Offset-heal
confines all edited pixels to one interior band instead.

The plate is only shifted horizontally, which is invisible for a repeating
backdrop, and no pixel is resized or squashed.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image


def wrap_diff(arr, n=30):
    """Join-STEP ratio: the discontinuity across the tile join, divided by the
    plate's own typical adjacent-column change.

    Comparing 30-column MEANS (the first version of this) was wrong: it
    punishes a legitimate left-to-right gradient, and it scored a plate as
    "worse" after a repair that had actually made the join continuous. What
    reads as a dividing line is a STEP — the art failing to continue across the
    boundary — so measure the step and normalise by how much this particular
    plate changes from one column to the next anyway.

    ~1.0 = the join is as smooth as ordinary neighbouring columns (seamless).
    >=3  = a hard join that will render as a vertical line.
    """
    a = arr[:, :, :3].astype(float)
    join = float(np.abs(a[:, 0] - a[:, -1]).mean())
    adj = np.abs(np.diff(a, axis=1)).mean(axis=(0, 2))
    base = float(np.median(adj))
    return join / base if base > 0.01 else 0.0


def make_seamless(arr, band=72):
    """Roll by W/2, then Poisson-blend the now-interior old boundary.

    Step 1 (the roll) is artifact-free by construction: the new outer edges are
    two columns that were already adjacent in the source art, so the tile join
    becomes seamless with zero pixels edited.

    Step 2 must repair the old boundary, now sitting mid-plate. A hand-rolled
    cosine/mirror blend was tried first and rejected on sight: it produced a
    washed-out mirrored band that looked exactly like the "poorly pasted
    together" artifact this whole exercise exists to remove. cv2.seamlessClone
    (Poisson) instead solves for a gradient-consistent patch, so a donor strip
    of the same material drops in with no visible border.

    NORMAL_CLONE, not MIXED_CLONE: MIXED keeps the strongest gradient from
    either source, which preserves the very hard edge we are trying to delete.
    """
    import cv2
    h, w = arr.shape[:2]
    rgb = arr[:, :, :3]
    band = int(min(max(16, band), w // 8))
    rolled = np.roll(rgb, w // 2, axis=1)
    bgr = cv2.cvtColor(rolled.astype(np.uint8), cv2.COLOR_RGB2BGR)

    cx = w // 2
    x0, x1 = cx - band, cx + band
    donor_dx = max(3 * band, 160)
    # Pull a same-material strip from well clear of the seam.
    donor = np.roll(bgr, -donor_dx, axis=1)
    patch = donor[:, x0:x1].copy()

    mask = np.full((h, x1 - x0), 255, np.uint8)
    feather = max(4, (x1 - x0) // 4)
    for k in range(feather):
        v = int(255 * (k + 1) / (feather + 1))
        mask[:, k] = v
        mask[:, (x1 - x0) - 1 - k] = v

    out = cv2.seamlessClone(patch, bgr, mask, ((x0 + x1) // 2, h // 2), cv2.NORMAL_CLONE)
    out_rgb = cv2.cvtColor(out, cv2.COLOR_BGR2RGB)
    if arr.shape[2] == 4:
        alpha = np.roll(arr[:, :, 3], w // 2, axis=1)[:, :, None]
        return np.concatenate([out_rgb, alpha], axis=2).astype(np.uint8)
    return out_rgb.astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--band", type=int, default=72)
    ap.add_argument("--check", action="store_true", help="report only, change nothing")
    ap.add_argument("--max-wrap", type=float, default=3.0, help="fail --check above this join-step ratio")
    a = ap.parse_args()

    bad = 0
    for p in a.paths:
        im = Image.open(p)
        mode = im.mode
        arr = np.asarray(im.convert("RGBA" if mode == "RGBA" else "RGB"))
        before = wrap_diff(arr)
        if a.check:
            ok = before <= a.max_wrap
            print(f"[{'OK ' if ok else 'FAIL'}] {os.path.basename(p):34s} join_ratio={before:5.1f} (limit {a.max_wrap})")
            if not ok:
                bad += 1
            continue
        out = make_seamless(arr, a.band)
        after = wrap_diff(out)
        img = Image.fromarray(out, mode="RGBA" if mode == "RGBA" else "RGB")
        if p.lower().endswith((".jpg", ".jpeg")):
            img.convert("RGB").save(p, quality=93, subsampling=0)
        else:
            img.save(p)
        print(f"{os.path.basename(p):34s} join_ratio {before:5.1f} -> {after:5.1f}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
