#!/usr/bin/env python3
"""The auction's seven new people through native Tripo (founder 2026-11-16): sheet -> mesh (30 cr) -> rig-check (free) -> rig v1.0
mixamo (25 cr) -> retarget presets (10 cr per clip) -> <work>/<id>/animated.glb. Resumable: every task id is saved to the manifest and a
task that already succeeded is never generated again.

  python3 tools/tripo/auction_cast_batch.py plan                 # cast + credit estimate, spends nothing
  python3 tools/tripo/auction_cast_batch.py run [--only id,id]   # advance every person as far as it goes
  python3 tools/tripo/auction_cast_batch.py finish [--only id]   # re-download animated.glb from the saved retarget task

Key: TRIPO_API_KEY from the environment (set -a; . ~/GM-GAME/.env; set +a), never printed.
Manifest: design/ep2/auction/cast-references-20261116/manifest.json. Downloads: $AUCTION_TRIPO_WORK (default .farm/tripo).
"""
import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(os.environ.get("GM_ROOT") or Path(__file__).resolve().parents[2])
sys.path.insert(0, str(ROOT / "tools/ep2_forge"))
import tripo_gen as T  # noqa: E402

REFS = ROOT / "design/ep2/auction/cast-references-20261116"
MANIFEST = Path(os.environ.get("AUCTION_TRIPO_MANIFEST") or REFS / "manifest.json")
WORK = Path(os.environ.get("AUCTION_TRIPO_WORK", ROOT / ".farm/tripo"))
GEN = {"model": "v3.1-20260211", "texture": True, "pbr": True, "texture_quality": "standard", "geometry_quality": "standard",
       "face_limit": 12000, "auto_size": True}
CHECK = ["preset:biped:idle", "preset:biped:greet_01", "preset:biped:complain_01"]
SING = ["preset:biped:idle", "preset:biped:sing_01"]
RIG_ONLY: list = []      # retarget is 10 credits PER CLIP (measured 2026-11-16): these four take checker A's Idle (same mixamo rig) in post
# id, game file, height (m), presets in order -> game clip names
CAST = [
    ("checker_a", "auction_checker_a.glb", 1.82, CHECK, ["Idle", "Greet", "Talk"]),
    ("checker_b", "auction_checker_b.glb", 1.78, CHECK, ["Idle", "Greet", "Talk"]),
    ("band_lead", "auction_band_lead.glb", 1.66, SING, ["Idle", "Play"]),
    ("band_fiddle", "auction_band_fiddle.glb", 1.76, RIG_ONLY, []),
    ("band_guitar", "auction_band_guitar.glb", 1.80, RIG_ONLY, []),
    ("band_bass", "auction_band_bass.glb", 1.84, RIG_ONLY, []),
    ("band_harmonica", "auction_band_harmonica.glb", 1.77, RIG_ONLY, []),
]
COST = {"mesh": 30, "rig": 25, "retarget": 10}      # retarget is per clip


def load() -> dict:
    return json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"people": {}}


def save(m: dict) -> None:
    MANIFEST.write_text(json.dumps(m, indent=1) + "\n")


def task(path: str, body: dict) -> dict:
    tid = T.call(path, json.dumps(body).encode())["task_id"]
    print("  task", path, tid, flush=True)
    t = T.poll(tid)
    t["task_id"] = tid
    return t


def advance(cid: str, file: str, h: float, presets: list, clips: list, row: dict, m: dict) -> None:
    out = WORK / cid
    out.mkdir(parents=True, exist_ok=True)
    row.update({"file": file, "height": h, "presets": presets, "clips": clips})
    if not row.get("mesh_task"):
        opts = dict(GEN)
        opts["input"] = T.upload(str(REFS / (cid + ".jpg")))
        t = task("/generation/image-to-model", opts)
        if t.get("status") != "success":
            sys.exit("%s: mesh %s" % (cid, t.get("status")))
        row["mesh_task"] = t["task_id"]
        o = t.get("output", {})
        urllib.request.urlretrieve(o.get("pbr_model") or o.get("model_url") or o.get("model"), out / "raw.glb")
        save(m)
    if "riggable" not in row:
        t = task("/animations/rig-check", {"input": row["mesh_task"]})
        o = t.get("output", {})
        row["riggable"], row["rig_type"] = bool(o.get("riggable")), o.get("rig_type")
        save(m)
    if not row["riggable"] or row.get("rig_type") != "biped":
        sys.exit("%s: not a riggable biped (%s)" % (cid, row.get("rig_type")))
    if not row.get("rig_task"):
        t = task("/animations/rig", {"input": row["mesh_task"], "model": "v1.0-20240301", "rig_type": "biped", "spec": "mixamo", "out_format": "glb"})
        if t.get("status") != "success":
            sys.exit("%s: rig %s %s" % (cid, t.get("status"), t.get("error_code")))
        row["rig_task"] = t["task_id"]
        o = t.get("output", {})
        urllib.request.urlretrieve(o.get("model_url") or o.get("model"), out / "rigged.glb")
        save(m)
    if not presets:
        return
    if not row.get("retarget_task"):
        t = task("/animations/retarget", {"input": row["rig_task"], "animations": presets, "out_format": "glb", "animate_in_place": True})
        if t.get("status") != "success":
            sys.exit("%s: retarget %s %s" % (cid, t.get("status"), t.get("error_code")))
        row["retarget_task"] = t["task_id"]
        row["retarget_output_keys"] = sorted(t.get("output", {}).keys())
        save(m)
        fetch(cid, row, t)


def fetch(cid: str, row: dict, t: dict | None = None) -> None:
    t = t or T.call("/tasks/" + row["retarget_task"])
    o = t.get("output", {})
    out = WORK / cid
    out.mkdir(parents=True, exist_ok=True)
    urls = o.get("model_urls") or [o.get("model_url") or o.get("model")]
    for i, u in enumerate([u for u in urls if u]):
        dst = out / ("animated.glb" if i == 0 and len(urls) == 1 else "animated_%d.glb" % i)
        urllib.request.urlretrieve(u, dst)
        print("  saved", dst, dst.stat().st_size, flush=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["plan", "run", "finish"])
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    only = {x for x in a.only.split(",") if x}
    m = load()
    if a.mode == "plan":
        total = 0
        for cid, file, h, presets, clips in CAST:
            row = m["people"].get(cid, {})
            left = (0 if row.get("mesh_task") else COST["mesh"]) + (0 if row.get("rig_task") else COST["rig"]) + (0 if row.get("retarget_task") else COST["retarget"] * len(presets))
            total += left
            print("%-15s %-28s h=%.2f clips=%s credits left ~%d" % (cid, file, h, ",".join(clips), left))
        print("TOTAL ~%d credits still to spend" % total)
        return 0
    before = T.balance()
    for cid, file, h, presets, clips in CAST:
        if only and cid not in only:
            continue
        row = m["people"].setdefault(cid, {})
        print(cid, flush=True)
        if a.mode == "run":
            advance(cid, file, h, presets, clips, row, m)
        else:
            fetch(cid, row)
    after = T.balance()
    m["credits_spent_runs"] = m.get("credits_spent_runs", []) + [{"before": before, "after": after}]
    save(m)
    print("credits %.0f -> %.0f" % (before, after))
    return 0


if __name__ == "__main__":
    sys.exit(main())
