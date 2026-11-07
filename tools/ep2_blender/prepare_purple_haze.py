"""Prepare the accepted Tripo purple-haze generation for Godot 4.3.
blender -b -P tools/ep2_blender/prepare_purple_haze.py -- SOURCE.glb OUT_DIR
Same UVs, PBR maps and three rooted plants; no face thinning. Sizes are metres.
"""
import bpy, bmesh, os, sys
from mathutils.bvhtree import BVHTree
from mathutils import Vector, Matrix
src,out=sys.argv[sys.argv.index('--')+1:];os.makedirs(out,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=src)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and len(o.data.materials)]
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
if len(meshes)>1:bpy.ops.object.join()
o=bpy.context.object
for mat in o.data.materials:
 mat.name='PurpleHaze_Foliage'
 for n in mat.node_tree.nodes:
  if n.type=='TEX_IMAGE' and n.image:
   n.image.name='Haze_'+n.image.name
   cap=512 if "Normal" in n.image.name else (256 if "ORM" in n.image.name else 1024)
   if max(n.image.size)>cap:n.image.scale(cap,cap)
 # Foliage is dielectric. Preserve the supplied albedo, normals and roughness map.
 bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 for link in list(bs.inputs['Metallic'].links):mat.node_tree.links.remove(link)
 bs.inputs['Metallic'].default_value=0
lo=Vector(tuple(min(c[k] for c in o.bound_box) for k in range(3)));hi=Vector(tuple(max(c[k] for c in o.bound_box) for k in range(3)))
o.data.transform(Matrix.Translation(Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))))
print('HAZE_SOURCE','tris',sum(len(p.vertices)-2 for p in o.data.polygons),'bounds',list(hi-lo),flush=True)
# Resolve the provider's tiny coplanar overlaps at the smallest exported scale.
# Keep UV split vertices: welding the thin foliage would invalidate its normals and seams.
o.data.transform(Matrix.Scale(1.35/(hi.z-lo.z),4))
bm=bmesh.new();bm.from_mesh(o.data);bm.faces.ensure_lookup_table();bm.verts.ensure_lookup_table()
bvh=BVHTree.FromBMesh(bm);drop=set()
for f in bm.faces:
 a,b,c=[v.co for v in f.verts];n=f.normal;center=(a+b+c)/3
 for point in (center,center.lerp(a,.6),center.lerp(b,.6),center.lerp(c,.6)):
  for _,_,index,_ in bvh.find_nearest_range(point,.001):
   if index is None or index==f.index:continue
   other=bm.faces[index]
   if any(v in other.verts for v in f.verts):continue
   if abs(n.dot(other.normal))<.999:continue
   # The same point-in-triangle test used by the repository QA gate.
   aa,bb,cc=[v.co for v in other.verts];nn=other.normal
   q=point-nn*nn.dot(point-aa)
   if all(nn.dot((v-u).cross(q-u))>=-1e-8 for u,v in [(aa,bb),(bb,cc),(cc,aa)]):
    drop.add(bm.faces[max(f.index,index)])
print('HAZE_COPLANAR_FACES_REMOVED',len(drop),flush=True)
if drop:bmesh.ops.delete(bm,geom=list(drop),context='FACES_ONLY')
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(o.data);bm.free();o.data.update()
original=o.data.copy()
for name,height in [('purple_frost',1.35),('purple_bloom_grove',1.55),('purple_bloom_tree',3.7)]:
 o.data=original.copy();o.data.transform(Matrix.Scale(height/1.35,4));o.name=name
 bpy.ops.export_scene.gltf(filepath=os.path.join(out,name+'.glb'),export_format='GLB',use_selection=True,export_animations=False,export_image_format='JPEG',export_jpeg_quality=91)
 print('HAZE_ASSET',name,'tris',sum(len(p.vertices)-2 for p in o.data.polygons),'bounds',list(o.dimensions),flush=True)
