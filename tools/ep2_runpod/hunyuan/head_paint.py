import torch
import os, sys, glob, time, shutil
os.chdir("/workspace/Hunyuan3D-2.1/hy3dpaint")
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dpaint"); sys.path.insert(0, "/workspace/Hunyuan3D-2.1")
try:
    from utils.torchvision_fix import apply_fix; apply_fix()
except Exception as e: print("fix warn", e)
from textureGenPipeline import Hunyuan3DPaintPipeline, Hunyuan3DPaintConfig
t = time.time()
conf = Hunyuan3DPaintConfig(6, 512)
R="/workspace/Hunyuan3D-2.1/hy3dpaint"
conf.multiview_cfg_path=R+"/cfgs/hunyuan-paint-pbr.yaml"
conf.custom_pipeline=R+"/hunyuanpaintpbr"
conf.realesrgan_ckpt_path=R+"/ckpt/RealESRGAN_x4plus.pth"
print("CFG", conf.multiview_cfg_path, conf.custom_pipeline, flush=True)
pipe = Hunyuan3DPaintPipeline(conf)
print("PAINT_LOADED", round(time.time()-t), flush=True)
out = pipe(mesh_path="/workspace/head_60k.glb", image_path="/workspace/head_ref_nobg.png")
print("PAINT_OUT", out, round(time.time()-t), flush=True)
