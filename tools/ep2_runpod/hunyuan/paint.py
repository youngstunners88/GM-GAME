import os, sys, glob, time, shutil
os.chdir("/workspace/Hunyuan3D-2.1/hy3dpaint")
sys.path.insert(0, os.getcwd()); sys.path.insert(0, "/workspace/Hunyuan3D-2.1")
try:
    from utils.torchvision_fix import apply_fix; apply_fix()
except Exception as e: print("fix warn", e)
from textureGenPipeline import Hunyuan3DPaintPipeline, Hunyuan3DPaintConfig
t = time.time()
conf = Hunyuan3DPaintConfig(6, 512)
pipe = Hunyuan3DPaintPipeline(conf)
print("PAINT_LOADED", round(time.time()-t), flush=True)
out = pipe(mesh_path="/workspace/bull_60k.glb", image_path="/workspace/bull_ref_nobg.png")
print("PAINT_OUT", out, round(time.time()-t), flush=True)
if out and os.path.exists(out): shutil.copy(out, "/workspace/bull_painted.glb")
for f in glob.glob(os.path.dirname(out or ".") + "/*"): print("OUTFILE", f)
