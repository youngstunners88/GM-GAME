"""Render the intact actual founder Winchester as a transparent weapon icon."""
import bpy, os, math
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT,'src/episode2/assets/weapons/winchester_1886_founder.glb'))
o=next(o for o in bpy.data.objects if o.type=='MESH')
# Keep the founder's integrated weapon/hands intact; render the same mesh used in play.
s=bpy.context.scene; s.render.engine='CYCLES'; s.cycles.samples=16; s.cycles.use_denoising=False
s.world=bpy.data.worlds.new('White neutral studio'); s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.65,.65,1); s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for loc,power,size in [((.7,-.3,1),60,1),((-.5,.4,.6),40,.7)]:
 bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object;l.data.energy=power;l.data.size=size;l.rotation_euler=(Vector((0,0,.15))-l.location).to_track_quat('-Z','Y').to_euler()
# Blender source +Y is down-barrel; a side view exposes the actual lever/receiver/stock.
coords=[o.matrix_world @ v.co for v in o.data.vertices]; lo=Vector(tuple(min(p[k] for p in coords) for k in range(3))); hi=Vector(tuple(max(p[k] for p in coords) for k in range(3))); center=(lo+hi)*.5
bpy.ops.object.camera_add(location=center+Vector((1.6,.04,.42)));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.42;s.camera=cam
s.render.film_transparent=True;s.render.resolution_x=640;s.render.resolution_y=320;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.filepath=os.path.join(ROOT,'src/episode2/assets/weapons/armory/winchester_icon.png');bpy.ops.render.render(write_still=True)
print('WINCHESTER_ICON_DONE')
