"""Bake ambient occlusion for a whole GLB into ONE atlas on its second UV set (founder 2026-10-25: "hyperreal ... prefer Runpod for
heavy mesh / bake work").

  blender -b --factory-startup -P tools/ep2_blender/bake_ao_atlas.py -- --in kit.glb --out kit.glb --ao kit_ao.jpg \
          [--px 2048] [--dist 0.12] [--samples 128] [--margin 8] [--gpu]

Why: the web build renders with Godot's Compatibility backend, which has no screen-space AO - so the creases of a CAD model (barrels in
their plates, ribs on a drum, a screw in a plate, a plank against its strap) get no contact shadow at all and read as clean plastic. A
baked AO atlas gives every crease its shadow for one texture read.

How: every mesh gets a FIRST UV set (kept as-is when present; a trivial cube projection otherwise - the engine's PBR dressing is
triplanar and ignores it) and a SECOND one, "AO", Smart-UV-projected with all meshes in one multi-object edit so their islands share a
single 0..1 atlas; Cycles bakes AO (GPU with --gpu: OptiX, else CUDA) into it with an edge margin; the GLB is re-exported with both UV
sets (glTF TEXCOORD_1 -> Godot UV2) and the AO image is written next to it. Node names, empties and materials round-trip unchanged.
Ep2Pbr.dress(root, {}, [], ao_tex) puts the atlas on `ao_texture` with `ao_on_uv2`. Prints @@{json}.
"""
import json
import math
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--in")
OUT = arg("--out", SRC)
AO = arg("--ao", os.path.splitext(OUT)[0] + "_ao.jpg")
PX = int(arg("--px", "2048"))
DIST = float(arg("--dist", "0.12"))
SAMPLES = int(arg("--samples", "128"))
MARGIN = int(arg("--margin", "8"))
GPU = "--gpu" in argv

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

# 1. UV sets: keep the first, add "AO" as the second on every mesh
for o in meshes:
    me = o.data
    if len(me.uv_layers) == 0:
        me.uv_layers.new(name="UVMap")
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=1.0)
        bpy.ops.object.mode_set(mode="OBJECT")
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[1])
    ao_layer = me.uv_layers.new(name="AO")
    me.uv_layers.active = ao_layer

# 2. one shared atlas: Smart UV Project with every mesh in the same edit session
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0025, area_weight=0.0, scale_to_bounds=False)
bpy.ops.uv.pack_islands(margin=0.003, rotate=True)
bpy.ops.object.mode_set(mode="OBJECT")

# 3. the bake target in every material (an unconnected, active image node), then Cycles AO
img = bpy.data.images.new("AO_Atlas", PX, PX, alpha=False, float_buffer=False)
img.generated_color = (1.0, 1.0, 1.0, 1.0)
mats = {m for o in meshes for m in o.data.materials if m is not None}
for m in mats:
    m.use_nodes = True
    nt = m.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.name = "AO_Bake_Target"
    node.image = img
    node.select = True
    nt.nodes.active = node

sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = False
device = "CPU"
if GPU:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for backend in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = backend
            prefs.get_devices()
            usable = [d for d in prefs.devices if d.type == backend]
            if usable:
                for d in prefs.devices:
                    d.use = d.type == backend
                sc.cycles.device = "GPU"
                device = backend
                break
        except TypeError:
            continue
sc.world = bpy.data.worlds.new("AO_World")
sc.world.light_settings.distance = DIST
bake = sc.render.bake
bake.margin = MARGIN
bake.margin_type = "EXTEND"
bake.use_selected_to_active = False
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.bake(type="AO", margin=MARGIN, use_clear=True)

os.makedirs(os.path.dirname(os.path.abspath(AO)), exist_ok=True)
img.filepath_raw = AO
img.file_format = "JPEG" if AO.lower().endswith((".jpg", ".jpeg")) else "PNG"
sc.render.image_settings.quality = 90
img.save()

# 4. the bake nodes go (they are not part of the look), the active UV goes back to the first set; export with both sets
for m in mats:
    n = m.node_tree.nodes.get("AO_Bake_Target")
    if n is not None:
        m.node_tree.nodes.remove(n)
for o in meshes:
    o.data.uv_layers.active = o.data.uv_layers[0]
for o in bpy.context.scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=False, export_yup=True, use_selection=False,
                          export_extras=False, export_cameras=False, export_lights=False, export_texcoords=True,
                          export_materials="EXPORT")
print("@@" + json.dumps({"ok": True, "device": device, "meshes": len(meshes), "px": PX, "samples": SAMPLES, "ao": AO,
                         "glb": OUT, "bytes": os.path.getsize(OUT)}))
