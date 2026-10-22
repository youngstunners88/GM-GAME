"""Textured Workbench shots of a prepared/animated folk .blend (headless-safe, no GPU needed). Skill: ep2-tripo-folk-to-game.

  blender -b in.blend --factory-startup -P tools/ep2_motion/folk_shot.py -- --out shots/ --views front side back three [--action Walk --frames 1 10 20]

Each view is a 720x960 PNG named <view>[_<action>_<frame>].png. Prints @@{json}.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
ap.add_argument("--views", nargs="+", default=["front", "side", "three"])
ap.add_argument("--action", default="")
ap.add_argument("--frames", nargs="*", type=int, default=[])
ap.add_argument("--res", nargs=2, type=int, default=[720, 960])
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
os.makedirs(a.out, exist_ok=True)

sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == "ARMATURE")
body = next(o for o in sc.objects if o.type == "MESH")
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "TEXTURE"
sh.show_shadows = True
sh.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = a.res
sc.render.film_transparent = False
sc.world = sc.world or bpy.data.worlds.new("W")
cam_data = bpy.data.cameras.new("ShotCam")
cam_data.lens = 50
cam = bpy.data.objects.new("ShotCam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
h = max((body.matrix_world @ Vector(c)).z for c in body.bound_box)
target = Vector((0.0, 0.0, h * 0.52))
dist = h * 1.9
dirs = {"front": (0, -1), "back": (0, 1), "side": (1, 0), "three": (0.7, -0.7), "left": (-1, 0)}
if a.action:
    act = bpy.data.actions.get(a.action)
    arm.animation_data_create()
    arm.animation_data.action = act
    if act.slots and not arm.animation_data.action_slot:
        arm.animation_data.action_slot = act.slots[0]
frames = a.frames or [sc.frame_current]
written = []
for f in frames:
    sc.frame_set(f)
    for v in a.views:
        dx, dy = dirs[v]
        cam.location = target + Vector((dx, dy, 0.08)).normalized() * dist
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        name = v if not a.action else "%s_%s_%03d" % (v, a.action, f)
        sc.render.filepath = os.path.join(a.out, name + ".png")
        bpy.ops.render.render(write_still=True)
        written.append(sc.render.filepath)
print("@@" + json.dumps({"ok": True, "written": written}))
