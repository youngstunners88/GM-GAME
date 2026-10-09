#!/usr/bin/env python3
"""Muapi GPT-IMAGE reference generator for the Fort Knox / AwesomeX PREP pass (skill ep2-hyperreal-scene-pipeline).

  python3 tools/ep2_forge/muapi_ref.py list                       the briefs, their views and the cost
  python3 tools/ep2_forge/muapi_ref.py gen exit_road              every view of one item (skips views that already exist)
  python3 tools/ep2_forge/muapi_ref.py gen spy_point --view hero  one view
  python3 tools/ep2_forge/muapi_ref.py gen all [--force] [--dry-run]
  python3 tools/ep2_forge/muapi_ref.py board flame_quad           contact sheet of an item's views (for you / a vision model to LOOK at)

Reads tools/ep2_forge/fort_knox_refs.json. A `t2i` view is GPT Image 2 text-to-image; an `i2i` view is GPT Image 2 image-to-image fed
the item's earlier view (so a turnaround or an "after the explosion" shot keeps the SAME subject) plus any repo images in `refs`
(e.g. the founder's Inferno Bull sheet). Output: <out_dir>/<id>/<view>.jpg (<=1600 px, q88) + <view>.json receipt (request id,
endpoint, payload, cost). Key: MUAPI_API_KEY from the environment only - never printed, never written. Reuses tools/ep2_film/muapi_film.py.
Cost seen 2026-10-09: ~$0.09 per 2K image at quality=high.
"""
import argparse
import hashlib
import importlib.util
import json
import os
import sys
import time
import urllib.error
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "tools/ep2_forge/fort_knox_refs.json"


def _film():
    spec = importlib.util.spec_from_file_location("muapi_film", ROOT / "tools/ep2_film/muapi_film.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def load_spec():
    return json.loads(SPEC.read_text())


def lock_text(spec, name):
    return spec.get({"env": "style_lock_env", "object": "style_lock_object", "scene": "style_lock_scene"}[name], "")


def out_paths(spec, item_id, view):
    d = ROOT / spec["out_dir"] / item_id
    return d / f"{view}.jpg", d / f"{view}.json"


def to_jpeg(png, dst, max_w=1600, q=88):
    im = Image.open(png).convert("RGB")
    if im.width > max_w:
        im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "JPEG", quality=q, optimize=True)
    return im.size


def upload_cached(film, path):
    """Upload a repo image to Muapi once (cached by content hash in the item folder's refs cache)."""
    cache_file = ROOT / ".farm/muapi_upload_cache.json"
    cache = json.loads(cache_file.read_text()) if cache_file.exists() else {}
    b = Path(path).read_bytes()
    h = hashlib.sha1(b).hexdigest()
    if h not in cache:
        cache[h] = film.upload(path)
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps(cache, indent=1))
    return cache[h]


def cmd_list(spec):
    n = 0
    for it in spec["items"]:
        print(f"{it['id']:20s} {it['title']}")
        for v in it["views"]:
            jpg, _ = out_paths(spec, it["id"], v["name"])
            n += 1
            print(f"   {v['name']:18s} {v['kind']} {v['aspect']:5s} {'DONE' if jpg.exists() else 'todo'}  {'from ' + v['from'] if v.get('from') else ''}")
    print(f"{n} views, ~${n * 0.09:.2f} at 2K/high")


def gen_view(film, spec, item, view, force=False, dry=False):
    jpg, rec = out_paths(spec, item["id"], view["name"])
    if jpg.exists() and not force:
        print(f"  skip {item['id']}/{view['name']} (exists)")
        return True
    prompt = lock_text(spec, view.get("lock", "env")) + " " + view["prompt"]
    payload = {"prompt": prompt, "aspect_ratio": view.get("aspect", "16:9"), "resolution": view.get("res", "2K"),
               "quality": view.get("quality", "high")}
    endpoint = spec["model_t2i"]
    if view["kind"] == "i2i":
        endpoint = spec["model_i2i"]
        urls = []
        if view.get("from"):
            _, prev_rec = out_paths(spec, item["id"], view["from"])
            if not prev_rec.exists():
                print(f"  !! {item['id']}/{view['name']} needs {view['from']} first")
                return False
            urls.append(json.loads(prev_rec.read_text())["url"])
        for r in view.get("refs", []):
            urls.append("(upload)" if dry else upload_cached(film, ROOT / r))
        payload["images_list"] = urls
    print(f"  {item['id']}/{view['name']}  {endpoint}  {payload['aspect_ratio']} {payload['resolution']} {payload['quality']}")
    if dry:
        print("     prompt:", prompt[:160].replace("\n", " "), "...")
        return True
    tmp = ROOT / ".farm/refs_tmp" / f"{item['id']}_{view['name']}.png"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    b0 = film.balance()
    try:
        rid = film.run(endpoint, payload, tmp, tries=120, every=4)
    except SystemExit as e:
        print("     FAILED:", e)
        return False
    except urllib.error.HTTPError as e:
        print("     HTTP", e.code, e.read()[:600].decode("utf-8", "replace"))
        return False
    cost = b0 - film.balance()
    size = to_jpeg(tmp, jpg)
    meta = json.loads(Path(str(tmp) + ".json").read_text())
    rec.write_text(json.dumps({"request_id": rid, "endpoint": endpoint, "payload": {k: v for k, v in payload.items() if k != "images_list"},
                               "url": meta["url"], "cost_usd": round(cost, 4), "size": size, "made": time.strftime("%Y-%m-%d")}, indent=1))
    print(f"     -> {jpg.relative_to(ROOT)} {size[0]}x{size[1]}  ${cost:.3f}")
    return True


def cmd_gen(spec, target, only_view, force, dry):
    film = _film()
    items = spec["items"] if target == "all" else [i for i in spec["items"] if i["id"] == target]
    if not items:
        sys.exit(f"no item '{target}' (python3 {sys.argv[0]} list)")
    ok = True
    for it in items:
        print(it["id"], "-", it["title"])
        for v in it["views"]:
            if only_view and v["name"] != only_view:
                continue
            ok = gen_view(film, spec, it, v, force, dry) and ok
    if not dry:
        print(f"balance ${film.balance():.3f}")
    return ok


def cmd_board(spec, item_id):
    it = next(i for i in spec["items"] if i["id"] == item_id)
    ims = []
    for v in it["views"]:
        jpg, _ = out_paths(spec, item_id, v["name"])
        if jpg.exists():
            ims.append((v["name"], Image.open(jpg).convert("RGB")))
    if not ims:
        sys.exit("nothing generated yet")
    h = 540
    tiles = [(n, im.resize((round(im.width * h / im.height), h), Image.LANCZOS)) for n, im in ims]
    w = sum(t.width for _, t in tiles) + 8 * (len(tiles) + 1)
    board = Image.new("RGB", (w, h + 56), (24, 24, 24))
    d = ImageDraw.Draw(board)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    x = 8
    for n, t in tiles:
        board.paste(t, (x, 48))
        d.text((x + 6, 12), f"{item_id} / {n}", fill=(255, 220, 140), font=font)
        x += t.width + 8
    dst = ROOT / spec["out_dir"] / item_id / "_board.jpg"
    board.save(dst, "JPEG", quality=85)
    print(dst.relative_to(ROOT))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["list", "gen", "board"])
    ap.add_argument("target", nargs="?")
    ap.add_argument("--view")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    spec = load_spec()
    if a.cmd == "list":
        cmd_list(spec)
    elif a.cmd == "gen":
        if not a.target:
            sys.exit("gen needs an item id or 'all'")
        if not a.dry_run and not os.environ.get("MUAPI_API_KEY"):
            sys.exit("MUAPI_API_KEY is not set in the environment")
        sys.exit(0 if cmd_gen(spec, a.target, a.view, a.force, a.dry_run) else 1)
    else:
        cmd_board(spec, a.target)


if __name__ == "__main__":
    main()
