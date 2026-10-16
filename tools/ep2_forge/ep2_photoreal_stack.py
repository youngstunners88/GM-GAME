#!/usr/bin/env python3
"""Ep2 photoreal stack - free tools, Godot 4.3 web safe.
Upscales albedo (RealESRGAN if present else Lanczos), derives normal+roughness,
keeps pack gate (<190MiB) by capping at 1K/2K and reusing existing downscale tools.
Usage: ep2_photoreal_stack.py --albedo src/episode2/assets/bear_rigged_0.jpg --outdir /tmp/ep2photo --size 1024
"""
import argparse, os, sys
from pathlib import Path

def load_img(p):
    from PIL import Image
    return Image.open(p).convert("RGB")

def upscale(img, size, esrgan_path=None):
    # RealESRGAN needs torch+realesrgan pkg + GPU; on 2GB 920MX use Lanczos fallback.
    # ComfyUI UltimateSDUpscale path (once SD1.5 lands) does tiled diffusion upscale instead.
    if esrgan_path and Path(esrgan_path).exists():
        try:
            import torch
            from realesrgan import RealESRGANer
            from basicsr.archs.rrdbnet_arch import RRDBNet
            model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64, num_block=23, num_grow_ch=32, scale=4)
            up = RealESRGANer(scale=4, model_path=str(esrgan_path), model=model,
                              tile=256, tile_pad=10, pre_pad=0, half=False, device="cpu")
            import numpy as np
            out, _ = up.enhance(np.array(img), outscale=2)
            from PIL import Image
            img = Image.fromarray(out)
        except Exception as e:
            print(f"ESRGAN failed ({e}), Lanczos fallback", file=sys.stderr)
    w, h = img.size
    s = max(w, h)
    if s != size:
        img = img.resize((size, int(h*size/w)), 3)  # 3 = LANCZOS
    return img

def albedo_to_normal(img, strength=1.5):
    import numpy as np
    from PIL import Image
    g = np.asarray(img.convert("L"), dtype=float) / 255.0
    dy, dx = np.gradient(g)
    n = np.dstack((-dx*strength, -dy*strength, np.ones_like(g)))
    n /= (np.linalg.norm(n, axis=2, keepdims=True) + 1e-8)
    return Image.fromarray(((n*0.5+0.5)*255).astype("uint8"))

def albedo_to_rough(img):
    import numpy as np
    from PIL import Image
    g = np.asarray(img.convert("L"), dtype=float)
    r = (255 - g*0.5 - 40).clip(60, 230)  # skin/cloth mid-rough, no mirror
    return Image.fromarray(r.astype("uint8")).convert("RGB")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--albedo", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--size", type=int, default=1024, choices=[512, 1024, 2048])
    ap.add_argument("--esrgan", default=os.path.expanduser("~/ComfyUI/models/upscale_models/RealESRGAN_x4plus.pth"))
    a = ap.parse_args()
    out = Path(a.outdir); out.mkdir(parents=True, exist_ok=True)
    img = load_img(a.albedo)
    up = upscale(img, a.size, a.esrgan)
    up.save(out / "albedo_hq.jpg", quality=88)
    albedo_to_normal(up).save(out / "normal_from_albedo.jpg", quality=88)
    albedo_to_rough(up).save(out / "roughness_from_albedo.jpg", quality=88)
    print(f"wrote {out}/albedo_hq.jpg + normal + roughness @ {a.size}px")
    print("next: SD1.5 diffusion re-texture via ComfyUI UltimateSDUpscale (tiled, denoise 0.35, depth-ControlNet) once checkpoint lands, then glb_downscale_textures.py to hold 189.6MiB gate.")

if __name__ == "__main__":
    main()
