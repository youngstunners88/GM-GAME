#!/usr/bin/env python3
"""SEAM + SMUDGE GATE — deterministic per-frame metrics for the defect class the
founder has circled across many passes: a hard vertical/horizontal DIVIDING LINE
(tile-wrap join, or raw void showing through a gap) and an off-palette GREEN
SMUDGE in the backdrop.

Why this exists
---------------
Every previous "fixed" claim leaned on a human (or a model) eyeballing a
screenshot. That failed repeatedly. This script turns each founder circle into a
NUMBER, so a regression cannot ship silently again.

It is deliberately biased toward catching things: a full-height column
discontinuity is a seam even if it looks subtle, because "subtle Diamond Vault
join" is exactly one of the circles.

Metrics (per frame, computed on the BACKDROP BAND only)
-------------------------------------------------------
  void_frac(x)   fraction of rows in the band that are near-black at column x.
                 A void gap (backdrop not covering the viewport) -> ~1.0.
  seam_frac(x)   fraction of rows with a hard horizontal step at column x.
                 A tile-wrap join spans the FULL height -> high.
                 A tree/rock edge is local -> low. This is what separates a
                 real seam from ordinary art detail.
  row_seam(y)    same idea rotated: catches a horizontal "paper join".
  green_blob     px count of off-palette green in the band, EXCLUDING thin
                 horizontal platform trim (which is intentionally teal/green).
  mean_luma      band brightness, so "darken the plate to hide the smear"
                 is itself detectable as a regression rather than a fix.

Exit code 1 on any FAIL, so CI/agents can gate on it.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

# --- thresholds (tuned against the founder's own circled frames) -------------
STEP_T = 26.0        # per-channel-mean step that counts as a hard edge
SEAM_FRAC_FAIL = 0.55   # full-height-ish discontinuity => dividing line
VOID_FRAC_FAIL = 0.50   # half the band near-black in one column => void gap
NEAR_BLACK = 26
GREEN_BLOB_FAIL = 900   # px of off-palette green in the backdrop band
WIDE_STEP_FAIL = 9.0    # mean-colour difference across a 30px window either side
BAND_TOP = 0.10         # skip the HUD strip
BAND_BOT = 0.60         # skip ground band / promo banner / control hints


def band_of(im):
    h = im.shape[0]
    return im[int(h * BAND_TOP):int(h * BAND_BOT)]


def _wide_step(band, axis, half=30):
    """Mean-colour difference between a wide window either side of each line.

    THIS is what separates a real join from ordinary art. A tile-wrap seam
    splices two unrelated parts of the plate together, so the AVERAGE colour of
    the 30px either side genuinely differs. An intentional thin bright line —
    a light shaft, a platform trim, a waterfall — is symmetric: bright pixels
    sit ON the line, but the wide averages on both sides still match, so its
    wide_step stays near zero. Without this test the gate fires on decoration
    (verified: it flagged L2's light shafts and the platform row), and a gate
    that cries wolf gets ignored exactly like a gate that sleeps.
    """
    b = band if axis == 1 else np.swapaxes(band, 0, 1)
    n = b.shape[1]
    out = np.zeros(n - 1)
    # cumulative sums make the sliding window means cheap
    cs = np.cumsum(np.concatenate([np.zeros((b.shape[0], 1, 3)), b], axis=1), axis=1)
    for x in range(n - 1):
        l0, l1 = max(0, x - half + 1), x + 1
        r0, r1 = x + 1, min(n, x + 1 + half)
        if l1 - l0 < 4 or r1 - r0 < 4:
            continue
        left = (cs[:, l1] - cs[:, l0]) / (l1 - l0)
        right = (cs[:, r1] - cs[:, r0]) / (r1 - r0)
        out[x] = float(np.abs(left.mean(axis=0) - right.mean(axis=0)).mean())
    return out


def column_metrics(band):
    """Return per-column void_frac, seam_frac and wide_step over the band."""
    lum = band.mean(axis=2)
    near_black = (band[..., 0] < NEAR_BLACK) & (band[..., 1] < NEAR_BLACK) & (band[..., 2] < NEAR_BLACK)
    void_frac = near_black.mean(axis=0)

    step = np.abs(np.diff(lum, axis=1))
    seam_frac = (step > STEP_T).mean(axis=0)  # len W-1
    return void_frac, seam_frac, _wide_step(band, axis=1)


def row_metrics(band):
    lum = band.mean(axis=2)
    step = np.abs(np.diff(lum, axis=0))
    return (step > STEP_T).mean(axis=1), _wide_step(band, axis=0)  # len H-1


def green_blob_px(band):
    """Off-palette green: G clearly dominant over BOTH R and B.

    Platform trim in this game is a bright teal line (high G AND high B), and
    the hero/pickups are small. A smudge is green-dominant and diffuse, so
    requiring G to beat B as well as R rejects the intentional teal trim.
    """
    R, G, B = band[..., 0].astype(int), band[..., 1].astype(int), band[..., 2].astype(int)
    green = (G - R > 26) & (G - B > 26) & (G > 60)
    # drop rows that are almost entirely green -> that's a trim line, not a blob
    rowfrac = green.mean(axis=1)
    green[rowfrac > 0.35, :] = False
    return int(green.sum())


def analyse(path):
    im = np.asarray(Image.open(path).convert("RGB")).astype(float)
    band = band_of(im)
    void_frac, seam_frac, cwide = column_metrics(band)
    rseam, rwide = row_metrics(band)
    gb = green_blob_px(band)

    # A defect needs BOTH a hard line AND a real discontinuity across it.
    col_score = np.minimum(seam_frac, 1.0) * (cwide >= WIDE_STEP_FAIL)
    row_score = np.minimum(rseam, 1.0) * (rwide >= WIDE_STEP_FAIL)
    void_score = void_frac[:len(cwide)] * (cwide >= WIDE_STEP_FAIL)

    smax = float(col_score.max()); sx = int(col_score.argmax())
    rmax = float(row_score.max()); ry = int(row_score.argmax())
    vmax = float(void_score.max()); vx = int(void_score.argmax())

    fails = []
    if vmax >= VOID_FRAC_FAIL:
        fails.append(f"VOID_GAP col x={vx} void_frac={vmax:.2f} wide_step={cwide[vx]:.1f}")
    if smax >= SEAM_FRAC_FAIL:
        fails.append(f"VERTICAL_SEAM col x={sx} seam_frac={smax:.2f} wide_step={cwide[sx]:.1f}")
    if rmax >= SEAM_FRAC_FAIL:
        fails.append(f"HORIZONTAL_JOIN row y={ry} seam_frac={rmax:.2f} wide_step={rwide[ry]:.1f}")
    if gb >= GREEN_BLOB_FAIL:
        fails.append(f"GREEN_SMUDGE px={gb}")

    return {
        "file": os.path.basename(path),
        "void_frac_max": round(vmax, 3), "void_x": vx,
        "seam_frac_max": round(smax, 3), "seam_x": sx,
        "col_wide_step": round(float(cwide.max()), 1),
        "row_seam_max": round(rmax, 3), "row_y": ry,
        "green_blob_px": gb,
        "mean_luma": round(float(band.mean()), 1),
        "fails": fails,
        "verdict": "FAIL" if fails else "PASS",
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--quiet-pass", action="store_true", help="only print FAILs")
    a = ap.parse_args()

    results, bad = [], 0
    for p in a.paths:
        if os.path.isdir(p):
            files = sorted(os.path.join(p, f) for f in os.listdir(p) if f.lower().endswith((".png", ".jpg", ".webp")))
        else:
            files = [p]
        for f in files:
            r = analyse(f)
            results.append(r)
            if r["verdict"] == "FAIL":
                bad += 1
            if a.json:
                continue
            if a.quiet_pass and r["verdict"] == "PASS":
                continue
            print(f"[{r['verdict']}] {r['file']:34s} void={r['void_frac_max']:.2f}@{r['void_x']:<5d} "
                  f"seam={r['seam_frac_max']:.2f}@{r['seam_x']:<5d} rowseam={r['row_seam_max']:.2f}@{r['row_y']:<4d} "
                  f"green={r['green_blob_px']:<6d} luma={r['mean_luma']}")
            for x in r["fails"]:
                print(f"         !! {x}")

    if a.json:
        print(json.dumps(results, indent=2))
    else:
        print(f"\n{len(results)} frame(s): {bad} FAIL, {len(results)-bad} PASS")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
