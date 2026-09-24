#!/usr/bin/env python3
"""Count smoke-bomb pixels in attack frames. The bomb is drawn from primitives,
so its colours are byte-exact: body (56,74,51), wrap (107,153,92), fuse
(255,184,77). A blob containing all three is the smoke bomb; nothing else in
the game carries that combination. Prints per-frame counts and a verdict."""
import sys, glob, numpy as np
from PIL import Image
BODY, WRAP, FUSE = (56,74,51), (107,153,92), (255,184,77)
d = sys.argv[1]
found = False
for f in sorted(glob.glob(f"{d}/r*_f*.png")):
    a = np.asarray(Image.open(f).convert("RGB")).reshape(-1,3)
    c = [int((a == np.array(k)).all(axis=1).sum()) for k in (BODY, WRAP, FUSE)]
    hit = c[0] > 40 and c[1] > 15 and c[2] > 3
    found |= hit
    print(f"{f.split('/')[-1]:14s} body={c[0]:4d} wrap={c[1]:4d} fuse={c[2]:3d} {'<- SMOKE BOMB' if hit else ''}")
print("VERDICT:", "SMOKE BOMB THROWN" if found else "NO SMOKE BOMB SEEN")
sys.exit(0 if found else 1)
