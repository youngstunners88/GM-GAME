#!/usr/bin/env python3
"""Make a horizontally-scrolling level background tile SEAMLESSLY at its wrap
boundary, without distorting the artwork or manufacturing flat bands.

WHY
---
The level backdrops render on a ParallaxLayer with `motion_mirroring.x =
width*scale` (level_base._setup_background). That REPEATS the plate as the
camera pans, so the plate's right edge butts against its own left edge. When
those edges don't match, that butt-join is a hard vertical "dividing line" that
sweeps across the screen as you move. Founder (2026-09-17) circled exactly this
as the Level 2 "paper-paste dividing line" and the Level 1 "sliver by the tree"
(the join is most visible where it crosses the dark tree trunk / dark cloud
pillar). Measured wrap mismatch (mean |left_edge - right_edge|):
  bg_l1_forest.jpg  = 17.7   (worst)
  bg_l2_crystal.jpg = 10.9
  bg_l3_goldrush.jpg=  0.1    (already tiles -> not processed here)

THE HEAL (low-frequency edge convergence — NOT a cross-fade)
-----------------------------------------------------------
A prior attempt cross-faded a wide band and manufactured flat, detail-less
bands. We avoid that: we add only a SMOOTH, LOW-FREQUENCY per-row correction
that decays to zero away from the seam, nudging the two edges onto their shared
mean so the wrap is continuous. All high-frequency detail is preserved exactly
(we only add a gentle brightness/colour ramp in the outer BAND px of each side),
so there is no flat band and the interior art is untouched. Result: edge
mismatch drops below the visible threshold while the painting looks unchanged.

Usage:
  python3 scripts/make-bg-seamless.py            # heal L1 + L2 in place
  python3 scripts/make-bg-seamless.py --check     # gate: assert both tile
"""
import sys
import numpy as np
from PIL import Image

TARGETS = [
    "src/assets/backgrounds/bg_l1_forest.jpg",
    "src/assets/backgrounds/bg_l2_crystal.jpg",
]
BAND = 110          # px on each edge that receive the smooth correction
MAX_EDGE_DIFF = 3.0  # gate threshold (below this the wrap join is invisible)


def heal(arr: np.ndarray, band: int = BAND) -> np.ndarray:
    h, w, _ = arr.shape
    out = arr.copy()
    left = arr[:, 0, :].astype(float)      # (h,3)
    right = arr[:, w - 1, :].astype(float)
    target = 0.5 * (left + right)          # where both edges should meet
    corr_left = target - left              # push left edge onto target
    corr_right = target - right
    # Smooth cosine falloff: full correction at the very edge, 0 by `band` in.
    for k in range(band):
        fall = 0.5 * (1.0 + np.cos(np.pi * k / band))   # 1 -> 0
        out[:, k, :] = np.clip(arr[:, k, :] + corr_left * fall, 0, 255)
        out[:, w - 1 - k, :] = np.clip(arr[:, w - 1 - k, :] + corr_right * fall, 0, 255)
    return out


def edge_diff(arr: np.ndarray) -> float:
    return float(np.abs(arr[:, 0, :].astype(float) - arr[:, -1, :].astype(float)).mean())


def main() -> int:
    check = "--check" in sys.argv
    rc = 0
    for path in TARGETS:
        im = Image.open(path).convert("RGB")
        arr = np.asarray(im).astype(float)
        d0 = edge_diff(arr)
        if check:
            ok = d0 <= MAX_EDGE_DIFF
            print("[bg-seamless] %s edge_diff=%.2f %s"
                  % (path, d0, "PASS" if ok else "FAIL (wrap join visible)"))
            if not ok:
                rc = 1
            continue
        fixed = heal(arr)
        d1 = edge_diff(fixed)
        # JPEG re-encode nudges edges slightly; save high quality to keep d1 low.
        Image.fromarray(fixed.astype(np.uint8)).save(path, quality=95, subsampling=0)
        reloaded = np.asarray(Image.open(path).convert("RGB")).astype(float)
        print("[bg-seamless] %s edge_diff %.2f -> %.2f (saved, reloaded=%.2f)"
              % (path, d0, d1, edge_diff(reloaded)))
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
