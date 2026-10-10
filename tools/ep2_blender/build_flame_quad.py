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


# --- textures (PIL): the side-view flame paint, tyre mud ------------------------------------------------------------------------
PAINT_F0, PAINT_F1 = -2.05, 1.98       # texture U range along the length
PAINT_U0, PAINT_U1 = 0.50, 1.65        # texture V range along the height
PAINT_W, PAINT_H = 2048, 600
SHIP_DIV = 2                           # painted at PAINT_W x PAINT_H, shipped at 1/SHIP_DIV (web pck budget: VRAM-compressed textures cost ~1 byte/px)


def paint_uv(f, u):
    return ((f - PAINT_F0) / (PAINT_F1 - PAINT_F0), (u - PAINT_U0) / (PAINT_U1 - PAINT_U0))


def px(f, u, ss=1):
    x = (f - PAINT_F0) / (PAINT_F1 - PAINT_F0) * PAINT_W * ss
    y = (1.0 - (u - PAINT_U0) / (PAINT_U1 - PAINT_U0)) * PAINT_H * ss
    return (x, y)


REF_SIDE = os.path.join(ROOT, "artifacts/episode2-gold-mine/references/fort_knox_prep/flame_quad/side.jpg")
PHOTO_AXLE_X, PHOTO_GROUND_Y, PHOTO_D = 400.0, 960.0, 360.0      # measured on the side elevation: front axle pixel, ground line, tyre diameter in px


def traced_flames():
    """The flames, TRACED from the GPT-image side elevation (hue/saturation threshold), so the paint job on the model is the reference's:
    returns a bool mask in photo pixels. (A side view projects onto the body's side-planar UVs 1:1 because the model is built to the same proportions.)"""
    from scipy import ndimage as ndi
    im = Image.open(REF_SIDE).convert("RGB")
    hsv = np.asarray(im.convert("HSV"), np.float32) / 255.0
    h, s, v = hsv[..., 0] * 360.0, hsv[..., 1], hsv[..., 2]
    m = (h > 10) & (h < 64) & (s > 0.52) & (v > 0.55)
    m[:380, :] = False
    m[730:, :] = False
    m[:, :200] = False
    m[:, 1520:] = False
    m = ndi.binary_closing(m, iterations=3)
    m = ndi.binary_opening(m, iterations=1)
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    return np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 260])


def make_paint(path):
    from scipy import ndimage as ndi
    W, H = PAINT_W, PAINT_H
    rng = np.random.default_rng(11)
    # candy-apple red base: lighter high on the panels, deep at the bottom, with a fine metallic flake
    y = np.linspace(0, 1, H)[:, None]
    base = np.zeros((H, W, 3), np.float32)
    base[..., 0] = 0.52 - 0.22 * (y ** 1.2)
    base[..., 1] = 0.035 + 0.02 * (1 - y)
    base[..., 2] = 0.045 + 0.015 * (1 - y)
    base = np.clip(base + rng.normal(0, 0.016, (H, W, 1)).astype(np.float32) * np.array([1.0, 0.5, 0.5], np.float32), 0, 1)
    # texture px -> (f,u) -> photo px, then sample the traced mask
    f = PAINT_F0 + (np.arange(W) + 0.5) / W * (PAINT_F1 - PAINT_F0)
    u = PAINT_U1 - (np.arange(H) + 0.5) / H * (PAINT_U1 - PAINT_U0)
    px_x = PHOTO_AXLE_X - (f - FA) * PHOTO_D
    px_y = PHOTO_GROUND_Y - u * PHOTO_D
    gx, gy = np.meshgrid(px_x, px_y)
    mask = ndi.map_coordinates(traced_flames().astype(np.float32), [gy, gx], order=1, mode="constant", cval=0.0) > 0.5
    # extra tongues the side photo only half shows (tank cowl, rear fender), drawn procedurally in the same language
    extra = Image.new("L", (W, H), 0)
    ed = ImageDraw.Draw(extra)
    for root, tip, w, curl in [((0.34, 1.20), (-0.20, 1.30), 0.045, 0.06), ((-0.98, 1.00), (-1.30, 1.30), 0.05, 0.10), ((-1.18, 0.96), (-1.55, 1.27), 0.05, 0.11)]:
        n = 36
        left, right = [], []
        for i in range(n + 1):
            t = i / n
            ff = root[0] + (tip[0] - root[0]) * t
            uu = root[1] + (tip[1] - root[1]) * t + curl * t ** 2.2
            wd = w * (math.sin(math.pi * min(t, 1.0) * 0.9 + 0.2) ** 0.9) * (1 - t ** 1.5) * (1 + 0.15 * math.sin(t * 11.0))
            left.append(((ff - PAINT_F0) / (PAINT_F1 - PAINT_F0) * W, (1 - (uu + wd - PAINT_U0) / (PAINT_U1 - PAINT_U0)) * H))
            right.append(((ff - PAINT_F0) / (PAINT_F1 - PAINT_F0) * W, (1 - (uu - wd * 0.8 - PAINT_U0) / (PAINT_U1 - PAINT_U0)) * H))
        ed.polygon(left + right[::-1], fill=255)
    mask = mask | (np.asarray(extra) > 127)
    din = ndi.distance_transform_edt(mask)
    dout = ndi.distance_transform_edt(~mask)
    wob = ndi.gaussian_filter(rng.normal(0, 1, (H, W)).astype(np.float32), 6) * 14.0       # airbrush unevenness
    d = np.clip(din + wob * 0.5, 0, None)
    ramp_d = [0, 3, 8, 15, 24, 36]
    ramp = np.array([(205, 40, 12), (240, 85, 12), (255, 135, 18), (255, 190, 44), (255, 225, 110), (255, 244, 170)], np.float32) / 255.0
    flame = np.stack([np.interp(d, ramp_d, ramp[:, c]) for c in range(3)], -1).astype(np.float32)
    col = base.copy()
    col[mask] = flame[mask]
    pin = (~mask) & (dout <= 5.0)                                         # the dark maroon pinstripe around every tongue
    k = np.clip(1.0 - (dout[pin] - 1.0) / 4.0, 0, 1)[:, None]
    col[pin] = col[pin] * (1 - k) + np.array([0.33, 0.02, 0.04], np.float32) * k
    col = ndi.gaussian_filter(col, sigma=(1.0, 1.0, 0))
    # worn / muddy lower edge: brown speckle that thickens toward the bottom of the panels
    yy = np.linspace(1, 0, H)[:, None, None]
    mud = (rng.random((H, W, 1)) < (0.20 * np.clip(0.50 - (1 - yy), 0, 1) * 2.0)).astype(np.float32)
    col = col * (1 - 0.7 * mud) + np.array([0.17, 0.10, 0.05], np.float32) * 0.7 * mud
    im = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8))
    im.resize((W // SHIP_DIV, H // SHIP_DIV), Image.LANCZOS).save(path, "JPEG", quality=90)


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
make_paint(PAINT_TEX)
make_grime(GRIME_TEX)
make_grime(STEEL_TEX, base=(0.16, 0.16, 0.17), mud=(0.20, 0.13, 0.07), seed=5, ship=128)
make_grime(RIM_TEX, base=(0.52, 0.52, 0.54), mud=(0.26, 0.16, 0.08), seed=9, ship=256)

M_PAINT = mat("Quad_Paint", (1, 1, 1), metal=0.18, rough=0.30, coat=1.0, tex=PAINT_TEX)
# NOTE chrome: the Compatibility renderer reflects only the SKY - in a sky-less room a fully metallic surface renders BLACK. The quad lives in the bear woods (a real sky), so 0.8 is right.
M_CHROME = mat("Quad_Chrome", (0.80, 0.80, 0.83), metal=0.8, rough=0.20)
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
# RED BODY PANELS (one side-planar UV space shared with the paint texture)
# =============================================================================================================================
def shell(name, stations, material, thickness=0.0, open_bottom=False, n=18, parent=None):
    """Loft a rounded-section shell along f. stations: dict(f, w, top, bot, r, edge) -> a superellipse-ish ring.
       open_bottom=True builds only the top arch (a fender): its side edges end at `edge` height instead of closing under."""
    rings = []
    uvs = []
    verts = []
    for st in stations:
        f, w, top, bot = st["f"], st["w"], st["top"], st["bot"]
        r = st.get("r", 0.12)
        edge = st.get("edge", bot)
        ring = []
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
            uvs.append(paint_uv(f, u))
        rings.append(ring)
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
    # side-planar UVs, but a vertex whose normal points UP slides to the plain-red band of the paint (no flame smeared across the crown)
    me = o.data
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    plain_v = (1.60 - PAINT_U0) / (PAINT_U1 - PAINT_U0)
    for poly in me.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            co = me.vertices[vi].co
            f_, u_ = -co.y, co.z
            uu, vv = paint_uv(f_, u_)
            nz = max(0.0, me.vertices[vi].normal.z)
            wgt = min(1.0, max(0.0, (nz - 0.62) / 0.30))
            wgt = wgt * wgt * (3 - 2 * wgt)
            uvl.data[li].uv = (uu, vv * (1 - wgt) + plain_v * wgt)
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
front_fender = shell("Fender_Front", FRONT, M_PAINT, thickness=0.035, open_bottom=True, n=20)

# rear fender over the back wheels
REAR = [
    dict(f=-0.55, w=0.74, top=1.30, bot=0.95, edge=1.02),
    dict(f=-0.78, w=0.93, top=1.30, bot=0.93, edge=0.88),
    dict(f=-1.22, w=0.95, top=1.36, bot=0.92, edge=0.78),
    dict(f=-1.55, w=0.93, top=1.31, bot=0.93, edge=0.88),
    dict(f=-1.82, w=0.78, top=1.27, bot=0.96, edge=1.03),
]
rear_fender = shell("Fender_Rear", REAR, M_PAINT, thickness=0.035, open_bottom=True, n=20)

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
tub = shell("Body_Tub", TUB, M_PAINT, n=24)

# seat (leather)
SEAT = [
    dict(f=0.20, w=0.25, top=1.47, bot=1.30), dict(f=0.05, w=0.30, top=1.50, bot=1.30), dict(f=-0.55, w=0.33, top=1.505, bot=1.28),
    dict(f=-1.00, w=0.33, top=1.50, bot=1.28), dict(f=-1.28, w=0.30, top=1.46, bot=1.28),
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
    tube("Rack_Leg%d" % sx, [(0.46 * sx, -1.0, RK_U), (0.46 * sx, -1.05, 1.28)], 0.022, M_CHROME, parent=ROOT_EMPTY)
    tube("Rack_LegB%d" % sx, [(0.46 * sx, -1.85, RK_U), (0.50 * sx, -1.65, 1.30)], 0.022, M_CHROME, parent=ROOT_EMPTY)
box("TailLamp", (0.0, -1.99, 1.30), (0.28, 0.04, 0.09), M_TAIL, ROOT_EMPTY, bevel=0.015)

# handlebar: stem, bar with the bend, grips, levers, the black headlight-visor pod and the fuel cap
HB_F = 0.60
tube("Steer_Stem", [(0.0, HB_F + 0.02, 1.48), (0.0, HB_F, 1.70)], 0.040, M_CHROME, parent=ROOT_EMPTY)
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
