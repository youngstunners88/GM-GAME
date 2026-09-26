#!/usr/bin/env python3
"""Meshy image-to-3D -> GLB, sized for the web-export pack budget.

Usage:
  python3 tools/meshy/meshy_gen.py <image> <out.glb> [--polycount N] [--pose a-pose|t-pose|keep]

Key is read from MESHY_API_KEY and is never printed, logged, or written to disk.

Why low polycount by default: the web pack has ~7 MiB of headroom under the 190 MiB
itch gate (see src/episode2/assets/GODOT_NOTES.md). Meshy's defaults (30k tris, 2k
textures) would spend most of that on one asset. Textures are downscaled afterwards
by tools/meshy/shrink_glb.py — Meshy has no sub-2k texture option.

Stdlib only (urllib), so it adds no dependency to the repo.
"""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.meshy.ai/openapi/v1/image-to-3d"
POLL_EVERY_S = 10
TIMEOUT_S = 1200


def _req(method: str, url: str, key: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        # Surface Meshy's own error text; it never contains the key.
        raise SystemExit(f"Meshy HTTP {e.code}: {e.read().decode(errors='replace')[:400]}") from None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("out")
    ap.add_argument("--polycount", type=int, default=8000)
    ap.add_argument("--pose", default="keep", choices=["keep", "a-pose", "t-pose"])
    ap.add_argument("--texture-prompt", default="")
    ap.add_argument("--pbr", action="store_true",
                    help="also generate normal + metallic/roughness maps (the surface detail)")
    a = ap.parse_args()

    key = os.environ.get("MESHY_API_KEY")
    if not key:
        raise SystemExit("MESHY_API_KEY not set")

    img = Path(a.image)
    mime = mimetypes.guess_type(img.name)[0] or "image/png"
    uri = f"data:{mime};base64,{base64.b64encode(img.read_bytes()).decode()}"

    body = {
        "image_url": uri,
        "ai_model": "latest",
        "should_remesh": True,
        "topology": "triangle",
        "target_polycount": a.polycount,
        "should_texture": True,
        "texture_resolution": "2k",
        "enable_pbr": bool(a.pbr),    # normal + metallic/roughness; shrink_glb sizes them down
        "pose_mode": "" if a.pose == "keep" else a.pose,
        "target_formats": ["glb"],
        "auto_size": True,
        "origin_at": "bottom",        # feet on y=0 — drops straight onto a cart floor / scaffold
    }
    if a.texture_prompt:
        body["texture_prompt"] = a.texture_prompt[:800]

    task = _req("POST", API, key, body)
    tid = task.get("result")
    if not tid:
        raise SystemExit(f"no task id in response: {list(task)}")
    print(f"task {tid} created ({img.name}, {a.polycount} tris)", flush=True)

    t0 = time.time()
    while True:
        s = _req("GET", f"{API}/{tid}", key)
        st = s.get("status")
        print(f"  {st} {s.get('progress', 0)}%", flush=True)
        if st == "SUCCEEDED":
            url = (s.get("model_urls") or {}).get("glb")
            if not url:
                raise SystemExit("SUCCEEDED but no model_urls.glb")
            out = Path(a.out)
            out.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(url, timeout=300) as r:
                out.write_bytes(r.read())
            print(f"wrote {out} ({out.stat().st_size:,} B) task={tid}", flush=True)
            return 0
        if st in ("FAILED", "CANCELED"):
            raise SystemExit(f"task {st}: {(s.get('task_error') or {}).get('message', '')}")
        if time.time() - t0 > TIMEOUT_S:
            raise SystemExit(f"timed out after {TIMEOUT_S}s (task {tid} may still finish)")
        time.sleep(POLL_EVERY_S)


if __name__ == "__main__":
    sys.exit(main())
