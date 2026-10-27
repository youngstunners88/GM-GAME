"""Meshy textured skiff -> metre-scale open hull, independent oars and sockets.
Blender4.3+: -- SOURCE.glb OUTPUT.glb SOURCE.blend
Source +X bow -> Blender -Y / Godot +Z. Seats/oarlocks use measured rigid nodes.
"""
import bpy,bmesh,sys,math,json
from mathutils import Vector
src,out,blend=sys.argv[sys.argv.index('--')+1:];bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=src)
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH');mesh.name='ClinkerHull'
for o in list(bpy.context.scene.objects):
 if o!=mesh:bpy.data.objects.remove(o,do_unlink=True)
bpy.context.view_layer.objects.active=mesh;mesh.select_set(True);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
lo=Vector(tuple(min(v.co[i] for v in mesh.data.vertices) for i in range(3)));hi=Vector(tuple(max(v.co[i] for v in mesh.data.vertices) for i in range(3)));mid=(lo+hi)*.5;dims=hi-lo
for v in mesh.data.vertices:
 p=v.co-mid;v.co=Vector((p.y*1.25/dims.y,-p.x*3.4/dims.x,p.z*.60/dims.z))
# Weld exported positional duplicates while retaining per-corner texture UVs.
bm=bmesh.new();bm.from_mesh(mesh.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
bm.to_mesh(mesh.data);bm.free()
mod=mesh.modifiers.new('UV_preserving_runtime_hull','DECIMATE');mod.ratio=24000/len(mesh.data.polygons);bpy.ops.object.modifier_apply(modifier=mod.name)
# Decimation can leave zero-area wires: they are not renderable hull detail.
bm=bmesh.new();bm.from_mesh(mesh.data)
bmesh.ops.delete(bm,geom=[e for e in bm.edges if not e.link_faces],context='EDGES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
# Remove measured sub-pixel hull flakes identified by semantic QA: four
# non-manifold seam triangles (<3 mm²) and a covered 8 mm² coplanar sliver.
flakes=set()
for e in bm.edges:
 if len(e.link_faces)>2:
  for f in e.link_faces:
   if f.calc_area()<.000004:flakes.add(f)
for f in bm.faces:
 if f.calc_area()<.00001 and (f.calc_center_median()-Vector((.453084,-.234321,-.095074))).length<.002:
  flakes.add(f)
bmesh.ops.delete(bm,geom=list(flakes),context='FACES')
bmesh.ops.delete(bm,geom=[e for e in bm.edges if not e.link_faces],context='EDGES')
bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(mesh.data);bm.free()
for im in bpy.data.images:
 if max(im.size)>1024:im.scale(1024,1024);im.pack()
def mat(n,c,metal=0):
 m=bpy.data.materials.new(n);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.82;p.inputs['Metallic'].default_value=metal;return m
wood=mat('LakeCedar',(.19,.105,.043));brass=mat('LakeOarlock',(.29,.20,.07),.40);leather=mat('LakeOarGrip',(.11,.052,.018))
def box(n,loc,dims,ma):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=n;o.dimensions=dims;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma);mod=o.modifiers.new('WornEdges','BEVEL');mod.width=.012;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);return o
def cyl(n,a,b,r,ma):
 d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=d.length,location=(Vector(a)+Vector(b))/2);o=bpy.context.object;o.name=n;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(ma);return o
def empty(n,p):
 o=bpy.data.objects.new(n,None);o.location=p;bpy.context.collection.objects.link(o);return o
box('RowingThwart',(0,0,.18),(.98,.25,.055),wood);box('FootRest',(0,.56,-.14),(.68,.18,.07),wood)
empty('SeatContact',(0,0,.2075));empty('FloorContact',(0,.56,-.105));empty('SternMooring',(0,1.57,.29))
# The moving water cut is measured from this hull's actual waterline section,
# not a bounding rectangle that would punch holes outside its pointed bow.
for i in range(18):
    z=-1.7+i*.2
    near=[abs(v.co.x) for v in mesh.data.vertices if abs(-v.co.y-z)<.12 and abs(v.co.z+.03)<.04]
    half=max(near,default=0)
    half=max(0,half-.028)
    if i in [0,17]:half=0
    empty('WaterCut_%02d'%i,(half,-z,-.03))

for side,sign in [('L',-1),('R',1)]:
 pivot=empty('OarPivot_'+side,(sign*.64,.22,.34))
 # Oars lie along local X, with a fixed inner grip at x = -sign*0.48.
 a=Vector((-sign*.48,0,0));b=Vector((sign*1.55,0,0));shaft=cyl('OarShaft_'+side,a,b,.022,wood);shaft.parent=pivot
 grip=cyl('OarGrip_'+side,a-Vector((sign*.05,0,0)),a+Vector((sign*.10,0,0)),.026,leather);grip.parent=pivot
 blade=box('OarBlade_'+side,(sign*1.60,0,0),(.58,.16,.035),wood);blade.parent=pivot
 socket=empty('GripContact_'+side,(-sign*.48,0,0));socket.parent=pivot
 tip=empty('BladeContact_'+side,(sign*1.70,0,0));tip.parent=pivot
 bpy.ops.mesh.primitive_torus_add(major_radius=.038,minor_radius=.009,major_segments=20,minor_segments=8,location=pivot.location,rotation=(0,math.pi/2,0));bpy.context.object.name='Oarlock_'+side;bpy.context.object.data.materials.append(brass)
bpy.ops.wm.save_as_mainfile(filepath=blend,compress=True)
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_image_format='AUTO',export_animations=False)
print('SKIFF_QA',json.dumps({'hull_triangles':len(mesh.data.polygons),'length_m':3.4,'beam_m':1.25,'hull_height_m':.6,'seat_height_m':.2075,'oar_pivot_m':.64,'independent_oars':2}))
