"""Meshy cabin -> plain GLB, source +Z front,6.2m wide/4.8deep/4.6high.
Blender4.3+: -- SOURCE.glb OUTPUT.glb SOURCE.blend [YAW_DEGREES]
"""
import bpy,bmesh,sys,math,json
from mathutils import Vector,Matrix
args=sys.argv[sys.argv.index('--')+1:];src,out,blend=args[:3];yaw=float(args[3])if len(args)>3 else 0
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=src)
objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name='LoganCabinShell';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for other in list(bpy.context.scene.objects):
 if other!=o:bpy.data.objects.remove(other,do_unlink=True)
rot=Matrix.Rotation(math.radians(yaw),4,'Z')
for v in o.data.vertices:v.co=rot@v.co
lo=Vector(tuple(min(v.co[i]for v in o.data.vertices)for i in range(3)));hi=Vector(tuple(max(v.co[i]for v in o.data.vertices)for i in range(3)));dim=hi-lo
for v in o.data.vertices:v.co=Vector(((v.co.x-(lo.x+hi.x)*.5)*6.2/dim.x,(v.co.y-(lo.y+hi.y)*.5)*4.8/dim.y,(v.co.z-lo.z)*4.6/dim.z))
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(o.data);bm.free()
m=o.modifiers.new('CabinRuntime','DECIMATE');m.ratio=min(1,32000/len(o.data.polygons));bpy.ops.object.modifier_apply(modifier=m.name)
bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.delete(bm,geom=[e for e in bm.edges if not e.link_faces],context='EDGES');bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS');bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
for im in bpy.data.images:
 if max(im.size)>1024:im.scale(1024,1024);im.pack()
bpy.ops.wm.save_as_mainfile(filepath=blend,compress=True);bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_image_format='AUTO',export_animations=False)
print('CABIN_QA',json.dumps({'source_dimensions':list(dim),'runtime_dimensions':list(o.dimensions),'polygons':len(o.data.polygons),'front_yaw':yaw}))
