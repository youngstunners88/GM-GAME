"""Paint the GoldMine town's wanted posters (skill ep2-wanted-posters).

    uv run --with pillow --with numpy python3 tools/ep2_forge/paint_wanted_posters.py --busts <dir with bust_*.png> --out src/episode2/extras/town/posters

Every poster is a 640 x 880 period hand-bill: aged, stained, creased paper; wood-type lettering (OFL faces in tools/ep2_forge/fonts);
a line-engraved portrait made from a REAL game model's bust (tools/ep2_forge/render_poster_bust.py), or a hatched woodcut silhouette
where the outlaw has no face in the game. Deterministic (seeded), so a rebuild gives the same posters.

Wording rules (ep2-jack-hammer-narrative / ep2-jailhouse): no digits, no "$", no tickers, no protocol numbers; Jack Hammer's bounty is
"paid in gold"; the accomplice has no name yet (the founder's call), so he is "name unknown" with a CAPTURED stamp - he is in the cell.
"""
import argparse
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

W, H = 640, 880
INK = (38, 27, 19)
RED = (150, 32, 24)
FONTS = Path(__file__).resolve().parent / "fonts"


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


WOOD = "HoltwoodOneSC-Regular.ttf"      # heavy wood type: WANTED, names
RYE = "Rye-Regular.ttf"                  # western display: DEAD OR ALIVE, REWARD
SERIF = "OldStandard-Regular.ttf"        # body text
SERIF_B = "OldStandard-Bold.ttf"
SERIF_I = "OldStandard-Italic.ttf"


# ---------------------------------------------------------------------------------------------------------------- paper
def paper(seed):
    rng = np.random.default_rng(seed)
    base = np.zeros((H, W, 3), np.float32)
    base[:] = (222, 200, 152)
    # fibre noise at two scales
    n1 = rng.normal(0, 1, (H // 4, W // 4)).astype(np.float32)
    n1 = np.array(Image.fromarray(n1).resize((W, H), Image.BICUBIC))
    n2 = rng.normal(0, 1, (H, W)).astype(np.float32)
    base += (n1 * 7.0 + n2 * 4.0)[..., None]
    # water stains and foxing: blurred blobs, darker brown at their rims
    stain = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(stain)
    for _ in range(9):
        cx, cy = rng.integers(0, W), rng.integers(0, H)
        r = rng.integers(25, 120)
        d.ellipse((cx - r, cy - r, cx + r, cy + int(r * rng.uniform(0.6, 1.2))), fill=int(rng.integers(30, 90)))
    for _ in range(40):
        cx, cy = rng.integers(0, W), rng.integers(0, H)
        r = rng.integers(2, 7)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=int(rng.integers(60, 140)))
    st = np.array(stain.filter(ImageFilter.GaussianBlur(9)), np.float32) / 255.0
    base -= st[..., None] * np.array([38, 44, 52], np.float32)
    # edges burned darker (vignette), sun-yellowed toward the top
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    ex = np.minimum(xx, W - 1 - xx) / (W * 0.5)
    ey = np.minimum(yy, H - 1 - yy) / (H * 0.5)
    edge = np.clip(1.0 - np.minimum(ex, ey) * 7.0, 0, 1) ** 1.6
    base -= edge[..., None] * np.array([70, 74, 70], np.float32)
    base += ((1.0 - yy / H) * 6.0)[..., None] * np.array([1.0, 0.6, -0.8], np.float32)
    # two fold creases (a quarter fold): a light ridge and a shadow line
    for fx in (W // 2 + int(rng.integers(-12, 12)),):
        base[:, fx - 1:fx + 1] -= 26
        base[:, fx + 1:fx + 3] += 10
    for fy in (H // 2 + int(rng.integers(-20, 20)),):
        base[fy - 1:fy + 1, :] -= 22
        base[fy + 1:fy + 3, :] += 8
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8))


def wear_ink(layer, seed):
    """Break up the ink like worn wood type on rough paper: drop random specks out of the solid letters."""
    rng = np.random.default_rng(seed + 7)
    a = np.array(layer.split()[-1], np.float32)
    holes = rng.random(a.shape) < 0.06
    blot = np.array(Image.fromarray((holes * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255.0
    a *= np.clip(1.0 - blot * 1.6, 0.0, 1.0)
    layer.putalpha(Image.fromarray(a.astype(np.uint8)))
    return layer


# ---------------------------------------------------------------------------------------------------------------- engraving
def engrave(bust_rgba, size):
    """A colour render -> a line-engraved portrait (ink alpha). Line screens at 45 and -45 degrees whose widths follow the shadow,
    a third finer screen in the deepest shadow, and contour lines from the edges."""
    im = bust_rgba.convert("RGBA")
    bbox = im.split()[-1].getbbox()
    if bbox:
        im = im.crop(bbox)
    im = ImageOps.contain(im, size, Image.LANCZOS)
    canvas = Image.new("RGBA", size, (255, 255, 255, 0))
    canvas.paste(im, ((size[0] - im.width) // 2, size[1] - im.height), im)
    alpha = np.array(canvas.split()[-1], np.float32) / 255.0
    grey = canvas.convert("L")
    mask = Image.fromarray(((alpha > 0.05) * 255).astype(np.uint8))
    lum = np.array(ImageOps.equalize(grey, mask=mask), np.float32) / 255.0
    lum = np.where(alpha > 0.05, lum, 1.0)
    dark = np.clip(1.0 - lum, 0, 1) ** 1.45 * 0.92        # engravings keep the lights open: paper shows through the face
    h, w = dark.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    period = 5.0

    def screen(u, k):
        ph = (u % period) / period
        return np.abs(ph - 0.5) * 2.0 < k

    ink = screen(xx + yy, dark * 0.95)                                   # main hatch follows tone
    ink |= screen(xx - yy + 2.0, np.clip(dark - 0.45, 0, 1) * 1.6)       # cross hatch in the shadows
    ink |= screen(yy * 1.0, np.clip(dark - 0.78, 0, 1) * 3.0)            # deepest shadow fills in
    edges = np.array(canvas.convert("L").filter(ImageFilter.FIND_EDGES), np.float32) / 255.0
    ink |= (edges > 0.28) & (alpha > 0.3)
    sil = np.array(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES), np.float32) / 255.0
    ink |= sil > 0.35
    a = (ink & (alpha > 0.05)).astype(np.float32)
    a = np.array(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.45)), np.uint8)
    out = Image.new("RGBA", size, INK + (0,))
    out.putalpha(Image.fromarray(a))
    return out


def masked_rider(size, seed):
    """A hatched woodcut silhouette of a masked rider (hat, bandana) for an outlaw with no face in the game."""
    w, h = size
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    cx = w // 2
    d.ellipse((cx - w * 0.17, h * 0.22, cx + w * 0.17, h * 0.62), fill=255)                        # head
    d.ellipse((cx - w * 0.40, h * 0.20, cx + w * 0.40, h * 0.30), fill=255)                        # brim
    d.rounded_rectangle((cx - w * 0.19, h * 0.02, cx + w * 0.19, h * 0.25), radius=int(w * 0.07), fill=255)   # crown
    d.polygon([(cx - w * 0.46, h), (cx - w * 0.30, h * 0.70), (cx - w * 0.08, h * 0.62), (cx + w * 0.08, h * 0.62),
               (cx + w * 0.30, h * 0.70), (cx + w * 0.46, h)], fill=255)                            # shoulders
    alpha = np.array(m, np.float32) / 255.0
    # tone: the bandana and hat band lighter (paper shows through), everything else dark
    yy0, xx0 = np.mgrid[0:h, 0:w].astype(np.float32)
    tone = 0.62 + 0.36 * (xx0 / w) + 0.10 * (yy0 / h)        # lit from the upper left
    lm = Image.new("L", size, 0)
    ld = ImageDraw.Draw(lm)
    ld.polygon([(cx - w * 0.18, h * 0.43), (cx + w * 0.18, h * 0.43), (cx, h * 0.66)], fill=255)       # bandana
    ld.rectangle((cx - w * 0.19, h * 0.19, cx + w * 0.19, h * 0.23), fill=255)                       # hat band
    ld.ellipse((cx - w * 0.11, h * 0.36, cx - w * 0.04, h * 0.40), fill=180)                        # eyes catch light
    ld.ellipse((cx + w * 0.04, h * 0.36, cx + w * 0.11, h * 0.40), fill=180)
    tone -= np.array(lm, np.float32) / 255.0 * 0.62
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ph = ((xx + yy) % 5.0) / 5.0
    ink = (np.abs(ph - 0.5) * 2.0 < tone) & (alpha > 0.5)
    sil = np.array(m.filter(ImageFilter.FIND_EDGES), np.float32) > 60
    ink |= sil
    out = Image.new("RGBA", size, INK + (0,))
    out.putalpha(Image.fromarray((ink * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.45)))
    return out


# ---------------------------------------------------------------------------------------------------------------- layout
def text_layer():
    return Image.new("RGBA", (W, H), INK + (0,))


def centred(d, y, text, f, fill=INK, spread=0):
    if spread:
        text = (" " * spread).join(text)
    tw = d.textlength(text, font=f)
    d.text(((W - tw) / 2, y), text, font=f, fill=fill)
    bb = d.textbbox(((W - tw) / 2, y), text, font=f)
    return bb[3]


def fit(d, text, name, max_w, start):
    s = start
    while s > 10 and d.textlength(text, font=font(name, s)) > max_w:
        s -= 2
    return font(name, s)


def rule(d, y, w=420, thick=3):
    d.rectangle(((W - w) / 2, y, (W + w) / 2, y + thick), fill=INK)
    d.rectangle(((W - w) / 2 + 30, y + thick + 3, (W + w) / 2 - 30, y + thick + 4), fill=INK)


def border(d):
    d.rectangle((22, 22, W - 23, H - 23), outline=INK, width=4)
    d.rectangle((32, 32, W - 33, H - 33), outline=INK, width=1)
    for (x, y) in ((22, 22), (W - 23, 22), (22, H - 23), (W - 23, H - 23)):
        d.ellipse((x - 9, y - 9, x + 9, y + 9), outline=INK, width=3)


def stamp(img, text, seed):
    """A red rubber stamp across the poster, rotated, with worn ink."""
    st = Image.new("RGBA", (W, 200), RED + (0,))
    d = ImageDraw.Draw(st)
    f = font(WOOD, 92)
    tw = d.textlength(text, font=f)
    d.rounded_rectangle(((W - tw) / 2 - 26, 20, (W + tw) / 2 + 26, 178), radius=18, outline=RED + (230,), width=10)
    d.text(((W - tw) / 2, 36), text, font=f, fill=RED + (230,))
    st = wear_ink(st, seed + 101)
    st = st.rotate(-18, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(st, ((W - st.width) // 2, int(H * 0.47) - st.height // 2))


def nail_holes(img, seed):
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    for (x, y) in ((W // 2 + rng.randint(-8, 8), 14), (14 + rng.randint(0, 4), H // 2), (W - 16, H - 18)):
        d.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(40, 30, 22, 255))
        d.ellipse((x - 9, y - 9, x + 9, y + 9), outline=(120, 92, 60, 120), width=2)


def poster(spec, busts, seed):
    img = paper(seed).convert("RGBA")
    ink = text_layer()
    d = ImageDraw.Draw(ink)
    border(d)
    y = 46
    y = centred(d, y, "WANTED", fit(d, "WANTED", WOOD, 548, 112)) + 6
    if spec.get("sub"):
        y = centred(d, y, spec["sub"], fit(d, spec["sub"], RYE, 520, 46)) + 12
    rule(d, y)
    y += 18
    box = tuple(spec.get("box", (360, 305)))
    portrait_y = y
    if spec.get("bust") and (busts / spec["bust"]).exists():
        eng = engrave(Image.open(busts / spec["bust"]), box)
        frame = (int((W - box[0]) / 2) - 8, portrait_y - 6, int((W + box[0]) / 2) + 8, portrait_y + box[1] + 6)
        d.rectangle(frame, outline=INK, width=3)
        ink.alpha_composite(eng, ((W - box[0]) // 2, portrait_y))
        y = portrait_y + box[1] + 16
    elif spec.get("rider"):
        sil = masked_rider((300, 300), seed)
        ink.alpha_composite(sil, ((W - 300) // 2 - 70, portrait_y + 10))
        sil2 = masked_rider((260, 260), seed + 1)
        ink.alpha_composite(sil2, ((W - 260) // 2 + 90, portrait_y + 50))
        y = portrait_y + 330
    else:
        y += 10
    for line in spec["lines"]:
        kind, txt = line
        if kind == "name":
            y = centred(d, y, txt, fit(d, txt, WOOD, 560, 64)) + 4
        elif kind == "alias":
            y = centred(d, y, txt, fit(d, txt, SERIF_I, 520, 30)) + 6
        elif kind == "body":
            y = centred(d, y, txt, fit(d, txt, SERIF_B, 540, 26)) + 4
        elif kind == "rule":
            rule(d, y + 6, 360, 2)
            y += 20
        elif kind == "reward":
            y = centred(d, y + 2, txt, fit(d, txt, RYE, 540, 58)) + 2
        elif kind == "small":
            y = centred(d, y, txt, fit(d, txt, SERIF, 520, 22)) + 2
    wear_ink(ink, seed)
    img.alpha_composite(ink)
    if spec.get("stamp"):
        stamp(img, spec["stamp"], seed)
    nail_holes(img, seed)
    # print soaks into the paper: multiply a touch of the paper grain back over the ink
    out = img.convert("RGB")
    grain = paper(seed + 3).convert("L").point(lambda v: 255 - (255 - v) // 5)
    out = ImageChops.multiply(out, Image.merge("RGB", (grain, grain, grain)))
    return out


SPECS = [
    {"id": "jack_hammer", "bust": "bust_jack_hammer.png", "sub": "DEAD OR ALIVE", "lines": [
        ("name", "JACK HAMMER"), ("alias", "alias Jackson Mccree"), ("rule", ""),
        ("body", "ONE EYE. MEAN AS A RATTLER."), ("body", "WANTED IN EVERY CAMP OF THE TERRITORY"),
        ("reward", "REWARD"), ("body", "PAID IN GOLD"), ("small", "Apply to the Sheriff, GoldMine")]},
    {"id": "accomplice", "bust": "bust_prisoner_accomplice.png", "sub": "FOR QUESTIONING", "stamp": "CAPTURED", "lines": [
        ("name", "NAME UNKNOWN"), ("alias", "seen riding with the bear men"), ("rule", ""),
        ("body", "CURLY HAIR. SOFT HANDS. TALKS PLENTY."), ("reward", "REWARD"), ("body", "PAID ON DELIVERY TO THE JAIL"),
        ("small", "Apply to the Sheriff, GoldMine")]},
    {"id": "masked_riders", "rider": True, "sub": "STAGE ROBBERS", "lines": [
        ("name", "THE MASKED RIDERS"), ("alias", "two men, bandanas, rode north"), ("rule", ""),
        ("body", "STOPPED THE ASSAY STAGE AT THE DRY WASH"), ("reward", "LIBERAL REWARD"),
        ("small", "Information to the Sheriff, GoldMine")]},
    {"id": "horse_thieves", "bust": "bust_horse.png", "box": (440, 300), "sub": "HORSE THIEVES", "lines": [
        ("name", "STOLEN"), ("body", "FROM THE LIVERY ON MAIN STREET"), ("rule", ""),
        ("body", "A BAY MARE, WHITE BLAZE, SHOD ALL ROUND"), ("body", "A SORREL GELDING, BRANDED GM"),
        ("reward", "REWARD"), ("body", "FOR THE HORSES AND THE THIEVES"), ("small", "Apply to the Sheriff, GoldMine")]},
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--busts", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    for i, spec in enumerate(SPECS):
        im = poster(spec, Path(a.busts), 1000 + i * 37)
        p = out / ("poster_%s.jpg" % spec["id"])
        im.save(p, quality=86, optimize=True)
        print("@@", p, p.stat().st_size)


if __name__ == "__main__":
    main()
