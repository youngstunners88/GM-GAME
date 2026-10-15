"""Transfer the game Inferno Bull's skeleton + skin weights onto the new Hunyuan3D-2.1 high-detail shape. Headless.

  blender -b --python tools/ep2_forge/bull_hunyuan_to_rig.py -- \
      [--shape design/ep2/blender/character-work/bull_hunyuan21_shape_2026-10-15.glb] \
      [--rig src/episode2/assets/inferno_bull_rigged.glb] \
      [--out design/ep2/blender/character-work/bull_hunyuan_rigged_candidate.glb] \
      [--faces 20000] [--smooth 4] [--rot-z -45] [--dx 0] [--dy 0] [--no-limb]

Pipeline (8 GB laptop: decimate BEFORE any per-vertex work, never open the GUI):
  1 import rig GLB (Armature + char1 + stray Icosphere) and the 677k-face shape
  2 quadric-decimate the shape to --faces
  3 align to char1: uniform scale to the same height, feet on z=0 (same floor as the rig), XY centred on char1's
    bbox centre (+ --dx/--dy), --rot-z (default -45, measured from renders; the rig faces -Y)
  4 weights: nearest point on char1's surface, barycentric blend of its 3 vertex weight sets (= Data Transfer
    "nearest face interpolated"); backpack/pouches stay rigid because char1 is already rigid there (bull_hero_fix)
  5 limb gate: each vertex is labelled by its nearest bone segment's limb and may only keep that limb's bones
    (+ root borrow), like bull_hero_fix.py; then --smooth passes over mesh edges (verts that are ~100% Spine02 are
    frozen so the pack stays rigid), limit 4 influences, normalise
  6 replace char1 with the new mesh named "char1" under the SAME Armature (same bone/node names, same actions)
  7 UVs: if the shape has none, smart_project (the GPU texture step needs them)   # TODO(texture): bake/paint here
  8 export GLB with the 4 original actions

Prints: FACES, BONES, INFLUENCE histogram, STRETCH (edges >2x in bind->Idle_02 posed frames, old vs new).
"""
import sys, math, argparse, os
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--shape", default="design/ep2/blender/character-work/bull_hunyuan21_shape_2026-10-15.glb")
ap.add_argument("--rig", default="src/episode2/assets/inferno_bull_rigged.glb")
ap.add_argument("--out", default="design/ep2/blender/character-work/bull_hunyuan_rigged_candidate.glb")
ap.add_argument("--faces", type=int, default=20000)
ap.add_argument("--smooth", type=int, default=4)
ap.add_argument("--rot-z", type=float, default=-45.0, help="degrees about Z (measured by render: the Hunyuan shape faces ~+X/-Y diagonal, the rig faces -Y)")
ap.add_argument("--dx", type=float, default=0.0)
ap.add_argument("--dy", type=float, default=0.0)
ap.add_argument("--painted", default="", help="painted UV-mapped OBJ (+ _metallic/_roughness jpgs beside it): no decimate, no unwrap, textured GLB")
ap.add_argument("--tex-size", type=int, default=2048)
ap.add_argument("--clip", default="Idle_02", help="action used for the STRETCH sample (bear: Idle)")
ap.add_argument("--mat-name", default="bull_hunyuan_painted")
ap.add_argument("--no-limb", action="store_true")
ap.add_argument("--keep-icosphere", action="store_true")
a = ap.parse_args(argv)

LIMBS = {
    "core": ["Hips", "Spine", "Spine01", "Spine02", "neck", "Head", "head_end", "headfront"],
    "larm": ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand"],
    "rarm": ["RightShoulder", "RightArm", "RightForeArm", "RightHand"],
    "lleg": ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase"],
    "rleg": ["RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"],
}
BORROW = {"core": ["LeftShoulder", "RightShoulder", "LeftUpLeg", "RightUpLeg"],
          "larm": ["Spine02", "neck"], "rarm": ["Spine02", "neck"], "lleg": ["Hips"], "rleg": ["Hips"]}
BONE_LIMB = {b: k for k, v in LIMBS.items() for b in v}

bpy.ops.wm.read_factory_settings(use_empty=True)


import json, struct


def _load(path):
    raw = open(path, "rb").read()
    jl, _ = struct.unpack_from("<II", raw, 12)
    j = json.loads(raw[20:20 + jl])
    off = 20 + jl
    bl, _ = struct.unpack_from("<II", raw, off)
    return j, bytearray(raw[off + 8:off + 8 + bl])


_CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
_NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def _acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    n = _NC[a["type"]]
    dt = np.dtype(_CT[a["componentType"]])
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", n * dt.itemsize)
    if stride == n * dt.itemsize:
        return np.frombuffer(b, dtype=dt, count=a["count"] * n, offset=o).reshape(a["count"], n).copy()
    out = np.empty((a["count"], n), dt)
    for k in range(a["count"]):
        out[k] = np.frombuffer(b, dtype=dt, count=n, offset=o + k * stride)
    return out


MAT_NAME = a.mat_name


def graft(orig_path, ex_path, out_path, tex=None):
    """Replace the mesh primitive of the original GLB by the exported one; remap JOINTS_0 by joint NODE NAME."""
    jo, bo = _load(orig_path)
    je, be = _load(ex_path)
    po = jo["meshes"][0]["primitives"][0]
    pe = je["meshes"][0]["primitives"][0]
    oname = [jo["nodes"][n]["name"] for n in jo["skins"][0]["joints"]]
    ename = [je["nodes"][n]["name"] for n in je["skins"][0]["joints"]]
    remap = np.array([oname.index(n) if n in oname else 0 for n in ename], np.uint16)
    P = _acc(je, be, pe["attributes"]["POSITION"]).astype(np.float32)
    N = _acc(je, be, pe["attributes"]["NORMAL"]).astype(np.float32) if "NORMAL" in pe["attributes"] else None
    UV = _acc(je, be, pe["attributes"]["TEXCOORD_0"]).astype(np.float32) if "TEXCOORD_0" in pe["attributes"] else None
    J = remap[_acc(je, be, pe["attributes"]["JOINTS_0"]).astype(np.int64)].astype(np.uint16)
    Wt = _acc(je, be, pe["attributes"]["WEIGHTS_0"])
    if Wt.dtype != np.float32:
        Wt = Wt.astype(np.float32) / float(np.iinfo(Wt.dtype).max)
    I = _acc(je, be, pe["indices"]).astype(np.uint32).reshape(-1)
    print("GRAFT verts", len(P), "tris", len(I) // 3, "pos bbox", P.min(0).round(3), P.max(0).round(3))
    data = bytearray(bo)

    def add(arr, comp, typ, target, minmax=False):
        while len(data) % 4:
            data.append(0)
        raw = np.ascontiguousarray(arr).tobytes()
        jo["bufferViews"].append({"buffer": 0, "byteOffset": len(data), "byteLength": len(raw), "target": target})
        data.extend(raw)
        ac = {"bufferView": len(jo["bufferViews"]) - 1, "componentType": comp, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            ac["min"] = [float(x) for x in arr.min(0)]; ac["max"] = [float(x) for x in arr.max(0)]
        jo["accessors"].append(ac)
        return len(jo["accessors"]) - 1
    at = {"POSITION": add(P, 5126, "VEC3", 34962, True), "JOINTS_0": add(J, 5123, "VEC4", 34962),
          "WEIGHTS_0": add(Wt.astype(np.float32), 5126, "VEC4", 34962)}
    if N is not None:
        at["NORMAL"] = add(N, 5126, "VEC3", 34962)
    if UV is not None:
        at["TEXCOORD_0"] = add(UV, 5126, "VEC2", 34962)
    po["attributes"] = at
    po["indices"] = add(I, 5125, "SCALAR", 34963)
    # the old atlas does not fit the new UVs: grey, or the painted albedo + packed metallic-roughness (no emission)
    mi = po.get("material", 0)
    jo["materials"][mi] = {"name": "bull_grey_untextured", "pbrMetallicRoughness": {
        "baseColorFactor": [0.55, 0.55, 0.55, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.8}}
    if tex:
        jo["images"], jo["textures"], jo["samplers"] = [], [], [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}]
        tid = []
        for raw in (tex["albedo"], tex["mr"]):
            while len(data) % 4:
                data.append(0)
            jo["bufferViews"].append({"buffer": 0, "byteOffset": len(data), "byteLength": len(raw)})
            data.extend(raw)
            jo["images"].append({"bufferView": len(jo["bufferViews"]) - 1, "mimeType": "image/jpeg"})
            jo["textures"].append({"sampler": 0, "source": len(jo["images"]) - 1})
            tid.append(len(jo["textures"]) - 1)
        jo["materials"][mi] = {"name": MAT_NAME, "doubleSided": False, "pbrMetallicRoughness": {
            "baseColorTexture": {"index": tid[0]}, "metallicRoughnessTexture": {"index": tid[1]},
            "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 1.0, "roughnessFactor": 1.0}}
    # compact: drop bufferViews no accessor/image uses any more
    used = {ac["bufferView"] for ac in jo["accessors"] if "bufferView" in ac} | \
           {im["bufferView"] for im in jo.get("images", []) if "bufferView" in im}
    # images belong to the dropped texture: remove them so the binary shrinks
    if not tex:
        jo.pop("images", None); jo.pop("textures", None); jo.pop("samplers", None)
    # drop accessors nothing references any more (the old mesh's POSITION/NORMAL/UV/JOINTS/WEIGHTS/indices)
    ref = set()
    for m in jo["meshes"]:
        for pr in m["primitives"]:
            ref.update(pr["attributes"].values())
            if "indices" in pr:
                ref.add(pr["indices"])
            for t in pr.get("targets", []):
                ref.update(t.values())
    for sk in jo.get("skins", []):
        if "inverseBindMatrices" in sk:
            ref.add(sk["inverseBindMatrices"])
    for an in jo.get("animations", []):
        for sm in an["samplers"]:
            ref.update((sm["input"], sm["output"]))
    keep = sorted(ref)
    amap = {o: n for n, o in enumerate(keep)}
    jo["accessors"] = [jo["accessors"][i] for i in keep]
    for m in jo["meshes"]:
        for pr in m["primitives"]:
            pr["attributes"] = {k: amap[v] for k, v in pr["attributes"].items()}
            if "indices" in pr:
                pr["indices"] = amap[pr["indices"]]
    for sk in jo.get("skins", []):
        if "inverseBindMatrices" in sk:
            sk["inverseBindMatrices"] = amap[sk["inverseBindMatrices"]]
    for an in jo.get("animations", []):
        for sm in an["samplers"]:
            sm["input"] = amap[sm["input"]]; sm["output"] = amap[sm["output"]]
    used = {ac["bufferView"] for ac in jo["accessors"] if "bufferView" in ac} | \
           {im["bufferView"] for im in jo.get("images", []) if "bufferView" in im}
    remap_bv, out, views = {}, bytearray(), []
    for i, bv in enumerate(jo["bufferViews"]):
        if i not in used:
            continue
        while len(out) % 4:
            out.append(0)
        o = bv.get("byteOffset", 0)
        nb = dict(bv); nb["byteOffset"] = len(out)
        out += data[o:o + bv["byteLength"]]
        remap_bv[i] = len(views); views.append(nb)
    for ac in jo["accessors"]:
        if "bufferView" in ac:
            ac["bufferView"] = remap_bv[ac["bufferView"]]
    for im in jo.get("images", []):
        im["bufferView"] = remap_bv[im["bufferView"]]
    jo["bufferViews"] = views
    jo["buffers"] = [{"byteLength": len(out)}]
    js = json.dumps(jo, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    with open(out_path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(out)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(out), 0x004E4942)); f.write(bytes(out))


def build_textures(obj_path, size):
    """albedo.jpg + packed metallic-roughness (R=1, G=roughness, B=metallic) as JPEG bytes, resized to <= size."""
    base = os.path.splitext(obj_path)[0]
    tmpd = os.path.dirname(os.path.abspath(a.out))

    def load(p):
        im = bpy.data.images.load(p)
        if max(im.size) > size:
            k = size / max(im.size)
            im.scale(max(1, int(im.size[0] * k)), max(1, int(im.size[1] * k)))
        return im
    alb = load(base + ".jpg")
    met = load(base + "_metallic.jpg")
    rou = load(base + "_roughness.jpg")
    w, h = alb.size
    if tuple(met.size) != (w, h):
        met.scale(w, h)
    if tuple(rou.size) != (w, h):
        rou.scale(w, h)
    m = np.empty(w * h * 4, np.float32); met.pixels.foreach_get(m)
    r = np.empty(w * h * 4, np.float32); rou.pixels.foreach_get(r)
    out = np.ones(w * h * 4, np.float32)
    out[1::4] = r[0::4]      # G = roughness
    out[2::4] = m[0::4]      # B = metallic
    pk = bpy.data.images.new("mr_packed", w, h, alpha=False)
    pk.pixels.foreach_set(out)
    res = {}
    for key, im in (("albedo", alb), ("mr", pk)):
        fp = os.path.join(tmpd, "_tex_%s.jpg" % key)
        im.file_format = "JPEG"
        sc = bpy.context.scene.render.image_settings
        sc.file_format = "JPEG"; sc.quality = 88; sc.color_mode = "RGB"
        im.save_render(fp, scene=bpy.context.scene)
        res[key] = open(fp, "rb").read(); os.remove(fp)
    print("TEXTURES albedo %dx%d %d KB, metallic-roughness %dx%d %d KB" % (w, h, len(res["albedo"]) // 1024, w, h, len(res["mr"]) // 1024))
    return res

# ---- 1 import ---------------------------------------------------------------------------------------------------
bpy.ops.import_scene.gltf(filepath=a.rig)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
old = bpy.data.objects["char1"]
ico = bpy.data.objects.get("Icosphere")
if ico and not a.keep_icosphere:
    bpy.data.objects.remove(ico, do_unlink=True)
before = set(bpy.data.objects)
if a.painted:
    bpy.ops.wm.obj_import(filepath=a.painted, forward_axis="NEGATIVE_Z", up_axis="Y")  # same frame as the glTF import
else:
    bpy.ops.import_scene.gltf(filepath=a.shape)
new = next(o for o in set(bpy.data.objects) - before if o.type == "MESH")
# the OBJ importer leaves a 90 deg X rotation on the object: bake it so later rot-z does not overwrite it
new.rotation_mode = "XYZ"
new.data.transform(new.matrix_world)
new.matrix_world = Matrix.Identity(4)
for o in set(bpy.data.objects) - before - {new}:
    bpy.data.objects.remove(o, do_unlink=True)
print("FACES shape_in", len(new.data.polygons))


def world_bbox(o):
    ws = np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices])
    return ws.min(0), ws.max(0)

# ---- 2 decimate -------------------------------------------------------------------------------------------------
new.name = "char1_new"
bpy.context.view_layer.objects.active = new
new.select_set(True)
if not a.painted:   # painted mesh keeps its 40k faces: decimating would break the texture/UVs
    mod = new.modifiers.new("dec", "DECIMATE")
    mod.ratio = min(1.0, a.faces / max(1, len(new.data.polygons)))
    bpy.ops.object.modifier_apply(modifier=mod.name)
print("FACES decimated(tris-ish polys)", len(new.data.polygons), "verts", len(new.data.vertices))

# ---- 3 align ----------------------------------------------------------------------------------------------------
omn, omx = world_bbox(old)
nmn, nmx = world_bbox(new)
if a.rot_z:
    new.rotation_mode = "XYZ"  # glTF import leaves QUATERNION mode, which ignores rotation_euler
    new.rotation_euler = (0, 0, math.radians(a.rot_z))
    bpy.context.view_layer.update()
    nmn, nmx = world_bbox(new)
s = (omx[2] - omn[2]) / (nmx[2] - nmn[2])
new.scale = (new.scale[0] * s,) * 3
bpy.context.view_layer.update()
nmn, nmx = world_bbox(new)
oc = (omn + omx) / 2
nc = (nmn + nmx) / 2
new.location += Vector((oc[0] - nc[0] + a.dx, oc[1] - nc[1] + a.dy, omn[2] - nmn[2]))
bpy.context.view_layer.update()
# bake the transform into the vertices (world coords), then express them in the Armature's local space
inv_arm = arm.matrix_world.inverted()
M = inv_arm @ new.matrix_world
new.data.transform(M)
new.parent = None
new.matrix_world = arm.matrix_world.copy()
new.data.update()
nmn, nmx = world_bbox(new)
print("ALIGN scale=%.4f old_bbox=%s..%s new_bbox=%s..%s" % (s, np.round(omn, 3), np.round(omx, 3), np.round(nmn, 3), np.round(nmx, 3)))

# ---- 4 weight transfer --------------------------------------------------------------------------------------------
gnames = [g.name for g in old.vertex_groups]
G = len(gnames)
ov = old.data.vertices
ow = np.zeros((len(ov), G), np.float32)
for v in ov:
    for g in v.groups:
        ow[v.index, g.group] = g.weight
dg = bpy.context.evaluated_depsgraph_get()
Wm_old = old.matrix_world
old_co_w = [Wm_old @ v.co for v in ov]
polys = old.data.polygons
tris, tri_vi = [], []
me = old.data
me.calc_loop_triangles()
for t in me.loop_triangles:
    tri_vi.append(t.vertices[:])
bm = bmesh.new(); bm.from_mesh(me); bm.transform(Wm_old); bm.faces.ensure_lookup_table()
bvh = BVHTree.FromBMesh(bm)
# map bmesh face index -> its first triangle's verts (faces are tris in the Meshy mesh; fan otherwise)
face_verts = [[v.index for v in f.verts] for f in bm.faces]

Wm_new = new.matrix_world
nv = len(new.data.vertices)
nw = np.zeros((nv, G), np.float32)
npos = np.zeros((nv, 3))
for v in new.data.vertices:
    p = Wm_new @ v.co
    npos[v.index] = p[:]
    loc, nor, fi, dist = bvh.find_nearest(p)
    if fi is None:
        continue
    vs = face_verts[fi]
    # barycentric over the triangle fan triangle nearest to loc
    best = None
    for k in range(1, len(vs) - 1):
        tri = (vs[0], vs[k], vs[k + 1])
        A, B, C = (old_co_w[i] for i in tri)
        v0, v1, v2 = B - A, C - A, loc - A
        d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
        d20, d21 = v2.dot(v0), v2.dot(v1)
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-14:
            continue
        bv = (d11 * d20 - d01 * d21) / den
        bw = (d00 * d21 - d01 * d20) / den
        bu = 1 - bv - bw
        err = -min(bu, bv, bw)
        if best is None or err < best[0]:
            best = (err, tri, (bu, bv, bw))
    if best is None:
        nw[v.index] = ow[vs[0]]
        continue
    _, tri, (bu, bv, bw) = best
    bu, bv, bw = max(bu, 0), max(bv, 0), max(bw, 0)
    sm = bu + bv + bw or 1.0
    nw[v.index] = (ow[tri[0]] * bu + ow[tri[1]] * bv + ow[tri[2]] * bw) / sm
bm.free()
print("TRANSFER done verts", nv)

# ---- 5 limb gate, smooth, limit, normalise ------------------------------------------------------------------------
if not a.no_limb:
    gi = {n: i for i, n in enumerate(gnames)}
    segs, seg_limb = [], []
    for b in arm.data.bones:
        if b.name not in gi:
            continue
        h = arm.matrix_world @ b.head_local
        kids = [c for c in b.children if c.name in gi]
        t = arm.matrix_world @ (kids[0].head_local if kids else b.tail_local)
        segs.append((np.array(h[:]), np.array(t[:]))); seg_limb.append(BONE_LIMB.get(b.name, "core"))
    best_d = np.full(nv, 1e9); lab = np.array(["core"] * nv, dtype=object)
    for (h, t), lb in zip(segs, seg_limb):
        ab = t - h
        tt = np.clip(((npos - h) @ ab) / max(ab @ ab, 1e-9), 0, 1)
        d = np.linalg.norm(npos - (h + np.outer(tt, ab)), axis=1)
        m = d < best_d
        best_d[m] = d[m]; lab[m] = lb
    for limb in LIMBS:
        allow = np.zeros(G, bool)
        for n in LIMBS[limb] + BORROW.get(limb, []):
            if n in gi:
                allow[gi[n]] = True
        sel = lab == limb
        gated = nw[sel] * allow
        ok = gated.sum(1) > 1e-4          # nothing left -> keep the raw transfer rather than orphaning the vertex
        tmp = nw[sel]
        tmp[ok] = gated[ok]
        nw[sel] = tmp

# adjacency for smoothing
bm2 = bmesh.new(); bm2.from_mesh(new.data); bm2.verts.ensure_lookup_table()
ei = np.array([[e.verts[0].index, e.verts[1].index] for e in bm2.edges])
bm2.free()
nw /= np.maximum(nw.sum(1, keepdims=True), 1e-8)
spine02 = gnames.index("Spine02") if "Spine02" in gnames else -1
frozen = (nw[:, spine02] > 0.99) if spine02 >= 0 else np.zeros(nv, bool)
deg = np.bincount(np.concatenate([ei[:, 0], ei[:, 1]]), minlength=nv).astype(np.float32) + 1
for _ in range(a.smooth):
    acc = nw.copy()
    np.add.at(acc, ei[:, 0], nw[ei[:, 1]])
    np.add.at(acc, ei[:, 1], nw[ei[:, 0]])
    sm = acc / deg[:, None]
    nw = np.where(frozen[:, None], nw, 0.5 * nw + 0.5 * sm)
# limit 4 + normalise
top = np.argsort(-nw, axis=1)[:, 4:]
np.put_along_axis(nw, top, 0.0, axis=1)
nw /= np.maximum(nw.sum(1, keepdims=True), 1e-8)
orphans = int((nw.sum(1) < 0.5).sum())
for gname in gnames:
    new.vertex_groups.new(name=gname)
for i in range(G):
    col = nw[:, i]
    idx = np.nonzero(col > 1e-3)[0]
    # vertex_groups.add per distinct weight is slow; group by rounded weight
    for w in np.unique(np.round(col[idx], 3)):
        sel = idx[np.round(col[idx], 3) == w]
        new.vertex_groups[i].add([int(x) for x in sel], float(w), "REPLACE")
infl = (nw > 1e-3).sum(1)
print("INFLUENCE hist 1..4:", [int((infl == k).sum()) for k in range(1, 5)], "orphans", orphans, "max", int(infl.max()))

# ---- 6 parent to the original armature, name like the original --------------------------------------------------
old_name = old.name
bpy.data.objects.remove(old, do_unlink=True)
new.name = old_name
new.data.name = old_name
new.parent = arm
new.matrix_parent_inverse = Matrix.Identity(4)
new.matrix_world = arm.matrix_world.copy()
am = new.modifiers.new("Armature", "ARMATURE")
am.object = arm
for p in new.data.polygons:
    p.use_smooth = True

# ---- 7 UVs --------------------------------------------------------------------------------------------------------
if not new.data.uv_layers and not a.painted:
    bpy.context.view_layer.objects.active = new
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    # TODO(texture): replace smart_project with xatlas / a seam-aware unwrap if the GPU texture bake needs bigger islands
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    print("UV smart_project applied")
mat = bpy.data.materials.new("bull_grey")  # (painted: graft() swaps in the real textured material)
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Base Color"].default_value = (0.55, 0.55, 0.55, 1)
bsdf.inputs["Roughness"].default_value = 0.8
new.data.materials.clear(); new.data.materials.append(mat)

# ---- 8 stretch + export -------------------------------------------------------------------------------------------
act = bpy.data.actions.get(a.clip)
if arm.animation_data is None:
    arm.animation_data_create()
if act:
    arm.animation_data.action = act
    try:
        arm.animation_data.action_slot = arm.animation_data.action_suitable_slots[0]
    except Exception as e:  # Blender 4.4+ slotted actions
        print("slot note", e)
mesh = new
ev = np.array([e.vertices[:] for e in mesh.data.edges])
co0 = np.array([v.co[:] for v in mesh.data.vertices])
L0 = np.linalg.norm(co0[ev[:, 0]] - co0[ev[:, 1]], axis=1)
worst = []
rng = int(act.frame_range[1]) if act else 24
for f in range(1, max(2, rng), 4):
    bpy.context.scene.frame_set(f)
    d2 = bpy.context.evaluated_depsgraph_get()
    m1 = mesh.evaluated_get(d2).to_mesh()
    co1 = np.array([v.co[:] for v in m1.vertices])
    r = np.linalg.norm(co1[ev[:, 0]] - co1[ev[:, 1]], axis=1) / np.maximum(L0, 1e-5)
    worst.append(int(((r > 2.0) & (L0 > 1e-4)).sum()))
    mesh.evaluated_get(d2).to_mesh_clear()
print("STRETCH new (clip) edges>2x per sampled frame: max=%d mean=%.1f" % (max(worst), float(np.mean(worst))))
bpy.context.scene.frame_set(1)
print("BONES", len(arm.data.bones), "ACTIONS", [x.name for x in bpy.data.actions])
os.makedirs(os.path.dirname(a.out), exist_ok=True)
tmp = a.out + ".blender_tmp.glb"
bpy.ops.export_scene.gltf(filepath=tmp, export_format="GLB", export_skins=True, export_animations=False,
                          export_apply=False, export_yup=True)
# TRAP (2026-10-15): re-exporting the Armature + Idle_02 through Blender 5 changed the pose (Spine02 collapsed 0.2 m,
# 1700 stretched edges). So Blender only exports the MESH+SKIN; we graft it into the ORIGINAL GLB JSON, which keeps
# every node, bone, inverse-bind matrix and clip byte-identical.
tex = build_textures(a.painted, a.tex_size) if a.painted else None
graft(a.rig, tmp, a.out, tex)
os.remove(tmp)
print("EXPORTED", a.out, os.path.getsize(a.out))
