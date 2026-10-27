"""Lake-specific forest kit. Blender4.3+; -- OUTPUT.glb SOURCE.blend.
Metre-scale crooked trunks, woody boughs and small crossed fir sprays instead
of scaled giant trunks. Existing founder forest texture atlas is bound in Godot.
"""
import bpy,math,random,sys,json
from mathutils import Vector
out,blend=sys.argv[sys.argv.index('--')+1:];bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(8827)
def mat(n,c):
 m=bpy.data.materials.new(n);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.9;return m
bark=mat('LakeBark',(.22,.15,.08));needle=mat('LakeNeedles',(.08,.17,.07));green=mat('RushBlade',(.14,.22,.065));seed=mat('RushSeed',(.16,.085,.028))
class Mesh:
 def __init__(self):self.v=[];self.f=[];self.uv=[]
 def face(self,pts,uv):
  b=len(self.v);self.v.extend(pts);self.f.append(tuple(range(b,b+len(pts))));self.uv.append(uv)
 def tube(self,points,radii,sides=7):
  for j in range(len(points)-1):
   a,b=Vector(points[j]),Vector(points[j+1]);d=(b-a).normalized();u=d.cross(Vector((0,0,1)))
   if u.length<.01:u=Vector((1,0,0))
   u.normalize();v=d.cross(u)
   for i in range(sides):
    aa=i*math.tau/sides;bb=(i+1)*math.tau/sides
    p=[a+(u*math.cos(aa)+v*math.sin(aa))*radii[j],a+(u*math.cos(bb)+v*math.sin(bb))*radii[j],b+(u*math.cos(bb)+v*math.sin(bb))*radii[j+1],b+(u*math.cos(aa)+v*math.sin(aa))*radii[j+1]]
    self.face(p,[(i/sides,j*.6),((i+1)/sides,j*.6),((i+1)/sides,(j+1)*.6),(i/sides,(j+1)*.6)])
 def spray(self,a,b,w,tilt):
  a,b=Vector(a),Vector(b);d=(b-a).normalized();side=d.cross(Vector((0,0,1))).normalized();up=d.cross(side).normalized();side=(side*math.cos(tilt)+up*math.sin(tilt)).normalized()
  # Two tapered, slightly folded cards per spray; actual alpha atlas supplies needles.
  for side in [side,up]:
   mid=a.lerp(b,.48)+Vector((0,0,.08));base=len(self.v)
   self.face([a-side*w*.18,a+side*w*.18,mid+side*w*.50,mid-side*w*.50],[(0,1),(1,1),(1,.5),(0,.5)])
   self.face([mid-side*w*.50,mid+side*w*.50,b+side*w*.14,b-side*w*.14],[(0,.5),(1,.5),(1,0),(0,0)])
 def obj(self,n,m,smooth=False):
  me=bpy.data.meshes.new(n);me.from_pydata(self.v,[],self.f);me.materials.append(m);layer=me.uv_layers.new()
  for p,uv in zip(me.polygons,self.uv):
   p.use_smooth=smooth
   for i,t in zip(p.loop_indices,uv):layer.data[i].uv=t
  ob=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(ob);return ob
for kind,h,seedn in [('FirA',12,271),('FirB',14,727),('YoungFir',7,827)]:
 rng.seed(seedn);wood=Mesh();leaves=Mesh();lean=Vector((rng.uniform(-.4,.4),rng.uniform(-.3,.3),0));pts=[];rs=[]
 for i in range(19):
  t=i/18;z=t*h;pts.append(lean*t*t+Vector((math.sin(t*5)*.08,math.cos(t*6)*.07,z)));rs.append((.22*(1-t)**.8+.022)*(1+.55*math.exp(-t*45)))
 wood.tube(pts,rs,10)
 for i in range(6):
  a=i*math.tau/6;wood.tube([Vector((0,0,.6)),Vector((math.cos(a)*.55,math.sin(a)*.55,.04))],[.11,.025],6)
 # Irregular individual branch tiers; no uniform Christmas-tree rings.
 for j in range(13):
  t=j/13;z=h*(.19+.75*t)+rng.uniform(-.15,.15);length=(h*.24)*(1-t)**.7+.18;count=rng.randint(4,7);rot=rng.random()*math.tau
  for k in range(count):
   a=rot+k*math.tau/count+rng.uniform(-.26,.26);d=Vector((math.cos(a),math.sin(a),0));side=Vector((-d.y,d.x,0));base=lean*(z/h)**2+Vector((0,0,z));ln=length*rng.uniform(.65,1.18);tip=base+d*ln+Vector((0,0,-.28*ln));elbow=base.lerp(tip,.6)+Vector((0,0,.13))
   wood.tube([base,elbow,tip],[.048*(1-t)+.01,.025,.003],5)
   for s in range(3):
    u=.18+s*.30;origin=base.lerp(tip,u);reach=.75*(1-t)+.35
    for sign in [-1,1]:
     end=origin+d*reach*.5+side*sign*reach*.55+Vector((0,0,-.22));leaves.spray(origin,end,reach*.90,rng.uniform(-.5,.5))
   leaves.spray(elbow,tip+Vector((0,0,.08)),max(.22,.45*(1-t)),rng.random())
 wood.obj(kind+'_Wood',bark,True);leaves.obj(kind+'_Needles',needle)
# Reeds: actual curved leaves, stems and cigar seedheads, shared in clusters.
for variant in range(2):
 rng.seed(88+variant);blade=Mesh();heads=Mesh()
 for i in range(17):
  a=rng.random()*math.tau;r=rng.random()*.38;x,y=math.cos(a)*r,math.sin(a)*r;h=rng.uniform(.55,1.35)
  blade.tube([(x,y,0),(x+.07,y-.04,h)],[.007,.003],4)
  if i%3==0:heads.tube([(x+.07,y-.04,h*.88),(x+.07,y-.04,h*1.05)],[.024,.017],7)
  for k in range(2):
   aa=a+k*2.5;d=Vector((math.cos(aa),math.sin(aa),0));side=Vector((-d.y,d.x,0))*.025;base=Vector((x,y,h*.2));mid=base+d*.24+Vector((0,0,h*.45));tip=base+d*.46+Vector((0,0,h*.52))
   blade.face([base-side*.2,base+side*.2,mid+side,mid-side],[(0,0),(1,0),(1,.55),(0,.55)]);blade.face([mid-side,mid+side,tip],[(0,.55),(1,.55),(.5,1)])
 blade.obj('Rush'+str(variant)+'_Blade',green,True);heads.obj('Rush'+str(variant)+'_Seed',seed,True)
# A rooted fallen trunk and broken boughs, with visible end-grain cap.
log=Mesh();log.tube([(-1.8,0,.19),(-.3,.04,.24),(1.7,.02,.31)],[.20,.18,.10],12)
for x in [-.9,.3,.8]:log.tube([(x,0,.25),(x+.2,.15,.7)],[.07,.018],6)
log.obj('Driftwood',bark,True)
bpy.ops.wm.save_as_mainfile(filepath=blend,compress=True)
bpy.ops.export_scene.gltf(filepath=out,export_format='GLB',export_animations=False)
print('LAKE_KIT',json.dumps({o.name:len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'}))
