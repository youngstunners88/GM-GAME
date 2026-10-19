"""Review shots of the two-storey Armory GLB (Workbench, material colours, headless-safe). Skill: ep2-armory-two-story.

  blender -b --factory-startup -P tools/ep2_blender/armory2_shots.py -- --glb armory2.glb --out shots/ [--res 960 600]
Cameras are in the GAME frame of the building (front +z, door at the origin) at eye height 1.65 m.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

ap = argparse.ArgumentParser()
ap.add_argument("--glb", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--res", nargs=2, type=int, default=[960, 600])
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
os.makedirs(a.out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.glb)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_shadows = True
sh.show_cavity = True
sh.cavity_type = "BOTH"
sc.display.shadow_focus = 0.4
sc.render.resolution_x, sc.render.resolution_y = a.res
ground = bpy.data.meshes.new("g")
ground.from_pydata([(-40, -40, -0.01), (40, -40, -0.01), (40, 40, -0.01), (-40, 40, -0.01)], [], [(0, 1, 2, 3)])
g = bpy.data.objects.new("Ground", ground)
gm = bpy.data.materials.new("Sand")
gm.diffuse_color = (0.62, 0.48, 0.32, 1)
ground.materials.append(gm)
sc.collection.objects.link(g)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam


def G(x, y, z):
    return Vector((x, -z, y))


shots = {
    "street_three": ((11.0, 1.65, 19.0), (0.0, 4.6, -2.0), 42),
    "street_front": ((0.0, 1.65, 21.0), (0.0, 4.8, 0.0), 40),
    "door_in": ((0.0, 1.65, 0.8), (0.0, 2.2, -8.0), 70),
    "counter": ((0.4, 1.65, -2.6), (-0.9, 1.3, -6.5), 70),
    "gallery_up": ((-1.5, 1.65, -3.0), (0.5, 4.6, -9.5), 75),
    "from_gallery": ((-3.6, 5.45, -10.5), (1.0, 1.0, -2.0), 75),
}
for name, (eye, look, lens_fov) in shots.items():
    cam.location = G(*eye)
    cam.rotation_euler = (G(*look) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.angle = math.radians(lens_fov)
    sc.render.filepath = os.path.join(a.out, name + ".png")
    bpy.ops.render.render(write_still=True)
print("@@done")
