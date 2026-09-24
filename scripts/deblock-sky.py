#!/usr/bin/env python3
"""Remove JPEG 8x8 block/banding artifacts from the SMOOTH SKY of a plate while
leaving every detailed pixel (trees, sun, mountains, crystals) byte-identical.

Root cause measured 2026-09-22: blaze plates are JPEGs; their smooth sky
gradients carry 8x8 DCT block artifacts that read as the founder's fixed
"blotches" on bright scenes and vanish on the one dark scene (L2 Blaze) he
grades clean. block8_contrast tracks his matrix.

Non-negotiable, because the founder has rejected blurred backgrounds before:
this must not soften structure. So the smooth-sky mask is ERODED away from any
detail by a wide margin and NOT feathered into it; smoothing is applied only
where the mask is fully 1, and the script asserts the detailed regions are
untouched (max change there must be ~0) or it refuses to write.
"""
import sys, numpy as np, cv2
from PIL import Image

def local_std(lum):
    m = cv2.blur(lum, (9,9)); sq = cv2.blur(lum*lum, (9,9))
    return np.sqrt(np.clip(sq - m*m, 0, None))

def block8(x, H):
    L = x[:int(H*0.55)].astype(np.float32).mean(axis=2)
    col = np.abs(np.diff(L, axis=1)).mean(axis=0)
    ph = np.array([col[i::8].mean() for i in range(8)])
    return float(ph.max()/(ph.mean()+1e-6))

def deblock(inp, outp):
    im = Image.open(inp).convert('RGB')
    a = np.asarray(im).astype(np.float32); H, W, _ = a.shape
    std = local_std(a.mean(axis=2))
    # detail = anything with structure. Dilate it so a tree tip's neighbourhood
    # is protected too, then the sky mask is the complement, eroded further.
    detail = (std >= 4.0).astype(np.uint8)
    detail = cv2.dilate(detail, np.ones((9,9), np.uint8))
    sky = ((1 - detail).astype(np.uint8))
    sky = cv2.erode(sky, np.ones((9,9), np.uint8))            # hard margin, no feather
    maskf = sky.astype(np.float32)[..., None]
    # gentle low-pass ONLY inside the hard sky mask -> removes blocks/banding,
    # cannot reach any protected pixel because the mask is 0 there.
    smooth = cv2.GaussianBlur(a, (0,0), 4.0)
    out = a*(1.0-maskf) + smooth*maskf
    # +-0.5 LSB ordered dither in the sky only, so the gradient can't re-band.
    bayer = (np.indices((H,W)).sum(axis=0) % 2).astype(np.float32) - 0.5
    out += (bayer*maskf[...,0])[..., None]
    out = np.clip(out, 0, 255).astype(np.uint8)
    # SAFETY: detailed pixels must be untouched.
    prot = detail.astype(bool)
    chg = np.abs(a - out.astype(np.float32)).max(axis=2)
    dmax = float(chg[prot].max()) if prot.any() else 0.0
    if dmax > 1.5:
        raise SystemExit(f"REFUSED {inp}: detail changed by {dmax:.1f} (>1.5) — would soften structure")
    Image.fromarray(out).save(outp)
    treated = float(maskf.mean())*100
    print(f"{inp.split('/')[-1]}: treated {treated:.1f}%  block8 {block8(np.asarray(im),H):.3f} -> "
          f"{block8(out,H):.3f}  detail_max_change {dmax:.2f} (must be <=1.5)")

if __name__ == '__main__':
    deblock(sys.argv[1], sys.argv[2])
