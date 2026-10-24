"""Render a head-and-shoulders bust of a game character GLB for a wanted poster (skill ep2-wanted-posters).

    blender -b --factory-startup -P tools/ep2_forge/render_poster_bust.py -- --glb <character.glb> --out <bust.png> [--yaw 0.35] [--samples 48] [--full]

The bust is the REAL model the game draws (Jack Hammer, the accomplice), so the poster matches the man in the street. Framing is
measured from the mesh: the top 26% of its height, centred on the head. The character faces glTF +Z (Blender -Y), so the camera
sits on -Y. Output is a plain colour PNG; tools/ep2_forge/paint_wanted_posters.py turns it into an engraving on the poster.
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


GLB = arg("--glb", "")
OUT = arg("--out", "/tmp/bust.png")
YAW = float(arg("--yaw", "0.35"))            # a three-quarter turn reads as a portrait, not a mugshot
SAMPLES = int(arg("--samples", "48"))
FULL = "--full" in argv                      # whole figure (the horse on the livery poster), not a bust

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
height = hi.z - lo.z
# the head: vertices in the top 14% of the body, their x/y centre (a T-pose's arms sit lower than the head)
head_pts = []
for o in meshes:
    mw = o.matrix_world
    for v in o.data.vertices:
        w = mw @ v.co
        if w.z > hi.z - height * 0.14:
            head_pts.append(w)
cx = sum(p.x for p in head_pts) / max(len(head_pts), 1)
cy = sum(p.y for p in head_pts) / max(len(head_pts), 1)
top = hi.z
frame_h = height * 0.26                        # head + shoulders (hat to collar bones)
centre = Vector((cx, cy, top - frame_h * 0.5))
if FULL:
    frame_h = max(height, (hi.x - lo.x) * 0.8, (hi.y - lo.y) * 0.8) * 1.05
    centre = (lo + hi) * 0.5

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.resolution_x = 640
scene.render.resolution_y = 800
scene.render.film_transparent = True
scene.view_settings.view_transform = "Standard"

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = frame_h * 1.02         # ortho scale spans the larger (vertical) side of a portrait frame
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
dist = 4.0
cam.location = centre + Vector((math.sin(YAW) * dist, -math.cos(YAW) * dist, 0.0))
cam.rotation_euler = (math.radians(90.0), 0.0, YAW)
scene.camera = cam


def light(name, kind, energy, loc, size=1.0):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    if kind == "AREA":
        ld.size = size
    lo_ = bpy.data.objects.new(name, ld)
    lo_.location = loc
    lo_.rotation_euler = (centre - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(lo_)


# hard key from the upper left (strong shadow side = engraving hatch), soft fill, a rim to cut the silhouette
light("Key", "AREA", 420.0, centre + Vector((-2.2, -2.4, 1.8)), 0.6)
light("Fill", "AREA", 60.0, centre + Vector((2.6, -2.0, 0.2)), 2.0)
light("Rim", "AREA", 160.0, centre + Vector((1.2, 2.6, 1.4)), 1.0)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[1].default_value = 0.15
scene.world = world

scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print('@@{"ok": true, "out": "%s", "height_m": %.3f, "head_pts": %d}' % (OUT, height, len(head_pts)))
