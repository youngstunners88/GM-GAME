"""GPU bake: high-poly Tripo character/prop -> game low-poly with CLEAN 1K textures (Cycles on the Runpod GPU, skill ep2-cloud-gpu-runpod).
  blender -b --python bake_lowpoly.py -- in.glb out.glb FACES RES [pitch_l=55 pitch_r=55 swing_l=0 swing_r=0 pose=1]
Steps: import -> (rig applied / dropped) -> optional arm pose on the HIGH mesh (town_pose.deform_arms; `pose=1` turns it on) -> decimate a copy to FACES
-> fresh smart-UV unwrap -> bake base colour + object-space-free tangent normals from the high mesh into RES x RES maps -> one Principled material -> GLB (JPEG).
Decimation alone smears the original UVs into white seam streaks; a re-bake gives the detail back inside the same pack budget."""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from town_pose import deform_arms, select_only  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
src, out, faces, res = argv[0], argv[1], int(argv[2]), int(argv[3])
kw = {}
do_pose = False
for a in argv[4:]:
    k, v = a.split("=")
    if k == "pose":
        do_pose = v == "1"
    else:
        kw[k] = float(v)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src) if src.lower().endswith((".glb", ".gltf")) else bpy.ops.import_scene.fbx(filepath=src)
sc = bpy.context.scene
meshes = [o for o in sc.objects if o.type == "MESH" and not o.name.startswith("Icosphere")]
for o in list(sc.objects):
    if o.type == "MESH" and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
hi = meshes[0]
# FBX imports come with the texture nodes unlinked: wire any *basecolor* image into Base Color so the bake sees the colour
for mat in bpy.data.materials:
    if mat.use_nodes:
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        img = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and "basecolor" in n.image.name.lower()), None)
        if bsdf and img and not bsdf.inputs["Base Color"].is_linked:
            mat.node_tree.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
select_only(hi)
for m in list(hi.modifiers):
    if m.type == "ARMATURE":
        bpy.ops.object.modifier_apply(modifier=m.name)
hi.parent = None
for o in list(sc.objects):
    if o.type in ("ARMATURE", "EMPTY"):
        bpy.data.objects.remove(o, do_unlink=True)
hi.vertex_groups.clear()
if do_pose:
    deform_arms(hi, **kw)
print("HIGH faces", len(hi.data.polygons))

# --- low copy
lo = hi.copy()
lo.data = hi.data.copy()
lo.name = "lo"
sc.collection.objects.link(lo)
select_only(lo)
dm = lo.modifiers.new("dec", "DECIMATE")
dm.ratio = min(1.0, faces / len(lo.data.polygons))
bpy.ops.object.modifier_apply(modifier="dec")
lo.data.materials.clear()
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(80.0), island_margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")
print("LOW faces", len(lo.data.polygons))

# --- Cycles on the GPU
sc.render.engine = "CYCLES"
sc.cycles.samples = 24
prefs = bpy.context.preferences.addons["cycles"].preferences
for dev_type in ("OPTIX", "CUDA"):
    try:
        prefs.compute_device_type = dev_type
        prefs.get_devices()
        gpus = [d for d in prefs.devices if d.type == dev_type]
        if gpus:
            for d in prefs.devices:
                d.use = d.type == dev_type
            sc.cycles.device = "GPU"
            print("BAKE DEVICE", dev_type, [d.name for d in gpus])
            break
    except Exception as e:
        print("device", dev_type, "failed", e)
sc.render.bake.margin = 16
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = float(os.environ.get("BAKE_EXTRUDE", "0.035"))
sc.render.bake.max_ray_distance = float(os.environ.get("BAKE_RAY", "0.12"))


def new_image(name, color, noncolor=False):
    img = bpy.data.images.new(name, res, res, alpha=False)
    img.generated_color = color
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    return img


def target_material(img):
    m = bpy.data.materials.new("bake_" + img.name)
    m.use_nodes = True
    n = m.node_tree.nodes.new("ShaderNodeTexImage")
    n.image = img
    m.node_tree.nodes.active = n
    lo.data.materials.clear()
    lo.data.materials.append(m)


bpy.ops.object.select_all(action="DESELECT")
hi.select_set(True)
lo.select_set(True)
bpy.context.view_layer.objects.active = lo
col = new_image("base", (0.5, 0.5, 0.5, 1.0))
target_material(col)
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
nrm = new_image("normal", (0.5, 0.5, 1.0, 1.0), True)
target_material(nrm)
bpy.ops.object.bake(type="NORMAL")

# --- final game material
m = bpy.data.materials.new("town_mat")
m.use_nodes = True
nt = m.node_tree
nt.nodes.clear()
o_ = nt.nodes.new("ShaderNodeOutputMaterial")
bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
bs.inputs["Roughness"].default_value = 0.85
bs.inputs["Metallic"].default_value = 0.0
nt.links.new(bs.outputs["BSDF"], o_.inputs["Surface"])
tb = nt.nodes.new("ShaderNodeTexImage")
tb.image = col
nt.links.new(tb.outputs["Color"], bs.inputs["Base Color"])
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = nrm
nm = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
nt.links.new(nm.outputs["Normal"], bs.inputs["Normal"])
lo.data.materials.clear()
lo.data.materials.append(m)
lo.data.polygons.foreach_set("use_smooth", [True] * len(lo.data.polygons))
bpy.data.objects.remove(hi, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
lo.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=80, use_selection=True)
print("OUT", out, os.path.getsize(out))
