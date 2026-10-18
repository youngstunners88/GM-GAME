"""Reference-driven olive leather FPS glove with finger skinning; headless Blender.
Coordinates: gun +Z forward, +Y up, metres. Preserve the existing revolver.
"""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
OUT=os.path.join(ROOT,'src/episode2/assets/weapons/armory/remington_grip_hand.glb')
TEXDIR=os.path.join(ROOT,'design/ep2/armory/blender/hand-textures')
os.makedirs(TEXDIR,exist_ok=True)
source=open(os.path.join(ROOT,'tools/blender/build_fp_hands.py')).read()
helpers=source[source.index('def B(p)'):source.index('# ------------------------------------------------------------------------------------------------------------------ main')]
helpers=helpers.replace('segments=20, ring_count=12','segments=10, ring_count=6')
helpers=helpers.replace('tris=1800','tris=300')
exec(helpers)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
glove=material('Worn olive glove', color=(.19,.23,.13,1),rough=.88)
# Bake-compatible grain and a subtle normal; no green yarn on the leather glove.
import random
rng=random.Random(1875)
img=bpy.data.images.new('Olive glove grain',width=256,height=256)
pixels=[]
for y in range(256):
 for x in range(256):
  v=rng.randrange(-9,10);pixels.extend(((72+v)/255,(79+v)/255,(49+v)/255,1))
img.pixels=pixels
path=os.path.join(TEXDIR,'olive_glove.png');img.filepath_raw=path;img.file_format='PNG';img.save()
tex=glove.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(path)
glove.node_tree.links.new(tex.outputs['Color'],glove.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
leather=material('Dark saddle leather','fp_leather.png',color=(.52,.56,.58,1),rough=.76)
seam=material('Glove seam',color=(.11,.13,.07,1),rough=.94)
brass=material('Aged brass cuff concho',color=(.38,.25,.10,1),rough=.48,metal=.65)
sleeve=material('Lil Blunt restrained green sleeve','fp_yarn.png',color=(.55,.62,.48,1),rough=.94)
bs=sleeve.node_tree.nodes['Principled BSDF'];nt=sleeve.node_tree
old=bs.inputs['Base Color'].links[0].from_socket
mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(.40,.46,.35,1)
nt.links.new(old,mix.inputs[1]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
# Closed right hand around the measured walnut grip. Thumb on the opposite side to the fingers.
paths={}
for j,name in enumerate(['middle','ring','little']):
 y=-.085-.023*j
 paths[name]=[(-.034,y,-.153),(-.041,y,-.105),(-.029,y,-.070),(-.005,y,-.063),(.021,y,-.078)]
paths['index']=[(-.034,-.069,-.112),(-.037,-.051,-.075),(-.025,-.052,-.045),(-.006,-.058,-.032)]
paths['thumb']=[(-.026,-.093,-.135),(-.016,-.063,-.133),(.009,-.048,-.119),(.026,-.051,-.098)]
parts=[sphere((-.025,-.108,-.154),.032,(.85,1.43,.75))]
for name,pts in paths.items():
 r=.010 if name=='thumb' else .0083 if name=='index' else .0092
 for i,(a,b) in enumerate(zip(pts,pts[1:])):parts.append(tube(a,b,r*(1-i*.07),r*(.94-i*.07),seg=14))
 for i,q in enumerate(pts):parts.append(sphere(q,r*(1-i*.065)))
hand=skin(join(parts,'ContactFittedHand'),voxel=.0019,smooth=3,tris=4200)
hand.data.materials.append(glove)
wrist=Vector((-.028,-.143,-.167));back=Vector((-.40,-.36,-.84)).normalized()
fa=forearm('Forearm',wrist,back,length=.65,r_wrist=.026,r_elbow=.040);fa.data.materials.append(sleeve)
# Leather cuff and narrow stitched piping, no oversized gold tube / horns.
a=wrist+back*.022;z=wrist+back*.125
cuff=tube(a,z,.031,.035,seg=32);cuff.name='Sewn bracer_cuff';cuff.data.materials.append(leather)
for f in cuff.data.polygons:f.use_smooth=True
side=Vector((1,0,0));side=(side-back*side.dot(back)).normalized();up=back.cross(side).normalized()
details=[]
for t in [.04,.94]:
 center=a+(z-a)*t
 for k in range(32):
  angle=k*math.tau/32
  q=center+(side*math.cos(angle)+up*math.sin(angle))*(.031+.004*t)
  details.append(sphere(q,.0009))
# Visible inset brass concho, leaf silhouette formed from small flattened ellipses.
center=a+(z-a)*.56+side*(-.035)
disc=sphere(center,.019,(.15,1,1));details.append(disc)
for angle in [-60,-35,0,35,60]:
 d=back*math.cos(math.radians(angle))+up*math.sin(math.radians(angle))
 ob=tube(center-side*.003,center-side*.003+d*.014,.0028,.0007,seg=8);details.append(ob)
orn=join(details,'Cuff stitches and leaf concho');orn.data.materials.append(brass)
bpy.context.view_layer.objects.active=orn
mod=orn.modifiers.new('Cuff detail budget','DECIMATE');mod.ratio=.18;bpy.ops.object.modifier_apply(modifier=mod.name)
# Independent finger bones. Geometry in the grip pose is the rest pose, not a fused gun mesh.
arm=bpy.data.armatures.new('Right glove finger rig');rig=bpy.data.objects.new('RightGloveRig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
palm=arm.edit_bones.new('palm');palm.head=B(wrist);palm.tail=B((-.032,-.079,-.12))
segments=[]
for name,pts in paths.items():
 parent=palm
 for i,(a,b) in enumerate(zip(pts,pts[1:])):
  bone=arm.edit_bones.new(name+str(i+1));bone.head=B(a);bone.tail=B(b);bone.parent=parent;parent=bone
  segments.append((bone.name,B(a),B(b)))
bpy.ops.object.mode_set(mode='OBJECT')
groups={name:hand.vertex_groups.new(name=name) for name in ['palm']+[s[0] for s in segments]}
def distance(p,a,b):
 d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-(a+d*t)).length
for v in hand.data.vertices:
 q=hand.matrix_world@v.co
 near=sorted([(distance(q,a,b),name) for name,a,b in segments])
 # Smooth transition into palm; no weights from adjacent digits across their gaps.
 d,name=near[0];w=max(0,min(1,(.024-d)/.012))
 groups[name].add([v.index],w,'REPLACE');groups['palm'].add([v.index],1-w,'REPLACE')
mod=hand.modifiers.new('Finger skin','ARMATURE');mod.object=rig
hand.parent=rig
# Trigger curl is a tiny fingertip squeeze; contact hand stays anchored through recoil.
rig.animation_data_create();action=bpy.data.actions.new('TriggerSqueeze');rig.animation_data.action=action
for f,k in [(1,0),(3,-.08),(7,0)]:
 for name in ['index2','index3']:
  b=rig.pose.bones[name];b.rotation_mode='XYZ';b.rotation_euler.x=k;b.keyframe_insert('rotation_euler',frame=f)
bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=7;bpy.context.scene.render.fps=30;bpy.context.scene.frame_set(1)
for img in bpy.data.images:
 if img.source=='FILE':img.pack()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'design/ep2/armory/blender/remington_grip_hand.blend'))
bpy.ops.export_scene.gltf(filepath=OUT,export_format='GLB',export_apply=False,export_animations=True,export_force_sampling=True)
print('REMINGTON_HAND_DONE',os.path.getsize(OUT))
