"""Neutral studio renders of a GLB under a Poly Haven HDRI (skill ep2-polyhaven-assets). Headless only.

  blender -b --python tools/ep2_blender/studio_turntable.py -- <model.glb> <hdri.hdr> <out_prefix> [--views front,34,back] [--size 900x1100] [--strength 1.0]

Why: a dark face could be the albedo or the engine's forge lighting. Under one neutral softbox the lighting variable is gone,
so what is still dark IS the texture. Standard view transform (no Filmic/AgX) so colours are not re-graded.
"""
import bpy, sys, math
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
glb, hdri, prefix = argv[0], argv[1], argv[2]
def opt(name, default):
    return argv[argv.index(name) + 1] if name in argv else default
views = opt("--views", "front,34,back").split(",")
W, H = [int(x) for x in opt("--size", "900x1100").split("x")]
strength = float(opt("--strength", "1.0"))
ang = {"front": 0, "34": 40, "side": 90, "back": 180}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (mn + mx) / 2; size = max(mx - mn)
sc = bpy.context.scene
w = bpy.data.worlds.new("studio"); sc.world = w; w.use_nodes = True
nt = w.node_tree; nt.nodes.clear()
env = nt.nodes.new("ShaderNodeTexEnvironment"); env.image = bpy.data.images.load(hdri)
bg = nt.nodes.new("ShaderNodeBackground"); bg.inputs["Strength"].default_value = strength
out = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(env.outputs[0], bg.inputs[0]); nt.links.new(bg.outputs[0], out.inputs[0])
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 70
for v in views:
    a = math.radians(ang.get(v, float(v) if v.replace('.', '').isdigit() else 0))
    d = size * 2.6
    cam.location = (c.x + d * math.sin(a), c.y - d * math.cos(a), c.z)
    cam.rotation_euler = (math.radians(90), 0, a)
    sc.render.filepath = f"{prefix}_{v}.png"
    bpy.ops.render.render(write_still=True)
print("STUDIO_DONE", prefix, views)
