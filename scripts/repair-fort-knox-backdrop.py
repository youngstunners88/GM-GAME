#!/usr/bin/env python3
"""Repair the baked-in horizontal-smear band on the right edge of the Fort Knox
vault backdrop.

WHY THIS EXISTS
---------------
Founder, repeatedly: the Fort Knox staking realm shows a "dividing line / paper
seam" that the Diamond Vault does NOT — even though both realms share
`vault_realm.gd` and its `_setup_backdrop()` byte-for-byte. Live browser capture
(scripts/capture-vaults.mjs, ?vault=fort) proved it is NOT the parallax mirror
join (the plate tiles at 0.0 edge diff) and NOT a runtime overlay: it is a band
of horizontal AI-generation SMEAR baked into the right edge of
`fort_knox_backdrop.png` itself (roughly texture x 896..1024). It scrolls with
the parallax because it is part of the texture. The Diamond Vault plate has no
such smear, which is exactly why only Fort Knox "still shows the seam."

THE REPAIR (detail graft, not a crop / not a rescale)
-----------------------------------------------------
The smear is a HIGH-FREQUENCY defect (horizontal streaks) sitting on an
otherwise-fine low-frequency brightness field (the vault's warm glow + the dark
edge vignette that makes the plate tile). So we:
  1. Keep the ORIGINAL low-frequency field of the band (brightness, colour,
     the dark edge vignette) untouched -> tiling stays seamless, layout intact.
  2. Replace only the band's high-frequency DETAIL with crisp vault detail
     reflected from the plate interior (mirror pivot at the band's left edge, so
     the join is continuous with zero seam).
  3. Feather the band edges so there is no hard boundary.

This never rescales or crops the art (the mistakes that clipped the L3 BTC coin
last time) and never brightens the last ~16px, so x=0 and x=1023 stay the same
dark vignette and the plate still tiles at ~0 edge diff.

Usage:
  python3 scripts/repair-fort-knox-backdrop.py            # repair in place
  python3 scripts/repair-fort-knox-backdrop.py --check    # gate: verify repaired
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

ART = "src/assets/art/vaults/fort_knox_backdrop.png"

# Smear band (measured from the texture + live capture). The last EDGE_KEEP
# columns are the dark tiling vignette and are left fully original.
BAND_X0 = 896
BAND_X1 = 1024
EDGE_KEEP = 16          # rightmost px kept 100% original (dark tiling gutter)
FEATHER = 20            # px of cross-fade at each band boundary
LOWPASS_SIGMA = 20.0    # separates brightness field from streak detail


def _blur(a: np.ndarray, sigma: float) -> np.ndarray:
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius=sigma))).astype(float)


def repair(arr: np.ndarray) -> np.ndarray:
    h, w, _ = arr.shape
    out = arr.copy()
    pivot = BAND_X0
    # Reflected source: dest column d -> source (2*pivot - d), crisp interior.
    src = np.empty_like(arr)
    for d in range(w):
        s = 2 * pivot - d
        s = max(0, min(w - 1, s))
        src[:, d, :] = arr[:, s, :]

    o_lf = _blur(arr, LOWPASS_SIGMA)
    r_lf = _blur(src, LOWPASS_SIGMA)
    # High-frequency detail from the reflected (crisp) region, brightness field
    # from the original band.
    grafted = o_lf + (src - r_lf)

    # Per-column blend weight: 0 outside the band, ramp up over the first
    # FEATHER px, hold at 1, then ramp back to 0 over the EDGE_KEEP+FEATHER tail
    # so the dark vignette edge stays 100% original.
    wcol = np.zeros(w)
    for x in range(w):
        if x < BAND_X0 or x >= BAND_X1:
            continue
        left = min(1.0, (x - BAND_X0) / float(FEATHER))
        tail_start = BAND_X1 - EDGE_KEEP - FEATHER
        right = 1.0
        if x >= BAND_X1 - EDGE_KEEP:
            right = 0.0
        elif x >= tail_start:
            right = 1.0 - (x - tail_start) / float(FEATHER)
        wcol[x] = max(0.0, min(1.0, min(left, right)))

    W = wcol[None, :, None]
    out = arr * (1.0 - W) + grafted * W
    return np.clip(out, 0, 255)


def _streakiness(arr: np.ndarray, x0: int, x1: int) -> float:
    """Mean vertical gradient in a column band. A horizontal smear is smooth
    vertically -> LOW value. Higher = more real (vertical) detail = less smear."""
    vg = np.abs(arr[1:, x0:x1, :] - arr[:-1, x0:x1, :]).mean()
    return float(vg)


def main() -> int:
    check = "--check" in sys.argv
    im = Image.open(ART).convert("RGB")
    arr = np.asarray(im).astype(float)

    band_vg = _streakiness(arr, BAND_X0, BAND_X1 - EDGE_KEEP)
    mid_vg = _streakiness(arr, 300, 700)
    edge_diff = float(np.abs(arr[:, 0, :] - arr[:, 1023, :]).mean())

    if check:
        # Gate thresholds: the band must NOT be a smooth smear relative to the
        # crisp mid-plate, and the plate must still tile.
        ratio = band_vg / max(1e-6, mid_vg)
        ok_detail = ratio >= 0.62
        ok_tile = edge_diff <= 2.0
        print("[fort-knox-backdrop] band_vgrad=%.2f mid_vgrad=%.2f ratio=%.2f "
              "edge_diff=%.2f" % (band_vg, mid_vg, ratio, edge_diff))
        if ok_detail and ok_tile:
            print("[fort-knox-backdrop] PASS — no smear band, tiles clean")
            return 0
        if not ok_detail:
            print("[fort-knox-backdrop] FAIL — right-edge smear band present "
                  "(detail ratio %.2f < 0.62); run repair-fort-knox-backdrop.py" % ratio)
        if not ok_tile:
            print("[fort-knox-backdrop] FAIL — plate no longer tiles "
                  "(edge_diff %.2f > 2.0)" % edge_diff)
        return 1

    print("[fort-knox-backdrop] before: band_vgrad=%.2f mid_vgrad=%.2f "
          "ratio=%.2f edge_diff=%.2f" % (band_vg, mid_vg, band_vg / max(1e-6, mid_vg), edge_diff))
    fixed = repair(arr)
    Image.fromarray(fixed.astype(np.uint8)).save(ART)
    nvg = _streakiness(fixed, BAND_X0, BAND_X1 - EDGE_KEEP)
    ndiff = float(np.abs(fixed[:, 0, :] - fixed[:, 1023, :]).mean())
    print("[fort-knox-backdrop] after:  band_vgrad=%.2f ratio=%.2f edge_diff=%.2f -> saved %s"
          % (nvg, nvg / max(1e-6, mid_vg), ndiff, ART))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
