#!/usr/bin/env python3
"""Inferno Bull's FLAME DESIGNER QUAD, built headless in Blender from the Muapi GPT-Image-2 reference (skill ep2-hyperreal-scene-pipeline).

  python3 tools/ep2_blender/build_flame_quad.py [--out src/episode2/assets/vehicles/flame_quad.glb] [--preview .farm/quad] [--no-render]

Reference: artifacts/episode2-gold-mine/references/fort_knox_prep/flame_quad/{hero_3q,side,rear_3q}.jpg (proportions measured from the side
elevation in units of the tyre outer diameter D = 1.0 m: wheelbase 2.43, length 3.87, seat top 1.5, handlebar 1.87, nose fender 1.0-1.36).
The game scales it (a 2.9 m bull rides it). Frame in the GLB: nose +Z, up +Y, origin on the ground midway between the axles, X lateral.
Four separate wheel nodes (Wheel_FL/FR/RL/RR, origin = hub centre, axle = local X) so the chamber can spin them; everything else is static.
The red panels share ONE side-planar UV map (U along the length, V along the height), so the flame paint is a single side-view texture.
Never opens the GUI (blender-headless-render-safety). pip bpy 4.2 + Pillow + numpy.
"""
import math
import os
import random
import sys

import bpy  # noqa: E402  (import bpy BEFORE bmesh)
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def arg(name, default=None):
    a = sys.argv
    if name in a:
        i = a.index(name)
        return a[i + 1] if i + 1 < len(a) and not a[i + 1].startswith("--") else True
    return default


OUT = arg("--out", os.path.join(ROOT, "src/episode2/assets/vehicles/flame_quad.glb"))
PREVIEW = arg("--preview", os.path.join(ROOT, ".farm/quad"))
RENDER = not arg("--no-render", False)
TEXDIR = os.path.join(PREVIEW, "tex")
random.seed(7)

# --- dimensions (metres, tyre outer diameter D = 1.0) -----------------------------------------------------------------------
R = 0.5                 # tyre radius
FA, RA = 1.215, -1.215  # front / rear axle position along the length (+ = nose)
TRK = 1.32              # track (tyre centre to tyre centre): 1.74 across the tyres
TW = 0.42               # tyre width
NOSE, TAIL = 1.92, -1.97


def V(x, f, u):
    """(lateral, forward, up) -> Blender coords. Blender -Y is the glTF +Z, so the nose points to -Y here and +Z in the GLB."""
    return Vector((x, -f, u))


# --- scene + materials ------------------------------------------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
S = bpy.context.scene
MATS = {}


def mat(name, color, metal=0.0, rough=0.5, coat=0.0, emit=None, emit_strength=0.0, tex=None, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.04
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = emit_strength
    if tex:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(tex)
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    m.use_backface_culling = False
    MATS[name] = m
    return m


def obj_from(name, verts, faces, material, uvs=None, smooth=True, parent=None, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    if uvs is not None:
        uv = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li, vi in zip(poly.loop_indices, poly.vertices):
                uv.data[li].uv = uvs[vi]
    o = bpy.data.objects.new(name, me)
    S.collection.objects.link(o)
    if material is not None:
        me.materials.append(material)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    o.location = loc
    if parent is not None:
        o.parent = parent
    return o


def bm_obj(name, bm, material, parent=None, loc=(0, 0, 0), smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    S.collection.objects.link(o)
    if material is not None:
        me.materials.append(material)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    o.location = loc
    if parent is not None:
        o.parent = parent
    return o


def tube(name, pts, radius, material, sides=10, closed=False, parent=None, round_r=0.0):
    """A tube along a polyline of (x,f,u) points (bevelled curve). `round_r` rounds the corners by inserting arc points."""
    pl = [V(*p) for p in pts]
    if round_r > 0.0 and len(pl) > 2:
        out = [pl[0]]
        for i in range(1, len(pl) - 1):
            a, b, c = pl[i - 1], pl[i], pl[i + 1]
            d1 = (a - b).normalized()
            d2 = (c - b).normalized()
            r = min(round_r, (a - b).length * 0.45, (c - b).length * 0.45)
            p1, p2 = b + d1 * r, b + d2 * r
            for k in range(7):
                t = k / 6.0
                out.append((1 - t) ** 2 * p1 + 2 * (1 - t) * t * b + t * t * p2)
        out.append(pl[-1])
        pl = out
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = max(2, sides // 3)
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pl) - 1)
    for p, v in zip(sp.points, pl):
        p.co = (v.x, v.y, v.z, 1.0)
    sp.use_cyclic_u = closed
    o = bpy.data.objects.new(name, cu)
    S.collection.objects.link(o)
    o.data.materials.append(material)
    if parent is not None:
        o.parent = parent
    return o


def box(name, c, size, material, parent=None, bevel=0.0, rot=(0, 0, 0)):
    """c = (x,f,u) centre, size = (sx, sf, su)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    o = bm_obj(name, bm, material, parent)
    o.location = V(*c)
    o.rotation_euler = rot
    return o


def cyl(name, c, r, h, material, axis="X", parent=None, segs=24, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=h)
    rot = {"X": Matrix.Rotation(math.radians(90), 4, "Y"), "Y": Matrix.Rotation(math.radians(90), 4, "X"), "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    o = bm_obj(name, bm, material, parent)
    o.location = V(*c)
    return o


def sphere(name, c, r, material, scale=(1, 1, 1), parent=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    o = bm_obj(name, bm, material, parent)
    o.location = V(*c)
    return o


# --- textures (PIL / numpy): the candy-red paint is BAKED PER PANEL from 3D position --------------------------------------------------------
# The three red panels (front fender, rear fender, centre tub) are lofts: u runs along the length, v around the section. Each texel is painted by
# asking "where in 3D is this texel and which way does the surface face there?": the flames TRACED from the Muapi side elevation show where the
# surface faces sideways, procedural TOP flames where it faces up (the fender crowns), flake and mud come from 3D noise so they are isotropic
# (the old single side-planar map slid every crown onto one texture row and stretched the flake into "wood grain").
# Left and right share ONE half (the UV folds at the crown line) and the three panels share ONE 1024x320 atlas at 5 mm per texel: web pck budget.
ATLAS_W, ATLAS_H = 1024, 320
MM = 0.005                                                 # metres per texel
PAD = 3                                                    # texels of edge replication around every panel rect (mip bleed)
RECTS = {"Body_Tub": (0, 0, 520, 290), "Fender_Front": (520, 0, 230, 260), "Fender_Rear": (750, 0, 254, 260)}
PANELS = {}                                                # name -> dict(grid, tvals, open, m) filled by shell()
SIDE_F0, SIDE_F1, SIDE_U0, SIDE_U1 = -2.05, 1.98, 0.50, 1.65   # extent of the side-flame raster (metres: length, height)
TOP_X1 = 1.05                                              # extent of the top-flame raster across |x|
REF_SIDE = os.path.join(ROOT, "artifacts/episode2-gold-mine/references/fort_knox_prep/flame_quad/side.jpg")
PHOTO_AXLE_X, PHOTO_GROUND_Y, PHOTO_D = 400.0, 960.0, 360.0      # measured on the side elevation: front axle pixel, ground line, tyre diameter in px


def fold_open(s):
    """Fender UV fold: 0 on the crown centre line, 1 at the lower (wheel-arch) edge. Left and right edges share one half of the texture."""
    return abs(2.0 * s - 1.0)


def fold_ring(s):
    """Tub UV fold: 0 on the crown, 0.5 on the equator (the side), 1 under the belly. Mirror-symmetric about the plane x = 0."""
    s = s % 1.0
    a = abs(s - 0.25) if s <= 0.5 else 0.5 - abs(s - 0.75)
    return a / 0.5


def atlas_uv(name, t, vf):
    x0, y0, w, h = RECTS[name]
    return ((x0 + PAD + t * (w - 2 * PAD)) / ATLAS_W, 1.0 - (y0 + PAD + vf * (h - 2 * PAD)) / ATLAS_H)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash3(ix, iy, iz, seed=0):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float64) / 65535.0


def cellnoise(P3, freq, seed=0):
    """Uniform 0..1 per (1/freq) metre cube: isotropic grain whatever the texture layout is."""
    ij = np.floor(P3 * freq).astype(np.int64)
    return _hash3(ij[..., 0], ij[..., 1], ij[..., 2], seed)


def vnoise(P3, freq, seed=0):
    """Smooth 3D value noise 0..1."""
    q = P3 * freq
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3.0 - 2.0 * f)
    def c(dx, dy, dz):
        return _hash3(i[..., 0] + dx, i[..., 1] + dy, i[..., 2] + dz, seed)
    x00 = c(0, 0, 0) * (1 - f[..., 0]) + c(1, 0, 0) * f[..., 0]
    x10 = c(0, 1, 0) * (1 - f[..., 0]) + c(1, 1, 0) * f[..., 0]
    x01 = c(0, 0, 1) * (1 - f[..., 0]) + c(1, 0, 1) * f[..., 0]
    x11 = c(0, 1, 1) * (1 - f[..., 0]) + c(1, 1, 1) * f[..., 0]
    y0 = x00 * (1 - f[..., 1]) + x10 * f[..., 1]
    y1 = x01 * (1 - f[..., 1]) + x11 * f[..., 1]
    return y0 * (1 - f[..., 2]) + y1 * f[..., 2]


def traced_flames():
    """The flames, TRACED from the GPT-image side elevation (hue/saturation threshold): a bool mask in photo pixels."""
    from scipy import ndimage as ndi
    im = Image.open(REF_SIDE).convert("RGB")
    hsv = np.asarray(im.convert("HSV"), np.float32) / 255.0
    h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    m = (h > 8) & (h < 64) & (s > 0.50) & (v > 0.45)
    m[:380, :] = False
    m[730:, :] = False
    m[:, :200] = False
    m[:, 1520:] = False
    m = ndi.binary_closing(m, iterations=3)
    m = ndi.binary_opening(m, iterations=1)
    m = ndi.binary_dilation(m, iterations=2)                 # the airbrushed red-orange rim of every tongue, not just its bright core
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    return np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 260])


def tongue_poly(root, tip, width, curl, to_px, n=40, sway=0.0):
    """A flame tongue from root to tip (2D metres): sine-shaped width, a curl that grows toward the tip and an S-curve (`sway`, metres) so it
    licks like fire instead of reading as a stripe. Returns the polygon in raster pixels."""
    root, tip = np.array(root, float), np.array(tip, float)
    d = tip - root
    perp = np.array([-d[1], d[0]]) / max(np.linalg.norm(d), 1e-6)
    left, right = [], []
    for i in range(n + 1):
        t = i / n
        c = root + d * t + perp * (curl * t ** 2.2 + sway * math.sin(2.0 * math.pi * t * 1.15))
        wd = width * (math.sin(math.pi * min(t, 1.0) * 0.9 + 0.2) ** 0.9) * (1 - t ** 1.4) * (1 + 0.15 * math.sin(t * 11.0))
        left.append(to_px(c + perp * wd))
        right.append(to_px(c - perp * wd * 0.8))
    return left + right[::-1]


def flame_cluster(draw, root, tip, width, curl, to_px, forks=2, sway=0.03):
    """One main tongue plus short forked licks branching off it (alternating sides) - the classic hot-rod flame."""
    draw.polygon(tongue_poly(root, tip, width, curl, to_px, sway=sway), fill=255)
    r, t_ = np.array(root, float), np.array(tip, float)
    d = t_ - r
    perp = np.array([-d[1], d[0]]) / max(np.linalg.norm(d), 1e-6)
    for fi in range(forks):
        tb = 0.30 + 0.20 * fi
        base = r + d * tb + perp * (curl * tb ** 2.2 + sway * math.sin(2.0 * math.pi * tb * 1.15))
        ang = (1 if fi % 2 == 0 else -1) * math.radians(26 + 7 * fi)
        rot = np.array([[math.cos(ang), -math.sin(ang)], [math.sin(ang), math.cos(ang)]])
        d2 = (rot @ d) * (0.52 - 0.10 * fi)
        draw.polygon(tongue_poly(base, base + d2, width * 0.55, curl * 0.5 * (1 if fi % 2 == 0 else -1), to_px, n=24, sway=sway * 0.6), fill=255)


def build_flame_rasters():
    """SIDE raster over (f, u) = the traced photo flames + three procedural tongues; TOP raster over (f, |x|) = the crown flames."""
    from scipy import ndimage as ndi
    cols = int(round((SIDE_F1 - SIDE_F0) / MM))
    rows = int(round((SIDE_U1 - SIDE_U0) / MM))
    f = SIDE_F0 + (np.arange(cols) + 0.5) * MM
    u = SIDE_U1 - (np.arange(rows) + 0.5) * MM
    gf, gu = np.meshgrid(f, u)
    px_x = PHOTO_AXLE_X - (gf - FA) * PHOTO_D
    px_y = PHOTO_GROUND_Y - gu * PHOTO_D
    side = ndi.map_coordinates(traced_flames().astype(np.float32), [px_y, px_x], order=1, mode="constant", cval=0.0)
    extra = Image.new("L", (cols, rows), 0)
    ed = ImageDraw.Draw(extra)
    to_side = lambda p: ((p[0] - SIDE_F0) / MM, (SIDE_U1 - p[1]) / MM)
    SIDES = [  # (f, u) root, tip, half-width, curl: the tank cowl, the rear fender side (rising), the front fender side (licking back from the nose)
        ((0.34, 1.20), (-0.20, 1.30), 0.050, 0.06), ((-0.98, 1.00), (-1.30, 1.30), 0.055, 0.10), ((-1.18, 0.96), (-1.55, 1.27), 0.055, 0.11),
        ((-1.45, 0.93), (-1.70, 1.18), 0.045, 0.08),
        ((1.66, 1.00), (0.95, 1.12), 0.060, 0.07), ((1.58, 1.10), (0.84, 1.24), 0.060, 0.08), ((1.40, 0.96), (0.82, 1.02), 0.045, 0.05)]
    for root, tip, w, curl in SIDES:
        flame_cluster(ed, root, tip, w, curl, to_side, forks=1, sway=0.02)
    side = np.maximum(side, np.asarray(extra, np.float32) / 255.0)
    # crown flames: roots at the nose / the tail, licking back along each fender and across the tank cowl (x is mirrored: |x|)
    trows = int(round(TOP_X1 / MM))
    top_im = Image.new("L", (cols, trows), 0)
    td = ImageDraw.Draw(top_im)
    to_top = lambda p: ((p[0] - SIDE_F0) / MM, p[1] / MM)
    TOPS = [  # (f, |x|) root, tip, half-width, curl: bold tongues licking back from the nose along each fender, across the tank cowl, forward from the tail
        ((1.70, 0.16), (0.98, 0.30), 0.085, 0.07), ((1.68, 0.40), (0.80, 0.54), 0.100, 0.11), ((1.60, 0.64), (0.72, 0.80), 0.105, 0.13), ((1.44, 0.86), (0.70, 0.98), 0.085, 0.10),
        ((1.36, 0.30), (1.00, 0.36), 0.050, 0.05),
        ((0.84, 0.16), (0.10, 0.26), 0.075, 0.07), ((0.80, 0.34), (0.22, 0.44), 0.060, 0.06),
        ((-1.78, 0.24), (-0.98, 0.38), 0.085, -0.07), ((-1.76, 0.50), (-0.86, 0.66), 0.105, -0.11), ((-1.66, 0.76), (-0.80, 0.90), 0.090, -0.10)]
    for root, tip, w, curl in TOPS:
        flame_cluster(td, root, tip, w, curl, to_top, forks=2, sway=0.035)
    return side, np.asarray(top_im, np.float32) / 255.0


def panel_geometry(name):
    """Texel -> 3D position and OUTWARD normal for the panel's atlas rect, from the loft grid (the same bilinear patches the mesh is built from)."""
    from scipy import ndimage as ndi
    P = PANELS[name]
    x0, y0, w, h = RECTS[name]
    G = np.array(P["grid"], np.float64)                       # [stations, ring, 3] = (x, f, u)
    tv = np.array(P["tvals"], np.float64)
    m, open_b = P["m"], P["open"]
    tt = np.clip((np.arange(w) + 0.5 - PAD) / (w - 2 * PAD), 0, 1)
    vv = np.clip((np.arange(h) + 0.5 - PAD) / (h - 2 * PAD), 0, 1)
    T, VF = np.meshgrid(tt, vv)
    if open_b:
        S_ = 0.5 + 0.5 * VF                                   # the right-hand half of the arch: crown (0.5) -> right edge (1.0)
    else:
        a = VF * 0.5
        S_ = np.where(a <= 0.25, 0.25 - a, 1.25 - a)          # the right-hand half of the ring
    order = np.argsort(tv)
    tv_s, G_s = tv[order], G[order]
    k = np.clip(np.searchsorted(tv_s, T, side="right") - 1, 0, len(tv_s) - 2)
    wk = ((T - tv_s[k]) / (tv_s[k + 1] - tv_s[k]))[..., None]
    ring_n = G_s.shape[1]
    sf = S_ * m
    i0 = np.clip(np.floor(sf).astype(int), 0, m - 1)
    wi = (sf - i0)[..., None]
    i1 = i0 + 1 if open_b else (i0 + 1) % ring_n
    A, B, C, D = G_s[k, i0], G_s[k, i1], G_s[k + 1, i0], G_s[k + 1, i1]
    P3 = (1 - wk) * ((1 - wi) * A + wi * B) + wk * ((1 - wi) * C + wi * D)
    dPdt = (1 - wi) * (C - A) + wi * (D - B)
    dPds = (1 - wk) * (B - A) + wk * (D - C)
    N = np.cross(dPdt, dPds)
    zc = 0.85 if open_b else 1.05
    cen = np.stack([np.zeros_like(P3[..., 0]), P3[..., 1], np.full_like(P3[..., 2], zc)], -1)
    sgn = np.sign(np.sum(N * (P3 - cen), -1, keepdims=True))
    N = N * np.where(sgn == 0, 1.0, sgn)
    N = np.stack([ndi.gaussian_filter(N[..., c], 2.0) for c in range(3)], -1)
    N = N / np.maximum(np.linalg.norm(N, axis=-1, keepdims=True), 1e-9)
    return P3, N


def bake_panel(name, side, top, rng):
    from scipy import ndimage as ndi
    P3, N = panel_geometry(name)
    X, Fv, Z = P3[..., 0], P3[..., 1], P3[..., 2]
    sample = lambda ras, r, c: ndi.map_coordinates(ras, [r, c], order=1, mode="constant", cval=0.0)
    ws = smoothstep(0.35, 0.75, np.abs(N[..., 0]))
    wt = smoothstep(0.45, 0.80, N[..., 2])
    ms = sample(side, (SIDE_U1 - Z) / MM - 0.5, (Fv - SIDE_F0) / MM - 0.5) * ws
    mt = sample(top, np.abs(X) / MM - 0.5, (Fv - SIDE_F0) / MM - 0.5) * wt
    M = np.maximum(ms, mt) > 0.5
    # candy-apple base: lighter high on the panels, deep low down, an isotropic metallic flake (a 5 mm cube grain whatever the layout)
    y = np.clip((1.65 - Z) / 1.15, 0, 1)
    col = np.stack([0.52 - 0.22 * y ** 1.2, 0.035 + 0.02 * (1 - y), 0.045 + 0.015 * (1 - y)], -1)
    fl = cellnoise(P3, 1.0 / MM) - 0.5
    col = col + fl[..., None] * np.array([0.050, 0.012, 0.012])
    # flames: orange -> yellow -> hot white toward the core, a dark maroon pinstripe around every tongue
    din = ndi.distance_transform_edt(M, sampling=MM)
    dout = ndi.distance_transform_edt(~M, sampling=MM)
    wob = ndi.gaussian_filter(rng.normal(0, 1, M.shape), 3.0) * 0.045
    d = np.clip(din + wob, 0, None)
    ramp_d = [0.0, 0.006, 0.016, 0.030, 0.048, 0.072]
    ramp = np.array([(205, 40, 12), (240, 85, 12), (255, 135, 18), (255, 190, 44), (255, 225, 110), (255, 244, 170)], np.float64) / 255.0
    flame = np.stack([np.interp(d, ramp_d, ramp[:, c]) for c in range(3)], -1)
    col = np.where(M[..., None], flame, col)
    pin = (~M) & (dout <= 0.010)
    k = np.clip(1.0 - (dout - 0.002) / 0.008, 0, 1)[..., None] * pin[..., None]
    col = col * (1 - k) + np.array([0.33, 0.02, 0.04]) * k
    # honest wear: mud thick low on the panels and thrown up behind each wheel (distance to the tyre surface in the f/u plane), broken up by 3D noise
    hgt = np.clip((1.32 - Z) / 0.55, 0, 1)
    spray = np.zeros_like(Z)
    for fa in (FA, RA):
        dist = np.hypot(Fv - fa, Z - R) - R
        spray = np.maximum(spray, np.exp(-np.clip(dist, 0, None) / 0.40))
    amt = np.clip(0.60 * hgt ** 2.2 + 0.45 * spray * hgt ** 1.2, 0, 1)
    nz = 0.5 * vnoise(P3, 7.0) + 0.3 * vnoise(P3, 21.0, 1) + 0.2 * vnoise(P3, 70.0, 2)
    cover = smoothstep(0.74 - 0.42 * amt, 0.80 - 0.42 * amt, nz) * (1.0 - 0.55 * M)      # mud sits ON TOP of the paint but flames stay mostly readable
    mud = np.array([0.20, 0.125, 0.065]) * (0.75 + 0.5 * vnoise(P3, 140.0, 3))[..., None]
    col = col * (1 - 0.80 * cover[..., None]) + mud * 0.80 * cover[..., None]
    col = ndi.gaussian_filter(col, sigma=(0.8, 0.8, 0))
    return np.clip(col, 0, 1)


def bake_paint(path):
    """Paint the whole atlas (called once every red panel has registered its loft in PANELS)."""
    side, top = build_flame_rasters()
    rng = np.random.default_rng(11)
    atlas = np.zeros((ATLAS_H, ATLAS_W, 3), np.float64)
    atlas[:] = np.array([0.30, 0.03, 0.04])
    for name, (x0, y0, w, h) in RECTS.items():
        atlas[y0:y0 + h, x0:x0 + w] = bake_panel(name, side, top, rng)
    Image.fromarray((atlas * 255).astype(np.uint8)).save(path, "JPEG", quality=92)


def make_grime(path, size=512, base=(0.04, 0.04, 0.045), mud=(0.22, 0.14, 0.07), seed=3, ship=256):
    """A dark rubber / steel base with mud patches (value-noise threshold) and speckle. Generated at `size`, shipped at `ship`."""
    rng = np.random.default_rng(seed)
    def noise(n):
        a = rng.random((n, n)).astype(np.float32)
        return np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), np.float32) / 255.0
    n = 0.5 * noise(6) + 0.3 * noise(14) + 0.2 * noise(40)
    patch = np.clip((n - 0.46) * 3.2, 0, 1)[..., None]
    speck = (rng.random((size, size, 1)) < 0.03).astype(np.float32)
    col = np.array(base, np.float32) * (1 - patch) + np.array(mud, np.float32) * patch
    col = col * (1 - 0.5 * speck) + np.array(mud, np.float32) * 0.5 * speck
    im = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8))
    (im if ship == size else im.resize((ship, ship), Image.LANCZOS)).save(path, "JPEG", quality=88)


os.makedirs(TEXDIR, exist_ok=True)
PAINT_TEX = os.path.join(TEXDIR, "quad_paint.jpg")
GRIME_TEX = os.path.join(TEXDIR, "quad_rubber.jpg")
STEEL_TEX = os.path.join(TEXDIR, "quad_grime_steel.jpg")
RIM_TEX = os.path.join(TEXDIR, "quad_rim.jpg")
make_grime(GRIME_TEX)
make_grime(STEEL_TEX, base=(0.16, 0.16, 0.17), mud=(0.20, 0.13, 0.07), seed=5, ship=128)
make_grime(RIM_TEX, base=(0.52, 0.52, 0.54), mud=(0.26, 0.16, 0.08), seed=9, ship=256)

# M_PAINT is created AFTER the red panels exist (bake_paint needs their loft grids), see below
# NOTE chrome: the Compatibility renderer reflects only the SKY - in a sky-less room a fully metallic surface renders BLACK. The quad lives in the bear woods (a real sky), so 0.8 is right.
M_CHROME = mat("Quad_Chrome", (0.62, 0.62, 0.66), metal=0.92, rough=0.16)
M_RUBBER = mat("Quad_Rubber", (1, 1, 1), metal=0.0, rough=0.92, tex=GRIME_TEX)
M_SEAT = mat("Quad_Seat", (0.025, 0.025, 0.028), metal=0.0, rough=0.5, coat=0.4)
M_STEEL = mat("Quad_Steel", (1, 1, 1), metal=0.5, rough=0.5, tex=STEEL_TEX)
M_BLACK = mat("Quad_BlackPlastic", (0.03, 0.03, 0.034), metal=0.0, rough=0.55)
M_RIM = mat("Quad_Rim", (1, 1, 1), metal=0.6, rough=0.42, tex=RIM_TEX)
M_ENGINE = mat("Quad_Engine", (0.34, 0.35, 0.37), metal=0.4, rough=0.45)
M_SPRING = mat("Quad_Spring", (0.55, 0.03, 0.03), metal=0.5, rough=0.35)
M_LENS = mat("Quad_Lens", (1.0, 0.95, 0.8), metal=0.0, rough=0.1, emit=(1.0, 0.92, 0.7), emit_strength=2.5)
M_TAIL = mat("Quad_TailLamp", (0.8, 0.02, 0.02), metal=0.0, rough=0.2, emit=(1.0, 0.05, 0.05), emit_strength=1.5)
M_BRASS = mat("Quad_Brass", (0.78, 0.55, 0.18), metal=0.5, rough=0.3)

ROOT_EMPTY = bpy.data.objects.new("QuadModel", None)
S.collection.objects.link(ROOT_EMPTY)


# =============================================================================================================================
# WHEELS
# =============================================================================================================================
TIRE_PROFILE = [(-0.170, 0.300), (-0.205, 0.340), (-0.218, 0.400), (-0.205, 0.452), (-0.155, 0.490), (-0.100, 0.500), (0.0, 0.502),
                (0.100, 0.500), (0.155, 0.490), (0.205, 0.452), (0.218, 0.400), (0.205, 0.340), (0.170, 0.300)]


def make_wheel(name, centre, side):
    """`side` = +1 for the right tyres (dish faces +X), -1 for the left. Axle = local X. Lathe tyre + chunky chevron lugs + steel rim."""
    seg = 56
    bm = bmesh.new()
    rings = []
    prof = TIRE_PROFILE
    for k in range(seg):
        a = 2 * math.pi * k / seg
        ca, sa = math.cos(a), math.sin(a)
        ring = []
        for (x, r) in prof:
            ring.append(bm.verts.new((x * side, r * ca, r * sa)))
        rings.append(ring)
    uvs = {}
    for k in range(seg):
        for j in range(len(prof) - 1):
            a, b = rings[k][j], rings[k][j + 1]
            c, d = rings[(k + 1) % seg][j + 1], rings[(k + 1) % seg][j]
            f = bm.faces.new((a, b, c, d) if side > 0 else (d, c, b, a))
            f.smooth = True
    # inner liner (so the rim hole is closed): a ring at the bead
    inner_a = [rings[k][0] for k in range(seg)]
    inner_b = [rings[k][-1] for k in range(seg)]
    for k in range(seg):
        k2 = (k + 1) % seg
        bm.faces.new((inner_a[k], inner_a[k2], inner_b[k2], inner_b[k]) if side > 0 else (inner_b[k], inner_b[k2], inner_a[k2], inner_a[k]))
    # lugs: two chevron rows + shoulder blocks
    nl = 26
    lug_h = 0.040
    for half in (-1, 1):
        for k in range(nl):
            a = 2 * math.pi * (k + (0.5 if half > 0 else 0.0)) / nl
            ca, sa = math.cos(a), math.sin(a)
            tang = Vector((0, -sa, ca))
            rad = Vector((0, ca, sa))
            # lug footprint on the crown: x from 0.012 to 0.150 (outward), skewed along the tangent for the chevron
            for (x0, x1) in ((0.010, 0.095), (0.100, 0.172)):
                pts = []
                for (xx, tt, hh) in ((x0, -0.034, 0.0), (x1, -0.034 + half * 0.045, 0.0), (x1, 0.034 + half * 0.045, 0.0), (x0, 0.034, 0.0)):
                    base_r = 0.5 - 0.0035 - 0.006 * (xx / 0.17) ** 2
                    pts.append((xx * half * side, base_r, tt))
                top = []
                for (xx, rr, tt) in pts:
                    p = Vector((xx, 0, 0)) + rad * (rr + lug_h) + tang * tt
                    top.append(bm.verts.new(p))
                bot = []
                for (xx, rr, tt) in pts:
                    p = Vector((xx, 0, 0)) + rad * (rr - 0.004) + tang * tt
                    bot.append(bm.verts.new(p))
                try:
                    bm.faces.new(top[::-1] if half * side > 0 else top)
                    for i in range(4):
                        j = (i + 1) % 4
                        bm.faces.new((bot[i], bot[j], top[j], top[i]) if half * side > 0 else (bot[j], bot[i], top[i], top[j]))
                except ValueError:
                    pass
    bm.normal_update()
    # simple cylindrical UVs for the mud texture
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for lp in f.loops:
            p = lp.vert.co
            ang = math.atan2(p.z, p.y) / (2 * math.pi) + 0.5
            lp[uv_layer].uv = (ang * 3.0, (p.x * side + 0.22) * 1.2)
    o = bm_obj(name, bm, M_RUBBER, ROOT_EMPTY, loc=V(*centre), smooth=True)
    # --- rim: dished steel disc + lip + hub + lug nuts + the six little holes ---
    rb = bmesh.new()
    segs = 48
    def ring_at(x, r):
        return [rb.verts.new((x * side, r * math.cos(2 * math.pi * k / segs), r * math.sin(2 * math.pi * k / segs))) for k in range(segs)]
    stations = [(0.150, 0.300), (0.185, 0.300), (0.195, 0.282), (0.172, 0.262), (0.150, 0.250), (0.128, 0.08), (0.150, 0.075), (0.172, 0.060), (0.172, 0.0)]
    rs = []
    for (x, r) in stations[:-1]:
        rs.append(ring_at(x, r))
    for i in range(len(rs) - 1):
        for k in range(segs):
            k2 = (k + 1) % segs
            f = rb.faces.new((rs[i][k], rs[i][k2], rs[i + 1][k2], rs[i + 1][k]) if side > 0 else (rs[i + 1][k], rs[i + 1][k2], rs[i][k2], rs[i][k]))
            f.smooth = True
    cap = rb.verts.new((0.172 * side, 0, 0))
    for k in range(segs):
        k2 = (k + 1) % segs
        rb.faces.new((rs[-1][k], rs[-1][k2], cap) if side > 0 else (cap, rs[-1][k2], rs[-1][k]))
    ro = bm_obj(name + "_Rim", rb, M_RIM, o, smooth=True)
    for i in range(6):
        a = 2 * math.pi * i / 6
        hole = cyl(name + "_Hole%d" % i, (0, 0, 0), 0.026, 0.006, M_BLACK, "X", ro, segs=12)
        hole.location = Vector((0.1745 * side, 0.165 * math.cos(a), 0.165 * math.sin(a)))
    for i in range(5):
        a = 2 * math.pi * i / 5
        nut = cyl(name + "_Nut%d" % i, (0, 0, 0), 0.018, 0.03, M_CHROME, "X", ro, segs=6)
        nut.location = Vector((0.18 * side, 0.045 * math.cos(a), 0.045 * math.sin(a)))
    boss = cyl(name + "_Boss", (0, 0, 0), 0.030, 0.045, M_STEEL, "X", ro, segs=16)
    boss.location = Vector((0.19 * side, 0, 0))
    return o


WHEELS = {}
for nm, (x, f, s) in {"Wheel_FL": (-TRK / 2, FA, -1), "Wheel_FR": (TRK / 2, FA, 1), "Wheel_RL": (-TRK / 2, RA, -1), "Wheel_RR": (TRK / 2, RA, 1)}.items():
    WHEELS[nm] = make_wheel(nm, (x, f, R), s)


# =============================================================================================================================
# RED BODY PANELS (the paint is baked per panel from 3D position: see bake_paint)
# =============================================================================================================================
def shell(name, stations, material, thickness=0.0, open_bottom=False, n=18, parent=None, paint=False):
    """Loft a rounded-section shell along f. stations: dict(f, w, top, bot, r, edge) -> a superellipse-ish ring.
       open_bottom=True builds only the top arch (a fender): its side edges end at `edge` height instead of closing under.
       paint=True registers the loft grid in PANELS and gives every loop its ATLAS UV (u = along the length, v = folded distance from the crown)."""
    rings = []
    verts = []
    grid = []
    for st in stations:
        f, w, top, bot = st["f"], st["w"], st["top"], st["bot"]
        edge = st.get("edge", bot)
        ring = []
        row = []
        m = n
        for i in range(m + 1 if open_bottom else m):
            if open_bottom:
                phi = -math.pi * 0.5 + math.pi * i / m           # left edge -> over the crown -> right edge
                x = w * math.sin(phi) * 1.0
                cr = math.cos(phi) ** 0.6
                u = edge + (top - edge) * cr
            else:
                phi = 2 * math.pi * i / m
                c, s = math.cos(phi), math.sin(phi)
                ex = 0.42                                          # superellipse exponent: boxy section with round corners
                x = w * math.copysign(abs(c) ** ex, c)
                u0 = 0.5 * (top + bot) + 0.5 * (top - bot) * math.copysign(abs(s) ** ex, s)
                u = u0
            ring.append(len(verts))
            verts.append(V(x, f, u))
            row.append((x, f, u))
        rings.append(ring)
        grid.append(row)
    faces = []
    for a, b in zip(rings[:-1], rings[1:]):
        cnt = len(a)
        for i in range(cnt - (1 if open_bottom else 0)):
            j = (i + 1) % cnt
            faces.append((a[i], a[j], b[j], b[i]))
    if not open_bottom:
        faces.append(tuple(rings[0][::-1]))
        faces.append(tuple(rings[-1]))
    o = obj_from(name, verts, faces, material, None, True, parent or ROOT_EMPTY)
    me = o.data
    me.update()
    if paint:
        f_vals = [st["f"] for st in stations]
        f0, f1 = min(f_vals), max(f_vals)
        tvals = [(f - f0) / (f1 - f0) for f in f_vals]
        PANELS[name] = dict(grid=grid, tvals=tvals, open=open_bottom, m=n)
        fold = fold_open if open_bottom else fold_ring
        uvl = me.uv_layers.new(name="UVMap")
        pi = 0
        for k in range(len(rings) - 1):
            cnt = len(rings[k])
            for i in range(cnt - (1 if open_bottom else 0)):
                poly = me.polygons[pi]
                pi += 1
                corners = [(tvals[k], i / n), (tvals[k], (i + 1) / n), (tvals[k + 1], (i + 1) / n), (tvals[k + 1], i / n)]
                for li, (t, s_) in zip(poly.loop_indices, corners):
                    uvl.data[li].uv = atlas_uv(name, t, fold(s_))
        if not open_bottom:                                        # the two end caps (hidden inside the body): the same fold, at the end stations
            poly = me.polygons[pi]
            pi += 1
            for li, idx in zip(poly.loop_indices, list(range(len(rings[0])))[::-1]):
                uvl.data[li].uv = atlas_uv(name, tvals[0], fold(idx / n))
            poly = me.polygons[pi]
            pi += 1
            for li, idx in zip(poly.loop_indices, range(len(rings[-1]))):
                uvl.data[li].uv = atlas_uv(name, tvals[-1], fold(idx / n))
    if thickness > 0:
        sol = o.modifiers.new("solid", "SOLIDIFY")
        sol.thickness = thickness
        sol.offset = -1
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    return o


# front fender / nose cover (an arch over the wheels and the nose)
FRONT = [
    dict(f=1.76, w=0.14, top=1.05, bot=1.0, edge=1.00),
    dict(f=1.66, w=0.40, top=1.08, bot=0.98, edge=0.99),
    dict(f=1.48, w=0.80, top=1.19, bot=0.98, edge=0.95),
    dict(f=1.26, w=0.93, top=1.28, bot=0.94, edge=0.86),
    dict(f=1.00, w=0.95, top=1.34, bot=0.92, edge=0.80),
    dict(f=0.78, w=0.93, top=1.30, bot=0.93, edge=0.86),
    dict(f=0.62, w=0.78, top=1.25, bot=0.97, edge=1.05),
]
front_fender = shell("Fender_Front", FRONT, None, thickness=0.035, open_bottom=True, n=20, paint=True)

# rear fender over the back wheels
REAR = [
    dict(f=-0.55, w=0.74, top=1.30, bot=0.95, edge=1.02),
    dict(f=-0.78, w=0.93, top=1.30, bot=0.93, edge=0.88),
    dict(f=-1.22, w=0.95, top=1.36, bot=0.92, edge=0.78),
    dict(f=-1.55, w=0.93, top=1.31, bot=0.93, edge=0.88),
    dict(f=-1.82, w=0.78, top=1.27, bot=0.96, edge=1.03),
]
rear_fender = shell("Fender_Rear", REAR, None, thickness=0.035, open_bottom=True, n=20, paint=True)

# centre tub + tank (closed loft)
TUB = [
    dict(f=0.90, w=0.24, top=1.40, bot=1.00, r=0.1),
    dict(f=0.66, w=0.34, top=1.52, bot=0.78, r=0.12),
    dict(f=0.30, w=0.38, top=1.50, bot=0.66, r=0.12),
    dict(f=0.00, w=0.40, top=1.36, bot=0.62, r=0.12),
    dict(f=-0.45, w=0.40, top=1.31, bot=0.62, r=0.12),
    dict(f=-0.90, w=0.40, top=1.30, bot=0.70, r=0.12),
    dict(f=-1.30, w=0.38, top=1.29, bot=0.86, r=0.12),
    dict(f=-1.70, w=0.30, top=1.25, bot=0.98, r=0.1),
]
tub = shell("Body_Tub", TUB, None, n=24, paint=True)

# the paint is baked now that all three panels have registered their lofts, then it becomes THE material of those panels
bake_paint(PAINT_TEX)
M_PAINT = mat("Quad_Paint", (1, 1, 1), metal=0.18, rough=0.30, coat=1.0, tex=PAINT_TEX)
for _o in (front_fender, rear_fender, tub):
    _o.data.materials.append(M_PAINT)

# seat (leather)
SEAT = [   # a padded bench wider than the tub under it (visible side roll), 1.575 m at the crown
    dict(f=0.22, w=0.27, top=1.50, bot=1.28), dict(f=0.05, w=0.38, top=1.56, bot=1.26), dict(f=-0.55, w=0.44, top=1.575, bot=1.25),
    dict(f=-1.00, w=0.44, top=1.57, bot=1.25), dict(f=-1.30, w=0.36, top=1.50, bot=1.26),
]
seat = shell("Seat", SEAT, M_SEAT, n=24)


# =============================================================================================================================
# FRAME, ENGINE, SUSPENSION, FOOTBOARDS
# =============================================================================================================================
# main frame rails + cross members
for sx in (-1, 1):
    tube("Frame_Rail%d" % sx, [(0.30 * sx, 1.15, 0.62), (0.30 * sx, 0.40, 0.56), (0.30 * sx, -0.85, 0.58), (0.30 * sx, -1.30, 0.78)], 0.032, M_STEEL, parent=ROOT_EMPTY, round_r=0.12)
    tube("Frame_Up%d" % sx, [(0.26 * sx, 1.0, 0.62), (0.24 * sx, 0.7, 1.05), (0.16 * sx, 0.5, 1.30)], 0.026, M_STEEL, parent=ROOT_EMPTY, round_r=0.05)
for f in (0.95, 0.2, -0.5, -1.05):
    tube("Frame_Cross%.2f" % f, [(-0.30, f, 0.6), (0.30, f, 0.6)], 0.024, M_STEEL, parent=ROOT_EMPTY)

# engine: crankcase, finned cylinder, head, clutch cover, exhaust
box("Engine_Case", (0.0, 0.45, 0.80), (0.46, 0.62, 0.40), M_ENGINE, ROOT_EMPTY, bevel=0.04)
cyl("Engine_Cylinder", (0.0, 0.62, 1.04), 0.14, 0.30, M_ENGINE, "Z", ROOT_EMPTY, segs=16)
for i in range(6):
    cyl("Engine_Fin%d" % i, (0.0, 0.62, 0.93 + 0.05 * i), 0.18, 0.012, M_ENGINE, "Z", ROOT_EMPTY, segs=16)
cyl("Engine_ClutchCover", (0.25, 0.22, 0.78), 0.17, 0.05, M_ENGINE, "X", ROOT_EMPTY, segs=20)
cyl("Engine_ClutchCoverL", (-0.25, 0.22, 0.78), 0.14, 0.05, M_ENGINE, "X", ROOT_EMPTY, segs=20)
tube("Exhaust", [(0.30, 0.98, 0.78), (0.36, 0.55, 0.64), (0.34, -0.40, 0.64), (0.40, -1.35, 0.78)], 0.045, M_CHROME, parent=ROOT_EMPTY, round_r=0.10)
cyl("Exhaust_Tip", (0.40, -1.62, 0.80), 0.06, 0.38, M_CHROME, "Y", ROOT_EMPTY, segs=14)

# footboards (black, muddy) + the side kick panels
for sx in (-1, 1):
    box("Footboard%d" % sx, (0.52 * sx, -0.05, 0.585), (0.36, 1.45, 0.045), M_BLACK, ROOT_EMPTY, bevel=0.012)
    box("Sill%d" % sx, (0.38 * sx, -0.05, 0.69), (0.05, 1.40, 0.18), M_BLACK, ROOT_EMPTY, bevel=0.01)
    # footboard grip ribs
    for k in range(10):
        box("Rib%d_%d" % (sx, k), (0.52 * sx, 0.55 - 0.13 * k, 0.612), (0.30, 0.025, 0.012), M_STEEL, ROOT_EMPTY)

# front suspension: double A-arms, red coil-over shocks, steering knuckles
for sx in (-1, 1):
    hubx = sx * (TRK / 2 - 0.20)
    tube("Aarm_Up%d" % sx, [(0.20 * sx, 1.08, 0.80), (hubx, FA, 0.66)], 0.022, M_STEEL, parent=ROOT_EMPTY)
    tube("Aarm_Low%d" % sx, [(0.22 * sx, 1.06, 0.40), (hubx, FA + 0.02, 0.34)], 0.025, M_STEEL, parent=ROOT_EMPTY)
    tube("Knuckle%d" % sx, [(hubx, FA, 0.66), (hubx, FA, 0.34)], 0.035, M_STEEL, parent=ROOT_EMPTY)
    sp = tube("Spring%d" % sx, [(0, 0, 0)], 0.012, M_SPRING, parent=ROOT_EMPTY)
    # coil spring: a helix drawn as a curve between the mounts
    cu = bpy.data.curves.new("SpringCurve%d" % sx, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.014
    cu.bevel_resolution = 3
    spl = cu.splines.new("POLY")
    turns, steps = 9, 90
    spl.points.add(steps)
    for i, p in enumerate(spl.points):
        t = i / steps
        a = 2 * math.pi * turns * t
        v = V(0.34 * sx + 0.055 * math.cos(a), FA + 0.05 + 0.055 * math.sin(a), 0.38 + 0.52 * t)
        p.co = (v.x, v.y, v.z, 1)
    so = bpy.data.objects.new("CoilOver%d" % sx, cu)
    so.data.materials.append(M_SPRING)
    S.collection.objects.link(so)
    so.parent = ROOT_EMPTY
    bpy.data.objects.remove(sp, do_unlink=True)
    tube("Shock%d" % sx, [(0.34 * sx, FA + 0.05, 0.36), (0.34 * sx, FA + 0.05, 0.93)], 0.020, M_CHROME, parent=ROOT_EMPTY)
# rear swingarm + shock + axle
tube("Swingarm", [(-TRK / 2 + 0.2, RA, 0.50), (-0.28, -0.55, 0.62), (0.28, -0.55, 0.62), (TRK / 2 - 0.2, RA, 0.50)], 0.04, M_STEEL, parent=ROOT_EMPTY, round_r=0.08)
tube("RearAxle", [(-TRK / 2 + 0.2, RA, 0.5), (TRK / 2 - 0.2, RA, 0.5)], 0.045, M_STEEL, parent=ROOT_EMPTY)
tube("RearShock", [(0.0, -0.70, 0.85), (0.0, -1.10, 1.10)], 0.03, M_SPRING, parent=ROOT_EMPTY)


# =============================================================================================================================
# CHROME: bull bar, rear rack, handlebar, headlight with its wire guard
# =============================================================================================================================
# front bull bar / brush guard with the slat panel
bar = [(-0.50, 1.55, 0.72), (-0.52, 1.88, 0.80), (-0.50, 1.93, 1.05), (0.50, 1.93, 1.05), (0.52, 1.88, 0.80), (0.50, 1.55, 0.72)]
tube("BullBar_Frame", bar, 0.034, M_CHROME, parent=ROOT_EMPTY, round_r=0.07)
tube("BullBar_Top", [(-0.46, 1.90, 1.03), (-0.46, 1.60, 1.00), (0.46, 1.60, 1.00), (0.46, 1.90, 1.03)], 0.028, M_CHROME, parent=ROOT_EMPTY, round_r=0.05)
for k in range(5):
    x = -0.30 + 0.15 * k
    tube("BullBar_Slat%d" % k, [(x, 1.91, 0.78), (x, 1.91, 1.03)], 0.016, M_CHROME, parent=ROOT_EMPTY)
tube("BullBar_Mount", [(-0.40, 1.55, 0.72), (-0.40, 1.15, 0.64)], 0.03, M_CHROME, parent=ROOT_EMPTY)
tube("BullBar_MountR", [(0.40, 1.55, 0.72), (0.40, 1.15, 0.64)], 0.03, M_CHROME, parent=ROOT_EMPTY)

# rear rack: perimeter loop + rails + cross rails + a raised rear hoop (the passenger's shooting rest)
RK_F0, RK_F1, RK_W, RK_U = -0.95, -1.97, 0.50, 1.50
tube("Rack_Loop", [(-RK_W, RK_F0, RK_U), (-RK_W, RK_F1, RK_U), (RK_W, RK_F1, RK_U), (RK_W, RK_F0, RK_U)], 0.026, M_CHROME, parent=ROOT_EMPTY, closed=True, round_r=0.08)
for x in (-0.25, 0.0, 0.25):
    tube("Rack_Rail%.2f" % x, [(x, RK_F0, RK_U), (x, RK_F1, RK_U)], 0.018, M_CHROME, parent=ROOT_EMPTY)
for f in (-1.15, -1.40, -1.65, -1.90):
    tube("Rack_Cross%.2f" % f, [(-RK_W, f, RK_U), (RK_W, f, RK_U)], 0.018, M_CHROME, parent=ROOT_EMPTY)
tube("Rack_Hoop", [(-RK_W, RK_F1, RK_U), (-RK_W + 0.04, RK_F1 - 0.04, RK_U + 0.28), (RK_W - 0.04, RK_F1 - 0.04, RK_U + 0.28), (RK_W, RK_F1, RK_U)], 0.022, M_CHROME, parent=ROOT_EMPTY, round_r=0.08)
for sx in (-1, 1):
    tube("Rack_Leg%d" % sx, [(0.46 * sx, -1.0, RK_U), (0.46 * sx, -1.05, 1.28)], 0.030, M_CHROME, parent=ROOT_EMPTY)
    tube("Rack_LegB%d" % sx, [(0.46 * sx, -1.85, RK_U), (0.50 * sx, -1.65, 1.30)], 0.030, M_CHROME, parent=ROOT_EMPTY)
    box("Rack_Bracket%d" % sx, (0.46 * sx, -1.05, 1.285), (0.11, 0.11, 0.035), M_BLACK, ROOT_EMPTY, bevel=0.01)
    box("Rack_BracketB%d" % sx, (0.50 * sx, -1.65, 1.305), (0.11, 0.11, 0.035), M_BLACK, ROOT_EMPTY, bevel=0.01)
box("TailLamp", (0.0, -1.99, 1.30), (0.28, 0.04, 0.09), M_TAIL, ROOT_EMPTY, bevel=0.015)

# handlebar: stem, bar with the bend, grips, levers, the black headlight-visor pod and the fuel cap
HB_F = 0.60
tube("Steer_Stem", [(0.0, HB_F + 0.02, 1.42), (0.0, HB_F, 1.76)], 0.045, M_CHROME, parent=ROOT_EMPTY)
cyl("Steer_Column", (0.0, HB_F + 0.03, 1.56), 0.085, 0.26, M_BLACK, "Z", ROOT_EMPTY, segs=16, r2=0.065)
tube("Handlebar", [(-0.62, HB_F + 0.10, 1.80), (-0.46, HB_F + 0.02, 1.86), (-0.20, HB_F, 1.86), (0.20, HB_F, 1.86), (0.46, HB_F + 0.02, 1.86), (0.62, HB_F + 0.10, 1.80)], 0.021, M_CHROME, parent=ROOT_EMPTY, round_r=0.07)
tube("Handlebar_Brace", [(-0.30, HB_F, 1.86), (-0.30, HB_F - 0.02, 1.70), (0.30, HB_F - 0.02, 1.70), (0.30, HB_F, 1.86)], 0.014, M_CHROME, parent=ROOT_EMPTY)
for sx in (-1, 1):
    g = cyl("Grip%d" % sx, (0.58 * sx, HB_F + 0.10, 1.80), 0.032, 0.20, M_BLACK, "X", ROOT_EMPTY, segs=12)
    g.rotation_euler = (0, math.radians(8) * sx, 0)
    tube("Lever%d" % sx, [(0.50 * sx, HB_F + 0.20, 1.80), (0.42 * sx, HB_F + 0.36, 1.78)], 0.010, M_CHROME, parent=ROOT_EMPTY)
box("Visor_Pod", (0.0, HB_F + 0.22, 1.60), (0.36, 0.30, 0.14), M_BLACK, ROOT_EMPTY, bevel=0.045)
cyl("FuelCap", (0.0, 0.40, 1.545), 0.062, 0.035, M_BLACK, "Z", ROOT_EMPTY, segs=14)
cyl("FuelCapRing", (0.0, 0.40, 1.535), 0.072, 0.012, M_CHROME, "Z", ROOT_EMPTY, segs=14)

# headlight: a deep chrome bezel, the glowing lens, a stone-guard of wire rings + spokes
HL = (0.0, 1.70, 1.28)
cyl("Headlight_Bezel", HL, 0.165, 0.13, M_CHROME, "Y", ROOT_EMPTY, segs=24)
lens = cyl("Headlight_Lens", (HL[0], HL[1] + 0.066, HL[2]), 0.135, 0.02, M_LENS, "Y", ROOT_EMPTY, segs=24)
for k, rr in enumerate((0.150, 0.100, 0.050)):
    ring = bpy.ops.mesh.primitive_torus_add(major_radius=rr, minor_radius=0.006, major_segments=24, minor_segments=5)
    ro = bpy.context.active_object
    ro.rotation_euler = (math.radians(90), 0, 0)
    ro.location = V(HL[0], HL[1] + 0.086, HL[2])
    ro.data.materials.append(M_CHROME)
    ro.parent = ROOT_EMPTY
    S.collection.objects.unlink(ro) if False else None
for k in range(8):
    a = 2 * math.pi * k / 8
    tube("Guard_Spoke%d" % k, [(HL[0], HL[1] + 0.088, HL[2]), (HL[0] + 0.150 * math.cos(a), HL[1] + 0.088, HL[2] + 0.150 * math.sin(a))], 0.004, M_CHROME, parent=ROOT_EMPTY)
tube("Headlight_Bracket", [(0.0, 1.62, 1.12), (0.0, 1.70, 1.10)], 0.03, M_CHROME, parent=ROOT_EMPTY)


# =============================================================================================================================
# FINISH: preview scene (ground, sun, cameras), renders, glTF export
# =============================================================================================================================
def add_cam(name, loc, target, lens=45.0, ortho=0.0):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    co = bpy.data.objects.new(name, cd)
    S.collection.objects.link(co)
    co.location = loc
    d = (Vector(target) - Vector(loc)).normalized()
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return co


def preview():
    os.makedirs(PREVIEW, exist_ok=True)
    gm = bpy.data.materials.new("PreviewGround")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.38, 0.38, 0.40, 1)
    gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=2, y_segments=2, size=14.0)
    g = bm_obj("PreviewGround", bm, gm)
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.4
    sun.angle = math.radians(6)
    sun.color = (1.0, 0.88, 0.72)
    so = bpy.data.objects.new("Sun", sun)
    S.collection.objects.link(so)
    so.rotation_euler = (math.radians(52), 0, math.radians(-35))
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 220
    fill.size = 6
    fill.color = (0.62, 0.74, 1.0)
    fo = bpy.data.objects.new("Fill", fill)
    S.collection.objects.link(fo)
    fo.location = V(5, 3, 4)
    fo.rotation_euler = (math.radians(65), 0, math.radians(120))
    w = bpy.data.worlds.new("World")
    w.use_nodes = True
    bgn = w.node_tree.nodes["Background"]
    bgn.inputs["Color"].default_value = (0.55, 0.62, 0.74, 1)
    bgn.inputs["Strength"].default_value = 0.9
    S.world = w
    S.render.engine = "CYCLES"
    S.cycles.device = "CPU"
    S.cycles.samples = int(arg("--samples", 24))
    S.cycles.use_denoising = False
    S.render.resolution_x, S.render.resolution_y = 1000, 750
    S.view_settings.view_transform = "Filmic" if "Filmic" in [t.identifier for t in S.view_settings.bl_rna.properties["view_transform"].enum_items] else "Standard"
    shots = {
        "hero": add_cam("hero", V(-3.9, 4.0, 1.9), V(0.1, 0.1, 0.78), 42),
        "side": add_cam("side", V(-9.0, 0.0, 0.85), V(0.0, 0.0, 0.85), 50, ortho=4.9),
        "rear": add_cam("rear", V(-3.6, -4.3, 2.0), V(0.0, -0.3, 0.9), 42),
        "rider": add_cam("rider", V(0.30, -0.95, 2.40), V(0.0, 3.0, 1.55), 30),
        "front": add_cam("front", V(0.0, 5.5, 1.2), V(0.0, 0.0, 0.9), 40),
    }
    for nm, co in shots.items():
        S.camera = co
        S.render.filepath = os.path.join(PREVIEW, nm + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", nm)
    for o in (g, so, fo):
        bpy.data.objects.remove(o, do_unlink=True)
    for co in shots.values():
        bpy.data.objects.remove(co, do_unlink=True)


def _baked(o):
    """A real mesh object equal to `o` as evaluated (curves beveled, modifiers applied), same parent / transform / material."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    mt = o.data.materials[0] if o.data.materials else None
    me.materials.clear()
    if mt is not None:
        me.materials.append(mt)
    for p_ in me.polygons:
        p_.use_smooth = True
    no = bpy.data.objects.new(o.name, me)
    S.collection.objects.link(no)
    no.parent = o.parent
    no.matrix_parent_inverse = o.matrix_parent_inverse.copy()
    no.matrix_basis = o.matrix_basis.copy()
    return no


def merge_parts():
    """WEB DRAW-CALL BUDGET: 164 loose tubes/boxes = 164 draw calls (x2 with the shadow pass) for ONE parked vehicle. Merge every static part
    by material (-> ~12 meshes) and every wheel's parts by material (-> tyre + rim + holes + nuts + boss). The four Wheel_* nodes keep their names and
    origins (hub centre, axle = local X) so the chamber can still spin them; their parts keep a 'Wheel_XX_*' name so the chamber ignores them."""
    objs = [o for o in S.objects if o.type in ("MESH", "CURVE") and o.name not in ("PreviewGround",)]
    names = {o: o.name for o in objs}
    bake = {o: _baked(o) for o in objs}
    # re-parent baked children onto baked parents (parents are wheel tyres / rims; ROOT_EMPTY stays)
    for o, no in bake.items():
        if o.parent in bake:
            no.parent = bake[o.parent]
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    for o, no in bake.items():                 # the originals are gone: give the copies their names back (no '.001' on the Wheel_* nodes)
        no.name = names[o]
        no.data.name = names[o]
    def wheel_of(o):
        a = o
        while a is not None:
            if a.name.startswith("Wheel_") and a.name.count("_") == 1:
                return a.name
            a = a.parent
        return None
    groups = {}
    for no in bake.values():
        mt = no.data.materials[0].name if no.data.materials else "none"
        groups.setdefault((wheel_of(no) or "STATIC", mt), []).append(no)
    for (owner, mt), members in sorted(groups.items()):
        # the tyre object itself (name == owner) is the join target of its own material group so it keeps the node name
        target = next((m for m in members if m.name == owner), members[0])
        bpy.ops.object.select_all(action="DESELECT")
        for m in members:
            m.select_set(True)
        bpy.context.view_layer.objects.active = target
        if len(members) > 1:
            bpy.ops.object.join()
        if owner == "STATIC":
            target.name = target.data.name = mt.replace("Quad_", "Body_")
        elif target.name != owner:
            target.name = target.data.name = "%s_%s" % (owner, mt.replace("Quad_", ""))
    print("merged into", sum(1 for o in S.objects if o.type == "MESH"), "mesh nodes")


def export():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in S.objects:
        if o.type in ("MESH", "CURVE"):
            o.select_set(True)
    ROOT_EMPTY.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=86, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT", export_cameras=False, export_lights=False)
    print("exported", OUT, os.path.getsize(OUT) // 1024, "KB")


def stats():
    tris = 0
    for o in S.objects:
        if o.type in ("MESH", "CURVE"):
            ev = o.evaluated_get(bpy.context.evaluated_depsgraph_get())
            me = ev.to_mesh()
            me.calc_loop_triangles()
            tris += len(me.loop_triangles)
            ev.to_mesh_clear()
    print("triangles", tris)
    return tris


if __name__ == "__main__":
    merge_parts()
    stats()
    export()
    if RENDER:
        preview()
