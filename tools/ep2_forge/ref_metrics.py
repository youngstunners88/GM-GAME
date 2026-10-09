#!/usr/bin/env python3
"""NUMBERS for the reference-match loop (skill ep2-hyperreal-scene-pipeline).

  python3 tools/ep2_forge/ref_metrics.py <reference.jpg> <capture.png> [--json out.json] [--state]

Jev (the decisions model) is TEXT-ONLY: it cannot see a screenshot, so a verdict on pixels must be fed numbers (CLAUDE.md model role split).
This turns "does my engine capture look like the reference?" into numbers:
  lum_emd      luminance-histogram distance (0 same .. 1 opposite)         too dark / flat / blown out
  palette_dist k-means palette distance, mean nearest-colour gap (0..1)     wrong colour world
  sat_diff     |mean saturation difference|                                 washed out / over-cooked
  warmth_diff  |log2(R/B ratio difference)|                                 warm sunset vs grey/blue
  edge_ratio   capture edge density / reference edge density                a flat grey box has ~0.1, a detailed scene ~0.7-1.3
  closeness    0..1 blend of the above (1 = same look). COARSE: it catches gross errors, never fine fidelity.
The reference is a GPT-image still and the capture is a real-time Godot frame, so a closeness of 0.55-0.7 is a good match; < 0.35 is wrong.
--state prints the paragraph to hand to `node scripts/jev.mjs --state "<text>" --bool "name=question"`.
"""
import argparse
import json
import math
import sys

import numpy as np
from PIL import Image

W, H = 320, 180


def load(path):
    return np.asarray(Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS), dtype=np.float32) / 255.0


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def sat(a):
    mx, mn = a.max(-1), a.min(-1)
    return np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)


def edges(l):
    gx = np.zeros_like(l)
    gy = np.zeros_like(l)
    gx[:, 1:-1] = l[:, 2:] - l[:, :-2]
    gy[1:-1, :] = l[2:, :] - l[:-2, :]
    return np.sqrt(gx * gx + gy * gy)


def emd1d(a, b, bins=32):
    ha, _ = np.histogram(a, bins=bins, range=(0, 1))
    hb, _ = np.histogram(b, bins=bins, range=(0, 1))
    ha = ha / ha.sum()
    hb = hb / hb.sum()
    return float(np.abs(np.cumsum(ha) - np.cumsum(hb)).sum() / bins)


def palette(a, k=6, iters=12, seed=1):
    px = a.reshape(-1, 3)
    rng = np.random.default_rng(seed)
    c = px[rng.choice(len(px), k, replace=False)]
    for _ in range(iters):
        d = ((px[:, None, :] - c[None]) ** 2).sum(-1)
        lab = d.argmin(1)
        for i in range(k):
            m = px[lab == i]
            if len(m):
                c[i] = m.mean(0)
    w = np.bincount(lab, minlength=k) / len(px)
    return c, w


def palette_dist(a, b):
    ca, wa = palette(a)
    cb, _ = palette(b)
    d = np.sqrt(((ca[:, None, :] - cb[None]) ** 2).sum(-1)).min(1)       # for each reference colour, the nearest capture colour
    return float((d * wa).sum() / math.sqrt(3.0))


def metrics(ref_path, cap_path):
    r, c = load(ref_path), load(cap_path)
    lr, lc = lum(r), lum(c)
    m = {
        "lum_mean_ref": float(lr.mean()), "lum_mean_cap": float(lc.mean()),
        "lum_std_ref": float(lr.std()), "lum_std_cap": float(lc.std()),
        "lum_emd": emd1d(lr, lc),
        "palette_dist": palette_dist(r, c),
        "sat_ref": float(sat(r).mean()), "sat_cap": float(sat(c).mean()),
    }
    m["sat_diff"] = abs(m["sat_ref"] - m["sat_cap"])
    wr = float(r[..., 0].mean() / max(r[..., 2].mean(), 1e-3))
    wc = float(c[..., 0].mean() / max(c[..., 2].mean(), 1e-3))
    m["warmth_ref"], m["warmth_cap"] = wr, wc
    m["warmth_diff"] = abs(math.log2(max(wc, 1e-3) / max(wr, 1e-3)))
    er, ec = float(edges(lr).mean()), float(edges(lc).mean())
    m["edge_ref"], m["edge_cap"] = er, ec
    m["edge_ratio"] = ec / max(er, 1e-4)
    parts = [
        1 - min(m["lum_emd"] / 0.20, 1.0),
        1 - min(m["palette_dist"] / 0.30, 1.0),
        1 - min(m["sat_diff"] / 0.30, 1.0),
        1 - min(m["warmth_diff"] / 0.80, 1.0),
        1 - min(abs(math.log(max(m["edge_ratio"], 1e-3))) / 1.2, 1.0),
    ]
    m["closeness"] = float(np.mean(parts))
    return {k: round(v, 4) for k, v in m.items()}


def state_text(m, name):
    return (f"Automated image-metric report comparing a real-time game capture ({name}) with its target reference still. "
            f"Overall closeness {m['closeness']:.2f} on a 0 to 1 scale (0.55 to 0.70 is a good match for a game frame against a rendered still; below 0.35 is wrong). "
            f"Luminance histogram distance {m['lum_emd']:.3f} (0 same, above 0.20 means the capture is far too dark, flat or blown out). "
            f"Palette distance {m['palette_dist']:.3f} (above 0.30 means a different colour world). "
            f"Saturation reference {m['sat_ref']:.2f} versus capture {m['sat_cap']:.2f}. "
            f"Warmth (red over blue) reference {m['warmth_ref']:.2f} versus capture {m['warmth_cap']:.2f}. "
            f"Edge density ratio capture over reference {m['edge_ratio']:.2f} (about 0.1 is a flat grey-box scene, 0.7 to 1.3 is a detailed scene).")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("reference")
    ap.add_argument("capture")
    ap.add_argument("--json")
    ap.add_argument("--state", action="store_true")
    a = ap.parse_args()
    mm = metrics(a.reference, a.capture)
    if a.json:
        json.dump(mm, open(a.json, "w"), indent=1)
    print(state_text(mm, a.capture) if a.state else json.dumps(mm, indent=1))
