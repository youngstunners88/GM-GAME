#!/usr/bin/env python3
"""Hunyuan3D-2.1 shape generation for MANY references in ONE pod session (loads the pipeline once).

Same code path as gen.py (BackgroundRemover -> Hunyuan3DDiTFlowMatchingPipeline, 50 steps, octree 384).
Pinned environment (see docs/episode2-quality/bull-hunyuan-2026-10-15/README.md): py3.12, torch 2.8.0+cu128,
transformers==4.46.0 diffusers==0.30.0 huggingface-hub==0.30.2, numpy 2.1-2.3, `pip install -e hy3dshape --no-deps`.

  python3 gen_batch.py jobs.json [--steps 50] [--octree 384]
jobs.json: [{"name": "bear_archer", "image": "/workspace/bear_archer_ref.png", "seed": 7}, ...]
Writes /workspace/<name>_ref_nobg.png and /workspace/<name>_hy_shape.glb per job. A failing job is logged and skipped
so one bad image never costs the rest of the (billed) session. Exit code 1 if any job failed.
"""
import argparse, json, sys, time, traceback

ap = argparse.ArgumentParser()
ap.add_argument("jobs")
ap.add_argument("--steps", type=int, default=50)
ap.add_argument("--octree", type=int, default=384)
a = ap.parse_args()

jobs = json.load(open(a.jobs))
for j in jobs:                                   # validate before loading 10 GB of weights
    assert {"name", "image"} <= set(j), f"job needs name+image: {j}"

import torch
sys.path.insert(0, "/workspace/Hunyuan3D-2.1/hy3dshape")
from PIL import Image
from hy3dshape.rembg import BackgroundRemover
from hy3dshape.pipelines import Hunyuan3DDiTFlowMatchingPipeline

t0 = time.time()
rembg = BackgroundRemover()
pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained("tencent/Hunyuan3D-2.1")
print("loaded", round(time.time() - t0), "s", flush=True)

failed = 0
for j in jobs:
    t = time.time()
    try:
        img = Image.open(j["image"]).convert("RGB")
        print(j["name"], "ref size", img.size, flush=True)
        img = rembg(img)
        img.save(f"/workspace/{j['name']}_ref_nobg.png")
        g = torch.Generator("cuda").manual_seed(int(j.get("seed", 7)))
        mesh = pipe(image=img, num_inference_steps=a.steps, octree_resolution=a.octree, generator=g)[0]
        out = f"/workspace/{j['name']}_hy_shape.glb"
        mesh.export(out)
        print("GEN_DONE", j["name"], len(mesh.vertices), "verts", len(mesh.faces), "faces",
              round(time.time() - t), "s ->", out, flush=True)
        torch.cuda.empty_cache()
    except Exception:
        failed += 1
        print("GEN_FAIL", j["name"], flush=True)
        traceback.print_exc()
print("BATCH_DONE", len(jobs) - failed, "ok", failed, "failed", round(time.time() - t0), "s", flush=True)
sys.exit(1 if failed else 0)
