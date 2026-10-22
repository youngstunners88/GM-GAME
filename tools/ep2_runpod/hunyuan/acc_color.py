"""SDXL img2img colour pass on a chosen reference: keeps the pose and silhouette, restores natural colour. Skill ep2-mixamo-pipeline.
  python acc_color.py <in.png> <out_prefix> "<prompt>" [strength=0.5] [n=4]"""
import sys, torch
from PIL import Image
from diffusers import StableDiffusionXLImg2ImgPipeline
src, prefix, prompt = sys.argv[1], sys.argv[2], sys.argv[3]
strength = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
n = int(sys.argv[5]) if len(sys.argv) > 5 else 4
pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16", use_safetensors=True).to("cuda")
img = Image.open(src).convert("RGB")
neg = "sepia, monochrome, black and white, vintage tint, cropped, text, watermark, deformed, blurry"
for i in range(n):
    g = torch.Generator("cuda").manual_seed(300 + i)
    out = pipe(prompt=prompt, negative_prompt=neg, image=img, strength=strength, num_inference_steps=40, guidance_scale=7.0, generator=g).images[0]
    out.save(f"/workspace/{prefix}_{300 + i}.png"); print("saved", i, flush=True)
print("COLOR_DONE")
