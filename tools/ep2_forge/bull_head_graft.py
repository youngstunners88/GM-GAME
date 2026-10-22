"""Bull v3: graft a newly generated high-detail HEAD bust onto the v2 painted BODY, skinned to the ORIGINAL game skeleton. Headless.

  blender -b --python tools/ep2_forge/bull_head_graft.py -- \
      [--body design/ep2/blender/character-work/bull_hunyuan_painted_v2_rigged_candidate.glb] \
      [--head design/ep2/blender/character-work/bull_head_hunyuan_painted/textured_mesh.obj] \
      [--out design/ep2/blender/character-work/bull_hunyuan_head_v3_rigged_candidate.glb] \
      [--scale 0.39 --tx -0.01 --ty 2.046 --tz 0.15 --yaw 0] [--head-cut-y 1.86] [--body-cut-y 1.96] [--tex 1024]

Method (numpy only, no Blender skeleton round-trip: Blender 5 re-export tore the pose, see bull_hunyuan_to_rig.py):
  1 BODY = mesh of the v2 candidate GLB (already skinned, in game space). HEAD = the bust OBJ (own UVs, Y up, faces +Z).
  2 HEAD is uniformly scaled + translated so its hat/horn silhouette matches the body's (front+side IoU grid search,
    s=0.39, see README); no yaw needed.
  3 cut: BODY faces above --body-cut-y and behind --body-back-z (i.e. old hat, horns, face) are removed; the pack, rifle
    and arms stay. HEAD faces below --head-cut-y (shoulders, straps, backpack bottle) are removed. The two cuts overlap
    so the head's neck/bandana sits inside the body's collar. Tiny floating shells are dropped.
  4 skin: head vertices 100% 'Head' joint, blending to 'neck' over --blend metres above the head cut.
  5 write ONE mesh with two primitives (body, head), two materials, grafted into the original GLB JSON (nodes, bones,
    inverse-binds and clips byte-identical). Both materials doubleSided, no emission.
"""
import sys, os, json, struct, argparse, math
import numpy as np
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
R = "design/ep2/blender/character-work/"
ap.add_argument("--body", default=R + "bull_hunyuan_painted_v2_rigged_candidate.glb")
ap.add_argument("--head", default=R + "bull_head_hunyuan_painted/textured_mesh.obj")
ap.add_argument("--out", default=R + "bull_hunyuan_head_v3_rigged_candidate.glb")
ap.add_argument("--scale", type=float, default=0.39)
ap.add_argument("--tx", type=float, default=-0.01)
ap.add_argument("--ty", type=float, default=2.046)
ap.add_argument("--tz", type=float, default=0.15)
ap.add_argument("--yaw", type=float, default=0.0)
ap.add_argument("--head-cut-y", type=float, default=1.86)
ap.add_argument("--body-cut-y", type=float, default=1.96)
ap.add_argument("--body-back-z", type=float, default=-0.12, help="body faces behind this z (pack) are never removed")
ap.add_argument("--body-side-x", type=float, default=0.45, help="body faces with x beyond this (rifle) are never removed")
ap.add_argument("--bottle-x", type=float, default=-0.62, help="bust units: drop shoulder bottle at x<this and y<0.22")
ap.add_argument("--body-cigar-z", type=float, default=0.36, help="body faces in front of this z, above y=1.8 and |x|<0.3 (the old cigar below the cut) go too")
ap.add_argument("--body-hat-y", type=float, default=2.12, help="below this y only a narrow column (|x-cx|<--body-lat-x) of the body is removed: the shoulder/neck fur beside the head stays")
ap.add_argument("--body-lat-x", type=float, default=0.20)
ap.add_argument("--no-weld", action="store_true", help="skip welding skin weights across UV-seam duplicates")
ap.add_argument("--no-backfix", action="store_true", help="skip the back-visible-only face flip")
ap.add_argument("--blend", type=float, default=0.05)
ap.add_argument("--tex", type=int, default=1024)
ap.add_argument("--min-faces", type=int, default=150)
a = ap.parse_args(argv)

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load(p):
    raw = open(p, "rb").read()
    jl, _ = struct.unpack_from("<II", raw, 12)
    j = json.loads(raw[20:20 + jl]); off = 20 + jl
    bl, _ = struct.unpack_from("<II", raw, off)
    return j, bytearray(raw[off + 8:off + 8 + bl])


def acc(j, b, i):
    a_ = j["accessors"][i]; bv = j["bufferViews"][a_["bufferView"]]; n = NC[a_["type"]]
    return np.frombuffer(b, CT[a_["componentType"]], count=a_["count"] * n,
                         offset=bv.get("byteOffset", 0) + a_.get("byteOffset", 0)).reshape(a_["count"], n).copy()


def bv_bytes(j, b, i):
    bv = j["bufferViews"][i]; o = bv.get("byteOffset", 0)
    return bytes(b[o:o + bv["byteLength"]])


def readobj(path):
    v, vt, f = [], [], []
    for l in open(path):
        if l.startswith("v "): v.append(l.split()[1:4])
        elif l.startswith("vt "): vt.append(l.split()[1:3])
        elif l.startswith("f "): f.append([[int(x) for x in t.split("/")[:2]] for t in l.split()[1:]])
    return np.array(v, np.float32), np.array(vt, np.float32), np.array(f)


def vnormals(P, I):
    fn = np.cross(P[I[:, 1]] - P[I[:, 0]], P[I[:, 2]] - P[I[:, 0]])
    n = np.zeros_like(P)
    for k in range(3):
        np.add.at(n, I[:, k], fn)
    return (n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)).astype(np.float32)


def components(P, I):
    """connected components over POSITION-welded vertices (UV seams duplicate vertices)."""
    _, wid = np.unique(np.round(P * 1e4).astype(np.int64), axis=0, return_inverse=True)
    wid = wid.reshape(-1)
    I = wid[I]
    nv = int(wid.max()) + 1
    lab = np.arange(nv)
    while True:
        m = lab[I].min(1)
        new = lab.copy()
        for k in range(3):
            np.minimum.at(new, I[:, k], m)
        new = new[new]  # pointer jump
        if (new == lab).all():
            return lab[I[:, 0]]
        lab = new


def compact(arrs, I, keep_face):
    I = I[keep_face]
    used = np.unique(I)
    remap = np.full(arrs[0].shape[0], -1, np.int64); remap[used] = np.arange(len(used))
    return [x[used] for x in arrs], remap[I].astype(np.uint32)


def drop_small(arrs, I, minf):
    fl = components(arrs[0], I)
    ids, cnt = np.unique(fl, return_counts=True)
    big = set(ids[cnt >= minf].tolist())
    keep = np.array([x in big for x in fl.tolist()]) if len(fl) < 0 else np.isin(fl, list(big))
    print("COMPONENTS", len(ids), "kept", len(big), "dropped faces", int((~keep).sum()))
    return compact(arrs, I, keep)


def weld_weights(P, J, W, ng=24):
    """UV seams duplicate vertices and the v2 weight transfer smoothed each copy separately, so seams crack when posed:
    average the (dense) weights of every group of coincident vertices, keep the 4 strongest."""
    _, gid = np.unique(np.round(P * 1e4).astype(np.int64), axis=0, return_inverse=True)
    gid = gid.reshape(-1); n = len(P)
    D = np.zeros((n, ng), np.float32)
    for k in range(4):
        np.add.at(D, (np.arange(n), J[:, k].astype(np.int64)), W[:, k])
    G = np.zeros((gid.max() + 1, ng), np.float32); np.add.at(G, gid, D)
    cnt = np.bincount(gid).astype(np.float32)
    D = G[gid] / cnt[gid][:, None]
    top = np.argsort(-D, axis=1)[:, :4]
    w4 = np.take_along_axis(D, top, 1); w4 /= np.maximum(w4.sum(1, keepdims=True), 1e-8)
    moved = int(((np.abs(G[gid] / cnt[gid][:, None] - D) >= 0).sum()) * 0)
    return top.astype(np.uint16), w4.astype(np.float32), int((cnt > 1).sum())



# ---- body -------------------------------------------------------------------------------------------------------
jo, bo = load(a.body)
pb = jo["meshes"][0]["primitives"][0]
A = pb["attributes"]
BP, BN, BUV = acc(jo, bo, A["POSITION"]), acc(jo, bo, A["NORMAL"]), acc(jo, bo, A["TEXCOORD_0"])
BJ, BW = acc(jo, bo, A["JOINTS_0"]).astype(np.uint16), acc(jo, bo, A["WEIGHTS_0"]).astype(np.float32)
BI = acc(jo, bo, pb["indices"]).astype(np.int64).reshape(-1, 3)
joints = [jo["nodes"][n]["name"] for n in jo["skins"][0]["joints"]]
J_HEAD, J_NECK = joints.index("Head"), joints.index("neck")
mat_body = jo["materials"][pb.get("material", 0)]
body_img = [bv_bytes(jo, bo, jo["images"][t["source"]]["bufferView"]) for t in jo["textures"]]
print("BODY verts", len(BP), "faces", len(BI))
cen = BP[BI].mean(1)
lat = np.where(cen[:, 1] > a.body_hat_y, a.body_side_x, a.body_lat_x)
rm = (cen[:, 1] > a.body_cut_y) & (cen[:, 2] > a.body_back_z) & (np.abs(cen[:, 0] - a.tx) < lat)
rm |= (cen[:, 2] > a.body_cigar_z) & (cen[:, 1] > 1.8) & (np.abs(cen[:, 0]) < 0.3)
print("BODY faces removed", int(rm.sum()))
(BP2, BN2, BUV2, BJ2, BW2), BI2 = compact([BP, BN, BUV, BJ, BW], BI, ~rm)
(BP2, BN2, BUV2, BJ2, BW2), BI2 = drop_small([BP2, BN2, BUV2, BJ2, BW2], BI2.astype(np.int64), a.min_faces)
if not a.no_weld:
    BJ2, BW2, ng_ = weld_weights(BP2, BJ2, BW2, len(joints))
    print("WELD weight groups with >1 vertex:", ng_)



# ---- head -------------------------------------------------------------------------------------------------------
v, vt, f = readobj(a.head)
vi = f[:, :, 0] - 1; ti = f[:, :, 1] - 1
uv = np.zeros((len(v), 2), np.float32); uv[vi.ravel()] = vt[ti.ravel()]
uv[:, 1] = 1.0 - uv[:, 1]                       # OBJ v is bottom-up, glTF top-down
HP = v * a.scale
if a.yaw:
    c, s_ = math.cos(math.radians(a.yaw)), math.sin(math.radians(a.yaw))
    HP = HP @ np.array([[c, 0, -s_], [0, 1, 0], [s_, 0, c]], np.float32).T
HP = (HP + np.array([a.tx, a.ty, a.tz], np.float32)).astype(np.float32)
HI = vi.astype(np.int64)
hc = HP[HI].mean(1)
hv = v[HI].mean(1)
hrm = (hc[:, 1] < a.head_cut_y) | ((hv[:, 0] < a.bottle_x) & (hv[:, 1] < 0.22))
print("HEAD verts", len(HP), "faces", len(HI), "removed", int(hrm.sum()))
HN = vnormals(HP, HI)
(HP2, HN2, HUV2), HI2 = compact([HP, HN, uv], HI, ~hrm)
(HP2, HN2, HUV2), HI2 = drop_small([HP2, HN2, HUV2], HI2.astype(np.int64), a.min_faces)
nv = len(HP2)
HJ = np.zeros((nv, 4), np.uint16); HW = np.zeros((nv, 4), np.float32)
t = np.clip((HP2[:, 1] - a.head_cut_y) / a.blend, 0, 1)
HJ[:, 0] = J_HEAD; HJ[:, 1] = J_NECK
HW[:, 0] = t; HW[:, 1] = 1 - t
print("HEAD final verts", nv, "faces", len(HI2), "bbox", HP2.min(0).round(3), HP2.max(0).round(3))
print("BODY final verts", len(BP2), "faces", len(BI2))



# ---- back-visible-only faces ---------------------------------------------------------------------------------------
# Cutting the bust/body through thick fur/straps leaves open shells whose INSIDE is seen from outside. A face that is seen
# from its back MORE OFTEN than from its front (26 far directions) is flipped (and its vertices duplicated with negated normals), so the exposed
# interior reads as an opaque wall even with back-face culling ON, instead of see-through.
def backfix(prims_):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    import itertools
    allP = np.vstack([p[0] for p in prims_]); off = np.cumsum([0] + [len(p[0]) for p in prims_])
    allT = np.vstack([p[5].astype(np.int64) + off[k] for k, p in enumerate(prims_)])
    bvh = BVHTree.FromPolygons([Vector(x) for x in allP.astype(np.float64)], [tuple(t) for t in allT])
    dirs = [np.array(d, float) / np.linalg.norm(d) for d in itertools.product((-1, 0, 1), repeat=3) if any(d)]
    res = []; toff = 0
    for k, (P, N, UV, J, W, I) in enumerate(prims_):
        I = I.astype(np.int64)
        c = P[I].mean(1); n = np.cross(P[I[:, 1]] - P[I[:, 0]], P[I[:, 2]] - P[I[:, 0]])
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
        win = np.nonzero((c[:, 1] > 1.78) & (c[:, 1] < 2.25) & (np.abs(c[:, 0] - a.tx) < 0.45) & (c[:, 2] > -0.3))[0]
        flip = []
        for fi in win:
            fr = bk = 0
            for d in dirs:
                h = bvh.ray_cast(Vector(c[fi] + d * 1.2), Vector(-d), 2.0)
                if h[0] is None or h[2] != fi + toff:
                    continue
                if n[fi] @ d > 0: fr += 1
                else: bk += 1
            if bk > fr: flip.append(fi)        # seen mostly from its back: make that side the front
        toff += len(I)
        flip = np.array(flip, np.int64)
        print("BACKFIX prim", k, "window faces", len(win), "flipped", len(flip))
        if len(flip):
            I2 = I.copy(); fv = np.unique(I[flip]); nm = np.full(len(P), -1, np.int64); nm[fv] = len(P) + np.arange(len(fv))
            I2[flip] = nm[I[flip]][:, [0, 2, 1]]
            P = np.vstack([P, P[fv]]); N = np.vstack([N, -N[fv]]); UV = np.vstack([UV, UV[fv]]); J = np.vstack([J, J[fv]]); W = np.vstack([W, W[fv]]); I = I2
        res.append((P, N, UV, J, W, I.astype(np.uint32)))
    return res


_pr = [(BP2, BN2, BUV2, BJ2, BW2, BI2), (HP2, HN2, HUV2, HJ, HW, HI2)]
if not a.no_backfix:
    _pr = backfix(_pr)
(BP2, BN2, BUV2, BJ2, BW2, BI2), (HP2, HN2, HUV2, HJ, HW, HI2) = _pr

# ---- head textures (resize + pack metallic-roughness) ---------------------------------------------------------
base = os.path.splitext(a.head)[0]
tmpd = os.path.dirname(os.path.abspath(a.out))


def ld(p):
    im = bpy.data.images.load(p)
    if im.size[0] != a.tex or im.size[1] != a.tex:
        im.scale(a.tex, a.tex)
    return im


alb, met, rou = ld(base + ".jpg"), ld(base + "_metallic.jpg"), ld(base + "_roughness.jpg")
w, h = alb.size
mm = np.empty(w * h * 4, np.float32); met.pixels.foreach_get(mm)
rr = np.empty(w * h * 4, np.float32); rou.pixels.foreach_get(rr)
pk = np.ones(w * h * 4, np.float32); pk[1::4] = rr[0::4]; pk[2::4] = mm[0::4]
pim = bpy.data.images.new("mr_head", w, h, alpha=False); pim.pixels.foreach_set(pk)
head_img = []
sc = bpy.context.scene.render.image_settings
sc.file_format = "JPEG"; sc.quality = 88; sc.color_mode = "RGB"
for im in (alb, pim):
    fp = os.path.join(tmpd, "_tex_head.jpg"); im.save_render(fp, scene=bpy.context.scene)
    head_img.append(open(fp, "rb").read()); os.remove(fp)
print("HEAD TEX %dx%d albedo %d KB mr %d KB" % (w, h, len(head_img[0]) // 1024, len(head_img[1]) // 1024))

# ---- write GLB ---------------------------------------------------------------------------------------------------
data = bytearray(bo)


def add(arr, comp, typ, target, minmax=False):
    while len(data) % 4:
        data.append(0)
    raw = np.ascontiguousarray(arr).tobytes()
    jo["bufferViews"].append({"buffer": 0, "byteOffset": len(data), "byteLength": len(raw), **({"target": target} if target else {})})
    data.extend(raw)
    ac = {"bufferView": len(jo["bufferViews"]) - 1, "componentType": comp, "count": int(arr.shape[0]), "type": typ}
    if minmax:
        ac["min"] = [float(x) for x in arr.min(0)]; ac["max"] = [float(x) for x in arr.max(0)]
    jo["accessors"].append(ac)
    return len(jo["accessors"]) - 1


def prim(P, N, UV, J, W, I, mat):
    return {"attributes": {"POSITION": add(P.astype(np.float32), 5126, "VEC3", 34962, True), "NORMAL": add(N.astype(np.float32), 5126, "VEC3", 34962),
                           "TEXCOORD_0": add(UV.astype(np.float32), 5126, "VEC2", 34962), "JOINTS_0": add(J.astype(np.uint16), 5123, "VEC4", 34962),
                           "WEIGHTS_0": add(W.astype(np.float32), 5126, "VEC4", 34962)},
            "indices": add(I.astype(np.uint32).reshape(-1), 5125, "SCALAR", 34963), "material": mat}


# materials / images: rebuild the lists (body keeps its two images, head adds two)
jo["images"], jo["textures"] = [], []
jo["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}]
tids = []
for raw in body_img + head_img:
    while len(data) % 4:
        data.append(0)
    jo["bufferViews"].append({"buffer": 0, "byteOffset": len(data), "byteLength": len(raw)})
    data.extend(raw)
    jo["images"].append({"bufferView": len(jo["bufferViews"]) - 1, "mimeType": "image/jpeg"})
    jo["textures"].append({"sampler": 0, "source": len(jo["images"]) - 1}); tids.append(len(jo["textures"]) - 1)


def mat(name, ta, tm):
    return {"name": name, "doubleSided": True, "pbrMetallicRoughness": {
        "baseColorTexture": {"index": ta}, "metallicRoughnessTexture": {"index": tm},
        "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 1.0, "roughnessFactor": 1.0}}


jo["materials"] = [mat("bull_body_v2", tids[0], tids[1]), mat("bull_head_v3", tids[2], tids[3])]
jo["meshes"][0]["primitives"] = [prim(BP2, BN2, BUV2, BJ2, BW2, BI2, 0), prim(HP2, HN2, HUV2, HJ, HW, HI2, 1)]

ref = set()
for m in jo["meshes"]:
    for pr in m["primitives"]:
        ref.update(pr["attributes"].values()); ref.add(pr["indices"])
for sk in jo.get("skins", []):
    if "inverseBindMatrices" in sk: ref.add(sk["inverseBindMatrices"])
for an in jo.get("animations", []):
    for sm in an["samplers"]: ref.update((sm["input"], sm["output"]))
keep = sorted(ref); amap = {o: n for n, o in enumerate(keep)}
jo["accessors"] = [jo["accessors"][i] for i in keep]
for m in jo["meshes"]:
    for pr in m["primitives"]:
        pr["attributes"] = {k: amap[x] for k, x in pr["attributes"].items()}; pr["indices"] = amap[pr["indices"]]
for sk in jo.get("skins", []):
    if "inverseBindMatrices" in sk: sk["inverseBindMatrices"] = amap[sk["inverseBindMatrices"]]
for an in jo.get("animations", []):
    for sm in an["samplers"]:
        sm["input"] = amap[sm["input"]]; sm["output"] = amap[sm["output"]]
used = {ac["bufferView"] for ac in jo["accessors"] if "bufferView" in ac} | {im["bufferView"] for im in jo["images"]}
rb, out, views = {}, bytearray(), []
for i, bv in enumerate(jo["bufferViews"]):
    if i not in used: continue
    while len(out) % 4: out.append(0)
    o = bv.get("byteOffset", 0); nb = dict(bv); nb["byteOffset"] = len(out)
    out += data[o:o + bv["byteLength"]]; rb[i] = len(views); views.append(nb)
for ac in jo["accessors"]:
    if "bufferView" in ac: ac["bufferView"] = rb[ac["bufferView"]]
for im in jo["images"]: im["bufferView"] = rb[im["bufferView"]]
jo["bufferViews"] = views; jo["buffers"] = [{"byteLength": len(out)}]
js = json.dumps(jo, separators=(",", ":")).encode()
while len(js) % 4: js += b" "
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
with open(a.out, "wb") as fh:
    fh.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out)))
    fh.write(struct.pack("<II", len(js), 0x4E4F534A)); fh.write(js)
    fh.write(struct.pack("<II", len(out), 0x004E4942)); fh.write(bytes(out))
print("EXPORTED", a.out, os.path.getsize(a.out), "bytes")
