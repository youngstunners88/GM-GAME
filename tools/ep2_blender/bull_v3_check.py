"""Close-up + transparency checks for a Bull GLB (headless, EEVEE, studio HDRI). Skill: blender-headless-render-safety.

  blender -b --python tools/ep2_blender/bull_v3_check.py -- <glb> <out_prefix> head  [--views front,34,side,back] [--hdri H]
  blender -b --python tools/ep2_blender/bull_v3_check.py -- <glb> <out_prefix> elbows [--walk-glb src/episode2/assets/inferno_bull_walking_clip.glb]

head   : ortho close-ups of the head/shoulders (rest pose).
elbows : for Idle_02 and the walk clip, arms locked (as Ep2BullHero) and unlocked, 4 frames each, both elbows,
         front/back/side, back-face culling OFF vs ON on a transparent film. Reports
           ONLY_BACK = pixels covered with culling OFF but not with culling ON (a surface seen only through its inside = see-through)
           HOLES     = pixels enclosed by the silhouette with culling ON that culling OFF covers (see-through interior)
           (a natural gap, e.g. between an akimbo arm and the torso, is background in BOTH modes and is not counted)
         and writes a magenta-background contact sheet per clip/lock: rows = elbow x view, cols = OFF | ON.
"""
import bpy, sys, math, os
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
glb, prefix, mode = argv[0], argv[1], argv[2]
def opt(n, d): return argv[argv.index(n) + 1] if n in argv else d
HDRI = opt("--hdri", os.path.expanduser("~/.cache/gm-game/polyhaven/studio_small_08/studio_small_08_1k.hdr"))
WALK = opt("--walk-glb", "src/episode2/assets/inferno_bull_walking_clip.glb")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("s"); sc.world = w; w.use_nodes = True
nt = w.node_tree; nt.nodes.clear()
env = nt.nodes.new("ShaderNodeTexEnvironment"); env.image = bpy.data.images.load(HDRI)
bg = nt.nodes.new("ShaderNodeBackground"); out = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(env.outputs[0], bg.inputs[0]); nt.links.new(bg.outputs[0], out.inputs[0])
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"


def render(path, size, loc, rot, ortho):
    sc.render.resolution_x = sc.render.resolution_y = size
    cam.data.ortho_scale = ortho; cam.location = loc; cam.rotation_euler = rot
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def fcurves(act):
    if hasattr(act, "fcurves"): return act.fcurves
    return act.layers[0].strips[0].channelbags[0].fcurves


def set_cull(on):
    for o in meshes:
        for m in o.data.materials:
            m.use_backface_culling = on


sc.render.film_transparent = True
if mode == "head":
    sc.render.film_transparent = False
    views = opt("--views", "front,34,side,back").split(",")
    head = arm.matrix_world @ arm.pose.bones["Head"].head
    ang = {"front": 0, "34": 40, "side": 90, "back": 180}
    for v in views:
        a = math.radians(ang[v]); d = 6
        c = Vector((head.x, head.y, head.z - 0.12))
        render("%s_%s.png" % (prefix, v), 800, (c.x + d * math.sin(a), c.y - d * math.cos(a), c.z), (math.radians(90), 0, a), 1.1)
    print("HEAD_DONE")
    sys.exit(0)

def backface_magenta():
    """first-visible-surface-is-a-back-face pixels render pure magenta (= an interior/gap is seen)."""
    for o in meshes:
        for m in o.data.materials:
            m.use_backface_culling = False
            nt_ = m.node_tree
            outn = next(n for n in nt_.nodes if n.type == "OUTPUT_MATERIAL")
            src = outn.inputs["Surface"].links[0].from_socket
            geo = nt_.nodes.new("ShaderNodeNewGeometry"); em = nt_.nodes.new("ShaderNodeEmission")
            em.inputs["Color"].default_value = (1, 0, 1, 1); em.inputs["Strength"].default_value = 1.0
            mix = nt_.nodes.new("ShaderNodeMixShader")
            nt_.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
            nt_.links.new(src, mix.inputs[1]); nt_.links.new(em.outputs[0], mix.inputs[2])
            nt_.links.new(mix.outputs[0], outn.inputs["Surface"])


if mode == "seam":
    # neck/collar window: 8 azimuths x (level, from above, from below); counts back-face-first pixels
    backface_magenta()
    gx, gy, gz = [float(t) for t in opt("--target", "-0.03,1.95,0.1").split(",")]   # glTF coords (Y up)
    cx, cy, cz = gx, -gz, gy                                                                      # Blender world
    tot_ = 0; sheet = []
    SZ2 = 400
    for el_deg in (0, 35, -25):
        row = []
        for az in range(0, 360, 45):
            a = math.radians(az); e = math.radians(el_deg); d = 6
            loc = (cx + d * math.cos(e) * math.sin(a), cy - d * math.cos(e) * math.cos(a), cz + d * math.sin(e))
            # camera looks at the point: Euler from direction
            dirv = Vector((cx, cy, cz)) - Vector(loc)
            cam.rotation_mode = "XYZ"
            rotq = dirv.to_track_quat("-Z", "Y").to_euler()
            render("/tmp/claude-1000/w/_sm.png", SZ2, loc, rotq, 0.55)
            im = bpy.data.images.load("/tmp/claude-1000/w/_sm.png", check_existing=False)
            px = np.empty(SZ2 * SZ2 * 4, np.float32); im.pixels.foreach_get(px); bpy.data.images.remove(im)
            px = px.reshape(SZ2, SZ2, 4)
            mg = (px[:, :, 0] > 0.9) & (px[:, :, 1] < 0.12) & (px[:, :, 2] > 0.9) & (px[:, :, 3] > 0.5)
            n = int(mg.sum()); tot_ += n
            print("SEAM_VIEW el=%d az=%d magenta_px=%d" % (el_deg, az, n))
            vis = px[:, :, :3].copy(); vis[px[:, :, 3] < 0.5] = (0.5, 0.5, 0.5)
            row.append(vis)
        sheet.append(np.concatenate(row, 1))
    full = np.concatenate(sheet, 0)
    sm = full[::2, ::2]
    im = bpy.data.images.new("ss", sm.shape[1], sm.shape[0], alpha=False)
    im.pixels.foreach_set(np.concatenate([sm, np.ones(sm.shape[:2] + (1,), np.float32)], 2).ravel())
    im.filepath_raw = prefix + "_seam_backface.png"; im.file_format = "PNG"; im.save()
    print("SEAM_TOTAL magenta_px", tot_)
    sys.exit(0)

# ---- elbows -----------------------------------------------------------------------------------------------------
ARM_BONES = ("LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand")
walk_act = None
if os.path.exists(WALK):
    have = set(bpy.data.objects)
    keep_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=WALK)
    for o in set(bpy.data.objects) - have:
        bpy.data.objects.remove(o, do_unlink=True)
    new = [x for x in bpy.data.actions if x not in keep_actions]
    walk_act = new[0] if new else None
idle = bpy.data.actions.get("Idle_02") or next(x for x in bpy.data.actions if x.name.startswith("Idle_02"))
print("ACTIONS", [x.name for x in bpy.data.actions])
if arm.animation_data is None: arm.animation_data_create()
VIEWS = {"front": ((0, -6, 0), (math.radians(90), 0, 0)), "back": ((0, 6, 0), (math.radians(90), 0, math.radians(180))),
         "sideL": ((6, 0, 0), (math.radians(90), 0, math.radians(90))), "sideR": ((-6, 0, 0), (math.radians(90), 0, math.radians(-90)))}
SZ = 256
tot = {}


def holes(mask, cover=None):
    """pixels not in `mask` that are enclosed by it (flood fill from the border); with `cover`, only those covered there."""
    h, w_ = mask.shape
    free = ~mask
    reach = np.zeros_like(free)
    reach[0, :] = free[0, :]; reach[-1, :] |= free[-1, :]; reach[:, 0] |= free[:, 0]; reach[:, -1] |= free[:, -1]
    while True:
        n = reach.copy()
        n[1:, :] |= reach[:-1, :] & free[1:, :]; n[:-1, :] |= reach[1:, :] & free[:-1, :]
        n[:, 1:] |= reach[:, :-1] & free[:, 1:]; n[:, :-1] |= reach[:, 1:] & free[:, :-1]
        if (n == reach).all(): break
        reach = n
    enc = free & ~reach
    return int((enc & cover).sum()) if cover is not None else int(enc.sum())


def grab(path):
    im = bpy.data.images.load(path, check_existing=False)
    px = np.empty(SZ * SZ * 4, np.float32); im.pixels.foreach_get(px); bpy.data.images.remove(im)
    return px.reshape(SZ, SZ, 4)


def magenta(px):
    a = px[:, :, 3:4]
    rgb = px[:, :, :3] * a + np.array([1, 0, 1], np.float32) * (1 - a)
    return np.concatenate([rgb, np.ones_like(a)], 2)


for cname, act in (("idle", idle), ("walk", walk_act)):
    if act is None: continue
    for lock in (True, False):
        fcs = fcurves(act)
        arm.animation_data.action = act
        try: arm.animation_data.action_slot = act.slots[0]
        except Exception: pass
        # Ep2Actor drops bone translations except Hips; Ep2BullHero locks the arms at idle/walk
        removed = []
        for fc in list(fcs):
            if (fc.data_path.endswith("location") and '"Hips"' not in fc.data_path) or \
               (lock and any('"%s"' % b in fc.data_path for b in ARM_BONES)):
                removed.append((fc.data_path, fc.array_index, [tuple(k.co) for k in fc.keyframe_points]))
                fcs.remove(fc)
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        frames = sorted({f0 + int((f1 - f0) * t) for t in (0, 0.5)})
        only = {}; hol = {}; best = {}
        for fr in frames:
            sc.frame_set(fr)
            bpy.context.view_layer.update()
            for el, bone in (("L", "LeftForeArm"), ("R", "RightForeArm")):
                c = arm.matrix_world @ arm.pose.bones[bone].head
                for vn, (off, rot) in VIEWS.items():
                    if (el == "L" and vn == "sideR") or (el == "R" and vn == "sideL"): continue   # the outer side only
                    loc = (c.x + off[0], c.y + off[1], c.z + off[2])
                    pxs = []
                    for cull in (False, True):
                        set_cull(cull)
                        p = "/tmp/claude-1000/w/_el.png"
                        render(p, SZ, loc, rot, 0.7)
                        pxs.append(grab(p))
                    off_m, on_m = pxs[0][:, :, 3] > 0.5, pxs[1][:, :, 3] > 0.5
                    k = (el, vn)
                    n_only = int((off_m & ~on_m).sum()); n_hol = holes(on_m, off_m)   # enclosed pixels that culling ON loses
                    only[k] = only.get(k, 0) + n_only; hol[k] = hol.get(k, 0) + n_hol
                    if k not in best or n_only + n_hol >= best[k][0]:
                        best[k] = (n_only + n_hol, magenta(pxs[0]), magenta(pxs[1]))
        tag = "%s_%s" % (cname, "locked" if lock else "free")
        rows = [np.concatenate([best[k][1], best[k][2]], 1) for k in sorted(best)]
        sheet = np.concatenate(rows, 0)
        im = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0], alpha=False)
        im.pixels.foreach_set(sheet.ravel()); im.filepath_raw = "%s_transp_%s.png" % (prefix, tag); im.file_format = "PNG"; im.save()
        bpy.data.images.remove(im)
        so, sh = sum(only.values()), sum(hol.values())
        print("TRANSP %-12s frames=%s ONLY_BACK=%d HOLES=%d per-case %s" % (tag, frames, so, sh,
              {"%s-%s" % k: (only[k], hol[k]) for k in sorted(only)}))
        tot[tag] = (so, sh)
        # restore the removed curves for the next lock mode
        for dp, idx, kps in removed:
            nf = fcs.new(dp, index=idx)
            for co in kps: nf.keyframe_points.insert(co[0], co[1])
    if arm.animation_data: pass
print("TRANSP_TOTAL", tot)
