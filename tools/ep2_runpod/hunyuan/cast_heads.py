"""Second, sharper head scans for full-body references (the body scan's face is ~60 px and comes out smeared): crop head + neck
from the background-removed reference, square it, upscale with SDXL img2img at a low strength (keeps the identity, adds detail).
Skill ep2-mixamo-pipeline (Jack Hammer 2026-10-21 did this by hand with jack_head_up.py).
  python3 cast_heads.py cast.json   [{"name": "shopA", "ref": "/workspace/x.png", "head_prompt": "..."}]
Writes /workspace/cast/<name>_head/<name>_head_src.png (the crop) and <name>_head_src_up.png (the upscale) + a crop record."""
import json, os, sys
import numpy as np
import torch
from PIL import Image
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dshape")
from hy3dshape.rembg import BackgroundRemover
from diffusers import StableDiffusionXLImg2ImgPipeline

cast = json.load(open(sys.argv[1]))
rb = BackgroundRemover()
pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16",
                                                        use_safetensors=True).to("cuda")
neg = "sepia, monochrome, vintage, sunglasses, hat, cap, side view, text, watermark, cartoon, multiple people, cropped face, deformed, blurry"
for c in cast:
    d = f"/workspace/cast/{c['name']}_head"
    os.makedirs(d, exist_ok=True)
    img = Image.open(c["ref"]).convert("RGB")
    alpha = np.array(rb(img).convert("RGBA"))[..., 3] > 128
    ys, xs = np.nonzero(alpha)
    y0, y1 = int(ys.min()), int(ys.max())
    h = y1 - y0
    head_rows = alpha[y0:y0 + int(0.11 * h)]
    cols = np.nonzero(head_rows.any(0))[0]
    cx = int((cols.min() + cols.max()) / 2)
    top, bot = max(0, y0 - int(0.02 * h)), y0 + int(0.20 * h)
    half = int(0.11 * h)
    box = (max(0, cx - half), top, min(img.width, cx + half), bot)
    crop = img.crop(box)
    side = max(crop.size)
    sq = Image.new("RGB", (side, side), (255, 255, 255))
    sq.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
    sq = sq.resize((1024, 1024), Image.LANCZOS)
    sq.save(f"{d}/{c['name']}_head_src.png")
    g = torch.Generator("cuda").manual_seed(1100)
    up = pipe(prompt=c["head_prompt"], negative_prompt=neg, image=sq, strength=float(c.get("head_strength", 0.40)), num_inference_steps=40,
              guidance_scale=7.5, generator=g).images[0]
    up.save(f"{d}/{c['name']}_head_src_up.png")
    json.dump({"box": box, "figure_px": h, "crop_top_px": top, "crop_bottom_px": bot, "figure_top_px": y0}, open(f"{d}/crop.json", "w"))
    print("HEAD_DONE", c["name"], box, "figure", h, "px", flush=True)
print("HEADS_ALL_DONE")
