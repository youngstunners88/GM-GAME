"""An American bison for the one-time buffalo stampede (founder 2026-11-01 evening, "Guns Buff" §5), reshaped from the game's own rigged
horse (src/episode2/assets/town/horse.glb) so it keeps that rig and its walk / stand / graze clips:
  - the neck and head swing down and forward about the withers (a bison carries its head low), the head is made heavy,
  - a shoulder hump, a deeper chest, a wider body and a thick neck,
  - two short upturned horns on the head bone,
  - a coat by vertex colour over the horse's albedo: dark shaggy front half (hump, neck, head, beard), lighter brown flanks.
Headless:  blender -b --factory-startup -P tools/ep2_blender/build_bison_from_horse.py -- <horse.glb> <out bison.glb>
"""
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in list(bpy.context.scene.objects):
    if o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)
mesh = bpy.data.objects["HorseMesh"]
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
me = mesh.data
gi = {g.name: g.index for g in mesh.vertex_groups}


def w(v, name):
    if name not in gi:
        return 0.0
    for g in v.groups:
        if g.group == gi[name]:
            return g.weight
    return 0.0


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


PIVOT = Vector((0.1, 0.0, 1.2))          # the withers: the neck swings down about here
DROP = math.radians(40.0)
for v in me.vertices:
    p = v.co.copy()
    wn = min(1.0, w(v, "neck1") + w(v, "neck2") + w(v, "head"))
    wh = w(v, "head")
    # neck + head down and forward (weighted, so the bend is smooth into the shoulders)
    if wn > 0.0:
        r = p - PIVOT
        a = -DROP * wn
        r = Vector((r.x * math.cos(a) - r.z * math.sin(a), r.y, r.x * math.sin(a) + r.z * math.cos(a)))
        q = PIVOT + r
        q.y *= 1.0 + 0.45 * wn                  # thick neck
        p = q
    torso = smooth(0.45, 0.8, p.z) * (1.0 - wn)
    front = smooth(-0.7, 0.0, p.x)
    p.y *= 1.0 + 0.55 * torso + 0.25 * torso * front          # wide body, wider at the shoulders
    p.z += 0.44 * math.exp(-((p.x - 0.0) / 0.5) ** 2) * smooth(0.95, 1.3, v.co.z) * (1.0 - wn)    # the hump, over the front legs
    p.z -= 0.13 * smooth(0.9, 0.6, v.co.z) * smooth(0.4, 0.62, v.co.z) * (1.0 - wn)              # a deep, low body
    legs_up = min(1.0, w(v, "FL_up") + w(v, "FR_up"))
    if legs_up > 0.2 and v.co.z > 0.55:                         # shaggy "chaps" on the upper front legs
        k = legs_up * smooth(0.55, 0.9, v.co.z)
        p.x += (p.x - 0.12) * 0.45 * k
        p.y *= 1.0 + 0.5 * k
    v.co = p
# the head heavy: scaled about its own centre
hv = [v for v in me.vertices if w(v, "head") > 0.35]
hc = sum((v.co for v in hv), Vector()) / max(1, len(hv))
for v in me.vertices:
    k = smooth(0.2, 0.6, w(v, "head"))
    if k > 0:
        d = v.co - hc
        # a bison's head: short in the face, broad, deep, with the beard hanging under the jaw
        d = Vector((d.x * (1.0 - 0.32 * k), d.y * (1.0 + 0.8 * k), d.z * (1.0 + 0.35 * k)))
        if d.z < 0:
            d.z *= 1.0 + 0.5 * k
        v.co = hc + d
me.update()

# horns: short, outward then up, on the head bone
top = max(v.co.z for v in hv)
for side in (1, -1):
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.06, radius2=0.008, depth=0.28,
                                    location=(hc.x - 0.06, side * 0.2, top - 0.04))
    horn = bpy.context.active_object
    horn.rotation_euler = (side * math.radians(-60), 0.0, 0.0)
    horn.name = "Horn" + ("L" if side > 0 else "R")
    hm = bpy.data.materials.new("Horn")
    hm.use_nodes = True
    b = next(n for n in hm.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (0.03, 0.028, 0.025, 1)
    b.inputs['Roughness'].default_value = 0.45
    horn.data.materials.append(hm)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    horn.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    vg = horn.vertex_groups.new(name="head")
    vg.add([vv.index for vv in horn.data.vertices], 1.0, 'REPLACE')
    bpy.ops.object.join()
    bpy.ops.object.select_all(action='DESELECT')

# the coat: the vertex colour IS the albedo (dark brown, near-black shag on the front half, a tan cast on the hump), mottled so it
# reads as fur; the horse's photo texture is dropped (a bay horse's coat under a tint still read as a horse)
me = mesh.data
col = me.color_attributes.new("Coat", 'FLOAT_COLOR', 'CORNER')     # linear, like glTF COLOR_0
gi = {g.name: g.index for g in mesh.vertex_groups}
for poly in me.polygons:
    for li in poly.loop_indices:
        v = me.vertices[me.loops[li].vertex_index]
        shag = max(smooth(-0.6, 0.0, v.co.x), min(1.0, w(v, "neck1") + w(v, "neck2") + w(v, "head")))
        hump = smooth(1.35, 1.65, v.co.z) * (1.0 - min(1.0, w(v, "head")))
        legs = smooth(0.42, 0.18, v.co.z)
        c = Vector((0.24, 0.155, 0.095)).lerp(Vector((0.11, 0.075, 0.05)), shag).lerp(Vector((0.36, 0.25, 0.15)), hump * 0.6)
        c = c.lerp(Vector((0.08, 0.06, 0.05)), legs)
        n = math.sin(v.co.x * 41.0 + v.co.z * 13.0) * math.sin(v.co.y * 37.0 - v.co.z * 29.0)
        c *= 1.0 + 0.16 * n
        col.data[li].color = (c.x ** 2.2, c.y ** 2.2, c.z ** 2.2, 1.0)    # the shades above are written as sRGB
for mat in me.materials:
    if mat is None or not mat.use_nodes or mat.name == "Horn":
        continue
    nt = mat.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    for l in list(b.inputs['Base Color'].links):
        nt.links.remove(l)
    vc = nt.nodes.new('ShaderNodeVertexColor')
    vc.layer_name = "Coat"
    nt.links.new(vc.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.95
    b.inputs['Metallic'].default_value = 0.0
arm.name = "BisonRig"
mesh.name = "BisonMesh"
arm.scale = (1.12, 1.12, 1.12)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=80, export_animations=True)
print("BISON_OK", len(me.vertices))
