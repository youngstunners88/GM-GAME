#!/usr/bin/env python3
"""Install the founder's own 3D props (Drive doc "3D Assets") into src/episode2/assets, baked to the code's conventions
so no per-prop transform constants are needed (skill ep2-founder-asset-swap):
  winchester_1886.glb  Meshy wUN2J2  length 1.2 m, muzzle +Z, stock -Z, centred
  miner_helmet.glb     Meshy tVC8jD  brim radius ~0.33, base y=0, lamp +Z
  whiskey_glass.glb    Meshy LKhotS  UNIT height (1.0), base y=0, centred on x/z  (code scales it)
  btc_coin.glb         Meshy oLKt9Y  UNIT diameter (1.0), face normal +Z, centred (code scales it)
Source GLBs come from `python3 tools/meshy/pull_share.py <code> --remesh 0 --name f_<slot>` (.farm/share/f_<slot>/game.glb).
Textures are then shrunk (the web pck budget, ep2-meshy-studio) with tools/meshy/shrink_glb.py.
"""
import subprocess, sys
from pathlib import Path
import numpy as np, trimesh
from trimesh.transformations import rotation_matrix as rot

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/episode2/assets"

def load(slot):
    return trimesh.load(ROOT / f".farm/share/f_{slot}/game.glb", force="scene")

def bounds(sc):
    return sc.bounds

def put(sc, name, tex, aux):
    tmp = ROOT / f".farm/share/{name}.tmp.glb"
    sc.export(tmp)
    subprocess.check_call([sys.executable, str(ROOT / "tools/meshy/shrink_glb.py"), str(tmp), str(OUT / name),
                           "--max", str(tex), "--aux-max", str(aux)])
    tmp.unlink()

# rifle: model length is X (muzzle -X). +90 deg about Y sends -X to +Z.
sc = load("rifle")
sc.apply_transform(rot(np.pi / 2, [0, 1, 0]))
sc.apply_scale(1.2)
b = bounds(sc); sc.apply_translation(-(b[0] + b[1]) / 2)
put(sc, "winchester_1886.glb", 1024, 128)

sc = load("helmet")
sc.apply_scale(0.73)
b = bounds(sc); sc.apply_translation([-(b[0][0] + b[1][0]) / 2, -b[0][1], -(b[0][2] + b[1][2]) / 2])
put(sc, "miner_helmet.glb", 768, 128)

sc = load("whiskey")
b = bounds(sc); sc.apply_scale(1.0 / (b[1][1] - b[0][1]))
b = bounds(sc); sc.apply_translation([-(b[0][0] + b[1][0]) / 2, -b[0][1], -(b[0][2] + b[1][2]) / 2])
put(sc, "whiskey_glass.glb", 512, 128)

sc = load("bitcoin")
b = bounds(sc); sc.apply_scale(1.0 / max(b[1][0] - b[0][0], b[1][1] - b[0][1]))
b = bounds(sc); sc.apply_translation(-(b[0] + b[1]) / 2)
put(sc, "btc_coin.glb", 512, 128)
print("installed")
