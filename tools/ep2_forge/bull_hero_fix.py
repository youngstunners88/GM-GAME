#!/usr/bin/env python3
"""Make the game Inferno Bull (inferno_bull_rigged.glb) read like the founder's character sheet - in place, on the GLB.

The skeleton, node names, rest transforms and the clip GLBs (walk / run / sit) stay byte-identical in meaning, so every
behaviour keeps working. What changes (measured 2026-10-11, skill ep2-bull-repose-hero "Game GLB" section):
  1. Idle_02 is rebuilt from the BIND pose. The Tripo body was sculpted upright and proud (head up, right arm relaxed at
     the pouch, left hand closed for a rifle) - exactly the sheet. The Meshy Idle_02 clip (made for the old Meshy body)
     bowed the head under the brim and lifted the right arm so its pouch/flap smeared into a "melted" sheet. The new
     Idle_02 is the bind pose + a slow breath (Spine02/neck/Head) and a tiny weight shift, same name, looping length.
  2. Skin weights are sanitised by LIMB: nearest-Meshy-vertex transfer gave chest islands RightUpLeg weight and pouch
     islands arm weight (so a step dragged the shoulder and an arm swing smeared the belt). Each vertex is labelled by the
     nearest bone segment (small islands take their majority label) and may only keep weights of bones in that limb
     (+ the joint it hangs from); the rest is renormalised.
  3. The stub of the deleted fused rifle left in the LEFT fist is removed (islands listed by --report) so the separate
     rifle prop (Ep2BullHeroRifle) sits in a clean fist.
  4. --tiny-tex (NOT used for the shipped GLB): would drop the embedded base colour. Do not: cliff_jump_cinematic.gd
     loads this GLB WITHOUT the bull_albedo.jpg override, so it needs the embedded atlas.
  Also: islands wholly inside --drop-box boxes are deleted (the rifle stub), triangles bridging a hand and the body are
  cut (--cut-hands), the backpack rides Spine02 rigidly, and weights are smoothed --smooth passes over the welded surface.

  Shipped 2026-10-11 (inferno_bull_rigged.glb, source kept at .farm/retired/inferno_bull_rigged_pre_hero_2026-10-11.glb):
    python3 tools/ep2_forge/bull_hero_fix.py .farm/retired/inferno_bull_rigged_pre_hero_2026-10-11.glb \
      src/episode2/assets/inferno_bull_rigged.glb --drop-box 0.42,0.70,0.80,1.30,0.06,0.42 \
      --drop-box 0.40,0.75,1.43,1.70,0.05,0.40 --drop-box 0.60,0.75,1.20,1.70,0.0,0.40
  python3 tools/ep2_forge/bull_hero_fix.py <in.glb> <out.glb> [--report] [--drop-islands 12,40] [--tiny-tex]
"""
import argparse, io, json, struct, sys, os
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

sys.path.insert(0, os.path.dirname(__file__))
from retarget_bull import load, acc  # noqa: E402

LIMBS = {
    "core": ["Hips", "Spine", "Spine01", "Spine02", "neck", "Head", "head_end", "headfront"],
    "larm": ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand"],
    "rarm": ["RightShoulder", "RightArm", "RightForeArm", "RightHand"],
    "lleg": ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase"],
    "rleg": ["RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"],
    "pack": ["Spine02"],          # the backpack rides the upper spine rigidly (never the head or the arms)
}
# bones a limb may borrow at its root (shoulder / hip blend)
BORROW = {"core": ["LeftShoulder", "RightShoulder", "LeftUpLeg", "RightUpLeg"],
          "larm": ["Spine02", "neck"], "rarm": ["Spine02", "neck"], "lleg": ["Hips"], "rleg": ["Hips"], "pack": ["Spine01"]}


def quat_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def node_local(n):
    m = np.eye(4)
    s = np.array(n.get("scale", [1, 1, 1]))
    m[:3, :3] = quat_mat(n.get("rotation", [0, 0, 0, 1])) * s
    m[:3, 3] = n.get("translation", [0, 0, 0])
    return m


def world_mats(j):
    parent = {}
    for i, n in enumerate(j["nodes"]):
        for c in n.get("children", []):
            parent[c] = i
    out = {}

    def w(i):
        if i in out:
            return out[i]
        m = node_local(j["nodes"][i])
        if i in parent:
            m = w(parent[i]) @ m
        out[i] = m
        return m
    for i in range(len(j["nodes"])):
        w(i)
    return out, parent


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-9), 0.0, 1.0)
    return np.linalg.norm(p - (a + np.outer(t, ab)), axis=1)


class Writer:
    """Append-only buffer writer that keeps every existing bufferView offset valid."""
    def __init__(self, j, bin_):
        self.j = j
        self.data = bytearray(bin_)

    def add(self, arr, comp, typ, target=None, minmax=False):
        while len(self.data) % 4:
            self.data.append(0)
        raw = np.ascontiguousarray(arr).tobytes()
        bv = {"buffer": 0, "byteOffset": len(self.data), "byteLength": len(raw)}
        if target:
            bv["target"] = target
        self.data += raw
        self.j["bufferViews"].append(bv)
        a = {"bufferView": len(self.j["bufferViews"]) - 1, "componentType": comp,
             "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = [float(x) for x in arr.min(0)]
            a["max"] = [float(x) for x in arr.max(0)]
        self.j["accessors"].append(a)
        return len(self.j["accessors"]) - 1


def compact(j, data):
    """Rewrite the binary so only referenced bufferViews survive (drops replaced accessors' bytes)."""
    used = set()
    for a in j["accessors"]:
        if "bufferView" in a:
            used.add(a["bufferView"])
    for im in j.get("images", []):
        if "bufferView" in im:
            used.add(im["bufferView"])
    remap, out, views = {}, bytearray(), []
    for i, bv in enumerate(j["bufferViews"]):
        if i not in used:
            continue
        while len(out) % 4:
            out.append(0)
        o = bv.get("byteOffset", 0)
        nb = dict(bv)
        nb["byteOffset"] = len(out)
        out += data[o:o + bv["byteLength"]]
        remap[i] = len(views)
        views.append(nb)
    for a in j["accessors"]:
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = remap[im["bufferView"]]
    j["bufferViews"] = views
    while len(out) % 4:
        out.append(0)
    j["buffers"] = [{"byteLength": len(out)}]
    return out


def save(path, j, data):
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(data)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(data), 0x004E4942)); f.write(bytes(data))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("out", nargs="?")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--drop-islands", default="")
    ap.add_argument("--drop-near-lhand", type=float, default=0.0,
                    help="also drop islands whose vertices all lie within this radius of the LeftHand palm and below the wrist")
    ap.add_argument("--drop-box", action="append", default=[],
                    help="x0,x1,y0,y1,z0,z1 (glTF metres): drop every island lying wholly inside the box")
    ap.add_argument("--tiny-tex", action="store_true")
    ap.add_argument("--no-idle", action="store_true")
    ap.add_argument("--no-weights", action="store_true")
    ap.add_argument("--cut-hands", type=float, default=0.22, help="radius around each hand for bridge cutting (0 = off)")
    ap.add_argument("--smooth", type=int, default=6, help="weight smoothing passes over the welded surface")
    ap.add_argument("--breath", type=float, default=1.0)
    a = ap.parse_args()

    j, b = load(a.src)
    W, parent = world_mats(j)
    names = {n.get("name"): i for i, n in enumerate(j["nodes"])}
    skin = j["skins"][0]
    joints = skin["joints"]
    jname = [j["nodes"][n]["name"] for n in joints]
    jpos = {jname[k]: W[joints[k]][:3, 3] for k in range(len(joints))}   # metres (Armature scale 0.01 applied)

    prim = j["meshes"][0]["primitives"][0]
    P = acc(j, b, prim["attributes"]["POSITION"]).astype(np.float64)
    UV = acc(j, b, prim["attributes"]["TEXCOORD_0"])
    J = acc(j, b, prim["attributes"]["JOINTS_0"]).astype(np.int64)
    Wt = acc(j, b, prim["attributes"]["WEIGHTS_0"]).astype(np.float64)
    I = acc(j, b, prim["indices"]).reshape(-1, 3).astype(np.int64)
    nv = len(P)
    # islands
    e = np.concatenate([I[:, [0, 1]], I[:, [1, 2]]])
    # UV seams split one surface into several vertex islands; weld by position so a seam never tears
    _, weld = np.unique(np.round(P, 5), axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    first = np.full(weld.max() + 1, -1)
    for v in range(nv):
        if first[weld[v]] < 0:
            first[weld[v]] = v
    ew = np.concatenate([e, np.stack([np.arange(nv), first[weld]], 1)])
    g = coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(nv, nv))     # UV islands (drop boxes work on these)
    ncomp, lab = connected_components(g, directed=False)
    sizes = np.bincount(lab, minlength=ncomp)
    order = np.argsort(-sizes)

    # texture for island colour (report only)
    tex = None
    try:
        from PIL import Image
        im = j["images"][0]
        bv = j["bufferViews"][im["bufferView"]]
        tex = np.asarray(Image.open(io.BytesIO(b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])).convert("RGB"))
    except Exception:
        pass

    def colour(ids):
        if tex is None:
            return (0, 0, 0)
        h, w = tex.shape[:2]
        uv = UV[ids]
        px = np.clip((uv[:, 0] % 1) * (w - 1), 0, w - 1).astype(int)
        py = np.clip((uv[:, 1] % 1) * (h - 1), 0, h - 1).astype(int)
        return tuple(int(c) for c in tex[py, px].mean(0))

    lh = jpos["LeftHand"]
    if a.report:
        print("verts", nv, "tris", len(I), "islands", ncomp)
        for k in ("LeftHand", "LeftForeArm", "RightHand", "Head", "head_end", "Hips"):
            print("JOINT", k, np.round(jpos[k], 3))
        print("-- islands with any vertex within 0.35 m of LeftHand (glTF y-up, metres)")
        for c in order:
            ids = np.where(lab == c)[0]
            d = np.linalg.norm(P[ids] - lh, axis=1)
            if d.min() < 0.35:
                lo, hi = P[ids].min(0), P[ids].max(0)
                print("ISL %5d n=%5d dmin=%.2f dmax=%.2f lo=%s hi=%s rgb=%s" % (c, len(ids), d.min(), d.max(),
                      np.round(lo, 2), np.round(hi, 2), colour(ids)))

    drop = set(int(x) for x in a.drop_islands.split(",") if x.strip())
    if a.drop_near_lhand > 0:
        for c in order:
            ids = np.where(lab == c)[0]
            if np.linalg.norm(P[ids] - lh, axis=1).max() < a.drop_near_lhand:
                drop.add(int(c))
    for bx in a.drop_box:
        x0, x1, y0, y1, z0, z1 = (float(t) for t in bx.split(","))
        inside = (P[:, 0] >= x0) & (P[:, 0] <= x1) & (P[:, 1] >= y0) & (P[:, 1] <= y1) & (P[:, 2] >= z0) & (P[:, 2] <= z1)
        out_cnt = np.bincount(lab[~inside], minlength=ncomp)
        in_cnt = np.bincount(lab[inside], minlength=ncomp)
        drop.update(int(c) for c in np.where((in_cnt > 0) & (out_cnt == 0))[0])
    if not a.out:
        return

    # --- 2. limb-sanitised weights -------------------------------------------------------------------------------------
    if not a.no_weights:
        segs = []   # (limb, bone index, a, b)
        for k, nm in enumerate(jname):
            n = joints[k]
            kids = [c for c in j["nodes"][n].get("children", []) if c in joints]
            tip = W[kids[0]][:3, 3] if kids else jpos[nm]
            limb = next(L for L, bs in LIMBS.items() if nm in bs and L != "pack")
            if nm in ("head_end", "headfront"):
                continue
            segs.append((limb, k, jpos[nm], tip))
        D = np.stack([seg_dist(P, s[2], s[3]) for s in segs], 1)
        near = np.array([s[0] for s in segs])[np.argmin(D, 1)]
        # The backpack (bedroll, lantern, straps) sits BEHIND the shoulders, so nearest-segment calls it "arm" and the
        # Talk / walk arm swing tore it into shards. Everything clearly behind the torso and between the shoulders is core.
        back = (P[:, 2] < jpos["Spine02"][2] - 0.16) & (np.abs(P[:, 0]) < 0.52) & (P[:, 1] > 1.15)
        near = near.astype("<U4")
        near[back] = "pack"
        # Belt pouches / holster straps hang beside the hands: below the belt line and inside the hip width they are never
        # arm (the old weights stretched them into the "melted" flap when the arm moved).
        belt = (P[:, 1] < 1.30) & (np.abs(P[:, 0]) < 0.44) & np.isin(near, ["larm", "rarm"])
        hipD = np.stack([D[:, [i for i, sg in enumerate(segs) if sg[0] == L]].min(1) for L in ("core", "lleg", "rleg")], 1)
        near[belt] = np.array(["core", "lleg", "rleg"])[np.argmin(hipD[belt], 1)]
        limb_of = near.copy()
        # Per-vertex labels (position based, so the two copies of a UV-seam vertex always agree). A per-UV-island
        # majority vote was tried and tore the seams open when a limb moved.
        allowed = {L: set(jname.index(x) for x in LIMBS[L] + BORROW[L] if x in jname) for L in LIMBS}
        before_bad = 0
        nearest_bone = np.array([s[1] for s in segs])[np.argmin(D, 1)]
        for L in LIMBS:
            m = limb_of == L
            ok = np.isin(J[m], list(allowed[L]))
            w = Wt[m] * ok
            before_bad += int(((Wt[m] * ~ok).sum(1) > 0.05).sum())
            s = w.sum(1)
            zero = s < 1e-4
            w[~zero] /= s[~zero, None]
            jj = J[m]
            # nothing left: bind rigidly to the nearest bone of its own limb
            jj[zero] = 0
            if L == "pack":
                jj[zero, 0] = jname.index("Spine02")
            else:
                own = [i for i, sg in enumerate(segs) if sg[0] == L]
                jj[zero, 0] = np.array([segs[i][1] for i in own])[np.argmin(D[m][zero][:, own], 1)]
            w[zero] = 0
            w[zero, 0] = 1.0
            J[m] = jj
            Wt[m] = w
        print("weights: %d vertices had >5%% weight from another limb (now 0)" % before_bad)
        for L in LIMBS:
            print("  limb %-4s %6d verts" % (L, int((limb_of == L).sum())))
        # Smooth the limb-clean weights over the WELDED surface so limb borders blend instead of tearing / stretching.
        nb = len(jname)
        dense = np.zeros((nv, nb))
        np.add.at(dense, (np.repeat(np.arange(nv), 4), J.reshape(-1)), Wt.reshape(-1))
        A = coo_matrix((np.ones(2 * len(ew)), (np.concatenate([ew[:, 0], ew[:, 1]]), np.concatenate([ew[:, 1], ew[:, 0]]))),
                       shape=(nv, nv)).tocsr()
        A.data[:] = 1.0
        deg = np.asarray(A.sum(1)).reshape(-1, 1)
        hard = dense.copy()
        for _ in range(a.smooth):
            dense = 0.5 * dense + 0.5 * (A @ dense) / np.maximum(deg, 1)
        pk = limb_of == "pack"           # the backpack stays rigid on the upper spine (smoothing bent it on the sit clip)
        dense[pk] = hard[pk]
        top = np.argsort(-dense, 1)[:, :4]
        Wt = np.take_along_axis(dense, top, 1)
        Wt[Wt < 0.02] = 0.0
        Wt /= np.maximum(Wt.sum(1, keepdims=True), 1e-9)
        J = top
        jc = j["accessors"][prim["attributes"]["JOINTS_0"]]["componentType"]
        jt = {5121: np.uint8, 5123: np.uint16}[jc]
    wr = Writer(j, b)
    if not a.no_weights:
        prim["attributes"]["JOINTS_0"] = wr.add(J.astype(jt), jc, "VEC4", 34962)
        prim["attributes"]["WEIGHTS_0"] = wr.add(Wt.astype(np.float32), 5126, "VEC4", 34962)

    # --- 2b. cut the fused hand: Tripo sculpted the right fist INTO the flask pouch (one surface). Triangles near a hand
    # whose corners belong to the arm AND to the body stretch into a sheet when the arm moves; delete those bridges.
    if not a.no_weights and a.cut_hands > 0:
        lab3 = limb_of[I]
        arm3 = np.isin(lab3, ["larm", "rarm"])
        mixed = arm3.any(1) & ~arm3.all(1)
        near_hand = np.zeros(len(I), bool)
        for hn in ("RightHand", "LeftHand"):
            near_hand |= np.linalg.norm(P[I].mean(1) - jpos[hn], axis=1) < a.cut_hands
        bridge = mixed & near_hand & (P[I].mean(1)[:, 1] < jpos["RightForeArm"][1])
        I = I[~bridge]
        print("cut %d hand-to-body bridge triangles" % int(bridge.sum()))
        drop_tri = True
    else:
        drop_tri = False

    # --- 3. drop rifle-stub islands ------------------------------------------------------------------------------------
    if drop or drop_tri:
        keep = ~np.isin(lab[I[:, 0]], list(drop))
        I2 = I[keep]
        print("dropped islands", sorted(drop), "tris", len(I) - len(I2))
        ic = j["accessors"][prim["indices"]]["componentType"]
        prim["indices"] = wr.add(I2.reshape(-1).astype(np.uint32 if ic == 5125 else np.uint16), ic, "SCALAR", 34963)

    # --- 1. Idle_02 from the bind pose ---------------------------------------------------------------------------------
    if not a.no_idle:
        anim = next(x for x in j["animations"] if x["name"] == "Idle_02")
        T = 2.3333333
        n = 71
        t = np.linspace(0, T, n).astype(np.float32)
        ph = 2 * np.pi * t / T          # one breath per loop (~26 / min: big chest, calm)
        tin = wr.add(t.reshape(-1, 1), 5126, "SCALAR", None, minmax=True)
        amp = {"Spine02": (0.018, 0.0), "Spine01": (0.008, 0.0), "neck": (-0.012, 0.004), "Head": (-0.010, 0.006),
               "LeftShoulder": (0.0, 0.010), "RightShoulder": (0.0, -0.010), "Hips": (0.0, 0.006)}
        samplers, channels = [], []
        for nm in jname:
            node = names[nm]
            nd = j["nodes"][node]
            q0 = np.array(nd.get("rotation", [0, 0, 0, 1]), dtype=np.float64)
            ax, sway = amp.get(nm, (0.0, 0.0))
            ax *= a.breath
            sway *= a.breath
            qs = []
            for p in ph:
                # small local X (pitch) breath + Z sway, applied after the rest rotation
                rx, rz = ax * np.sin(p), sway * np.sin(p * 0.5)
                dq = np.array([np.sin(rx / 2), 0, 0, np.cos(rx / 2)])
                dz = np.array([0, 0, np.sin(rz / 2), np.cos(rz / 2)])
                q = qmul(qmul(q0, dq), dz)
                qs.append(q / np.linalg.norm(q))
            qs = np.array(qs, dtype=np.float32)
            out = wr.add(qs, 5126, "VEC4")
            samplers.append({"input": tin, "output": out, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": "rotation"}})
            if nm == "Hips":
                tr = np.array(nd.get("translation", [0, 0, 0]), dtype=np.float32)
                trs = np.tile(tr, (n, 1))
                trs[:, 1] += (0.35 * np.sin(ph) * a.breath).astype(np.float32)   # 3.5 mm rise on the breath (cm units)
                samplers.append({"input": tin, "output": wr.add(trs, 5126, "VEC3"), "interpolation": "LINEAR"})
                channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": "translation"}})
        anim["samplers"], anim["channels"] = samplers, channels
        print("Idle_02 rebuilt from the bind pose:", len(channels), "channels")

    # --- 4. tiny embedded texture --------------------------------------------------------------------------------------
    if a.tiny_tex:
        from PIL import Image
        bio = io.BytesIO()
        Image.new("RGB", (4, 4), (40, 36, 34)).save(bio, "JPEG", quality=90)
        raw = np.frombuffer(bio.getvalue(), dtype=np.uint8)
        while len(wr.data) % 4:
            wr.data.append(0)
        j["bufferViews"].append({"buffer": 0, "byteOffset": len(wr.data), "byteLength": len(raw)})
        wr.data += raw.tobytes()
        j["images"][0]["bufferView"] = len(j["bufferViews"]) - 1

    # unreferenced accessors are dropped implicitly by compact() only through bufferViews; prune the accessors too
    data = prune_and_compact(j, wr.data)
    save(a.out, j, data)
    print("wrote", a.out, os.path.getsize(a.out), "bytes")


def qmul(a, b):
    x1, y1, z1, w1 = a
    x2, y2, z2, w2 = b
    return np.array([w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
                     w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
                     w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
                     w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2])


def prune_and_compact(j, data):
    used = set()
    for m in j["meshes"]:
        for p in m["primitives"]:
            used.update(p["attributes"].values())
            if "indices" in p:
                used.add(p["indices"])
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            used.add(s["inverseBindMatrices"])
    for an in j.get("animations", []):
        for s in an["samplers"]:
            used.add(s["input"]); used.add(s["output"])
    old = j["accessors"]
    remap, new = {}, []
    for i, x in enumerate(old):
        if i in used:
            remap[i] = len(new)
            new.append(x)
    j["accessors"] = new
    for m in j["meshes"]:
        for p in m["primitives"]:
            p["attributes"] = {k: remap[v] for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = remap[p["indices"]]
    for s in j.get("skins", []):
        if "inverseBindMatrices" in s:
            s["inverseBindMatrices"] = remap[s["inverseBindMatrices"]]
    for an in j.get("animations", []):
        for s in an["samplers"]:
            s["input"] = remap[s["input"]]; s["output"] = remap[s["output"]]
    return compact(j, data)


if __name__ == "__main__":
    main()
