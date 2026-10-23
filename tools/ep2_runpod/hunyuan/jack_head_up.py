import torch
from PIL import Image
from diffusers import StableDiffusionXLImg2ImgPipeline
src = Image.open("/workspace/jhC_700.png").convert("RGB")
box = (285, 25, 545, 305)                       # hat + face + neck of the chosen full-body reference
c = src.crop(box); side = max(c.size)
sq = Image.new("RGB", (side, side), (255, 255, 255)); sq.paste(c, ((side - c.width) // 2, (side - c.height) // 2))
sq = sq.resize((1024, 1024), Image.LANCZOS); sq.save("/workspace/hd_crop.png")
pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained("stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16, variant="fp16", use_safetensors=True).to("cuda")
prompt = ("close portrait of a mean menacing weathered Wild West outlaw wearing a black hat, a black leather eye patch with a strap over his left eye, one cold narrowed eye, "
          "deep scowl, dark stubble beard, scar, facing straight at the camera, head and neck only, natural colour photograph, plain white background, soft even lighting, sharp detail")
neg = "sepia, monochrome, vintage, smiling, sunglasses, side view, text, watermark, two eye patches, cartoon, multiple people, cropped face"
for i, st in enumerate([0.35, 0.45, 0.55, 0.45]):
    g = torch.Generator("cuda").manual_seed(1100 + i)
    pipe(prompt=prompt, negative_prompt=neg, image=sq, strength=st, num_inference_steps=40, guidance_scale=7.5, generator=g).images[0].save(f"/workspace/hu_{i}.png")
sh = Image.new("RGB", (1600, 400), "white")
sh.paste(sq.resize((400, 400)), (0, 0))
for i in range(4): sh.paste(Image.open(f"/workspace/hu_{i}.png").resize((300, 300)), (400 + i * 300, 50))
sh.save("/workspace/hu_sheet.jpg", quality=88); print("UP_DONE")
