#!/usr/bin/env python3
"""The founder rigged Inferno Bull in Tripo Studio (60-joint UE-style skeleton, no clips). This script builds the game
GLB WITHOUT touching any game code or clip:

  * keep the Meshy skeleton's NAMES, hierarchy and local ROTATIONS (so every clip and the hand/head holders work),
  * move its joints to the Tripo joints' world positions (so the animated skeleton matches the Tripo bind pose),
  * take the Tripo mesh, UVs and skin weights; fold fingers/twist/clavicle/root joints into the 24 Meshy joints,
  * cut the rifle fused to his left hand (vertices weighted to hand/forearm and far from the arm),
  * shift the Hips translation of every clip by the new hips offset (clips ship in tools output .glb too).

  python3 tools/ep2_forge/build_bull_from_tripo_rig.py <meshy_rig.glb> <tripo_rig.glb> <out_rigged.glb> [clip.glb ...]
Run on the ORIGINAL Meshy files (.farm/retired/inferno_bull_rigged_meshy.glb, the clip GLBs in git history if needed).
Clips passed are patched IN PLACE (Hips translation only; idempotent only on pristine inputs).
"""
import argparse, io, json, struct, sys
import numpy as np
from PIL import Image
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import retarget_bull as R
import rig_tools as T

MAP = {  # Meshy joint <- Tripo joint (positions)
    'Hips': 'pelvis', 'Spine': 'spine_01', 'Spine01': 'spine_02', 'Spine02': 'spine_03', 'neck': 'neck_01', 'Head': 'head',
    'LeftShoulder': 'clavicle_l', 'LeftArm': 'upperarm_l', 'LeftForeArm': 'lowerarm_l', 'LeftHand': 'hand_l',
    'RightShoulder': 'clavicle_r', 'RightArm': 'upperarm_r', 'RightForeArm': 'lowerarm_r', 'RightHand': 'hand_r',
    'LeftUpLeg': 'thigh_l', 'LeftLeg': 'calf_l', 'LeftFoot': 'foot_l', 'LeftToeBase': 'ball_l',
    'RightUpLeg': 'thigh_r', 'RightLeg': 'calf_r', 'RightFoot': 'foot_r', 'RightToeBase': 'ball_r',
}
FOLD = {  # Tripo joint -> Meshy joint that takes its weight
    'root': 'Hips', 'upperarm_twist_01_l': 'LeftArm', 'lowerarm_twist_01_l': 'LeftForeArm', 'upperarm_twist_01_r': 'RightArm',
    'lowerarm_twist_01_r': 'RightForeArm', 'thigh_twist_01_l': 'LeftUpLeg', 'calf_twist_01_l': 'LeftLeg',
    'thigh_twist_01_r': 'RightUpLeg', 'calf_twist_01_r': 'RightLeg',
}
for side, S in (('l', 'Left'), ('r', 'Right')):
    for f in ('index', 'middle', 'pinky', 'ring', 'thumb'):
        for k in (1, 2, 3):
            FOLD[f'{f}_0{k}_{side}'] = S + 'Hand'
for m, t in MAP.items():
    FOLD[t] = m


def patch_hips(path, delta_cm):
    j, b = R.load(path)
    b = bytearray(b)
    names = {i: n['name'] for i, n in enumerate(j['nodes'])}
    done = set()
    for an in j.get('animations', []):
        for ch in an['channels']:
            if ch['target']['path'] != 'translation' or names[ch['target']['node']] != 'Hips':
                continue
            out = an['samplers'][ch['sampler']]['output']
            if out in done:
                continue
            done.add(out)
            a = j['accessors'][out]
            bv = j['bufferViews'][a['bufferView']]
            off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
            arr = np.frombuffer(b, dtype='<f4', count=a['count'] * 3, offset=off).reshape(-1, 3).copy()
            arr += delta_cm.astype(np.float32)
            b[off:off + arr.nbytes] = arr.tobytes()
            a['min'] = [float(x) for x in arr.min(axis=0)]; a['max'] = [float(x) for x in arr.max(axis=0)]
    write_glb(path, j, bytes(b))
    print('patched Hips in', path, 'tracks', len(done))


def write_glb(path, j, data):
    jb = json.dumps(j, separators=(',', ':')).encode(); jb += b' ' * ((4 - len(jb) % 4) % 4)
    data = data + b'\0' * ((4 - len(data) % 4) % 4)
    out = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(jb) + 8 + len(data))
    out += struct.pack('<I4s', len(jb), b'JSON') + jb + struct.pack('<I4s', len(data), b'BIN\0') + data
    open(path, 'wb').write(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('meshy'); ap.add_argument('tripo'); ap.add_argument('dst'); ap.add_argument('clips', nargs='*')
    ap.add_argument('--tex', type=int, default=1024)
    ap.add_argument('--radius', type=float, default=0.15)
    ap.add_argument('--hand-radius', dest='hand_radius', type=float, default=0.30)
    a = ap.parse_args()
    jo, bo = R.load(a.meshy)
    jt, bt = R.load(a.tripo)
    skO = jo['skins'][0]; namesO = [jo['nodes'][i]['name'] for i in skO['joints']]
    skT = jt['skins'][0]; namesT = [jt['nodes'][i]['name'] for i in skT['joints']]
    nid_o = {n['name']: i for i, n in enumerate(jo['nodes'])}
    nid_t = {n['name']: i for i, n in enumerate(jt['nodes'])}
    par_o = T.parents(jo)
    Go = T.global_matrices(jo)            # includes Armature scale 0.01 -> metres
    Gt = T.global_matrices(jt)
    # --- Tripo mesh
    prim = jt['meshes'][0]['primitives'][0]
    V = R.acc(jt, bt, prim['attributes']['POSITION']).astype(np.float64)
    UV = R.acc(jt, bt, prim['attributes']['TEXCOORD_0']).astype(np.float64)
    J0 = R.acc(jt, bt, prim['attributes']['JOINTS_0']).astype(np.int64)
    W0 = R.acc(jt, bt, prim['attributes']['WEIGHTS_0']).astype(np.float64)
    F = R.acc(jt, bt, prim['indices']).reshape(-1, 3).astype(np.int64)
    s = 2.4 / (V[:, 1].max() - V[:, 1].min())
    print(f'scale {s:.4f}')
    V = V * s
    pos_t = {n: Gt[nid_t[n]][:3, 3] * s for n in namesT}
    # --- new joint world positions for the Meshy topology
    p_new = {}
    for mj, tj in MAP.items():
        p_new[mj] = pos_t[tj]
    for extra in ('head_end', 'headfront'):
        p_new[extra] = p_new['Head'] + (Go[nid_o[extra]][:3, 3] - Go[nid_o['Head']][:3, 3])
    # --- patch the Meshy skeleton: new local translations (cm) with the OLD global rotations
    for jn in namesO:
        i = nid_o[jn]
        pi = par_o[i]
        if jn == 'Hips':
            parent_pos = np.zeros(3); Rp = np.eye(3)
        else:
            parent_pos = p_new[jo['nodes'][pi]['name']]
            Rp = Go[pi][:3, :3] / 0.01 if jo['nodes'][pi]['name'] != 'Armature' else np.eye(3)
            Rp = Rp / np.linalg.norm(Rp, axis=0)          # strip scale
        t_cm = (np.linalg.inv(Rp) @ (p_new[jn] - parent_pos)) / 0.01
        jo['nodes'][i]['translation'] = [float(x) for x in t_cm]
    hips_i = nid_o['Hips']
    old_hips_t = np.array(json.loads(json.dumps(R.load(a.meshy)[0]['nodes'][hips_i]['translation'])))
    delta = np.array(jo['nodes'][hips_i]['translation']) - old_hips_t
    print('hips delta (cm)', np.round(delta, 2))
    # --- new inverse bind matrices from the new bind pose (Armature scale included, as the Meshy file does)
    Gn = T.global_matrices(jo)
    ibm = np.stack([np.linalg.inv(Gn[nid_o[n]]).T.reshape(16) for n in namesO]).astype(np.float32)   # column-major
    # --- skin weights folded onto the 24 Meshy joints
    idx_o = {n: i for i, n in enumerate(namesO)}
    J = np.zeros((len(V), 4), dtype=np.uint16); W = np.zeros((len(V), 4), dtype=np.float32)
    for vi in range(len(V)):
        acc_w = {}
        for jj, ww in zip(J0[vi], W0[vi]):
            if ww <= 0:
                continue
            tn = namesT[jj]
            mn = FOLD.get(tn)
            if mn is None:
                continue
            acc_w[idx_o[mn]] = acc_w.get(idx_o[mn], 0.0) + ww
        if not acc_w:
            acc_w = {idx_o['Hips']: 1.0}
        top = sorted(acc_w.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in top)
        for ti, (jj, ww) in enumerate(top):
            J[vi, ti] = jj; W[vi, ti] = ww / tot
    # --- strip the rifle from the left hand: weighted to hand/forearm yet far from the arm
    def origin(n):
        return p_new[n]
    sh, el, ha = origin('LeftArm'), origin('LeftForeArm'), origin('LeftHand')
    tip = ha + (ha - el) / np.linalg.norm(ha - el) * 0.30
    dist = np.minimum.reduce([R.seg_dist(V, sh, el) / a.radius, R.seg_dist(V, el, ha) / a.radius,
                              R.seg_dist(V, ha, tip) / a.hand_radius])
    dom = J[np.arange(len(J)), W.argmax(axis=1)]
    left = np.isin(dom, [idx_o['LeftHand'], idx_o['LeftForeArm']])
    far = left & (dist > 1.0)
    keep = ~far[F].any(axis=1)
    print(f'triangles {len(F)} -> {int(keep.sum())} (rifle removed {int((~keep).sum())})')
    F = F[keep]
    # the Tripo export also carries a flat cigar-smoke ribbon (near-white texels, above the head); it renders as a white
    # blade without alpha, and the game draws its own smoke particles
    tex0 = jt['images'][jt['textures'][jt['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']]
    bv0 = jt['bufferViews'][tex0['bufferView']]
    im0 = np.asarray(Image.open(io.BytesIO(bt[bv0.get('byteOffset', 0):bv0.get('byteOffset', 0) + bv0['byteLength']])).convert('RGB').resize((256, 256)), dtype=np.float32) / 255.0
    uvc = np.clip((UV * 255).astype(int), 0, 255)
    lum = im0[uvc[:, 1], uvc[:, 0]].mean(axis=1)
    bright = (lum > 0.80) & (V[:, 1] > 1.9)
    smoke = bright[F].all(axis=1)
    print('smoke ribbon faces removed:', int(smoke.sum()))
    F = F[~smoke]
    ids = np.unique(F); remap = -np.ones(len(V), dtype=np.int64); remap[ids] = np.arange(len(ids))
    V, UV, J, W = V[ids], UV[ids], J[ids], W[ids]; F = remap[F]
    import trimesh
    N = np.asarray(trimesh.Trimesh(V, F, process=False).vertex_normals, dtype=np.float32)
    # --- texture
    tex_img = [i for i in jt['images'] if i.get('mimeType') == 'image/jpeg']
    bc_tex = jt['textures'][jt['materials'][0]['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
    ib = jt['images'][bc_tex]; bv = jt['bufferViews'][ib['bufferView']]
    raw = bt[bv.get('byteOffset', 0):bv.get('byteOffset', 0) + bv['byteLength']]
    img = Image.open(io.BytesIO(raw)).convert('RGB').resize((a.tex, a.tex), Image.LANCZOS)
    # --- write
    bl = R.Blob()
    a_pos = bl.accessor(V.astype(np.float32), 5126, 'VEC3', 34962, True)
    a_nrm = bl.accessor(N, 5126, 'VEC3', 34962)
    a_uv = bl.accessor(UV.astype(np.float32), 5126, 'VEC2', 34962)
    a_j = bl.accessor(J, 5123, 'VEC4', 34962)
    a_w = bl.accessor(W, 5126, 'VEC4', 34962)
    a_i = bl.accessor(F.astype(np.uint32).ravel(), 5125, 'SCALAR', 34963)
    a_ibm = bl.accessor(ibm.reshape(-1, 16), 5126, 'MAT4')
    amap = {}
    CTm = R.CT
    for an in jo.get('animations', []):
        for sm in an['samplers']:
            for key in ('input', 'output'):
                old = sm[key]
                if old not in amap:
                    arr = R.acc(jo, bo, old)
                    t = jo['accessors'][old]
                    if key == 'output' and False:
                        pass
                    amap[old] = bl.accessor(arr.astype(CTm[t['componentType']]), t['componentType'], t['type'], None, key == 'input')
                sm[key] = amap[old]
    buf = io.BytesIO(); img.save(buf, 'JPEG', quality=90)
    iv = bl.view(buf.getvalue())
    skO['inverseBindMatrices'] = a_ibm
    jo['meshes'] = [{'name': 'InfernoBull', 'primitives': [{'attributes': {'POSITION': a_pos, 'NORMAL': a_nrm, 'TEXCOORD_0': a_uv,
                                                                           'JOINTS_0': a_j, 'WEIGHTS_0': a_w}, 'indices': a_i, 'material': 0}]}]
    jo['images'] = [{'bufferView': iv, 'mimeType': 'image/jpeg'}]
    jo['samplers'] = [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}]
    jo['textures'] = [{'sampler': 0, 'source': 0}]
    jo['materials'] = [{'name': 'bull', 'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'metallicFactor': 0.0, 'roughnessFactor': 0.8}}]
    jo['accessors'] = bl.accs; jo['bufferViews'] = bl.views
    jo['buffers'] = [{'byteLength': len(bl.data)}]
    jo.pop('extensionsUsed', None)
    write_glb(a.dst, jo, bytes(bl.data))
    # the animations in the rigged GLB also need the hips offset
    patch_hips(a.dst, delta)
    for c in a.clips:
        patch_hips(c, delta)
    print('wrote', a.dst)
    return 0


if __name__ == '__main__':
    sys.exit(main())
