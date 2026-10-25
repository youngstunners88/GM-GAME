"""Independent Western cart: bevelled timber, iron hardware, axle-centred wheels.
Blender 4.3+: -- output.glb [source.blend]. Z up / front -Y.
"""
import bpy,sys,math
from mathutils import Vector
out,*blend=sys.argv[sys.argv.index('--')+1:];bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(n,c,metal=0,rough=.7):
 m=bpy.data.materials.new(n);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;return m
wood=mat('Planks',(.19,.09,.035));trim=mat('Trim',(.28,.15,.063));iron=mat('Iron',(.09,.065,.042),.3);leather=mat('Leather',(.08,.033,.013));brass=mat('Brass',(.38,.23,.065),.5)
def bevel(o,w=.012):
 mod=o.modifiers.new('RoundedWorkingEdges','BEVEL');mod.width=w;mod.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
def box(n,loc,dims,ma):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=n;o.dimensions=dims;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma);bevel(o);return o
def cyl(n,a,b,r,ma,verts=16):
 d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d.length,location=(Vector(a)+Vector(b))/2);o=bpy.context.object;o.name=n;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(ma);bevel(o,.006);return o
def torus(n,center,r,minor,ma):
 bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=10,location=center,major_radius=r,minor_radius=minor,rotation=(0,math.pi/2,0));o=bpy.context.object;o.name=n;o.data.materials.append(ma);return o
def join(obs,n,origin):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=obs[0];o.name=n;bpy.context.scene.cursor.location=origin;bpy.ops.object.origin_set(type='ORIGIN_CURSOR');return o
for i in range(8): box('BedPlank',(0,-.68+i*.195,.91),(1.30,.185,.08),wood)
for x in [-.64,.64]:
 for z in [1.04,1.19,1.34]:box('Sideboard',(x,.08,z),(.055,1.55,.125),wood)
 for y in [-.68,.85]:box('CornerStake',(x,y,1.14),(.085,.08,.6),trim)
 for y in [-.64,.78]:
  for z in [1.04,1.19,1.34]:cyl('Rivet',(x-.04,y,z),(x+.04,y,z),.016,iron,12)
for z in [1.04,1.19,1.34]:box('Tailboard',(0,.86,z),(1.29,.06,.125),wood)
for x in [-.46,.46]:box('Chassis',(x,.10,.78),(.12,1.8,.18),trim)
cyl('Axle',(-.88,0,.62),(.88,0,.62),.067,iron)
for x in [-.45,.45]:
 box('BenchLeg',(x,-.54,1.04),(.09,.12,.40),trim)
 box('Shaft',(x,-1.42,.94),(.07,2.15,.07),trim)
box('Bench',(0,-.53,1.26),(1.25,.40,.09),trim)
box('SeatLeather',(0,-.53,1.315),(1.06,.34,.035),leather)
box('Footboard',(0,-1.0,.80),(1.14,.33,.055),wood)
# Banded cargo chest behind the seat; distinct boards and forged latches.
box('Chest',(0,.39,1.15),(.76,.62,.42),wood)
for x in [-.28,.28]:box('ChestIronBand',(x,.39,1.15),(.035,.635,.435),iron)
box('ChestLatch',(0,.065,1.20),(.08,.018,.14),brass)
static=list(bpy.context.scene.objects);join(static,'CartBody',(0,0,0))
for side,x in [('L',.81),('R',-.81)]:
 obs=[]
 for dx in [-.045,.045]:obs.append(torus('Felloe',(x+dx,0,.62),.565,.038,trim))
 obs.append(torus('IronTyre',(x,0,.62),.605,.015,iron))
 obs.append(cyl('Hub',(x-.11,0,.62),(x+.11,0,.62),.12,trim,32))
 for j in range(12):
  a=j*math.tau/12;dy=math.sin(a);dz=math.cos(a)
  obs.append(cyl('Spoke',(x,dy*.10,.62+dz*.10),(x,dy*.56,.62+dz*.56),.025,trim))
 obs.append(cyl('AxleCap',(x-.12,0,.62),(x+.12,0,.62),.055,iron,24));join(obs,'Wheel_'+side,(x,0,.62))
if blend:bpy.ops.wm.save_as_mainfile(filepath=blend[0])
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB')
