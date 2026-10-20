"""Generate T-pose reference images for a game character on the Runpod pod (SDXL base, fp16). Skill ep2-mixamo-pipeline.
  python acc_ref.py "<prompt>" <out_prefix> [n]   -> /workspace/<out_prefix>_<seed>.png (832x1216)"""
import sys, torch
from diffusers import StableDiffusionXLPipeline
prompt, prefix = sys.argv[1], sys.argv[2]
n = int(sys.argv[3]) if len(sys.argv) > 3 else 6
pipe = StableDiffusionXLPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16", use_safetensors=True).to("cuda")
neg = "hat, cap, sunglasses, cropped, close-up, cut off feet, extra limbs, deformed hands, blurry, text, watermark, multiple people, shadow on background, props, weapon"
for seed in range(n):
    g = torch.Generator("cuda").manual_seed(100 + seed)
    img = pipe(prompt=prompt, negative_prompt=neg, num_inference_steps=32, guidance_scale=7.0, width=832, height=1216, generator=g).images[0]
    img.save(f"/workspace/{prefix}_{100 + seed}.png")
    print("saved", seed, flush=True)
print("REF_DONE")
