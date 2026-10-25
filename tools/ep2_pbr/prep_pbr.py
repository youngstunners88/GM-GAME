#!/usr/bin/env python3
"""Prepare the Episode 2 PBR material sets (founder 2026-10-25: "hyperreal ... not grey primitives") for the streamed extras pack.

    python3 tools/ep2_pbr/prep_pbr.py <downloads_dir>        # needs ImageMagick 7 (`magick`)

<downloads_dir>/<set>/{albedo,normal,rough,ao,metal}.jpg come from Poly Haven / ambientCG (both CC0 - commercial use, no attribution
required; ids recorded below and in pbr_sets.json). Writes src/episode2/extras/pbr/<set>/:
  albedo.jpg   sRGB base colour
  normal.jpg   OpenGL-convention normal map (Godot's convention: green up)
  orm.jpg      R = ambient occlusion, G = roughness, B = metalness (one texture instead of three; Ep2Pbr reads the channels)
and src/episode2/extras/pbr/pbr_sets.json with each set's source, licence, size and its MEAN LINEAR ALBEDO - Ep2Pbr divides the
authored material colour by it, so a dressed material keeps the brightness and hue the founder approved and only gains surface detail.
Hero metals/woods seen at arm's length stay 1024 px; the rest are 512 px to keep the streamed download small. Only sets a caller
maps to (Ep2Pbr.BY_NAME or an Ep2Pbr.replace call) belong here: every set ships in the streamed pack.
The .jpg.import presets next to the maps are TRACKED (.gitignore exception): lossy WebP 0.85 + mipmaps, no 3D detection. CI's
default re-import would be lossless without mipmaps - several times the download, and shimmering at a distance.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "src", "episode2", "extras", "pbr")

SETS = {   # set id: (source, size px)
    "brass_worn": ("ambientcg:Metal048B", 1024),
    "steel_blued": ("ambientcg:Metal063", 1024),
    "wood_walnut": ("polyhaven:smoked_walnut_veneer", 1024),
    "wood_dark": ("polyhaven:dark_wood", 1024),
    "planks_weathered": ("polyhaven:old_planks_02", 1024),
    "planks_raw": ("polyhaven:raw_plank_wall", 1024),
    "stone_dressed": ("polyhaven:sandstone_blocks_08", 1024),
    "iron_painted": ("polyhaven:rusty_metal_02", 512),
    "leather_brown": ("polyhaven:brown_leather", 512),
    "brick_red": ("polyhaven:large_red_bricks", 512),
    "stone_rustic": ("polyhaven:rustic_stone_wall_02", 512),
    "fabric_burlap": ("ambientcg:Fabric066", 512),
    "rope": ("ambientcg:Rope001", 512),
}
DOWNLOAD_NAME = {"fabric_burlap": "fabric_burlap_b"}     # the download folder when it differs from the set id


def magick(*args):
    subprocess.run(["magick", *args], check=True)


def mean_linear(path):
    out = subprocess.run(["magick", path, "-colorspace", "RGB", "-resize", "1x1!", "-format", "%[fx:r] %[fx:g] %[fx:b]", "info:"],
                         check=True, capture_output=True, text=True).stdout.split()
    return [round(float(x), 4) for x in out]


def main() -> int:
    src_root = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    manifest = {"licence": "CC0 1.0 (Poly Haven, ambientCG): commercial use, no attribution required", "sets": {}}
    for sid, (source, px) in SETS.items():
        src = os.path.join(src_root, DOWNLOAD_NAME.get(sid, sid))
        dst = os.path.join(OUT, sid)
        os.makedirs(dst, exist_ok=True)
        size = f"{px}x{px}!"
        magick(os.path.join(src, "albedo.jpg"), "-resize", size, "-quality", "88", os.path.join(dst, "albedo.jpg"))
        magick(os.path.join(src, "normal.jpg"), "-resize", size, "-quality", "92", os.path.join(dst, "normal.jpg"))
        chans = []
        for key, fill in (("ao", "white"), ("rough", "gray70"), ("metal", "black")):
            p = os.path.join(src, key + ".jpg")
            if os.path.exists(p):
                chans += ["(", p, "-colorspace", "Gray", "-resize", size, ")"]
            else:
                chans += ["(", "-size", f"{px}x{px}", f"xc:{fill}", "-colorspace", "Gray", ")"]
        magick(*chans, "-combine", "-colorspace", "sRGB", "-quality", "90", os.path.join(dst, "orm.jpg"))
        entry = {"source": source, "px": px, "mean_albedo_linear": mean_linear(os.path.join(dst, "albedo.jpg")),
                 "has_metal_map": os.path.exists(os.path.join(src, "metal.jpg")), "has_ao_map": os.path.exists(os.path.join(src, "ao.jpg"))}
        manifest["sets"][sid] = entry
        print(sid, entry)
    with open(os.path.join(OUT, "pbr_sets.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    total = sum(os.path.getsize(os.path.join(dp, fn)) for dp, _, fns in os.walk(OUT) for fn in fns)
    print("pbr total %.2f MB in %s" % (total / 1e6, os.path.relpath(OUT, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
