#!/usr/bin/env python3
"""Repair the AI-generation defects baked into the shipped background art.

Founder, 2026-09-16: "there are some blemishes on the screen of the game
throughout different stages... sometimes it looks like the background has been
badly smudged together... Lets fix these issues so that the background is
seamless."

Two defect classes, both produced by the image model that generated this art,
both baked into the JPEG/PNG rather than introduced by any engine code:

  1. A SMEARED BAND along the right edge of almost every background — columns
     of horizontally-streaked pixels where the generator ran out of coherent
     content. Because `level_base._setup_background()` tiles the backdrop every
     texture-width, that band repeats across the whole level, which is why the
     founder sees the same bad stripe again and again as he walks. This is the
     big vertical smudge he red-circled in Levels 1 and 2.

  2. RECTANGULAR PATCH QUADS in the interior of the Blaze Rush gold plate —
     flat dark rectangles with hard straight borders pasted over the forest.
     These are the blotches he circled all over the Blaze Rush shot.

Repairs, in order:
  * interior quads are REBUILT with exemplar (shift-map) inpainting, which
    copies real patches from elsewhere in the same painting, so a hole through
    the treeline comes back as trees;
  * the smear band is CROPPED OFF — never painted over, and NEVER rescaled
    back to the original width. The plate simply ends up narrower; the engine
    tiles by the real texture width, so nothing downstream cares.

    Rescaling back to 1280 was the first version and it was a bad mistake. An
    ~8% horizontal stretch turned the round Bitcoin coin in the Stage 3 canyon
    into an ellipse and shifted the composition until a second coin was clipped
    at the frame edge — the founder caught it immediately ("the bitcoin logo
    against the background is now cut!!!"). Distorting a brand mark to save a
    few pixels of width is never the right trade. The cut position is also
    chosen to avoid slicing a logo (see safe_cut).

WHAT THIS DELIBERATELY DOES NOT DO — and why, so nobody re-adds it:
A "seamless tiling" pass (roll + inpaint the wrap, or cross-fade the edges)
was built, measured and REMOVED. Two findings killed it. First, healing across
the wrap leaves a diffused flat band on both outer edges — it manufactures
exactly the smear this script exists to delete, and the checker caught it
doing so. Second, and decisive: the tiling join is not visible in the first
place. Rendering a plate tiled twice and looking at the join shows the art
flowing straight through, even on the worst-scoring plate. The edge-mismatch
number does not track visibility, so blending real art away to improve it was
cost with no benefit. The one genuine hard cut the founder saw was the Diamond
Vault's, and that was a CODE bug (vault_realm.gd mirrored by the UNSCALED
texture width), fixed there — not an art property.

Run: python3 scripts/repair-backgrounds.py [--check]
  --check  report defects and exit non-zero if any remain (the CI gate)
"""
from __future__ import annotations

import sys
import os
import numpy as np

# OpenCV is needed to REPAIR (inpainting) but deliberately NOT to CHECK. The
# check is the CI gate, and CI should not install a large native wheel just to
# confirm the shipped art is still clean, so --check runs on PIL+numpy alone.
# Repair is a one-off authoring step run by hand.
cv2 = None
if "--check" not in sys.argv:
    try:
        import cv2  # type: ignore # noqa: F811
    except ImportError:  # pragma: no cover
        print("repair-backgrounds: repair needs OpenCV — "
              "pip install opencv-contrib-python-headless")
        sys.exit(2)

BG_DIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "src", "assets", "backgrounds"))

# Interior rectangular quads, per file, as (x0, y0, x1, y1) in source pixels.
# Measured off the art at 2x zoom and cross-checked against a detector for
# columns/rows carrying an unnaturally persistent hard edge. Only the Blaze
# Rush gold plate carries these; every other background's defect is the
# right-edge band, which is found automatically.
INTERIOR_QUADS = {
    "bg_blaze_l3_gold.jpg": [
        (20, 272, 180, 366),
        (216, 350, 362, 432),
        # Runs to the right border on purpose: this quad sits against the edge
        # smear, and rebuilding only to the quad's own edge left a strip of
        # streaks between the two repairs. Doing the whole corner in one pass
        # removes both, after which there is no band left to crop — so this
        # plate keeps its full width with no rescale at all.
        (950, 272, 1280, 500),
    ],
}

# A column carrying this fraction (or less) of the plate's typical
# column-to-column change is treated as smeared. The band fades in over ~100px
# rather than ending abruptly, so a tight threshold (0.45 was the first try)
# clips only the flattest core and leaves visible streaks behind — confirmed
# by eye on the repaired plate. 0.70 takes the whole gradient.
SMEAR_RATIO = 0.70
MIN_BAND = 16        # ignore runs shorter than this

# FIRST, DO NO HARM. Plates listed here are left exactly as authored.
#
# bg_l3_goldrush is the Stage 3 canyon. Its right-edge streaking is faint, the
# founder never flagged it in any screenshot — and a small Bitcoin coin sits at
# x 1115..1195, right inside the band. Every repair available there is worse
# than the defect: cropping to clear the streaks slices the coin (which is
# exactly what he caught: "the bitcoin logo against the background is now
# cut!!!"), and inpainting around a protected coin box leaves visible patch
# seams in the canyon wall. A faint streak nobody reported beats a cut brand
# mark, so this plate stays untouched until the art itself is regenerated.
SKIP = {
    "bg_l3_goldrush.jpg",
    # The widened Stage 3 plate (bg_l3_goldrush.jpg + its horizontal mirror,
    # 2560px) that the level now actually uses — added 2026-09-17 to kill the
    # "central peak smudge" (the 1280px plate's dark canyon-wall edges doubling
    # at the parallax wrap; widening it means it never wraps in-level). The
    # mirror puts the same dark, low-detail (but NOT smeared) canyon wall on the
    # right edge, so the streak heuristic false-positives here for the identical
    # reason the original is skipped, and repairing it would still risk the
    # baked wBTC coin. Tiling + width are gated separately by
    # scripts/check-l3-wide-backdrop.py.
    "bg_l3_goldrush_wide.jpg",
}


def smear_band(img: np.ndarray) -> int:
    """Width in px of the horizontally-smeared run touching the RIGHT edge.

    A smeared column is nearly identical to its neighbour (the generator
    stretched one column sideways), so the mean |column - next column|
    collapses far below the plate's typical value.
    """
    d = np.abs(np.diff(img.astype(float), axis=1)).mean(axis=(0, 2))
    med = float(np.median(d))
    if med <= 0:
        return 0
    low = d < med * SMEAR_RATIO
    x = len(low) - 1
    while x >= 0 and low[x]:
        x -= 1
    width = len(low) - 1 - x
    return width if width >= MIN_BAND else 0


def rebuild(img: np.ndarray, hole: np.ndarray) -> np.ndarray:
    """Reconstruct the masked area from real content elsewhere in the plate.

    SHIFTMAP is exemplar-based: it copies matching patches from the rest of the
    painting. Telea, the obvious alternative, diffuses surrounding colour
    inward and leaves exactly the soft smeared blobs the founder is complaining
    about — measured on this same art, so this is not a stylistic preference.

    NOTE the inverted mask convention: cv2.xphoto.inpaint treats NON-ZERO as
    the KNOWN pixels, the opposite of cv2.inpaint. Verified empirically before
    relying on it (the other way round changed the hole by 0.2/255 — it
    silently did nothing).
    """
    dst = np.zeros_like(img)
    cv2.xphoto.inpaint(img, (255 - hole), dst, cv2.xphoto.INPAINT_SHIFTMAP)
    if dst.size == 0 or int(dst.max()) == 0:
        return cv2.inpaint(img, hole, 10, cv2.INPAINT_TELEA)
    return dst


def salience(img: np.ndarray) -> np.ndarray:
    """Per-column 'how much does this column matter' score.

    A column running through a brand logo, a coin or a lit prop is bright,
    saturated and full of edges; one running through flat sky or shadowed rock
    is not. Used to place the crop where it cannot slice a artwork element.
    """
    f = img.astype(np.float32)
    bright = f.max(axis=2)                       # luminance-ish
    sat = bright - f.min(axis=2)                 # colourfulness
    # MAX down the column, never the mean. A Bitcoin coin is ~110px tall in a
    # 720px frame, so averaging dilutes it to nothing — measured: the coin's
    # column scored 0.11 by mean (indistinguishable from empty sky at 0.02)
    # but 0.78 by max against 0.05 for sky. The mean version is exactly why
    # the first cut went straight through the coin.
    return ((bright / 255.0) * (sat / 255.0)).max(axis=0)


def safe_cut(img: np.ndarray, floor_px: int) -> int:
    """How many right-hand columns to drop: enough to clear the smear, placed
    where the cut does NOT run through artwork.

    FOUNDER, 2026-09-17: "the bitcoin logo against the background is now cut!!!"
    He was right. The first version cropped a fixed `floor_px` and then rescaled
    back to the original width. Two separate harms, both real:

      * the rescale stretched every plate ~8% horizontally, turning the round
        Bitcoin coin in bg_l3_goldrush into an ellipse — a distorted BRAND MARK;
      * the cut landed at x=1185, straight through a second, smaller Bitcoin
        coin that occupies x 1115..1195, lopping its right edge off.

    So: never rescale (the caller now keeps the cropped width, and the engine
    tiles by the real texture width anyway, so nothing downstream cares), and
    walk the cut outward from the minimum until it sits in a quiet column.
    """
    w = img.shape[1]
    s = salience(img)
    quiet = float(np.percentile(s, 40))       # "ordinary background" for this plate

    def edge_score(cut: int) -> float:
        col = w - cut - 1                     # the column that becomes the new edge
        return float(s[max(0, col - 4):col + 1].max())

    # Prefer the smallest cut, at or beyond the smear start, that leaves a quiet
    # edge. Failing that, pull the cut BACK below the smear start — leaving a
    # few columns of the faintest streaks is a far smaller sin than slicing a
    # brand mark in half, and the band fades out gradually anyway.
    for cut in range(floor_px, min(floor_px + 220, w - 32)):
        if edge_score(cut) <= quiet:
            return cut
    for cut in range(floor_px - 1, max(0, floor_px - 60), -1):
        if edge_score(cut) <= quiet:
            return cut
    # Nothing quiet either way: take the least-bad edge rather than guessing.
    span = range(max(1, floor_px - 60), min(floor_px + 220, w - 32))
    return min(span, key=edge_score)


def repair(path: str) -> tuple[bool, str]:
    name = os.path.basename(path)
    if name in SKIP:
        return True, f"{name}: SKIPPED by policy (see SKIP)"
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    if img is None:
        return False, f"{name}: unreadable"
    h, w = img.shape[:2]
    notes: list[str] = []

    quads = INTERIOR_QUADS.get(name, [])
    if quads:
        mask = np.zeros((h, w), np.uint8)
        for (x0, y0, x1, y1) in quads:
            mask[max(0, y0):min(h, y1), max(0, x0):min(w, x1)] = 255
        img = rebuild(img, mask)
        notes.append(f"rebuilt {len(quads)} quad(s)")

    band = smear_band(img)
    if band:
        cut = safe_cut(img, band)
        img = img[:, : w - cut]
        notes.append(f"cropped {cut}px smear band (now {img.shape[1]}px wide)")

    if not notes:
        # Nothing to do — do NOT rewrite. Re-encoding a clean JPEG just to
        # produce an identical-looking file costs a generation of quality and
        # shows up as a pointless diff in review.
        return True, f"{name}: already clean (untouched)"

    params = [int(cv2.IMWRITE_JPEG_QUALITY), 95] \
        if path.lower().endswith((".jpg", ".jpeg")) else []
    cv2.imwrite(path, img, params)

    # Verify the bytes actually written, not the array in memory: JPEG
    # re-encoding changes the measurement, and an in-memory check once
    # reported a plate fixed while the shipped file still failed.
    ok, msg = check(path)
    return ok, f"{name}: " + ", ".join(notes) + (" [STILL DEFECTIVE]" if not ok else "")


def check(path: str) -> tuple[bool, str]:
    """Gate: fail if a shipped background still carries a smear band.

    Runs on PIL+numpy so CI needs no OpenCV.
    """
    from PIL import Image

    name = os.path.basename(path)
    try:
        img = np.asarray(Image.open(path).convert("RGB"))
    except Exception as exc:  # noqa: BLE001 - reported, not swallowed
        return False, f"{name}: unreadable ({exc})"
    band = smear_band(img)
    if name in SKIP:
        return True, f"{name}: smear_band={band}px (skipped by policy)"
    return band == 0, f"{name}: smear_band={band}px"


def main() -> int:
    checking = "--check" in sys.argv
    files = sorted(
        os.path.join(BG_DIR, f)
        for f in os.listdir(BG_DIR)
        if f.lower().endswith((".jpg", ".jpeg", ".png"))
    )
    bad = 0
    for f in files:
        ok, msg = check(f) if checking else repair(f)
        print(("  [OK]   " if ok else "  [FAIL] ") + msg)
        bad += 0 if ok else 1
    print(f"BACKGROUND_ART: {'ALL CLEAN' if bad == 0 else f'{bad} DEFECTIVE'}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
