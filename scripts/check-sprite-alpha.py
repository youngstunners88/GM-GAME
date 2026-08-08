#!/usr/bin/env python3
"""Fail if any transparent-intended sprite actually ships an opaque background.

WHY THIS EXISTS
An image model returned a PNG with NO alpha channel content at all: it had
PAINTED the grey "transparency" checkerboard as real pixels. The preview looked
correct, the trim step keyed off the alpha channel and therefore did nothing,
and the game shipped a flame-diamond obstacle rendered as a solid WHITE CARD
floating in mid-air. The founder saw it immediately; a one-command alpha check
would have caught it before the build.

This makes that class of mistake structurally impossible for generated art.
Hand-authored opaque textures (backgrounds, tilesets, key art) are exempt by
path — only sprites that are SUPPOSED to be cut out are checked.
"""
import sys, glob
from PIL import Image

# Sprites that must have a cut-out background. Backgrounds/logos/badges are
# deliberately opaque and are not listed.
PATTERNS = [
    "src/assets/sprites/fx_*.png",
    "src/assets/sprites/sprite_item_*.png",
    "src/assets/sprites/sprite_enemy_*.png",
]
EXEMPT = {"fx_dot.png"}  # a solid dot IS the asset

fails = []
checked = 0
for pat in PATTERNS:
    for f in sorted(glob.glob(pat)):
        name = f.rsplit("/", 1)[-1]
        if name in EXEMPT:
            continue
        im = Image.open(f).convert("RGBA")
        w, h = im.size
        px = im.load()
        checked += 1
        # All four corners opaque == no cut-out at all.
        corners = [px[0, 0], px[w-1, 0], px[0, h-1], px[w-1, h-1]]
        if all(c[3] > 200 for c in corners):
            fails.append(f"{f}: all 4 corners opaque (corner alpha "
                         f"{[c[3] for c in corners]}) — background was never removed")

print(f"sprite-alpha: checked {checked} sprite(s)")
for f in fails:
    print(f"  [FAIL] {f}")
if fails:
    print(f"SPRITE_ALPHA: {len(fails)} FAILURE(S)")
    sys.exit(1)
print("SPRITE_ALPHA: ALL PASS")
