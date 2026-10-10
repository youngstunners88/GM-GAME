#!/usr/bin/env python3
"""IMAGE -> 3D through Muapi (skill ep2-hyperreal-scene-pipeline, step 4). Tripo H3.1 and Meshy 6/7 are sold PAY-PER-CALL on the same Muapi balance as GPT Image 2,
so the native Meshy / Tripo credit pools (40 / 0 on 2026-10-10) are not the limit: a Tripo multiview run is ~$0.2, Meshy-6 ~$0.5, Meshy-7 ~$1.7.

  python3 tools/ep2_forge/muapi_3d.py models                                       the 3D endpoints, price, accepted fields
  python3 tools/ep2_forge/muapi_3d.py run tripo3d-h31-multiview-to-3d --images front.jpg side.jpg back.jpg --out .farm/3d/quad_tripo \\
        --set texture=true --set pbr=true --set texture_quality=detailed --set geometry_quality=detailed --set face_limit=60000
  python3 tools/ep2_forge/muapi_3d.py run meshy-6-multi-image-to-3d --images a.jpg b.jpg --out .farm/3d/quad_meshy --set target_polycount=40000 --set enable_pbr=true
  python3 tools/ep2_forge/muapi_3d.py estimate <model> [--set k=v ...]            price for those options (the estimate endpoint validates nothing)

`--images` takes repo paths (uploaded once, cached by hash in .farm/muapi_upload_cache.json) or http(s) URLs; single-image models get `image_url`, the multi ones
`images_list`. `--set k=v` values are parsed as JSON when they can be (true / 12 / "str"). Every output URL of the finished task is downloaded next to a
receipt `<out>/receipt.json` (request id, endpoint, payload, cost, urls). Key: MUAPI_API_KEY from the environment only - never printed.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _film():
    spec = importlib.util.spec_from_file_location("muapi_film", ROOT / "tools/ep2_film/muapi_film.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def upload_cached(film, path):
    cache_file = ROOT / ".farm/muapi_upload_cache.json"
    cache = json.loads(cache_file.read_text()) if cache_file.exists() else {}
    h = hashlib.sha1(Path(path).read_bytes()).hexdigest()
    if h not in cache:
        cache[h] = film.upload(str(path))
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps(cache, indent=1))
    return cache[h]


def parse_sets(sets):
    out = {}
    for s in sets or []:
        k, _, v = s.partition("=")
        try:
            out[k] = json.loads(v)
        except json.JSONDecodeError:
            out[k] = v
    return out


def cmd_models(film):
    d = film.call("/models")
    for it in d["models"]:
        if it.get("group_of") == "3d" or it.get("category") in ("Image to 3D", "Text to 3D"):
            print(f"{it['name']:34s} ${it.get('cost', 0):<6} {it.get('category', ''):12s} {', '.join(it.get('input_fields', []))}")


def cmd_estimate(film, model, sets):
    r = film.call(f"/models/{model}/estimate-cost", parse_sets(sets), "POST")
    print(json.dumps(r, indent=1)[:600])


def cmd_run(film, model, images, out, sets, dry):
    payload = parse_sets(sets)
    urls = [im if im.startswith("http") else ("(upload) " + im if dry else upload_cached(film, ROOT / im if not os.path.isabs(im) else im)) for im in images]
    single = model.endswith("image-to-3d") and "multi" not in model          # single-image models take `image_url`, the multi-view ones `images_list`
    if single:
        payload["image_url"] = urls[0]
    else:
        payload["images_list"] = urls
    print(model, {k: v for k, v in payload.items() if k not in ("images_list", "image_url")}, f"{len(urls)} image(s)")
    if dry:
        return 0
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    b0 = film.balance()
    sub = film.call("/" + model, payload, "POST")
    rid = sub.get("request_id") or sub.get("id")
    if not rid:
        sys.exit(f"no request id: {sub}")
    print("submitted", rid, flush=True)
    for i in range(400):
        time.sleep(6)
        try:
            res = film.call(f"/predictions/{rid}/result")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                continue
            raise
        st = res.get("status")
        if i % 10 == 0:
            print("  ", st, flush=True)
        if st == "completed":
            files = []
            for j, u in enumerate(res.get("outputs") or []):
                if not isinstance(u, str):
                    continue
                ext = Path(u.split("?")[0]).suffix or ".bin"
                dst = out / f"out_{j}{ext}"
                urllib.request.urlretrieve(u, dst)
                files.append(dst.name)
                print("  saved", dst, dst.stat().st_size // 1024, "KB")
            cost = b0 - film.balance()
            (out / "receipt.json").write_text(json.dumps({"request_id": rid, "endpoint": model, "payload": {k: v for k, v in payload.items() if k not in ("images_list", "image_url")},
                                                          "n_images": len(urls), "outputs": res.get("outputs"), "files": files, "cost_usd": round(cost, 4),
                                                          "made": time.strftime("%Y-%m-%d")}, indent=1))
            print(f"done  cost ${cost:.3f}  balance ${film.balance():.3f}")
            return 0
        if st in ("failed", "cancelled"):
            sys.exit(f"{st}: {res.get('error')}")
    sys.exit("timed out")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["models", "run", "estimate"])
    ap.add_argument("model", nargs="?")
    ap.add_argument("--images", nargs="*", default=[])
    ap.add_argument("--out", default=".farm/3d/out")
    ap.add_argument("--set", action="append", dest="sets")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if not os.environ.get("MUAPI_API_KEY"):
        sys.exit("MUAPI_API_KEY is not set in the environment")
    film = _film()
    if a.cmd == "models":
        cmd_models(film)
    elif a.cmd == "estimate":
        cmd_estimate(film, a.model, a.sets)
    else:
        if not a.model or not a.images:
            sys.exit("run needs a model and --images")
        sys.exit(cmd_run(film, a.model, a.images, a.out, a.sets, a.dry_run))


if __name__ == "__main__":
    main()
