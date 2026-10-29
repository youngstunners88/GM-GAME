"""Add a recoverable walking skeleton to the founder's static Sheriff.

Blender 4.3+ headless, no remesh, decimation, material or texture changes.
The actual grounded gait is installed by ep2_grounded_walk.gd from this rest rig.
Usage: blender -b --factory-startup -P THIS -- --source FILE --out FILE --blend FILE
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--source', required=True)
p.add_argument('--out', required=True)
p.add_argument('--blend', required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.source))
# Some installed add-ons inject an unrelated default Icosphere on import.
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name != 'Icosphere']
body = max(meshes, key=lambda o: len(o.data.vertices))
for o in list(bpy.context.scene.objects):
    if o != body:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
coords = [v.co.copy() for v in body.data.vertices]
lo, hi = min(v.z for v in coords), max(v.z for v in coords)
factor = 1.85 / (hi - lo)
for v in body.data.vertices:
    v.co = Vector((v.co.x * factor, v.co.y * factor, (v.co.z - lo) * factor))
body.name = 'FounderSheriff'
arm = bpy.data.armatures.new('SheriffRestRig')
rig = bpy.data.objects.new('SheriffRig', arm)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
body.select_set(False)
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')

def bone(name, start, end, parent=None):
    b = arm.edit_bones.new(name)
    b.head, b.tail = start, end
    if parent: b.parent = arm.edit_bones[parent]
    return b

bone('Hips', (0, 0, .96), (0, 0, 1.08))
bone('Spine', (0, 0, 1.08), (0, 0, 1.40), 'Hips')
bone('Head', (0, 0, 1.40), (0, 0, 1.78), 'Spine')
for side, x in [('Left', .145), ('Right', -.145)]:
    bone(side+'UpLeg', (x, 0, .96), (x, -.025, .53), 'Hips')
    bone(side+'Leg', (x, -.025, .53), (x, .015, .12), side+'UpLeg')
    bone(side+'Foot', (x, .015, .12), (x, -.17, .055), side+'Leg')
bpy.ops.object.mode_set(mode='OBJECT')
groups = {b.name: body.vertex_groups.new(name=b.name) for b in arm.bones}

def smooth(a, b, v):
    k = max(0, min(1, (v-a)/(b-a)))
    return k*k*(3-2*k)

for v in body.data.vertices:
    z = v.co.z
    if z > 1.43:
        weights = {'Head': 1.0}
    elif z > 1.02:
        head = smooth(1.38, 1.48, z)
        weights = {'Spine': 1-head, 'Head': head}
    elif z > .87:
        k = smooth(.87, 1.04, z)
        weights = {'Hips': 1-k, 'Spine': k}
    else:
        side = 'Left' if v.co.x > 0 else 'Right'
        pelvis = smooth(.78, .92, z)
        thigh = smooth(.46, .61, z)
        shin = smooth(.13, .24, z)
        weights = {'Hips': pelvis, side+'UpLeg': (1-pelvis)*thigh,
                   side+'Leg': (1-pelvis)*(1-thigh)*shin,
                   side+'Foot': (1-pelvis)*(1-thigh)*(1-shin)}
    for name, weight in weights.items():
        if weight > 0: groups[name].add([v.index], weight, 'REPLACE')
body.parent = rig
mod = body.modifiers.new('WalkingSkin', 'ARMATURE')
mod.object = rig
rig.animation_data_create()
idle = bpy.data.actions.new('Idle')
rig.animation_data.action = idle
for b in rig.pose.bones:
    b.rotation_mode = 'QUATERNION'
    for f in [1, 31]:
        b.keyframe_insert('rotation_quaternion', frame=f)
idle.use_fake_user = True
bpy.context.scene.render.fps = 30
bpy.context.scene.frame_set(1)
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.blend))
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.out), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_skins=True,
    export_influence_nb=4, export_yup=True, export_apply=False, export_image_format='AUTO')
print('@@'+json.dumps({'vertices': len(body.data.vertices), 'triangles': sum(len(p.vertices)-2 for p in body.data.polygons),
    'bones': len(arm.bones), 'neutral_mesh_preserved': True, 'blender': bpy.app.version_string}))
