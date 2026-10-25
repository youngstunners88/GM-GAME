"""Author seated driving and greeting clips on the Meshy farmer's own skin.
Blender 4.3+: -- rigged.glb seated.glb [editable.blend]. No standing-wave substitution.
"""
import bpy,sys,math,json
from mathutils import Vector,Matrix,Quaternion
src,out,*blend=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=src)
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
# The provider file contains an unskinned unrelated Icosphere. Exclude it explicitly.
for o in list(bpy.context.scene.objects):
 if o.type=='MESH' and not o.vertex_groups: bpy.data.objects.remove(o,do_unlink=True)
rig.name='FarmerRig';rig.animation_data_clear()
# Shape the existing left fingers into a rein grip in bind space. No replacement
# hand or independent floating prop: these vertices keep their original skin.
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.vertex_groups)
left=rig.data.bones['LeftHand'];origin=left.head_local
axis=(left.tail_local-left.head_local).normalized();normal=Vector((0,0,1));normal=(normal-axis*normal.dot(axis)).normalized()
gi=body.vertex_groups['LeftHand'].index
for v in body.data.vertices:
    weight=next((g.weight for g in v.groups if g.group==gi),0)
    d=v.co-origin;t=d.dot(axis)
    if weight>.65 and t>6:
        a=min(2.6,(t-6)/3.2)
        v.co+=axis*(6+3.2*math.sin(a)-t)-normal*(3.2*(1-math.cos(a)))

# Work in the provider's centimetre bone space; retain its .01 object scale.
rest={b.name:b.matrix_local.copy() for b in rig.data.bones};heads={b.name:b.head_local.copy() for b in rig.data.bones}
rig.location.z=-.86322
# Handmade felt hat: fitted brim, crown and leather band, rigidly skinned to Head.
def mat(n,c):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*c,1);m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85;return m
felt=mat('FarmerHatFelt',(.13,.065,.028));band=mat('FarmerHatBand',(.045,.022,.009))
for name,rad,depth,z,sy,ma in [('HatBrim',28,1.6,170,.80,felt),('HatCrown',12.8,12,176.5,.85,felt),('HatBand',13,2.6,172.8,.85,band)]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=rad,depth=depth,location=(0,0,0));o=bpy.context.object;o.name=name
 # hat data shares the rig's centimetre space
 for v in o.data.vertices:
  v.co.y*=sy
  if name=='HatCrown' and v.co.z>0: v.co.x*=.84;v.co.y*=.88
  if name=='HatBrim':v.co.z+=2.2*(abs(v.co.x)/28)**3
  v.co.z+=z
 o.parent=rig;o.data.materials.append(ma);vg=o.vertex_groups.new(name='Head');vg.add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('HatSkin','ARMATURE');mod.object=rig
 bevel=o.modifiers.new('SoftFeltEdge','BEVEL');bevel.width=.8;bevel.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
# Matrix rotation is derived from each bone's actual rest direction, not Euler guesses.
def segment(n,child,h,t):
 pb=rig.pose.bones[n];q=(heads[child]-heads[n]).rotation_difference(t-h)
 pb.matrix=Matrix.Translation(h) @ q.to_matrix().to_4x4() @ rest[n].to_3x3().to_4x4();bpy.context.view_layer.update()
def two_bone(h,target,l1,l2,pole):
 d=target-h;axis=d.normalized();length=min(d.length,l1+l2-.01);a=(l1*l1-l2*l2+length*length)/(2*length);r=math.sqrt(max(0,l1*l1-a*a));v=(pole-axis*pole.dot(axis)).normalized();return h+axis*a+v*r
sc=bpy.context.scene;sc.render.fps=30;sc.frame_start=0;sc.frame_end=90
for clip in ['seated_drive','seated_greet']:
 act=bpy.data.actions.new(clip);act.use_fake_user=True;rig.animation_data_create();rig.animation_data.action=act
 for f in range(0,91):
  sc.frame_set(f);u=f/90
  for pb in rig.pose.bones: pb.matrix_basis=Matrix.Identity(4)
  bpy.context.view_layer.update()
  # Both thighs lie on the bench; bent knees put the boots on the footboard.
  for side in ['Left','Right']:
   h=heads[side+'UpLeg'];k=Vector((h.x,-34,86));ank=Vector((h.x,-39,46));toe=Vector((h.x,-51,38))
   segment(side+'UpLeg',side+'Leg',h,k);segment(side+'Leg',side+'Foot',k,ank);segment(side+'Foot',side+'ToeBase',ank,toe)
   pb=rig.pose.bones[side+'ToeBase'];pb.matrix=Matrix.Translation(toe)@rest[side+'ToeBase'].to_3x3().to_4x4();bpy.context.view_layer.update()
  # Left hand stays at the rein grip for every greeting frame.
  for side in ['Left','Right']:
   h=heads[side+'Arm'];el=heads[side+'ForeArm'];hand=heads[side+'Hand'];wave=clip=='seated_greet' and side=='Right'
   # Raised right forearm with a soft two-sweep greeting; seated pelvis and left grip unchanged.
   envelope=math.sin(math.pi*min(1,u/.22)/2) if u<.22 else (math.cos(math.pi*(u-.78)/.22/2) if u>.78 else 1)
   target=Vector((12,-36,116)) if side=='Left' else Vector((-18,-32,112))
   if wave: target=target.lerp(Vector((-48+7*math.sin(u*math.tau*2),-12,163)),envelope)
   joint=two_bone(h,target,(el-h).length,(hand-el).length,Vector((1 if side=='Left' else -1,0,-.25)))
   segment(side+'Arm',side+'ForeArm',h,joint);segment(side+'ForeArm',side+'Hand',joint,target)
   # Provider has no finger joints: retain the existing hand shape, orient palm naturally.
   pb=rig.pose.bones[side+'Hand'];turn=Matrix.Identity(4)
   if wave:
    axis=rest[side+'Hand'].to_3x3()@Vector((0,1,0));up=Vector((.12*math.sin(u*math.tau*2),0,1)).normalized();q=axis.rotation_difference(up)
    normal=Vector((0,0,1));normal=(normal-axis*normal.dot(axis)).normalized();palm=q@normal;wanted=Vector((0,-1,0));angle=math.atan2(up.dot(palm.cross(wanted)),palm.dot(wanted));q=Quaternion(up,angle)@q;turn=Quaternion().slerp(q,envelope).to_matrix().to_4x4()
   pb.matrix=Matrix.Translation(target)@turn@rest[side+'Hand'].to_3x3().to_4x4();bpy.context.view_layer.update()
  for pb in rig.pose.bones:
   pb.rotation_mode='QUATERNION';pb.keyframe_insert('location',frame=f);pb.keyframe_insert('rotation_quaternion',frame=f);pb.keyframe_insert('scale',frame=f)
 for fc in act.fcurves:
  for k in fc.keyframe_points:k.interpolation='LINEAR'
rig.animation_data.action=bpy.data.actions['seated_drive'];sc.frame_set(0)
if blend:bpy.ops.wm.save_as_mainfile(filepath=blend[0])
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_image_format='JPEG',export_jpeg_quality=88,export_animations=True,export_force_sampling=True,export_frame_range=True)
print('FARMER_QA',json.dumps({'bones':len(rig.data.bones),'clips':['seated_drive','seated_greet'],'left_grip_cm':[12,-36,116],'seat_origin_offset_m':-.86322}))
