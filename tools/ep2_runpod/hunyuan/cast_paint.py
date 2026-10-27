"""Decimate each Hunyuan shape to its game budget BEFORE painting (the paint's own UV unwrap is then the final one; a decimate after
painting shreds the face UVs) and paint PBR textures from its reference, loading the paint pipeline once. Skill ep2-mixamo-pipeline.
  python3 cast_paint.py <dir>:<faces> ...   each <dir> holds <base>_hy_shape.glb + <base>_ref_nobg.png (<base> = the dir's name);
  writes <dir>/<base>_dec.glb and the painted <dir>/textured_mesh.obj (+ its .mtl / .jpg maps, + a trimesh .glb)."""
import os, sys, time, traceback
import trimesh


def decimate(vertices, faces, target):
    """Quadric decimation to ~target faces: pymeshlab when this build has the filter (2022.2+ with plugins), else fast_simplification
    (the runpod/pytorch 1.0.x image's pymeshlab wheel ships without the filter plugins)."""
    try:
        import pymeshlab
        ms = pymeshlab.MeshSet(); ms.add_mesh(pymeshlab.Mesh(vertices, faces))
        ms.meshing_decimation_quadric_edge_collapse(targetfacenum=target, preservenormal=True, preserveboundary=True, qualitythr=0.5)
        dm = ms.current_mesh()
        return dm.vertex_matrix(), dm.face_matrix()
    except Exception as e:
        print("pymeshlab decimate unavailable (%s): fast_simplification" % type(e).__name__, flush=True)
    import fast_simplification
    return fast_simplification.simplify(vertices, faces, target_reduction=max(0.0, 1.0 - float(target) / float(len(faces))), agg=5)


jobs = [a.rsplit(":", 1) for a in sys.argv[1:]]
os.chdir("/workspace/Hunyuan3D-2.1/hy3dpaint")
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dpaint"); sys.path.insert(0, "/workspace/Hunyuan3D-2.1")
try:
    from utils.torchvision_fix import apply_fix; apply_fix()
except Exception as e:
    print("fix warn", e)
from textureGenPipeline import Hunyuan3DPaintPipeline, Hunyuan3DPaintConfig
t0 = time.time()
conf = Hunyuan3DPaintConfig(6, 512)
R = "/workspace/Hunyuan3D-2.1/hy3dpaint"
conf.multiview_cfg_path = R + "/cfgs/hunyuan-paint-pbr.yaml"
conf.custom_pipeline = R + "/hunyuanpaintpbr"
conf.realesrgan_ckpt_path = R + "/ckpt/RealESRGAN_x4plus.pth"
pipe = Hunyuan3DPaintPipeline(conf)
print("PAINT_LOADED", round(time.time() - t0), flush=True)
failed = 0
for d, faces in jobs:
    base = os.path.basename(d.rstrip("/"))
    t = time.time()
    try:
        m = trimesh.load(f"{d}/{base}_hy_shape.glb", force="mesh")
        v, f = decimate(m.vertices, m.faces, int(faces))
        trimesh.Trimesh(v, f).export(f"{d}/{base}_dec.glb")
        print("DECIM", base, len(f), "faces", flush=True)
        out = pipe(mesh_path=f"{d}/{base}_dec.glb", image_path=f"{d}/{base}_ref_nobg.png")
        print("PAINT_OK", base, out, round(time.time() - t), "s", flush=True)
    except Exception:
        failed += 1
        print("PAINT_FAIL", base, flush=True)
        traceback.print_exc()
print("PAINT_ALL_DONE", len(jobs) - failed, "ok", failed, "failed", round(time.time() - t0), "s", flush=True)
sys.exit(1 if failed else 0)
