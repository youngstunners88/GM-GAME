#!/usr/bin/env python3
"""Poly Haven (CC0, no API key) helper for Episode 2 lighting / materials / props. Skill: ep2-polyhaven-assets.

  ph.py search  --type hdris|textures|models [--cat studio] [--tag softbox] [--limit 10]
  ph.py info    <asset_id>
  ph.py get     <asset_id> [--res 1k] [--fmt hdr|exr|jpg|png|blend|gltf|fbx] [--out DIR]
  ph.py sources                          list what was downloaded (provenance log)

Downloads go to ~/.cache/gm-game/polyhaven (NOT the repo / pack); every download is appended to the provenance log.
Assets are CC0 (public domain, commercial use OK, attribution not required). They are for RENDERS/TOOLS and set dressing;
anything that enters the game pack must still pass the 190 MiB budget (ep2-asset-forge) and be listed in the log.
"""
import argparse, json, os, sys, time, urllib.parse, urllib.request
API = "https://api.polyhaven.com"
CACHE = os.path.expanduser("~/.cache/gm-game/polyhaven")
LOG = os.path.join(CACHE, "sources.jsonl")
UA = {"User-Agent": "gm-game-polyhaven/1.0 (Lil Blunt Adventure tooling)"}  # the API asks for an identifying UA

def get(path, **q):
    url = API + path + (("?" + urllib.parse.urlencode(q)) if q else "")
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40) as r:
        return json.loads(r.read())

def search(a):
    q = {"t": a.type}
    if a.cat: q["c"] = a.cat
    d = get("/assets", **q)
    rows = [(v.get("download_count", 0), k, v) for k, v in d.items() if not a.tag or a.tag.lower() in [t.lower() for t in v.get("tags", [])]]
    for dl, k, v in sorted(rows, reverse=True)[:a.limit]:
        print(f"{k:30} dl={dl:>7} cats={','.join(v.get('categories', [])[:4])} tags={','.join(v.get('tags', [])[:5])}")
    print(f"({len(rows)} matches)")

def info(a):
    v = get("/info/" + a.id)
    print(json.dumps({k: v.get(k) for k in ("name", "type", "authors", "categories", "tags", "download_count", "max_resolution", "evs_cap")}, indent=1))

def pick(files, a):
    """Walk the /files tree for a (res, fmt) leaf: {'url','size','md5'}."""
    def leaf(node):
        return isinstance(node, dict) and "url" in node
    def walk(node, path):
        if leaf(node): yield path, node
        elif isinstance(node, dict):
            for k, v in node.items(): yield from walk(v, path + [k])
    hits = [(p, n) for p, n in walk(files, []) if a.res in p and (not a.fmt or a.fmt in p or n["url"].lower().endswith("." + a.fmt))]
    return hits

def download(a):
    files = get("/files/" + a.id)
    hits = pick(files, a)
    if not hits:
        sys.exit("no file for res=%s fmt=%s; tree top keys: %s" % (a.res, a.fmt, list(files)[:12]))
    # smallest matching file first (HDRI/texture maps are one file each; models bring includes)
    hits.sort(key=lambda h: h[1].get("size", 0))
    out = os.path.join(a.out or CACHE, a.id); os.makedirs(out, exist_ok=True)
    done = []
    for path, n in hits[:1] if a.type_hint in ("hdris",) else hits[:12]:
        dst = os.path.join(out, os.path.basename(urllib.parse.urlparse(n["url"]).path))
        if not os.path.exists(dst):
            with urllib.request.urlopen(urllib.request.Request(n["url"], headers=UA), timeout=120) as r, open(dst, "wb") as f:
                f.write(r.read())
        done.append({"path": dst, "bytes": os.path.getsize(dst), "tree": "/".join(path), "url": n["url"]})
    os.makedirs(CACHE, exist_ok=True)
    with open(LOG, "a") as f:
        f.write(json.dumps({"id": a.id, "when": time.strftime("%Y-%m-%d %H:%M:%S"), "license": "CC0", "files": done}) + "\n")
    for d in done: print("saved", d["path"], d["bytes"], "bytes")

def sources(_):
    print(open(LOG).read() if os.path.exists(LOG) else "(nothing downloaded yet)")

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); sp = ap.add_subparsers(dest="cmd", required=True)
    s = sp.add_parser("search"); s.add_argument("--type", default="hdris"); s.add_argument("--cat"); s.add_argument("--tag"); s.add_argument("--limit", type=int, default=10); s.set_defaults(f=search)
    i = sp.add_parser("info"); i.add_argument("id"); i.set_defaults(f=info)
    g = sp.add_parser("get"); g.add_argument("id"); g.add_argument("--res", default="1k"); g.add_argument("--fmt", default=""); g.add_argument("--out"); g.add_argument("--type-hint", dest="type_hint", default="hdris"); g.set_defaults(f=download)
    sp.add_parser("sources").set_defaults(f=sources)
    a = ap.parse_args(); a.f(a)
