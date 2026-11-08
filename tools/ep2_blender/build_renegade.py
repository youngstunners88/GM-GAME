"""RENEGADE, THE AUCTIONEER (founder brief PROMPT_AUCTION_HOUSE_RENEGADE_JACK_HAMMER_2026-11-08: locked Drive GLB
1n8FeWFni0M3PKX_itj3-gL2uHqD1CsF0 - gold Bitcoin-print frock coat, pipe, Tripo + Mixamo rig, no clips).

    blender -b --factory-startup -P tools/ep2_blender/build_renegade.py -- --src <drive.glb> [--out src/episode2/extras/people/renegade.glb]

Brought to Jack Hammer's streamed budget (same Tripo rig, ~16k tris, 1024 albedo + normal, the 12 MB metal-rough PNG dropped): the
extras pack had ~4.4 MB left on 2026-11-08. No clips are baked: Ep2AuctionHouse lends him Jack Hammer's and Logan's Mixamo clips at
runtime (identical mixamorig bone names). Prints @@{json}.
"""
import json
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = argv[argv.index("--src") + 1]
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/people/renegade.glb"
TRIS = 16000

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mesh = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.polygons))
for o in [o for o in bpy.data.objects if o.type == "MESH" and o != mesh]:
    bpy.data.objects.remove(o)                        # the rig's Icosphere bone shape
for pb in arm.pose.bones:
    pb.custom_shape = None
arm.name = "renegade_rig"
mesh.name = "renegade_body"
before = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
dec = mesh.modifiers.new("dec", "DECIMATE")
dec.ratio = TRIS / max(before, 1)
dec.use_collapse_triangulate = True
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.modifier_move_to_index(modifier="dec", index=0)       # before the armature modifier
bpy.ops.object.modifier_apply(modifier="dec")
after = sum(len(p.vertices) - 2 for p in mesh.data.polygons)

mat = mesh.data.materials[0]
mat.name = "renegade"
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
kept = []
for inp in ("Metallic", "Roughness"):
    for link in list(bsdf.inputs[inp].links):
        mat.node_tree.links.remove(link)              # the 12 MB metal-rough PNG: a flat cloth/skin finish instead
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.62
for node in list(mat.node_tree.nodes):
    if node.type == "TEX_IMAGE" and node.image is not None:
        if not node.outputs[0].links or "rough" in node.image.name.lower() or "metal" in node.image.name.lower():
            mat.node_tree.nodes.remove(node)
            continue
        if max(node.image.size) > 1024:
            node.image.scale(1024, 1024)
        kept.append(node.image.name)

os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=86, export_animations=False,
                          export_yup=True, export_extras=False, export_cameras=False, export_lights=False)
print("@@" + json.dumps({"tris_before": before, "tris": after, "images": kept, "bytes": os.path.getsize(OUT)}))
