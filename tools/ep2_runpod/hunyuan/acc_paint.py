"""Decimate a Hunyuan shape to 60k faces and paint PBR textures from the reference (Hunyuan3D-2.1 paint). Skill ep2-mixamo-pipeline.
  python acc_paint.py <out_prefix>   needs /workspace/<prefix>_shape.glb and <prefix>_nobg.png; writes <prefix>_60k.glb + the painted GLB path"""
import os, sys, glob, time, shutil
import trimesh, pymeshlab
prefix = sys.argv[1]
m = trimesh.load(f"/workspace/{prefix}_shape.glb", force="mesh")
ms = pymeshlab.MeshSet(); ms.add_mesh(pymeshlab.Mesh(m.vertices, m.faces))
ms.meshing_decimation_quadric_edge_collapse(targetfacenum=60000, preservenormal=True, preserveboundary=True, qualitythr=0.5)
d = ms.current_mesh()
trimesh.Trimesh(d.vertex_matrix(), d.face_matrix()).export(f"/workspace/{prefix}_60k.glb")
print("DECIM", len(d.face_matrix()), "faces", flush=True)
os.chdir("/workspace/Hunyuan3D-2.1/hy3dpaint")
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dpaint"); sys.path.insert(0, "/workspace/Hunyuan3D-2.1")
try:
    from utils.torchvision_fix import apply_fix; apply_fix()
except Exception as e: print("fix warn", e)
from textureGenPipeline import Hunyuan3DPaintPipeline, Hunyuan3DPaintConfig
t = time.time()
conf = Hunyuan3DPaintConfig(6, 512)
R = "/workspace/Hunyuan3D-2.1/hy3dpaint"
conf.multiview_cfg_path = R + "/cfgs/hunyuan-paint-pbr.yaml"
conf.custom_pipeline = R + "/hunyuanpaintpbr"
conf.realesrgan_ckpt_path = R + "/ckpt/RealESRGAN_x4plus.pth"
pipe = Hunyuan3DPaintPipeline(conf)
print("PAINT_LOADED", round(time.time() - t), flush=True)
out = pipe(mesh_path=f"/workspace/{prefix}_60k.glb", image_path=f"/workspace/{prefix}_nobg.png")
print("PAINT_OUT", out, round(time.time() - t), flush=True)
if out and os.path.exists(out):
    shutil.copy(out, f"/workspace/{prefix}_painted.glb")
for f in glob.glob(os.path.dirname(out or ".") + "/*"): print("OUTFILE", f)
print("PAINT_DONE")
