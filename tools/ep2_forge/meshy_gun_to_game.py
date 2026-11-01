"""Founder's Meshy gun GLBs (gun + Lil Blunt's gloved hands, 2026-11-01) -> game-weight first-person models.

Headless only:  blender -b --factory-startup -P tools/ep2_forge/meshy_gun_to_game.py -- <src.glb> <out.glb> <real_length_m> [tris]

Meshy hands us ~500-800k triangles with 8K/4K textures (~70 MB) and the gun yawed at the reference photo's 3/4 angle. This:
  1. shrinks the textures (base colour 1024, normal / metal-rough 512, JPEG),
  2. finds the gun's long axis by PCA over the NON-sleeve geometry (the green leafy sleeve is excluded by its texture colour)
     and turns it so the muzzle points Blender -Y with +Z up (= game muzzle +Z, +Y up after the glTF export),
  3. scales the gun to its real length, puts the origin on the barrel line at the gun's middle,
  4. decimates to the triangle budget and writes a GLB, then prints ANCHORS (game frame) for Ep2ArmoryGunView.
"""
import bpy, bmesh, sys, colorsys, math
import numpy as np
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, LENGTH = argv[0], argv[1], float(argv[2])
TRIS = int(argv[3]) if len(argv) > 3 else 24000

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
obj = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
bpy.context.view_layer.objects.active = obj
for o in bpy.context.scene.objects:
    o.select_set(o == obj)
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# 1. textures
base = None
for mat in obj.data.materials:
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            is_base = any(l.to_socket == bsdf.inputs['Base Color'] for l in n.outputs[0].links)
            s = 1024 if is_base else 512
            if is_base:
                base = n.image
            if n.image.size[0] > s:
                n.image.scale(s, s)
S = base.size[0]
px = np.array(base.pixels[:], dtype=np.float32).reshape(S, S, 4)

# 2. sleeve faces (leafy green) are left out of the axis fit
bm = bmesh.new()
bm.from_mesh(obj.data)
uv = bm.loops.layers.uv.active
pts = []
for f in bm.faces:
    u = sum((l[uv].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
    x = min(S - 1, max(0, int(u.x * S)))
    y = min(S - 1, max(0, int(u.y * S)))
    h, s, v = colorsys.rgb_to_hsv(*px[y, x, :3])
    if 65 <= h * 360 <= 120 and s > 0.3 and v > 0.18:
        continue
    pts.append(f.calc_center_median())
P = np.array([tuple(p) for p in pts])
c = P.mean(axis=0)
w, V = np.linalg.eigh(np.cov((P - c).T))
a = Vector(V[:, np.argmax(w)]).normalized()
if a.x > 0:                        # Meshy's side view shows the muzzle at -X
    a = -a
rot = a.rotation_difference(Vector((0, -1, 0))).to_matrix().to_4x4()
bm.free()
obj.data.transform(Matrix.Translation(-Vector(c)))
obj.data.transform(rot)
# roll: the receiver top must be +Z. After the yaw the sleeve (hands) hangs BELOW the barrel: if its mean is above, flip.
co = np.array([v.co[:] for v in obj.data.vertices])
along = -co[:, 1]
span = along.max() - along.min()
k = LENGTH / span
obj.data.transform(Matrix.Scale(k, 4))
co *= k
along = -co[:, 1]
front = co[along > along.max() - 0.08 * span * k]
barrel_z = float(np.median(front[:, 2]))
if np.median(co[:, 2]) > barrel_z + 0.02:
    obj.data.transform(Matrix.Rotation(math.pi, 4, 'Y'))
    co = np.array([v.co[:] for v in obj.data.vertices])
    front = co[-co[:, 1] > (-co[:, 1]).max() - 0.08 * span * k]
    barrel_z = float(np.median(front[:, 2]))
obj.data.transform(Matrix.Translation(Vector((0, 0, -barrel_z))))
obj.data.update()

# 3. decimate
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > TRIS:
    m = obj.modifiers.new("dec", 'DECIMATE')
    m.ratio = TRIS / tris
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)
obj.name = "Gun"
obj.data.name = "Gun"

co = np.array([v.co[:] for v in obj.data.vertices])
g = lambda b: (round(float(b[0]), 3), round(float(b[2]), 3), round(float(-b[1]), 3))   # Blender -> game
muz = co[np.argmin(co[:, 1])]
print("ANCHOR muzzle", g((0, muz[1], 0)), "aabb_min", g(co.min(axis=0)), "aabb_max", g(co.max(axis=0)),
      "tris", sum(len(p.vertices) - 2 for p in obj.data.polygons))
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False, export_image_format='JPEG',
                          export_jpeg_quality=82, export_apply=True, export_animations=False)
