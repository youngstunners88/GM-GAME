#!/usr/bin/env python3
"""Cut a props sheet (props on a white background) into the 4x2 alpha atlas that
RoomFixture.gd expects: 8 cells of 443.5x443.5 px, prop centred horizontally and
bottom-aligned so the ground contact sits at ~93% of the cell height.

Usage: build_prop_atlas.py <sheet.jpg|png> <out_atlas.png> [--debug <checker.png>] [--no-shadow]
--no-shadow drops baked drop shadows and pale glow halos and de-fringes the white
matte off the edges (RoomFixture draws its own contact + cast shadows, and a baked
one would double up and point the wrong way).
Order = row-major by component position (top row left->right, then bottom row).
White is removed by a border flood fill; light-grey drop shadows that touch the
background become soft black alpha, so the props keep a grounded contact shadow.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

CELL_W, CELL_H, COLS, ROWS = 443, 443, 4, 2
FILL_W, FILL_H, CONTACT = 0.86, 0.86, 0.93

def cutout(rgb: np.ndarray, no_shadow: bool = False):
    mn = rgb.min(axis=2)
    sat = rgb.max(axis=2) - mn
    bg_strict = (mn >= 244) & (sat <= 10)
    lab, n = ndi.label(bg_strict)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    if no_shadow:
        # pale halos touching the background, plus enclosed white pockets (e.g. between
        # a scale's chains) that a hole fill would otherwise turn into solid white
        pale = (mn >= 222) & (sat <= 30)
        p_lab, _ = ndi.label(pale | bg)
        bg |= np.isin(p_lab, list(set(np.unique(p_lab[bg])) - {0})) & pale
        pocket_lab, pn = ndi.label((mn >= 238) & (sat <= 8))
        sizes = ndi.sum(np.ones_like(pocket_lab), pocket_lab, index=np.arange(1, pn + 1))
        for i, sz in enumerate(sizes, start=1):
            if sz >= 150:
                bg |= pocket_lab == i
    obj = ~bg
    # Shadow = light grey, unsaturated pixels within reach of the background.
    near_bg = ndi.binary_dilation(bg, iterations=60)
    shadowish = obj & (sat <= 22) & (mn >= 150) & near_bg
    # keep only shadow pixels connected to the background (not glass/paper inside props)
    sh_lab, _ = ndi.label(shadowish | bg)
    bg_ids = set(np.unique(sh_lab[bg])) - {0}
    shadow = shadowish & np.isin(sh_lab, list(bg_ids))
    if no_shadow:
        # baked drop shadow is background: the room draws its own
        gone = bg | shadow
        solid = ndi.binary_fill_holes(~gone) & ~gone  # no opening: it would break thin chains
        return solid, np.zeros_like(shadow)
    solid = obj & ~shadow
    solid = ndi.binary_opening(solid, iterations=1)
    solid = ndi.binary_fill_holes(solid)
    return solid, shadow

def defringe(rgb: np.ndarray, solid: np.ndarray, width: int = 1) -> np.ndarray:
    """Replace the outer `width` px of colour with the nearest interior colour so no
    white matte survives at the silhouette edge."""
    core = ndi.binary_erosion(solid, iterations=width)
    _, (iy, ix) = ndi.distance_transform_edt(~core, return_indices=True)
    out = rgb.copy()
    ring = solid & ~core
    out[ring] = rgb[iy[ring], ix[ring]]
    return out


def load_rgba(src, no_shadow: bool = False):
    """RGBA straight through when the sheet already carries transparency, otherwise
    white-key an opaque sheet (Gemini/GPT image models return white backgrounds)."""
    im = Image.open(src)
    if im.mode == "RGBA" and np.array(im.getchannel("A")).min() == 0:
        return np.array(im).astype(np.uint8)
    rgb = np.array(im.convert("RGB")).astype(np.int32)
    solid, shadow = cutout(rgb, no_shadow)
    if no_shadow:
        rgb = defringe(rgb, solid)
    h, w = solid.shape
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = rgb.astype(np.uint8)
    a = np.zeros((h, w), np.float32)
    dark = (255 - rgb.min(axis=2)).astype(np.float32) / 255.0
    a[shadow] = np.clip(dark[shadow] * 1.15, 0, 0.55)
    out[shadow & ~solid, :3] = 0
    a = np.where(solid, np.clip(ndi.gaussian_filter(solid.astype(np.float32), 0.8) * 1.2, 0, 1), a)
    out[..., 3] = (a * 255).astype(np.uint8)
    return out


def main():
    src, out = sys.argv[1], sys.argv[2]
    arr = load_rgba(src, "--no-shadow" in sys.argv)
    h, w = arr.shape[:2]
    solid = arr[..., 3] > 40
    merged = ndi.binary_dilation(solid, iterations=10)
    lab, n = ndi.label(merged)
    boxes = []
    for i, sl in enumerate(ndi.find_objects(lab), start=1):
        if (lab[sl] == i).sum() < 4000:
            continue
        # tight box of the visible pixels of this prop
        ys, xs = sl
        sub = solid[ys, xs] & (lab[ys, xs] == i)
        yy, xx = np.where(sub)
        boxes.append(((slice(ys.start + yy.min(), ys.start + yy.max() + 1), slice(xs.start + xx.min(), xs.start + xx.max() + 1)), i))
    boxes.sort(key=lambda b: (b[0][0].start // (h // ROWS), b[0][1].start))
    if len(boxes) != COLS * ROWS:
        print("WARN: found", len(boxes), "props (expected 8)")
    atlas = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS), (0, 0, 0, 0))
    for idx, (sl, i) in enumerate(boxes[: COLS * ROWS]):
        ys, xs = sl
        # only THIS prop's pixels (neighbours' soft fringes must not bleed into the crop)
        own = arr.copy()
        own[..., 3] = np.where(lab == i, own[..., 3], 0)
        im = Image.fromarray(own, "RGBA")
        pad = 40  # keep any soft shadow around the prop
        box = (max(xs.start - pad, 0), max(ys.start - pad, 0), min(xs.stop + pad, w), min(ys.stop + pad, h))
        crop = im.crop(box)
        sb = (xs.start - box[0], ys.start - box[1], xs.stop - box[0], ys.stop - box[1])
        pw, ph = sb[2] - sb[0], sb[3] - sb[1]
        k = min(CELL_W * FILL_W / pw, CELL_H * FILL_H / ph)
        crop = crop.resize((max(1, int(crop.width * k)), max(1, int(crop.height * k))), Image.LANCZOS)
        cx = int((sb[0] + pw / 2) * k)
        cy = int(sb[3] * k)
        col, row = idx % COLS, idx // COLS
        ox = col * CELL_W + CELL_W // 2 - cx
        oy = row * CELL_H + int(CELL_H * CONTACT) - cy
        layer = Image.new("RGBA", atlas.size, (0, 0, 0, 0))
        layer.paste(crop, (ox, oy))
        clip = np.zeros((atlas.size[1], atlas.size[0]), np.uint8)
        clip[row * CELL_H:(row + 1) * CELL_H, col * CELL_W:(col + 1) * CELL_W] = 255
        layer.putalpha(Image.fromarray(np.minimum(np.array(layer.getchannel("A")), clip)))
        atlas = Image.alpha_composite(atlas, layer)
    atlas.save(out, optimize=True)
    if "--debug" in sys.argv:
        chk = Image.new("RGB", atlas.size, (120, 110, 100))
        chk.paste(atlas, (0, 0), atlas)
        chk.save(sys.argv[sys.argv.index("--debug") + 1], quality=80)
    print("atlas", atlas.size, "props", len(boxes))


main()
