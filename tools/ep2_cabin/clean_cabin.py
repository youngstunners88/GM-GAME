"""Correct measured near-coplanar Meshy slivers by a3mm normal offset, preserving UVs.
Runs on normalized editable derivative; never regenerates provider work.
"""
import bpy,bmesh,sys,json
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_point_tri
src,out=sys.argv[sys.argv.index('--')+1:];bpy.ops.wm.open_mainfile(filepath=src);o=bpy.data.objects['LoganCabinShell']
removed=0;repairs=0
for iteration in range(3):
 bm=bmesh.new();bm.from_mesh(o.data)
 bad=[f for f in bm.faces if f.calc_area()<1e-10];removed+=len(bad);bmesh.ops.delete(bm,geom=bad,context='FACES')
 bmesh.ops.delete(bm,geom=[e for e in bm.edges if not e.link_faces],context='EDGES');bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
 bm.faces.ensure_lookup_table();bm.verts.ensure_lookup_table();bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
 verts=[v.co.copy()for v in bm.verts];tris=[tuple(v.index for v in f.verts)for f in bm.faces];bv=BVHTree.FromPolygons(verts,tris);fix={}
 for f in bm.faces:
  a,b,c=[v.co for v in f.verts];n=f.normal;cen=(a+b+c)/3
  for p in (cen,cen.lerp(a,.6),cen.lerp(b,.6),cen.lerp(c,.6)):
   for co,n2,j,dist in bv.find_nearest_range(p,.001):
    if j is None or j==f.index or set(tris[j])&set(tris[f.index])or n.dot(n2)<.999:continue
    g=bm.faces[j];q=p-n2*n2.dot(p-g.verts[0].co)
    if intersect_point_tri(q,*[v.co for v in g.verts])is not None:
     small=f if f.calc_area()<g.calc_area()else g
     for v in small.verts:fix[v.index]=small.normal.copy()*.003
 for i,offset in fix.items():bm.verts[i].co+=offset
 repairs+=len(fix);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 if not fix:break
bpy.ops.wm.save_as_mainfile(filepath=src,compress=True);bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_image_format='AUTO',export_animations=False)
print('CABIN_CLEAN',json.dumps({'degenerate_faces_removed':removed,'vertices_offset':repairs}))
