#!/usr/bin/env python3
"""Put the founder's Tripo minotaur ("Inferno Bull", Drive 1hIk04...) on the existing Meshy Inferno Bull skeleton.

The Tripo model is an UNRIGGED static mesh (and Tripo rigging needs credits). The Meshy Bull is the same character
in the same stance, already rigged with the free walk/run clips and the extra clips the show uses. So:
  1. read the Meshy rigged GLB (skeleton, skin, animations - kept byte-for-byte in meaning),
  2. scale/align the Tripo mesh onto the Meshy bind pose (feet + height),
  3. give every Tripo vertex the blended joints/weights of its nearest Meshy vertices (k = 4),
  4. delete the rifle that is fused to his left hand (same rule as tools/meshy/strip_bull_rifle.py),
  5. write one clean GLB: new mesh + old skeleton + old clips, the 1024 px base-colour texture embedded.

  python3 tools/ep2_forge/decimate_textured.py .farm/drive/bull_raw.glb .farm/bull/bull_50k.glb --faces 50000
  python3 tools/ep2_forge/retarget_bull.py src/episode2/assets/inferno_bull_rigged.glb .farm/bull/bull_50k.glb out.glb
Clip GLBs (walking/running/sit) keep working because the node names and hierarchy are unchanged.
"""
import argparse, io, json, struct, sys
import numpy as np, trimesh
from PIL import Image
from scipy.spatial import cKDTree

CT = {5126: '<f4', 5123: '<u2', 5125: '<u4', 5121: 'u1'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def load(path):
    b = open(path, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', b[off:off + 4])[0]
    return j, bytes(b[off + 8:off + 8 + bl])


def acc(j, bin_, i):
    a = j['accessors'][i]
    bv = j['bufferViews'][a['bufferView']]
    n = NC[a['type']]
    o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    return np.frombuffer(bin_, dtype=CT[a['componentType']], count=a['count'] * n, offset=o).reshape(a['count'], n).copy()


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + np.outer(t, ab)), axis=1)


class Blob:
    def __init__(self):
        self.data = bytearray(); self.views = []; self.accs = []

    def view(self, raw, target=None):
        while len(self.data) % 4:
            self.data.append(0)
        v = {'buffer': 0, 'byteOffset': len(self.data), 'byteLength': len(raw)}
        if target:
            v['target'] = target
        self.data.extend(raw); self.views.append(v)
        return len(self.views) - 1

    def accessor(self, arr, ctype, typ, target=None, minmax=False):
        a = np.ascontiguousarray(arr)
        bv = self.view(a.tobytes(), target)
        d = {'bufferView': bv, 'componentType': ctype, 'count': int(len(a)), 'type': typ}
        if minmax:
            d['min'] = [float(x) for x in a.min(axis=0)]; d['max'] = [float(x) for x in a.max(axis=0)]
        self.accs.append(d)
        return len(self.accs) - 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('rig'); ap.add_argument('mesh'); ap.add_argument('dst')
    ap.add_argument('--k', type=int, default=4)
    ap.add_argument('--rifle-dist', dest='rifle_dist', type=float, default=0.10)
    ap.add_argument('--radius', type=float, default=0.15)
    ap.add_argument('--hand-radius', dest='hand_radius', type=float, default=0.30)
    a = ap.parse_args()
    j, rb = load(a.rig)
    prim = j['meshes'][0]['primitives'][0]
    P0 = acc(j, rb, prim['attributes']['POSITION'])
    J0 = acc(j, rb, prim['attributes']['JOINTS_0']).astype(np.int64)
    W0 = acc(j, rb, prim['attributes']['WEIGHTS_0']).astype(np.float64)
    I0 = acc(j, rb, prim['indices']).reshape(-1, 3).astype(np.int64)
    used = np.unique(I0)                                    # only vertices the old mesh really draws
    sk = j['skins'][0]
    names = [j['nodes'][i]['name'] for i in sk['joints']]
    ibm = acc(j, rb, sk['inverseBindMatrices'])

    sc = trimesh.load(a.mesh, force='scene')
    g = list(sc.geometry.values())[0]
    V = np.asarray(g.vertices, dtype=np.float64)
    F = np.asarray(g.faces, dtype=np.int64)
    UV = np.asarray(g.visual.uv, dtype=np.float64).copy()
    UV[:, 1] = 1.0 - UV[:, 1]
    tex = g.visual.material.baseColorTexture
    # --- align onto the bind pose: height, then feet centre (x,z) of both meshes
    s = (P0[used, 1].max() - P0[used, 1].min()) / (V[:, 1].max() - V[:, 1].min())
    V = (V - np.array([0.0, V[:, 1].min(), 0.0])) * s
    # the two bodies are near-identical: fit a small offset on the torso/legs core (median nearest distance)
    tree0 = cKDTree(P0[used])
    core = V[(np.abs(V[:, 0]) < 0.3) & (V[:, 1] > 0.1) & (V[:, 1] < 1.6)][::5]
    best = None
    for dz in np.arange(-0.3, 0.31, 0.02):
        for dx in np.arange(-0.15, 0.16, 0.03):
            for dy in (-0.03, 0.0, 0.03):
                dd, _ = tree0.query(core + np.array([dx, dy, dz]))
                sc_ = float(np.median(dd))
                if best is None or sc_ < best[0]:
                    best = (sc_, dx, dy, dz)
    V = V + np.array(best[1:])
    print(f'scale {s:.3f}  offset {np.round(best[1:], 3)}  core fit {best[0]*100:.1f} cm  height {V[:,1].max():.3f}')
    # --- skin transfer: blend joints of the k nearest old vertices
    tree = cKDTree(P0[used])
    d, nn = tree.query(V, k=a.k)
    wgt = 1.0 / (d + 1e-3)
    J = np.zeros((len(V), 4), dtype=np.uint16); W = np.zeros((len(V), 4), dtype=np.float32)
    for vi in range(len(V)):
        acc_w = {}
        for kk in range(a.k):
            src = used[nn[vi, kk]]
            for jj, ww in zip(J0[src], W0[src]):
                if ww > 0:
                    acc_w[int(jj)] = acc_w.get(int(jj), 0.0) + ww * wgt[vi, kk]
        top = sorted(acc_w.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in top) or 1.0
        for ti, (jj, ww) in enumerate(top):
            J[vi, ti] = jj; W[vi, ti] = ww / tot
    # --- strip the rifle fused to the left hand
    def origin(n):
        return np.linalg.inv(ibm.reshape(-1, 4, 4)[names.index(n)].T)[:3, 3]
    # The Tripo model carries a rifle in his LEFT hand (+x). The Meshy bull has none, so those vertices are far from
    # every Meshy surface point: drop vertices >10 cm from the Meshy body on the left side (the fist stays).
    d_old, _ = tree0.query(V)
    far = (d_old > a.rifle_dist) & (V[:, 0] > 0.40)
    keep = ~far[F].any(axis=1)
    print(f'triangles {len(F)} -> {int(keep.sum())} (rifle removed: {int((~keep).sum())})')
    F = F[keep]
    # --- compact vertices to the kept ones
    ids = np.unique(F); remap = -np.ones(len(V), dtype=np.int64); remap[ids] = np.arange(len(ids))
    V, UV, J, W = V[ids], UV[ids], J[ids], W[ids]; F = remap[F]
    N = np.asarray(trimesh.Trimesh(V, F, process=False).vertex_normals, dtype=np.float32)
    # --- write a clean GLB
    bl = Blob()
    a_pos = bl.accessor(V.astype(np.float32), 5126, 'VEC3', 34962, True)
    a_nrm = bl.accessor(N, 5126, 'VEC3', 34962)
    a_uv = bl.accessor(UV.astype(np.float32), 5126, 'VEC2', 34962)
    a_j = bl.accessor(J, 5123, 'VEC4', 34962)
    a_w = bl.accessor(W, 5126, 'VEC4', 34962)
    a_i = bl.accessor(F.astype(np.uint32).ravel(), 5125, 'SCALAR', 34963)
    a_ibm = bl.accessor(ibm.astype(np.float32), 5126, 'MAT4')
    amap = {}
    for an in j.get('animations', []):
        for sm in an['samplers']:
            for key in ('input', 'output'):
                old = sm[key]
                if old not in amap:
                    arr = acc(j, rb, old)
                    t = j['accessors'][old]
                    amap[old] = bl.accessor(arr.astype(CT[t['componentType']]), t['componentType'], t['type'], None, key == 'input')
                sm[key] = amap[old]
    img = tex.convert('RGB')
    buf = io.BytesIO(); img.save(buf, 'JPEG', quality=90)
    iv = bl.view(buf.getvalue())
    sk['inverseBindMatrices'] = a_ibm
    j['meshes'] = [{'name': 'InfernoBull', 'primitives': [{'attributes': {'POSITION': a_pos, 'NORMAL': a_nrm, 'TEXCOORD_0': a_uv,
                                                                          'JOINTS_0': a_j, 'WEIGHTS_0': a_w}, 'indices': a_i, 'material': 0}]}]
    j['images'] = [{'bufferView': iv, 'mimeType': 'image/jpeg'}]
    j['samplers'] = [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}]
    j['textures'] = [{'sampler': 0, 'source': 0}]
    j['materials'] = [{'name': 'bull', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0,
                                                                'roughnessFactor': 0.8}}]
    j['accessors'] = bl.accs; j['bufferViews'] = bl.views
    j['buffers'] = [{'byteLength': len(bl.data)}]
    j.pop('extensionsUsed', None)
    jb = json.dumps(j, separators=(',', ':')).encode(); jb += b' ' * ((4 - len(jb) % 4) % 4)
    data = bytes(bl.data) + b'\0' * ((4 - len(bl.data) % 4) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(jb) + 8 + len(data))
    out += struct.pack('<I4s', len(jb), b'JSON') + jb + struct.pack('<I4s', len(data), b'BIN\0') + data
    open(a.dst, 'wb').write(out)
    print('wrote', a.dst, len(out) // 1024, 'KB')
    return 0


if __name__ == '__main__':
    sys.exit(main())
