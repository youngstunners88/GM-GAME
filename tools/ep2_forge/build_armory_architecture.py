"""Deterministic Blender-authored Fort Knox kit. Coordinates below are Godot XYZ.

blender -b --python tools/ep2_forge/build_armory_architecture.py -- EDITABLE.blend
Exports one mesh per material: bevels and block joints without per-block draw calls.
"""
import bpy, math, random, sys, json
from pathlib import Path
from mathutils import Vector

repo=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(1886)
mats={}
for name,color,rough,metal in [
    ('ArmoryOak',(.25,.12,.05),.82,0),
    ('ArmoryOakDark',(.16,.07,.03),.88,0),
    ('ArmoryStone',(.34,.30,.24),.91,0),
    ('ArmoryStoneLight',(.42,.37,.29),.88,0),
    ('ArmoryIron',(.055,.05,.043),.52,.45),
    ('ArmoryBrass',(.39,.24,.09),.4,.65)]:
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
    mats[name]=m

def finish(o,mat,bevel):
    o.data.materials.append(mats[mat])
    if bevel:
        mod=o.modifiers.new('Worn edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def box(name,pos,size,mat,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0],-pos[2],pos[1]))
    o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,mat,bevel)

# Individual staggered oak boards: the original floor was one featureless box.
for col in range(35):
    x=-7.0+col*.4
    z=-1.0
    first=True
    while z<13.5:
        length=min((1.1+(col%3)*.73) if first else random.uniform(2.6,3.8),13.5-z)
        box('Oak floorboard',(x,-.02,z+length/2),(.39,.07,max(.025,length-.012)),
            'ArmoryOakDark' if (col+int(z*3))%5==0 else 'ArmoryOak',.009)
        z+=length;first=False

# Dressed stone jambs, plinths and actual wedge-shaped voussoirs.
for side in [-1,1]:
    box('Vault plinth',(side*2.95,.19,16.4),(.91,.38,1.25),'ArmoryStone',.045)
    for row in range(6):
        box('Vault jamb',(side*2.92,.64+row*.46,16.4),(.65,.44,1.05),
            'ArmoryStoneLight' if row%3==0 else 'ArmoryStone',.035)
    box('Vault impost',(side*2.9,3.16,16.4),(.94,.22,1.24),'ArmoryStoneLight',.035)
for i in range(17):
    a=i*math.pi/17+.008;b=(i+1)*math.pi/17-.008
    verts=[]
    for z in [15.83,16.98]:
        for rx,ry,t in [(2.6,1.85,a),(3.28,2.45,a),(3.28,2.45,b),(2.6,1.85,b)]:
            verts.append((rx*math.cos(t),-z,3.18+ry*math.sin(t)))
    faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    mesh=bpy.data.meshes.new('Arch voussoir');mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new('Vault keystone' if i==8 else 'Vault voussoir',mesh)
    bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True)
    finish(o,'ArmoryStoneLight' if i%4==0 else 'ArmoryStone',.027)

# Low stone footing establishes weight beneath the timber-panelled side walls.
for side in [-1,1]:
    for row in range(2):
        for j in range(14):
            z=-.4+j
            box('Alcove footing',(side*6.99,.19+row*.32,z),(.29,.30,.975),'ArmoryStone',.018)

# Cabinet cornice, inset lower doors, brass inlay and iron straps behind the rifles.
for y,h,depth in [(1.02,.12,.42),(3.93,.16,.43),(4.13,.13,.32)]:
    box('Armory cornice',(-6.76,y,7.4),(depth,h,7.6),'ArmoryOak',.024)
for z in [3.8,5.3,6.8,8.3,9.8,11.0]:
    box('Rack stile',(-6.73,2.55,z),(.3,2.65,.12),'ArmoryOak',.018)
for z in [4.5,6.,7.5,9.,10.4]:
    box('Cabinet door',(-6.64,.57,z),(.3,.77,1.31),'ArmoryOakDark',.025)
    box('Cabinet raised panel',(-6.46,.57,z),(.075,.53,1.08),'ArmoryOak',.018)
    box('Brass pull',(-6.39,.72,z),(.08,.065,.25),'ArmoryBrass',.018)
for y in [1.08,3.94]:
    box('Rack brass inlay',(-6.53,y,7.4),(.024,.025,7.35),'ArmoryBrass',.005)

# Consolidate by material; exported game geometry has six mesh surfaces total.
for name,mat in mats.items():
    objects=[o for o in bpy.data.objects if o.type=='MESH' and o.data.materials and o.data.materials[0]==mat]
    if not objects:continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
editable=Path(sys.argv[sys.argv.index('--')+1]).resolve()
bpy.ops.wm.save_as_mainfile(filepath=str(editable))
out=repo/'src/episode2/assets/hideout/armory_architecture.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False)
report={'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.data.objects if o.type=='MESH'), 'mesh_count':len([o for o in bpy.data.objects if o.type=='MESH']), 'bytes':out.stat().st_size}
print(json.dumps(report))
