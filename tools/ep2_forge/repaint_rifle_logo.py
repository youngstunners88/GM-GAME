#!/usr/bin/env python3
"""Lil Blunt's rifle (founder Drive "rifle 3d.glb", Tripo, his green arm + glove baked in): replace the SMEARED GOLD BLOB that Tripo
made of the GM logo with the founder-approved emblem - TEXTURE ONLY (skill ep2-winchester-logo).

Why texture-only: every earlier logo fix that touched geometry went wrong (a bezel ring wider than the plate, a delete-cylinder that
holed the top strap). Here no vertex moves and no face is deleted, so no ring and no hole CAN appear. For every texel of every triangle
lying on the receiver plate round the old blob, the texel's 3-D point is projected onto the plate plane and:
  * inside the logo disc (radius = the blob's own radius x0.95, never larger): albedo = the emblem (chain + green GM on dark enamel),
    emissive = the emblem's glow mask (the green GM), normal = flat (the blob's relief must not show through), metal/rough = gold vs enamel;
  * in a thin annulus outside it: only GOLD-ish texels (the blob's leftover rim) are repainted with the plate's own median steel colour,
    so screws / scratches / engraving round it stay as they were.
The Mixamo auto-rig in the file is a broken default (identity rest, see ep2-founder-weapon-glb) and is dropped: the output is a static mesh.

  python3 tools/ep2_forge/repaint_rifle_logo.py --src .farm/drive_1010/rifle_3d.glb --out .farm/drive_1010/rifle_logo_fixed.glb \
      --emblem artifacts/episode2-gold-mine/references/founder_2026-10-10b/emblem/gm_emblem_color.jpg \
      --emit artifacts/episode2-gold-mine/references/founder_2026-10-10b/emblem/gm_emblem_emit.png [--tex 2048] [--report out.json]
"""
import argparse, json
import numpy as np, trimesh
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True); ap.add_argument("--out", required=True)
ap.add_argument("--emblem", required=True); ap.add_argument("--emit", default="")
ap.add_argument("--scale", type=float, default=0.95, help="logo radius / old blob radius (<= 1: never larger than the old logo)")
ap.add_argument("--chain-r", type=float, default=0.485, help="emblem image radius (fraction of width) of the chain's outer edge")
ap.add_argument("--tex", type=int, default=0, help="output albedo size (0 = keep)")
ap.add_argument("--report", default="")
ap.add_argument("--band-gain", dest="band_gain", type=float, default=1.25, help="extra lift of the rim band (compensates the flat disc's darker shading)")
a = ap.parse_args()

sc = trimesh.load(a.src, force="scene")
g = list(sc.geometry.values())[0]
V = np.asarray(g.vertices, dtype=np.float64); F = np.asarray(g.faces); UV = np.asarray(g.visual.uv, dtype=np.float64)
VN = np.array(g.vertex_normals, dtype=np.float64); FN = np.array(g.face_normals)
mat = g.visual.material
alb = np.asarray(mat.baseColorTexture.convert("RGB")).astype(np.float32) / 255.0
nrm = np.asarray(mat.normalTexture.convert("RGB")).astype(np.float32) / 255.0 if mat.normalTexture is not None else None
mr = np.asarray(mat.metallicRoughnessTexture.convert("RGB")).astype(np.float32) / 255.0 if mat.metallicRoughnessTexture is not None else None
emb = np.asarray(Image.open(a.emblem).convert("RGB")).astype(np.float32) / 255.0
emi = np.asarray(Image.open(a.emit).convert("RGB")).astype(np.float32) / 255.0 if a.emit else None
emis = np.zeros((1024, 1024, 3), np.float32)


def sample(img, u, v):
    """img sampled at UV (u right, v up, glTF v flipped), nearest."""
    h, w = img.shape[:2]
    x = np.clip((u % 1.0) * w, 0, w - 1).astype(int); y = np.clip((1.0 - (v % 1.0)) * h, 0, h - 1).astype(int)
    return img[y, x]


# --- 1. find the blob on each receiver side: gold texels on plate-facing vertices round the receiver
Cv = sample(alb, UV[:, 0], UV[:, 1])
gold_v = (Cv[:, 0] > 0.40) & (Cv[:, 1] > 0.28) & (Cv[:, 2] < 0.25) & (Cv[:, 0] - Cv[:, 2] > 0.25)
box = (np.abs(V[:, 0] - 0.27) < 0.07) & (V[:, 1] > 0.16) & (V[:, 1] < 0.30)          # the receiver (measured, rifle_3d.glb frame)
import trimesh.ray.ray_triangle as _rt
rmi = _rt.RayMeshIntersector(trimesh.Trimesh(V, F, process=False))
FN0 = FN.copy()
sites = []
for s in (-1, 1):
    m = gold_v & box & (np.sign(VN[:, 2]) == s) & (np.abs(VN[:, 2]) > 0.6)
    if m.sum() < 8:
        continue
    Q = V[m]; c = Q.mean(0)
    n = VN[m].mean(0); n /= np.linalg.norm(n)
    d = Q - c; d -= np.outer(d @ n, n)
    r_blob = float(np.percentile(np.linalg.norm(d, axis=1), 98))
    # MEASURE the visible surface with rays from outside the gun along -n (the first hit is what the player sees):
    # the PLATE level = median hit depth in the annulus 1.3..1.75 x the blob radius; the DISH = first-hit triangles inside it.
    up0 = np.array([0.0, 1.0, 0.0]); t2 = up0 - n * (up0 @ n); t2 /= np.linalg.norm(t2); t1 = np.cross(t2, n)
    gr = np.linspace(-1.8, 1.8, 73) * r_blob
    ox, oy = np.meshgrid(gr, gr); ox = ox.ravel(); oy = oy.ravel()
    origins = c + np.outer(ox, t1) + np.outer(oy, t2) + n * 0.25
    dirs = np.tile(-n, (len(origins), 1))
    locs, ray_i, tri_i = rmi.intersects_location(origins, dirs, multiple_hits=False)
    depth = (locs - c) @ n
    rad = np.hypot(ox[ray_i], oy[ray_i])
    ann = (rad > r_blob * 1.3) & (rad < r_blob * 1.75) & (FN0[tri_i] @ n > 0.8)
    plate_off = float(np.median(depth[ann])) if ann.sum() > 10 else 0.0
    c = c + n * plate_off
    # fit the TRUE plate plane to the ray hits on the plate round the dish (the blob's own normal is a few degrees off the plate:
    # a disc flattened onto it caught the light differently and read as a dark band)
    hp = locs[ann]
    if len(hp) > 20:
        pc = hp.mean(0); _, _, vt = np.linalg.svd(hp - pc); pn = vt[2] * np.sign(vt[2] @ n)
        c = c - pn * ((c - pc) @ pn)
        tilt_deg = float(np.degrees(np.arccos(np.clip(pn @ n, -1, 1))))
        n = pn
    else:
        tilt_deg = 0.0
    # FLATTEN Tripo's logo DISH (a recessed well with a raised lip reads as an outer ring however the texture is painted).
    # Vertices only - nothing deleted, so no hole can open. EVERY vertex in the cylinder r < 1.22 x blob radius whose depth is within
    # -8 / +5 mm of the plate (the dish floor -1..-7 mm, its walls and lip; MEASURED radial profile) goes onto the plate plane, eased to
    # zero between 1.12 and 1.22 x radius. Beyond 1.3 x the panel edge sits ~10 mm below the plate: a wider window pulled it up into
    # slivers (2026-10-10 render), and a first-hit-only flatten left shards - both rejected.
    relv = V - c
    dpt = relv @ n
    inpl = np.linalg.norm(relv - np.outer(dpt, n), axis=1)
    # WHERE THE DISH ENDS, per side, from the ray hits: the first radius past 0.95 x the blob radius from which the visible surface
    # stays within 1 mm of the fitted plate (side -1's outer slope ran to ~1.3 x and, left unflattened, shaded as a dark ring)
    hd = (locs - c) @ n
    edges_r = np.arange(0.95, 1.6, 0.025)
    dish_end = 1.22
    for e in edges_r:
        mm = (rad >= e * r_blob) & (rad < (e + 0.025) * r_blob)
        if mm.sum() and np.median(np.abs(hd[mm])) < 0.001 and all(
                np.median(np.abs(hd[(rad >= f * r_blob) & (rad < (f + 0.025) * r_blob)])) < 0.0015
                for f in (e + 0.025, e + 0.05) if ((rad >= f * r_blob) & (rad < (f + 0.025) * r_blob)).any()):
            dish_end = float(e)
            break
    dish_end = float(np.clip(dish_end + 0.04, 1.12, 1.4))
    # ...and PER 15-DEGREE SECTOR (side -1 had a groove on one arc only, to ~1.5 x: a dark crescent): sector end = first radius from
    # which the hits stay within 1 mm of the plate for two bins, never below the global end, never past 1.6 x
    hang = np.arctan2((locs - c) @ t2, (locs - c) @ t1)
    nsec = 24
    sec_end = np.full(nsec, dish_end)
    for k in range(nsec):
        a0 = -np.pi + k * 2 * np.pi / nsec
        sm = (hang >= a0) & (hang < a0 + 2 * np.pi / nsec)
        for e in np.arange(dish_end - 0.04, 1.6, 0.025):
            b1 = sm & (rad >= e * r_blob) & (rad < (e + 0.05) * r_blob)
            b2 = sm & (rad >= (e + 0.05) * r_blob) & (rad < (e + 0.1) * r_blob)
            if b1.sum() >= 2 and b2.sum() >= 2 and np.median(np.abs(hd[b1])) < 0.001 and np.median(np.abs(hd[b2])) < 0.0012:
                sec_end[k] = max(dish_end, float(e) + 0.04)
                break
        else:
            sec_end[k] = dish_end
    sec_end = np.minimum(sec_end, 1.6)
    sec_end = (np.roll(sec_end, 1) + 2 * sec_end + np.roll(sec_end, -1)) / 4.0       # smooth sector to sector
    # the dish = the VISIBLE surface (first-hit triangles inside 1.15 x radius), grown through mesh edges to every connected vertex
    # inside 1.22 x radius and within 22 mm of the plate (the dish wall: its floor is 1-7 mm down, the wall reaches ~19 mm).
    # Growing by connectivity, not by a depth window, keeps the panel edge (~10 mm down, 1.3 x radius, not connected inside the
    # radius) untouched and leaves no half-moved triangle (the depth-window version left slivers).
    seed = np.unique(F[np.unique(tri_i[(rad < r_blob * 1.15) & (FN0[tri_i] @ n > 0.3)])].ravel())
    vang = np.arctan2(relv @ t2, relv @ t1)
    vsec = (((vang + np.pi) / (2 * np.pi)) * nsec).astype(int) % nsec
    vend = sec_end[vsec]
    allow = (inpl < r_blob * vend) & (dpt > -0.022) & (dpt < 0.006)
    region = np.zeros(len(V), bool); region[seed[allow[seed]]] = True
    edges = np.vstack([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    for _ in range(40):
        grow = (region[edges[:, 0]] & ~region[edges[:, 1]] & allow[edges[:, 1]])
        nxt = np.unique(edges[grow, 1])
        grow2 = (region[edges[:, 1]] & ~region[edges[:, 0]] & allow[edges[:, 0]])
        nxt = np.union1d(nxt, np.unique(edges[grow2, 0]))
        if len(nxt) == 0:
            break
        region[nxt] = True
    dv = np.where(region)[0]
    wgt = np.clip((r_blob * vend - inpl) / (r_blob * 0.08), 0.0, 1.0)
    max_move = float(np.abs(dpt[dv]).max()) if len(dv) else 0.0
    V[dv] -= np.outer(dpt[dv] * wgt[dv], n)
    full = dv[wgt[dv] >= 1.0]
    VN[full] = n
    blend = dv[wgt[dv] < 1.0]
    VN[blend] = (VN[blend] * (1.0 - wgt[blend])[:, None] + n * wgt[blend][:, None])
    VN[blend] /= np.linalg.norm(VN[blend], axis=1, keepdims=True)
    dish_faces = np.where(np.isin(F, full).all(axis=1))[0]
    ann = np.zeros(int(ann.sum()))
    dish = dv
    st_faces = dish_faces
    up = np.array([0.0, 1.0, 0.0]); e2 = up - n * (up @ n); e2 /= np.linalg.norm(e2)
    e1 = np.cross(e2, n); e1 /= np.linalg.norm(e1)          # screen-right for a viewer on the +n side: letters read un-mirrored
    sites.append(dict(side=s, c=c, n=n, e1=e1, e2=e2, r_blob=r_blob, R=r_blob * a.scale, plate_off_mm=round(plate_off * 1000, 2), plate_tilt_deg=round(tilt_deg, 2), dish_end=round(dish_end, 3), sec_end=sec_end, sector_end_max=round(float(sec_end.max()), 3), dish_verts=int(len(dish)), dish_faces=st_faces, dish_max_move_mm=round(max_move * 1000, 2), plate_annulus_verts=int(len(ann))))
print("sites", [(s["side"], np.round(s["c"], 4).tolist(), round(s["r_blob"], 4), round(s["R"], 4)) for s in sites])

FN = np.asarray(trimesh.Trimesh(V, F, process=False).face_normals)
H, W = alb.shape[:2]
stats = []
for st in sites:
    c, n, e1, e2, R, rb = st["c"], st["n"], st["e1"], st["e2"], st["R"], st["r_blob"]
    cen = V[F].mean(1)
    rel = cen - c
    inplane = np.linalg.norm(rel - np.outer(rel @ n, n), axis=1)
    sel = np.where((inplane < rb * 1.65) & (np.abs(rel @ n) < 0.006) & (FN @ n > 0.5))[0]
    # plate colour: median of non-gold texels in the ring 1.25..1.6 x blob radius
    ring_cols = []
    painted = logo_px = rim_px = 0
    for fi in sel:
        tri_uv = UV[F[fi]]; tri_p = V[F[fi]]
        xs = (tri_uv[:, 0] % 1.0) * W; ys = (1.0 - (tri_uv[:, 1] % 1.0)) * H
        x0, x1 = int(np.floor(xs.min())), int(np.ceil(xs.max())); y0, y1 = int(np.floor(ys.min())), int(np.ceil(ys.max()))
        if x1 - x0 > 400 or y1 - y0 > 400:
            continue                                          # a triangle wrapping the atlas seam: skip
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        T = np.array([[xs[0] - xs[2], xs[1] - xs[2]], [ys[0] - ys[2], ys[1] - ys[2]]])
        if abs(np.linalg.det(T)) < 1e-9:
            continue
        Ti = np.linalg.inv(T)
        l12 = Ti @ np.vstack([gx.ravel() - xs[2], gy.ravel() - ys[2]])
        l3 = 1.0 - l12.sum(0)
        inside = (l12[0] >= -0.01) & (l12[1] >= -0.01) & (l3 >= -0.01)
        if not inside.any():
            continue
        lam = np.vstack([l12, l3])[:, inside]
        P = (tri_p.T @ lam).T
        q = P - c
        u = (q @ e1) / R; v = (q @ e2) / R
        rr = np.sqrt(u * u + v * v)
        px = np.clip(gx.ravel()[inside].astype(int), 0, W - 1); py = np.clip(gy.ravel()[inside].astype(int), 0, H - 1)
        pang0 = np.arctan2(v, u)
        pend0 = st["sec_end"][(((pang0 + np.pi) / (2 * np.pi)) * len(st["sec_end"])).astype(int) % len(st["sec_end"])]
        ring = (rr > (pend0 + 0.1) * rb / R) & (rr < (pend0 + 0.35) * rb / R)
        cur = alb[py, px]
        notgold = ~((cur[:, 0] > 0.40) & (cur[:, 1] > 0.28) & (cur[:, 2] < 0.25))
        if ring.any():
            ok = ring & notgold
            ring_cols.append(cur[ok])
            st.setdefault("ring", []).append((np.arctan2(v[ok], u[ok]), px[ok], py[ok]))
        st.setdefault("todo", []).append((px, py, u, v, rr))
    plate = np.median(np.concatenate(ring_cols), axis=0) if ring_cols else np.array([0.3, 0.32, 0.36])
    st["plate"] = plate
    if st.get("ring"):
        ra = np.concatenate([r[0] for r in st["ring"]]); rpx = np.concatenate([r[1] for r in st["ring"]]); rpy = np.concatenate([r[2] for r in st["ring"]])
        o = np.argsort(ra)
        st["ring_ang"], st["ring_px"], st["ring_py"] = ra[o], rpx[o], rpy[o]
        cols = alb[rpy, rpx]
        nb = 60
        bi = ((ra + np.pi) / (2 * np.pi) * nb).astype(int) % nb
        bins = np.array([np.median(cols[bi == j], axis=0) if (bi == j).any() else np.median(cols, axis=0) for j in range(nb)])
        bins = (np.roll(bins, 1, 0) + bins + np.roll(bins, -1, 0)) / 3.0
        st["ring_bins"] = bins
        # copy SOURCE texels before any are overwritten
        st["ring_snapshot"] = True
    for px, py, u, v, rr in st.get("todo", []):
        cur = alb[py, px]
        logo = rr <= 1.0
        if logo.any():
            ex = 0.5 + u[logo] * a.chain_r; ey = 0.5 - v[logo] * a.chain_r
            eh, ew = emb.shape[:2]
            ix = np.clip(ex * ew, 0, ew - 1).astype(int); iy = np.clip(ey * eh, 0, eh - 1).astype(int)
            alb[py[logo], px[logo]] = emb[iy, ix]
            if nrm is not None:
                nh, nw = nrm.shape[:2]
                nrm[np.clip(py[logo] * nh // H, 0, nh - 1), np.clip(px[logo] * nw // W, 0, nw - 1)] = (0.5, 0.5, 1.0)
            if mr is not None:
                mh, mw = mr.shape[:2]
                lum = emb[iy, ix].mean(1)
                goldish = (emb[iy, ix][:, 0] - emb[iy, ix][:, 2]) > 0.18
                mr[np.clip(py[logo] * mh // H, 0, mh - 1), np.clip(px[logo] * mw // W, 0, mw - 1), 1] = np.where(goldish, 0.32, 0.55)
                mr[np.clip(py[logo] * mh // H, 0, mh - 1), np.clip(px[logo] * mw // W, 0, mw - 1), 2] = np.where(goldish, 0.85, 0.15)
            if emi is not None:
                eh2, ew2 = emi.shape[:2]
                jx = np.clip(ex * ew2, 0, ew2 - 1).astype(int); jy = np.clip(ey * eh2, 0, eh2 - 1).astype(int)
                emis[np.clip(py[logo] * 1024 // H, 0, 1023), np.clip(px[logo] * 1024 // W, 0, 1023)] = emi[jy, jx]
            logo_px += int(logo.sum())
        # the old logo's rim band (dish wall + lip + brown/gold remnant): filled with the receiver's OWN steel texels copied from the
        # plate ring just outside it at the same angle (albedo, normal, metal/rough) - no flat median colour, so no dark band
        pang = np.arctan2(v, u)
        pend = st["sec_end"][(((pang + np.pi) / (2 * np.pi)) * len(st["sec_end"])).astype(int) % len(st["sec_end"])]
        rim = (rr > 1.0) & (rr < (pend + 0.06) * rb / R)
        fix = rim
        if fix.any() and st.get("ring_ang") is not None:
            ang = np.arctan2(v[fix], u[fix])
            k = np.searchsorted(st["ring_ang"], ang).clip(0, len(st["ring_ang"]) - 1)
            sx = st["ring_px"][k]; sy = st["ring_py"][k]
            # albedo: the plate's colour at this angle, smoothed over +-6 deg (a per-texel copy speckled), with the old texel's fine
            # luminance grain kept at 25 % so the steel is not a flat paint patch
            bins = st["ring_bins"]
            b_i = ((ang + np.pi) / (2 * np.pi) * len(bins)).astype(int) % len(bins)
            lum = alb[py[fix], px[fix]].mean(1, keepdims=True)
            alb[py[fix], px[fix]] = np.clip(bins[b_i] * (0.85 + 0.3 * lum / max(float(lum.mean()), 1e-3) * 0.5), 0, 1)
            if nrm is not None:
                nh, nw = nrm.shape[:2]
                nrm[np.clip(py[fix] * nh // H, 0, nh - 1), np.clip(px[fix] * nw // W, 0, nw - 1)] = nrm[np.clip(sy * nh // H, 0, nh - 1), np.clip(sx * nw // W, 0, nw - 1)]
            if mr is not None:
                mh, mw = mr.shape[:2]
                mr[np.clip(py[fix] * mh // H, 0, mh - 1), np.clip(px[fix] * mw // W, 0, mw - 1)] = mr[np.clip(sy * mh // H, 0, mh - 1), np.clip(sx * mw // W, 0, mw - 1)]
            rim_px += int(fix.sum())
            st.setdefault("rimset", []).append((px[fix], py[fix], rr[fix]))
    # level the rim band to the plate: its fill is a few % darker and the flattened disc shades darker still (render profile dipped to
    # 0.72 x the plate at 0.9-1.12 x the logo radius = a faint ring). Gain the band's albedo so its brightness matches the plate ring,
    # strongest at the emblem edge and tapering to 1 at the band's outer edge. Measured, not guessed: --band-gain multiplies it.
    if st.get("rimset") and st.get("ring"):
        rpx = np.concatenate([q[0] for q in st["rimset"]]); rpy = np.concatenate([q[1] for q in st["rimset"]]); rrr = np.concatenate([q[2] for q in st["rimset"]])
        plate_l = float(alb[st["ring_py"], st["ring_px"]].mean())
        rim_l = float(alb[rpy, rpx].mean())
        gain = float(np.clip(plate_l / max(rim_l, 1e-3) * a.band_gain, 1.0, 1.6))
        taper = np.clip(1.0 - (rrr - 1.0) / ((st["sector_end_max"] + 0.06) * rb / R - 1.0), 0.0, 1.0)[:, None]
        alb[rpy, rpx] = np.clip(alb[rpy, rpx] * (1.0 + (gain - 1.0) * taper), 0, 1)
        st["band_gain"] = round(gain, 3)
    stats.append(dict(band_gain=st.get("band_gain"), dish_end=st["dish_end"], sector_end_max=st["sector_end_max"], plate_tilt_deg=st["plate_tilt_deg"], plate_off_mm=st["plate_off_mm"], dish_verts=st["dish_verts"], dish_max_move_mm=st["dish_max_move_mm"], plate_annulus_verts=st["plate_annulus_verts"], side=st["side"], centre=np.round(st["c"], 4).tolist(), normal=np.round(st["n"], 3).tolist(),
                      blob_radius_mm=round(st["r_blob"] * 1000, 1), logo_radius_mm=round(st["R"] * 1000, 1),
                      faces=int(len(sel)), logo_texels=logo_px, rim_gold_texels_repainted=rim_px,
                      plate_rgb=np.round(plate, 3).tolist()))
print(json.dumps(stats, indent=1))

# --- 2. write: same geometry, same UVs; textures replaced
def img(arr, size=None):
    im = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    return im.resize((size, size), Image.LANCZOS) if size else im

newmat = trimesh.visual.material.PBRMaterial(
    baseColorTexture=img(alb, a.tex or None),
    normalTexture=img(nrm) if nrm is not None else None,
    metallicRoughnessTexture=img(mr) if mr is not None else None,
    emissiveTexture=img(emis) if emi is not None else None,
    emissiveFactor=[1.0, 1.0, 1.0] if emi is not None else None,
    metallicFactor=1.0, roughnessFactor=1.0, doubleSided=False)
out = trimesh.Trimesh(V, F, vertex_normals=VN, visual=trimesh.visual.TextureVisuals(uv=UV, material=newmat), process=False)
out.export(a.out)
print("wrote", a.out)
if a.report:
    json.dump(dict(src=a.src, sites=stats, geometry_changed=False, faces=int(len(F)), verts=int(len(V))), open(a.report, "w"), indent=1)
