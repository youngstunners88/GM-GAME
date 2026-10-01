#!/usr/bin/env python3
"""Download finished Meshy image-to-3d tasks for Inferno Bull's hideout, shrink them for the web pack and install
them under src/episode2/assets/hideout/. Provenance goes to src/episode2/assets/hideout/sources.json.

  python3 tools/meshy/pull_hideout_props.py name=task_id [name=task_id ...]

Key: MESHY_API_KEY from the environment, never printed. Waits for tasks that are still running.
"""
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

API = "https://api.meshy.ai/openapi/v1/image-to-3d/"
DEST = Path("src/episode2/assets/hideout")
FARM = Path(".farm/hideout/meshy")


def _get(task: str) -> dict:
    r = urllib.request.Request(API + task, headers={"Authorization": "Bearer " + os.environ["MESHY_API_KEY"]})
    return json.loads(urllib.request.urlopen(r, timeout=60).read())


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)
    FARM.mkdir(parents=True, exist_ok=True)
    src_file = DEST / "sources.json"
    sources = json.loads(src_file.read_text()) if src_file.exists() else {}
    for arg in sys.argv[1:]:
        name, task = arg.split("=", 1)
        for _ in range(60):
            t = _get(task)
            if t.get("status") == "SUCCEEDED":
                break
            if t.get("status") in ("FAILED", "CANCELED", "EXPIRED"):
                print(f"[{name}] {t.get('status')}: {t.get('task_error')}")
                break
            time.sleep(10)
        if t.get("status") != "SUCCEEDED":
            continue
        raw = FARM / f"{name}_raw.glb"
        urllib.request.urlretrieve(t["model_urls"]["glb"], raw)
        out = DEST / f"{name}.glb"
        subprocess.run([sys.executable, "tools/meshy/shrink_glb.py", str(raw), str(out), "--max", "1024",
                        "--aux-max", "256"], check=True)
        sources[f"{name}.glb"] = {"task": task, "kind": "image-to-3d smart-topology (meshy-t2), textured",
                                  "concept": f"tools/ep2_forge/hideout_concepts.py -> {name}",
                                  "credits": t.get("consumed_credits", 15)}
        print(f"[{name}] OK {out} {out.stat().st_size} B")
    src_file.write_text(json.dumps(sources, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
