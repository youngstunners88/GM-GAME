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
AF.build_clips(arm_ob, "utah")

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
                         "animations": [x.get("name") for x in gl.get("animations", [])], "images": len(gl.get("images", []))}))
