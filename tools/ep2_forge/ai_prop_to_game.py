#!/usr/bin/env python3
"""AI image-to-3D PROP -> game-ready GLB (skill ep2-set-piece-forge, step 4 "clean-up"; the vehicle version is ai_vehicle_to_game.py).

  python3 tools/ep2_forge/ai_prop_to_game.py --src .farm/3d/lift_cage_tripo/out_0.glb --out src/episode2/assets/mine_lift/mine_lift_cage.glb \
        --fit 3.8,0,3.8 --yscale 0.75 --cut=-1.35,1.35,0.15,3.4,-9,-1.55 --cut=-1.35,1.35,0.15,3.4,1.55,9 [--yaw 90] [--tex-base 1024] [--report]

What it does to a Tripo / Meshy GLB (one fused mesh, 4096 textures, arbitrary size):
  1. optional --yaw (degrees about +Y) to face the prop the way the chamber needs;
  2. scales it to --fit W,H,D metres (a 0 means "keep the proportion": the axes given set a uniform scale, or with two axes given each is
     stretched to its own size and a 0 axis takes their mean); --yscale multiplies the height afterwards (a tall AI cage made human-scale);
  3. stands it on y = 0 and centres it in x / z (or --anchor top: the top at y = 0, for a skull hung by its crown);
  4. --cut x0,x1,y0,y1,z0,z1 (metres, after scaling, repeatable) deletes every face whose centroid is inside the box: doorways in a cage,
     the back of a wall prop, a base it should not have;
  5. drops floating slivers (position-welded connectivity, < --min-piece triangles);
  6. re-encodes the textures: base colour --tex-base JPEG, metallic-roughness --tex-mr JPEG, normal map dropped unless --keep-normal.
Writes ONE mesh / ONE material. Import it with meshes/generate_lods=false + create_shadow_meshes=false and LOSSY texture imports
(docs/pck_budget_doc.md). Pure numpy + Pillow + pygltflib.
"""
import argparse
import importlib.util
import io
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from pygltflib import (GLTF2, Accessor, Asset, Attributes, Buffer, BufferView, Material, Mesh, Node, PbrMetallicRoughness, Primitive, Scene,
                       Texture, TextureInfo)
from pygltflib import Image as GImage

_spec = importlib.util.spec_from_file_location("ai_vehicle_to_game", Path(__file__).with_name("ai_vehicle_to_game.py"))
_veh = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_veh)
read_accessor, image_bytes = _veh.read_accessor, _veh.image_bytes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--fit", default="0,1,0", help="target W,H,D in metres (0 = keep proportion)")
    ap.add_argument("--yscale", type=float, default=1.0)
    ap.add_argument("--yaw", type=float, default=0.0)
    ap.add_argument("--ymap", default="", help="piecewise-linear height remap after scaling, 'src:dst,src:dst,...' (metres, from y=0): "
                    "squash a too-tall plank panel, stretch the bars above it")
    ap.add_argument("--anchor", default="bottom", choices=["bottom", "top", "centre"])
    ap.add_argument("--cut", action="append", default=[], help="x0,x1,y0,y1,z0,z1: delete faces with the centroid inside")
    ap.add_argument("--tex-base", type=int, default=1024)
    ap.add_argument("--tex-mr", type=int, default=256)
    ap.add_argument("--keep-normal", action="store_true")
    ap.add_argument("--min-piece", type=int, default=60)
    ap.add_argument("--name", default="PropModel")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()

    g = GLTF2().load(a.src)
    blob = g.binary_blob()
    prim = g.meshes[0].primitives[0]
    V = read_accessor(g, blob, prim.attributes.POSITION).astype(np.float64)
    N = read_accessor(g, blob, prim.attributes.NORMAL).astype(np.float64)
    UV = read_accessor(g, blob, prim.attributes.TEXCOORD_0).astype(np.float32)
    F = read_accessor(g, blob, prim.indices).reshape(-1, 3).astype(np.int64)
    print("source: %d verts %d tris, size %s" % (len(V), len(F), np.round(V.max(0) - V.min(0), 3).tolist()))

    yaw = np.radians(a.yaw)
    R = np.array([[np.cos(yaw), 0, np.sin(yaw)], [0, 1, 0], [-np.sin(yaw), 0, np.cos(yaw)]])
    V = V @ R.T
    N = N @ R.T
    size = V.max(0) - V.min(0)
    fit = np.array([float(x) for x in a.fit.split(",")])
    given = fit > 0
    if given.sum() == 0:
        sys.exit("--fit needs at least one non-zero axis")
    if given.sum() == 1:
        s = np.full(3, fit[given][0] / size[given][0])
    else:
        s = np.where(given, fit / np.maximum(size, 1e-9), 0.0)
        s[~given] = s[given].mean()
    s[1] *= a.yscale
    V = V * s
    N = N / s                                       # normals transform by the inverse scale
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    mn, mx = V.min(0), V.max(0)
    off = np.array([(mn[0] + mx[0]) / 2, {"bottom": mn[1], "top": mx[1], "centre": (mn[1] + mx[1]) / 2}[a.anchor], (mn[2] + mx[2]) / 2])
    V = V - off
    if a.ymap:
        pts = sorted([tuple(float(v) for v in kv.split(":")) for kv in a.ymap.split(",")])
        xs = np.array([0.0] + [p[0] for p in pts]); ys = np.array([0.0] + [p[1] for p in pts])
        top = V[:, 1].max()
        if xs[-1] < top:                                   # beyond the last knot: keep the last segment's slope 1 (shift)
            xs = np.append(xs, top); ys = np.append(ys, ys[-1] + top - xs[-2])
        slope = np.interp(V[:, 1], (xs[:-1] + xs[1:]) / 2, np.diff(ys) / np.maximum(np.diff(xs), 1e-9))
        V[:, 1] = np.interp(V[:, 1], xs, ys)
        N[:, 1] /= np.maximum(slope, 1e-3)                 # a vertical stretch tilts normals toward horizontal
        N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
        print("ymap knots", list(zip(xs.round(3).tolist(), ys.round(3).tolist())))
    print("game size %s (scale %s)" % (np.round(V.max(0) - V.min(0), 3).tolist(), np.round(s, 4).tolist()))

    keep = np.ones(len(F), bool)
    cent = V[F].mean(1)
    for c in a.cut:
        x0, x1, y0, y1, z0, z1 = [float(v) for v in c.split(",")]
        inside = (cent[:, 0] > x0) & (cent[:, 0] < x1) & (cent[:, 1] > y0) & (cent[:, 1] < y1) & (cent[:, 2] > z0) & (cent[:, 2] < z1)
        keep &= ~inside
        print("  cut %s: %d tris" % (c, int(inside.sum())))

    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    _, weld_id = np.unique(np.round(V, 4), axis=0, return_inverse=True)
    n_weld = int(weld_id.max()) + 1
    idx = np.where(keep)[0]
    tri = weld_id[F[idx]]
    r = np.concatenate([tri[:, 0], tri[:, 1], tri[:, 2]])
    c = np.concatenate([tri[:, 1], tri[:, 2], tri[:, 0]])
    _, lab = connected_components(coo_matrix((np.ones(len(r)), (r, c)), shape=(n_weld, n_weld)), directed=False)
    fl = lab[tri[:, 0]]
    cnt = np.bincount(fl)
    small = np.where((cnt > 0) & (cnt < a.min_piece))[0]
    if len(small):
        drop = np.isin(fl, small)
        keep[idx[drop]] = False
        print("  dropped %d floating piece(s), %d tris" % (len(small), int(drop.sum())))

    out = GLTF2()
    out.asset = Asset(version="2.0", generator="ep2 ai_prop_to_game")
    chunks, views, accs = [], [], []
    cursor = [0]

    def add_view(b, target=None):
        pad = (-len(b)) % 4
        views.append(BufferView(buffer=0, byteOffset=cursor[0], byteLength=len(b), target=target))
        chunks.append(b + b"\0" * pad)
        cursor[0] += len(b) + pad
        return len(views) - 1

    def add_acc(arr, ctype, atype, target, minmax=False):
        vi = add_view(arr.tobytes(), target)
        ac = Accessor(bufferView=vi, componentType=ctype, count=len(arr), type=atype)
        if minmax:
            ac.min = arr.min(0).astype(float).tolist()
            ac.max = arr.max(0).astype(float).tolist()
        accs.append(ac)
        return len(accs) - 1

    out.images, out.textures = [], []

    def add_image(im, sz, q, nm):
        im = im.resize((sz, sz), Image.LANCZOS) if im.size != (sz, sz) else im
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=q, optimize=True)
        vi = add_view(buf.getvalue())
        out.images.append(GImage(bufferView=vi, mimeType="image/jpeg", name=nm))
        out.textures.append(Texture(source=len(out.images) - 1))
        return len(out.textures) - 1

    pm = g.materials[0].pbrMetallicRoughness
    base = Image.open(io.BytesIO(image_bytes(g, blob, g.textures[pm.baseColorTexture.index].source))).convert("RGB")
    pbr = PbrMetallicRoughness(baseColorTexture=TextureInfo(index=add_image(base, a.tex_base, 86, "BaseColor")), baseColorFactor=[1, 1, 1, 1],
                               metallicFactor=1.0, roughnessFactor=1.0)
    if pm.metallicRoughnessTexture is not None:
        mr = Image.open(io.BytesIO(image_bytes(g, blob, g.textures[pm.metallicRoughnessTexture.index].source))).convert("RGB")
        pbr.metallicRoughnessTexture = TextureInfo(index=add_image(mr, a.tex_mr, 88, "MetalRough"))
    mat = Material(name=a.name, pbrMetallicRoughness=pbr, doubleSided=True)   # cut doorways expose the inside of AI shells
    if a.keep_normal and g.materials[0].normalTexture is not None:
        nim = Image.open(io.BytesIO(image_bytes(g, blob, g.textures[g.materials[0].normalTexture.index].source))).convert("RGB")
        nbuf = io.BytesIO()
        nim.resize((512, 512), Image.LANCZOS).save(nbuf, "PNG")
        vi = add_view(nbuf.getvalue())
        out.images.append(GImage(bufferView=vi, mimeType="image/png", name="Normal"))
        out.textures.append(Texture(source=len(out.images) - 1))
        from pygltflib import NormalMaterialTexture
        mat.normalTexture = NormalMaterialTexture(index=len(out.textures) - 1)
    out.materials = [mat]

    idx = np.where(keep)[0]
    used, inv = np.unique(F[idx].ravel(), return_inverse=True)
    big = len(used) >= 65535
    ia = add_acc(inv.astype(np.uint32 if big else np.uint16).reshape(-1, 1), 5125 if big else 5123, "SCALAR", 34963)
    pa = add_acc(V[used].astype(np.float32), 5126, "VEC3", 34962, True)
    na = add_acc(N[used].astype(np.float32), 5126, "VEC3", 34962)
    ua = add_acc(UV[used].astype(np.float32), 5126, "VEC2", 34962)
    out.meshes = [Mesh(name=a.name, primitives=[Primitive(attributes=Attributes(POSITION=pa, NORMAL=na, TEXCOORD_0=ua), indices=ia, material=0)])]
    out.nodes = [Node(name=a.name, mesh=0)]
    out.accessors, out.bufferViews = accs, views
    blobout = b"".join(chunks)
    out.buffers = [Buffer(byteLength=len(blobout))]
    out.scenes = [Scene(nodes=[0])]
    out.scene = 0
    out.set_binary_blob(blobout)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    out.save_binary(a.out)
    print("wrote %s  %.2f MB, %d tris, size %s" % (a.out, os.path.getsize(a.out) / 1048576, int(keep.sum()), np.round(V[used].max(0) - V[used].min(0), 3).tolist()))


if __name__ == "__main__":
    main()
