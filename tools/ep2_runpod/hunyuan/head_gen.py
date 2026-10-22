import sys, time, torch
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dshape")
from PIL import Image
from hy3dshape.rembg import BackgroundRemover
from hy3dshape.pipelines import Hunyuan3DDiTFlowMatchingPipeline
t=time.time(); img=Image.open("/workspace/head_ref.png").convert("RGB"); print("ref", img.size, flush=True)
img=BackgroundRemover()(img); img.save("/workspace/head_ref_nobg.png")
pipe=Hunyuan3DDiTFlowMatchingPipeline.from_pretrained("tencent/Hunyuan3D-2.1")
mesh=pipe(image=img, num_inference_steps=50, octree_resolution=512, generator=torch.Generator("cuda").manual_seed(7))[0]
mesh.export("/workspace/head_hy_shape.glb"); print("GEN_DONE", len(mesh.faces), round(time.time()-t), flush=True)
