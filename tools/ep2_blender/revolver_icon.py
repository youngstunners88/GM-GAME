"""Render the weapon-selector icon (640x384, transparent) from the gun-only founder revolver.
blender -b --python tools/ep2_blender/revolver_icon.py -- <gun_only_hero.glb> <out.png>
Use a hero-quality gun-only GLB (metal): tools/ep2_blender/revolver_gun_only.py <hero.glb> <out.glb> 0.45 -
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import revolver_lib as L  # noqa: E402

glb, out = sys.argv[sys.argv.index("--") + 1:][:2]
obj = L.load_all(glb)
L.studio(world_strength=1.4)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 64
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 640, 384
sc.render.film_transparent = True
sc.render.image_settings.color_mode = "RGBA"
lo, hi = L.bbox(obj)
ctr = (lo + hi) / 2
cam_d = bpy.data.cameras.new("c")
cam_d.type = "ORTHO"
cam_d.ortho_scale = max(hi.x - lo.x, (hi.z - lo.z) * 640 / 384) * 1.12
cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
a, e = math.radians(-90 + 8), math.radians(6)           # right flank, muzzle left, a touch of three-quarter
cam.location = ctr + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * 3
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("render done", out)
