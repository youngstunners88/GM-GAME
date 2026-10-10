#!/usr/bin/env python3
"""AI image-to-3D VEHICLE -> game-ready GLB (skill ep2-hyperreal-scene-pipeline, step 4 "clean-up").

  python3 tools/ep2_forge/ai_vehicle_to_game.py --src .farm/3d/quad_tripo_mv/out_0.glb --out src/episode2/assets/vehicles/flame_quad_ai.glb
        [--tex-base 1024] [--tex-mr 256] [--keep-normal] [--no-wheels] [--nose=-x] [--report]

What it does to a Tripo / Meshy GLB (one fused mesh, 4096 textures, arbitrary frame and size):
  1. finds the four wheels from the mesh itself (ground-contact clusters -> tyre radius by the half-width iteration) - no hand measurement;
  2. rotates the nose to +Z (up stays +Y), scales so the tyre diameter is --tyre-d (1.0 m, the game's quad), stands it on the ground with the origin midway between the axles;
  3. cuts the four wheels out as their own nodes (Wheel_FL/FR/RL/RR, origin = hub centre, axle = local X) by face-centroid-in-cylinder, so the chamber can spin them;
  4. re-encodes the textures for the web pack: base colour --tex-base JPEG, metallic-roughness --tex-mr JPEG, the (nearly flat) normal map DROPPED unless --keep-normal;
  5. writes ONE material / five meshes (body + wheels) = 5 draw calls, no LODs, no tangents needed.
The geometry is NOT decimated (UV islands of AI meshes are confetti: collapsing edges tears the texture). Import it with `meshes/generate_lods=false`,
`meshes/create_shadow_meshes=false` and LOSSY texture imports (see docs/pck_budget_doc.md): a 1024 base colour costs 0.2 MB packed instead of 1.65 MB.
Pure numpy + Pillow + pygltflib; never opens Blender.
"""
import argparse
import io
import json
import math
import sys

import numpy as np
from PIL import Image
from pygltflib import (GLTF2, Accessor, Asset, Buffer, BufferView, Material, Mesh, Node, PbrMetallicRoughness, Primitive, Scene, Texture,
                       TextureInfo)
from pygltflib import Image as GImage

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_accessor(gltf, blob, idx):
    a = gltf.accessors[idx]
    bv = gltf.bufferViews[a.bufferView]
    dt = np.dtype(COMP[a.componentType])
    n = NCOMP[a.type]
    off = (bv.byteOffset or 0) + (a.byteOffset or 0)
    stride = bv.byteStride or dt.itemsize * n
    if stride == dt.itemsize * n:
        return np.frombuffer(blob, dtype=dt, count=a.count * n, offset=off).reshape(a.count, n).copy()
    return np.ndarray(shape=(a.count, n), dtype=dt, buffer=blob, offset=off, strides=(stride, dt.itemsize)).copy()


def image_bytes(gltf, blob, idx):
    im = gltf.images[idx]
    bv = gltf.bufferViews[im.bufferView]
    off = bv.byteOffset or 0
    return blob[off:off + bv.byteLength]


def find_wheels(V, ground_band=0.02, link=0.06):
    """Four ground-contact clusters -> hub centres and the tyre radius, all in the SOURCE frame (Y up, nose along +/-X, lateral Z)."""
    from scipy.cluster.hierarchy import fcluster, linkage
    ymin = float(V[:, 1].min())
    span = float(V[:, 0].max() - V[:, 0].min())
    low = V[V[:, 1] < ymin + ground_band * span]
    lab = fcluster(linkage(low[:, [0, 2]], "single"), t=link * span, criterion="distance")
    cl = []
    for k in np.unique(lab):
        p = low[lab == k]
        if len(p) >= 20:
            cl.append((float(p[:, 0].mean()), float(p[:, 2].mean())))
    cl.sort()
    if len(cl) != 4:
        sys.exit(f"expected 4 ground clusters, found {len(cl)}: {cl}")
    wheels = []
    for cx0, cz in cl:
        half = 0.10 * span                                   # first pass: only the middle of the bottom arc (certainly tyre)
        R = cx = cy = None
        for _ in range(4):
            sel = V[(np.abs(V[:, 2] - cz) < 0.03 * span) & (np.abs(V[:, 0] - cx0) < half) & (V[:, 1] < ymin + 0.2 * span)]
            bins = np.linspace(cx0 - half, cx0 + half, 31)
            pts = []
            for lo, hi in zip(bins[:-1], bins[1:]):
                m = (sel[:, 0] >= lo) & (sel[:, 0] < hi)
                if m.any():
                    pts.append(sel[m][np.argmin(sel[m][:, 1])][[0, 1]])   # the LOWEST point of every x-bin = the tyre's bottom silhouette
            pts = np.array(pts)
            A = np.c_[2 * pts[:, 0], 2 * pts[:, 1], np.ones(len(pts))]
            sol = np.linalg.lstsq(A, (pts ** 2).sum(1), rcond=None)[0]
            cx, cy = float(sol[0]), float(sol[1])
            R = float(np.sqrt(sol[2] + cx * cx + cy * cy))
            half = min(0.85 * R, 0.25 * span)               # next pass: the whole lower arc, still inside the tyre
        wheels.append([cx, ymin + R, cz, R])
    w = np.array(wheels)
    Rm = float(np.median(w[:, 3]))
    for row, (cx0, _) in zip(w, cl):
        if abs(row[3] - Rm) > 0.15 * Rm or abs(row[0] - cx0) > 0.3 * Rm:      # a bad circle fit (the lowest-point envelope caught something else): trust the other three
            row[0], row[3] = cx0, Rm
        row[1] = ymin + Rm
        row[3] = Rm
    return w, ymin


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--tex-base", type=int, default=1024)
    ap.add_argument("--tex-mr", type=int, default=256)
    ap.add_argument("--keep-normal", action="store_true")
    ap.add_argument("--no-wheels", action="store_true")
    ap.add_argument("--tyre-d", type=float, default=1.0, help="tyre outer diameter in metres after scaling")
    ap.add_argument("--nose", default="+x", choices=["+x", "-x", "+z", "-z"], help="which source axis the nose points along")
    ap.add_argument("--cut-r", type=float, default=1.03, help="wheel cut radius as a multiple of the tyre radius")
    ap.add_argument("--cut-half", type=float, default=0.30, help="wheel cut half-width along the axle, metres (after scaling)")
    ap.add_argument("--stray-r", type=float, default=1.08, help="a wheel face with a corner beyond this many tyre radii from the hub goes back to the body")
    ap.add_argument("--min-piece", type=int, default=150, help="connected pieces of a part with fewer triangles than this are dropped as floaters")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()

    g = GLTF2().load(a.src)
    blob = g.binary_blob()
    prim = g.meshes[0].primitives[0]
    V = read_accessor(g, blob, prim.attributes.POSITION).astype(np.float64)
    N = read_accessor(g, blob, prim.attributes.NORMAL).astype(np.float64)
    UV = read_accessor(g, blob, prim.attributes.TEXCOORD_0).astype(np.float32)
    F = read_accessor(g, blob, prim.indices).reshape(-1, 3).astype(np.int64)
    print("source: %d verts %d tris, bounds %s" % (len(V), len(F), np.round(V.max(0) - V.min(0), 3).tolist()))

    # --- 1. bring the nose to +X first so the wheel finder sees the canonical source frame -------------------------------------------------
    rot_to_x = {"+x": np.eye(3), "-x": np.diag([-1.0, 1.0, -1.0]), "+z": np.array([[0, 0, 1.0], [0, 1.0, 0], [-1.0, 0, 0]]), "-z": np.array([[0, 0, -1.0], [0, 1.0, 0], [1.0, 0, 0]])}[a.nose]
    V = V @ rot_to_x.T
    N = N @ rot_to_x.T
    wheels, ymin = find_wheels(V)
    R = float(np.median(wheels[:, 3]))
    scale = a.tyre_d / (2.0 * R)
    xmid = float((wheels[:, 0].min() + wheels[:, 0].max()) / 2.0)
    print("wheels (x,y,z,R) in source units:\n", np.round(wheels, 4), "\ntyre R %.4f -> scale %.4f, axle midpoint x %.4f" % (R, scale, xmid))

    # --- 2. source (nose +X, up +Y, lateral Z) -> game (nose +Z, up +Y, lateral X): x' = -z, z' = x --------------------------------------------
    def to_game(P):
        return np.stack([-P[:, 2], P[:, 1], P[:, 0]], -1)
    Vg = to_game(V - np.array([xmid, ymin, 0.0])) * scale
    Ng = to_game(N)
    Wg = to_game(wheels[:, :3] - np.array([xmid, ymin, 0.0])) * scale
    R_g = a.tyre_d / 2.0

    # name the wheels: front = +Z, left = -X (the model's left when facing the nose... Godot +X is the rider's LEFT when facing +Z, so FL = +X)
    order = {}
    for i, w in enumerate(Wg):
        order[("F" if w[2] > 0 else "R") + ("L" if w[0] > 0 else "R")] = i
    if len(order) != 4:
        sys.exit("could not name four wheels: %s" % Wg)

    parts = []   # (name, face mask, hub or None)
    cent = Vg[F].mean(1)
    assigned = np.zeros(len(F), bool)
    if not a.no_wheels:
        for nm in ["FL", "FR", "RL", "RR"]:
            hub = Wg[order[nm]]
            inside = (np.abs(cent[:, 0] - hub[0]) <= a.cut_half) & (np.hypot(cent[:, 1] - hub[1], cent[:, 2] - hub[2]) <= R_g * a.cut_r) & ~assigned
            # a face whose corners reach far outside the tyre (a suspension arm, a fender flap, a long sliver) must stay with the body, or it swings
            # around the hub like a loose part when the wheel spins
            vr = np.hypot(Vg[F][:, :, 1] - hub[1], Vg[F][:, :, 2] - hub[2]).max(1)
            vx = np.abs(Vg[F][:, :, 0] - hub[0]).max(1)
            stray = inside & ((vr > R_g * a.stray_r) | (vx > a.cut_half + 0.06))
            print("  %s: %d stray faces returned to the body" % (nm, int(stray.sum())))
            inside &= ~stray
            assigned |= inside
            parts.append(("Wheel_" + nm, inside, hub))
            print("  Wheel_%s: %d tris, hub %s" % (nm, int(inside.sum()), np.round(hub, 3).tolist()))
    parts.insert(0, ("Body", ~assigned, None))
    print("  Body: %d tris" % int((~assigned).sum()))

    # floaters: connected pieces of a part that are tiny (a stray flap / sliver left by the reconstruction) are dropped - the engine-side thorn lesson (ep2-rifle-realism)
    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components
    _, weld_id = np.unique(np.round(Vg, 4), axis=0, return_inverse=True)
    n_weld = int(weld_id.max()) + 1
    for pi, (name, mask, hub) in enumerate(parts):
        idx = np.where(mask)[0]
        if len(idx) == 0:
            continue
        # weld by POSITION first: AI meshes split every UV island into its own vertices, so index-connectivity would call each island a "piece"
        tri = weld_id[F[idx]]
        r = np.concatenate([tri[:, 0], tri[:, 1], tri[:, 2]])
        c = np.concatenate([tri[:, 1], tri[:, 2], tri[:, 0]])
        _, lab = connected_components(coo_matrix((np.ones(len(r)), (r, c)), shape=(n_weld, n_weld)), directed=False)
        fl = lab[tri[:, 0]]
        cnt = np.bincount(fl)
        small = np.where((cnt > 0) & (cnt < a.min_piece))[0]
        if len(small):
            drop = np.isin(fl, small)
            mask2 = mask.copy()
            mask2[idx[drop]] = False
            parts[pi] = (name, mask2, hub)
            print("  %s: dropped %d floating piece(s), %d tris" % (name, len(small), int(drop.sum())))

    # --- 3. new glTF: one material (base colour + metallic-roughness, normal dropped), five meshes ---------------------------------------------
    out = GLTF2()
    out.asset = Asset(version="2.0", generator="ep2 ai_vehicle_to_game")
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

    # textures
    base = Image.open(io.BytesIO(image_bytes(g, blob, g.textures[g.materials[0].pbrMetallicRoughness.baseColorTexture.index].source))).convert("RGB")
    mrinfo = g.materials[0].pbrMetallicRoughness.metallicRoughnessTexture
    mr = Image.open(io.BytesIO(image_bytes(g, blob, g.textures[mrinfo.index].source))).convert("RGB") if mrinfo is not None else None
    out.images, out.textures = [], []

    def add_image(im, size, q, nm):
        im = im.resize((size, size), Image.LANCZOS) if im.size != (size, size) else im
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=q, optimize=True)
        vi = add_view(buf.getvalue())
        out.images.append(GImage(bufferView=vi, mimeType="image/jpeg", name=nm))
        out.textures.append(Texture(source=len(out.images) - 1))
        return len(out.textures) - 1

    t_base = add_image(base, a.tex_base, 86, "BaseColor")
    pbr = PbrMetallicRoughness(baseColorTexture=TextureInfo(index=t_base), baseColorFactor=[1, 1, 1, 1], metallicFactor=1.0, roughnessFactor=1.0)
    if mr is not None:
        pbr.metallicRoughnessTexture = TextureInfo(index=add_image(mr, a.tex_mr, 88, "MetalRough"))
    mat = Material(name="QuadAI", pbrMetallicRoughness=pbr, doubleSided=False)
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

    out.nodes = [Node(name="QuadModel", children=[])]
    out.meshes = []
    for name, mask, hub in parts:
        idx = np.where(mask)[0]
        if len(idx) == 0:
            continue
        used, inv = np.unique(F[idx].ravel(), return_inverse=True)
        P = Vg[used].copy()
        if hub is not None:
            P -= hub
        nrm = Ng[used]
        nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
        tri = inv.reshape(-1, 3)
        ia = add_acc(tri.astype(np.uint16 if len(used) < 65535 else np.uint32).ravel().reshape(-1, 1), 5123 if len(used) < 65535 else 5125, "SCALAR", 34963)
        pa = add_acc(P.astype(np.float32), 5126, "VEC3", 34962, True)
        na = add_acc(nrm.astype(np.float32), 5126, "VEC3", 34962)
        ua = add_acc(UV[used].astype(np.float32), 5126, "VEC2", 34962)
        from pygltflib import Attributes
        out.meshes.append(Mesh(name=name, primitives=[Primitive(attributes=Attributes(POSITION=pa, NORMAL=na, TEXCOORD_0=ua), indices=ia, material=0)]))
        node = Node(name=name, mesh=len(out.meshes) - 1)
        if hub is not None:
            node.translation = [float(hub[0]), float(hub[1]), float(hub[2])]
        out.nodes.append(node)
        out.nodes[0].children.append(len(out.nodes) - 1)
    out.accessors, out.bufferViews = accs, views
    blobout = b"".join(chunks)
    out.buffers = [Buffer(byteLength=len(blobout))]
    out.scenes = [Scene(nodes=[0])]
    out.scene = 0
    out.set_binary_blob(blobout)
    out.save_binary(a.out)
    import os
    print("wrote %s  %.2f MB  (%d meshes, textures %d / %d)" % (a.out, os.path.getsize(a.out) / 1048576, len(out.meshes), a.tex_base, a.tex_mr))
    if a.report:
        print(json.dumps({"scale": scale, "tyre_r_src": R, "axle_mid_x_src": xmid, "wheels_game": np.round(Wg, 4).tolist(), "size_game": np.round(Vg.max(0) - Vg.min(0), 3).tolist()}))


if __name__ == "__main__":
    main()
