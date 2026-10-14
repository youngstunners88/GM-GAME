import sys, time, torch
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dshape")
from PIL import Image
from hy3dshape.rembg import BackgroundRemover
from hy3dshape.pipelines import Hunyuan3DDiTFlowMatchingPipeline
t=time.time()
img = Image.open("/workspace/bull_ref.jpg").convert("RGB")
print("ref size", img.size, flush=True)
img = BackgroundRemover()(img)
img.save("/workspace/bull_ref_nobg.png")
pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained("tencent/Hunyuan3D-2.1")
print("loaded", round(time.time()-t), "s", flush=True)
g = torch.Generator("cuda").manual_seed(7)
mesh = pipe(image=img, num_inference_steps=50, octree_resolution=384, generator=g)[0]
mesh.export("/workspace/bull_hy_shape.glb")
print("GEN_DONE", len(mesh.vertices), "verts", len(mesh.faces), "faces", round(time.time()-t), "s", flush=True)
