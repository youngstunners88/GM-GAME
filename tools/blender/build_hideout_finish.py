#!/usr/bin/env python3
"""Author the hideout finish kit in headless Blender; no paid generation.

Run: blender -b --python tools/blender/build_hideout_finish.py -- <repo-root>
Godot coordinates below are metres, +Y up. Editable source keeps all six kits.
UVs, bevels, hollow profiles and standard glTF PBR survive the Web renderer.
"""
import bpy
import bmesh
import math
import os
import sys
import json
import struct
from mathutils import Vector
from collections import defaultdict

ROOT = os.path.abspath(sys.argv[sys.argv.index('--') + 1])
OUT = os.path.join(ROOT, 'src/episode2/assets/hideout')
SOURCE = os.path.join(ROOT, 'design/ep2/blender/hideout_finish.blend')
bpy.ops.wm.read_factory_settings(use_empty=True)
os.makedirs(os.path.dirname(SOURCE), exist_ok=True)
os.makedirs(OUT, exist_ok=True)


def xyz(p):
    return Vector((p[0], -p[2], p[1]))


def material(name, color, roughness, metallic=0, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    # Principled colours are linear; the game palette below is specified in sRGB.
    p.inputs['Base Color'].default_value = (*[c ** 2.2 for c in color], 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    if image:
        node = m.node_tree.nodes.new('ShaderNodeTexImage')
        node.image = bpy.data.images.load(image, check_existing=True)
        m.node_tree.links.new(node.outputs['Color'], p.inputs['Base Color'])
    return m


wood = material('Finish_WornOak', (.38, .23, .12), .82,
                image=os.path.join(ROOT, 'src/episode2/assets/textures/tex_timber.jpg'))
iron = material('Finish_HammeredIron', (.17, .145, .12), .58, .28)
edge = material('Finish_RubbedIron', (.31, .285, .24), .42, .32)
stone = material('Finish_SootStone', (.40, .37, .32), .94,
                 image=os.path.join(ROOT, 'src/episode2/assets/textures/tex_rock_wall.jpg'))
gold = material('Finish_CastGold', (.86, .63, .25), .31, .35)
brass = material('Finish_OldBrass', (.58, .40, .18), .45, .32)

# Small baked normal maps from source luminance: standard NormalMap nodes,
# not Blender-only noise/bump nodes that disappear in the glTF export.
def add_normal(mat, source, name, strength):
    src = bpy.data.images.load(source, check_existing=True).copy()
    src.scale(128, 128)
    import numpy as np
    px = np.array(src.pixels[:], dtype=np.float32).reshape(128, 128, 4)
    h = px[:, :, :3].mean(axis=2)
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack((-dx, -dy, np.ones_like(h)), axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    rgba = np.ones((128, 128, 4), np.float32)
    rgba[:, :, :3] = n * .5 + .5
    image = bpy.data.images.new(name, width=128, height=128)
    image.colorspace_settings.name = 'Non-Color'
    image.pixels = rgba.flatten().tolist()
    image.filepath_raw = os.path.join(OUT, name + '.png')
    image.file_format = 'PNG'
    image.save()
    node = mat.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    nm = mat.node_tree.nodes.new('ShaderNodeNormalMap')
    nm.inputs['Strength'].default_value = .65
    mat.node_tree.links.new(node.outputs['Color'], nm.inputs['Color'])
    mat.node_tree.links.new(nm.outputs['Normal'], mat.node_tree.nodes['Principled BSDF'].inputs['Normal'])


add_normal(wood, os.path.join(ROOT, 'src/episode2/assets/textures/tex_timber.jpg'), 'finish_oak_normal', 3)
add_normal(stone, os.path.join(ROOT, 'src/episode2/assets/textures/tex_rock_wall.jpg'), 'finish_stone_normal', 5)
# Original colour sources remain at their original resolution on disk. Loading
# into Blender above scales only its datablock; both exported maps are 256px.

parts = []
kit = None


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata([xyz(v) for v in verts], [], faces)
    data.materials.append(mat)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    o = bpy.data.objects.new(name, data)
    kit.objects.link(o)
    parts.append(o)
    return o


def bevel(o, amount=.025):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    b = o.modifiers.new('Worn arris', 'BEVEL')
    b.width = amount
    b.segments = 1
    bpy.ops.object.modifier_apply(modifier=b.name)
    o.select_set(False)


def box(name, size, pos, mat, amount=.025):
    x, y, z = [v / 2 for v in size]
    verts = [(pos[0]+a*x, pos[1]+b*y, pos[2]+c*z)
             for a,b,c in [(-1,-1,-1),(-1,-1,1),(-1,1,1),(-1,1,-1),(1,-1,-1),(1,1,-1),(1,1,1),(1,-1,1)]]
    o = mesh(name, verts, [(0,3,2,1),(4,7,6,5),(0,1,7,4),(3,5,6,2),(1,2,6,7),(0,4,5,3)], mat)
    # Project each polygon onto its own broad face in metres. Vertical timber
    # uses long grain; never let the default cube UV tile it into tiny stripes.
    uv = o.data.uv_layers.new(name='UVMap')
    for poly in o.data.polygons:
        normal = poly.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        axes = [i for i in range(3) if i != axis]
        extent = (size[0], size[2], size[1])
        axes.sort(key=lambda i: extent[i], reverse=True)
        for idx in poly.loop_indices:
            v = o.data.vertices[o.data.loops[idx].vertex_index].co
            uv.data[idx].uv = (v[axes[0]] * .33, v[axes[1]] * .22)
    bevel(o, amount)
    return o


def rod(name, a, b, radius, mat, vertices=12):
    av, bv = xyz(a), xyz(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(bv-av).length, location=(av+bv)/2)
    o = bpy.context.object
    for col in list(o.users_collection): col.objects.unlink(o)
    kit.objects.link(o)
    o.name = name
    o.rotation_euler = (bv-av).to_track_quat('Z', 'Y').to_euler()
    o.data.materials.append(mat)
    parts.append(o)
    bevel(o, min(radius*.18, .008))
    return o


def lathe(name, profile, mat, segments=48):
    verts=[]
    for radius,y in profile:
        verts += [(radius*math.cos(i*math.tau/segments), y, radius*math.sin(i*math.tau/segments)) for i in range(segments)]
    faces=[]
    for j in range(len(profile)-1):
        for i in range(segments):
            k=(i+1)%segments
            faces.append((j*segments+i,j*segments+k,(j+1)*segments+k,(j+1)*segments+i))
    o=mesh(name,verts,faces,mat)
    for p in o.data.polygons:p.use_smooth=True
    return o


def start(name):
    global parts, kit
    parts=[]
    kit=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(kit)


def finish(name):
    # Merge by material: production draw calls bounded independently of detail.
    groups=defaultdict(list)
    for o in parts:groups[o.data.materials[0].name].append(o)
    final=[]
    for key,objs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objs:o.select_set(True)
        bpy.context.view_layer.objects.active=objs[0]
        bpy.ops.object.join()
        o=bpy.context.object
        o.name=name+'_'+key
        final.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in final:o.select_set(True)
    path=os.path.join(OUT,name+'.glb')
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_apply=True)
    # The editable .blend is packed. Game exports share the existing colour
    # images and two normal maps, rather than importing a copy for every GLB.
    blob = open(path, 'rb').read()
    length = struct.unpack_from('<I', blob, 12)[0]
    doc = json.loads(blob[20:20+length])
    for im in doc.get('images', []):
        image_name = im['name'].split('.')[0]
        if image_name.startswith('tex_'):
            im['uri'] = '../textures/' + image_name + '.jpg'
        elif image_name.startswith('finish_'):
            im['uri'] = image_name + '.png'
        else:
            raise ValueError('Unregistered image '+image_name)
        im.pop('bufferView', None)
        im.pop('mimeType', None)
    js = json.dumps(doc, separators=(',', ':')).encode()
    js += b' ' * ((-len(js)) % 4)
    tail = blob[20+length:]
    with open(path, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, 20+len(js)+len(tail)))
        f.write(struct.pack('<I4s', len(js), b'JSON'))
        f.write(js)
        f.write(tail)
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in final)
    stats[name]={'triangles':triangles,'meshes':len(final),'bytes':os.path.getsize(path)}
    print('KIT',name,stats[name])


stats={}
start('ForgeCrucible')
lathe('Hollow cast vessel',[(0,.28),(.67,.28),(.88,.42),(.99,1.2),(1.02,1.57),(.98,1.66),(.91,1.66),(.9,1.55),(.86,.68),(.64,.41),(0,.41)],iron)
lathe('Thick rolled lip',[(.96,1.57),(1.035,1.58),(1.05,1.64),(1.015,1.7),(.94,1.7),(.91,1.64),(.96,1.57)],edge)
for y in [.55,1.36]:
    lathe('Forged hoop',[(.89 if y<1 else .997,y-.05),(.94 if y<1 else 1.03,y-.05),(.94 if y<1 else 1.03,y+.05),(.89 if y<1 else .997,y+.05)],edge)
    for i in range(12):
        a=i*math.tau/12;r=.95 if y<1 else 1.045
        rod('Rivet',(r*math.cos(a),y,r*math.sin(a)),((r+.035)*math.cos(a),y,(r+.035)*math.sin(a)),.025,brass,10)
for a in [0,math.tau/3,math.tau*2/3]:
    c,s=math.cos(a),math.sin(a)
    rod('Splayed foot',(.56*c,.36,.56*s),(.83*c,.06,.83*s),.12,iron)
for side in [-1,1]:
    box('Lift lug',(.1,.3,.25),(side*1.04,1.24,0),edge)
    rod('Handle', (side*1.11,1.29,-.24),(side*1.11,1.29,.24),.05,edge)
finish('forge_crucible')

start('PourLadle')
lathe('Ladle bowl',[(0,-.24),(.3,-.24),(.44,-.1),(.46,.16),(.41,.2),(.36,.13),(.34,-.1),(0,-.15)],iron,32)
lathe('Ladle rolled rim',[(.4,.14),(.48,.14),(.48,.2),(.4,.2),(.4,.14)],edge,32)
for side in [-1,1]:rod('Suspension', (side*.42,.1,0),(side*.28,1.05,0),.036,iron)
rod('Suspension crosspiece',(-.28,1.05,0),(.28,1.05,0),.045,edge)
finish('pour_ladle')

start('FiringBench')
for i in range(4):
    box('Top slab',(2.1,.115,.2),(0,.80,(i-1.5)*.205),wood,.022)
for x in [-.77,.77]:
    box('Trestle',(.15,.67,.60),(x,.34,0),wood,.017)
    box('Foot',(.3,.10,.87),(x,.07,0),wood)
    box('Iron end cap',(.19,.13,.64),(x,.70,0),iron,.009)
    for z in [-.24,.24]:rod('Peg',(x-.1,.63,z),(x+.1,.63,z),.022,brass,10)
box('Through stretcher',(1.7,.14,.15),(0,.23,0),wood)
for x in [-1,1]:box('Bound end',(.055,.135,.81),(x,.79,0),iron,.008)
finish('firing_bench')

start('FurnaceStonework')
# Godot mount = (-6.3,0,16.05). Deep opening around the existing molten mouth.
for side in [-1,1]:
    for j in range(5):
        box('Sooted jamb',(.64,.50,.82),(side*1.55,.34+j*.51,0),stone,.07)
for j in range(9):
    a=j*math.pi/9;b=(j+1)*math.pi/9;verts=[]
    for z in [-.4,.42]:
        for r,t in [(1.25,a),(1.91,a),(1.91,b),(1.25,b)]:
            verts.append((r*math.cos(t),2.36+r*.64*math.sin(t),z))
    o=mesh('Voussoir',verts,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],stone)
    bevel(o,.045)
box('Deep hearth',(4.2,.22,1.7),(0,.11,.12),stone,.07)
box('Fire lintel',(2.5,.15,.25),(0,2.75,.43),iron)
for i in range(7):rod('Hearth grate',(-1.08+i*.36,.18,.52),(-1.08+i*.36,.67,.52),.03,iron)
finish('furnace_stonework')

start('RangeBackstop')
# Same 11 x 6.4 m bounds and front-plane anchor as existing wall.
for i in range(22):
    x=-5.5+(i+.5)*.5
    box('Scarred plank',(.484,6.10-(i%4)*.032,.16),(x,3.15,.03-(i%3)*.012),wood,.025)
for y in [.20,4.38,6.05]:
    box('Cross rail',(10.95,.24,.18),(0,y,.16),wood)
    for i in range(22):
        x=-5.5+(i+.5)*.5
        rod('Square nail',(x,y,.23),(x,y,.258),.022,iron,6)
for side in [-1,1]:
    for j in range(8):box('Stone wing',(.73,.73,.51),(side*5.27,.39+j*.74,.12),stone,.055)
    box('End cap',(.87,.16,.66),(side*5.27,6.08,.13),stone)
box('Stone kick course',(9.7,.22,.55),(0,.16,.12),stone,.035)
for x in [-3.8,3.8]:
    box('Lamp hood',(.52,.12,.45),(x,4.70,.45),iron)
    rod('Hood bracket',(x,4.70,.2),(x,4.70,.65),.03,iron)
finish('range_wall')

start('CastIngot')
verts=[(-.25,0,-.12),(.25,0,-.12),(.25,0,.12),(-.25,0,.12),(-.21,.13,-.09),(.21,.13,-.09),(.21,.13,.09),(-.21,.13,.09)]
o=mesh('Tapered ingot',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],gold)
bevel(o,.013)
for x in [-.11,.11]:box('Stamp impression',(.06,.002,.025),(x,.1305,0),brass,.002)
finish('cast_ingot')

# Save all kits together, with names and local origins suitable for editing.
for image in bpy.data.images:
    if image.type=='IMAGE':image.pack()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
with open(os.path.join(ROOT,'design/ep2/blender/hideout_finish_manifest.json'),'w') as f:
    json.dump({'generator':'Blender '+bpy.app.version_string,'basis':'Godot metres; glTF Y-up','license':'project-authored geometry; existing project texture sources','kits':stats,'source':os.path.relpath(SOURCE,ROOT)},f,indent=2)
print('FINISH KIT COMPLETE',SOURCE)
