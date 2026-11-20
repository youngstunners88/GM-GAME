#!/usr/bin/env python3
"""MediaPipe world landmarks -> CMU-style BVH that tools/ep2_motion/retarget_bvh.py accepts (stages `solved` and `cleaned`).

    ~/tools/venv-mocap/bin/python -I scripts/solve_bvh.py band_fiddle            # work/<role>/solved.bvh  (raw, every frame)
    ~/tools/venv-mocap/bin/python -I scripts/solve_bvh.py band_fiddle --clean    # work/<role>/cleaned.bvh (smoothed, looped)

Direction-based, so the video performer's proportions never reach the game rig. Every BVH joint rests with an identity frame
(CMU convention: +X = performer's left, +Y up, +Z = performer's forward), so a joint's local rotation is parent_world^T @ world.
Axes: MediaPipe world is x = image right (performer's left), y DOWN, z AWAY from the camera (measured 2026-11-20: the nose has
z < 0). P = (x, -y, -z) is a proper rotation (no mirror). The camera pitch is removed by turning the mean leg axis (ankle-mid ->
hip-mid) onto +Y. Twist is unobservable: the upper arm/thigh twist comes from the elbow/knee bend plane when bent, else follows
the parent. Hands are not solved (retarget_bvh.py does not map hands; band_play.gd's HandAim turns them).
Prints @@{json}.
"""
import argparse
import json
import os

import numpy as np
from scipy.signal import savgol_filter
from scipy.spatial.transform import Rotation as Rot, Slerp

ROOT = os.path.expanduser("~/Documents/SmokeRealm-mocap")
NOSE, LEAR, REAR, LSH, RSH, LEL, REL, LWR, RWR = 0, 7, 8, 11, 12, 13, 14, 15, 16
LHIP, RHIP, LKN, RKN, LANK, RANK, LHEEL, RHEEL, LTOE, RTOE = 23, 24, 25, 26, 27, 28, 29, 30, 31, 32

# name, parent, offset (m). Order = BVH write order (depth-first).
SKEL = [
    ("Hips", None, (0, 0, 0)),
    ("LeftUpLeg", "Hips", (0.09, 0, 0)), ("LeftLeg", "LeftUpLeg", (0, -0.42, 0)), ("LeftFoot", "LeftLeg", (0, -0.42, 0)),
    ("LeftToeBase", "LeftFoot", (0, -0.05, 0.12)),
    ("RightUpLeg", "Hips", (-0.09, 0, 0)), ("RightLeg", "RightUpLeg", (0, -0.42, 0)), ("RightFoot", "RightLeg", (0, -0.42, 0)),
    ("RightToeBase", "RightFoot", (0, -0.05, 0.12)),
    ("LowerBack", "Hips", (0, 0.08, 0)), ("Spine", "LowerBack", (0, 0.15, 0)), ("Spine1", "Spine", (0, 0.15, 0)),
    ("Neck", "Spine1", (0, 0.12, 0)), ("Head", "Neck", (0, 0.10, 0)),
    ("LeftShoulder", "Spine1", (0.02, 0.10, 0)), ("LeftArm", "LeftShoulder", (0.15, 0, 0)),
    ("LeftForeArm", "LeftArm", (0.28, 0, 0)), ("LeftHand", "LeftForeArm", (0.25, 0, 0)),
    ("RightShoulder", "Spine1", (-0.02, 0.10, 0)), ("RightArm", "RightShoulder", (-0.15, 0, 0)),
    ("RightForeArm", "RightArm", (-0.28, 0, 0)), ("RightHand", "RightForeArm", (-0.25, 0, 0)),
]
END = {"LeftToeBase": (0, 0, 0.05), "RightToeBase": (0, 0, 0.05), "Head": (0, 0.15, 0),
       "LeftHand": (0.08, 0, 0), "RightHand": (-0.08, 0, 0)}
PARENT = {n: p for n, p, _ in SKEL}
OFF = {n: np.array(o, float) for n, _, o in SKEL}
HIP_H = 0.95


def nrm(v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-9)


def frame(x, y):
    """Rotation whose columns are (x, y', x cross y') with y' = y orthogonalised to x."""
    x = nrm(x)
    y = nrm(y - x * np.sum(x * y, -1, keepdims=True))
    return np.stack([x, y, np.cross(x, y)], -1)


def swing(a, b):
    """Shortest rotation (matrices [N,3,3]) turning unit vectors a onto b."""
    a, b = nrm(a), nrm(b)
    ax = np.cross(a, b)
    s = np.linalg.norm(ax, axis=-1)
    c = np.sum(a * b, -1)
    ang = np.arctan2(s, c)
    axis = np.where(s[:, None] > 1e-8, ax / np.maximum(s, 1e-12)[:, None], np.array([1.0, 0, 0]))
    return Rot.from_rotvec(axis * ang[:, None]).as_matrix()


def slerp_m(A, B, w):
    """Per-frame slerp between rotation stacks A, B with weight w (scalar or [N])."""
    w = np.broadcast_to(np.asarray(w, float), (len(A),))
    rel = Rot.from_matrix(np.einsum("nji,njk->nik", A, B))          # A^T B
    return np.einsum("nij,njk->nik", A, Rot.from_rotvec(rel.as_rotvec() * w[:, None]).as_matrix())


def limb(parent_w, a_obs, b_obs, a0, b0):
    """World rotation of a two-segment limb's upper bone: bend-plane frame when bent, parent-following swing when straight."""
    n0 = np.cross(a0, b0)
    M_rest = frame(a0[None], n0[None])[0]
    n = np.cross(nrm(a_obs), nrm(b_obs))
    bend = np.degrees(np.arcsin(np.clip(np.linalg.norm(n, axis=-1), 0, 1)))
    W_frame = np.einsum("nij,kj->nik", frame(a_obs, n), M_rest)
    W_swing = np.einsum("nij,njk->nik", swing(np.einsum("nij,j->ni", parent_w, a0), a_obs), parent_w)
    t = np.clip((bend - 15.0) / 20.0, 0, 1)
    return slerp_m(W_swing, W_frame, t * t * (3 - 2 * t))


def to_p(world):
    """MediaPipe world -> P (x, -y, -z), then level the mean leg axis onto +Y."""
    P = world * np.array([1.0, -1.0, -1.0])
    hip = (P[:, LHIP] + P[:, RHIP]) / 2
    ank = (P[:, LANK] + P[:, RANK]) / 2
    up = nrm((hip - ank).mean(0))
    R = swing(up[None], np.array([[0, 1.0, 0]]))[0]
    return P @ R.T, float(np.degrees(np.arccos(np.clip(up[1], -1, 1))))


def root_track(image, P):
    """Hip-mid sway (x) and bob (y) from the image, in metres via the torso length, mean removed."""
    px = image[:, :, :2] * np.array([720.0, 1280.0])
    hip_px = (px[:, LHIP] + px[:, RHIP]) / 2
    sh_px = (px[:, LSH] + px[:, RSH]) / 2
    m_per_px = np.median(np.linalg.norm(((P[:, LSH] + P[:, RSH]) - (P[:, LHIP] + P[:, RHIP])) / 2, axis=-1)
                         / np.linalg.norm(sh_px - hip_px, axis=-1))
    d = (hip_px - hip_px.mean(0)) * m_per_px
    return np.stack([d[:, 0], -d[:, 1], np.zeros(len(d))], -1)


def solve(P, neutral_legs=False):
    N = len(P)
    W = {}
    hipm = (P[:, LHIP] + P[:, RHIP]) / 2
    shm = (P[:, LSH] + P[:, RSH]) / 2
    spine = shm - hipm
    up = np.broadcast_to([0, 1.0, 0], spine.shape)
    W["Hips"] = frame(P[:, LHIP] - P[:, RHIP], nrm(up) + 0.3 * nrm(spine))
    C = frame(P[:, LSH] - P[:, RSH], spine)
    W["LowerBack"] = slerp_m(W["Hips"], C, 1 / 3)
    W["Spine"] = slerp_m(W["Hips"], C, 2 / 3)
    W["Spine1"] = C
    earm = (P[:, LEAR] + P[:, REAR]) / 2
    X = nrm(P[:, LEAR] - P[:, REAR])
    Z = nrm(P[:, NOSE] - earm)
    Z = nrm(Z - X * np.sum(X * Z, -1, keepdims=True))
    Hd = np.stack([X, np.cross(Z, X), Z], -1)
    W["Head"] = Hd
    W["Neck"] = slerp_m(C, Hd, 0.5)
    for side, SH, EL, WR, s in (("Left", LSH, LEL, LWR, 1.0), ("Right", RSH, REL, RWR, -1.0)):
        W[side + "Shoulder"] = C
        a0, b0 = np.array([s, 0, 0]), np.array([0, 0, 1.0])
        up_w = limb(C, P[:, EL] - P[:, SH], P[:, WR] - P[:, EL], a0, b0)
        W[side + "Arm"] = up_w
        fa = np.einsum("nij,njk->nik", swing(np.einsum("nij,j->ni", up_w, a0), P[:, WR] - P[:, EL]), up_w)
        W[side + "ForeArm"] = fa
        W[side + "Hand"] = fa
    for side, HP, KN, AN, HE, TO in (("Left", LHIP, LKN, LANK, LHEEL, LTOE), ("Right", RHIP, RKN, RANK, RHEEL, RTOE)):
        a0, b0 = np.array([0, -1.0, 0]), np.array([0, 0, -1.0])
        th = limb(W["Hips"], P[:, KN] - P[:, HP], P[:, AN] - P[:, KN], a0, b0)
        W[side + "UpLeg"] = th
        sh = np.einsum("nij,njk->nik", swing(np.einsum("nij,j->ni", th, a0), P[:, AN] - P[:, KN]), th)
        W[side + "Leg"] = sh
        f0 = nrm(OFF[side + "ToeBase"])
        ft = np.einsum("nij,njk->nik", swing(np.einsum("nij,j->ni", sh, f0), P[:, TO] - P[:, HE]), sh)
        W[side + "Foot"] = ft
        W[side + "ToeBase"] = ft
        if neutral_legs:        # legs hidden (skirt) or occluded (upright bass): straight in world, feet forward; plant() keeps them still
            I = np.broadcast_to(np.eye(3), (N, 3, 3)).copy()
            for b in ("UpLeg", "Leg", "Foot", "ToeBase"):
                W[side + b] = I
    return W


def fk(W, root):
    """Joint world positions [N,3] per joint for the BVH rest skeleton (used for QC: foot slide, seam)."""
    pos = {"Hips": root + np.array([0, HIP_H, 0])}
    for n, p, _ in SKEL[1:]:
        pos[n] = pos[p] + np.einsum("nij,j->ni", W[p], OFF[n])
    return pos


def plant(W, root, P, min_frac=0.9, drop=0.0):
    # NOTE: retarget_bvh.py subtracts the clip's MEAN hip height, so a constant `drop` is erased downstream (2026-11-21) and the
    # bent knees would lift the feet; keep drop = 0 for clips going through it.
    """Lock each ankle that is planted for >= min_frac of the clip to its mean position (in BVH-skeleton space) with a 2-bone
    IK whose knee keeps the observed bend side. A standing player's feet then never slide under the hip sway."""
    pos = fk(W, root)                                   # ankle targets from the undropped stance
    low = fk(W, root - np.array([0, drop, 0]))          # hips lowered by `drop`: the knees bend to keep the feet where they were
    done = {}
    for side, KN, HP in (("Left", LKN, LHIP), ("Right", RKN, RHIP)):
        a = pos[side + "Foot"]
        planted = a[:, 1] < a[:, 1].min() + 0.03
        if planted.mean() < min_frac:
            done[side] = False
            continue
        target = a.mean(0)
        hip = low[side + "UpLeg"]
        l1 = np.linalg.norm(OFF[side + "Leg"])
        l2 = np.linalg.norm(OFF[side + "Foot"])
        v = target - hip
        dist = np.clip(np.linalg.norm(v, axis=-1), 1e-4, (l1 + l2) * 0.999)
        u = nrm(v)
        pole = pos[side + "Leg"] - hip + np.array([0, 0, 0.05])   # current knee as the bend side; forward bias for straight legs
        pole = nrm(pole - u * np.sum(pole * u, -1, keepdims=True))
        cos1 = (l1 ** 2 + dist ** 2 - l2 ** 2) / (2 * l1 * dist)
        ang = np.arccos(np.clip(cos1, -1, 1))
        knee = hip + l1 * (u * np.cos(ang)[:, None] + pole * np.sin(ang)[:, None])
        ank = hip + u * dist[:, None]
        a0, b0 = np.array([0, -1.0, 0]), np.array([0, 0, -1.0])
        th = limb(W["Hips"], knee - hip, ank - knee, a0, b0)
        sh = np.einsum("nij,njk->nik", swing(np.einsum("nij,j->ni", th, a0), ank - knee), th)
        # the foot keeps its observed world orientation (flat on the floor), not the new shin's
        W[side + "UpLeg"], W[side + "Leg"] = th, sh
        done[side] = True
    return W, done


def local_euler(W):
    out = {}
    for n, p, _ in SKEL:
        L = W[n] if p is None else np.einsum("nji,njk->nik", W[p], W[n])
        out[n] = Rot.from_matrix(L).as_euler("ZXY", degrees=True)
    return out


def face_x(W, root):
    """Turn the whole take so the performer faces BVH +X (= Blender +X after the importer's Y-up -> Z-up). retarget_bvh.py applies
    the source's world rotation CHANGE pre-multiplied by a yaw, not conjugated, so the source must already face the way the target
    rig rests: the auction band GLBs face +X (Ep2TownFolk.SIDEWAYS_EXPORTS). With yaw_deg -90 in the clip row the yaw then nets out
    to the performer's small stance turn only (measured 2026-11-20: facing -Y source onto the +X rig turned the fiddler 90 deg)."""
    Q = Rot.from_euler("y", 90, degrees=True).as_matrix()       # +Z (forward) -> +X, +X (left) -> -Z
    W = {k: np.einsum("ij,njk,lk->nil", Q, v, Q) for k, v in W.items()}
    return W, root @ Q.T, Q


def write_bvh(path, W, root, fps, Q=None):
    eul = local_euler(W)
    OFF_W = {k: (Q @ v if Q is not None else v) for k, v in OFF.items()}
    END_W = {k: tuple(Q @ np.array(v, float)) if Q is not None else v for k, v in END.items()}
    lines = ["HIERARCHY"]
    children = {}
    for n, p, _ in SKEL:
        children.setdefault(p, []).append(n)

    def emit(n, depth):
        ind = "  " * depth
        o = OFF_W[n]
        lines.append(f"{ind}{'ROOT' if PARENT[n] is None else 'JOINT'} {n}")
        lines.append(ind + "{")
        lines.append(f"{ind}  OFFSET {o[0]:.5f} {o[1]:.5f} {o[2]:.5f}")
        if PARENT[n] is None:
            lines.append(f"{ind}  CHANNELS 6 Xposition Yposition Zposition Zrotation Xrotation Yrotation")
        else:
            lines.append(f"{ind}  CHANNELS 3 Zrotation Xrotation Yrotation")
        for c in children.get(n, []):
            emit(c, depth + 1)
        if n in END_W:
            e = END_W[n]
            lines.extend([f"{ind}  End Site", ind + "  {", f"{ind}    OFFSET {e[0]:.5f} {e[1]:.5f} {e[2]:.5f}", ind + "  }"])
        lines.append(ind + "}")

    emit("Hips", 0)
    N = len(root)
    lines += ["MOTION", f"Frames: {N}", f"Frame Time: {1.0 / fps:.6f}"]
    for i in range(N):
        row = [root[i, 0], root[i, 1] + HIP_H, root[i, 2]]
        for n, _, _ in SKEL:
            row += list(eul[n][i])
        lines.append(" ".join(f"{v:.4f}" for v in row))
    open(path, "w").write("\n".join(lines) + "\n")


def pose_feat(P):
    hipm = (P[:, LHIP] + P[:, RHIP]) / 2
    J = [NOSE, LSH, RSH, LEL, REL, LWR, RWR, LKN, RKN, LANK, RANK]
    return (P[:, J] - hipm[:, None]).reshape(len(P), -1)


def find_loop(P, fps, lo_s=2.0, hi_s=4.0, k=6):
    """Best [s, s+L) window: pose AND velocity of frame s+L match frame s. Prefers longer loops slightly."""
    F = pose_feat(P)
    V = np.gradient(F, axis=0)
    best = (1e9, 0, 0)
    for L in range(int(lo_s * fps), int(hi_s * fps) + 1):
        for s in range(k, len(P) - L):
            e = s + L
            cost = np.sum((F[s] - F[e]) ** 2) + 4.0 * np.sum((V[s] - V[e]) ** 2)
            cost *= 1.0 - 0.1 * (L - lo_s * fps) / ((hi_s - lo_s) * fps)
            if cost < best[0]:
                best = (cost, s, L)
    return best


def crossfade(A, s, L, k):
    """Frames s..s+L-1; the last k ease toward the frames just before s so frame L-1 flows into frame 0."""
    out = A[s:s + L].copy()
    for j in range(k):
        i = L - k + j
        w = (j + 1) / (k + 1)
        w = w * w * (3 - 2 * w)
        out[i] = A[s + i] * (1 - w) + A[s + i - L] * w
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("role")
    ap.add_argument("--clean", action="store_true")
    ap.add_argument("--window", type=int, default=7)
    ap.add_argument("--fade", type=int, default=6)
    ap.add_argument("--neutral-legs", action="store_true", help="unreliable legs (lead skirt, bass occlusion): straight, planted")
    ap.add_argument("--torso-damp", type=float, default=1.0, help="scale torso rotation from upright (instrument fixed to the feet)")
    a = ap.parse_args()
    d = np.load(os.path.join(ROOT, "work", a.role, "landmarks.npz"))
    fps = float(d["fps"])
    P, tilt = to_p(d["world"].astype(float))
    root = root_track(d["image"].astype(float), P)
    info = {"role": a.role, "frames_in": len(P), "fps": fps, "camera_tilt_deg": round(tilt, 1)}
    if a.clean:
        P = savgol_filter(P, a.window, 2, axis=0)
        root = savgol_filter(root, a.window * 2 + 1, 2, axis=0)
        cost, s, L = find_loop(P, fps, k=a.fade)
        info.update(loop_start=s, loop_frames=L, loop_seconds=round(L / fps, 2), loop_cost=round(float(cost), 5))
        P = crossfade(P, s, L, a.fade)
        root = crossfade(root, s, L, a.fade)
        # seam check: the loop wraps from frame L-1 to frame 0
        P = np.concatenate([P, P[:1]])          # temporarily append the wrap frame for the per-frame checks
        root = np.concatenate([root, root[:1]])
    W = solve(P, a.neutral_legs)
    info["neutral_legs"] = a.neutral_legs
    if a.torso_damp < 1.0:
        # An instrument placed from the player's FEET (the upright bass on its endpin) does not follow the torso: a full-size lean
        # or turn carried the plucking hand 8 cm past its reach (2026-11-21). Scale the torso's turn from upright, keep its rhythm.
        I = np.broadcast_to(np.eye(3), W["Hips"].shape).copy()
        for b in ("Hips", "LowerBack", "Spine", "Spine1", "Neck", "Head", "LeftShoulder", "RightShoulder"):
            W[b] = slerp_m(I, W[b], a.torso_damp)
        info["torso_damp"] = a.torso_damp
    if a.clean:
        W, info["feet_planted"] = plant(W, root, P)
    pos = fk(W, root)
    # QC: elbow/knee angular speed (deg/frame) and foot slide when planted
    q = {}
    for b in ("LeftForeArm", "RightForeArm", "LeftLeg", "RightLeg", "LeftArm", "RightArm", "Spine1", "Head"):
        R = Rot.from_matrix(W[b])
        dang = np.degrees((R[1:] * R[:-1].inv()).magnitude())
        q[b] = round(float(dang.max()), 1)
    info["max_deg_per_frame"] = q
    slide = {}
    for side in ("Left", "Right"):
        p = pos[side + "Foot"]
        h = p[:, 1]
        sp = np.linalg.norm(np.diff(p[:, [0, 2]], axis=0), axis=-1)
        planted = (h[:-1] < h.min() + 0.03)
        slide[side] = {"planted_frac": round(float(planted.mean()), 2),
                       "slide_mm_per_frame_max": round(float(sp[planted].max() * 1000) if planted.any() else 0.0, 1),
                       "range_cm": round(float(np.ptp(p[:, [0, 2]], axis=0).max() * 100), 1)}
    info["foot"] = slide
    if a.clean:
        info["seam_deg"] = {b: round(float(np.degrees((Rot.from_matrix(W[b][-1:]) * Rot.from_matrix(W[b][-2:-1]).inv()).magnitude()[0])), 1)
                            for b in ("LeftArm", "RightArm", "Spine1", "Head", "LeftUpLeg")}
        # The loop is already closed. retarget_bvh.py always drops the first 2 source frames (CMU T-pose frames), so pad with the
        # loop's last 2 frames; keep the wrap frame (== frame 0) at the end so Godot's linear loop lands back on frame 0.
        # Use "loop": false in the clip row: its blend would double-close the seam.
        L = len(root) - 1
        sel = [L - 2, L - 1] + list(range(L)) + [0]
        W = {k: v[sel] for k, v in W.items()}
        root = root[sel]
        info["bvh_frames"] = len(sel)
    out = os.path.join(ROOT, "work", a.role, "cleaned.bvh" if a.clean else "solved.bvh")
    np.savez(out.replace(".bvh", "_fk.npz"), **{k: v[:len(root)] for k, v in fk(W, root).items()})   # QC view: facing +Z
    Wx, rootx, Q = face_x(W, root)
    write_bvh(out, Wx, rootx, fps, Q)
    info["out"] = out
    print("@@" + json.dumps(info))


if __name__ == "__main__":
    main()
