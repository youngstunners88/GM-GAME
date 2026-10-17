"""Blender-authored reusable longbow and arrow, with a limb draw morph. Metres, +Z shot."""
import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
OUT=os.path.join(ROOT,'src/episode2/assets/weapons/armory')
def P(p):return Vector((p[0],-p[2],p[1]))
def mat(name,c,rough=.7,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;return m
def tube(name,a,b,ra,rb,m,n=12):
 a,b=P(a),P(b);d=b-a;bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=ra,radius2=rb,depth=d.length,location=(a+b)*.5);o=bpy.context.object;o.name=name;o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(d.normalized());o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 return o
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.preferences.filepaths.save_version=0
wood=mat('Oiled yew',(.26,.12,.042));wrap=mat('Hand stitched grip leather',(.09,.045,.021));horn=mat('Horn tip overlays',(.065,.045,.025));trim=mat('Waxed binding',(.44,.34,.18))
# One continuous oval stave, curved back at the tips. Morph bends the limbs under tension.
verts=[];faces=[]
N=48;K=12
for j in range(N+1):
 t=j/N;y=(t-.5)*1.5;u=abs(y)/.75;z=-.44*u*u
 width=.026*(1-.63*u)+.003;thick=.014*(1-.42*u)
 for k in range(K):
  a=k*math.tau/K;verts.append(P((math.cos(a)*width,y,z+math.sin(a)*thick)))
for j in range(N):
 for k in range(K):faces.append((j*K+k,j*K+(k+1)%K,(j+1)*K+(k+1)%K,(j+1)*K+k))
faces.extend([tuple(range(K-1,-1,-1)),tuple(N*K+k for k in range(K))])
me=bpy.data.meshes.new('Continuous yew stave');me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new('FlexibleLimbs',me);bpy.context.collection.objects.link(ob);ob.data.materials.append(wood)
for f in me.polygons:f.use_smooth=True
ob.shape_key_add(name='Basis');key=ob.shape_key_add(name='Draw')
for v in key.data:
 # Blender y is minus forward; tips pull back slightly while the handle remains fixed.
 u=abs(v.co.z)/.75;v.co.y+=.045*u*u
for i in range(14):
 y=-.10+i*.0145;tube('Leather grip wrap',(0,y,0),(0,y+.012,0),.030,.030,wrap,16)
for side in [-1,1]:
 for i in range(4):
  y=side*(.65+i*.019);z=-.44*(abs(y)/.75)**2;tube('Tip binding',(0,y-.004,z),(0,y+.004,z),.014,.014,trim)
 # Tip overlay follows the rest stave; runtime string endpoints follow draw deformation.
 y=side*.735;z=-.44*(abs(y)/.75)**2;tube('Horn nock',(0,y-.015,z),(0,y+.015,z),.010,.008,horn)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'design/ep2/armory/blender/bear_longbow.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'bear_longbow.glb'),export_format='GLB',export_morph=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
wood=mat('Arrow cedar',(.34,.21,.092));steel=mat('Forged arrowhead',(.21,.22,.23),.36,.72);feather=mat('Barred ochre feather',(.53,.38,.16));nock=mat('Bone nock',(.65,.57,.39))
tube('Cedar shaft',(0,0,.025),(0,0,.87),.0048,.0038,wood,12)
tube('Split bone nock',(0,0,0),(0,0,.035),.006,.005,nock)
# Broadhead is thin and pointed, not a round bullet cone.
vs=[P(p) for p in [(0,0,.95),(-.018,0,.87),(.018,0,.87),(0,-.003,.875),(0,.003,.875)]]
me=bpy.data.meshes.new('Forged broadhead');me.from_pydata(vs,[],[(0,1,3),(0,3,2),(0,2,4),(0,4,1),(1,4,2,3)]);me.update();o=bpy.data.objects.new('Broadhead',me);bpy.context.collection.objects.link(o);o.data.materials.append(steel)
for k in range(3):
 a=k*math.tau/3;dx,dy=math.cos(a)*.027,math.sin(a)*.027
 pts=[P(p) for p in [(0,0,.055),(dx,dy,.075),(dx,dy,.16),(0,0,.19)]]
 me=bpy.data.meshes.new('Feather');me.from_pydata(pts,[],[(0,1,2,3)]);me.update();o=bpy.data.objects.new('Fletching',me);bpy.context.collection.objects.link(o);o.data.materials.append(feather)
 for j in range(7):
  z=.08+j*.011;tube('Feather barb',(dx*.18,dy*.18,z+.013),(dx,dy,z),.0007,.0004,nock,5)
# Join static arrow pieces by material: the whole arrow is rigid in flight.
for m in [wood,steel,feather,nock]:
 objects=[o for o in bpy.data.objects if o.type=='MESH' and len(o.data.materials)>0 and o.data.materials[0]==m]
 if objects:
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
  objects[0].name=m.name
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'bear_arrow.glb'),export_format='GLB')
print('BOW_ARROW_DONE')
