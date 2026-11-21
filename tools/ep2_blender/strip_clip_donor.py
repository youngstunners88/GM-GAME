"""Strip a retargeted clip donor to its skeleton + clips (the MPFB folk's shared clip library, tools/ep2_motion/clips_stockpile.json).

    blender -b --factory-startup -P tools/ep2_blender/strip_clip_donor.py -- <clips_full.glb> <folk_clips.glb>

The donor is one MPFB figure with every clip baked on its armature (retarget_bvh.py --export-glb). Every MPFB figure shares that
skeleton, so the game copies these clips onto each one (Ep2TownFolk's own library) and the meshes are dead weight here: removed.
The armature keeps its name ("Armature") so the clips' track paths (Armature/Skeleton3D:<bone>) resolve on every figure.
"""
import os
import sys

import bpy

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
arm.name = "Armature"
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_optimize_animation_size=True, export_yup=True)
print("CLIPS", out, os.path.getsize(out), sorted(a.name for a in bpy.data.actions))
