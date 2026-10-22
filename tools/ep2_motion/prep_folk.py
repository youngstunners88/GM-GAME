"""Prepare a founder Tripo character (rigged FBX or GLB) for the game: one armature + one skinned body, real height, feet on z=0,
centred, transforms applied, decimated keeping skin weights, <= 4 influences, textures shrunk. Skill: ep2-tripo-folk-to-game.

  blender -b --factory-startup -P tools/ep2_motion/prep_folk.py -- --src rich.fbx --height 1.80 --tris 16000 --tex 1024 --out rich_prep.blend

Prints one line `@@{json}` with the measured result (tris before/after, height, bones, images).
"""
import argparse
import json
import os
import sys

import bpy

ap = argparse.ArgumentParser()
ap.add_argument("--src", required=True)
ap.add_argument("--height", type=float, required=True, help="world height of the body mesh in metres (hat included)")
ap.add_argument("--tris", type=int, default=16000)
ap.add_argument("--tex", type=int, default=1024, help="base colour / normal size")
ap.add_argument("--aux-tex", type=int, default=512, help="metal/rough and other maps")
ap.add_argument("--out", required=True)
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])

bpy.ops.wm.read_factory_settings(use_empty=True)
if a.src.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=a.src)
else:
    bpy.ops.import_scene.gltf(filepath=a.src)

arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
body = max((o for o in meshes if o.vertex_groups), key=lambda o: len(o.data.polygons))
for o in list(bpy.data.objects):          # strays (Utah's 80-tri Icosphere), empties, lights, cameras
    if o not in (arm, body):
        bpy.data.objects.remove(o, do_unlink=True)
tris_before = sum(len(p.vertices) - 2 for p in body.data.polygons)


def sel(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def body_bbox():
    bpy.context.view_layer.update()
    pts = [body.matrix_world @ v.co for v in body.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


# 1. scale to height, then feet on z=0 and centred on x/y; apply so the armature and body both carry scale 1
lo, hi = body_bbox()
s = a.height / (hi[2] - lo[2])
arm.scale = [v * s for v in arm.scale]
if body.parent != arm:
    body.scale = [v * s for v in body.scale]
sel([arm, body], arm)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
lo, hi = body_bbox()
shift = (-(lo[0] + hi[0]) * 0.5, -(lo[1] + hi[1]) * 0.5, -lo[2])
arm.location = [arm.location[i] + shift[i] for i in range(3)]
if body.parent != arm:
    body.location = [body.location[i] + shift[i] for i in range(3)]
sel([arm, body], arm)
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

# 2. decimate first in the stack (Collapse interpolates UVs and vertex weights), then clean the weights for engines
ratio = min(1.0, a.tris / max(tris_before, 1))
if ratio < 1.0:
    m = body.modifiers.new("Decimate", "DECIMATE")
    m.decimate_type = "COLLAPSE"
    m.ratio = ratio
    m.use_collapse_triangulate = True
    with bpy.context.temp_override(object=body, active_object=body):
        bpy.ops.object.modifier_move_to_index(modifier=m.name, index=0)
        bpy.ops.object.modifier_apply(modifier=m.name)
sel([body], body)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
tris_after = sum(len(p.vertices) - 2 for p in body.data.polygons)

# 3. textures: shrink and re-save as JPEG next to the output (base colour + normal at --tex, the rest at --aux-tex)
outdir = os.path.dirname(os.path.abspath(a.out))
stem = os.path.splitext(os.path.basename(a.out))[0].replace("_prep", "")
images = []
for mat in body.data.materials:
    if not mat or not mat.node_tree:
        continue
    for n in mat.node_tree.nodes:
        if n.type != "TEX_IMAGE" or not n.image:
            continue
        img = n.image
        role = "albedo"
        for l in n.outputs[0].links:
            sock = l.to_socket.name.lower()
            if "normal" in l.to_node.type.lower() or "normal" in sock or l.to_node.type == "NORMAL_MAP":
                role = "normal"
            elif "base color" not in sock:
                role = "orm"
        if role == "albedo" and "normal" in img.name.lower():
            role = "normal"
        size = a.tex if role in ("albedo", "normal") else a.aux_tex
        _ = img.pixels[0]                      # force the (packed) pixels to load so .size is real
        if img.size[0] > size:
            img.scale(size, size)
        path = os.path.join(outdir, "%s_%s.jpg" % (stem, role))
        img.filepath_raw = path
        img.file_format = "JPEG"
        bpy.context.scene.render.image_settings.quality = 90
        img.save()
        if img.packed_file:                    # drop the packed 4K original so the exporter reads the shrunk file
            img.unpack(method="REMOVE")
        img.filepath = path
        img.reload()
        img.name = "%s_%s" % (stem, role)
        images.append({"name": img.name, "size": list(img.size), "role": role, "file": os.path.basename(path)})

arm.name = "%s_rig" % stem
body.name = "%s_body" % stem
bpy.ops.wm.save_as_mainfile(filepath=a.out)
bpy.ops.file.make_paths_relative()          # textures next to the .blend travel with it (Runpod, other checkouts)
bpy.ops.wm.save_mainfile()
lo, hi = body_bbox()
print("@@" + json.dumps({"ok": True, "tris_before": tris_before, "tris_after": tris_after, "height": round(hi[2] - lo[2], 3),
                         "foot_z": round(lo[2], 4), "bones": len(arm.data.bones), "images": images, "out": a.out}))
