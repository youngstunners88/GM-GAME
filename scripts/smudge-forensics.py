#!/usr/bin/env python3
"""Locate a reported visual "smudge" and say WHERE IT LIVES.

Written 2026-09-22 after a month of failed smudge hunts. Every earlier attempt
guessed at a cause and then changed art to match the guess; twice that wrecked a
plate that was never the problem. This script answers the only question that
matters first — is the defect in the ARTWORK, drawn ON TOP of it at runtime, or
absent from our render entirely (i.e. it lives on the reporter's machine) — and
it answers it from pixels, with no hypothesis required.

Three findings it encodes, each of which cost real time to learn:

  * Test the RATIO, not the colour name. The founder called these "green".
    Measured, they multiply the sky by (R x0.86, G x0.89, B x0.83): a near
    NEUTRAL darkening that only READS green because it sits on saturated
    orange. Every detector written to match `G > R and G > B` reported the game
    clean for a month. --blobs prints per-channel ratios so the description
    never has to be trusted again.

  * High-pass before judging. A painted sky is a smooth gradient; subtracting a
    heavy blur flattens it to noise and leaves any real blob standing alone.
    This needs no reference image and no registration, so it works on a
    screenshot that arrives with nothing to compare against.

  * Compare against EVERY historical version of the plate. "It is not in the
    art" is only true if it is not in the art the reporter is actually running,
    which is not necessarily the art in your working tree.

Usage:
  smudge-forensics.py shot.png --plates src/assets/backgrounds/*.jpg
  smudge-forensics.py shot.png --against artifacts/our-capture.png --blobs
"""
from __future__ import annotations
import argparse, sys
import numpy as np

try:
    import cv2
    from PIL import Image
except ImportError:
    sys.exit("needs opencv-python and pillow")

CANVAS = (1280, 720)
# Sky band: below the HUD, above the ground. Tuned to this game's layouts.
BAND = (120, 460)
# A clean painted gradient sits near 4-5; the founder's 2026-09-21 capture of
# the same build and scene measured 7.18 with a 1st-percentile of -19.8 against
# our -8.3. Flag well above clean rather than at it.
STD_FLAG = 6.5
P1_FLAG = -14.0


def load(path: str) -> np.ndarray:
    im = Image.open(path).convert("RGB").resize(CANVAS, Image.LANCZOS)
    return np.asarray(im).astype(np.float32)


def highpass(a: np.ndarray, sigma: float = 45.0) -> np.ndarray:
    lum = a.mean(axis=2)
    return lum - cv2.GaussianBlur(lum, (0, 0), sigma)


def sky_stats(h: np.ndarray) -> tuple[float, float]:
    band = h[BAND[0]:BAND[1]]
    return float(band.std()), float(np.percentile(band, 1))


def best_align(shot: np.ndarray, plate: np.ndarray) -> tuple[int, float]:
    """Backgrounds scroll and wrap, so a plate matches at some x offset."""
    lo, hi = BAND
    best = (0, 1e9)
    for dx in range(0, CANVAS[0]):
        d = float(np.abs(shot[lo:hi] - np.roll(plate, -dx, axis=1)[lo:hi]).mean())
        if d < best[1]:
            best = (dx, d)
    return best


def find_blobs(shot: np.ndarray, ref: np.ndarray, drop: float = 10.0) -> list[dict]:
    """Regions where the shot is darker than the reference."""
    d = -(shot - ref)[:, :, 0]
    m = (d > drop).astype(np.uint8)
    m[:BAND[0]] = 0
    m[BAND[1]:] = 0
    # Annotation ink (the reporter's red circle) is red with BOTH other
    # channels low. Do not widen this: an earlier version tested only
    # `G < 110`, which matched the smudges themselves and erased the evidence.
    ink = ((shot[:, :, 1] < 70) & (shot[:, :, 2] < 70) & (shot[:, :, 0] > 110)).astype(np.uint8)
    m[cv2.dilate(ink, np.ones((9, 9), np.uint8)) > 0] = 0
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, lbl, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    out = []
    for i in range(1, n):
        if stats[i, 4] < 60:
            continue
        sel = lbl == i
        s, r = shot[sel].mean(axis=0), ref[sel].mean(axis=0)
        out.append({
            "px": int(stats[i, 4]),
            "box": (int(stats[i, 0]), int(stats[i, 1]), int(stats[i, 2]), int(stats[i, 3])),
            "ratio": tuple(round(float(v), 3) for v in (s / np.maximum(r, 1e-6))),
        })
    return sorted(out, key=lambda b: -b["px"])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("shot")
    ap.add_argument("--plates", nargs="*", default=[], help="candidate background art")
    ap.add_argument("--against", help="our own capture of the same scene")
    ap.add_argument("--blobs", action="store_true")
    ap.add_argument("--dump", help="write the high-pass view here")
    a = ap.parse_args()

    shot = load(a.shot)
    hs = highpass(shot)
    std, p1 = sky_stats(hs)
    dirty = std > STD_FLAG or p1 < P1_FLAG
    print(f"shot            sky highpass std={std:6.2f}  p1={p1:7.1f}   "
          f"{'SMUDGED' if dirty else 'clean'}")
    if a.dump:
        Image.fromarray(np.clip(128 + hs * 6, 0, 255).astype(np.uint8)).save(a.dump)

    for p in a.plates:
        pl = load(p)
        pstd, pp1 = sky_stats(highpass(pl))
        dx, mad = best_align(shot, pl)
        print(f"  plate {p.split('/')[-1]:34s} own_std={pstd:5.2f} "
              f"align_dx={dx:4d} mad={mad:5.2f}"
              f"{'   <- MATCHES the running art' if mad < 6.0 else ''}")
        if mad < 6.0 and pstd < STD_FLAG and dirty:
            print("       verdict: plate is CLEAN but the shot is not -> "
                  "the defect is drawn ON TOP at runtime, not baked into the art.")

    if a.against:
        ours = load(a.against)
        ostd, op1 = sky_stats(highpass(ours))
        print(f"our capture     sky highpass std={ostd:6.2f}  p1={op1:7.1f}   "
              f"{'SMUDGED' if (ostd > STD_FLAG or op1 < P1_FLAG) else 'clean'}")
        if dirty and ostd <= STD_FLAG:
            print("  verdict: the SAME build renders clean here. The defect is not in "
                  "the build's output -> look at the reporter's GPU/driver, browser "
                  "compositing, or screen-capture path before touching any asset.")
        if a.blobs:
            for b in find_blobs(shot, ours):
                print(f"    blob px={b['px']:5d} box={b['box']} multiply={b['ratio']}")
    return 1 if dirty else 0


if __name__ == "__main__":
    sys.exit(main())
