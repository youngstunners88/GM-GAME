#!/usr/bin/env python3
"""Reads the key-colour captures of weapon_consistency_shot: per frame, the whole view and the gun alone (arm excluded) in pixels.
python3 tools/ep2_shots/weapon_consistency_measure.py <dir> [out.json]

The gun alone comes from the `-gun` frame when the view has separate arms, else from colour: the sleeve and glove are green/olive (hue 45-130, measured
as channel ratios, not a colour name), and the rest is gun. Prints bbox width, height, diagonal length, area and whether anything covers the centre third.
"""
import glob
import json
import os
import subprocess
import sys

import numpy as np


def load_rgb(path: str) -> np.ndarray:
    """H x W x 3 uint8 through ImageMagick (no PIL on this machine)."""
    w, h = subprocess.check_output(["magick", "identify", "-format", "%w %h", path], text=True).split()
    raw = subprocess.check_output(["magick", path, "-depth", "8", "rgb:-"])
    return np.frombuffer(raw, dtype=np.uint8).reshape(int(h), int(w), 3)


def key_mask(a: np.ndarray) -> np.ndarray:
    """True where the frame is not the magenta key."""
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return ~((r > 200) & (b > 200) & (g < 60))


def arm_mask(a: np.ndarray) -> np.ndarray:
    """Green sleeve + olive glove: green is at least the largest channel, or olive with green close to red and blue well under both."""
    r, g, b = a[..., 0].astype(float), a[..., 1].astype(float), a[..., 2].astype(float)
    return (g >= r * 0.92) & (g > b * 1.25)


def box(mask: np.ndarray) -> dict | None:
    ys, xs = np.nonzero(mask)
    if xs.size < 30:
        return None
    x0, x1, y0, y1 = int(np.percentile(xs, 0.2)), int(np.percentile(xs, 99.8)), int(np.percentile(ys, 0.2)), int(np.percentile(ys, 99.8))
    return {"x0": x0, "x1": x1, "y0": y0, "y1": y1, "w": x1 - x0, "h": y1 - y0, "diag": round(float(np.hypot(x1 - x0, y1 - y0)), 1), "area": int(xs.size)}


def centre_third(mask: np.ndarray) -> float:
    h, w = mask.shape
    return round(float(mask[h // 3: 2 * h // 3, w // 3: 2 * w // 3].mean()), 4)


def main() -> None:
    d = sys.argv[1]
    res = {}
    for path in sorted(glob.glob(os.path.join(d, "*.png"))):
        name = os.path.basename(path)[:-4]
        if name.endswith("-gun") or not (name.startswith("ads-") or name.startswith("hip-")):
            continue
        a = load_rgb(path)
        whole = key_mask(a)
        gun_path = os.path.join(d, name + "-gun.png")
        if os.path.exists(gun_path):
            gun = key_mask(load_rgb(gun_path))
            source = "gun frame"
        else:
            gun = whole & ~arm_mask(a)
            source = "colour"
        arm = whole & ~gun
        res[name] = {"gun_source": source, "gun": box(gun), "whole": box(whole), "arm_in_centre_third": centre_third(arm), "gun_in_centre_third": centre_third(gun)}
        print(name, json.dumps(res[name]))
    if len(sys.argv) > 2:
        with open(sys.argv[2], "w") as f:
            json.dump(res, f, indent=1)


if __name__ == "__main__":
    main()
