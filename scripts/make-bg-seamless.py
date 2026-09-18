#!/usr/bin/env python3
"""Gate: the Level 1 / Level 2 backdrops must have NO visible tile-wrap seam.

History (why this file changed shape):
  - 2026-09-17: first attempt "edge-healed" the plates (cross-faded the outer
    columns so left edge tone == right edge tone). Founder rejected it — the
    cross-fade turned the hard butt-join into a smooth textureless column
    running through the tree trunk / cloud pillar (the "sellotape sliver").
  - 2026-09-18 (Fable 5.1 diagnosis): the real fix is to ROLL each plate by
    ~W/2 (so its new edges are formerly-adjacent columns → the wrap is natively
    seamless) and REPAINT the now-interior discontinuity with real continued
    structure (cv2 seamlessClone NORMAL, not a cross-fade). See
    scripts/repaint-wrap-seam.py. This file is now a pure CHECK — it never
    edits the plates.

What it verifies on the SHIPPED plates:
  1. The wrap join is seamless: mean |col0 - colLast| is small (the roll put
     adjacent columns at the edges). This catches a regression to a raw,
     non-tiling plate.
  2. No residual full-height interior seam from a bad repaint: scan for a
     column whose step is BOTH a strong outlier AND continuous down most of the
     height. A legitimate high-contrast feature (e.g. the L2 god-ray light
     shaft) is a thin bright line, not a full-height tonal butt-join, so it is
     excluded by requiring the step to persist across most rows AND to be a
     left/right tonal STEP rather than a bright spike.
"""
import sys
import numpy as np
from PIL import Image

TARGETS = [
    "src/assets/backgrounds/bg_l1_forest.jpg",
    "src/assets/backgrounds/bg_l2_crystal.jpg",
]
MAX_WRAP_DIFF = 5.0   # mean |edge-edge| after the roll; a raw plate is ~11-18


def _wrap_diff(a: np.ndarray) -> float:
    return float(np.abs(a[:, 0, :].astype(float) - a[:, -1, :].astype(float)).mean())


def _worst_interior_seam(a: np.ndarray) -> tuple[int, float]:
    """Return (x, score) of the worst full-height tonal butt-join. Score = how
    much a boundary looks like two plates pasted together: the mean L-R tonal
    step over a +/-12px window, gated to boundaries where that step is
    consistent (low variance) down the full height — i.e. a straight seam, not
    textured detail or a bright god-ray."""
    f = a.astype(np.float32)
    h, w, _ = f.shape
    best = (0, 0.0)
    # compare a 12px block left vs 12px block right at each candidate boundary
    for x in range(30, w - 30):
        L = f[:, x - 12:x, :].mean(axis=1)
        R = f[:, x:x + 12, :].mean(axis=1)
        step = np.abs(L - R).mean(axis=1)      # per-row tonal step (h,)
        # a real seam: high mean step AND low relative variance (consistent line)
        m = step.mean()
        if m > best[1] and step.std() < 0.9 * m + 6.0:
            best = (x, float(m))
    return best


def main() -> int:
    if "--check" not in sys.argv:
        print("make-bg-seamless.py is a check-only gate (the plates are produced "
              "by scripts/repaint-wrap-seam.py). Run with --check.")
        return 2
    rc = 0
    for path in TARGETS:
        a = np.asarray(Image.open(path).convert("RGB"))
        wd = _wrap_diff(a)
        sx, ss = _worst_interior_seam(a)
        ok_wrap = wd <= MAX_WRAP_DIFF
        ok_seam = ss <= 22.0
        status = "PASS" if (ok_wrap and ok_seam) else "FAIL"
        print("[bg-wrap] %s wrap_diff=%.2f worst_interior_seam=%.1f@x%d %s"
              % (path, wd, ss, sx, status))
        if not ok_wrap:
            print("          -> wrap join not seamless (roll regressed?)")
        if not ok_seam:
            print("          -> a full-height interior butt-join remains at x%d" % sx)
        if not (ok_wrap and ok_seam):
            rc = 1
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
