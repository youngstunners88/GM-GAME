"""Small timber staging dock, in metres; Godot origin is walking surface height.
Blender 5.2 -b --factory-startup -P this.py -- OUTPUT.glb SOURCE.blend
"""
import bpy, math, random, sys
from pathlib import Path
from mathutils import Vector
out, blend = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
random.seed(88)
def mat(name, color, roughness=.85):
    m=bpy.data.materials.new(name)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=roughness
    return m
woods=[mat('Aged cedar '+str(i),(.22+i*.015,.13+i*.01,.065+i*.007)) for i in range(5)]
rope=mat('Hemp rope',(.47,.36,.20)); iron=mat('Forged iron',(.07,.065,.05),.55)
def box(name, loc, size, material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    mod=o.modifiers.new('Soft worn edges','BEVEL');mod.width=.018;mod.segments=1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
for i in range(27):
    box('Dock plank',(-3.9+i*.3,0,-.065),( .285,2.8+random.uniform(-.06,.06),.13),random.choice(woods))
for y in (-1,1):
    box('Under beam',(0,y,-.2),(8.1,.17,.22),woods[0])
for x in (-3.6,0,3.6):
    for y in (-1.25,1.25):
        box('Dock pile',(x,y,-.34),(.20,.20,1.5),woods[0])
        # Three rope turns hug each pile; not floating circles.
        for z in (.18,.22,.26):
            bpy.ops.mesh.primitive_torus_add(major_radius=.147,minor_radius=.016,
                major_segments=12,minor_segments=4,location=(x,y,z))
            bpy.context.object.data.materials.append(rope)
# Mooring cleat at the outer edge.
box('Cleat base',(3.4,0,.08),(.12,.15,.16),iron)
box('Cleat horns',(3.4,0,.17),(.45,.08,.07),iron)
Path(out).parent.mkdir(parents=True,exist_ok=True)
Path(blend).parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(blend).resolve()))
bpy.ops.export_scene.gltf(filepath=str(Path(out).resolve()),export_format='GLB',export_animations=False)
print('LOGAN_DOCK',Path(out).stat().st_size)
