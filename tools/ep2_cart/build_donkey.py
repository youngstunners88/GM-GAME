"""Meshy donkey -> UV-preserving reduction, fitted quadruped skin and distance walk.
Blender 4.3+; -- SOURCE.glb OUTPUT.glb [SOURCE.blend]. Z up, nose -Y.
The walk is 1.5 m per cycle with 60% stance: each planted hoof moves
+0.9 m locally while the actor travels -0.9 m. No whole-body bob.
"""
import bpy,sys,math,json
from mathutils import Vector, Matrix
src,out,*blend=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH');mesh.name='DonkeyCoat'
bpy.context.view_layer.objects.active=mesh
for ob in bpy.context.selected_objects: ob.select_set(False)
mesh.select_set(True)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
# Source is centered at the origin. Normalize feet and measured ear height.
zmin=min(v.co.z for v in mesh.data.vertices);zmax=max(v.co.z for v in mesh.data.vertices);scale=1.7/(zmax-zmin)
for v in mesh.data.vertices: v.co=Vector((v.co.x*scale,v.co.y*scale,(v.co.z-zmin)*scale))
mod=mesh.modifiers.new('UVPreservingRuntimeReduction','DECIMATE');mod.ratio=20000/len(mesh.data.polygons);bpy.ops.object.modifier_apply(modifier=mod.name)
for im in bpy.data.images:
 if im.size[0]>1024: im.scale(1024,1024)
arm=bpy.data.armatures.new('DonkeySkeleton');rig=bpy.data.objects.new('DonkeyRig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,h,t,parent=None):
 b=arm.edit_bones.new(name);b.head=h;b.tail=t
 if parent: b.parent=arm.edit_bones[parent]
 return b
bone('root',(0,0,0),(0,0,.15));bone('body',(0,.3,1.05),(0,-.2,1.05),'root')
bone('neck',(0,-.20,1.02),(0,-.65,1.26),'body');bone('head',(0,-.65,1.26),(0,-1.05,.98),'neck')
bone('tail',(0,.90,1.06),(0,1.10,.60),'body')
legs={}
for side,x in [('L',.123),('R',-.123)]:
 for row,y,hipz,kneey in [('front',-.155,1.00,-.10),('hind',.825,1.04,.96)]:
  n=row+'_'+side;h=Vector((x,y,hipz));k=Vector((x,kneey,.54));a=Vector((x,y,.105));tip=Vector((x,y-.04,.025))
  bone(n+'_upper',h,k,'body');bone(n+'_lower',k,a,n+'_upper');bone(n+'_hoof',a,tip,n+'_lower')
  legs[n]=(h,k,a,tip)
bpy.ops.object.mode_set(mode='OBJECT')
# Region-constrained distance weights prevent cross-leg/bridle bleed.
for b in arm.bones: mesh.vertex_groups.new(name=b.name)
def segdist(p,a,b):
 d=b-a;return (p-(a+d*max(0,min(1,(p-a).dot(d)/d.length_squared)))).length
for v in mesh.data.vertices:
 p=v.co
 if p.z<.95 and p.y>-.39 and .05<abs(p.x)<.23 and (p.y<.10 or p.y>.65):
  n=('front' if p.y<.34 else 'hind')+('_L' if p.x>0 else '_R')
  h,k,a,t=legs[n];names=[n+'_upper',n+'_lower',n+'_hoof']
  if p.z<.16: weights=[0,0,1]
  else:
   ds=[segdist(p,h,k),segdist(p,k,a),segdist(p,a,t)];weights=[math.exp(-d*32) for d in ds]
  leg=max(0,min(1,(.95-p.z)/.4));sw=sum(weights);weights=[w/sw*leg for w in weights];names.append('body');weights.append(1-leg)
 elif p.y<-.43:
  # neck/head transition follows the generated bridle rigidly with the head
  w=max(0,min(1,(-p.y-.43)/.22));names=['neck','head'];weights=[1-w,w]
 elif p.y>.96: names=['tail'];weights=[1]
 else: names=['body'];weights=[1]
 total=sum(weights)
 for n,w in zip(names,weights):
  if w/total>.005: mesh.vertex_groups[n].add([v.index],w/total,'REPLACE')
mesh.parent=rig;mod=mesh.modifiers.new('QuadrupedSkin','ARMATURE');mod.object=rig
bpy.context.scene.render.fps=48;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=30
rig.animation_data_create();act=bpy.data.actions.new('donkey_walk');rig.animation_data.action=act;act.use_fake_user=True
# Place a bone using its rest orientation and a target segment (avoids roll guesses).
def pose_segment(name,h,t):
 pb=rig.pose.bones[name];rest=pb.bone;rot=(rest.tail_local-rest.head_local).rotation_difference(t-h)
 pb.matrix=Matrix.Translation(h) @ rot.to_matrix().to_4x4() @ rest.matrix_local.to_3x3().to_4x4()
 bpy.context.view_layer.update()
 pb.keyframe_insert('location');pb.keyframe_insert('rotation_quaternion');pb.keyframe_insert('scale')
phases={'hind_L':0,'front_L':.25,'hind_R':.5,'front_R':.75}
for f in range(0,31):
 bpy.context.scene.frame_set(f);u=f/30
 for n,(h,k,a,tip) in legs.items():
  p=(u+phases[n])%1
  if p<.6: dy=-.45+1.5*p;lift=0
  else:
   t=(p-.6)/.4;dy=.45*math.cos(math.pi*t);lift=.15*math.sin(math.pi*t)
  ankle=a+Vector((0,dy,lift));d=ankle-h;dist=d.length;l1=(k-h).length;l2=(a-k).length
  axis=d.normalized();mid=(l1*l1-l2*l2+dist*dist)/(2*dist);rad=math.sqrt(max(0,l1*l1-mid*mid))
  pole=Vector((0,1 if n.startswith('hind') else -1,0));perp=(pole-axis*pole.dot(axis)).normalized();joint=h+axis*mid+perp*rad
  pose_segment(n+'_upper',h,joint);pose_segment(n+'_lower',joint,ankle);pose_segment(n+'_hoof',ankle,ankle+(tip-a))
 for n in ['neck','head','tail']:
  pb=rig.pose.bones[n];pb.rotation_mode='QUATERNION'
  from mathutils import Quaternion
  pb.rotation_quaternion=Quaternion((1,0,0),.015*math.sin(u*math.tau+(1 if n=='tail' else 0)));pb.keyframe_insert('rotation_quaternion')
for fc in act.fcurves:
 for kp in fc.keyframe_points: kp.interpolation='LINEAR'
bpy.context.scene.frame_set(0)
if blend: bpy.ops.wm.save_as_mainfile(filepath=blend[0])
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_image_format='JPEG',export_jpeg_quality=88,export_animations=True,export_force_sampling=True,export_frame_range=True)
print('DONKEY_QA',json.dumps({'triangles':len(mesh.data.polygons),'bones':len(arm.bones),'stride_m':1.5,'duration_s':.625,'stance_fraction':.6,'ear_height_m':1.7}))
