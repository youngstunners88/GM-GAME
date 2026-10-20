#!/usr/bin/env python3
"""Paint the GoldMine town's sign boards (skill ep2-gold-rush-town): cream serif letters with a dark outline and a hairline border on
weathered dark-brown boards, like the founder's town target. Writes src/episode2/assets/town/sign_<WORD>.png (1024 wide).
Never a DIAMONDS sign in Episode 2 (ep2-fort-knox-arc rule 4).

    python3 tools/ep2_forge/paint_town_signs.py                    # every sign
    python3 tools/ep2_forge/paint_town_signs.py ARMS               # just the armory board
    python3 tools/ep2_forge/paint_town_signs.py ARMS --font <ttf>  # a specific face
"""
import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path("src/episode2/assets/town")
# DejaVu is the original face; fall back to any serif present, then to the in-repo Western bookman.
FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
    "/usr/share/fonts/liberation/LiberationSerif-Bold.ttf",
    "src/episode2/assets/weapons/armory/western_bookman.otf",
]
WORDS = {"CERTIFICATES": "CERTIFICATES", "SALOON": "SALOON", "TREASURY": "TREASURY", "GENERAL": "GENERAL STORE", "HOTEL": "HOTEL",
         "ASSAY": "ASSAY OFFICE", "AUCTIONS": "AUCTIONS", "STATS": "STATS", "RESERVE": "RESERVE", "FORTKNOX": "FORT KNOX",
         "ARMS": "RICH & UTAH ARMS", "JAIL": "JAILHOUSE"}


def font_path(override=None):
    if override:
        return override
    for f in FONT_CANDIDATES:
        if Path(f).exists():
            return f
    raise SystemExit("no serif font found for the town signs")


def board(text, w=1024, h=180, seed=0, font_file=None):
    rng = random.Random(seed)
    im = Image.new("RGB", (w, h), (52, 34, 22))
    px = im.load()
    for y in range(h):                     # plank grain + weathering
        band = (y // 45) % 2
        for x in range(w):
            n = rng.random() * 14 - 7 + (6 if band else 0) + 5 * ((x * 7 + y * 3) % 23 == 0)
            r, g, b = px[x, y]
            px[x, y] = (max(0, int(r + n)), max(0, int(g + n * 0.8)), max(0, int(b + n * 0.6)))
    d = ImageDraw.Draw(im)
    for yy in (45, 90, 135):
        d.line([(0, yy), (w, yy)], fill=(30, 20, 13), width=2)
    d.rectangle([10, 10, w - 11, h - 11], outline=(214, 190, 140), width=4)
    d.rectangle([20, 20, w - 21, h - 21], outline=(120, 96, 62), width=2)
    size = 120
    font = ImageFont.truetype(font_file, size)
    while d.textlength(text, font=font) > w - 90 and size > 40:
        size -= 4
        font = ImageFont.truetype(font_file, size)
    tw = d.textlength(text, font=font)
    x = (w - tw) / 2
    y = (h - size) / 2 - size * 0.12
    d.text((x + 4, y + 5), text, font=font, fill=(20, 12, 8))
    d.text((x, y), text, font=font, fill=(232, 214, 168), stroke_width=3, stroke_fill=(70, 46, 26))
    wear = Image.new("L", (w, h), 0)
    wd = ImageDraw.Draw(wear)
    for _ in range(260):
        cx, cy = rng.randrange(w), rng.randrange(h)
        wd.ellipse([cx, cy, cx + rng.randrange(2, 9), cy + rng.randrange(1, 4)], fill=rng.randrange(40, 120))
    dark = Image.new("RGB", (w, h), (60, 40, 26))
    im = Image.composite(dark, im, wear.filter(ImageFilter.GaussianBlur(0.8)))
    return im


def main():
    ap = argparse.ArgumentParser(description="paint the town sign boards")
    ap.add_argument("keys", nargs="*", help="only these sign keys (default: all)")
    ap.add_argument("--font", default=None, help="font file override")
    ap.add_argument("--out", default=None, help="output folder (default src/episode2/assets/town); streamed extras use src/episode2/extras/jail")
    args = ap.parse_args()
    chosen = font_path(args.font)
    out = Path(args.out) if args.out else OUT
    out.mkdir(parents=True, exist_ok=True)
    for i, (key, text) in enumerate(WORDS.items()):
        if args.keys and key not in args.keys:
            continue
        board(text, seed=i, font_file=chosen).save(out / f"sign_{key}.png")
        print("sign", key, "->", chosen)


if __name__ == "__main__":
    main()
