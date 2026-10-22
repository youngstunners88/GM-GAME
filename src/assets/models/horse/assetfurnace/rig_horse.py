"""Rig the AssetFurnace horse mesh and render the game's sprite frames.

    blender -b --factory-startup --python rig_horse.py -- horse_finished.glb OUT_DIR

Static mesh in, three outputs in OUT_DIR:
  horse_rigged.glb      skinned GLB with clips horse_walk / horse_graze / horse_stand
  frames/horse_*.png    340x320 feet-planted sprite frames (names the game already loads)
  report.json           bone fit, planted-foot residuals, walk speed

Rig: 15 bones. Legs are 2-bone IK (upper, cannon) plus a hoof stub, so a stance hoof is
pinned to the ground exactly (constant backward speed) instead of swinging on a sine.
Skin weights are geometric (distance to each bone segment, compact support), then
smoothed over the mesh. Near/far legs are 0.1 apart, so heat-diffusion auto weights
would bleed between them.

Frame: mesh faces +X, up is +Z, ground is z=0 (Blender). glTF export turns that into
facing +X, up +Y.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
K = 2.6                      # mesh units -> rig units (ears end up ~1.95 high)
SRC_GROUND = 0.375           # the raw mesh is centred, hooves at z = -0.375
FPS = 30
WALK_FRAMES, GRAZE_FRAMES, STAND_FRAMES = 24, 36, 90
DUTY = 0.60                  # fraction of the stride a hoof is on the ground
STEP = 0.16                  # hoof travel while planted, pre-K units (stride = STEP/DUTY)
HIP_DROP = 0.025             # body sits lower than the straight-leg height while walking
PHASE = {"HL": 0.0, "FL": 0.25, "HR": 0.5, "FR": 0.75}   # lateral-sequence 4-beat
CANVAS = (340, 320)          # what stable_horses.gd expects
PPU = 345.0                  # canvas pixels per pre-K unit (horse 0.906 long + hind swing fit in 340 px)


def P(x, y, z):
    return Vector((K * x, K * y, K * z))


# ------------------------------------------------------------------ mesh
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = next(o for o in bpy.data.objects if o.type == "MESH")
mesh.name = "HorseMesh"
mesh.rotation_mode = "XYZ"                     # glTF imports use quaternions; Euler would be ignored
mesh.rotation_euler = (0, 0, math.pi)          # raw mesh faces -X; the game wants +X
mesh.scale = (K, K, K)
mesh.location = (0, 0, K * SRC_GROUND)
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
nv = len(mesh.data.vertices)
V = np.empty(nv * 3)
mesh.data.vertices.foreach_get("co", V)
V = V.reshape(-1, 3)
print("mesh", nv, "verts, z", V[:, 2].min() / K, V[:, 2].max() / K)
V[:, 2] -= V[:, 2].min()                       # hooves exactly on z=0
mesh.data.vertices.foreach_set("co", V.ravel())
mesh.data.update()
Vn = V / K                                      # pre-K units for fitting

# ------------------------------------------------------------------ legs: fit axes from the mesh
legs = {}
for tag, front, left in (("FL", True, True), ("FR", True, False), ("HL", False, True), ("HR", False, False)):
    sel = (Vn[:, 0] > -0.15) == front
    sel &= (Vn[:, 1] > 0) == left
    pts = []
    for lo in np.arange(0.0, 0.30, 0.04):
        m = sel & (Vn[:, 2] >= lo) & (Vn[:, 2] < lo + 0.04)
        if m.sum() > 5:
            pts.append((lo + 0.02, Vn[m, 0].mean(), Vn[m, 1].mean()))
    pts = np.array(pts)
    ax = np.polyfit(pts[:, 0], pts[:, 1], 1)
    ay = np.polyfit(pts[:, 0], pts[:, 2], 1)
    hip_h, knee_h, fet_h = 0.40, (0.15 if front else 0.16), 0.055

    def at(h):
        return (float(np.polyval(ax, h)), float(np.polyval(ay, h)), h)

    legs[tag] = {"front": front, "hip": at(hip_h), "knee": at(knee_h), "fet": at(fet_h),
                 "ground": (at(0.0)[0], at(0.0)[1], 0.0)}
    print(tag, {k: tuple(round(c, 3) for c in v) for k, v in legs[tag].items() if k != "front"})

# ------------------------------------------------------------------ armature
BONES = {   # name: (head, tail, parent) in pre-K units
    "root": ((-0.05, 0, 0.46), (0.0, 0, 0.46), None),
    "spine": ((-0.32, 0, 0.49), (0.06, 0, 0.50), "root"),
    "neck1": ((0.04, 0, 0.50), (0.17, 0, 0.60), "spine"),
    "neck2": ((0.17, 0, 0.60), (0.30, 0, 0.67), "neck1"),
    "head": ((0.30, 0, 0.67), (0.45, 0, 0.55), "neck2"),
    "tail1": ((-0.40, 0, 0.54), (-0.43, 0, 0.38), "spine"),
    "tail2": ((-0.43, 0, 0.38), (-0.44, 0, 0.14), "tail1"),
}
for tag, L in legs.items():
    BONES[f"{tag}_up"] = (L["hip"], L["knee"], "root")
    BONES[f"{tag}_lo"] = (L["knee"], L["fet"], f"{tag}_up")
    BONES[f"{tag}_ho"] = (L["fet"], L["ground"], f"{tag}_lo")
ORDER = list(BONES)             # parents always precede children

arm_data = bpy.data.armatures.new("HorseRig")
arm = bpy.data.objects.new("HorseRig", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for name in ORDER:
    h, t, par = BONES[name]
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = P(*h), P(*t)
    eb.roll = 0.0
    if par:
        eb.parent = arm_data.edit_bones[par]
bpy.ops.object.mode_set(mode="OBJECT")
REST = {b.name: b.matrix_local.copy() for b in arm_data.bones}
PARENT = {n: BONES[n][2] for n in ORDER}

# ------------------------------------------------------------------ skin weights
key = np.round(Vn * 1e5).astype(np.int64)
U, inv = np.unique(key, axis=0, return_inverse=True)   # seam duplicates share a weight
inv = inv.ravel()
Up = np.zeros((len(U), 3))
Up[inv] = Vn
edges = np.empty(len(mesh.data.edges) * 2, dtype=np.int64)
mesh.data.edges.foreach_get("vertices", edges)
edges = edges.reshape(-1, 2)
ea, eb_ = inv[edges[:, 0]], inv[edges[:, 1]]
nbr_a = np.concatenate([ea, eb_])
nbr_b = np.concatenate([eb_, ea])
deg = np.bincount(nbr_a, minlength=len(U)).astype(float)
deg[deg == 0] = 1

RADIUS = {"spine": 0.21, "neck1": 0.12, "neck2": 0.11, "head": 0.13, "tail1": 0.07, "tail2": 0.06}
for n in ORDER:
    if n[:2] in legs and n.endswith(("_up", "_lo")):
        RADIUS[n] = 0.075
    elif n.endswith("_ho"):
        RADIUS[n] = 0.06
RADIUS["root"] = 0.0


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


names = [n for n in ORDER if n != "root"]
W = np.zeros((len(U), len(names)))
for j, n in enumerate(names):
    h, t, _ = BONES[n]
    d = seg_dist(Up, np.array(h), np.array(t))
    w = np.clip(1.0 - d / RADIUS[n], 0.0, None) ** 2
    if n.endswith("_up"):   # the thigh/shoulder blends into the barrel instead of denting it
        s = np.clip((Up[:, 2] - 0.28) / 0.12, 0, 1)
        w = w * (1.0 - 0.85 * s * s * (3 - 2 * s))
    W[:, j] = w
empty = W.sum(1) < 1e-6
if empty.any():     # outside every bone's reach: nearest bone by relative distance
    rel = np.stack([seg_dist(Up[empty], np.array(BONES[n][0]), np.array(BONES[n][1])) / max(RADIUS[n], 0.05)
                    for n in names], 1)
    W[np.where(empty)[0], rel.argmin(1)] = 1.0
W /= W.sum(1, keepdims=True)
for _ in range(5):          # smooth over the surface, 60/40, never across the (disconnected) legs
    acc = np.zeros_like(W)
    np.add.at(acc, nbr_a, W[nbr_b])
    W = 0.6 * W + 0.4 * acc / deg[:, None]
    W /= W.sum(1, keepdims=True)
top = np.argsort(-W, axis=1)[:, :4]                       # glTF skins carry 4 influences
keep = np.zeros_like(W)
np.put_along_axis(keep, top, np.take_along_axis(W, top, 1), 1)
keep[keep < 0.01] = 0.0
keep /= keep.sum(1, keepdims=True)
WV = keep[inv]
groups = {n: mesh.vertex_groups.new(name=n) for n in names}
for j, n in enumerate(names):
    idx = np.nonzero(WV[:, j] > 0)[0]
    for w in np.unique(np.round(WV[idx, j], 3)):
        sel = idx[np.round(WV[idx, j], 3) == w]
        groups[n].add(sel.tolist(), float(w), "REPLACE")
mesh.parent = arm
mod = mesh.modifiers.new("HorseRig", "ARMATURE")
mod.object = arm
print("weights: max influences/vertex", int((WV > 0).sum(1).max()))

# ------------------------------------------------------------------ posing (pure matrix math)
pb = arm.pose.bones
for b in pb:
    b.rotation_mode = "QUATERNION"


def rest_dir_xz(name):
    h, t, _ = BONES[name]
    return math.atan2(t[2] - h[2], t[0] - h[0])


def pose_matrices(rel_y, rel_z, offset):
    """Armature-space pose matrix for every bone. rel_y/rel_z: extra rotation (rad) about
    world Y (pitch, + = nose down) and world Z (yaw), pivoting on the bone's own head."""
    pose = {}
    for n in ORDER:
        par = PARENT[n]
        if par is None:
            base = Matrix.Translation(offset) @ REST[n]
        else:
            base = pose[par] @ REST[par].inverted() @ REST[n]
        piv = base.translation
        r = (Matrix.Translation(piv) @ Matrix.Rotation(rel_z.get(n, 0.0), 4, "Z")
             @ Matrix.Rotation(rel_y.get(n, 0.0), 4, "Y") @ Matrix.Translation(-piv))
        pose[n] = r @ base
    return pose


def to_basis(pose):
    out = {}
    for n in ORDER:
        par = PARENT[n]
        if par is None:
            out[n] = REST[n].inverted() @ pose[n]
        else:
            rel = REST[par].inverted() @ REST[n]
            out[n] = rel.inverted() @ pose[par].inverted() @ pose[n]
    return out


def apply(rel_y, rel_z=None, offset=Vector((0, 0, 0)), keyframe=None):
    pose = pose_matrices(rel_y, rel_z or {}, offset)
    for n, m in to_basis(pose).items():
        loc, quat, _ = m.decompose()
        pb[n].location, pb[n].rotation_quaternion = loc, quat
        pb[n].scale = (1, 1, 1)
        if keyframe is not None:
            pb[n].keyframe_insert("location", frame=keyframe)
            pb[n].keyframe_insert("rotation_quaternion", frame=keyframe)
    return pose


def smooth(u):
    return u * u * (3 - 2 * u)


def leg_ik(tag, tip_x, tip_z, fold, offset):
    """Joint angles that put hoof `tag`'s ground point at (tip_x, tip_z) (rig units, x/z only)
    with the hoof stub rotated back by `fold` rad. Returns {bone: rel_y}."""
    L = legs[tag]
    hip = Vector(P(*L["hip"])) + offset
    l1 = math.dist((P(*L["hip"]).x, P(*L["hip"]).z), (P(*L["knee"]).x, P(*L["knee"]).z))
    l2 = math.dist((P(*L["knee"]).x, P(*L["knee"]).z), (P(*L["fet"]).x, P(*L["fet"]).z))
    l3 = math.dist((P(*L["fet"]).x, P(*L["fet"]).z), (P(*L["ground"]).x, P(*L["ground"]).z))
    psi_h = -math.pi / 2 - fold                      # hoof direction: straight down, then back
    ax, az = tip_x - l3 * math.cos(psi_h), tip_z - l3 * math.sin(psi_h)
    dx, dz = ax - hip.x, az - hip.z
    d = min(max(math.hypot(dx, dz), abs(l1 - l2) + 1e-4), (l1 + l2) * 0.999)
    alpha = math.acos(max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    psi_a = math.atan2(dz, dx)
    psi_up = psi_a + alpha if L["front"] else psi_a - alpha     # knee forward / hock back
    kx, kz = hip.x + l1 * math.cos(psi_up), hip.z + l1 * math.sin(psi_up)
    psi_lo = math.atan2(az - kz, ax - kx)
    up, lo, ho = f"{tag}_up", f"{tag}_lo", f"{tag}_ho"
    a_up = rest_dir_xz(up) - psi_up
    a_lo = rest_dir_xz(lo) - psi_lo
    a_ho = rest_dir_xz(ho) - psi_h
    return {up: a_up, lo: a_lo - a_up, ho: a_ho - a_lo}


def walk_pose(p, keyframe=None):
    rel_y, rel_z = {}, {}
    bob = math.cos(4 * math.pi * p)                  # two bobs per stride
    off = Vector((0, 0, -K * (HIP_DROP - 0.006 * bob)))
    for tag, ph in PHASE.items():
        q = (p - ph) % 1.0
        gx, gz = K * 0.5 * (legs[tag]["ground"][0] + legs[tag]["hip"][0]), 0.0
        if q < DUTY:                                  # stance: hoof slides back at body speed
            u = q / DUTY
            tx, tz, fold = gx + K * STEP * (0.5 - u), 0.0, 0.0
        else:                                         # swing: arc forward, hoof tucks back
            u = (q - DUTY) / (1 - DUTY)
            tx = gx + K * STEP * (-0.5 + smooth(u))
            tz = K * 0.045 * math.sin(math.pi * u)
            fold = 0.45 * math.sin(math.pi * u)
        tz -= off.z * 0.0                             # target is in armature space, ground is z=0
        rel_y.update(leg_ik(tag, tx, tz, fold, off))
    s = 4 * math.pi * p + 2.4
    rel_y["spine"] = 0.02 * math.sin(4 * math.pi * p)
    rel_y["neck1"] = 0.05 * math.sin(s)
    rel_y["neck2"] = -0.04 * math.sin(s)
    rel_y["head"] = -0.02 * math.sin(s)
    rel_z["tail1"] = 0.12 * math.sin(2 * math.pi * p)
    rel_z["tail2"] = 0.10 * math.sin(2 * math.pi * p - 0.8)
    return apply(rel_y, rel_z, off, keyframe)


GRAZE_DROP = 0.045          # forehand crouch while cropping (pre-K units)
GRAZE_SPREAD = {"FL": 0.035, "FR": -0.035, "HL": 0.0, "HR": 0.0}   # near foreleg steps forward
GRAZE_PITCH = 0.10          # spine nose-down
MUZZLE_Z = 0.10             # head bone tip height over the grass (pre-K units)
NECK_SPLIT = (0.50, 0.33, 0.17)


def graze_rel(lam):
    return {"neck1": lam * NECK_SPLIT[0], "neck2": lam * NECK_SPLIT[1], "head": lam * NECK_SPLIT[2],
            "spine": GRAZE_PITCH}


def graze_pose(t, keyframe=None):
    off = Vector((0, 0, -K * GRAZE_DROP))
    rel_y, rel_z = graze_rel(GRAZE_LAM), {}
    for tag in legs:
        gx = P(*legs[tag]["ground"]).x + K * GRAZE_SPREAD[tag]
        rel_y.update(leg_ik(tag, gx, 0.0, 0.0, off))
    rel_y["head"] += 0.16 * math.sin(2 * math.pi * 2 * t)          # cropping bob
    rel_y["neck1"] += 0.05 * math.sin(2 * math.pi * 2 * t + 1.2)
    rel_z["tail1"] = 0.30 * math.sin(2 * math.pi * 2 * t + 1.0)
    rel_z["tail2"] = 0.25 * math.sin(2 * math.pi * 2 * t + 1.6)
    return apply(rel_y, rel_z, off, keyframe)


def stand_pose(t, keyframe=None):
    rel_y = {"neck1": 0.02 * math.sin(2 * math.pi * t), "head": 0.015 * math.sin(2 * math.pi * t + 1.0)}
    rel_z = {"tail1": 0.12 * math.sin(2 * math.pi * t + 0.5), "tail2": 0.10 * math.sin(2 * math.pi * t + 1.3)}
    return apply(rel_y, rel_z, Vector((0, 0, 0)), keyframe)


# graze: smallest neck fold that brings the head tip down to the grass
def muzzle_tip(lam):
    off = Vector((0, 0, -K * GRAZE_DROP))
    pose = pose_matrices(graze_rel(lam), {}, off)
    tip = pose["head"] @ REST["head"].inverted() @ Vector(P(*BONES["head"][1]))
    return tip / K


GRAZE_LAM = 1.4
for lam in np.arange(0.2, 2.0, 0.005):
    if muzzle_tip(lam).z <= MUZZLE_Z:
        GRAZE_LAM = float(lam)
        break
print("graze fold lam", round(GRAZE_LAM, 3), "head tip x,z", [round(c, 3) for c in muzzle_tip(GRAZE_LAM)[::2]],
      "neck abs deg", [round(math.degrees(GRAZE_LAM * c), 1) for c in NECK_SPLIT])

# ------------------------------------------------------------------ verify: hooves stay planted
dg = bpy.context.evaluated_depsgraph_get()
hoof_idx = {}
for tag in legs:
    g = mesh.vertex_groups[f"{tag}_ho"].index
    ids = [v.index for v in mesh.data.vertices if any(vg.group == g and vg.weight > 0.6 for vg in v.groups)]
    hoof_idx[tag] = ids


def hoof_centroid(tag):
    ev = mesh.evaluated_get(dg)
    m = ev.to_mesh()
    c = np.mean([m.vertices[i].co[:] for i in hoof_idx[tag]], axis=0)
    ev.to_mesh_clear()
    return c


speed = K * STEP / DUTY / (WALK_FRAMES / FPS)       # rig units per second
resid = {}
N = WALK_FRAMES * 4
for tag, ph in PHASE.items():
    xs, zs, qs = [], [], []
    for i in range(N):
        p = i / N
        walk_pose(p)
        bpy.context.view_layer.update()
        c = hoof_centroid(tag)
        xs.append(c[0] + speed * ((p - ph) % 1.0) * (WALK_FRAMES / FPS))   # q, not p: p wraps mid-stance
        zs.append(c[2])
        qs.append((p - ph) % 1.0)
    xs, zs, qs = np.array(xs), np.array(zs), np.array(qs)
    st = (qs > 0.03) & (qs < DUTY - 0.03)           # skip the touch-down / lift-off frames
    resid[tag] = {"stance_frames": int(st.sum()),
                  "x_drift_cm": round(float((xs[st].max() - xs[st].min()) * 100), 2),
                  "z_range_cm": round(float((zs[st].max() - zs[st].min()) * 100), 2),
                  "swing_lift_cm": round(float((zs[~st].max() - zs[st].mean()) * 100), 2)}
print("planted-foot residual (rig units are metres, ears ~1.95 m):", json.dumps(resid))

# ------------------------------------------------------------------ actions
if arm.animation_data is None:
    arm.animation_data_create()
CLIPS = (("horse_walk", WALK_FRAMES, walk_pose), ("horse_graze", GRAZE_FRAMES, graze_pose),
         ("horse_stand", STAND_FRAMES, stand_pose))
for name, n, fn in CLIPS:
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for i in range(n + 1):                          # last key repeats the first: seamless loop
        fn((i % n) / n, keyframe=1 + i)
    act.frame_range = (1, n + 1)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, act)
arm.animation_data.action = None
for b in pb:
    b.location, b.rotation_quaternion = (0, 0, 0), (1, 0, 0, 0)

# ------------------------------------------------------------------ export GLB
os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
mesh.select_set(True)
glb = os.path.join(OUT, "horse_rigged.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True,
                          export_apply=False)
print("exported", glb, os.path.getsize(glb))

# ------------------------------------------------------------------ sprite frames
for tr in arm.animation_data.nla_tracks:      # exported already; stop the clips overriding direct poses
    tr.mute = True
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 40
sc.cycles.use_denoising = False
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y = CANVAS
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.78, 0.80, 0.84, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sc.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(55), math.radians(8), math.radians(-25))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = CANVAS[0] / PPU * K
cam.location = (K * 0.0, -8.0, CANVAS[1] / PPU * K / 2)          # ground = bottom row of the canvas
cam.rotation_euler = (math.radians(90), 0, 0)
sc.collection.objects.link(cam)
sc.camera = cam
frames = os.path.join(OUT, "frames")


def shoot(fname, fn, arg):
    fn(arg)
    sc.render.filepath = os.path.join(frames, fname)
    bpy.ops.render.render(write_still=True)


for i in range(8):
    shoot(f"horse_walk_{i:02d}.png", walk_pose, i / 8)
for i in range(6):
    shoot(f"horse_graze_{i:02d}.png", graze_pose, i / 6)
shoot("horse_stand.png", stand_pose, 0.0)

px_per_cycle = K * STEP / DUTY / K * PPU            # canvas px the ground slides per stride
report = {
    "bones": len(ORDER), "verts": nv, "scale_K": K, "fps": FPS,
    "walk_frames": WALK_FRAMES, "walk_cycle_s": WALK_FRAMES / FPS, "walk_speed_units_per_s": round(speed, 3),
    "stride_canvas_px": round(px_per_cycle, 1), "planted_feet": resid,
    "graze_fold_rad": round(GRAZE_LAM, 3),
    "legs": {t: {k: [round(c, 3) for c in v] for k, v in L.items() if k != "front"} for t, L in legs.items()},
}
with open(os.path.join(OUT, "report.json"), "w") as f:
    json.dump(report, f, indent=2)
print("DONE")
