#!/usr/bin/env python3
"""Painted Warcraft-style overworld maps for the three Protocol Portal tours (MuAPI Flux).
Founder refs: docs/founder_briefs/2026-09-28 (image4 = the overhead fantasy-map style anchor).
Usage: gen_portal_maps.py <out_dir> [variants]"""
import sys, pathlib
sys.path.insert(0, "scripts")
from generate_art import generate
STYLE = ("high-angle three-quarter overhead view of a detailed painted fantasy RTS game map, "
         "Warcraft III / World of Warcraft overworld style, hand-painted textures, dense detail, "
         "rich lighting, a clear winding dirt road running left to right across the lower third "
         "for a hero to walk along, wide panoramic composition, no text, no letters, no UI, no characters")
MAPS = {
 "smoke": "SMOKE realm: a hazy smoky enchanted forest valley, drifting purple and green smoke, "
          "a hedge-maze garden, a glowing neon purple-green lounge pavilion, an ash-grey stone ring "
          "plaza, a mossy recycling well, giant leaves and glowing mushrooms, lanterns, twilight",
 "diamonds": "DIAMONDS realm: a crystalline citadel of cyan diamond spires on a dark stone plateau "
          "over black water, glowing green ring runes on the ground, a pressure press forge, "
          "a crystal mint gate arch, terraces and bridges, cyan and emerald glow, night",
 "gold": "GOLD MINE realm: a wild-west frontier gold rush mining town in a canyon, timber "
          "boardwalks, mine cart rails, piles of gold nuggets and coins, a steel vault with a "
          "clock tower, an assay office, lanterns, warm golden sunset dust",
}
out = pathlib.Path(sys.argv[1]); n = int(sys.argv[2]) if len(sys.argv) > 2 else 1
for proto, desc in MAPS.items():
    for v in range(n):
        png = generate(f"{desc}. {STYLE}", 1344, 576)
        if png: (out / f"{proto}_v{v}.png").write_bytes(png); print("ok", proto, v)
        else: print("FAIL", proto, v)
