"""Draw the wBTC pickup as a readable Bitcoin coin.

Founder, twice about the SAME object:
  * "Ive told you many times to remove these random orange rectangles that
     have no function!!!"  -> those ARE the wBTC pickups.
  * "This bitcoin symbol is still not clear!"

wbtc.gd drew the collectible as a bare 30x15 ColorRect in Bitcoin orange with
no symbol on it at all. At game scale that is an orange smear with no meaning,
which is exactly why he read it as functionless clutter.

This bakes a proper coin at the same 40px footprint the other protocol tokens
use: gold rim, orange body, and a bold white B with the two vertical strokes,
drawn as geometry (not a font) so it stays crisp and needs no font resource.
Supersampled 8x and box-filtered so the curve and the strokes stay clean.
"""
from PIL import Image, ImageDraw

S, SS = 40, 8
W = S * SS
img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

RIM_HI  = (255, 214, 102, 255)
RIM_LO  = (176, 120, 20, 255)
BODY    = (247, 147, 26, 255)   # Bitcoin orange
BODY_SH = (198, 106, 12, 255)
SYM     = (255, 255, 255, 255)

def u(v):
    return v * SS

# Outer rim, then a darker seat, then the body — reads as a struck coin.
d.ellipse((0, 0, W - 1, W - 1), fill=RIM_LO)
d.ellipse((u(1.2), u(1.2), W - 1 - u(1.2), W - 1 - u(1.2)), fill=RIM_HI)
d.ellipse((u(3.4), u(3.4), W - 1 - u(3.4), W - 1 - u(3.4)), fill=BODY_SH)
d.ellipse((u(4.2), u(3.6), W - 1 - u(4.6), W - 1 - u(5.0)), fill=BODY)

# --- The B, built from rectangles + two bowls, centred on the coin.
cx = W / 2.0
stem_x = u(14.5)
stem_w = u(4.2)
top_y, bot_y = u(11.0), u(29.0)
d.rectangle((stem_x, top_y, stem_x + stem_w, bot_y), fill=SYM)

def bowl(y0, y1, right):
    """One lobe of the B as a filled ring segment."""
    h = y1 - y0
    d.ellipse((stem_x + stem_w * 0.2, y0, right, y1), fill=SYM)
    inset = h * 0.28
    d.ellipse((stem_x + stem_w * 1.15, y0 + inset, right - inset * 1.15, y1 - inset),
              fill=BODY)
    # Square off the left side so the bowl meets the stem cleanly.
    d.rectangle((stem_x, y0, stem_x + stem_w, y1), fill=SYM)
    d.rectangle((stem_x + stem_w, y0 + inset, stem_x + stem_w + inset * 0.5, y1 - inset),
                fill=BODY)

bowl(top_y, u(20.2), u(26.0))
bowl(u(19.4), bot_y, u(27.4))

# The two vertical strokes through the B — the part that makes it read as ₿.
for sx in (u(15.6), u(20.4)):
    d.rectangle((sx, u(7.4), sx + u(2.6), u(11.6)), fill=SYM)
    d.rectangle((sx, u(28.4), sx + u(2.6), u(32.6)), fill=SYM)

out = img.resize((S, S), Image.BOX)
out.save("src/assets/sprites/sprite_item_wbtc.png")
a = out.split()[3]
print("wrote sprite_item_wbtc.png", out.size,
      "corner alpha:", [a.getpixel(p) for p in [(0,0),(S-1,0),(0,S-1),(S-1,S-1)]])
