"""Bake authored scrollwork onto a compact PBR game mesh, preserving editable high source.
Blender background only. Outputs new portable GLB, not a change to founder Winchester.
"""
import bpy,bmesh,os
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
OUT=os.path.join(ROOT,'src/episode2/assets/weapons/armory')
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'design/ep2/armory/blender/remington_1875_gold.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=1;s.cycles.use_denoising=False
high=[bpy.data.objects[n] for n in ['Barrel','GoldDetails','Engraving']]
lowparts=[]
for name in ['Barrel','GoldDetails']:
 source=bpy.data.objects[name];copy=source.copy();copy.data=source.data.copy();bpy.context.collection.objects.link(copy);bpy.context.view_layer.objects.active=copy
 dec=copy.modifiers.new('Silhouette-preserving game budget','DECIMATE');dec.ratio=.45;bpy.ops.object.modifier_apply(modifier=dec.name);lowparts.append(copy)
bpy.ops.object.select_all(action='DESELECT')
for o in lowparts:o.select_set(True)
bpy.context.view_layer.objects.active=lowparts[0];bpy.ops.object.join();low=lowparts[0];low.name='GameGold'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=.8,island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
mat=bpy.data.materials.new('Baked hand engraved gold');mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=.82;bs.inputs['Roughness'].default_value=.26
low.data.materials.clear();low.data.materials.append(mat)
for p in low.data.polygons:p.material_index=0
for kind in ['color','normal']:
 image=bpy.data.images.new('Remington '+kind,512,512,alpha=False);image.colorspace_settings.name='sRGB' if kind=='color' else 'Non-Color'
 tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image;mat.node_tree.nodes.active=tex
 bpy.ops.object.select_all(action='DESELECT')
 for o in high:o.select_set(True)
 low.select_set(True);bpy.context.view_layer.objects.active=low
 args=dict(use_selected_to_active=True,cage_extrusion=.003,max_ray_distance=.006,margin=5)
 if kind=='color':
  # Metallic surfaces have no diffuse energy: bake base colour through emission,
  # otherwise a diffuse pass darkens the gold and produces false black panels.
  restore=[]
  for m in {m for o in high for m in o.data.materials}:
   nt=m.node_tree;out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');old=out.inputs['Surface'].links[0].from_socket;src=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED');em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=src.inputs['Base Color'].default_value;nt.links.new(em.outputs[0],out.inputs['Surface']);restore.append((nt,out,old,em))
  bpy.ops.object.bake(type='EMIT',**args)
  for nt,out,old,em in restore:nt.links.new(old,out.inputs['Surface']);nt.nodes.remove(em)
 else:bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',**args)
 if kind=='normal':
  pix=list(image.pixels)
  for k in range(0,len(pix),4):
   if pix[k]+pix[k+1]+pix[k+2]<.15:pix[k:k+3]=[.5,.5,1.0]
  image.pixels=pix
 image.pack()
 if kind=='color':mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
 else:
  normal=mat.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.65;mat.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);mat.node_tree.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
# Wood, sights keep their original colour/roughness, with reduced hidden bevel tessellation.
rest=[bpy.data.objects[n] for n in ['BoreAndSights','WalnutGrip']]
for o in rest:
 bpy.context.view_layer.objects.active=o;dec=o.modifiers.new('Game budget','DECIMATE');dec.ratio=.40;bpy.ops.object.modifier_apply(modifier=dec.name)
bpy.ops.object.select_all(action='DESELECT')
for o in [low]+rest:o.select_set(True)
low.name='Barrel' # rename after original is removed below
for o in high:bpy.data.objects.remove(o,do_unlink=True)
low.name='Barrel'
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'remington_1875_gold.glb'),export_format='GLB',use_selection=True,export_apply=True)
print('REMINGTON_BAKE_DONE',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in [low]+rest),os.path.getsize(os.path.join(OUT,'remington_1875_gold.glb')))
