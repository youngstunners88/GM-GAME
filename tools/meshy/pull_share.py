#!/usr/bin/env python3
"""Founder Meshy share link -> game-ready GLB in one command (skill: ep2-founder-intake).

  python3 tools/meshy/pull_share.py DL2PTu [--remesh 25000] [--tex 1024] [--aux 512] [--name hero]

  share code or full URL -> task uuid -> task JSON (name, prompts, thumbnail)
  -> raw GLB (kept in .farm, usually 50-170 MB, 0.5-2.7 M verts)
  -> `meshy remesh` of the SAME task (5 credits) unless --remesh 0
  -> tools/meshy/shrink_glb.py (textures to --tex / --aux px)
  -> scripts/glb-shot.mjs contact sheet + bounds

Output folder: .farm/share/<name-or-code>/  (meta.json, thumb.png, remesh.glb, game.glb, sheet.png)
Nothing is installed into src/ — the caller decides the game name and placement.
Key: MESHY_API_KEY from the environment (never printed). The remesh is the only paid step.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API = "https://api.meshy.ai/openapi/v1"
UUID = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")


def req(path: str) -> dict | list | None:
    r = urllib.request.Request(API + path, headers={"Authorization": "Bearer " + os.environ["MESHY_API_KEY"]})
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def resolve(share: str) -> str:
    """Share code / URL -> task uuid (the redirect URL ends in it)."""
    if UUID.fullmatch(share):
        return share
    url = share if share.startswith("http") else f"https://www.meshy.ai/s/{share}"
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=60) as resp:
        found = UUID.findall(resp.geturl())
    if not found:
        sys.exit(f"could not find a task id in the redirect of {url}")
    return found[-1]


def find_task(uid: str) -> tuple[str, dict]:
    for ep in ("image-to-3d", "multi-image-to-3d", "text-to-3d", "remesh", "retexture"):
        t = req(f"/{ep}/{uid}")
        if t:
            return ep, t
    sys.exit(f"task {uid} is not readable with this API key (not the founder's account?)")


def download(url: str, dest: Path) -> None:
    urllib.request.urlretrieve(url, dest)


def run(cmd: list[str]) -> str:
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    if r.returncode != 0:
        sys.exit(f"{' '.join(cmd[:3])} failed: {(r.stdout + r.stderr)[-400:]}")
    return r.stdout


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("share")
    ap.add_argument("--remesh", type=int, default=25000, help="target triangles; 0 = skip the paid remesh")
    ap.add_argument("--tex", type=int, default=1024)
    ap.add_argument("--aux", type=int, default=512)
    ap.add_argument("--name", default="")
    a = ap.parse_args()
    if not os.environ.get("MESHY_API_KEY"):
        sys.exit("STOP: MESHY_API_KEY is not set")

    uid = resolve(a.share)
    kind, task = find_task(uid)
    out = ROOT / ".farm/share" / (a.name or a.share.rsplit("/", 1)[-1])
    out.mkdir(parents=True, exist_ok=True)
    (out / "meta.json").write_text(json.dumps({k: task.get(k) for k in (
        "id", "name", "status", "object_prompt", "style_prompt", "texture_prompt", "art_style", "model_urls")}, indent=2))
    print(f"{kind} {uid}: '{task.get('name')}' [{task.get('status')}]")
    if task.get("thumbnail_url"):
        download(task["thumbnail_url"], out / "thumb.png")

    src = out / "raw.glb"
    glb_url = (task.get("model_urls") or {}).get("glb") or task.get("model_url")
    if a.remesh > 0:
        sub = json.loads(run(["meshy", "remesh", "create", "--input-task-id", uid, "--topology", "triangle",
                              "--target-polycount", str(a.remesh), "--target-formats", "glb", "--async",
                              "--output-schema", "v1", "--format", "json", "--no-update-check"]))
        rid = sub["result"]["submission"]["task_id"]
        print(f"remesh task {rid} ({a.remesh} tris) ...", flush=True)
        while True:
            rt = req(f"/remesh/{rid}")
            if rt and rt.get("status") == "SUCCEEDED":
                glb_url = rt["model_urls"]["glb"]
                break
            if rt and rt.get("status") in ("FAILED", "CANCELED"):
                sys.exit(f"remesh {rt.get('status')}: {rt.get('task_error')}")
            time.sleep(8)
    if not glb_url:
        sys.exit("no GLB url on the task")
    download(glb_url, src)
    print(f"downloaded {src.stat().st_size // 1024} KB")
    game = out / "game.glb"
    print(run([sys.executable, "tools/meshy/shrink_glb.py", str(src), str(game), "--max", str(a.tex),
               "--aux-max", str(a.aux)]).strip().splitlines()[-1])
    try:
        info = run(["node", "scripts/glb-shot.mjs", str(game), str(out / "sheet.png"), "--size", "320"]).strip().splitlines()[-1]
        print("bounds/tris:", info[:240])
    except SystemExit as e:
        print("contact sheet skipped:", e)
    print(f"OK -> {out}/game.glb  (sheet: {out}/sheet.png)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
