#!/usr/bin/env python3
"""Episode 2 runner asset forge — every textured asset the runner needs, in one run.

  python3 tools/ep2_forge/forge_runner_assets.py [--only name,name] [--skip-meshy] [--skip-textures]

1. Source stills: founder reference art where it exists (revolver, Lil Blunt, bear),
   crops of IMG_2492 for the cart and boulder, a MuAPI still for the pickaxe.
2. Meshy image-to-3D **with PBR** (base colour + normal + metallic/roughness) for all
   six, in parallel — the surface detail the founder asked for.
3. tools/meshy/shrink_glb.py: base colour kept at hero res, detail maps sized down,
   so the web pack stays under the itch gate.
4. MuAPI tileable surface textures for the tunnel (rock, timber, gold vein, gravel),
   made seamless here so they tile on the walls without visible joins.

Outputs land in src/episode2/assets/ (GLBs) and src/episode2/assets/textures/.
Keys (MESHY_API_KEY, MUAPI_API_KEY) are read from the environment, never printed.
Provenance is written to src/episode2/assets/forge_manifest.json.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from generate_art import generate  # noqa: E402  (MuAPI Flux caller, proven)

ASSETS = ROOT / "src/episode2/assets"
TEX = ASSETS / "textures"
WORK = ROOT / ".farm/forge"
REF = ROOT / "artifacts/episode2-gold-mine/references"
FREF = ROOT / "artifacts/founder-art/references"

# name -> (source still, polycount, base-colour max px, detail-map max px, texture prompt)
MODELS = {
    # The founder's Stage 3 still shows Lil Blunt HOLDING the revolver, so Meshy built the
    # whole character. A standalone still gets the gun on its own.
    "golden_revolver": ("muapi:single ornate golden six-shooter revolver, engraved gold frame and "
                        "cylinder, dark walnut grip, side view, isolated on pure white background, "
                        "centered, entire gun visible, studio lighting, game asset", 9000, 1024, 512,
                        "polished gold revolver, engraved gold frame, dark wood grip, brass cylinder"),
    "lil_blunt": ("crop:IMG_2492_cart-jump_bears-arrows-boulders.jpg:660,200,975,540", 12000, 1024, 512,
                  "cute cartoon green cannabis-leaf character, brass miner helmet with headlamp, brown "
                  "leather gloves and boots, grey trousers, leather tool belt"),
    "bear_archer": ("ref:REF_balaclava-bear-archer_turnaround.jpg", 12000, 1024, 512,
                    "brown fur bear, black knitted balaclava, rusty brass miner helmet with lamp, red "
                    "bandana, leather straps and pouches, wooden recurve bow"),
    "ore_cart": ("crop:IMG_2492_cart-jump_bears-arrows-boulders.jpg:830,515,1275,800", 8000, 1024, 512,
                 "weathered wooden mine cart planks, riveted dark iron bands and corners, iron wheels"),
    # A crop of IMG_2492 caught part of a cart and Meshy fused crates onto the rock.
    "boulder_rock": ("muapi:single large rough grey granite boulder, round, faint gold flecks, isolated "
                     "on pure white background, centered, whole rock visible, game asset", 3000, 512, 256,
                     "rough grey granite boulder with faint gold flecks"),
    "pickaxe": ("muapi:single miner's pickaxe, iron head, worn wooden handle, isolated on pure white "
                "background, centered, full object visible, studio lighting, game asset", 4000, 512, 256,
                "forged dark iron pickaxe head, worn oak handle with leather wrap"),
}

# name -> prompt. Made tileable after generation.
TEXTURES = {
    "rock_wall": "seamless tileable texture of dark rough mine tunnel rock wall, wet stone, subtle gold "
                 "mineral flecks, top-down orthographic, flat even lighting, no perspective, no objects",
    "gold_vein": "seamless tileable texture of dark rock with bright glittering gold ore veins running "
                 "through it, top-down orthographic, flat even lighting, no perspective",
    "timber": "seamless tileable texture of old weathered mine timber planks, dark brown wood grain, "
              "iron nails, top-down orthographic, flat even lighting, no perspective",
    "gravel": "seamless tileable texture of mine track ballast gravel and dirt, dark brown and grey "
              "stones, top-down orthographic, flat even lighting, no perspective",
}


def log(msg: str) -> None:
    print(msg, flush=True)


def still_for(name: str, spec: str) -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    out = WORK / f"{name}_src.png"
    kind, rest = spec.split(":", 1)
    if kind == "founder":
        return FREF / rest
    if kind == "ref":
        return REF / rest
    if kind == "crop":
        fn, box = rest.split(":")
        l, t, r, b = (int(v) for v in box.split(","))
        im = Image.open(REF / fn).convert("RGB").crop((l, t, r, b))
        s = 900 / max(im.size)
        im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS).save(out)
        return out
    if kind == "muapi":
        if not out.exists():
            png = generate(rest, 1024, 1024)
            if not png:
                raise RuntimeError(f"MuAPI failed for {name}")
            out.write_bytes(png)
        return out
    raise ValueError(spec)


def build_model(name: str) -> dict:
    spec, poly, bmax, amax, tprompt = MODELS[name]
    src = still_for(name, spec)
    raw = WORK / f"{name}_raw.glb"
    cmd = [sys.executable, str(ROOT / "tools/meshy/meshy_gen.py"), str(src), str(raw),
           "--polycount", str(poly), "--pbr", "--texture-prompt", tprompt]
    t0 = time.time()
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return {"name": name, "ok": False, "error": (r.stdout + r.stderr)[-400:]}
    task = next((l.split("task=")[-1] for l in r.stdout.splitlines() if "task=" in l), "")
    out = ASSETS / f"{name}.glb"
    s = subprocess.run([sys.executable, str(ROOT / "tools/meshy/shrink_glb.py"), str(raw), str(out),
                        "--max", str(bmax), "--aux-max", str(amax)], capture_output=True, text=True)
    if s.returncode != 0:
        return {"name": name, "ok": False, "error": s.stderr[-400:]}
    return {"name": name, "ok": True, "file": str(out.relative_to(ROOT)), "bytes": out.stat().st_size,
            "meshy_task": task.strip(), "source": spec, "polycount": poly, "pbr": True,
            "base_px": bmax, "detail_px": amax, "secs": int(time.time() - t0)}


def make_tileable(im: Image.Image) -> Image.Image:
    """Blend the image with its half-offset copy through a soft cross mask, so the
    edges match and it tiles without a visible seam."""
    w, h = im.size
    off = Image.new("RGB", (w, h))
    off.paste(im.crop((w // 2, h // 2, w, h)), (0, 0))
    off.paste(im.crop((0, h // 2, w // 2, h)), (w // 2, 0))
    off.paste(im.crop((w // 2, 0, w, h // 2)), (0, h // 2))
    off.paste(im.crop((0, 0, w // 2, h // 2)), (w // 2, h // 2))
    mask = Image.new("L", (w, h), 0)
    px = mask.load()
    for y in range(h):
        for x in range(w):
            dx = min(x, w - 1 - x) / (w / 2)
            dy = min(y, h - 1 - y) / (h / 2)
            px[x, y] = int(255 * max(0.0, min(1.0, min(dx, dy) * 3.0)))
    mask = mask.filter(ImageFilter.GaussianBlur(8))
    return Image.composite(im, off, mask)


def build_texture(name: str) -> dict:
    TEX.mkdir(parents=True, exist_ok=True)
    png = generate(TEXTURES[name], 1024, 1024)
    if not png:
        return {"name": name, "ok": False}
    raw = WORK / f"tex_{name}.png"
    raw.write_bytes(png)
    im = make_tileable(Image.open(raw).convert("RGB")).resize((512, 512), Image.LANCZOS)
    out = TEX / f"tex_{name}.jpg"
    im.save(out, "JPEG", quality=86, optimize=True)
    return {"name": name, "ok": True, "file": str(out.relative_to(ROOT)), "bytes": out.stat().st_size}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--skip-meshy", action="store_true")
    ap.add_argument("--skip-textures", action="store_true")
    a = ap.parse_args()
    only = set(filter(None, a.only.split(",")))
    jobs = []
    with ThreadPoolExecutor(max_workers=10) as ex:
        if not a.skip_meshy:
            jobs += [ex.submit(build_model, n) for n in MODELS if not only or n in only]
        if not a.skip_textures:
            jobs += [ex.submit(build_texture, n) for n in TEXTURES if not only or n in only]
        results = [j.result() for j in jobs]
    man = ASSETS / "forge_manifest.json"
    prev = json.loads(man.read_text()) if man.exists() else {}
    for r in results:
        log(("OK   " if r.get("ok") else "FAIL ") + json.dumps(r)[:300])
        if r.get("ok"):
            prev[r["name"]] = r
    man.write_text(json.dumps(prev, indent=2) + "\n")
    return 0 if all(r.get("ok") for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
