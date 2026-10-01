#!/usr/bin/env python3
"""Concept images for Inferno Bull's hideout props (skill ep2-hideout-set-dressing), via Muapi Flux.

Each prop is drawn ISOLATED on a plain white background so Meshy image-to-3d gets a clean silhouette; the
poster and the cowhide are textures used directly. Output: .farm/hideout/concepts/<id>.png
  python3 tools/ep2_forge/hideout_concepts.py [id ...]
Auth: MUAPI_API_KEY from the environment only.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from generate_art import generate  # noqa: E402  (Flux submit + poll, verified)

OUT = Path(".farm/hideout/concepts")
STYLE = ("stylized realistic 3D game asset render, warm golden firelight, rich saturated colors, highly detailed, "
         "isolated on a plain pure white background, entire object in frame, three-quarter view, no text")
PROPS = {
    "gatling": ("side view of a single 1880s Colt Gatling gun, a long cluster of six steel barrels pointing to the "
                "left held by brass rings, polished brass breech housing with a hand crank, brass ammunition drum on "
                "top, mounted on a sturdy wooden tripod, stylized realistic 3D game asset render, warm firelight, rich "
                "colors, highly detailed, isolated on a plain pure white background, entire object in frame, "
                "side profile view, no text", 1024, 1024),
    "bear_standing": ("a taxidermy brown grizzly bear standing upright on its hind legs on a wooden plinth, roaring "
                      "with its mouth open, front paws raised with claws, thick brown fur, " + STYLE, 1024, 1024),
    "bear_head": ("a taxidermy brown grizzly bear head trophy mounted on a dark wooden shield plaque, roaring with its "
                  "mouth open, sharp teeth, thick brown fur, front view, " + STYLE, 1024, 1024),
    "ore_cart": ("an old west wooden mining ore cart on four iron wheels, iron straps and rivets, heaped full of "
                 "shiny gold bars and gold nuggets, " + STYLE, 1024, 1024),
    "cauldron": ("a large cast-iron smelting crucible pot brimming with glowing orange molten gold, riveted iron "
                 "bands, two side handles, standing on a round stone base, " + STYLE, 1024, 1024),
    "poster": ("vintage 1890s wild west saloon pin-up poster, painted illustration of a glamorous smiling woman with "
               "dark curly hair in a long red ruffled dress with black lace, sitting with one leg crossed, art nouveau "
               "ornamental border, aged cream paper, warm colors, the words MISS GOLDIE at the top, full poster in "
               "frame, flat front view", 768, 1152),
    "cowhide": ("top-down flat seamless texture of a brown and white spotted cowhide leather rug, natural hair "
                "texture, large irregular dark brown patches on cream white, full frame, no background", 1024, 1024),
}


def main() -> int:
    want = sys.argv[1:] or list(PROPS)
    OUT.mkdir(parents=True, exist_ok=True)
    for pid in want:
        prompt, w, h = PROPS[pid]
        print(f"[{pid}] generating {w}x{h}", flush=True)
        png = generate(prompt, w, h)
        if png:
            (OUT / f"{pid}.png").write_bytes(png)
            print(f"[{pid}] OK {len(png)} B", flush=True)
        else:
            print(f"[{pid}] FAILED", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
