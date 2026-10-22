"""Blender 5.2+: refine the supplied train, preserve the main photo sprite.
Run from repo root: blender -b src/assets/models/goldmine_train/goldmine_train.blend
  --python tools/ep2_blender/train_fidelity_pass.py
Writes the editable source, GLB and alternate sprite only. Git retains the intake.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'src/assets/models/goldmine_train'
scene = bpy.context.scene
bpy.context.preferences.filepaths.save_version=0
bpy.context.view_layer.update()
old = bpy.data.collections.get('Train Fidelity')
if old:
    for o in list(old.objects): bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(old)
collection = bpy.data.collections.new('Train Fidelity')
scene.collection.children.link(collection)

def mat(name, color, metal=0, rough=.4):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

iron = mat('Pass charcoal iron', (.055,.064,.072), .72)
brass = mat('Pass warm brass', (.52,.29,.085), .78, .28)
steel = mat('Pass wheel steel', (.16,.18,.19), .78, .32)
wood = mat('Pass cab walnut', (.13,.052,.022), .05, .6)
coal = mat('Pass coal', (.018,.021,.024), .08, .85)

def own(o, name, material):
    o.name = name
    for c in list(o.users_collection): c.objects.unlink(o)
    collection.objects.link(o)
    if material: o.data.materials.clear(); o.data.materials.append(material)
    return o

def box(name, pos, dims, material=iron):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = own(bpy.context.object,name,material); o.dimensions = dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return o

def bar(name, a, b, width=.045, material=steel):
    a,b=Vector(a),Vector(b)
    o=box(name,(a+b)/2,(width,width,(b-a).length),material)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def ring(name, pos, radius, thickness, rotation=(math.pi/2,0,0), material=steel):
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=6,
        location=pos,major_radius=radius-thickness,minor_radius=thickness,rotation=rotation)
    return own(bpy.context.object,name,material)

def wheel(name,x,y,z,r):
    ring(name+' rim',(x,y,z),r,.055)
    for n in range(12):
        a=n*math.tau/12
        bar(name+' spoke '+str(n),(x,y,z),(x+math.cos(a)*(r-.07),y,z+math.sin(a)*(r-.07)),.045)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r*.17,depth=.22,
        location=(x,y,z),rotation=(math.pi/2,0,0))
    own(bpy.context.object,name+' hub',brass)

# Replace only coarse components whose silhouette/detail needs correction.
replace = ['Cab','CabWindowL','CabWindowR','Cowcatcher','StackFunnel']
for o in list(bpy.data.objects):
    if o.name in replace or o.name.startswith(('Driver','PilotWheel','TenderWheel')):
        bpy.data.objects.remove(o,do_unlink=True)
for o in bpy.data.objects:
    if o.type != 'MESH' or o.name.startswith(('Tie_','Rail')): continue
    if o.name.startswith(('Band_','Bell','GM_Medallion','TenderStripe')): material=brass
    elif o.name == 'CabRoof': material=wood
    else: material=iron
    o.data.materials.clear(); o.data.materials.append(material)

# Two open framed windows on each side; no painted solid window plaques.
box('Cab lower body',(2.4,0,1.85),(1.9,1.9,1.05))
for y in [-.96,.96]:
    for x in [1.48,2.38,3.32]: box('Cab window upright',(x,y,2.91),(.085,.09,1.23),wood)
    for z in [2.34,3.48]: box('Cab window sill',(2.4,y,z),(1.94,.10,.075),brass)
    box('Cab door panel',(2.88,y,1.84),(.62,.07,.86),wood)
    box('Cab step',(3.15,y*1.12,1.08),(.46,.26,.09),steel)
    for x in [1.53,2.33,2.43,3.27]: box('Window brass trim',(x,y*1.005,2.91),(.025,.025,1.05),brass)

# Flared funnel with a dark inset/open-looking mouth and rim, rather than a drum.
bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.29,radius2=.65,depth=.72,location=(-2,0,3.57))
own(bpy.context.object,'Flared funnel',iron)
ring('Funnel lip',(-2,0,3.94),.66,.045,(0,0,0),iron)
bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.58,depth=.012,location=(-2,0,3.925))
own(bpy.context.object,'Funnel dark opening',coal)

# A real slatted pilot: angled rods across a wedge, tied by a front beam.
box('Pilot front beam',(-4.15,0,.24),(.12,1.9,.12),wood)
box('Pilot top beam',(-3.27,0,1.0),(.12,1.4,.10),iron)
for i in range(13):
    y=-.88+i*1.76/12
    bar('Cowcatcher slat '+str(i),(-4.12,y,.27),(-3.27,y*.72,.99),.046)

for y in [-.94,.94]:
    for i,x in enumerate([.4,2.0]): wheel('Driver '+str(i)+str(y),x,y,.85,.85)
    for i,x in enumerate([-2.8,-1.85]): wheel('Pilot '+str(i)+str(y),x,y,.43,.39)
    for i,x in enumerate([4.1,5.7]): wheel('Tender '+str(i)+str(y),x,y,.45,.42)
    # Offset crank pins and their connecting bar, both sides, not a central plank.
    bar('Coupling rod '+str(y),(.4,y*1.1,.63),(2,y*1.1,.63),.085)
    for x in [.4,2]:
        bar('Crank '+str(x)+str(y),(x,y*1.1,.85),(x,y*1.1,.63),.10,brass)
    bar('Piston rod '+str(y),(-1.65,y*1.06,.68),(.4,y*1.1,.63),.055)
    for z in [1.03,2.43]: box('Tender edge trim',(4.9,y,z),(2.65,.06,.065),brass)

rng=random.Random(1875)
for i in range(24):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=rng.uniform(.14,.25),
        location=(rng.uniform(3.92,5.88),rng.uniform(-.68,.68),rng.uniform(2.47,2.70)))
    own(bpy.context.object,'Tender coal '+str(i),coal)

def text(name,body,pos,size,rotation):
    cu=bpy.data.curves.new(name,'FONT');cu.body=body;cu.size=size;cu.align_x='CENTER';cu.align_y='CENTER';cu.extrude=.002
    o=bpy.data.objects.new(name,cu);collection.objects.link(o);o.location=pos;o.rotation_euler=rotation;cu.materials.append(brass)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o.select_set(False)
for y in [-.99,.99]:
    text('Tender GOLD MINE '+str(y),'GOLD MINE',(4.9,y,1.85),.32,(math.pi/2,0,0 if y<0 else math.pi))
    text('Cab GM '+str(y),'GM',(2,y*1.07,1.9),.25,(math.pi/2,0,0 if y<0 else math.pi))

# Use and pack the supplied, provenance-recorded Poly Haven softbox environment.
scene.world.use_nodes=True
n=scene.world.node_tree.nodes;n.clear()
env=n.new('ShaderNodeTexEnvironment');env.image=bpy.data.images.load(str(DEST/'studio_small_09_2k.hdr'),check_existing=True);env.image.pack()
bg=n.new('ShaderNodeBackground');bg.inputs['Strength'].default_value=.7
out=n.new('ShaderNodeOutputWorld');scene.world.node_tree.links.new(env.outputs['Color'],bg.inputs['Color']);scene.world.node_tree.links.new(bg.outputs[0],out.inputs[0])
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_x=1920;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.camera.location=(1,-16,3.3);scene.camera.rotation_euler=(Vector((1,0,1.95))-scene.camera.location).to_track_quat('-Z','Y').to_euler();scene.camera.data.ortho_scale=13.5
bpy.context.view_layer.update()
meshes=[o for o in scene.objects if o.type=='MESH'];tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
assert tris<30000, tris
scene['fidelity_pass']='Open cab windows; flared funnel; slatted pilot; spoked drivers and crank rods; coal tender. Main photo sprite unchanged.'
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'goldmine_train.blend'),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(DEST/'goldmine_train.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False)
scene.render.filepath=str(ROOT/'src/assets/sprites/sprite_train_goldmine_blender-render.png')
bpy.ops.render.render(write_still=True)
print('TRAIN_PASS '+json.dumps({'triangles':tris,'mesh_objects':len(meshes),'hdr_packed':env.image.packed_file is not None}))
