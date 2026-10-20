"""Hunyuan3D-2.1 image -> shape (untextured GLB) for a game character, on the Runpod pod. Skill ep2-mixamo-pipeline.
  python acc_gen.py <ref.png> <out_prefix>      -> /workspace/<out_prefix>_shape.glb (+ _nobg.png)"""
import sys, time, torch
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dshape")
from PIL import Image
from hy3dshape.rembg import BackgroundRemover
from hy3dshape.pipelines import Hunyuan3DDiTFlowMatchingPipeline
ref, prefix = sys.argv[1], sys.argv[2]
t = time.time()
img = Image.open(ref).convert("RGB")
img = BackgroundRemover()(img)
img.save(f"/workspace/{prefix}_nobg.png")
pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained("tencent/Hunyuan3D-2.1")
print("loaded", round(time.time() - t), "s", flush=True)
g = torch.Generator("cuda").manual_seed(7)
mesh = pipe(image=img, num_inference_steps=50, octree_resolution=384, generator=g)[0]
mesh.export(f"/workspace/{prefix}_shape.glb")
print("GEN_DONE", len(mesh.vertices), "verts", len(mesh.faces), "faces", round(time.time() - t), "s", flush=True)
