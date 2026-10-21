"""Rig a generated (Hunyuan3D / Tripo-style) standing humanoid mesh onto the game's townfolk skeleton and export a game GLB with the five authored
clips (Idle / Carry / Greet / Point / Walk). Skill ep2-mixamo-pipeline.

  blender -b --factory-startup -P tools/ep2_motion/rig_scan_character.py -- --obj textured_mesh.obj --albedo albedo.jpg \
      --height 1.74 --tris 16000 --tex 1024 --out src/episode2/extras/people/prisoner_hq.glb [--debug dbg/]

Steps: import (z-up, faces -Y) -> real height, feet on z=0, centred -> decimate (Collapse keeps UVs) -> fit the on-box joints (tools/ep2_blender/
build_armory_folk.py S()) to the mesh (vertical proportions kept, shoulder/hip widths measured from silhouette slices) -> armature from the same
code that authors the clips -> bone weights (nearest-segment weighting limited per limb by slab rules) -> clips -> export. --debug writes x-ray
renders of the fit and a stress-pose strip so the fit can be judged by eye before it ships.
Prints @@{json}.
"""
import argparse
import importlib.util
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument("--obj", required=True)
ap.add_argument("--albedo", required=True)
ap.add_argument("--height", type=float, default=1.74)
ap.add_argument("--tris", type=int, default=22000)
ap.add_argument("--tex", type=int, default=1024)
ap.add_argument("--out", required=True)
ap.add_argument("--debug", default="")
ap.add_argument("--shoulder-k", type=float, default=0.0, help="override shoulder half-width (m) if the auto measure is off")
ap.add_argument("--head-obj", default="", help="a separate, sharper head scan (hat and neck) that replaces the body scan's own head")
ap.add_argument("--head-albedo", default="")
ap.add_argument("--head-tex", type=int, default=1024)
ap.add_argument("--head-tris", type=int, default=9000)
ap.add_argument("--head-span", type=float, default=0.44, help="metres from the top of the head scan down to its (cropped) bottom edge")
ap.add_argument("--head-keep", type=float, default=0.40, help="keep the head scan this far below its top (the neck stub is hidden in the collar)")
ap.add_argument("--eye-patch", action="store_true", help="Jack Hammer: model a leather eye patch + straps over the head scan's patch eye (the painted one is unreliable)")
ap.add_argument("--head-tone", type=float, default=1.0, help="saturation multiplier for the head albedo (the scan's skin comes out hot)")
ap.add_argument("--boots", action="store_true", help="model leather boots over the scan's flat-cut trouser ends (weighted to the Foot bones)")
ap.add_argument("--neck-cut", type=float, default=0.36, help="the body scan is cut this far below the top of the figure")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

spec = importlib.util.spec_from_file_location("armory_folk", os.path.join(HERE, "..", "ep2_blender", "build_armory_folk.py"))
AF = importlib.util.module_from_spec(spec)
sys.argv_backup, sys.argv = sys.argv, [sys.argv[0]]          # the folk module parses --dir itself
spec.loader.exec_module(AF)
sys.argv = sys.argv_backup

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = AF.FPS
bpy.ops.wm.obj_import(filepath=a.obj)
body = next(o for o in bpy.data.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)     # the OBJ importer leaves a Y-up -> Z-up rotation on the object

# ---- 1. normalise: real height, feet on z = 0, centred on x/y (by the hip-height slab)
me = body.data
zs = [v.co.z for v in me.vertices]
z0, z1 = min(zs), max(zs)
s = a.height / (z1 - z0)
for v in me.vertices:
    v.co = Vector((v.co.x * s, v.co.y * s, (v.co.z - z0) * s))
hip = [v.co for v in me.vertices if 0.80 < v.co.z < 1.0]
cx = sum(p.x for p in hip) / len(hip)
cy = sum(p.y for p in hip) / len(hip)
for v in me.vertices:
    v.co.x -= cx
    v.co.y -= cy
me.update()
tris_before = sum(len(p.vertices) - 2 for p in me.polygons)

# ---- 1b. optional head swap: cut the body scan's smeared head off at the collar and prepare the separate head scan (weighted to the Head bone in step 5)
head = None
if a.head_obj:
    bm = bmesh.new()
    bm.from_mesh(me)
    zcut = a.height - a.neck_cut
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > zcut], context="VERTS")
    bm.to_mesh(me)
    bm.free()
    sl = [v.co for v in me.vertices if v.co.z > zcut - 0.06]
    ncx = sum(p.x for p in sl) / len(sl)
    ncy = sum(p.y for p in sl) / len(sl)
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=a.head_obj)
    head = next(o for o in bpy.data.objects if o not in before and o.type == "MESH")
    bpy.ops.object.select_all(action="DESELECT")
    head.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    hz = [v.co.z for v in head.data.vertices]
    h0, h1 = min(hz), max(hz)
    s2 = a.head_span / (h1 - h0)
    top_z = a.height
    for v in head.data.vertices:
        v.co = Vector((v.co.x * s2, v.co.y * s2, (v.co.z - h0) * s2 + (top_z - a.head_span)))
    bm = bmesh.new()
    bm.from_mesh(head.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < top_z - a.head_keep], context="VERTS")
    bm.to_mesh(head.data)
    bm.free()
    ring = [v.co for v in head.data.vertices if v.co.z < top_z - a.head_keep + 0.04]
    hcx = sum(p.x for p in ring) / len(ring)
    hcy = sum(p.y for p in ring) / len(ring)
    for v in head.data.vertices:
        v.co.x += ncx - hcx
        v.co.y += ncy - hcy
    head.data.update()
    head_tris_before = sum(len(p.vertices) - 2 for p in head.data.polygons)
    if head_tris_before > a.head_tris:
        dm = head.modifiers.new("Decimate", "DECIMATE")
        dm.decimate_type = "COLLAPSE"
        dm.ratio = a.head_tris / head_tris_before
        dm.use_collapse_triangulate = True
        with bpy.context.temp_override(object=head, active_object=head):
            bpy.ops.object.modifier_apply(modifier=dm.name)
    for poly in head.data.polygons:
        poly.use_smooth = True
    himg = bpy.data.images.load(os.path.abspath(a.head_albedo))
    if himg.size[0] > a.head_tex:
        himg.scale(a.head_tex, a.head_tex)
    if a.head_tone != 1.0:
        import numpy as np
        tb = np.empty(himg.size[0] * himg.size[1] * 4, dtype=np.float32)
        himg.pixels.foreach_get(tb)
        tb = tb.reshape(-1, 4)
        lum = (tb[:, 0] * 0.3 + tb[:, 1] * 0.55 + tb[:, 2] * 0.15)[:, None]
        tb[:, :3] = (lum + (tb[:, :3] - lum) * a.head_tone) * (0.90 + 0.10 * a.head_tone)
        himg.pixels.foreach_set(tb.reshape(-1))
        himg.update()
    hmat = bpy.data.materials.new("jack_head")
    hb = next(n for n in hmat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    ht = hmat.node_tree.nodes.new("ShaderNodeTexImage")
    ht.image = himg
    hmat.node_tree.links.new(ht.outputs["Color"], hb.inputs["Base Color"])
    hb.inputs["Roughness"].default_value = 0.8
    hb.inputs["Metallic"].default_value = 0.0
    head.data.materials.clear()
    head.data.materials.append(hmat)
    bpy.context.view_layer.objects.active = body
    patch_ob = None
    if a.eye_patch:
        # Jack Hammer's patch eye is his LEFT (screen right when he faces us). The scan's own painted patch is smeared, so the patch and its straps are
        # painted into the head albedo from the real surface: landmarks are pixels of a reference render (camera 0.9 m in front of the face at hat-top -
        # 0.2 m, 70 mm lens, 900 px); every pixel of the patch shape is a ray dropped on the head scan, its UV is found and the texel painted.
        import numpy as np
        from mathutils.interpolate import poly_3d_calc
        cam_o = Vector((0.0, -0.9, a.height - 0.20))
        mpp = 0.9 * 18.0 / 70.0 / 450.0
        W, Hh = himg.size
        buf = np.empty(W * Hh * 4, dtype=np.float32)
        himg.pixels.foreach_get(buf)
        buf = buf.reshape(Hh, W, 4)
        uvl = head.data.uv_layers.active.data
        painted = 0

        def paint_px(px, py, col):
            d = Vector(((px - 450) * mpp, 0.9, -(py - 450) * mpp)).normalized()
            hit, loc, nor, fi = head.ray_cast(cam_o, d)
            if not hit or nor.y > -0.15:                              # only surfaces that face the camera
                return False
            poly = head.data.polygons[fi]
            vs = [head.data.vertices[v].co for v in poly.vertices]
            wts = poly_3d_calc(vs, loc)
            u = sum(w * uvl[l].uv.x for w, l in zip(wts, poly.loop_indices))
            v = sum(w * uvl[l].uv.y for w, l in zip(wts, poly.loop_indices))
            x, y = int(u * (W - 1)), int(v * (Hh - 1))
            buf[max(0, y - 1):y + 2, max(0, x - 1):x + 2] = col
            return True

        def sample_px(px, py):
            d = Vector(((px - 450) * mpp, 0.9, -(py - 450) * mpp)).normalized()
            hit, loc, nor, fi = head.ray_cast(cam_o, d)
            if not hit:
                return None
            poly = head.data.polygons[fi]
            vs = [head.data.vertices[v].co for v in poly.vertices]
            wts = poly_3d_calc(vs, loc)
            u = sum(w * uvl[l].uv.x for w, l in zip(wts, poly.loop_indices))
            v = sum(w * uvl[l].uv.y for w, l in zip(wts, poly.loop_indices))
            return buf[int(v * (Hh - 1)), int(u * (W - 1))].copy()

        # the scan painted a black smear down the cheek where it tried to put a patch: cover it with the cheek's own skin tone first
        cols = [c for c in (sample_px(400, 575), sample_px(395, 600), sample_px(415, 560), sample_px(380, 590)) if c is not None]
        if cols:
            skin = sum(cols) / len(cols)
            for gy in range(496, 600):
                for gx in range(428, 516):
                    paint_px(gx, gy, skin)
        LEATHER = (0.020, 0.017, 0.015, 1.0)
        STRAP = (0.030, 0.024, 0.020, 1.0)
        cx, cy, rx, ry, tilt = 436.0, 498.0, 47.0, 37.0, math.radians(-22)
        for gy in range(int(cy - 70), int(cy + 71)):
            for gx in range(int(cx - 70), int(cx + 71)):
                dx, dy = gx - cx, gy - cy
                u2 = (dx * math.cos(tilt) + dy * math.sin(tilt)) / rx
                v2 = (-dx * math.sin(tilt) + dy * math.cos(tilt)) / ry
                r2 = u2 * u2 + v2 * v2
                if r2 <= 1.0:
                    painted += paint_px(gx, gy, (0.012, 0.010, 0.009, 1.0) if r2 < 0.78 else LEATHER)        # darker core, a lighter stitched rim
        for pts in ([(398, 474), (350, 458), (300, 449), (240, 445)], [(480, 500), (508, 492), (530, 482), (552, 464)]):
            for (p0, p1) in zip(pts[:-1], pts[1:]):
                n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1])) * 1.5) + 1
                for k in range(n + 1):
                    t = k / n
                    for off in (-2, -1, 0, 1, 2):
                        paint_px(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t + off, STRAP)
        himg.pixels.foreach_set(buf.reshape(-1))
        himg.update()
        himg.pack()
        print("@@PATCH painted rays", painted)

# ---- 2. decimate before skinning
if tris_before > a.tris:
    m = body.modifiers.new("Decimate", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = a.tris / tris_before
    m.use_collapse_triangulate = True
    with bpy.context.temp_override(object=body, active_object=body):
        bpy.ops.object.modifier_apply(modifier=m.name)
me = body.data
for poly in me.polygons:
    poly.use_smooth = True                              # a decimated scan is faceted without smooth normals
tris = sum(len(p.vertices) - 2 for p in me.polygons)

# ---- 3. material: albedo only (shrunk), roughness constant - small, game-safe
img = bpy.data.images.load(os.path.abspath(a.albedo))
if img.size[0] > a.tex:
    img.scale(a.tex, a.tex)
mat = bpy.data.materials.new("prisoner")
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.85
bsdf.inputs["Metallic"].default_value = 0.0
me.materials.clear()
me.materials.append(mat)

# ---- 4. measure the silhouette and fit the joints
H = a.height
pts = [v.co for v in me.vertices]


def xext(z, tol=0.015):
    xs = [p.x for p in pts if abs(p.z - z) < tol]
    return (min(xs), max(xs)) if xs else (0.0, 0.0)


# shoulder line: the widest slab between 70% and 86% of the height
best = max(((xext(H * f)[1] - xext(H * f)[0], H * f) for f in [0.70 + 0.01 * i for i in range(17)]))
sh_w, sh_z = best
# hip width: the slab at ~50% of the height
hw0, hw1 = xext(H * 0.50)
j = AF.S(H, girth=1.0)
scale_z = H / 1.86
# measured widths -> joint x positions (arms hang at the body's sides: the outer extent is the arm's outside)
arm_x = sh_w / 2 * 0.80 if not a.shoulder_k else a.shoulder_k
for side, sx in (("L", 1.0), ("R", -1.0)):
    j["arm." + side].x = sx * arm_x * 0.78
    j["clav." + side].x = sx * arm_x * 0.30
    j["elbow." + side].x = sx * arm_x * 0.98
    j["wrist." + side].x = sx * arm_x * 1.02
    j["hand." + side].x = sx * arm_x * 1.04
    leg_x = max(0.07, (hw1 - hw0) / 2 * 0.42)
    j["thigh." + side].x = sx * leg_x
    j["knee." + side].x = sx * leg_x * 1.08
    j["ankle." + side].x = sx * leg_x * 1.12
    j["toe." + side].x = sx * leg_x * 1.12
# the body's own y (depth): centre the skeleton on the mesh's median depth at each level is enough for a stylised rig
fit = {"shoulder_width_m": round(sh_w, 3), "shoulder_z_m": round(sh_z, 3), "hip_width_m": round(hw1 - hw0, 3), "arm_x": round(arm_x, 3)}

# ---- 5. armature from the same code that authors the clips, weights, clips
arm_ob = AF.make_armature("prisoner_hq", j)
ends = AF.bone_ends(j)
seg = {b: (ends[b][0], ends[b][1] - ends[b][0]) for b, _ in AF.BONE_PARENTS if b != "Root"}
for b in seg:
    body.vertex_groups.new(name=b)
vg = {g.name: g for g in body.vertex_groups}
LEFT = ("Shoulder.L", "UpperArm.L", "Forearm.L", "Hand.L")
RIGHT = ("Shoulder.R", "UpperArm.R", "Forearm.R", "Hand.R")
mid_x = 0.0
for v in me.vertices:
    co = v.co
    allowed = list(seg.keys())
    # a vertex well inside the torso column never takes arm weights (arms hang beside the body); outside it never takes the other arm's
    if abs(co.x) < arm_x * 0.62 and co.z > 0.9 * scale_z:
        allowed = [b for b in allowed if b not in LEFT and b not in RIGHT]
    elif co.x > 0:
        allowed = [b for b in allowed if b not in RIGHT]
    else:
        allowed = [b for b in allowed if b not in LEFT]
    if co.z < 0.52 * H:
        allowed = [b for b in allowed if not (b.startswith("Thigh.") or b.startswith("Shin.") or b.startswith("Foot.")) or b.endswith(".L" if co.x > 0 else ".R")]
    best = []
    for b in allowed:
        p0, d = seg[b]
        t = max(0.0, min(1.0, (co - p0).dot(d) / max(d.length_squared, 1e-9)))
        best.append(((co - (p0 + d * t)).length, b))
    best.sort()
    best = best[:3]
    ws = [(1.0 / max(dist, 0.012) ** 4, b) for dist, b in best]
    tot = sum(w for w, _ in ws)
    for w, b in ws:
        vg[b].add([v.index], w / tot, "REPLACE")
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm_ob
body.parent = arm_ob
body.name = "prisoner_hq_body"
if head is not None:
    hg = head.vertex_groups.new(name="Head")
    hg.add([v.index for v in head.data.vertices], 1.0, "REPLACE")
    hm = head.modifiers.new("Armature", "ARMATURE")
    hm.object = arm_ob
    head.parent = arm_ob
    head.name = "jack_head"
    if a.eye_patch and "patch_ob" in globals() and patch_ob is not None:
        pg = patch_ob.vertex_groups.new(name="Head")
        pg.add([v.index for v in patch_ob.data.vertices], 1.0, "REPLACE")
        pam = patch_ob.modifiers.new("Armature", "ARMATURE")
        pam.object = arm_ob
        patch_ob.parent = arm_ob
AF.build_clips(arm_ob, "utah")

# ---- 5b. optional boots: black leather over the flat-cut trouser ends, one rigid piece per foot
boots_ob = None
if a.boots:
    bm_mat = bpy.data.materials.new("Boots")
    bb = next(n for n in bm_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bb.inputs["Base Color"].default_value = (0.012, 0.009, 0.007, 1)
    bb.inputs["Roughness"].default_value = 0.95
    bb.inputs["Specular IOR Level"].default_value = 0.1
    parts = []
    for side, sgn in (("L", 1.0), ("R", -1.0)):
        sl = [v.co for v in me.vertices if v.co.z < 0.12 and (v.co.x * sgn) > 0]
        if not sl:
            continue
        x0, x1 = min(p.x for p in sl), max(p.x for p in sl)
        y0, y1 = min(p.y for p in sl), max(p.y for p in sl)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        rx, ry = (x1 - x0) / 2 + 0.014, (y1 - y0) / 2 + 0.014
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=1.0, depth=1.0, location=(cx, cy, 0.17))
        sh = bpy.context.object
        sh.scale = (rx, ry, 0.34)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy - 0.085, 0.05))
        ft = bpy.context.object
        ft.scale = (rx * 2 * 1.02, 0.30, 0.10)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(cx, cy + ry * 0.9, 0.015))
        hl = bpy.context.object
        hl.scale = (rx * 1.6, 0.07, 0.03)
        for o in (sh, ft, hl):
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in (sh, ft, hl):
            o.select_set(True)
        bpy.context.view_layer.objects.active = sh
        bpy.ops.object.join()
        foot = bpy.context.object
        foot.name = "boot_" + side
        bv = foot.modifiers.new("Bevel", "BEVEL")
        bv.width = 0.022
        bv.segments = 3
        with bpy.context.temp_override(object=foot, active_object=foot):
            bpy.ops.object.modifier_apply(modifier=bv.name)
        for poly in foot.data.polygons:
            poly.use_smooth = True
        foot.data.materials.append(bm_mat)
        g = foot.vertex_groups.new(name="Foot." + side)
        g.add([v.index for v in foot.data.vertices], 1.0, "REPLACE")
        fm = foot.modifiers.new("Armature", "ARMATURE")
        fm.object = arm_ob
        foot.parent = arm_ob
        parts.append(foot)
    boots_ob = parts

# ---- 6. optional debug renders: x-ray fit + a stress strip
if a.debug:
    os.makedirs(a.debug, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 500, 760
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    sc.collection.objects.link(cam)
    sc.camera = cam

    def shot(name, view="front", xray=False):
        sc.display.shading.show_xray = xray
        d = {"front": Vector((0, -1, 0.05)), "three": Vector((0.7, -0.7, 0.05))}[view].normalized()
        ctr = Vector((0, 0, H * 0.5))
        cam.location = ctr + d * H * 2.2
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(a.debug, name + ".png")
        bpy.ops.render.render(write_still=True)
    arm_ob.show_in_front = True
    arm_ob.data.display_type = "STICK"
    shot("fit_xray", "front", True)
    for act in ("Walk", "Greet", "Point", "Carry"):
        bpy.data.actions.get(act)
    arm_ob.animation_data_create()
    for act, fr in (("Walk", 8), ("Greet", 12), ("Point", 14), ("Carry", 10)):
        A = bpy.data.actions.get(act)
        if A is None:
            continue
        arm_ob.animation_data.action = A
        if A.slots and not arm_ob.animation_data.action_slot:
            arm_ob.animation_data.action_slot = A.slots[0]
        sc.frame_set(fr)
        arm_ob.data.display_type = "OCTAHEDRAL"
        shot("pose_" + act, "three", False)

# ---- 7. export (selection only; clips as actions)
for act in bpy.data.actions:
    act.use_fake_user = True
bpy.ops.object.select_all(action="DESELECT")
arm_ob.select_set(True)
body.select_set(True)
if head is not None:
    head.select_set(True)
    if a.eye_patch and "patch_ob" in globals() and patch_ob is not None:
        patch_ob.select_set(True)
for bo in (boots_ob or []):
    bo.select_set(True)
bpy.context.view_layer.objects.active = arm_ob
arm_ob.animation_data_create()
arm_ob.animation_data.action = bpy.data.actions["Idle"]
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=a.out, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
    export_animations=True, export_animation_mode="ACTIONS", export_skins=True, export_influence_nb=4, export_def_bones=False,
    export_force_sampling=False, export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=True,
    export_bake_animation=False, export_frame_range=False, export_image_format="JPEG", export_jpeg_quality=88)
raw = open(a.out, "rb").read()
import struct
jl = struct.unpack_from("<I", raw, 12)[0]
gl = json.loads(raw[20:20 + jl])
print("@@" + json.dumps({"ok": True, "out": a.out, "bytes": len(raw), "tris_before": tris_before, "tris": tris, "fit": fit, "bones": len(arm_ob.data.bones),
                         "animations": [x.get("name") for x in gl.get("animations", [])], "images": len(gl.get("images", [])), "head_tris": (sum(len(p.vertices) - 2 for p in head.data.polygons) if head is not None else 0)}))
