"""Draw the Big Axe pickup so it is not the pickaxe again.

STAGE 3 CLARITY BUG. Founder, about Stage 3: "the design is still shitty",
"remove the clutter", "if a prop is unclear, remove it rather than invent lore
for it".

One concrete instance of "unclear" that survived every previous pass:
big_axe.tscn and pickaxe_tool.tscn both point at
`sprite_item_pickaxe.png`. Level 3 spawns BOTH — one `pickaxe_tool` and one
`big_axe` — so the stage contains two power-ups that are pixel-identical on
screen and do completely different things. A player has no way to tell which
one they just walked into, and the second one reads as a duplicate of the
first, i.e. as clutter.

The Big Axe is a power-up the founder explicitly likes and asked to keep (it
got its own timer last pass), so the fix is to CLARIFY it, not cut it: a
proper broad double-bladed felling axe, bigger than the pickaxe (44px vs 34px
tall), with a warm gold sheen on the steel so it reads as the upgraded tool at
a glance.

Supersampled 8x and box-filtered so the bevels stay clean at game scale.
"""
from PIL import Image, ImageDraw

W_PX, H_PX, SS = 40, 44, 8
W, H = W_PX * SS, H_PX * SS
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

HAFT_HI = (156, 106, 58, 255)
HAFT    = (118, 76, 38, 255)
HAFT_LO = (78, 48, 22, 255)
STEEL   = (214, 220, 232, 255)
STEEL_HI = (248, 250, 255, 255)
STEEL_LO = (132, 142, 162, 255)
GOLD    = (226, 176, 62, 255)
GOLD_LO = (162, 118, 30, 255)


def u(v):
    return v * SS


# --- Haft: a straight handle down the middle, with a lit edge on the left so
# the axe has a light direction instead of reading as a flat silhouette.
cx = W / 2.0
d.polygon([(cx - u(3.0), u(8.0)), (cx + u(3.0), u(8.0)),
           (cx + u(2.4), H - u(1.0)), (cx - u(2.4), H - u(1.0))], fill=HAFT)
d.polygon([(cx - u(3.0), u(8.0)), (cx - u(1.4), u(8.0)),
           (cx - u(1.0), H - u(1.0)), (cx - u(2.4), H - u(1.0))], fill=HAFT_HI)
d.polygon([(cx + u(1.4), u(8.0)), (cx + u(3.0), u(8.0)),
           (cx + u(2.4), H - u(1.0)), (cx + u(1.2), H - u(1.0))], fill=HAFT_LO)
# Grip wrap at the base — the detail that says "tool", not "stick".
for gy in (H - u(9.0), H - u(6.0), H - u(3.0)):
    d.rectangle((cx - u(2.9), gy, cx + u(2.9), gy + u(1.3)), fill=HAFT_LO)

# --- Head: TWO bits, one each side. A double-bladed felling axe is the
# clearest possible silhouette contrast against the single-spike pickaxe.
for side in (-1, 1):
    # Bit body — a broad crescent flaring out from the haft to the edge.
    d.polygon([
        (cx + side * u(2.0), u(3.0)),
        (cx + side * u(15.5), u(6.0)),
        (cx + side * u(17.5), u(12.0)),
        (cx + side * u(15.5), u(18.0)),
        (cx + side * u(2.0), u(21.0)),
    ], fill=STEEL)
    # Cutting edge highlight along the outer arc.
    d.polygon([
        (cx + side * u(15.5), u(6.0)),
        (cx + side * u(17.5), u(12.0)),
        (cx + side * u(15.5), u(18.0)),
        (cx + side * u(13.8), u(16.6)),
        (cx + side * u(15.4), u(12.0)),
        (cx + side * u(13.8), u(7.4)),
    ], fill=STEEL_HI)
    # Shadowed cheek nearest the haft, so the head has thickness.
    d.polygon([
        (cx + side * u(2.0), u(3.0)),
        (cx + side * u(7.0), u(4.2)),
        (cx + side * u(7.0), u(19.8)),
        (cx + side * u(2.0), u(21.0)),
    ], fill=STEEL_LO)

# --- Gold collar binding the head to the haft. This is the GoldMine stage;
# the warm band is also what separates it from the cold grey pickaxe at a
# glance, which is the entire point of this sprite existing.
d.rectangle((cx - u(4.6), u(6.4), cx + u(4.6), u(11.0)), fill=GOLD)
d.rectangle((cx - u(4.6), u(11.0), cx + u(4.6), u(13.2)), fill=GOLD_LO)
d.rectangle((cx - u(4.6), u(15.0), cx + u(4.6), u(18.4)), fill=GOLD)
d.rectangle((cx - u(4.6), u(18.4), cx + u(4.6), u(19.8)), fill=GOLD_LO)

out = img.resize((W_PX, H_PX), Image.LANCZOS)
out.save("src/assets/sprites/sprite_item_bigaxe.png")
print("wrote src/assets/sprites/sprite_item_bigaxe.png", out.size)
