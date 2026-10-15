"""Blender 4.3: authored Remington 1875, reference-driven gold scrollwork/walnut.
Run: blender -b --python tools/ep2_blender/build_remington.py
Output is new geometry; never edits the founder Winchester. All units metres.
"""
import bpy, bmesh, math, os, json, random
from mathutils import Vector, Matrix
from math import sin, cos, pi
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../..'))
OUT=os.path.join(ROOT,'src/episode2/assets/weapons/armory')
SOURCE=os.path.join(ROOT,'design/ep2/armory/blender')
os.makedirs(OUT,exist_ok=True); os.makedirs(SOURCE,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
# Authored coordinates match runtime: +Z muzzle, +Y up. Blender export maps back.
def P(p): return Vector((p[0],-p[2],p[1]))
def mat(name,c,metal=0,rough=.3):
 m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 return m
gold=mat('Polished antique gold',(0.76,.42,.085),.82,.24)
edge=mat('Raised gold edges',(.95,.68,.26),.88,.2)
cut=mat('Hand cut engraving',(.12,.052,.012),.2,.46)
steel=mat('Dark bore and sight notch',(.025,.019,.012),.65,.31)
wood=mat('Oiled figured walnut',(.16,.055,.017),0,.36)
# Portable PBR grain, generated source texture; no unbaked shader dependence.
img=bpy.data.images.new('Walnut grain',128,256)
px=[]
for v in range(256):
 for u in range(128):
  grain=(sin(u*.29+sin(v*.037)*2.7+sin(v*.009)*4)+sin(u*.83+v*.04)*.28)*.18
  light=.72+grain+sin(u*.05+v*.014)*.14
  px.extend((.25*light,.092*light,.033*light,1))
img.pixels=px; img.pack()
n=wood.node_tree.nodes.new('ShaderNodeTexImage'); n.image=img
wood.node_tree.links.new(n.outputs['Color'],wood.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
wood.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.25
meshes=[]
def finish(o,name,m,bevel=0):
 o.name=name; o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('Machined radiused edges','BEVEL'); mod.width=bevel; mod.segments=3
  bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
 for f in o.data.polygons: f.use_smooth=True
 meshes.append(o); return o
def cyl(name,r,length,pos,m,axis=(0,0,1),verts=48):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=length,location=P(pos)); o=bpy.context.object
 o.rotation_euler=P(axis).to_track_quat('Z','Y').to_euler()
 return finish(o,name,m,.0006)
def profile(name,points,thick,m,bevel=.002,x=0):
 # points are (muzzle-coordinate z, height y), extruded across width x.
 verts=[P((x+s*thick/2,y,z)) for s in [-1,1] for z,y in points]; N=len(points)
 faces=[tuple(range(N-1,-1,-1)),tuple(range(N,2*N))]
 faces += [(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)]
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update(); ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
 finish(ob,name,m,bevel)
 bpy.context.view_layer.objects.active=ob; ob.select_set(True)
 bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.uv.smart_project(); bpy.ops.object.mode_set(mode='OBJECT'); ob.select_set(False)
 return ob
def smooth_profile(pts):
 result=[]
 for i in range(len(pts)):
  a,b,c,d=[Vector(pts[k%len(pts)]) for k in [i-1,i,i+1,i+2]]
  for j in range(5):
   t=j/5; q=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t); result.append(tuple(q))
 return result
def curve(name,pts,r,m,closed=False):
 c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=1; c.bevel_depth=r; c.bevel_resolution=0
 s=c.splines.new('POLY'); s.points.add(len(pts)-1)
 for p,co in zip(s.points,pts): p.co=(*P(co),1)
 s.use_cyclic_u=closed
 o=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(o); o.data.materials.append(m)
 bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o; bpy.ops.object.convert(target='MESH'); meshes.append(o); return o
# Barrel with genuine bore: concentric ring front and dark recessed inner wall.
barrel=cyl('Barrel',.022,.295,(0,.038,.1955),gold)
# cut the bore all the way through barrel (no black disc stuck to the muzzle).
bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.0105,depth=.31,location=P((0,.038,.20)))
hole=bpy.context.object; hole.rotation_euler=P((0,0,1)).to_track_quat('Z','Y').to_euler()
bpy.context.view_layer.objects.active=barrel; mod=barrel.modifiers.new('True barrel bore','BOOLEAN'); mod.object=hole; mod.operation='DIFFERENCE'; bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(hole,do_unlink=True)
cyl('Bore shadow',.0104,.001,(0,.038,.29),steel)
for z in [.052,.058,.33,.336]: cyl('Barrel band',.0225,.0013,(0,.038,z),edge)
cyl('Ejector housing',.0065,.247,(.017,.002,.199),gold,verts=24)
cyl('Ejector button',.009,.005,(.017,.002,.319),edge,verts=24)
profile('Remington triangular web',[(.053,-.036),(.29,-.004),(.31,.003),(.053,.003)],.015,gold,.0015)
# Frame leaves the entire cylinder visible through the open side.
profile('Frame',[(-.094,-.033),(-.105,.018),(-.085,.071),(.058,.071),(.058,.057),(-.064,.057),(-.073,.042),(-.071,-.024),(.059,-.024),(.059,-.04),(-.07,-.048)],.041,gold,.002)
cy=cyl('Fluted cylinder',.047,.092,(0,.026,-.007),gold,verts=64)
# Six concave longitudinal flutes: material shadows come from actual concavity.
for i in range(6):
 a=i*pi/3
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=P((cos(a)*.048,.026+sin(a)*.048,-.003)))
 h=bpy.context.object; h.scale=(.010,.034,.010); # Blender Y = long barrel direction
 bpy.context.view_layer.objects.active=h; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.context.view_layer.objects.active=cy; mod=cy.modifiers.new('Cylinder flute','BOOLEAN'); mod.object=h; mod.operation='DIFFERENCE'; bpy.ops.object.modifier_apply(modifier=mod.name); bpy.data.objects.remove(h,do_unlink=True)
 cyl('Cartridge chamber',.009,.001,(cos(a)*.029,.026+sin(a)*.029,.0395),steel,verts=24)
 cyl('Cylinder rim',.002,.002,(cos(a)*.043,.026+sin(a)*.043,-.051),edge,verts=12)
# Swept curved walnut grip, matching reference's raked bird-head silhouette.
grip=[(-.080,-.029),(-.103,-.044),(-.121,-.066),(-.138,-.091),(-.151,-.121),(-.162,-.161),(-.159,-.169),(-.094,-.169),(-.087,-.163),(-.084,-.133),(-.078,-.104),(-.064,-.077),(-.062,-.059)]
profile('Gold grip frame',smooth_profile(grip),.042,gold,.003)
for side in [-1,1]:
 inset=[(-.085,-.044),(-.104,-.055),(-.12,-.078),(-.133,-.102),(-.145,-.133),(-.151,-.157),(-.1,-.158),(-.098,-.133),(-.091,-.102),(-.075,-.076),(-.074,-.06)]
 profile('Walnut grip panel',smooth_profile(inset),.005,wood,.0035,side*.022)
 # thin inlaid border around swept walnut side, gold lines catch edge lighting.
 curve('Grip inlay',[(side*.0252,y,z) for z,y in smooth_profile(inset)],.00045,edge,True)
# Trigger guard elongated oval, separately curved trigger.
curve('Trigger guard',[(.0,-.072+.028*cos(t),-.033+.039*sin(t)) for t in [2*pi*i/64 for i in range(64)]],.0025,gold,True)
curve('Curved trigger',[(0,-.04,-.025),(0,-.052,-.028),(0,-.067,-.025),(0,-.075,-.016)],.0021,edge)
profile('Cocked hammer',[(-.078,.047),(-.1,.051),(-.116,.07),(-.129,.074),(-.132,.069),(-.116,.057),(-.108,.036),(-.088,.022)],.012,gold,.001)
profile('Front sight',[(.304,.058),(.304,.068),(.299,.073),(.285,.073),(.277,.058)],.004,gold,.0006)
for x in [-.011,.011]: profile('Rear sight',[(.0,.071),(-.018,.071),(-.018,.078),(.0,.078)],.005,steel,.0003,x)
# Engraved screw heads, fine slots; same design visible on both sides.
for side in [-1,1]:
 for z,y in [(.055,-.032),(-.076,-.025),(-.092,.035)]:
  cyl('Slotted screw',.005,.001,(side*.0225,y,z),edge,axis=(1,0,0),verts=24)
  curve('Screw slot',[(side*.0232,y-.0025,z-.0025),(side*.0232,y+.0025,z+.0025)],.0005,cut)
# Floral acanthus scrollwork: thin dark incised-looking lines and bright companion edges.
def scroll(surface,cx,cy,r,flip=1):
 # surface maps 2D ornament coordinates onto curved gold or flat frame.
 pts=[]
 for i in range(25):
  t=i/24; a=flip*(.4+t*2*pi*1.6); rad=r*(1-.92*t)
  pts.append(surface(cx+cos(a)*rad,cy+sin(a)*rad))
 curve('Floral engraved scroll',pts,.00038,cut)
 for k in [0,1,2]:
  t=.13+k*.16; a=flip*(.4+t*2*pi*1.6); rad=r*(1-.92*t)
  z=cx+cos(a)*rad; y=cy+sin(a)*rad
  leaf=[]
  for j in range(11):
   u=j/10; leaf.append(surface(z+r*.5*sin(pi*u)*cos(a+.7),y+r*.5*sin(pi*u)*sin(a+.7)+r*.22*u))
  curve('Acanthus leaf',leaf,.00029,cut)
for side in [-1,1]:
 # Barrel ornaments wrap around the cylindrical surface; no floating flat decals.
 def barrel_surface(z,h):
  h=max(-.018,min(.018,h)); return (side*math.sqrt(.02205**2-h*h),.038+h,z)
 for j in range(9):
  scroll(barrel_surface,.075+j*.028,.003,.015,(-1)**j)
  scroll(barrel_surface,.086+j*.028,-.011,.0065,(-1)**(j+1))
 def frame_surface(z,y): return (side*.0212,y,z)
 for j in range(5): scroll(frame_surface,-.055+j*.022,.064,.007,(-1)**j)
 for z,y,r in [(-.088,.029,.012),(-.083,-.027,.01),(.042,-.032,.009)]: scroll(frame_surface,z,y,r)
 def web_surface(z,y): return (side*.0076,y,z)
 for j in range(5): scroll(web_surface,.075+j*.034,-.021+j*.004,.0055,(-1)**j)
 # Cylinder scrolls follow actual round surface at side without touching flutes.
 def cylinder_surface(z,h):
  return (side*math.sqrt(max(.0001,.04715**2-h*h)),.026+h,z)
 for j in range(3): scroll(cylinder_surface,-.036+j*.029,-.006,.011,(-1)**j)
# Bitcoin medallions: raised B + double strokes, chased outer milled/beaded edge.
font=bpy.data.fonts.load('/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf')
for side in [-1,1]:
 for z,y,r,x in [(-.12,-.117,.014,.026),(-.075,-.033,.012,.023)]:
  cyl('Bitcoin medallion',r,.0018,(side*x,y,z),edge,axis=(1,0,0),verts=48)
  for rr in [r*.84,r*.94]: curve('Coin milled rim',[(side*(x+.0012),y+cos(a)*rr,z+sin(a)*rr) for a in [2*pi*i/48 for i in range(48)]],.00025,cut,True)
  c=bpy.data.curves.new('Bitcoin B','FONT'); c.body='B'; c.font=font; c.align_x='CENTER'; c.align_y='CENTER'; c.size=r*1.45; c.extrude=.00015; c.bevel_depth=.00007
  ob=bpy.data.objects.new('Bitcoin double stroke B',c); bpy.context.collection.objects.link(ob); ob.location=P((side*(x+.0016),y,z)); ob.rotation_euler=Matrix(((0,0,side),(side,0,0),(0,1,0))).to_euler()
  bpy.context.view_layer.objects.active=ob; bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.ops.object.convert(target='MESH'); ob.data.materials.append(cut); meshes.append(ob)
  for dz in [-.002,.001]: curve('Bitcoin double bars',[(side*(x+.0018),y-r*.7,z+dz),(side*(x+.0018),y+r*.7,z+dz)],.00045,cut)
# Bake modifier-free, join by material to bound draw calls; named Barrel survives integration.
for m in [gold,edge,cut,steel,wood]:
 group=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==m]
 bpy.ops.object.select_all(action='DESELECT')
 for o in group: o.select_set(True)
 bpy.context.view_layer.objects.active=group[0]; bpy.ops.object.join(); group[0].name={'Polished antique gold':'Barrel','Raised gold edges':'GoldDetails','Hand cut engraving':'Engraving','Dark bore and sight notch':'BoreAndSights','Oiled figured walnut':'WalnutGrip'}[m.name]
 for o in [group[0]]:
  if m == cut:
   mod=o.modifiers.new('Ornament topology budget','DECIMATE'); mod.ratio=.45; bpy.ops.object.modifier_apply(modifier=mod.name)
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Only these final meshes belong to runtime.
for ob in [o for o in bpy.data.objects if o.type=='MESH']:
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges));bmesh.ops.triangulate(bm,faces=list(bm.faces));bad=[f for f in bm.faces if f.calc_area()<1e-13]
 if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update()
runtime=[o for o in bpy.data.objects if o.type=='MESH']
tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in runtime)
bpy.ops.object.select_all(action='DESELECT')
for o in runtime:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(SOURCE,'remington_1875_high.glb'),use_selection=True,export_format='GLB',export_yup=True,export_materials='EXPORT')
# Studio setup uses transparent world and neutral reflections. Saved source includes this camera.
s=bpy.context.scene; s.render.engine='CYCLES'; s.cycles.samples=40; s.cycles.use_denoising=False
s.world=bpy.data.worlds.new('Neutral studio'); s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.38,.38,1); s.world.node_tree.nodes['Background'].inputs[1].default_value=.20
s.render.film_transparent=True; s.view_settings.view_transform='AgX'; s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'
def area(name,pos,power,size,target):
 bpy.ops.object.light_add(type='AREA',location=P(pos)); o=bpy.context.object; o.name=name; o.data.energy=power; o.data.shape='RECTANGLE'; o.data.size=size; o.data.size_y=size*.3; o.rotation_euler=(P(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Long white reflection',(.4,.5,.2),14,.6,(0,0,.08)); area('Soft edge',(-.2,.3,-.2),9,.4,(0,0,.08)); area('Lower gold rim',(.3,-.25,.3),8,.35,(0,0,.08))
bpy.ops.object.camera_add(location=P((.85,.16,.10))); cam=bpy.context.object; cam.rotation_euler=(P((0,-.04,.09))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=.57; s.camera=cam
s.render.resolution_x=1000; s.render.resolution_y=600; s.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,'remington_1875_gold.blend'))
s.render.filepath=os.path.join(SOURCE,'remington_studio.png'); bpy.ops.render.render(write_still=True)
s.render.resolution_x=640; s.render.resolution_y=384; s.render.filepath=os.path.join(OUT,'remington_icon.png'); bpy.ops.render.render(write_still=True)
receipt={'source':'Founder isolated engraved gold Remington reference, conversation 2026-10-15','method':'Blender-authored mesh and floral curves; no paid provider','triangles':tris,'runtime_meshes':len(runtime),'length_m':.505,'textures':'128x256 authored walnut grain; metallic/roughness portable glTF','output':'src/episode2/assets/weapons/armory/remington_1875_gold.glb'}
with open(os.path.join(SOURCE,'asset-receipt.json'),'w') as f:json.dump(receipt,f,indent=2)
print('REMINGTON_BUILD_DONE',json.dumps(receipt))
