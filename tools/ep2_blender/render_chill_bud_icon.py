"""Render the actual founder bud for Tabs. Usage: blender -b -P this.py -- IN.glb OUT.png"""
import bpy, sys
from mathutils import Vector
src,out=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=src)
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];coords=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box]
lo=Vector(tuple(min(c[k] for c in coords) for k in range(3)));hi=Vector(tuple(max(c[k] for c in coords) for k in range(3)));center=(lo+hi)*.5;extent=max(hi-lo)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False
s.world=bpy.data.worlds.new('Neutral studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.55,.55,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.7
for vec,power in [((1,-1,2),120),((-1,.2,1),65)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(vec)*extent);l=bpy.context.object;l.data.energy=power*extent**2;l.data.size=extent*1.5;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=center+Vector((1,-2,.45))*extent);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=extent*1.1;s.camera=cam
s.render.film_transparent=True;s.render.resolution_x=320;s.render.resolution_y=320;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.filepath=out;bpy.ops.render.render(write_still=True)
print('CHILL_BUD_ICON_DONE')
