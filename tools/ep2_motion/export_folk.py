"""Export an animated folk .blend (prep_folk -> retarget_bvh) to a Godot GLB: the skinned body + rig + every clip as its own animation.
Skill: ep2-tripo-folk-to-game.

  blender -b rich_anim.blend --factory-startup -P tools/ep2_motion/export_folk.py -- --out src/episode2/extras/folk/rich_armory2.glb

Prints @@{json}: bytes, tris, bones, the animations found in the written file (parsed back from the GLB JSON chunk).
"""
import argparse
import json
import os
import struct
import sys

import bpy

ap = argparse.ArgumentParser()
ap.add_argument("--out", required=True)
a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:])
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == "ARMATURE")
body = next(o for o in sc.objects if o.type == "MESH")
for act in bpy.data.actions:
    act.use_fake_user = True
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = arm
arm.animation_data_create()
arm.animation_data.action = bpy.data.actions.get("Idle") or next(iter(bpy.data.actions))
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=a.out, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
    export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_step=1,
    export_optimize_animation_size=True, export_anim_single_armature=True, export_def_bones=False,
    export_skins=True, export_all_influences=False, export_morph=False, export_lights=False, export_cameras=False,
    export_image_format="AUTO", export_jpeg_quality=90)
raw = open(a.out, "rb").read()
jlen = struct.unpack_from("<I", raw, 12)[0]
gl = json.loads(raw[20:20 + jlen])
print("@@" + json.dumps({"ok": True, "out": a.out, "bytes": len(raw), "tris": sum(len(p.vertices) - 2 for p in body.data.polygons),
                         "bones": len(arm.data.bones), "skins": len(gl.get("skins", [])), "images": len(gl.get("images", [])),
                         "animations": [x.get("name") for x in gl.get("animations", [])]}))
