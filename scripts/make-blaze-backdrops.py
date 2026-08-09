"""Build one Blaze Rush forest backdrop per realm.

Founder: "return the trees in the background of the Blaze Rush like before for
stage one as it had the theme of the 1st stage, and the theme of the 2nd Blaze
Rush background should align with the 2nd stage and same with the 3rd" -- and
explicitly NOT "a single tint of the main stage art", which is what the current
_build_stage_theme_layer does (it loads the level's own plate and modulates it).

`bg_blaze_rush_treeline.jpg` was already in the repo, referenced by nothing --
that is the "before" art. It is the base for all three, so every realm is the
SAME forest world. What differs per realm is done structurally, not with a
modulate:

  * a gradient MAP on luminance (not a multiply tint) re-paints the whole sky
    and canopy through that realm's ramp while keeping every branch and cloud
    edge intact;
  * each realm gets its own landmark silhouettes composited into the MIDDLE
    distance -- glowing mushroom caps (Smoke), crystal spires (Crystal), mesas
    and a low sun (Gold);
  * the near-black treeline is masked back over the top afterwards, so the
    landmarks sit BEHIND the front trees instead of pasted on the glass.

Output is 1280x720 to match the viewport and the other backdrop plates.
"""
import random
from PIL import Image, ImageDraw, ImageFilter

SRC = "src/assets/backgrounds/bg_blaze_rush_treeline.jpg"
W, H = 1280, 720

base = Image.open(SRC).convert("RGB").resize((W, H), Image.LANCZOS)
lum = base.convert("L")

# The near, almost-black treeline + ground. Everything darker than this in the
# lower two thirds is "in front" and gets re-laid over the landmarks.
near_mask = lum.point(lambda v: 255 if v < 46 else 0).convert("L")
cut = Image.new("L", (W, H), 0)
ImageDraw.Draw(cut).rectangle((0, int(H * 0.30), W, H), fill=255)
near_mask = Image.composite(near_mask, Image.new("L", (W, H), 0), cut)
near_mask = near_mask.filter(ImageFilter.MaxFilter(3))


def gradient_map(img_l, stops):
    """Re-paint by luminance through a colour ramp. Preserves all structure."""
    ramp = []
    for i in range(256):
        t = i / 255.0 * (len(stops) - 1)
        a = min(int(t), len(stops) - 2)
        f = t - a
        c0, c1 = stops[a], stops[a + 1]
        ramp.append(tuple(int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3)))
    out = Image.new("RGB", img_l.size)
    px = img_l.load()
    op = out.load()
    for y in range(img_l.size[1]):
        for x in range(img_l.size[0]):
            op[x, y] = ramp[px[x, y]]
    return out


def glow(draw_on, xy, r, colour, layers=5):
    """Soft additive-ish halo, drawn as stacked translucent discs."""
    ov = Image.new("RGBA", draw_on.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for i in range(layers, 0, -1):
        rr = r * i / layers
        a = int(38 * (1 - (i - 1) / layers))
        d.ellipse((xy[0] - rr, xy[1] - rr, xy[0] + rr, xy[1] + rr),
                  fill=(colour[0], colour[1], colour[2], a))
    draw_on.alpha_composite(ov)


# ---------------------------------------------------------------- SMOKE (L1)
def smoke_realm(img):
    """Stage 1: the mushroom forest. Closest to the source -- this is the
    'trees like before' the founder asked to have back."""
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    # Mid-distance mushrooms, echoing bg_l1_forest's pink glow.
    #
    # Founder (B5): these must READ as magic mushrooms, "cap + stem, not
    # generic blobs". The first cut was literally an ellipse with a 6px
    # rectangle under it, which at this distance is a blob on a stick. A
    # mushroom is legible from three cues, all of them added here: a cap that
    # OVERHANGS the stem, a darker underside so the cap reads as a solid, and
    # spots. The stem is also tapered and wider at the base so it plants.
    caps = [(165, 430, 58), (410, 452, 40), (700, 424, 50),
            (960, 446, 44), (1165, 418, 36)]
    for x, y, s in caps:
        st_top, st_bot = s * 0.20, s * 0.30
        d.polygon([(x - st_top, y), (x + st_top, y),
                   (x + st_bot, y + s * 1.05), (x - st_bot, y + s * 1.05)],
                  fill=(214, 178, 214, 232))
        # Cap: wider than the stem by design — that overhang IS the silhouette.
        d.ellipse((x - s, y - s * 0.66, x + s, y + s * 0.30), fill=(214, 74, 150, 238))
        # Lit crown over a darker underside band.
        d.chord((x - s, y - s * 0.66, x + s, y + s * 0.30), 180, 360,
                fill=(244, 116, 182, 240))
        d.chord((x - s * 0.92, y - s * 0.10, x + s * 0.92, y + s * 0.30), 10, 170,
                fill=(150, 40, 104, 235))
        for sx, sy, sr in [(-0.42, -0.30, 0.17), (0.06, -0.40, 0.20),
                           (0.48, -0.24, 0.14)]:
            d.ellipse((x + s * (sx - sr), y + s * (sy - sr * 0.8),
                       x + s * (sx + sr), y + s * (sy + sr * 0.8)),
                      fill=(255, 226, 244, 236))
    ov = ov.filter(ImageFilter.GaussianBlur(0.6))
    img.alpha_composite(ov)
    for x, y, s in caps:
        glow(img, (x, y), s * 2.4, (255, 120, 200))
    # Spore motes drifting in the canopy light.
    sp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sp)
    rng = random.Random(1101)
    for _ in range(70):
        x = rng.uniform(0, W)
        y = rng.uniform(190, 490)
        r = rng.uniform(1.0, 3.2)
        ds.ellipse((x - r, y - r, x + r, y + r), fill=(255, 190, 235, 120))
    img.alpha_composite(sp)
    return img


# -------------------------------------------------------------- CRYSTAL (L2)
def crystal_realm(img):
    """Stage 2: crystal spires pushing up through the treeline, cave-cyan sky."""
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    spires = [(150, 250, 300, 62), (300, 355, 250, 40), (620, 210, 330, 74),
              (760, 330, 245, 44), (1050, 265, 295, 58), (1210, 350, 235, 38)]
    for cx, top, height, half in spires:
        base_y = top + height
        body = [(cx - half, base_y), (cx - half * 0.82, top + height * 0.28),
                (cx, top), (cx + half * 0.82, top + height * 0.28),
                (cx + half, base_y)]
        d.polygon(body, fill=(58, 150, 208, 236))
        # Lit facet down one side gives the flat polygon a cut-gem read.
        d.polygon([(cx, top), (cx + half * 0.82, top + height * 0.28),
                   (cx + half, base_y), (cx + half * 0.28, base_y)],
                  fill=(126, 216, 246, 240))
        d.polygon([(cx, top), (cx - half * 0.34, top + height * 0.42),
                   (cx - half * 0.10, base_y), (cx + half * 0.10, base_y)],
                  fill=(196, 244, 255, 200))
    ov = ov.filter(ImageFilter.GaussianBlur(0.7))
    img.alpha_composite(ov)
    for cx, top, height, half in spires:
        glow(img, (cx, top + height * 0.42), half * 3.1, (110, 220, 255))
    return img


# ----------------------------------------------------------------- GOLD (L3)
def gold_realm(img):
    """Stage 3: canyon mesas and a low sun behind the treeline, amber sky."""
    glow(img, (640, 300), 340, (255, 196, 92), layers=7)
    ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    d.ellipse((640 - 132, 300 - 132, 640 + 132, 300 + 132), fill=(255, 214, 122, 245))
    # Flat-topped buttes, the Gold Rush silhouette language.
    #
    # The first pass sloped the sides in from the base corners, which at this
    # width/height ratio reads as a HOUSE ROOF, not a mesa. A butte is defined
    # by near-VERTICAL walls under a wide flat cap, with only a short talus
    # skirt at the bottom -- so the cap now spans most of the footprint and the
    # slope is confined to the lowest fifth. They also sit on the flanks now,
    # framing the sun rather than cutting across it.
    def butte(x, base_y, w, h):
        cap = w * 0.78                      # flat top, most of the width
        inset = (w - cap) / 2.0
        talus = h * 0.18                    # scree skirt, the only sloped part
        d.polygon([
            (x, base_y),
            (x + inset * 0.55, base_y - talus),
            (x + inset, base_y - talus * 1.15),
            (x + inset, base_y - h),        # vertical wall
            (x + inset + cap, base_y - h),  # flat cap
            (x + inset + cap, base_y - talus * 1.15),
            (x + w - inset * 0.55, base_y - talus),
            (x + w, base_y),
        ], fill=(40, 17, 20, 252))
        # Sunward wall catches a little light so the stack reads as rock.
        d.polygon([
            (x + inset + cap * 0.70, base_y - h),
            (x + inset + cap, base_y - h),
            (x + inset + cap, base_y - talus * 1.15),
            (x + inset + cap * 0.70, base_y - talus * 1.15),
        ], fill=(78, 35, 30, 250))
        # Cap rim, a touch lighter than the wall.
        d.polygon([
            (x + inset, base_y - h),
            (x + inset + cap, base_y - h),
            (x + inset + cap, base_y - h + h * 0.055),
            (x + inset, base_y - h + h * 0.055),
        ], fill=(92, 44, 34, 250))

    for mx, mbase, mw, mh in [(-70, 512, 300, 232), (150, 526, 230, 168),
                              (930, 520, 280, 216), (1170, 532, 240, 160)]:
        butte(mx, mbase, mw, mh)
    ov = ov.filter(ImageFilter.GaussianBlur(0.6))
    img.alpha_composite(ov)
    # Gold dust catching the low light.
    sp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sp)
    rng = random.Random(3303)
    for _ in range(90):
        x = rng.uniform(0, W)
        y = rng.uniform(210, 510)
        r = rng.uniform(1.0, 3.0)
        # Thin the dust close to the sun disc so it never reads as a ring
        # drawn around it.
        if ((x - 640) ** 2 + (y - 300) ** 2) ** 0.5 < 210 and rng.random() < 0.75:
            continue
        ds.ellipse((x - r, y - r, x + r, y + r), fill=(255, 226, 150, 130))
    img.alpha_composite(sp)
    return img


REALMS = [
    ("l1_smoke", [(14, 8, 32), (48, 20, 74), (108, 36, 128), (198, 62, 176), (246, 158, 226)], smoke_realm),
    ("l2_crystal", [(6, 12, 34), (14, 40, 82), (24, 92, 146), (68, 172, 214), (186, 240, 252)], crystal_realm),
    ("l3_gold", [(20, 10, 20), (66, 26, 34), (150, 62, 40), (232, 140, 52), (255, 216, 130)], gold_realm),
]

near_src = gradient_map(lum, [(0, 0, 0), (255, 255, 255)])  # placeholder, replaced per realm

for name, stops, decorate in REALMS:
    mapped = gradient_map(lum, stops).convert("RGBA")
    # Landmarks go in the middle distance...
    art = decorate(mapped.copy())
    # ...then the near treeline is laid back over them so they sit BEHIND it.
    near = gradient_map(lum, stops).convert("RGBA")
    art = Image.composite(near, art, near_mask)
    out = art.convert("RGB")
    path = "src/assets/backgrounds/bg_blaze_%s.jpg" % name
    out.save(path, quality=92)
    print("wrote", path, out.size)
