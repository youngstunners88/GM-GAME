"""Baked positive-transform left stave grip and right string-hook glove, same reference materials."""
import bpy,os,math
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
TEXDIR=os.path.join(ROOT,'design/ep2/armory/blender/hand-textures')
source=open(os.path.join(ROOT,'tools/blender/build_fp_hands.py')).read();exec(source[source.index('def B(p)'):source.index('# ------------------------------------------------------------------------------------------------------------------ main')].replace('tris=1800','tris=300'))
for side in ['left','right']:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 glove=material('Olive leather glove','olive_glove.png',rough=.88)
 leather=material('Saddle cuff','fp_leather.png',color=(.5,.55,.6,1),rough=.8)
 sleeve=material('Lil Blunt sleeve','fp_yarn.png',color=(.55,.62,.48,1),rough=.95)
 bs=sleeve.node_tree.nodes['Principled BSDF'];nt=sleeve.node_tree;old=bs.inputs['Base Color'].links[0].from_socket
 mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(.40,.46,.35,1);nt.links.new(old,mix.inputs[1]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
 sign=1 if side=='left' else -1
 # Local origin is independent stave grip / moving nock respectively.
 palm=(sign*.033,-.013,-.028)
 parts=[sphere(palm,.031,(.65,1.25,1.0))]
 for j in range(4):
  y=.027-j*.021
  pts=[(sign*.032,y,-.034),(sign*.040,y,-.006),(sign*.026,y,.024),(0,y,.032),(-sign*.015,y,.018)]
  if side=='right':pts=[(sign*.024,y,-.027),(sign*.030,y,.001),(sign*.014,y,.015),(0,y,.005)]
  for a,b in zip(pts,pts[1:]):parts.append(tube(a,b,.0084,.0073,seg=12))
  for p in pts:parts.append(sphere(p,.008))
 pts=[(sign*.026,-.027,-.04),(sign*.018,.017,-.037),(-sign*.005,.031,-.023),(-sign*.023,.013,-.011)]
 for a,b in zip(pts,pts[1:]):parts.append(tube(a,b,.010,.008,seg=12))
 for p in pts:parts.append(sphere(p,.009))
 hand=skin(join(parts,side.title()+'Glove'),voxel=.002,smooth=3,tris=2000);hand.data.materials.append(glove)
 wrist=Vector((sign*.032,-.065,-.04));back=Vector((sign*.45,-.45,-.8)).normalized()
 fa=forearm('Forearm',wrist,back,length=.75,r_wrist=.025,r_elbow=.038);fa.data.materials.append(sleeve)
 cuff=tube(wrist+back*.024,wrist+back*.125,.031,.035,seg=24);cuff.name='Leather cuff';cuff.data.materials.append(leather)
 for im in bpy.data.images:
  if im.source=='FILE':im.pack()
 bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'src/episode2/assets/weapons/armory/bow_'+side+'_hand.glb'),export_format='GLB')
print('BOW_HANDS_DONE')
