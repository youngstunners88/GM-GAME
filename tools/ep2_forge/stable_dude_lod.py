import bpy,sys,os
src,out=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=src)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');mesh=max((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:len(o.data.polygons))
arm.data.pose_position='REST'
mod=mesh.modifiers.new('StableLOD','DECIMATE');mod.ratio=.79;mod.use_collapse_triangulate=True
bpy.context.view_layer.objects.active=mesh;mesh.select_set(True)
mesh.modifiers.move(mesh.modifiers.find(mod.name),0);bpy.ops.object.modifier_apply(modifier=mod.name)
arm.data.pose_position='POSE'
for a in bpy.data.actions:a.use_fake_user=True
print('STABLE_DUDE_LOD',sum(len(p.vertices)-2 for p in mesh.data.polygons),'bones',len(arm.data.bones),'actions',[a.name for a in bpy.data.actions])
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_force_sampling=True,export_optimize_animation_size=True,export_image_format='JPEG',export_jpeg_quality=80)
