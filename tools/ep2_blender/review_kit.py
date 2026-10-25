"""Side-view review renders of single props in a kit GLB (Workbench, studio light, cavity).
  blender -b --factory-startup -P review_kit.py -- --glb kit.glb --out dir Kit_Revolver:side Kit_Keg:34 ...
View codes: side (from game +x), back (from game -z), top, 34 (three-quarter)."""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB = argv[argv.index("--glb") + 1]
OUT = argv[argv.index("--out") + 1]
specs = [a for a in argv if ":" in a]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_shadows = False
sh.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 1200, 800
sc.world = bpy.data.worlds.new("W")
sc.world.color = (0.62, 0.64, 0.68)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
os.makedirs(OUT, exist_ok=True)
roots = {o.name: o for o in sc.objects if o.parent is None}
for spec in specs:
    name, view = spec.split(":")
    for n, r in roots.items():
        vis = n == name
        for o in [r] + list(r.children_recursive):
            o.hide_render = not vis
    r = roots[name]
    pts = []
    for o in r.children_recursive:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (lo + hi) * 0.5
    size = max((hi - lo).length, 0.05)
    d = {"side": Vector((1, 0, 0)), "back": Vector((0, 1, 0)), "top": Vector((0, 0, 1)), "34": Vector((1, -1, 0.7)).normalized(),
         "front": Vector((0, -1, 0)), "under": Vector((0.2, 0.3, -1)).normalized()}[view]
    cam.location = c + d * size * 3.0
    up = Vector((0, 1, 0)) if view == "top" else Vector((0, 0, 1))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = size * 1.1
    sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (name, view))
    bpy.ops.render.render(write_still=True)
print("@@done")
