"""Founder's Drive models (2026-10-14: Jake.glb, donkey cart 3d model.glb, 30+ MB each, 4K textures) -> web-pack-sized game GLBs.
  python3 tools/ep2_blender/prep_founder_town_models.py jake  <in.glb> <out.glb> [faces]
  python3 tools/ep2_blender/prep_founder_town_models.py cart  <in.glb> <out.glb> [faces]
Runs with the `bpy` pip module (no GUI). jake/pose: the T-pose arms are rotated into a stance by vertex math (`deform_arms`, key=value\noverrides pitch_l pitch_r swing_l swing_r) and baked static; cart: use the FBX from the zip - the Tripo rig is applied (rest pose) and dropped.
Both: decimated, textures to 1024, JPEG in the GLB."""
import sys, math
import bpy
from mathutils import Vector, Matrix

kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
faces = int(sys.argv[4]) if len(sys.argv) > 4 else 12000
bpy.ops.wm.read_factory_settings(use_empty=True)
(bpy.ops.import_scene.fbx(filepath=src) if src.lower().endswith('.fbx') else bpy.ops.import_scene.gltf(filepath=src))
sc = bpy.context.scene


def meshes():
    return [o for o in sc.objects if o.type == 'MESH']


def align_to_front(rotz):
    """Turn the mesh about the vertical so it faces glTF +Z (Blender -Y) with the arm span along x. Tripo multiview outputs face +X (use rotz=-90) or +Z (0)."""
    if abs(rotz) < 1e-6:
        return
    for o in meshes():
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        o.rotation_mode = 'XYZ'
        o.rotation_euler = (0.0, 0.0, math.radians(rotz))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    # stand it on the floor, centred
    for o in meshes():
        import numpy as _np
        me = o.data
        co = _np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get('co', co)
        co = co.reshape(-1, 3)
        co[:, 0] -= (co[:, 0].max() + co[:, 0].min()) * 0.5
        co[:, 1] -= (co[:, 1].max() + co[:, 1].min()) * 0.5
        co[:, 2] -= co[:, 2].min()
        me.vertices.foreach_set('co', co.reshape(-1))
        me.update()


def bake_object_transforms():
    """Tripo GLBs carry a node rotation/scale: bake it into the vertices so the mesh axes are the model's (x = arm span, z = height)."""
    for o in meshes():
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def select_only(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def bake_modifiers(o):
    select_only(o)
    for m in list(o.modifiers):
        if m.type == 'ARMATURE':
            bpy.ops.object.modifier_apply(modifier=m.name)


def decimate(o, target):
    n = len(o.data.polygons)
    if n <= target:
        return
    m = o.modifiers.new('dec', 'DECIMATE')
    m.ratio = target / n
    m.delimit = {'UV'}          # keep the UV island borders: plain collapse smears the 4K unwrap into white seam streaks
    select_only(o)
    bpy.ops.object.modifier_apply(modifier='dec')


def shrink_images(px=1024):
    for img in bpy.data.images:
        if img.size[0] > px:
            img.scale(px, px)


import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from town_pose import smoothstep, deform_arms


def clean_material(o, base, normal):
    """One Principled material from two images (the FBX nodes come in unlinked)."""
    m = bpy.data.materials.new('town_mat')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    bs = nt.nodes.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Roughness'].default_value = 0.85
    bs.inputs['Metallic'].default_value = 0.0
    nt.links.new(bs.outputs['BSDF'], out.inputs['Surface'])
    tb = nt.nodes.new('ShaderNodeTexImage')
    tb.image = bpy.data.images[base]
    nt.links.new(tb.outputs['Color'], bs.inputs['Base Color'])
    if normal in bpy.data.images:
        tn = nt.nodes.new('ShaderNodeTexImage')
        tn.image = bpy.data.images[normal]
        tn.image.colorspace_settings.name = 'Non-Color'
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nt.links.new(tn.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], bs.inputs['Normal'])
    o.data.materials.clear()
    o.data.materials.append(m)


bake_object_transforms() if kind != 'cart' else None
ROTZ = float(next((a_.split('=')[1] for a_ in sys.argv[5:] if a_.startswith('rotz=')), 0.0))
if kind != 'cart':
    align_to_front(ROTZ)
if kind == 'cart':
    # the founder's GLB skins to shards in every importer; his FBX (same Tripo job, in the zip) is the clean one
    body = [o for o in meshes() if not o.name.startswith('Icosphere')][0]
    select_only(body)
    bake_modifiers(body)
    body.parent = None
    for o in list(sc.objects):
        if o != body:
            bpy.data.objects.remove(o, do_unlink=True)
    body.vertex_groups.clear()
    decimate(body, faces)
    shrink_images(1024)
    clean_material(body, 'donkey_cart_3d_model_basecolor', 'donkey_cart_3d_model_normal')
elif kind in ('jake', 'pose', 'duo'):
    body = meshes()[0]
    decimate(body, faces)
    # args after faces: key=value arm pose overrides (e.g. pitch_r=20 swing_r=80), `auto=1` fits the shoulders to the mesh;
    # duo: `a:key=v` for the first pose ("Idle"), `b:key=v` for the second ("Draw"); both share ONE material / texture set.
    kw = {'a': {}, 'b': {}}
    for a_ in sys.argv[5:]:
        k_, v_ = a_.split('=')
        if k_ == 'rotz':
            continue
        tgt = ['a', 'b']
        if k_[:2] in ('a:', 'b:'):
            tgt, k_ = [k_[0]], k_[2:]
        for t_ in tgt:
            kw[t_][k_] = float(v_)
    if kind == 'duo':
        body2 = body.copy()
        body2.data = body.data.copy()
        sc.collection.objects.link(body2)
        body.name, body2.name = 'Idle', 'Draw'
        deform_arms(body, **kw['a'])
        deform_arms(body2, **kw['b'])
    else:
        deform_arms(body, **kw['a'])
    import json as _json
    info = {}
    for ob in meshes():
        import numpy as _np
        me = ob.data
        co = _np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get('co', co)
        co = co.reshape(-1, 3)
        r = co[co[:, 0] < -0.5 * abs(co[:, 0]).max()]          # the character's RIGHT arm (x < 0): its tip
        tip = r[_np.argmin(r[:, 0])] if len(r) else _np.zeros(3)
        # hand = the mean of the vertices within 6% of the body height of the farthest point along the arm
        H_ = co[:, 2].max() - co[:, 2].min()
        near = r[_np.linalg.norm(r - tip, axis=1) < 0.06 * H_] if len(r) else r
        hand = near.mean(axis=0) if len(near) else tip
        info[ob.name] = {'hand_r': [float(hand[0]), float(hand[2]), float(-hand[1])], 'height': float(H_), 'zmin': float(co[:, 2].min())}    # glTF axes
    open(out + '.json', 'w').write(_json.dumps(info))
    print('HAND', info)

shrink_images(1024)
for o in meshes():
    o.select_set(True)
print('faces', sum(len(o.data.polygons) for o in meshes()))
for ob in meshes():
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=82, export_apply=True)
import os
print('out', os.path.getsize(out))
