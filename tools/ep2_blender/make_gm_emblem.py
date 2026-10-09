"""Build the CLEAR rifle emblem textures from the founder's GM logo (PIL + numpy only, no Blender).

    python3 -I tools/ep2_blender/make_gm_emblem.py <GOLD_LOGO.png> <out_dir> [--src-only]

Why: the full logo (thin chain ring, small lettering, soft dark disc) turned to mud at ~100 px on the receiver plate
(founder 2026-10-09 "how unclear the logo is"). This version crops TIGHT to the pickaxe + G + M + mountain so they fill
the disc, lifts the gold, deepens the enamel behind it, thickens the neon-green outline into a glow, and replaces the
illegible chain with a thick gold bezel. Writes emblem_color.png (RGBA, opaque disc), emblem_emit.png (RGB).
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

SRC, OUT = sys.argv[1], sys.argv[2]
if "--classic" in sys.argv:
    # CLASSIC (founder 2026-10-09, seeing the Blender hero render rifle_v3_threequarter.png: "look how beautiful and clear that is"):
    # the founder's logo AS DESIGNED - gold chain ring, gold lettering, restrained neon - cut to a circle, gold gently lifted.
    NN = 512
    im = Image.open(SRC).convert("RGB")
    CX, CY, R = 512, 452, 372
    c = im.crop((CX - R, CY - R, CX + R, CY + R)).resize((NN, NN), Image.LANCZOS)
    a = np.asarray(c).astype(np.float32) / 255.0
    a = np.clip(a ** 0.9 * 1.08, 0, 1)
    yy, xx = np.mgrid[0:NN, 0:NN].astype(np.float32)
    rr = np.sqrt((xx - NN / 2) ** 2 + (yy - NN / 2) ** 2)
    alpha = np.clip((NN / 2 - 1 - rr), 0, 1)
    gr = np.clip((a[..., 1] - np.maximum(a[..., 0] * 1.2, a[..., 2]) - 0.05) / 0.3, 0, 1)      # neon-green pixels only
    emit = a * gr[..., None] * 1.0
    Image.fromarray((np.dstack([a, alpha]) * 255).astype(np.uint8), "RGBA").save(OUT + "/emblem_color.png", optimize=True)
    Image.fromarray((np.clip(emit, 0, 1) * 255).astype(np.uint8)).save(OUT + "/emblem_emit.png", optimize=True)
    print("classic emblem written", OUT); sys.exit(0)
N = 384                                       # 384 px is plenty for ~150 px on screen and keeps the web pack small
K = N / 512.0
img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32) / 255.0
H, W, _ = img.shape
# the emblem's inner disc: centre and radius measured on the 1024 logo (chain ring is outside r ~ 300)
CX, CY, R_IN = 512, 452, 300
box = (CX - R_IN, CY - R_IN, CX + R_IN, CY + R_IN)
crop = Image.fromarray((img * 255).astype(np.uint8)).crop(box)
EMB_R = int(212 * K)                                   # px radius the inner disc occupies in the final 512 texture
crop = crop.resize((2 * EMB_R, 2 * EMB_R), Image.LANCZOS)
a = np.asarray(crop).astype(np.float32) / 255.0
r_, g_, b_ = a[..., 0], a[..., 1], a[..., 2]
val = a.max(-1)
sat = (a.max(-1) - a.min(-1)) / (a.max(-1) + 1e-5)
# the chain ring's lower arc leaks into the crop (thin links = mud at game size): erase it, keep the pickaxe handle's end
_h, _w = val.shape
_py, _px = np.mgrid[0:_h, 0:_w].astype(np.float32)
_dx = (_px - _w / 2) / (_w / 2) * R_IN
_dy = (_py - _h / 2) / (_h / 2) * R_IN
_lr = np.sqrt(_dx ** 2 + _dy ** 2)
chain = (_lr > 236) & (_dy > 100) & ~((_dx > 8) & (_dx < 125) & (_dy > 70))
green = np.clip((g_ - r_ * 1.15 - 0.04) / 0.30, 0, 1)                    # neon outline mask
gold = np.clip((r_ - b_ - 0.10) / 0.35, 0, 1) * np.clip((val - 0.30) / 0.25, 0, 1) * (1.0 - green)
gold = np.where(chain, 0.0, gold)
green = np.where(chain, 0.0, green)
# thicken + glow the neon outline
gm = Image.fromarray((green * 255).astype(np.uint8))
thick = np.maximum(green, np.asarray(gm.filter(ImageFilter.MaxFilter(5 if K > 0.9 else 3))).astype(np.float32) / 255.0)
glow = np.asarray(gm.filter(ImageFilter.GaussianBlur(5 * K))).astype(np.float32) / 255.0
# colour: enamel behind, gold lifted (gamma + saturation), green outline pushed to pure neon
enamel = np.array([0.020, 0.045, 0.030], np.float32)
gold_rgb = np.clip(a ** 0.82 * np.array([1.18, 1.08, 0.80], np.float32), 0, 1)
rgb = enamel[None, None, :] + 0 * a
rgb = rgb * (1 - gold[..., None]) + gold_rgb * gold[..., None]
neon = np.array([0.20, 1.0, 0.10], np.float32)
rgb = rgb * (1 - thick[..., None]) + neon * thick[..., None]
rgb = np.clip(rgb + glow[..., None] * neon * 0.35, 0, 1)
emit_in = np.clip(gold[..., None] * gold_rgb * 0.40 + (thick[..., None] * 1.0 + glow[..., None] * 0.5) * neon, 0, 1)

canvas = np.zeros((N, N, 4), np.float32)
emit = np.zeros((N, N, 3), np.float32)
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
c0 = N / 2.0
rr = np.sqrt((xx - c0) ** 2 + (yy - c0) ** 2)
# emblem disc (inner)
o = c0 - EMB_R
ix0, iy0 = int(o), int(o)
inner = rr < EMB_R + 1
canvas[iy0:iy0 + 2 * EMB_R, ix0:ix0 + 2 * EMB_R, :3] = rgb
emit[iy0:iy0 + 2 * EMB_R, ix0:ix0 + 2 * EMB_R] = emit_in
canvas[rr >= EMB_R, :3] = 0
emit[rr >= EMB_R] = 0
# gold bezel: r 212..250, brushed highlight sweeping round, dark groove inside and a thin dark rim outside
ang = np.arctan2(yy - c0, xx - c0)
shade = 0.70 + 0.30 * np.cos(ang + 0.9) + 0.08 * np.cos(6 * ang)
bez = (rr >= EMB_R) & (rr < 250 * K)
gold_base = np.array([0.95, 0.70, 0.20], np.float32)
for ch in range(3):
    canvas[..., ch] = np.where(bez, np.clip(gold_base[ch] * shade, 0, 1), canvas[..., ch])
    emit[..., ch] = np.where(bez, gold_base[ch] * 0.16, emit[..., ch])
groove = (rr >= EMB_R) & (rr < EMB_R + 5 * K)
rim = (rr >= 244 * K) & (rr < 250 * K)
for ch in range(3):
    canvas[..., ch] = np.where(groove, 0.05, canvas[..., ch])
    canvas[..., ch] = np.where(rim, canvas[..., ch] * 0.55, canvas[..., ch])
    emit[..., ch] = np.where(groove | rim, 0.0, emit[..., ch])
canvas[..., 3] = np.clip((250.5 * K - rr), 0, 1)                      # hard circle (1 px antialias); the shader uses a CLIP mask
Image.fromarray((canvas * 255).astype(np.uint8), "RGBA").save(OUT + "/emblem_color.png", optimize=True)
Image.fromarray((np.clip(emit, 0, 1) * 255).astype(np.uint8)).save(OUT + "/emblem_emit.png", optimize=True)
print("emblem written", OUT)
