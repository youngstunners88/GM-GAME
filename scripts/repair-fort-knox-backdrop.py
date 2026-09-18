#!/usr/bin/env python3
"""Gate for the Fort Knox vault backdrop.

Founder 2026-09-17/18 + Fable 5.1 diagnosis: the Fort Knox seam was the parallax
TILE-WRAP join. The plate was ~viewport-wide with `motion_mirroring = width`, so
the repeat butted the plate's right edge (dense machinery) against its left edge
(the bright cave-mouth sky) — a hard vertical line at every camera position. An
earlier detail-graft of the right-edge smear did not touch the wrap, so the seam
survived.

Fix (see vault_realm.gd::_setup_backdrop): the gold plate is WIDENED to cover the
whole camera travel and tiling is turned OFF for it (`motion_mirroring = ZERO`),
so there is no repeat and no join. The extension is machinery-only, faded into
shadow so no mirror reads. Diamond Vault keeps its working mirrored parallax.

This gate verifies the shipped `fort_knox_backdrop.png`:
  1. is wide enough that, un-tiled, it covers the camera travel
     (needed source px = ceil((1280 + 0.4*(BOUNDS-1280)) / 1.25), BOUNDS=2600 -> 1447);
  2. has no smooth horizontal SMEAR band at its right edge (the old defect) —
     measured as vertical-gradient detail, not tone.
"""
import sys
import numpy as np
from PIL import Image

ART = "src/assets/art/vaults/fort_knox_backdrop.png"
MIN_WIDTH = 1447


def main() -> int:
    check = "--check" in sys.argv
    im = Image.open(ART).convert("RGB")
    w, h = im.size
    arr = np.asarray(im).astype(float)

    # smear metric: mean vertical gradient in the old smear band vs mid-plate.
    def vg(x0, x1):
        return float(np.abs(arr[1:, x0:x1, :] - arr[:-1, x0:x1, :]).mean())
    # old smear sat at the ORIGINAL right edge (x 900-1020); it is now interior.
    band_vg = vg(900, 1020)
    mid_vg = vg(300, 700)
    ratio = band_vg / max(1e-6, mid_vg)

    if check:
        ok_w = w >= MIN_WIDTH
        ok_smear = ratio >= 0.55
        print("[fort-knox] width=%d (need>=%d) old-smear-band detail ratio=%.2f"
              % (w, MIN_WIDTH, ratio))
        if ok_w and ok_smear:
            print("[fort-knox] PASS — wide enough to cover travel un-tiled, no smear band")
            return 0
        if not ok_w:
            print("[fort-knox] FAIL — plate %d px < %d; un-tiled it leaves a gap at far-right"
                  % (w, MIN_WIDTH))
        if not ok_smear:
            print("[fort-knox] FAIL — smooth smear band present (ratio %.2f < 0.55)" % ratio)
        return 1

    print("[fort-knox] width=%d smear-ratio=%.2f (this script is now a --check gate; "
          "the plate is produced in-session per Fable's extend+no-tile plan)" % (w, ratio))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
