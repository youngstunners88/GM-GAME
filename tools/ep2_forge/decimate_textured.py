#!/usr/bin/env python3
"""Founder Tripo/Meshy raw GLB (1M verts, 4K textures) -> game mesh, UVs kept (skill ep2-founder-asset-swap).
  python3 tools/ep2_forge/decimate_textured.py in.glb out.glb --faces 50000 --tex 1024
Round-trips through OBJ so pymeshlab's texture-aware quadric collapse keeps the UV seams.
(pip install pymeshlab trimesh pillow; apt-get install libopengl0)
"""
import argparse, os, tempfile
import numpy as np, trimesh, pymeshlab
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--faces", type=int, default=50000)
ap.add_argument("--tex", type=int, default=1024)
a = ap.parse_args()

sc = trimesh.load(a.src, force="scene")
g = list(sc.geometry.values())[0]
mat = g.visual.material
tex = mat.baseColorTexture
tmp = tempfile.mkdtemp()
obj = os.path.join(tmp, "m.obj")
tex.convert("RGB").save(os.path.join(tmp, "m.png"))
g.export(obj)                                   # writes m.obj + material.mtl + texture
for f in os.listdir(tmp):
    if f.endswith(".mtl"):
        s = open(os.path.join(tmp, f)).read()
        import re
        s = re.sub(r"map_Kd .*", "map_Kd m.png", s)
        open(os.path.join(tmp, f), "w").write(s)
ms = pymeshlab.MeshSet()
ms.load_new_mesh(obj)
ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=a.faces, preserveboundary=True, preservenormal=True,
                                                         qualitythr=0.5, extratcoordw=1.0)
out_obj = os.path.join(tmp, "d.obj")
ms.save_current_mesh(out_obj, save_textures=False)
d = trimesh.load(out_obj, process=False, force="mesh")
uv = np.asarray(d.visual.uv) if hasattr(d.visual, "uv") and d.visual.uv is not None else None
print("faces", len(d.faces), "verts", len(d.vertices), "uv", None if uv is None else uv.shape)
img = tex.convert("RGB")
if max(img.size) > a.tex:
    img = img.resize((a.tex, a.tex), Image.LANCZOS)
d.visual = trimesh.visual.TextureVisuals(uv=uv, material=trimesh.visual.material.PBRMaterial(
    baseColorTexture=img, metallicFactor=0.0, roughnessFactor=0.8, doubleSided=False))
d.export(a.dst)
print("wrote", a.dst, os.path.getsize(a.dst) // 1024, "KB")
