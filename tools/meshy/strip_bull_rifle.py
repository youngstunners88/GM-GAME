#!/usr/bin/env python3
"""Remove the rifle that is fused into the Bull Mine Gunslinger's left hand, so Inferno Bull can pick the real
Winchester 1886 off the wall (founder 2026-10-02: "rifle glued to the drink hand").

The model is ONE skinned mesh; the rifle is geometry weighted to LeftHand/LeftForeArm. We delete the triangles of
those two bones that lie farther than --radius (model units) from the arm polyline (shoulder -> elbow -> hand -> a
little past the hand), by rewriting the index buffer in place (same vertices, fewer triangles), so the skin, UVs and
clips are untouched.

  python3 tools/meshy/strip_bull_rifle.py in.glb out.glb [--radius 0.17] [--dry-run]
"""
import argparse, json, struct, sys
import numpy as np

CT = {5126: '<f4', 5123: '<u2', 5125: '<u4', 5121: 'u1'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def load(path):
    b = open(path, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', b[off:off + 4])[0]
    return j, bytearray(b[off + 8:off + 8 + bl])


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src'); ap.add_argument('dst')
    ap.add_argument('--radius', type=float, default=0.13)
    ap.add_argument('--hand-radius', dest='hand_radius', type=float, default=0.26)
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    j, bin_ = load(a.src)
    prim = j['meshes'][0]['primitives'][0]
    P = acc(j, bin_, prim['attributes']['POSITION'])
    J = acc(j, bin_, prim['attributes']['JOINTS_0'])
    W = acc(j, bin_, prim['attributes']['WEIGHTS_0'])
    I = acc(j, bin_, prim['indices']).reshape(-1, 3).astype(np.int64)
    sk = j['skins'][0]
    names = [j['nodes'][i]['name'] for i in sk['joints']]
    ibm = acc(j, bin_, sk['inverseBindMatrices']).reshape(-1, 4, 4)

    def origin(n):
        return np.linalg.inv(ibm[names.index(n)].T)[:3, 3]
    sh, el, ha = origin('LeftArm'), origin('LeftForeArm'), origin('LeftHand')
    tip = ha + (ha - el) / np.linalg.norm(ha - el) * 0.30
    # The glove/hand is chunkier than the forearm, so it keeps a wider radius than the arm.
    d = np.minimum.reduce([seg_dist(P, sh, el) / a.radius, seg_dist(P, el, ha) / a.radius,
                           seg_dist(P, ha, tip) / a.hand_radius])
    a_radius = 1.0
    dom = J[np.arange(len(J)), W.argmax(axis=1)]
    left = np.isin(dom, [names.index('LeftHand'), names.index('LeftForeArm')])
    far = left & (d > a_radius)
    tri_far = far[I].any(axis=1)
    keep = ~tri_far
    print(f'triangles {len(I)} -> {int(keep.sum())}  (removed {int(tri_far.sum())}); far verts {int(far.sum())}')
    if a.dry_run:
        return 0
    new_idx = I[keep].astype(np.uint32).ravel()
    # append a new bufferView + accessor for the trimmed indices
    while len(bin_) % 4:
        bin_.append(0)
    start = len(bin_)
    bin_.extend(new_idx.tobytes())
    j['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': new_idx.nbytes, 'target': 34963})
    j['accessors'].append({'bufferView': len(j['bufferViews']) - 1, 'componentType': 5125, 'count': int(len(new_idx)),
                           'type': 'SCALAR', 'max': [int(new_idx.max())], 'min': [int(new_idx.min())]})
    prim['indices'] = len(j['accessors']) - 1
    j['buffers'][0]['byteLength'] = len(bin_)
    jb = json.dumps(j, separators=(',', ':')).encode()
    jb += b' ' * ((4 - len(jb) % 4) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(jb) + 8 + len(bin_))
    out += struct.pack('<I4s', len(jb), b'JSON') + jb + struct.pack('<I4s', len(bin_), b'BIN\0') + bytes(bin_)
    open(a.dst, 'wb').write(out)
    print('wrote', a.dst, len(out), 'B')
    return 0


if __name__ == '__main__':
    sys.exit(main())
