"""Close-up of the cylinder emblem on a revolver GLB (canon check: the Bitcoin B must read).
blender -b --python tools/ep2_blender/revolver_closeup.py -- <glb> <out.png> [side=-1|1]
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import revolver_lib as L  # noqa: E402

glb, out = sys.argv[sys.argv.index("--") + 1:][:2]
side = float(sys.argv[sys.argv.index("--") + 3]) if len(sys.argv) > sys.argv.index("--") + 3 else -1.0
obj = L.load_main_mesh(glb)
L.studio()
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 48
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 800, 600
cam_d = bpy.data.cameras.new("c")
cam_d.lens = 85
cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
tgt = Vector((-0.17, 0.0, 0.47))
cam.location = tgt + Vector((0.0, side * 0.62, 0.02))
cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("render done", out)
