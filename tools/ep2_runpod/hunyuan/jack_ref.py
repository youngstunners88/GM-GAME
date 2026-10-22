"""Jack Hammer reference: SDXL img2img from the on-box figure render (pose guide). Skill ep2-jack-hammer-character."""
import sys, torch
from PIL import Image
from diffusers import StableDiffusionXLImg2ImgPipeline
strength = float(sys.argv[1]); n = int(sys.argv[2]); seed0 = int(sys.argv[3]); tag = sys.argv[4]
pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16", use_safetensors=True).to("cuda")
img = Image.open("/workspace/pose_guide2.png").convert("RGB")
prompt = ("full body photograph of a mean, menacing Wild West outlaw standing facing the camera in a relaxed A-pose with both arms held away from his body, hands open and visible, "
          "tall hard man, scarred cruel face with a snarl, a black leather eye patch with a strap covering his left eye so only his right eye shows, deep scar across the patched eye, one cold narrowed eye, unshaven jaw, clenched teeth, a long black duster coat, black bowler hat, dark leather gloves, black boots with spurs, "
          "natural colour, plain white studio background, even soft lighting, entire body visible from hat to boots, wide framing")
neg = ("hands behind back, hands in pockets, hand on hip, arms crossed, sepia, monochrome, vintage, cropped, close-up, cut off feet, extra limbs, deformed hands, blurry, text, watermark, "
       "multiple people, smiling, friendly, shadow on background, weapon, hammer, cartoon, sunglasses, both eyes covered")
for i in range(n):
    g = torch.Generator("cuda").manual_seed(seed0 + i)
    out = pipe(prompt=prompt, negative_prompt=neg, image=img, strength=strength, num_inference_steps=40, guidance_scale=7.5, generator=g).images[0]
    out.save(f"/workspace/{tag}_{seed0 + i}.png"); print("saved", i, flush=True)
print("REF_DONE")
