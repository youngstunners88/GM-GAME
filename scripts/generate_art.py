#!/usr/bin/env python3
"""Generate game art from assets/art-manifest.json via the Muapi Flux API.
Part of the game-aesthetics-forge skill
(.claude/skills/game-aesthetics-forge/SKILL.md — art-direction rules there).

Flow (verified): POST https://api.muapi.ai/api/v1/flux-dev-image with
header 'x-api-key', body {prompt,width,height,num_images}; returns request_id;
poll GET /api/v1/predictions/{id}/result until status==completed; image at
outputs[0]. Sprites are generated on a flat magenta (#FF00FF) field and
chroma-keyed to transparency, then downscaled with nearest-neighbour so the
pixel-art edges stay crisp.

Usage:
  python3 scripts/generate_art.py               generate everything missing
  python3 scripts/generate_art.py --force id…   regenerate specific ids
  python3 scripts/generate_art.py --dry-run     list what would run

Auth: MUAPI_API_KEY env only — never hardcoded (SEC-001).
"""
import json, os, sys, time, io, urllib.request, urllib.error
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets" / "art-manifest.json"
BASE = os.environ.get("MUAPI_BASE_URL", "https://api.muapi.ai/api/v1")


def key() -> str:
    k = os.environ.get("MUAPI_API_KEY", "")
    if not k:
        sys.exit("MUAPI_API_KEY not set")
    return k


def _req(url, method="GET", payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    r = urllib.request.Request(url, data=data, method=method, headers={
        "x-api-key": key(), "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=60) as resp:
        return json.loads(resp.read())


def generate(prompt: str, w: int, h: int) -> bytes | None:
    """Submit a Flux job, poll to completion, return the raw PNG bytes."""
    sub = _req(f"{BASE}/flux-dev-image", "POST",
               {"prompt": prompt, "width": w, "height": h, "num_images": 1})
    rid = sub.get("request_id") or sub.get("id")
    if not rid:
        print(f"  ! no request_id: {sub}"); return None
    for _ in range(120):  # ~6 min ceiling
        time.sleep(3)
        try:
            res = _req(f"{BASE}/predictions/{rid}/result")
        except urllib.error.HTTPError as e:
            if e.code == 404:  # result not ready yet on some paths
                continue
            raise
        st = res.get("status")
        if st == "completed":
            outs = res.get("outputs") or []
            if not outs:
                print("  ! completed but no outputs"); return None
            with urllib.request.urlopen(outs[0], timeout=60) as im:
                return im.read()
        if st == "failed":
            print(f"  ! generation failed: {res.get('error')}"); return None
    print("  ! timed out polling"); return None


def chroma_key(png: bytes, size: int, tol: int = 70) -> Image.Image:
    """Remove the background by flood-filling from the 4 corners: whatever
    colour the corners are (Flux renders 'magenta' as a soft pink field, not
    pure #FF00FF), erase contiguous regions within `tol` of it. Far more
    robust than a fixed-hue key — it removes the ACTUAL background and leaves
    the subject even if the subject contains some pink. Then trim, square-pad,
    nearest-downscale."""
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    w, h = img.size
    px = img.load()

    def close(c, ref):
        return abs(c[0] - ref[0]) + abs(c[1] - ref[1]) + abs(c[2] - ref[2]) <= tol * 3

    from collections import deque
    seen = [[False] * w for _ in range(h)]
    dq = deque()
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    refs = [px[cx, cy][:3] for cx, cy in corners]
    for (cx, cy) in corners:
        dq.append((cx, cy))
    while dq:
        x, y = dq.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        c = px[x, y]
        if not any(close(c, r) for r in refs):
            continue
        seen[y][x] = True
        px[x, y] = (0, 0, 0, 0)
        dq.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    # Secondary scrub: kill any leftover strongly-pink/magenta pixels (Flux
    # often adds a soft shadow ellipse in the key colour that the corner
    # flood-fill can't reach because the subject separates it). Conservative
    # thresholds so cyan/gold/teal/green subjects are never touched — only
    # true magenta (high R, high B, low G) goes.
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # Pink/magenta = red AND blue both clearly above green. Relative
            # test (not fixed g<120) catches desaturated pink shadows too,
            # while cyan (low R) and gold (low B) subjects never qualify.
            if a > 0 and r > 165 and b > 135 and g < r - 40 and g < b - 20:
                px[x, y] = (0, 0, 0, 0)

    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    side = max(img.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return sq.resize((size, size), Image.NEAREST)


def main() -> int:
    args = sys.argv[1:]
    dry = "--dry-run" in args
    force = set()
    if "--force" in args:
        force = {a for a in args[args.index("--force") + 1:] if not a.startswith("--")}

    man = json.loads(MANIFEST.read_text())
    ok = fail = skip = 0
    for a in man["assets"]:
        out = ROOT / a["path"]
        # Regenerate only if explicitly forced or the output is missing.
        if a["id"] not in force and out.exists():
            skip += 1; continue
        print(f"{a['id']}  -> {a['path']}  ({a['width']}x{a['height']} @ {a.get('out_size','full')})")
        if dry:
            continue
        # Cache the raw 512px download so re-keying/re-cropping never re-bills.
        cache = ROOT / ".art-cache" / f"{a['id']}.png"
        if not force and a["id"] not in force and cache.exists():
            png = cache.read_bytes()
        else:
            png = generate(a["prompt"], a["width"], a["height"])
            if png is None:
                fail += 1; continue
            cache.parent.mkdir(parents=True, exist_ok=True)
            cache.write_bytes(png)
        out.parent.mkdir(parents=True, exist_ok=True)
        if a.get("sprite"):
            chroma_key(png, a.get("out_size", 64), a.get("key_tol", 70)).save(out)
        else:
            im = Image.open(io.BytesIO(png)).convert("RGB")
            if a.get("out_w") and a.get("out_h"):
                im = im.resize((a["out_w"], a["out_h"]), Image.LANCZOS)
            im.save(out, quality=88)
        ok += 1
        print(f"  ok ({out.stat().st_size}B)")
    print(f"\ndone: {ok} generated, {skip} skipped, {fail} failed")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
