"""A character reference that KEEPS the pose guide's A-pose: SDXL img2img from a front render (pose_guide_render.py or Jack Hammer's
pose_guide.png). Skill ep2-mixamo-pipeline. Same idea as jack_ref.py, any character:
  python3 ref_img2img.py <guide.png> "<prompt>" <strength> <n> <seed0> <tag> ["<extra negative>"]  -> /workspace/<tag>_<seed>.png
0.66 keeps the guide's face details (Jack's patch); 0.72-0.80 keeps only the silhouette and pose."""
import sys, torch
from PIL import Image
from diffusers import StableDiffusionXLImg2ImgPipeline
guide, prompt, strength, n, seed0, tag = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), sys.argv[6]
extra = sys.argv[7] if len(sys.argv) > 7 else ""
pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16", use_safetensors=True).to("cuda")
img = Image.open(guide).convert("RGB").resize((832, 1216))
neg = ("hands behind back, hands in pockets, hand on hip, arms crossed, holding objects, sepia, monochrome, vintage photo, cropped, close-up, cut off feet, extra limbs, "
       "deformed hands, blurry, text, watermark, multiple people, shadow on background, shelves, store interior, furniture, weapon, cartoon, 3d render, plastic, eye patch, " + extra)
for i in range(n):
    g = torch.Generator("cuda").manual_seed(seed0 + i)
    out = pipe(prompt=prompt, negative_prompt=neg, image=img, strength=strength, num_inference_steps=40, guidance_scale=7.5, generator=g).images[0]
    out.save(f"/workspace/{tag}_{seed0 + i}.png"); print("saved", i, flush=True)
print("REF_DONE")
