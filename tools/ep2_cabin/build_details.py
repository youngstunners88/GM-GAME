"""Metre-scale Logan porch/prospecting kit. Blender4.3+: -- OUTPUT.glb SOURCE.blend.
Blender x/y/z -> Godot x/-z/y; front is Blender-Y / Godot+Z.
"""
import bpy,bmesh,math,random,sys,json
from mathutils import Vector
out,blend=sys.argv[sys.argv.index('--')+1:];bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(827)
def mat(n,c,metal=0):
 m=bpy.data.materials.new(n);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.78;p.inputs['Metallic'].default_value=metal;return m
wood=mat('CabinCedar',(.25,.14,.065));iron=mat('CabinIron',(.08,.09,.085),.5);gold=mat('CabinGold',(.72,.43,.09),.65);fabric=mat('CabinBurlap',(.38,.29,.16));leather=mat('CabinLeather',(.12,.055,.022));stone=mat('CabinStone',(.24,.25,.23))
keep=set()
def gp(p):return (p[0],-p[2],p[1])
def box(n,p,d,m,bevel=.012,retained=False):
 bpy.ops.mesh.primitive_cube_add(size=1,location=gp(p));o=bpy.context.object;o.name=n;o.dimensions=(d[0],d[2],d[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if bevel:
  mod=o.modifiers.new('WornEdges','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 if retained:keep.add(o.name)
 return o
def cylinder(n,a,b,r,m,sides=16):
 a,b=Vector(gp(a)),Vector(gp(b));d=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=r,depth=d.length,location=(a+b)*.5);o=bpy.context.object;o.name=n;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);o.data.materials.append(m);return o
def marker(n,p):
 o=bpy.data.objects.new(n,None);o.location=gp(p);bpy.context.collection.objects.link(o);return o
# Deck is a true supported floor; no solid slab hiding the underlying bank.
for i in range(22):
 x=-3.18+(i+.5)*6.36/22;box('PorchBoard',(x,.20,3.75),(6.36/22-.007,.08,2.7),wood,.008)
for x in [-2.95,0,2.95]:
 box('DeckStringer',(x,.10,3.75),(.15,.16,2.75),wood)
 for z in [2.5,4.95]:box('StoneFooting',(x,-.055,z),(.32,.22,.32),stone,.025)
# Open deck extension: the Meshy cabin already includes its own gabled entry.
# Brand posts and low side rails keep the roof silhouette and doorway clear.
for x in [-2.55,2.55]:
 box('PorchPost',(x,1.35,4.95),(.17,2.22,.17),wood)
 cylinder('PostIronCollar',(x,.26,4.95),(x,.34,4.95),.105,iron,8)
for x in [-3.0,3.0]:
 for z in [2.6,4.95]:box('RailPost',(x,.72,z),(.11,.96,.11),wood)
 for y in [.66,1.13]:box('PorchSideRail',(x,y,3.75),(.08,.09,2.45),wood)
# Gentle approach plank ramp: z5.1 height.24 -> z6.1 height0.
for i in range(9):
 z=5.1+(i+.5)/9;top=.24*(6.1-z)
 o=box('ApproachRamp',(0,top-.035,z),(1.7,.07,1/9-.006),wood,.004);o.rotation_euler.x=math.atan(.24)
marker('PorchSurface',(0,.24,4.0));marker('RampTop',(0,.24,5.1));marker('RampFoot',(0,0,6.1))
# Main sentence and brand mounts. Text/art binds separately and never comes from Meshy.
box('LPBoard',(4.4,1.35,3.6),(2.8,.95,.065),wood,.018)
marker('LPFace',(4.4,1.35,3.635))
for x in [-2.55,2.55]:box('BrandMount',(x,1.90,5.075),(1.05,1.07,.07),wood,.015)
marker('GMFace',(-2.55,2.00,5.111));marker('GMWordmark',(-2.55,1.445,5.111));marker('BTCFace',(2.55,1.90,5.136))
box('GoldmineWordmarkMount',(-2.55,1.445,5.075),(1.05,.30,.07),wood)
cylinder('BTCMedallion',(2.55,1.90,5.11),(2.55,1.90,5.135),.46,gold,48)
for x in [3.10,5.70]:
 box('LPSignPost',(x,1.0,3.6),(.12,2.0,.12),wood)
 for y in [.90,1.80]:cylinder('SignFastener',(x,y,3.63),(x,y,3.64),.014,iron,8)
# Upright notice board: bills at eye level from the courtyard, under the porch roof.
box('NoticeBacking',(-4.2,1.33,3.9),(1.82,1.35,.09),wood)
for x in [-5.07,-3.33]:box('NoticePost',(x,.85,3.91),(.09,1.7,.1),wood)
for y in [.64,2.02]:box('NoticeFrame',(-4.2,y,3.965),(1.95,.065,.075),wood,.008)
marker('PosterRH',(-4.63,1.35,3.947));marker('PosterJack',(-3.77,1.35,3.947))
for x in [-4.97,-4.29,-4.10,-3.44]:
 for y in [.92,1.79]:cylinder('PosterTack',(x,y,3.94),(x,y,3.952),.009,iron,8)
# Prospecting bench: retained tabletop allows independent geometry contact tests.
box('ProspectingTabletop',(1.95,1.045,3.8),(1.75,.09,.82),wood,.018,True)
for x in [1.24,2.66]:
 for z in [3.48,4.12]:box('BenchLeg',(x,.62,z),(.10,.76,.10),wood)
box('BenchBrace',(1.95,.47,3.83),(1.5,.09,.10),wood)
marker('TableSurface',(1.95,1.09,3.8))
def pan(n,p):
 prof=[(0,0),(.10,0),(.208,.052),(.225,.062),(.225,.075),(.211,.075),(.20,.059),(.095,.012),(0,.012)]
 verts=[];rings=[];faces=[];N=48
 for r,h in prof:
  ring=[]
  for j in range(1 if r==0 else N):
   a=j*math.tau/N;ring.append(len(verts));verts.append(gp((p[0]+r*math.cos(a),p[1]+h,p[2]+r*math.sin(a))))
  rings.append(ring)
 for a,b in zip(rings,rings[1:]):
  for j in range(N):
   if len(a)==1:faces.append((a[0],b[(j+1)%N],b[j]))
   elif len(b)==1:faces.append((a[j],a[(j+1)%N],b[0]))
   else:faces.append((a[j],a[(j+1)%N],b[(j+1)%N],b[j]))
 me=bpy.data.meshes.new(n);me.from_pydata(verts,[],faces);me.materials.append(iron);o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);keep.add(n)
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.01);bpy.ops.object.mode_set(mode='OBJECT')
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
 return o
pan('GoldPan0',(1.59,1.09,3.86));pan('GoldPan1',(2.25,1.09,3.75));marker('PanInterior',(1.59,1.102,3.86))
# Riffles sit just inside the upper slope, leaving the flat inner base clear.
for center in [(1.59,3.86),(2.25,3.75)]:
 for r,h in [(.16,.043),(.182,.056)]:
  bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=.004,major_segments=40,minor_segments=6,location=gp((center[0],1.09+h,center[1])));bpy.context.object.name='PanRiffle';bpy.context.object.data.materials.append(iron)
for i in range(7):
 dx=rng.uniform(-.055,.055);dz=rng.uniform(-.04,.04);p=(1.59+dx,1.102,3.86+dz)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=gp(p));o=bpy.context.object;o.name='Nugget%d'%i
 for v in o.data.vertices:v.co*=rng.uniform(.8,1.14)
 for v in o.data.vertices:v.co.x*=rng.uniform(.012,.022);v.co.y*=.012;v.co.z*=.010
 lo=min(v.co.z for v in o.data.vertices)
 for v in o.data.vertices:v.co.z-=lo
 o.data.materials.append(gold);keep.add(o.name);marker('NuggetBase%d'%i,p)
# Small ore sacks on bare pad; no currency pickups.
for i,p in enumerate([(-2.4,0,6.4),(-2.05,0,6.7)]):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,radius=1,location=gp((p[0],.21,p[2])));o=bpy.context.object;o.name='PayDirtSack';o.scale=(.24,.19,.24)
 for v in o.data.vertices:
  if v.co.z<-.85:v.co.z=-.85
  v.co.x*=1+.1*math.sin(v.co.z*9)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(fabric)
 cylinder('SackTie',(p[0],.39,p[2]),(p[0],.42,p[2]),.065,leather)
# Shovel and pick lean against the workbench side.
cylinder('ShovelHandle',(2.85,.25,3.4),(2.75,1.80,3.10),.023,wood)
o=box('ShovelBlade',(2.85,.34,3.4),(.25,.35,.025),iron,.055);o.rotation_euler.x=.20
cylinder('PickHandle',(1.1,.25,3.15),(1.04,1.45,3.1),.024,wood)
points=[(.73,1.32,3.10),(.85,1.43,3.10),(1.05,1.47,3.10),(1.25,1.43,3.10),(1.38,1.30,3.10)];radii=[.004,.028,.035,.028,.004]
for a,b,r1,r2 in zip(points,points[1:],radii,radii[1:]):
 va,vb=Vector(gp(a)),Vector(gp(b));d=vb-va;bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=r1,radius2=r2,depth=d.length,location=(va+vb)*.5);o=bpy.context.object;o.name='ForgedPickHead';o.rotation_euler=d.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);o.data.materials.append(iron)
# Open coffer with tangible BTC reserves; no financial quantity is asserted.
for x in [-2.76,-1.70]:box('CofferSide',(x,.52,3.18),(.07,.56,.68),wood)
for z in [2.86,3.5]:box('CofferEnd',(-2.23,.52,z),(1.12,.56,.065),wood)
box('CofferFloor',(-2.23,.275,3.18),(1.06,.07,.62),wood)
o=box('CofferLid',(-2.23,.99,2.82),(1.14,.065,.72),wood);o.rotation_euler.x=math.radians(-65)
for x in [-2.60,-1.86]:box('CofferStrap',(x,.54,3.535),(.04,.58,.015),iron,.004)
box('ReserveLabelPlate',(-2.23,.56,3.54),(.90,.46,.016),wood,.005)
marker('ReserveLabel',(-2.23,.56,3.548))
# Raised lined tray: coins are visible from the reachable porch, and supported.
for x in [-2.58,-1.88]:box('TraySupport',(x,.45,3.18),(.07,.28,.45),wood)
box('ReserveTray',(-2.23,.625,3.18),(.97,.07,.52),leather)
for i in range(8):
 stack=i//2;layer=i%2;x=-2.23+[-.28,-.10,.10,.29][stack];z=3.18+[-.10,.10,-.08,.11][stack];h=.66+layer*.012
 cylinder('ReserveCoin',(x,h,z),(x,h+.012,z),.06,gold,24);marker('CoinFace%d'%i,(x,h+.013,z))
# Closed ledger above reserve chest rim on a small fitted shelf.
box('LedgerShelf',(-2.23,.85,3.62),(1.15,.045,.28),wood)
box('ReserveLedger',(-2.23,.9,3.62),(.38,.055,.23),leather,.008);marker('LedgerFace',(-2.23,.93,3.62))
# Small exterior ore remnants resting on a low stone sorting slab.
box('OreSortingSlate',(-1.6,.04,6.3),(.43,.08,.32),stone,.018,True)
for j,offset in enumerate([(-.11,-.06),(.08,.04),(.02,-.08)]):
 p=(-1.6+offset[0],.08,6.3+offset[1]);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=gp(p));o=bpy.context.object;o.name='ExteriorNugget%d'%j
 for v in o.data.vertices:v.co*=rng.uniform(.8,1.13);v.co.x*=.027;v.co.y*=.017;v.co.z*=.013
 lo=min(v.co.z for v in o.data.vertices)
 for v in o.data.vertices:v.co.z-=lo
 o.data.materials.append(gold);keep.add(o.name)
# A small hanging oil lantern under the eave, paired with a local light in Godot.
glass=mat('CabinLantern',(.55,.24,.045));glass.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(.8,.30,.035,1);glass.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.5
cylinder('LanternGlass',(3.2,2.18,5.25),(3.2,2.46,5.25),.075,glass,12)
for y in [2.16,2.48]:cylinder('LanternCap',(3.2,y-.012,5.25),(3.2,y+.012,5.25),.10,iron,12)
for x in [-.075,.075]:
 for z in [-.075,.075]:cylinder('LanternBar',(3.2+x,2.17,5.25+z),(3.2+x,2.47,5.25+z),.006,iron,6)
cylinder('LanternBracket',(2.55,2.40,4.95),(3.2,2.55,5.25),.016,iron,8)
keep.add('LanternBracket')
cylinder('LanternChain',(3.2,2.49,5.25),(3.2,2.55,5.25),.009,iron,8)
keep.add('LanternChain')
marker('LanternLight',(3.2,2.33,5.25))
# Batch fixed detail by material; preserve pans/table/nuggets for independent QA.
for material in [wood,iron,gold,fabric,leather,stone,glass]:
 obs=[o for o in list(bpy.context.scene.objects)if o.type=='MESH' and o.name not in keep and o.data.materials and o.data.materials[0]==material]
 if not obs:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name='Fixed_'+material.name;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
# Remove only numerical zero-area bevel leftovers before import/LOD generation.
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.dissolve_degenerate(bm,dist=.000001,edges=list(bm.edges))
 bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.calc_area()<1e-12],context='FACES')
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
bpy.ops.wm.save_as_mainfile(filepath=blend,compress=True)
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_image_format='AUTO',export_animations=False)
print('DETAILS_QA',json.dumps({'meshes':sum(o.type=='MESH'for o in bpy.context.scene.objects),'polygons':sum(len(o.data.polygons)for o in bpy.context.scene.objects if o.type=='MESH'),'pan_diameter_m':.45,'table_top_m':1.09,'porch_top_m':.24,'nuggets':7,'BTC_coins':8}))
