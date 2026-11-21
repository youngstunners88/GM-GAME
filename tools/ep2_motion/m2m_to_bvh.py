"""Mesh2Motion CC0 stock clip (one GLB) -> CMU-named, Y-up BVH that tools/ep2_motion/retarget_bvh.py reads (skill ep2-mesh2motion-stock).
Decode meshopt first: gltfpack -i clip.glb -o clip_plain.glb -noq -kn -km -af 24
  blender -b --factory-startup -P tools/ep2_motion/m2m_to_bvh.py -- clip_plain.glb out.bvh
Source: github.com/Mesh2Motion/mesh2motion-app static/assets/human/animations (art CC0, LICENSE-CC0.MD).
"""
import bpy, sys
a=sys.argv[sys.argv.index("--")+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0])
arm=next(o for o in bpy.data.objects if o.type=="ARMATURE")
M={"pelvis":"Hips","spine_01":"LowerBack","spine_02":"Spine","spine_03":"Spine1","neck_01":"Neck","head":"Head"}
for s,X in (("l","Left"),("r","Right")):
    M.update({f"clavicle_{s}":f"{X}Shoulder",f"upperarm_{s}":f"{X}Arm",f"lowerarm_{s}":f"{X}ForeArm",f"hand_{s}":f"{X}Hand",f"thigh_{s}":f"{X}UpLeg",f"calf_{s}":f"{X}Leg",f"foot_{s}":f"{X}Foot",f"ball_{s}":f"{X}ToeBase"})
for b in arm.data.bones:
    if b.name in M: b.name=M[b.name]
act=bpy.data.actions[0]; f0,f1=map(int,act.frame_range)
bpy.context.scene.render.fps=24
bpy.context.view_layer.objects.active=arm; arm.select_set(True)
# BVH is Y-up (CMU); Blender's exporter writes armature space as-is (Z-up) and retarget_bvh's importer assumes Y-up, which laid the digger
# flat. Rotate the rig -90 deg about X and apply it, so armature-space up is +Y.
import math
arm.rotation_mode="XYZ"; arm.rotation_euler=(arm.rotation_euler.x - math.pi/2, 0, 0)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
print("@@",act.name,f0,f1, bpy.context.scene.render.fps)
bpy.ops.export_anim.bvh(filepath=a[1], frame_start=f0, frame_end=f1, root_transform_only=False)
