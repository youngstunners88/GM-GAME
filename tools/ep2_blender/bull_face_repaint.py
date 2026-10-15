"""Repaint the Hunyuan-painted Inferno Bull's FACE albedo from the founder reference. Headless, numpy only (8 GB laptop).

  blender -b --python tools/ep2_blender/bull_face_repaint.py -- [--src <painted dir>] [--dst <v2 dir>] [--ref <ref.jpg>] [--report-dir <dir>]

Method (no Blender bake; the projection is rasterised straight in UV space with numpy):
 1 import the painted OBJ (world Z-up, the head faces yaw 315 deg i.e. -45 about Z, same frame bull_hunyuan_to_rig uses)
 2 software-render an orthographic front view (z-buffer) -> per-pixel face id, so only faces that are VISIBLE from the front
   and whose normal faces the camera are touched (no backface/occluder bleed: brim, bandana, backpack stay as painted)
 3 camera-project the reference head onto those faces: a 2-landmark affine (aviator centre + aviator width, measured by
   eye on the reference and on the model view) maps model (x,z) to reference pixels; every texel of a selected face is
   rasterised in UV space (barycentric -> 3D -> view -> reference sample, bilinear)
 4 composite with an elliptical feathered weight (smoothstep) so seams fade into the surrounding fur; the weight region
   is bounded to the aviator + snout + nose-ring band (the model's own cigar/mouth are left alone: the reference head is
   3/4-turned and its cigar would double the model's)
 5 write textured_mesh.jpg (only file replaced) into --dst; metallic/roughness/obj/mtl are copied unchanged
 6 report: mean luminance of mask / non-mask region before and after, and a windowed SSIM of the front view vs the
   reference crop (unlit albedo, grayscale) before and after
Pixel values are used as loaded by bpy (identical for src and dst, so ratios are comparable).
"""
import bpy, sys, os, shutil, numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def opt(n, d): return argv[argv.index(n) + 1] if n in argv else d
D = "design/ep2/blender/character-work/"
SRC = opt("--src", D + "bull_hunyuan_painted")
DST = opt("--dst", D + "bull_hunyuan_painted_v2")
REF = opt("--ref", "artifacts/episode2-gold-mine/references/founder_2026-10-10b/inferno_bull_with_rifle.jpg")
RPT = opt("--report-dir", "docs/episode2-quality/bull-hunyuan-2026-10-15")
YAW = 315.0
# model view landmarks (units, after yaw): aviator centre + width ; reference landmarks (px, top-left origin)
M_CX, M_CZ, M_W = -0.056, 0.749, 0.208
R_CX, R_CY, R_W = 505.0, 200.0, 155.0
K = M_W / R_W                                   # model units per reference pixel
ELL = dict(cx=-0.05, cz=0.728, ax=0.15, az=0.065)   # feather ellipse in model view units

def load_obj(p):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=p, forward_axis="NEGATIVE_Z", up_axis="Y")
    o = [x for x in bpy.data.objects if x.type == "MESH"][0]; me = o.data
    V = np.empty(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", V); V = V.reshape(-1, 3).astype(np.float64)
    M = np.array(o.matrix_world); V = V @ M[:3, :3].T + M[:3, 3]
    P = len(me.polygons)
    F = np.empty(P * 3, np.int32); me.polygons.foreach_get("vertices", F); F = F.reshape(-1, 3)
    uv = np.empty(len(me.loops) * 2, np.float32); me.uv_layers[0].data.foreach_get("uv", uv)
    UV = uv.reshape(-1, 2)[:P * 3].reshape(P, 3, 2).astype(np.float64)
    return V, F, UV
def loadimg(p):
    im = bpy.data.images.load(p); w, h = im.size
    return np.array(im.pixels[:], np.float32).reshape(h, w, 4)[:, :, :3]   # row 0 = bottom
def saveimg(a, p):
    h, w = a.shape[:2]; im = bpy.data.images.new("o%d" % len(bpy.data.images), w, h)
    im.pixels.foreach_set(np.concatenate([a, np.ones((h, w, 1), np.float32)], 2).astype(np.float32).ravel())
    im.filepath_raw = p; im.file_format = "PNG" if p.endswith("png") else "JPEG"
    bpy.context.scene.render.image_settings.quality = 95; im.save()
def rotz(V, deg):
    a = np.radians(deg); c, s = np.cos(a), np.sin(a)
    return V @ np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]]).T
def raster_view(Vr, F, tex, UV, bounds, S):
    """ortho view from -Y: returns (rgb [row0=bottom], face-id map)."""
    x0, x1, z0, z1 = bounds; sx = (S[0] - 1) / (x1 - x0); sz = (S[1] - 1) / (z1 - z0)
    img = np.full((S[1], S[0], 3), 0.5, np.float32); zb = np.full((S[1], S[0]), 1e9, np.float32); fid = np.full((S[1], S[0]), -1, np.int32)
    th, tw = tex.shape[:2]; P = np.stack([(Vr[:, 0] - x0) * sx, (Vr[:, 2] - z0) * sz, Vr[:, 1]], 1)
    for f in range(len(F)):
        a, b, c = P[F[f]]
        xa, xb = int(max(np.floor(min(a[0], b[0], c[0])), 0)), int(min(np.ceil(max(a[0], b[0], c[0])), S[0] - 1))
        za, zc = int(max(np.floor(min(a[1], b[1], c[1])), 0)), int(min(np.ceil(max(a[1], b[1], c[1])), S[1] - 1))
        if xb < xa or zc < za: continue
        d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(d) < 1e-9: continue
        X, Z = np.meshgrid(np.arange(xa, xb + 1), np.arange(za, zc + 1))
        l1 = ((b[1] - c[1]) * (X - c[0]) + (c[0] - b[0]) * (Z - c[1])) / d
        l2 = ((c[1] - a[1]) * (X - c[0]) + (a[0] - c[0]) * (Z - c[1])) / d; l3 = 1 - l1 - l2
        m = (l1 >= -1e-3) & (l2 >= -1e-3) & (l3 >= -1e-3)
        dep = l1 * a[2] + l2 * b[2] + l3 * c[2]
        sub = zb[za:zc + 1, xa:xb + 1]; ok = m & (dep < sub)
        if not ok.any(): continue
        sub[ok] = dep[ok]; fid[za:zc + 1, xa:xb + 1][ok] = f
        u = l1 * UV[f, 0, 0] + l2 * UV[f, 1, 0] + l3 * UV[f, 2, 0]; v = l1 * UV[f, 0, 1] + l2 * UV[f, 1, 1] + l3 * UV[f, 2, 1]
        ti = np.clip((v * (th - 1)).astype(int), 0, th - 1); tj = np.clip((u * (tw - 1)).astype(int), 0, tw - 1)
        img[za:zc + 1, xa:xb + 1][ok] = tex[ti, tj][ok]
    return img, fid
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
def weight(x, z):
    r = np.sqrt(((x - ELL["cx"]) / ELL["ax"]) ** 2 + ((z - ELL["cz"]) / ELL["az"]) ** 2)
    return 1 - smooth(0.65, 1.0, r)
def bilinear(img, px, py):   # img row0=bottom; px, py in top-left reference pixel coords
    h, w = img.shape[:2]; y = (h - 1) - py
    x = np.clip(px, 0, w - 1.001); y = np.clip(y, 0, h - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int); fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy) + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)
def lum(a): return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
def ssim(a, b, win=8):
    a = a.astype(np.float64); b = b.astype(np.float64); h, w = a.shape; h -= h % win; w -= w % win
    A = a[:h, :w].reshape(h // win, win, w // win, win).transpose(0, 2, 1, 3).reshape(-1, win * win)
    B = b[:h, :w].reshape(h // win, win, w // win, win).transpose(0, 2, 1, 3).reshape(-1, win * win)
    ma, mb = A.mean(1), B.mean(1); va, vb = A.var(1), B.var(1); cov = ((A - ma[:, None]) * (B - mb[:, None])).mean(1)
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    return float(np.mean((2 * ma * mb + c1) * (2 * cov + c2) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))))

V, F, UV = load_obj(os.path.join(SRC, "textured_mesh.obj"))
alb = loadimg(os.path.join(SRC, "textured_mesh.jpg")); H, W = alb.shape[:2]
ref = loadimg(REF); RH = ref.shape[0]
Vr = rotz(V, YAW)
bounds = (-0.5, 0.5, 0.55, 1.0); S = (1000, 450)
view0, fid = raster_view(Vr, F, alb, UV, bounds, S)

# visible, camera-facing faces whose view-space centroid lies in the feather ellipse
e1 = Vr[F[:, 1]] - Vr[F[:, 0]]; e2 = Vr[F[:, 2]] - Vr[F[:, 0]]; nrm = np.cross(e1, e2)
nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
cen = Vr[F].mean(1)
vis = np.zeros(len(F), bool); vis[np.unique(fid[fid >= 0])] = True
facing = np.abs(nrm[:, 1]) > 0.3        # |n_y|: orientation sign varies with OBJ winding, visibility already culls the back
sel = np.where(vis & facing & (weight(cen[:, 0], cen[:, 2]) > 0.0))[0]
print("FACES_SELECTED", len(sel), "of", len(F))

out = alb.copy(); mask = np.zeros((H, W), np.float32)
for f in sel:
    uv = UV[f] * np.array([W - 1, H - 1]); xa, xb = int(np.floor(uv[:, 0].min())) - 1, int(np.ceil(uv[:, 0].max())) + 1
    ya, yb = int(np.floor(uv[:, 1].min())) - 1, int(np.ceil(uv[:, 1].max())) + 1
    xa, ya = max(xa, 0), max(ya, 0); xb, yb = min(xb, W - 1), min(yb, H - 1)
    a, b, c = uv; d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(d) < 1e-9: continue
    X, Y = np.meshgrid(np.arange(xa, xb + 1), np.arange(ya, yb + 1))
    l1 = ((b[1] - c[1]) * (X - c[0]) + (c[0] - b[0]) * (Y - c[1])) / d
    l2 = ((c[1] - a[1]) * (X - c[0]) + (a[0] - c[0]) * (Y - c[1])) / d; l3 = 1 - l1 - l2
    m = (l1 >= -0.03) & (l2 >= -0.03) & (l3 >= -0.03)      # ~1 px dilation
    if not m.any(): continue
    p3 = l1[..., None] * Vr[F[f, 0]] + l2[..., None] * Vr[F[f, 1]] + l3[..., None] * Vr[F[f, 2]]
    w = weight(p3[..., 0], p3[..., 2]) * m
    if w.max() <= 0: continue
    px = R_CX + (p3[..., 0] - M_CX) / K; py = R_CY - (p3[..., 2] - M_CZ) / K
    samp = bilinear(ref, px, py)
    sl = (slice(ya, yb + 1), slice(xa, xb + 1))
    wf = np.maximum(mask[sl], w)                            # overlap-safe: never double-blend
    out[sl] = np.where((w > mask[sl])[..., None], alb[sl] * (1 - w[..., None]) + samp * w[..., None], out[sl])
    mask[sl] = wf

core = mask > 0.5
l0, l1_ = lum(alb), lum(out)
rep = {}
rep["mask_texels"] = int(core.sum()); rep["mask_pct_of_atlas"] = float(100 * core.mean())
rep["face_mean_lum_before"] = float(l0[core].mean()); rep["face_mean_lum_after"] = float(l1_[core].mean())
rep["face_std_before"] = float(l0[core].std()); rep["face_std_after"] = float(l1_[core].std())
nm = mask == 0
rep["nonface_mean_before"] = float(l0[nm].mean()); rep["nonface_mean_after"] = float(l1_[nm].mean())
rep["nonface_change_pct"] = float(100 * (rep["nonface_mean_after"] - rep["nonface_mean_before"]) / rep["nonface_mean_before"])
rep["whole_atlas_change_pct"] = float(100 * (l1_.mean() - l0.mean()) / l0.mean())

# front-view crop vs reference crop (unlit albedo), same affine
view1, _ = raster_view(Vr, F, out, UV, bounds, S)
x0, x1, z0, z1 = bounds
Wc, Hc = 220, 120
xs = M_CX - 0.135 + np.arange(Wc) * (0.27 / Wc); zs = M_CZ + 0.07 - np.arange(Hc) * (0.14 / Hc)   # top row first
Xg, Zg = np.meshgrid(xs, zs)
refc = bilinear(ref, R_CX + (Xg - M_CX) / K, R_CY - (Zg - M_CZ) / K)
def view_crop(v):
    ix = np.clip(((Xg - x0) / (x1 - x0) * (S[0] - 1)).astype(int), 0, S[0] - 1)
    iz = np.clip(((Zg - z0) / (z1 - z0) * (S[1] - 1)).astype(int), 0, S[1] - 1)
    return v[iz, ix]
c0, c1 = view_crop(view0), view_crop(view1)
rep["crop_ssim_before"] = ssim(lum(c0), lum(refc)); rep["crop_ssim_after"] = ssim(lum(c1), lum(refc))
rep["crop_mean_lum_ref"] = float(lum(refc).mean()); rep["crop_mean_lum_before"] = float(lum(c0).mean()); rep["crop_mean_lum_after"] = float(lum(c1).mean())
rep["crop_contrast_ref"] = float(lum(refc).std()); rep["crop_contrast_before"] = float(lum(c0).std()); rep["crop_contrast_after"] = float(lum(c1).std())

os.makedirs(DST, exist_ok=True); os.makedirs(RPT, exist_ok=True)
for fn in os.listdir(SRC):
    if fn != "textured_mesh.jpg": shutil.copy2(os.path.join(SRC, fn), os.path.join(DST, fn))
saveimg(out, os.path.abspath(os.path.join(DST, "textured_mesh.jpg")))
side = np.concatenate([c0, c1, refc], 1)       # rows already top-first
saveimg(side[::-1], os.path.abspath(os.path.join(RPT, "face_repaint_before_after_ref.png")))   # before | after | reference
saveimg(np.repeat(mask[:, :, None], 3, 2), os.path.abspath(os.path.join(RPT, "face_repaint_mask.png")))
for k, v in rep.items(): print("REP", k, v)
