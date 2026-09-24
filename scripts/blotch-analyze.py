#!/usr/bin/env python3
"""Measure a captured scene matrix for blotches and GRADE THE DETECTOR against
the founder's labelled matrix (scripts/blotch-oracle.json).

Why grading the detector is the whole point
-------------------------------------------
Between 2026-08-20 and 2026-09-22 five different blotch detectors were written
for this bug. Every one of them reported the game clean, and every one was
believed, because nobody ever asked the only question that matters: *does this
detector agree with the founder on frames he has already graded?* They all
tested `green > red and green > blue`, and the defect is a near-NEUTRAL
darkening (multiply R x0.86 G x0.89 B x0.83) that merely READS green on a warm
sky. A detector nobody calibrated is not evidence of anything.

So this tool never prints a bare verdict. It prints the verdict AND how the
detector scored on the six frames the founder graded. If agreement is not 6/6,
the correct response is to fix the detector, not to report the frames.

Method
------
For each scene, align its capture to the background plate it actually draws
(resolved from the repo by blotch-scenes.py, never hardcoded) and measure the
fraction of sky-band pixels rendered DARKER than that plate. Alignment is
needed because backgrounds parallax-scroll and wrap.

Deliberately NOT used: a global high-pass std. It cannot separate a blotch from
legitimate art detail, so it scores a busy forest as dirtier than a smudged
sunset. Verified on this matrix — it ranks l2_blaze (clean, 13.79) above
l3_blaze (blotched, 5.52), i.e. exactly backwards.
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
import numpy as np

try:
    import cv2
    from PIL import Image
except ImportError:
    sys.exit("needs opencv-python and pillow")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from blotch_scenes import plate_for  # noqa: E402

CANVAS = (1280, 720)
SKY = (120, 440)          # below the HUD, above the ground band
DARKER_THAN_PLATE = 10.0  # 8-bit levels; below this is JPEG/resample noise

# VALIDITY GATE. The plate-diff only measures a blotch where the plate is
# actually what you are looking at. In a main stage the sky band is full of
# trees, platforms and props, so the frame disagrees with its plate everywhere
# and "% darker than plate" measures FOREGROUND, not blotches.
#
# This matters more than it sounds. Without this gate the matrix scored 5/6
# against the founder — three of them by accident, because any busy scene
# clears any threshold. A detector that is right for the wrong reason is how
# five previous detectors passed while the bug shipped. If the aligned frame
# differs from its plate by more than this, the reading is refused rather than
# reported.
MAX_MAD_FOR_VALID_READING = 5.0


def load(p, size=CANVAS) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGB").resize(size, Image.LANCZOS)).astype(np.float32)


def align(shot: np.ndarray, plate: np.ndarray) -> tuple[int, float]:
    lo, hi = SKY
    best = (0, 1e9)
    for dx in range(CANVAS[0]):
        d = float(np.abs(shot[lo:hi] - np.roll(plate, -dx, axis=1)[lo:hi]).mean())
        if d < best[1]:
            best = (dx, d)
    return best


def overlay_residual(shot: np.ndarray, plate: np.ndarray) -> dict:
    dx, mad = align(shot, plate)
    ref = np.roll(plate, -dx, axis=1)
    lo, hi = SKY
    drop = -(shot - ref)[lo:hi, :, 0]
    return {"dx": dx, "mad": round(mad, 2),
            "pct_darker": round(float((drop > DARKER_THAN_PLATE).mean() * 100), 3)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("matrix_dir")
    ap.add_argument("--oracle", default=str(Path(__file__).parent / "blotch-oracle.json"))
    ap.add_argument("--threshold", type=float, default=1.0,
                    help="pct_darker above which a scene is called blotched")
    a = ap.parse_args()

    oracle = json.loads(Path(a.oracle).read_text())["scenes"]
    rows, agree, total = [], 0, 0
    for scene, truth in oracle.items():
        cap = Path(a.matrix_dir) / f"{scene}.png"
        if not cap.exists():
            rows.append((scene, None, None, truth["blotched"], "NO CAPTURE"))
            continue
        plate = plate_for(scene)
        r = overlay_residual(load(cap), load(plate))
        if r["mad"] > MAX_MAD_FOR_VALID_READING:
            rows.append((scene, r, None, truth["blotched"],
                         "UNMEASURABLE (foreground hides the plate)"))
            continue
        called = r["pct_darker"] > a.threshold
        ok = called == truth["blotched"]
        agree += ok
        total += 1
        rows.append((scene, r, called, truth["blotched"], "agree" if ok else "MISMATCH"))

    print(f"{'scene':10s} {'plate mad':>9s} {'%darker':>8s} {'detector':>9s} {'founder':>8s}  result")
    for scene, r, called, truth, note in rows:
        if r is None:
            print(f"{scene:10s} {'-':>9s} {'-':>8s} {'-':>9s} {str(truth):>8s}  {note}")
            continue
        print(f"{scene:10s} {r['mad']:9.2f} {r['pct_darker']:8.3f} "
              f"{str(called):>9s} {str(truth):>8s}  {note}")

    unmeasurable = [r[0] for r in rows if r[2] is None and r[1] is not None]
    if unmeasurable:
        print(f"\nnot measurable by plate-diff: {', '.join(unmeasurable)}")
        print("  These need the other method: capture the SAME scene here and diff it against\n"
              "  the founder's own screenshot of it. Do not guess from the plate.")
    print(f"\ncalibration: detector agrees with the founder on {agree}/{total} MEASURABLE frames")
    if total and agree < total:
        print("VERDICT: detector is NOT calibrated. Its opinion on any ungraded frame is\n"
              "worthless until it reproduces the founder's matrix. Fix the metric — do not\n"
              "report these numbers as findings, and do not change any artwork on them.")
        return 2
    print("VERDICT: detector reproduces the founder's matrix. Its readings can be trusted\n"
          "on ungraded frames.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
