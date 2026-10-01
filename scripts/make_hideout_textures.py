#!/usr/bin/env python3
"""Generates the two painted textures for Inferno Bull's hideout (design/ep2/INFERNO_BULL_HIDEOUT_design.md):
a vintage western pin-up poster (tasteful 1890s saloon-show style, red dress, fully clothed) and a cowhide rug.
Pure PIL, deterministic, no external art. Re-run to regenerate."""
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "src/episode2/assets/textures/"


def poster() -> None:
    w, h = 512, 768
    im = Image.new("RGB", (w, h), (226, 196, 140))
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    # aged paper blotches
    for _ in range(260):
        x, y, r = rnd.randrange(w), rnd.randrange(h), rnd.randrange(8, 40)
        c = rnd.randrange(-18, 10)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(226 + c, 196 + c, 140 + c))
    im = im.filter(ImageFilter.GaussianBlur(5))
    d = ImageDraw.Draw(im)
    # ornate double border
    d.rectangle((14, 14, w - 14, h - 14), outline=(90, 28, 22), width=6)
    d.rectangle((26, 26, w - 26, h - 26), outline=(150, 100, 40), width=3)
    # warm backdrop curtain
    d.rectangle((40, 100, w - 40, h - 150), fill=(120, 30, 34))
    for x in range(40, w - 40, 28):
        d.line((x, 100, x + 6, h - 150), fill=(96, 20, 26), width=5)
    # figure: seated, three-quarter pose, long red dress with slit, bare shoulders
    skin = (236, 190, 156)
    d.ellipse((205, 150, 285, 245), fill=skin)                       # head
    d.pieslice((190, 128, 305, 250), 180, 360, fill=(40, 22, 20))     # hair top
    d.ellipse((262, 160, 322, 300), fill=(40, 22, 20))               # hair falling over shoulder
    d.polygon([(215, 235), (275, 235), (300, 300), (190, 300)], fill=skin)   # neck + shoulders
    d.polygon([(190, 295), (300, 295), (320, 400), (180, 400)], fill=(196, 28, 36))   # bodice
    d.polygon([(180, 395), (320, 395), (400, 640), (110, 640)], fill=(176, 20, 30))   # skirt
    d.polygon([(250, 430), (330, 430), (420, 640), (300, 640)], fill=(214, 44, 52))   # skirt highlight
    d.polygon([(215, 470), (260, 470), (200, 640), (130, 640)], fill=skin)           # leg through the slit
    d.ellipse((120, 618, 215, 650), fill=(30, 18, 16))               # shoe
    d.line((196, 300, 150, 380), fill=skin, width=22)                # arm on hip
    d.line((296, 300, 330, 420), fill=skin, width=22)
    d.ellipse((205, 185, 215, 195), fill=(30, 20, 18))               # eyes
    d.ellipse((245, 185, 255, 195), fill=(30, 20, 18))
    d.arc((218, 205, 252, 230), 20, 160, fill=(190, 30, 40), width=5)  # smile
    # lettering (default bitmap font scaled up by drawing on a small layer)
    try:
        font = ImageFont.load_default(size=44)
        font2 = ImageFont.load_default(size=26)
    except TypeError:
        font = font2 = ImageFont.load_default()
    d.text((w // 2, 62), "MISS GOLDIE", fill=(90, 28, 22), font=font, anchor="mm")
    d.text((w // 2, h - 100), "THE FORT KNOX REVUE", fill=(90, 28, 22), font=font2, anchor="mm")
    d.text((w // 2, h - 62), "NIGHTLY  ~  ADMISSION IN GOLD", fill=(150, 100, 40), font=font2, anchor="mm")
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    im.save(OUT + "tex_pinup_poster.jpg", quality=88)


def cowhide() -> None:
    w = h = 512
    im = Image.new("RGB", (w, h), (232, 224, 208))
    d = ImageDraw.Draw(im)
    rnd = random.Random(11)
    for _ in range(26):
        cx, cy = rnd.randrange(w), rnd.randrange(h)
        pts = []
        for i in range(14):
            import math
            a = i / 14 * 2 * math.pi
            r = rnd.randrange(22, 62)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        d.polygon(pts, fill=(70, 38, 24) if rnd.random() < 0.8 else (30, 20, 16))
    im = im.filter(ImageFilter.GaussianBlur(3))
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = rnd.randrange(-9, 9)
            r, g, b = px[x, y]
            px[x, y] = (max(0, r + n), max(0, g + n), max(0, b + n))
    im.save(OUT + "tex_cowhide.jpg", quality=85)


if __name__ == "__main__":
    poster()
    cowhide()
    print("textures written")
