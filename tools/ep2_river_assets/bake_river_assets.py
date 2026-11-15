import bpy,bmesh,sys,math,mathutils,json
kind,src,out=sys.argv[-3],sys.argv[-2],sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.import_scene.gltf(filepath=src)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
mesh=max((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices))
for o in [o for o in bpy.data.objects if o.type=='MESH' and o!=mesh]: bpy.data.objects.remove(o)
info={}
def shrink_tex(o,px):
  for m in o.data.materials:
    nt=m.node_tree;bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    for inp in list(bs.inputs):
      if inp.name!='Base Color':
        for l in list(inp.links): nt.links.remove(l)
    bs.inputs['Roughness'].default_value=1.0 if kind=='vulture' else .85
    bs.inputs['Metallic'].default_value=0.0
    for n in nt.nodes:
      if n.type=='TEX_IMAGE' and n.image and n.outputs[0].links and n.outputs[0].links[0].to_socket.name=='Base Color':
        n.image.scale(px,px)
def baked(name,posefn=None):
  for pb in arm.pose.bones: pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.rotation_quaternion=(1,0,0,0)
  if posefn: posefn()
  bpy.context.view_layer.update()
  dg=bpy.context.evaluated_depsgraph_get()
  me=bpy.data.meshes.new_from_object(mesh.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
  me.transform(mesh.matrix_world)
  o=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(o)
  return o
def weld(o):
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=bm.verts,dist=0.0004);bm.to_mesh(o.data);bm.free()
def decimate(o,tris):
  weld(o)
  n=sum(len(p.vertices)-2 for p in o.data.polygons)
  if n>tris:
    m=o.modifiers.new('d','DECIMATE');m.ratio=tris/n
    bpy.context.view_layer.objects.active=o
    with bpy.context.temp_override(object=o): bpy.ops.object.modifier_apply(modifier='d')
def drop_islands(o,maxz):
  bm=bmesh.new();bm.from_mesh(o.data);bm.verts.ensure_lookup_table()
  seen=set();kill=[]
  for v in bm.verts:
    if v.index in seen: continue
    st=[v];comp=[]
    seen.add(v.index)
    while st:
      x=st.pop();comp.append(x)
      for e in x.link_edges:
        w=e.other_vert(x)
        if w.index not in seen: seen.add(w.index);st.append(w)
    if max(c.co.z for c in comp)<maxz: kill+=comp
  bmesh.ops.delete(bm,geom=kill,context='VERTS');bm.to_mesh(o.data);bm.free()
  return len(kill)
def export(objs,path,q=82):
  for o in bpy.data.objects: o.select_set(o in objs)
  bpy.ops.export_scene.gltf(filepath=path,use_selection=True,export_format='GLB',export_image_format='JPEG',export_jpeg_quality=q,export_skins=False,export_animations=False,export_apply=True,export_materials='EXPORT')
if kind=='cowboy':
  shrink_tex(mesh,1024)
  def aim(): pass
  def rest():
    for b,deg in (('mixamorig:Spine2',30),('mixamorig:Neck',-30)):
      pb=arm.pose.bones[b];pb.rotation_mode='QUATERNION'
      R=mathutils.Quaternion((0,1,0),math.radians(deg))
      bm=(arm.matrix_world@pb.bone.matrix_local).to_quaternion()
      pb.rotation_quaternion=bm.inverted()@R@bm
      bpy.context.view_layer.update()
  d=baked('Draw',aim);i=baked('Idle',rest)
  for o in (d,i):
    o.data.transform(mathutils.Matrix.Rotation(-math.pi/2,4,'Z'))
    weld(o);k=drop_islands(o,0.09);info[o.name+'_raft_verts_removed']=k
    decimate(o,10000)
  for o in (d,i):
    ws=[v.co for v in o.data.vertices];top=max(v.z for v in ws)
    tip=min(ws,key=lambda v:v.y)   # muzzle: furthest forward (-Y = forward)
    info[o.name]={'height':top,'muzzle_frac':[tip.x/top,tip.z/top,-tip.y/top],'tris':sum(len(p.vertices)-2 for p in o.data.polygons),
      'min':[min(v[j] for v in ws) for j in range(3)],'max':[max(v[j] for v in ws) for j in range(3)]}
  arm.hide_set(True);mesh.hide_set(True)
  export([d,i],out)
elif kind=='vulture':
  shrink_tex(mesh,1024)
  o=baked('Vulture')
  o.data.transform(mathutils.Matrix.Rotation(math.pi,4,'Z'))   # head to +Y (Godot -Z)
  decimate(o,7000)
  ws=[v.co for v in o.data.vertices]
  span=max(v.x for v in ws)-min(v.x for v in ws);s=2.2/span
  o.data.transform(mathutils.Matrix.Scale(s,4))
  ws=[v.co for v in o.data.vertices];feet=min(v.z for v in ws)
  # feet at z=-0.27 (Ep2VultureMesh.PERCH_HEIGHT), body on the X centre line
  o.data.transform(mathutils.Matrix.Translation((0,0,-0.27-feet)))
  SH=0.085  # shoulder half-width: faces outboard of it are wing
  bm=bmesh.new();bm.from_mesh(o.data);bm.faces.ensure_lookup_table()
  parts={}
  for side,name in ((1,'WingR'),(-1,'WingL'),(0,'Body')):
    b2=bm.copy();b2.faces.ensure_lookup_table()
    kill=[f for f in b2.faces if not ((f.calc_center_median().x*side>SH) if side else abs(f.calc_center_median().x)<=SH)]
    bmesh.ops.delete(b2,geom=kill,context='FACES')
    me=bpy.data.meshes.new(name);b2.to_mesh(me);b2.free()
    for m in o.data.materials: me.materials.append(m)
    ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob);parts[name]=ob
  bm.free()
  # pivot = mean of the wing root band
  for name,side in (('WingL',-1),('WingR',1)):
    ob=parts[name];root=[v.co for v in ob.data.vertices if abs(abs(v.co.x)-SH)<0.06]
    p=sum(root,mathutils.Vector())/max(len(root),1);p.x=side*SH
    ob.data.transform(mathutils.Matrix.Translation(-p));ob.location=p
    info[name+'_pivot_blender']=list(p)
  ws=[v.co for v in o.data.vertices]
  info['bounds']=[[min(v[j] for v in ws) for j in range(3)],[max(v[j] for v in ws) for j in range(3)]]
  info['tris']={k:len(v.data.polygons) for k,v in parts.items()}
  arm.hide_set(True);mesh.hide_set(True)
  export(list(parts.values()),out)
elif kind=='cabin':
  shrink_tex(mesh,1024)
  o=baked('NeighborShell');decimate(o,9000)
  ws=[v.co for v in o.data.vertices]
  w=max(v.x for v in ws)-min(v.x for v in ws);s=5.2/w
  o.data.transform(mathutils.Matrix.Scale(s,4))
  ws=[v.co for v in o.data.vertices]
  c=mathutils.Vector(((max(v.x for v in ws)+min(v.x for v in ws))/2,(max(v.y for v in ws)+min(v.y for v in ws))/2,min(v.z for v in ws)))
  o.data.transform(mathutils.Matrix.Translation(-c))
  ws=[v.co for v in o.data.vertices]
  info['bounds']=[[min(v[j] for v in ws) for j in range(3)],[max(v[j] for v in ws) for j in range(3)]];info['tris']=len(o.data.polygons)
  arm.hide_set(True);mesh.hide_set(True)
  export([o],out)
print('BAKEINFO',json.dumps(info))
