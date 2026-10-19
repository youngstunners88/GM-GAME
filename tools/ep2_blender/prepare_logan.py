"""Blender 5.2: supplied Logan skin -> small Godot 4.3 GLB with authored gestures.
Run with -- SOURCE.glb OUTPUT.glb SOURCE.blend. Never changes the supplied source.
No remeshing, rebinding, texture recolouring or paid generation.
"""
import bpy
import bmesh
import json
import math
import sys
from pathlib import Path
from mathutils import Quaternion, Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from logan_mesh_repair import repair_overlaps, attach_measured_fragments

source, output, blend = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(source).resolve()))
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and
          any(m.type == 'ARMATURE' and m.object == arm for m in o.modifiers)]
assert len(meshes) == 1 and len(arm.data.bones) == 65
for ob in list(bpy.data.objects):
    if ob not in meshes and ob != arm:
        bpy.data.objects.remove(ob, do_unlink=True)
mesh = meshes[0]
mesh.name = 'Logan'
arm.name = 'LoganRig'
original_vertices = len(mesh.data.vertices)
# Source QA measured 9 winding conflicts and 2 collapsed faces. Preserve the
# separate clothing/UV shells; welding them creates non-manifold intersections.
bm = bmesh.new()
bm.from_mesh(mesh.data)
bad = [f for f in bm.faces if f.calc_area() < 1e-10]
if bad:
    bmesh.ops.delete(bm, geom=bad, context='FACES_ONLY')
original_normals = {f: f.normal.copy() for f in bm.faces}
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
# An open clothing/UV shell has no globally-defined inside. Preserve its source
# orientation; correct inconsistent neighbours without flipping whole patches.
seen = set()
for face in bm.faces:
    if face in seen:
        continue
    component, todo = [], [face]
    seen.add(face)
    while todo:
        current = todo.pop()
        component.append(current)
        for edge in current.edges:
            for other in edge.link_faces:
                if other not in seen:
                    seen.add(other)
                    todo.append(other)
    if sum(f.normal.dot(original_normals[f]) for f in component) < 0:
        bmesh.ops.reverse_faces(bm, faces=component)
loose = [e for e in bm.edges if not e.link_faces]
if loose:
    bmesh.ops.delete(bm, geom=loose, context='EDGES')
fragment_moves = attach_measured_fragments(bm)
overlaps_trimmed = repair_overlaps(bm)
bm.to_mesh(mesh.data)
bm.free()
mesh.data.update()
# Keep the source's asymmetric clothing and UVs; resize maps on this copy.
for im in bpy.data.images:
    if max(im.size) > 1024:
        ratio = 1024 / max(im.size)
        im.scale(round(im.size[0] * ratio), round(im.size[1] * ratio))
        im.pack()
for mat in mesh.data.materials:
    mat.use_backface_culling = False

def rotation(name, axis, angle):
    """Armature-space direction mapped into THIS bone's rest axes, not a foreign rig."""
    b = arm.pose.bones['mixamorig:' + name]
    local_axis = b.bone.matrix_local.to_3x3().inverted() @ Vector(axis)
    b.rotation_mode = 'QUATERNION'
    b.rotation_quaternion = Quaternion(local_axis.normalized(), angle)

def pose(phase, gesture=0.0, nod=0.0):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = Quaternion()
    # Rest T-pose -> relaxed arms. No root bob: the boots remain planted.
    rotation('LeftArm', (0, 1, 0), math.radians(70 - 42 * gesture))
    rotation('RightArm', (0, 1, 0), math.radians(-72))
    rotation('LeftForeArm', (0, 0, 1), math.radians(-12 - 18 * gesture))
    rotation('RightForeArm', (0, 0, 1), math.radians(10))
    rotation('Spine2', (1, 0, 0), 0.009 * math.sin(phase))
    rotation('Head', (1, 0, 0), nod + 0.008 * math.sin(phase))
    # Gentle finger curl, not clenched fists. Keep the gesturing index open.
    for side in ('Left', 'Right'):
        for finger in ('Index', 'Middle', 'Ring', 'Pinky'):
            for joint in (1, 2, 3):
                n = side + 'Hand' + finger + str(joint)
                angle = 0.14 if joint == 1 else 0.22
                if side == 'Left' and finger == 'Index':
                    angle *= 1 - gesture
                rotation(n, (0, 0, 1), angle * (-1 if side == 'Left' else 1))

sc = bpy.context.scene
sc.render.fps = 24
arm.animation_data_create()
for name, frames in [('Idle', 97), ('Greet', 61), ('Point', 73), ('Approve', 49)]:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data.action = action
    for f in range(1, frames + 1, 3):
        u = (f - 1) / (frames - 1)
        gesture = math.sin(math.pi * u) ** 2 if name in ('Greet', 'Point') else 0.0
        nod = 0.07 * math.sin(2 * math.pi * u) if name == 'Approve' else 0.0
        pose(2 * math.pi * u, gesture, nod)
        for pb in arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=f, group=pb.name)
    action.use_cyclic = name == 'Idle'
arm.animation_data.action = bpy.data.actions['Idle']
sc.frame_set(1)
sc.frame_start, sc.frame_end = 1, 97
bpy.ops.object.select_all(action='DESELECT')
for ob in [arm, mesh]:
    ob.select_set(True)
bpy.context.view_layer.objects.active = arm
Path(output).parent.mkdir(parents=True, exist_ok=True)
Path(blend).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(blend).resolve()))
bpy.ops.export_scene.gltf(filepath=str(Path(output).resolve()), export_format='GLB',
    use_selection=True, export_apply=False, export_yup=True, export_animations=True,
    export_animation_mode='ACTIONS', export_skins=True, export_influence_nb=4,
    export_def_bones=False, export_force_sampling=False, export_frame_range=False,
    export_image_format='JPEG', export_jpeg_quality=88)
print(json.dumps({'asset':output, 'source_vertices':original_vertices, 'vertices':len(mesh.data.vertices), 'bones':65,
                  'overlaps_trimmed':overlaps_trimmed, 'fragment_moves':fragment_moves,
                  'clips':['Idle','Greet','Point','Approve'], 'bytes':Path(output).stat().st_size}))
