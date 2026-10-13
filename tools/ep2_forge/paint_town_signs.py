#!/usr/bin/env python3
"""Paint the GoldMine town's sign boards (skill ep2-gold-rush-town): cream serif letters with a dark outline and a hairline border on
weathered dark-brown boards, like the founder's town target. Writes src/episode2/assets/town/sign_<WORD>.png (1024 wide).
Never a DIAMONDS sign in Episode 2 (ep2-fort-knox-arc rule 4).

    python3 tools/ep2_forge/paint_town_signs.py
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path("src/episode2/assets/town")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
WORDS = {"CERTIFICATES": "CERTIFICATES", "SALOON": "SALOON", "TREASURY": "TREASURY", "GENERAL": "GENERAL STORE", "HOTEL": "HOTEL",
         "ASSAY": "ASSAY OFFICE", "AUCTIONS": "AUCTIONS", "STATS": "STATS", "RESERVE": "RESERVE", "FORTKNOX": "FORT KNOX"}


def board(text, w=1024, h=180, seed=0):
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
    font = ImageFont.truetype(FONT, size)
    while d.textlength(text, font=font) > w - 90 and size > 40:
        size -= 4
        font = ImageFont.truetype(FONT, size)
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


OUT.mkdir(parents=True, exist_ok=True)
for i, (key, text) in enumerate(WORDS.items()):
    board(text, seed=i).save(OUT / f"sign_{key}.png")
    print("sign", key)
