"""Render every action of an animated folk .blend at N frames per second (front view, small, timestamp in the name) to pick clip
windows. Skill: ep2-runpod-motion-lab. Runs well on the Runpod pod (Workbench, one Blender session for all clips).

  blender -b utah_scan.blend --factory-startup -P tools/ep2_motion/scan_sheets.py -- --out scan/ --per-sec 1 --res 180 240
"""
import argparse
import json
import os
import sys

import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--per-sec", type=float, default=1.0)
ap.add_argument("--res", nargs=2, type=int, default=[180, 240])
ap.add_argument("--fps", type=int, default=30)
ap.add_argument("--view", default="three")
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
os.makedirs(a.out, exist_ok=True)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == "ARMATURE")
body = next(o for o in sc.objects if o.type == "MESH")
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x, sc.render.resolution_y = a.res
cam = bpy.data.objects.new("ScanCam", bpy.data.cameras.new("ScanCam"))
sc.collection.objects.link(cam)
sc.camera = cam
h = max((body.matrix_world @ Vector(c)).z for c in body.bound_box)
target = Vector((0.0, 0.0, h * 0.5))
d = {"front": Vector((0, -1, 0.1)), "three": Vector((0.7, -0.7, 0.12)), "side": Vector((1, 0, 0.1))}[a.view].normalized()
cam.location = target + d * h * 2.4
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
arm.animation_data_create()
out = {}
for act in bpy.data.actions:
    arm.animation_data.action = act
    if act.slots and not arm.animation_data.action_slot:
        arm.animation_data.action_slot = act.slots[0]
    f0, f1 = [int(v) for v in act.frame_range]
    step = max(1, int(round(a.fps / a.per_sec)))
    names = []
    for f in range(f0, f1 + 1, step):
        sc.frame_set(f)
        p = os.path.join(a.out, "%s__%05.1fs.png" % (act.name, (f - f0) / a.fps))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        names.append(os.path.basename(p))
    out[act.name] = len(names)
print("@@" + json.dumps(out))
