"""Shrink the rigged AssetFurnace horse for the Episode 2 town (pack headroom is ~2.5 MB): decimate to ~7k tris,
1024 textures, keep the 19-bone skin and the three clips (horse_walk, horse_graze, horse_stand).
blender -b --python tools/ep2_blender/horse_game.py -- <horse_rigged.glb> <out.glb> [tris=7000] [tex=1024]
"""
import os
import sys

import bpy

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
TRIS = int(a[2]) if len(a) > 2 else 7000
TEX = int(a[3]) if len(a) > 3 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 24
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = max([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: len(o.data.polygons))
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
print("before tris", sum(len(p.vertices) - 2 for p in mesh.data.polygons), "actions", [x.name for x in bpy.data.actions])
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    nt = mat.node_tree
    bs = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
    for lk in list(nt.links):
        if lk.to_socket.name in ("Normal", "Metallic", "Roughness"):
            nt.links.remove(lk)
    bs.inputs["Metallic"].default_value = 0.0
    bs.inputs["Roughness"].default_value = 0.72
    for n in [n for n in nt.nodes if n.type in ("NORMAL_MAP", "SEPARATE_COLOR", "SEPARATE_RGB")]:
        nt.nodes.remove(n)
    for n in [n for n in nt.nodes if n.type == "TEX_IMAGE" and not any(l.from_node == n for l in nt.links)]:
        nt.nodes.remove(n)             # detail MR / normal textures no longer used: do not ship them
for im in list(bpy.data.images):
    if im.users == 0:
        bpy.data.images.remove(im)
for im in bpy.data.images:
    if im.size[0] > TEX:
        im.scale(TEX, TEX)
bpy.context.view_layer.objects.active = mesh
mod = mesh.modifiers.new("dec", "DECIMATE")
mod.ratio = min(1.0, TRIS / max(sum(len(p.vertices) - 2 for p in mesh.data.polygons), 1))
bpy.ops.object.modifier_apply(modifier="dec") if not any(m.type == "ARMATURE" for m in mesh.modifiers[:0]) else None
print("after tris", sum(len(p.vertices) - 2 for p in mesh.data.polygons), "mods", [m.type for m in mesh.modifiers])
for o in [o for o in bpy.data.objects if o.type == "MESH" and o is not mesh]:
    bpy.data.objects.remove(o, do_unlink=True)
for x in bpy.data.actions:
    x.use_fake_user = True
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=72,
                          export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
                          export_force_sampling=True, export_optimize_animation_size=True)
print("export done", OUT, os.path.getsize(OUT))
