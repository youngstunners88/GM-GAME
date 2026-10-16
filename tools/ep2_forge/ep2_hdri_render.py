#!/usr/bin/env python3
"""Ep2 HDRI reference renders - photoreal lighting check for Bull/bear.
Uses PolyHaven studio HDRI + sun fill, Cycles low-sample + denoise.
Run in Blender (Rigify now enabled in userprefs, not needed here):
  blender --background --python tools/ep2_forge/ep2_hdri_render.py -- \
    --glb src/episode2/assets/inferno_bull_rigged.glb \
    --hdri /tmp/opencode/studio_small_09_1k.hdr --outdir /tmp/ep2hdri
Do NOT run while the Godot web export is going (both eat RAM).
"""
import bpy, math, sys, os

def args():
    a = sys.argv[sys.argv.index("--") + 1:]
    d = {"--hdri": "/tmp/opencode/studio_small_09_1k.hdr",
         "--outdir": "/tmp/ep2hdri", "--samples": "64"}
    for i in range(0, len(a) - 1, 2):
        d[a[i]] = a[i + 1]
    return d

d = args()
glb, hdri, outdir, samples = d["--glb"], d["--hdri"], d["--outdir"], int(d["--samples"])
os.makedirs(outdir, exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = samples
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1280, 720

world = scene.world
world.use_nodes = True
nodes, links = world.node_tree.nodes, world.node_tree.links
nodes.clear()
out = nodes.new("ShaderNodeOutputWorld")
bg = nodes.new("ShaderNodeBackground")
bg.inputs["Strength"].default_value = 1.0
env = nodes.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(hdri)
links.new(env.outputs["Color"], bg.inputs["Color"])
links.new(bg.outputs["Background"], out.inputs["Surface"])

bpy.ops.object.light_add(type="SUN", location=(5, -5, 10))
bpy.context.active_object.data.energy = 2.0

bpy.ops.import_scene.gltf(filepath=glb)
imported = bpy.context.selected_objects
root = imported[0] if imported else None

cams = {"front": ((0, -6, 2.0), (math.radians(82), 0, 0)),
        "side": ((6, 0, 2.0), (math.radians(82), 0, math.radians(90))),
        "threequarter": ((4.5, -4.5, 3.0), (math.radians(72), 0, math.radians(45)))}
for name, (loc, rot) in cams.items():
    bpy.ops.object.camera_add(location=loc, rotation=rot)
    scene.camera = bpy.context.active_object
    scene.render.filepath = os.path.join(outdir, os.path.basename(glb).replace(".glb", f"_{name}.png"))
    bpy.ops.render.render(write_still=True)
print("HDRI RENDER DONE:", outdir)
