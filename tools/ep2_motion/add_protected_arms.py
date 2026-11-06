"""Preserve supplied geometry/materials; add rest-fitted arms for protected draws.
Blender -b -P THIS -- --source INPUT --out OUTPUT --kind sheriff|bartender --blend SOURCE.blend
"""
import argparse, sys, os, json, math
import bpy
from mathutils import Vector
p=argparse.ArgumentParser()
for n in ['source','out','kind','blend']: p.add_argument('--'+n,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath(a.source))
body=max((o for o in bpy.context.scene.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices))
rig=next((o for o in bpy.context.scene.objects if o.type=='ARMATURE'),None)
if rig is None:
 arm=bpy.data.armatures.new('ProtectedRestRig');rig=bpy.data.objects.new('ProtectedRig',arm);bpy.context.collection.objects.link(rig)
 body.parent=rig;mod=body.modifiers.new('ProtectedSkin','ARMATURE');mod.object=rig
arm=rig.data
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(n,start,end,parent=None):
 b=arm.edit_bones.new(n);b.head=rig.matrix_world.inverted()@Vector(start);b.tail=rig.matrix_world.inverted()@Vector(end)
 if parent:b.parent=arm.edit_bones[parent]
if a.kind=='bartender':
 bone('Hips',(0,0,.49),(0,0,.58));bone('Spine',(0,0,.58),(0,0,.77),'Hips');bone('Head',(0,0,.77),(0,0,.95),'Spine')
 points=[(.12,0,.745),(.205,0,.625),(.29,0,.515),(.332,0,.463)];threshold=.115;falloff=.045
else:
 points=[(.255,0,1.43),(.45,0,1.18),(.60,0,.97),(.69,0,.84)];threshold=.245;falloff=.10
for side,sgn in [('Left',1),('Right',-1)]:
 pts=[(sgn*x,y,z) for x,y,z in points]
 for i,(suffix,par) in enumerate([('Arm','Spine'),('ForeArm',side+'Arm'),('Hand',side+'ForeArm')]):bone(side+suffix,pts[i],pts[i+1],par)
bpy.ops.object.mode_set(mode='OBJECT')
groups={b.name:body.vertex_groups.get(b.name) or body.vertex_groups.new(name=b.name) for b in arm.bones}
segments={n:(b.head_local.copy(), b.tail_local-b.head_local) for n,b in arm.bones.items() if n.endswith(('Arm','Hand'))}
def smooth(k): k=max(0,min(1,k));return k*k*(3-2*k)
for v in body.data.vertices:
 world=body.matrix_world@v.co;point=rig.matrix_world.inverted()@world
 if a.kind=='bartender':
  base='Head' if world.z>.78 else ('Spine' if world.z>.53 else 'Hips');groups[base].add([v.index],1,'REPLACE')
 factor=smooth((abs(world.x)-threshold)/falloff) if points[-1][2]-.06<world.z<points[0][2]+.08 else 0
 if factor<=0:continue
 side='Left' if world.x>0 else 'Right';dist=[]
 for n,(start,d) in segments.items():
  if not n.startswith(side):continue
  t=max(0,min(1,(point-start).dot(d)/d.length_squared));dist.append(((point-start-d*t).length,n))
 dist.sort()
 # Coat/apron edges beyond the silhouette threshold are still torso, not arms.
 # Restrict the arm blend to the rest-fitted limb envelope before normalizing.
 radius=.13 if a.kind=='sheriff' else .07
 factor*=smooth((radius-dist[0][0])/(radius*.35))
 if factor<=0:continue
 chosen=dist[:2];weights=[1/(d*d+.0001) for d,n in chosen];total=sum(weights)
 previous=[(g.group,g.weight) for g in v.groups]
 for idx,w in previous:body.vertex_groups[idx].add([v.index],w*(1-factor),'REPLACE')
 for (_,n),w in zip(chosen,weights):groups[n].add([v.index],factor*w/total,'REPLACE')
if rig.animation_data is None or rig.animation_data.action is None:
 rig.animation_data_create();rig.animation_data.action=bpy.data.actions.new('Idle')
 for b in rig.pose.bones:
  b.rotation_mode='QUATERNION'
  for f in [1,31]:b.keyframe_insert('rotation_quaternion',frame=f)
bpy.context.scene.frame_set(1)
os.makedirs(os.path.dirname(os.path.abspath(a.blend)),exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(a.blend))
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(a.out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_influence_nb=4,export_yup=True,export_apply=False,export_image_format='AUTO')
print('PROTECTED_RIG',json.dumps({'vertices':len(body.data.vertices),'bones':len(arm.bones),'kind':a.kind,'geometry_preserved':True}))
