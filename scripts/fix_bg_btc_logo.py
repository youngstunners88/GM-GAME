#!/usr/bin/env python3
"""Repaint the mangled Bitcoin coin baked into the Stage 3 background art.

FOUNDER, 20+ TIMES: "Fix this BTC logo for goodness sake."

Why every previous fix missed it: the coin the founder circles is NOT a game
object. It is painted into src/assets/backgrounds/bg_l3_goldrush.jpg, so every
session that "fixed the BTC logo" was editing the collectible SPRITE while the
broken glyph sat untouched in the background image. The baked coin carries a
garbled, disconnected B that reads as noise at gameplay size.

This composites a correct Bitcoin mark over that one coin, matched to its
measured position and radius, and leaves the surrounding orange glow and the
rest of the painting alone. The large coin over the sun is deliberately NOT
touched: the founder explicitly approved that view ("you brought back the sun
as it was before").

Usage: python3 scripts/fix_bg_btc_logo.py
"""
from PIL import Image
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
BG = ROOT / "src" / "assets" / "backgrounds" / "bg_l3_goldrush.jpg"

sys.path.insert(0, str(ROOT / "scripts"))
from gen_btc_logo import make  # noqa: E402  — same geometric mark the sprites use

# Measured from the art itself (bright-gold blob detection), not eyeballed.
# Radius carries a 3px margin over the measured blob (x 1127-1190,
# y 286-345) so no sliver of the old mangled coin survives at the edge.
COIN_CENTER = (1159, 316)
COIN_RADIUS = 35


def main() -> int:
    bg = Image.open(BG).convert("RGB")
    d = COIN_RADIUS * 2
    logo = make(d)  # RGBA, official orange disc + white rotated B

    cx, cy = COIN_CENTER
    bg.paste(logo, (cx - COIN_RADIUS, cy - COIN_RADIUS), logo)

    # Re-save at high quality; this is a background plate, banding shows.
    bg.save(BG, quality=95, subsampling=0)
    print(f"  -> repainted BTC coin at {COIN_CENTER} r={COIN_RADIUS} in {BG.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
