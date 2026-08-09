"""Redraw the Magic Mushroom pickup so it reads as a mushroom at game scale.

Founder (B5): the props "should read as magic mushrooms but do not... cap +
stem, not generic blobs."

The old 40x40 sprite was a pale, low-contrast cap with almost no stem, which at
the size it actually renders collapsed into a light smudge. This draws the
mushroom explicitly from its silhouette in: a WIDE domed cap that overhangs a
clearly separate stem, a dark keyline so the shape survives against both the
bright Smoke Realm canopy and the dark cavern, cream spots for the "magic"
read, and a flared base so it sits rather than floats.

Supersampled 8x and box-filtered down, which keeps the curve clean without the
blur a Gaussian would add at this size.
"""
from PIL import Image, ImageDraw, ImageFilter

S = 40
SS = 8
W = S * SS

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

OUTLINE = (38, 16, 44, 255)
CAP     = (214, 44, 96, 255)
CAP_HI  = (248, 104, 148, 255)
CAP_LO  = (156, 24, 74, 255)
SPOT    = (255, 238, 232, 255)
STEM    = (246, 232, 214, 255)
STEM_SH = (208, 186, 176, 255)
GILL    = (176, 132, 152, 255)

def u(v):  # 0..40 design units -> supersampled px
    return v * SS

# --- stem: slightly waisted, flared foot, drawn first so the cap overlaps it
# Wider than a literal reading of the reference would suggest: at 40px a
# 5px stem reads as a stick under a cap rather than part of the same object.
d.polygon([(u(15.2), u(20)), (u(24.8), u(20)),
           (u(27.0), u(33.5)), (u(13.0), u(33.5))], fill=OUTLINE)
d.polygon([(u(16.3), u(20.5)), (u(23.7), u(20.5)),
           (u(25.6), u(32.6)), (u(14.4), u(32.6))], fill=STEM)
# shaded right face gives the stem volume
d.polygon([(u(21.0), u(20.5)), (u(23.7), u(20.5)),
           (u(25.6), u(32.6)), (u(22.4), u(32.6))], fill=STEM_SH)

# --- cap: a wide dome that clearly OVERHANGS the stem (the silhouette cue
# that separates "mushroom" from "blob")
d.ellipse((u(3), u(6), u(37), u(24)), fill=OUTLINE)
d.ellipse((u(4.2), u(7.2), u(35.8), u(22.8)), fill=CAP)
# underside band, so the cap reads as a solid with a lit top
d.chord((u(4.2), u(7.2), u(35.8), u(22.8)), 12, 168, fill=CAP_LO)
# gills peeking under the overhang
d.chord((u(9), u(15.5), u(31), u(24.5)), 20, 160, fill=GILL)
# top highlight
d.chord((u(7.5), u(8.4), u(30), u(21)), 190, 350, fill=CAP_HI)

# --- spots: the "magic" read. Sized/placed to follow the dome's curve.
for cx, cy, r in [(12.0, 12.2, 3.0), (20.5, 10.2, 3.6), (28.4, 13.0, 2.7),
                  (16.2, 16.6, 2.1), (25.0, 17.2, 1.9)]:
    d.ellipse((u(cx - r), u(cy - r * 0.82), u(cx + r), u(cy + r * 0.82)), fill=SPOT)

out = img.resize((S, S), Image.BOX)

# Faint outer glow so it pops as a pickup without a halo ring.
glow = out.filter(ImageFilter.GaussianBlur(1.6))
glow_px = glow.load()
for y in range(S):
    for x in range(S):
        r, g, b, a = glow_px[x, y]
        glow_px[x, y] = (255, 150, 200, int(a * 0.30))
final = Image.alpha_composite(glow, out)

final.save("src/assets/sprites/sprite_item_mushroom.png")
a = final.split()[3]
print("wrote sprite_item_mushroom.png", final.size,
      "corner alpha:", [a.getpixel(p) for p in [(0,0),(S-1,0),(0,S-1),(S-1,S-1)]])
