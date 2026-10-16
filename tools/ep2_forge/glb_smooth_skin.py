#!/usr/bin/env python3
"""Weld and smooth the skin weights of a GLB in place (mesh, skeleton and clips stay byte-identical).

    python3 tools/ep2_forge/glb_smooth_skin.py in.glb out.glb [--iters 5] [--keep 0.6] [--max-edge 0.35]
        [--pin x0,y0,z0,x1,y1,z1:bone ...] [--pin-parts x0,y0,z0,x1,y1,z1:bone:maxverts:fromA+fromB ...]

Why: a mesh whose weights were transferred from another rig ("nearest old vertex") has (a) UV-seam duplicates with
different weights, which crack open when posed, and (b) noisy weights that stretch thin shells into slivers.
Steps: average the weights of vertices that share a position, Laplacian-smooth them over the surface (blend `keep`
of the vertex's own weights with its neighbours', skipping edges longer than `max-edge` of the mesh height so
separate parts do not leak into each other), keep the top 4 influences, renormalise, write back.
--pin region:bone[:fromA+fromB] forces every vertex inside the box (in rest-pose metres, before any node transform) to one bone (with `from`, only vertices originally >50% on those joints).
--pin-parts does the same but only for detached mesh pieces (connected components) of at most maxverts welded
vertices whose centre is inside the box and whose original weight is mostly (>50%) on the `from` joints, so a quiver's loose arrows follow the spine without grabbing the arms.
"""
import argparse
import json
import struct
from pathlib import Path

import numpy as np

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(b: bytes):
    off, j, blob, blob_off = 12, None, b"", 0
    while off < len(b):
        n, t = struct.unpack("<II", b[off:off + 8])
        if t == 0x4E4F534A:
            j = json.loads(b[off + 8:off + 8 + n])
        elif t == 0x004E4942:
            blob_off = off + 8
            blob = b[off + 8:off + 8 + n]
        off += 8 + n
    return j, bytearray(blob), blob_off


def acc_slice(j, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    dt, nc = CT[a["componentType"]], NC[a["type"]]
    stride = bv.get("byteStride") or dt().itemsize * nc
    return a, bv.get("byteOffset", 0) + a.get("byteOffset", 0), stride, dt, nc


def read_acc(j, blob, i):
    a, start, stride, dt, nc = acc_slice(j, i)
    isz = dt().itemsize * nc
    raw = np.frombuffer(bytes(blob), dtype=np.uint8)
    rows = np.stack([raw[start + k * stride:start + k * stride + isz] for k in range(a["count"])]) \
        if stride != isz else raw[start:start + a["count"] * isz].reshape(a["count"], isz)
    return rows.copy().view(dt).reshape(a["count"], nc)


def write_acc(j, blob, i, arr):
    a, start, stride, dt, nc = acc_slice(j, i)
    isz = dt().itemsize * nc
    data = np.ascontiguousarray(arr.astype(dt)).view(np.uint8).reshape(a["count"], isz)
    for k in range(a["count"]):
        blob[start + k * stride:start + k * stride + isz] = data[k].tobytes()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", type=Path)
    ap.add_argument("dst", type=Path)
    ap.add_argument("--iters", type=int, default=5)
    ap.add_argument("--keep", type=float, default=0.6)
    ap.add_argument("--max-edge", type=float, default=0.35, help="fraction of mesh height; longer edges do not smooth")
    ap.add_argument("--pin", action="append", default=[], metavar="x0,y0,z0,x1,y1,z1:bone")
    ap.add_argument("--pin-parts", action="append", default=[], metavar="x0,y0,z0,x1,y1,z1:bone:maxverts:fromjoints")
    ap.add_argument("--pin-mask", action="append", default=[], metavar="mask.npz:bone:maxverts",
                    help="npz with bool array `red` (one per original vertex): pin those vertices, plus every "
                         "detached piece of at most maxverts welded vertices that contains one, to bone")
    ap.add_argument("--mask-z-max", type=float, default=0.0, help="only mask vertices with z (glTF) below this")
    ap.add_argument("--pin-grow", type=int, default=0, metavar="RINGS",
                    help="after pinning, also pin vertices within this many mesh edges of a pinned one, limited to "
                         "y > --grow-y-min and z < --grow-z-max (closes stray unpinned vertices that stretch)")
    ap.add_argument("--grow-y-min", type=float, default=1.3)
    ap.add_argument("--grow-z-max", type=float, default=0.08)
    a = ap.parse_args()
    raw = a.src.read_bytes()
    j, blob, blob_off = read_glb(raw)
    joints = [j["nodes"][n]["name"] for n in j["skins"][0]["joints"]]
    pins = []
    for p in a.pin:
        frm = None
        if p.count(":") == 2:
            p, frm = p.rsplit(":", 1)
            frm = [joints.index(f) for f in frm.split("+")]
        box, bone = p.rsplit(":", 1)
        v = [float(x) for x in box.split(",")]
        pins.append((np.array(v[:3]), np.array(v[3:]), joints.index(bone), frm))
    parts = []
    for p in a.pin_parts:
        box, bone, mx, frm = p.rsplit(":", 3)
        v = [float(x) for x in box.split(",")]
        parts.append((np.array(v[:3]), np.array(v[3:]), joints.index(bone), int(mx), [joints.index(f) for f in frm.split("+")]))
    masks = []
    for p in a.pin_mask:
        f, bone, mx = p.rsplit(":", 2)
        masks.append((np.load(f)["red"], joints.index(bone), int(mx)))
    for m in j["meshes"]:
        for prim in m["primitives"]:
            at = prim["attributes"]
            pos = read_acc(j, blob, at["POSITION"]).astype(np.float64)
            jn = read_acc(j, blob, at["JOINTS_0"]).astype(np.int64)
            wa, *_ = acc_slice(j, at["WEIGHTS_0"])
            wt = read_acc(j, blob, at["WEIGHTS_0"]).astype(np.float64)
            if wa["componentType"] != 5126:
                wt /= float(np.iinfo(CT[wa["componentType"]]).max)
            idx = read_acc(j, blob, prim["indices"]).astype(np.int64).ravel()
            n, nj = len(pos), len(joints)
            dense = np.zeros((n, nj))
            for c in range(4):
                np.add.at(dense, (np.arange(n), jn[:, c]), wt[:, c])
            h = pos[:, 1].max() - pos[:, 1].min()
            key = np.round(pos / 1e-5).astype(np.int64)
            uniq, inv = np.unique(key, axis=0, return_inverse=True)
            inv = inv.ravel()
            u = len(uniq)
            W = np.zeros((u, nj))
            cnt = np.bincount(inv, minlength=u).astype(float)
            np.add.at(W, inv, dense)
            W /= cnt[:, None]
            P = np.zeros((u, 3))
            P[inv] = pos
            tri = idx.reshape(-1, 3)
            e = np.concatenate([tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [2, 0]]])
            ea, eb = inv[e[:, 0]], inv[e[:, 1]]
            ok = (ea != eb) & (np.linalg.norm(P[ea] - P[eb], axis=1) < a.max_edge * h)
            ca, cb = ea, eb
            ea, eb = ea[ok], eb[ok]
            na, nb = np.concatenate([ea, eb]), np.concatenate([eb, ea])
            deg = np.bincount(na, minlength=u).astype(float)
            deg[deg == 0] = 1
            W0 = W.copy()
            for _ in range(a.iters):
                acc = np.zeros_like(W)
                np.add.at(acc, na, W[nb])
                W = a.keep * W + (1 - a.keep) * acc / deg[:, None]
            pinned_all = np.zeros(u, bool)
            last_bone = None
            for lo, hi, bone, frm in pins:
                inside = np.all((P >= lo) & (P <= hi), axis=1)
                if frm is not None:
                    inside &= W0[:, frm].sum(1) > 0.5
                W[inside] = 0.0
                W[inside, bone] = 1.0
                pinned_all |= inside
                last_bone = bone
                print(f"pinned {int(inside.sum())} welded vertices to {joints[bone]}")
            if parts or masks:
                lab = np.arange(u)
                while True:
                    mn = np.minimum(lab[ca], lab[cb])
                    new = lab.copy()
                    np.minimum.at(new, ca, mn)
                    np.minimum.at(new, cb, mn)
                    new = new[new]
                    if (new == lab).all():
                        break
                    lab = new
                for lo, hi, bone, mx, frm in parts:
                    n_pinned = 0
                    for c in np.unique(lab):
                        m = lab == c
                        if m.sum() > mx:
                            continue
                        ctr = (P[m].min(0) + P[m].max(0)) / 2
                        if np.all((ctr >= lo) & (ctr <= hi)) and W0[m][:, frm].sum() / m.sum() > 0.5:
                            W[m] = 0.0
                            W[m, bone] = 1.0
                            n_pinned += int(m.sum())
                    print(f"pinned {n_pinned} welded vertices (detached parts) to {joints[bone]}")
                for red, bone, mx in masks:
                    hit = np.zeros(u, bool)
                    hit[inv[red & (pos[:, 2] < a.mask_z_max)]] = True
                    pin = np.zeros(u, bool)
                    for c in np.unique(lab[hit]):
                        m = lab == c
                        pin |= m if m.sum() <= mx else (m & hit)
                    W[pin] = 0.0
                    W[pin, bone] = 1.0
                    pinned_all |= pin
                    last_bone = bone
                    print(f"pinned {int(pin.sum())} welded vertices (red mask) to {joints[bone]}")
            if a.pin_grow and last_bone is not None:
                allowed = (P[:, 1] > a.grow_y_min) & (P[:, 2] < a.grow_z_max)
                for _ in range(a.pin_grow):
                    add = np.zeros(u, bool)
                    add[cb[pinned_all[ca]]] = True
                    add[ca[pinned_all[cb]]] = True
                    add &= allowed & ~pinned_all
                    pinned_all |= add
                W[pinned_all] = 0.0
                W[pinned_all, last_bone] = 1.0
                print(f"after growing {a.pin_grow} rings: {int(pinned_all.sum())} welded vertices pinned")
            full = W[inv]
            top = np.argsort(-full, axis=1)[:, :4]
            tw = np.take_along_axis(full, top, 1)
            tw[tw < 0.005] = 0.0
            s = tw.sum(1, keepdims=True)
            s[s == 0] = 1.0
            tw /= s
            if wa["componentType"] != 5126:
                tw = np.rint(tw * np.iinfo(CT[wa["componentType"]]).max)
            write_acc(j, blob, at["JOINTS_0"], top)
            write_acc(j, blob, at["WEIGHTS_0"], tw)
            moved = float(np.abs(full - dense).sum(1).mean())
            print(f"{n} verts, {u} welded; mean weight change {moved:.3f}")
    out = bytearray(raw)
    out[blob_off:blob_off + len(blob)] = blob
    a.dst.write_bytes(bytes(out))
    print("wrote", a.dst)


if __name__ == "__main__":
    main()
