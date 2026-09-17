#!/usr/bin/env python3
"""Gate: the Level 3 gold-rush backdrop must be the WIDENED plate that never
wraps in-level, so the founder's "central peak smudge" (the original 1280px
plate's dark low-detail canyon-wall edges doubling at the parallax tile-wrap)
can never come back.

Background (founder 2026-09-17): bg_l3_goldrush.jpg is 1280x720 and tiles at
edge-diff ~0.1, so no hard seam — but its LEFT and RIGHT edge columns are the
dark, flat, low-detail near-canyon walls. The level scrolls far enough that the
parallax layer wraps, butting those two dark walls together into an oversized
muddy dark mass behind the ENTER VAULT door. The fix widens the plate to 2560px
(original + horizontal mirror) so the wrap boundary (x=2560) is never reached
in-level (max parallax offset ~1092 << 2560-1280), the intended single canyon
shows everywhere, and the baked wBTC coin is untouched (it stays in the original
half).

This gate asserts:
  1. bg_l3_goldrush_wide.jpg exists and is >= 2372px wide (never wraps in-level).
  2. It still tiles (edge_diff small) — belt-and-braces.
  3. level_03_data.tres actually points at the wide plate (not the 1280 one).
"""
import sys
import numpy as np
from PIL import Image

WIDE = "src/assets/backgrounds/bg_l3_goldrush_wide.jpg"
TRES = "src/resources/level_03_data.tres"
MIN_WIDTH = 2372   # max parallax offset (~1092) + viewport (1280)
MAX_EDGE_DIFF = 3.0


def main() -> int:
    # --check is the only mode; accepted for parity with the other gates.
    import os
    ok = True
    if not os.path.exists(WIDE):
        print("[l3-wide] FAIL — %s missing" % WIDE)
        return 1
    im = Image.open(WIDE).convert("RGB")
    w, h = im.size
    arr = np.asarray(im).astype(float)
    edge = float(np.abs(arr[:, 0, :] - arr[:, -1, :]).mean())
    if w < MIN_WIDTH:
        print("[l3-wide] FAIL — width %d < %d (would wrap in-level)" % (w, MIN_WIDTH))
        ok = False
    if edge > MAX_EDGE_DIFF:
        print("[l3-wide] FAIL — edge_diff %.2f > %.1f" % (edge, MAX_EDGE_DIFF))
        ok = False
    try:
        tres = open(TRES, encoding="utf-8").read()
    except OSError:
        print("[l3-wide] FAIL — cannot read %s" % TRES)
        return 1
    if "bg_l3_goldrush_wide.jpg" not in tres:
        print("[l3-wide] FAIL — level_03_data.tres does not use the wide plate")
        ok = False
    if ok:
        print("[l3-wide] PASS — wide plate %dx%d, edge_diff=%.2f, wired in level data"
              % (w, h, edge))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
