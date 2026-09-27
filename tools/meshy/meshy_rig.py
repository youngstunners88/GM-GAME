#!/usr/bin/env python3
"""Rig a Meshy character and bake a named set of library animations into ONE GLB.

  python3 tools/meshy/meshy_rig.py <image_to_3d_task_id> <out.glb> --height 0.9 \
      --actions 89,466,258,178,403,104,170,237,477 [--fps 30]

1. POST /openapi/v1/rigging {input_task_id, height_meters}   -> rig task
2. POST /openapi/v1/animations {rig_task_id, action_ids[<=10], post_process fps}
   -> ONE merged GLB, one clip per action, clip names = library names
3. Download animation_glb_url (skinned mesh + armature + clips).

Source image-to-3D tasks are kept by Meshy for 3 days: rig within that window or
re-forge. Rigging is humanoid-only (422 = pose estimation failed).
Key: MESHY_API_KEY from the environment, never printed.
Writes <out>.rig.json with task ids + clip order for provenance.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.request

API = "https://api.meshy.ai/openapi/v1"


def _req(method: str, path: str, body: dict | None = None) -> dict:
    key = os.environ.get("MESHY_API_KEY", "")
    if not key:
        sys.exit("STOP: MESHY_API_KEY is not set")
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(f"{API}{path}", data=data, method=method, headers={
        "Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        sys.exit(f"Meshy {method} {path} -> HTTP {e.code}: {e.read()[:300]!r}")


def _poll(path: str, label: str, limit: int = 1800) -> dict:
    t0 = time.time()
    while time.time() - t0 < limit:
        t = _req("GET", path)
        st = t.get("status")
        if st == "SUCCEEDED":
            return t
        if st in ("FAILED", "CANCELED", "EXPIRED"):
            sys.exit(f"{label} {st}: {t.get('task_error')}")
        print(f"  {label} {st} {t.get('progress', 0)}%", flush=True)
        time.sleep(10)
    sys.exit(f"{label} timed out")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("task_id")
    ap.add_argument("out")
    ap.add_argument("--height", type=float, default=1.7)
    ap.add_argument("--actions", required=True, help="comma list of library action ids (<=10)")
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--rig-task", default="", help="reuse an existing rig task")
    a = ap.parse_args()
    actions = [int(x) for x in a.actions.split(",") if x.strip()]
    if not 1 <= len(actions) <= 10:
        sys.exit("1..10 action ids")

    rig_id = a.rig_task
    if not rig_id:
        rig_id = _req("POST", "/rigging", {"input_task_id": a.task_id, "height_meters": a.height})["result"]
        print(f"rig task={rig_id}", flush=True)
        _poll(f"/rigging/{rig_id}", "rig")
    body = {"rig_task_id": rig_id, "action_ids": actions,
            "post_process": {"operation_type": "change_fps", "fps": a.fps}}
    anim_id = _req("POST", "/animations", body)["result"]
    print(f"anim task={anim_id}", flush=True)
    t = _poll(f"/animations/{anim_id}", "anim")
    url = t["result"]["animation_glb_url"]
    urllib.request.urlretrieve(url, a.out)
    with open(a.out + ".rig.json", "w") as f:
        json.dump({"source_task": a.task_id, "rig_task": rig_id, "anim_task": anim_id,
                   "actions": actions, "fps": a.fps, "height_m": a.height,
                   "credits": t.get("consumed_credits")}, f, indent=2)
    print(f"OK {a.out} ({os.path.getsize(a.out)} B)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
