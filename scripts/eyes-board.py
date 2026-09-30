#!/usr/bin/env python3
"""eyes-board.py - turn one `eyes=1` capture into boards a reviewer (human, Claude or a vision model)
can actually read (skill: see-it-yourself).

  python3 scripts/eyes-board.py <shot_dir> <metres> [--ref REF.jpg --ref-box x0,y0,x1,y1] [--box x0,y0,x1,y1]

Writes, next to the capture:
  d####_board.png  game frame | subject crop x3 | reference crop at the same height (labelled)
  d####_orbit.png  the six orbit views of the same frozen frame, each cropped on the subject

Why crops: at 1280x720 the hero is ~200 px tall; a full-frame read (by eye or by a model) misses a hat
through a head, a hidden revolver or a pickaxe held like a club. The crop is where the defects are.
The subject box comes from the `EYES box` line the capture prints (posed skeleton, projected).
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

LABEL_H = 34


def _font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
              "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def _label(img, text):
    out = Image.new("RGB", (img.width, img.height + LABEL_H), (18, 18, 18))
    out.paste(img, (0, LABEL_H))
    ImageDraw.Draw(out).text((10, 6), text, fill=(255, 214, 90), font=_font(20))
    return out


def _fit_h(img, h):
    return img.resize((max(1, int(img.width * h / img.height)), h), Image.LANCZOS)


def _row(tiles, gap=8):
    w = sum(t.width for t in tiles) + gap * (len(tiles) - 1)
    h = max(t.height for t in tiles)
    out = Image.new("RGB", (w, h), (18, 18, 18))
    x = 0
    for t in tiles:
        out.paste(t, (x, 0))
        x += t.width + gap
    return out


def _box(s):
    return tuple(int(v) for v in s.split(","))


def _lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def metrics(stem, box=None):
    """Hero mask from the with/without-hero pair, then numbers a gate (or Jev) can read:
    area, value contrast against the background ring around him, RMS contrast inside him,
    and pixel counts for the parts the founder names (gold revolver, green leaves, brown leather)."""
    if not os.path.exists(stem + "_nohero.png"):
        return None
    g = np.asarray(Image.open(stem + ".png").convert("RGB")).astype(float)
    n = np.asarray(Image.open(stem + "_nohero.png").convert("RGB")).astype(float)
    mask = np.abs(g - n).max(-1) > 18
    # Particles (embers, sparks) keep simulating between the two renders: keep only the diff inside the
    # skeleton's projected box, and only its largest connected blob (the hero), closed over small gaps.
    if box is not None:
        keep = np.zeros_like(mask)
        keep[max(0, box[1]):box[3], max(0, box[0]):box[2]] = True
        mask &= keep
    try:
        from scipy import ndimage
        mask = ndimage.binary_closing(mask, iterations=2)
        lab, nlab = ndimage.label(mask)
        if nlab > 1:
            sizes = ndimage.sum(mask, lab, range(1, nlab + 1))
            mask = lab == (1 + int(np.argmax(sizes)))
    except ImportError:
        pass
    if mask.sum() < 50:
        return mask, {"area_pct": 0.0, "note": "hero not on screen"}
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    pad = max(8, int(0.25 * max(y1 - y0, x1 - x0)))
    ring = np.zeros_like(mask)
    ring[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad] = True
    ring &= ~mask
    L = _lum(g)
    hero = g[mask]
    r, gg, b = hero[:, 0], hero[:, 1], hero[:, 2]
    gold = (r > 150) & (gg > 105) & (b < 0.62 * r) & (r >= gg) & (gg > b)
    green = (gg > r * 1.08) & (gg > b * 1.3) & (gg > 60)
    brown = (r > gg * 1.25) & (gg > b) & (r > 50) & ~gold
    lh, lb = L[mask], L[ring]
    return mask, {
        "area_pct": round(100.0 * mask.mean(), 2),
        "bbox": [int(x0), int(y0), int(x1), int(y1)],
        "hero_lum": round(float(lh.mean()), 1),
        "bg_ring_lum": round(float(lb.mean()), 1),
        "value_sep": round(float(abs(lh.mean() - lb.mean())), 1),
        "hero_rms_contrast": round(float(lh.std() / max(lh.mean(), 1.0)), 3),
        "hero_p95_lum": round(float(np.percentile(lh, 95)), 1),
        "gold_px": int(gold.sum()),
        "green_pct": round(100.0 * green.mean(), 1),
        "brown_pct": round(100.0 * brown.mean(), 1),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("metres", type=int)
    ap.add_argument("--box", help="subject box in the game frame (from the EYES box line)")
    ap.add_argument("--ref")
    ap.add_argument("--ref-box", help="subject box in the reference image")
    ap.add_argument("--h", type=int, default=560, help="board row height")
    ap.add_argument("--compare", help="more marks to grid against <metres> (A/B of `vary=` variants): 55,70")
    ap.add_argument("--views", default="game,back,left,front", help="columns for --compare")
    ap.add_argument("--labels", help="row labels for --compare, ';'-separated")
    a = ap.parse_args()

    if a.compare:
        marks = [a.metres] + [int(m) for m in a.compare.split(",")]
        labels = a.labels.split(";") if a.labels else ["d%04d" % m for m in marks]
        box = _box(a.box) if a.box else None
        rows = []
        for m, lab in zip(marks, labels):
            stem = os.path.join(a.dir, "d%04d" % m)
            cells = []
            for v in a.views.split(","):
                im = Image.open(stem + (".png" if v == "game" else "_%s.png" % v)).convert("RGB")
                if v == "game" and box:
                    im = im.crop(box)
                elif v != "game":
                    cw, ch = im.width // 2, int(im.height * 0.9)
                    im = im.crop(((im.width - cw) // 2, (im.height - ch) // 2, (im.width + cw) // 2, (im.height + ch) // 2))
                cells.append(_label(_fit_h(im, 300), "%s | %s" % (lab, v)))
            rows.append(_row(cells))
        grid = Image.new("RGB", (max(r.width for r in rows), sum(r.height + 8 for r in rows)), (18, 18, 18))
        y = 0
        for r in rows:
            grid.paste(r, (0, y))
            y += r.height + 8
        outp = os.path.join(a.dir, "compare.png")
        grid.save(outp)
        print("compare", outp)
        return 0

    stem = os.path.join(a.dir, "d%04d" % a.metres)
    game = Image.open(stem + ".png").convert("RGB")
    box = _box(a.box) if a.box else (0, 0, game.width, game.height)
    box = (max(0, box[0]), max(0, box[1]), min(game.width, box[2]), min(game.height, box[3]))
    tiles = [_label(_fit_h(game, a.h), "GAME CAMERA (what the player sees)"),
             _label(_fit_h(game.crop(box), a.h), "SUBJECT CROP x%.1f" % (a.h / (box[3] - box[1])))]
    if a.ref:
        ref = Image.open(a.ref).convert("RGB")
        rb = _box(a.ref_box) if a.ref_box else (0, 0, ref.width, ref.height)
        tiles.append(_label(_fit_h(ref.crop(rb), a.h), "FOUNDER TARGET (same crop)"))
    m = metrics(stem, box)
    if m is not None:
        mask, stats = m
        crop = game.crop(box)
        # Value test (artists' greyscale check): does he separate from the tunnel without colour?
        tiles.append(_label(_fit_h(crop.convert("L").convert("RGB"), a.h), "VALUE (greyscale) test"))
        # Thumbnail test: the whole frame at 25 % - is he still findable at a glance?
        thumb = game.resize((game.width // 4, game.height // 4), Image.LANCZOS)
        tiles.append(_label(_fit_h(thumb, a.h // 2), "THUMBNAIL 25%"))
        tiles.append(_label(_fit_h(Image.fromarray((mask * 255).astype("uint8")).convert("RGB").crop(box), a.h),
                            "HERO MASK %.1f%% of frame" % stats["area_pct"]))
        with open(stem + "_metrics.json", "w") as f:
            json.dump(stats, f, indent=1)
        print("metrics", json.dumps(stats))
    _row(tiles).save(stem + "_board.png")
    print("board", stem + "_board.png")

    views = ["back", "front", "left", "right", "q_front", "top"]
    have = [v for v in views if os.path.exists("%s_%s.png" % (stem, v))]
    if not have:
        return 0
    cells = []
    for v in have:
        im = Image.open("%s_%s.png" % (stem, v)).convert("RGB")
        # the orbit camera looks at the subject centre: the middle third holds the subject
        cw, ch = im.width // 2, int(im.height * 0.9)
        crop = im.crop(((im.width - cw) // 2, (im.height - ch) // 2, (im.width + cw) // 2, (im.height + ch) // 2))
        cells.append(_label(_fit_h(crop, 380), v.upper()))
    rows = [_row(cells[i:i + 3]) for i in range(0, len(cells), 3)]
    sheet = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows) + 8 * (len(rows) - 1)), (18, 18, 18))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y))
        y += r.height + 8
    sheet.save(stem + "_orbit.png")
    print("orbit", stem + "_orbit.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
