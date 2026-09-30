#!/usr/bin/env python3
"""tuck_mane_under_hat.py - fold Lil Blunt's back mane leaves DOWN under his hat brim.

  python3 tools/meshy/tuck_mane_under_hat.py src/episode2/assets/lil_blunt_hero.glb [--dry-run]

Founder 2026-09-30: "correct Lil Blunt's hat with his hair". His target art shows the hat sitting ON TOP
with a leaf collar UNDER the brim. The Meshy "Smiling Zipline Hero" has ~800 head-mane leaf vertices at the
BACK that rise above the brim (up to 5 cm above the crown), so from the chase camera the brim looked like it
cut through a bush. Measured per 45-degree sector around the head axis (skill see-it-yourself).

What it does: leaf-green head-skinned vertices that rise more than 0.06 m above the head joint seed the
selection, which spreads through connected triangles (never into the brown hat or the hands); every selected
vertex has its height above the head joint squashed to SQUASH, so the mane tops out under the hat crown. The face, the front mane, the hat, UVs and skin weights are not
touched. The brim heights are still printed per sector as a diagnostic. Idempotent: afterwards no leaf is above the
seed height, so a re-run moves nothing. Run AFTER tools/meshy/reweight_mane.py.
"""
import io
import json
import struct
import sys

import numpy as np
from PIL import Image

HEAD_BONES = ("neck", "Head", "head_end", "headfront")
FRONT_KEEP_DEG = 0.0       # 0 = every direction: no leaf above brim height frames the face (measured: 2 verts in the front sector)
SQUASH = 0.35              # leaf height kept above the head joint
SECTORS = 16


def main(path, dry):
    raw = open(path, "rb").read()
    jlen = struct.unpack("<I", raw[12:16])[0]
    j = json.loads(raw[20:20 + jlen])
    bin_off = 20 + jlen + 8
    buf = bytearray(raw)

    def view(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        dt = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32}[a["componentType"]]
        assert not bv.get("byteStride") or bv["byteStride"] == np.dtype(dt).itemsize * n, "interleaved buffers not handled"
        off = bin_off + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return off, np.frombuffer(bytes(buf[off:off + a["count"] * n * np.dtype(dt).itemsize]), dtype=dt).reshape(a["count"], n)

    prim = j["meshes"][0]["primitives"][0]["attributes"]
    pacc = j["accessors"][prim["POSITION"]]
    poff, P = view(prim["POSITION"])
    _, UV = view(prim["TEXCOORD_0"])
    _, J = view(prim["JOINTS_0"])
    _, W = view(prim["WEIGHTS_0"])
    P = P.astype(float).copy()
    img = j["images"][j["textures"][0]["source"]]
    bv = j["bufferViews"][img["bufferView"]]
    ib = bin_off + bv.get("byteOffset", 0)
    T = np.asarray(Image.open(io.BytesIO(bytes(buf[ib:ib + bv["byteLength"]]))).convert("RGB")).astype(float)
    h, w = T.shape[:2]
    col = T[np.clip((UV[:, 1] % 1) * h, 0, h - 1).astype(int), np.clip((UV[:, 0] % 1) * w, 0, w - 1).astype(int)]
    green = (col[:, 1] > col[:, 0] * 1.15) & (col[:, 1] > col[:, 2] * 1.3)
    brown = (col[:, 0] > col[:, 1] * 1.15) & (col[:, 0] > 60)

    skin = j["skins"][0]
    names = np.array([j["nodes"][i]["name"] for i in skin["joints"]])
    _, ibm = view(skin["inverseBindMatrices"])
    ibm = ibm.reshape(-1, 4, 4).transpose(0, 2, 1)
    jp = {n: np.linalg.inv(ibm[i])[:3, 3] for i, n in enumerate(names)}
    dom = names[J[np.arange(len(J)), W.argmax(1)]]
    on_head = np.isin(dom, HEAD_BONES)

    head = jp["Head"]
    face = jp["headfront"] - head
    face_ang = np.degrees(np.arctan2(face[0], face[2]))
    dx, dz = P[:, 0] - head[0], P[:, 2] - head[2]
    R = np.hypot(dx, dz)
    ang = (np.degrees(np.arctan2(dx, dz)) - face_ang + 180.0) % 360.0 - 180.0   # 0 = face, +-180 = back

    hat = brown & on_head & (P[:, 1] > head[1] - 0.06)
    edges = np.linspace(-180.0, 180.0, SECTORS + 1)
    centres = 0.5 * (edges[:-1] + edges[1:])
    brim = np.full(SECTORS, np.nan)
    for k in range(SECTORS):
        s = hat & (ang >= edges[k]) & (ang < edges[k + 1])
        if s.sum() >= 4:
            ring = s & (R >= np.percentile(R[s], 75))
            brim[k] = np.median(P[ring, 1])
    ok = ~np.isnan(brim)
    if ok.sum() < 3:
        print("could not find the hat brim; nothing changed")
        return 1
    # circular interpolation over the sectors that have hat verts
    xs = np.concatenate([centres[ok] - 360.0, centres[ok], centres[ok] + 360.0])
    ys = np.tile(brim[ok], 3)
    brim_at = np.interp(ang, xs, ys)

    seed = green & on_head & (np.abs(ang) >= FRONT_KEEP_DEG) & (P[:, 1] > head[1] + 0.061)
    # Move whole leaf pieces, not colour-tested corners: a triangle with one corner folded and one left up
    # (a shaded leaf edge that failed the green test) stretches into a thin "grass" spike. Spread the
    # selection through connected triangles, over any vertex that is behind/beside the face, above the
    # brim, not the hat (brown - the leaves and the hat are one connected surface, and folding the crown dents
    # it) and not a hand (the revolver and pickaxe are skinned to the hands).
    cand = (np.abs(ang) >= FRONT_KEEP_DEG) & (P[:, 1] > head[1]) & ~np.isin(dom, ("RightHand", "LeftHand")) & ~brown \
        & (np.linalg.norm(P - head, axis=1) < 0.6)
    tri = view(j["meshes"][0]["primitives"][0]["indices"])[1].reshape(-1, 3).astype(np.int64)
    sel = seed.copy()
    for _ in range(12):
        hit = sel[tri].any(1)
        grow = np.zeros_like(sel)
        grow[tri[hit].ravel()] = True
        grow &= cand
        if not (grow & ~sel).any():
            break
        sel |= grow
    print("brim height per sector:", np.round(brim, 3).tolist())
    print("seed leaves %d, whole pieces after spreading:" % seed.sum())
    print("mane pieces to squash: %d verts (tallest %.3f m above the head joint)" % (
        sel.sum(), float((P[sel, 1] - head[1]).max()) if sel.any() else 0.0))
    if dry or not sel.any():
        return 0
    # Squash each piece's height above the HEAD JOINT (not above a per-direction brim estimate: the hat is
    # tilted, and the "outer ring" of a tilted hat is partly crown, which left leaves visibly above the brim
    # from behind). SQUASH 0.35 puts the tallest leaf (+0.17 m) at +0.06 m - under the crown top (+0.115 m).
    top = head[1]
    P[sel, 1] = np.where(P[sel, 1] > top, top + SQUASH * (P[sel, 1] - top), P[sel, 1])
    pb = P.astype(np.float32).tobytes()
    buf[poff:poff + len(pb)] = pb
    # keep the accessor bounds true (glTF requires POSITION min/max)
    pacc["min"] = P.min(0).astype(float).tolist()
    pacc["max"] = P.max(0).astype(float).tolist()
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = bytes(buf[20 + jlen:])
    out = raw[:12] + struct.pack("<I", len(js)) + b"JSON" + js + rest
    out = out[:8] + struct.pack("<I", len(out)) + out[12:]
    open(path, "wb").write(out)
    print("wrote", path)
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], "--dry-run" in sys.argv))
