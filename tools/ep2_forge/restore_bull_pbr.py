"""Blender 5.x: restore supplied Tripo maps onto the game's existing rig.

blender -b --python tools/ep2_forge/restore_bull_pbr.py -- SOURCE.glb OUTPUT.blend
Only textures are exported to the game; its rig, mesh and animation bytes stay intact.
"""
import bpy, sys, json, numpy as np
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
source, editable = map(Path, sys.argv[sys.argv.index('--') + 1:])
out = repo / 'src/episode2/assets/textures'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
original = max((o for o in bpy.data.objects if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
images = [n.image for n in original.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE']
color = next(i for i in images if 'BaseColor' in i.name)
orm = next(i for i in images if 'metallic' in i.name)
normal = next(i for i in images if 'Normal' in i.name)
# The generated map has a low metallic haze on fur/leather. Remove that
# baseline while retaining the high-valued buckles and engraved armor.
orm.colorspace_settings.name='Non-Color'
pixels=np.array(orm.pixels[:],dtype=np.float32).reshape(-1,4)
pixels[:,2]=np.clip((pixels[:,2]-.38)/.5,0,1)
pixels[:,1]=np.clip(pixels[:,1],.45,.95)
orm.pixels.foreach_set(pixels.ravel());orm.update()
for im, stem, size, fmt in [(color,'bull_albedo',2048,'JPEG'),(orm,'bull_metal_rough',1024,'PNG'),(normal,'bull_normal',1024,'PNG')]:
    im.scale(size,size)
    im.file_format = fmt
    im.filepath_raw = str(out / (stem + ('.jpg' if fmt == 'JPEG' else '.png')))
    im.save()
for o in list(bpy.data.objects): bpy.data.objects.remove(o,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(repo/'src/episode2/assets/inferno_bull_rigged.glb'))
mesh=bpy.data.objects['char1']
mat=mesh.data.materials[0]; mat.name='InfernoBull_RestoredPBR'
nodes=mat.node_tree.nodes; links=mat.node_tree.links
bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
tex=next(n for n in nodes if n.type=='TEX_IMAGE');tex.image=color
mr=nodes.new('ShaderNodeTexImage');mr.image=orm;orm.colorspace_settings.name='Non-Color'
sep=nodes.new('ShaderNodeSeparateColor');links.new(mr.outputs['Color'],sep.inputs[0])
links.new(sep.outputs['Green'],bs.inputs['Roughness'])
links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
nm=nodes.new('ShaderNodeTexImage');nm.image=normal;normal.colorspace_settings.name='Non-Color'
n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.65
links.new(nm.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],bs.inputs['Normal'])
for im in [color,orm,normal]: im.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(editable))
print('Restored 2K color, 1K roughness/metalness and tangent normals; runtime skeleton and mesh unchanged.')
