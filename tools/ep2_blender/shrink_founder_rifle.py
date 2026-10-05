"""Shrink + normalise the founder's Winchester GLB (skill ep2-founder-weapon-glb).
    python3 tools/ep2_blender/shrink_founder_rifle.py /tmp/w.glb src/episode2/assets/weapons/winchester_1886_founder.glb
Imports the Tripo rifle, bakes the skin pose into the mesh, drops the Mixamo rig + helper, orients the barrel along +Z
(muzzle +Z, stock -Z, ~1.2 m, centred), decimates to ~10k tris, downsizes textures, exports a skin-less GLB."""
import math
import os
import sys

import bpy
from mathutils import Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2] if "--" in sys.argv else sys.argv[1:3]
TRIS = 10000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
mesh = [o for o in bpy.data.objects if o.type == "MESH" and len(o.data.polygons) > 1000][0]
for o in list(bpy.data.objects):
    if o is not mesh:
        bpy.data.objects.remove(o, do_unlink=True)
mesh.parent = None
for m in list(mesh.modifiers):
    mesh.modifiers.remove(m)                       # drop Armature modifier: use the rest geometry
mesh.vertex_groups.clear()
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
mesh.matrix_world.identity()
# --- measure principal axes of the vertex cloud (PCA) -> barrel = longest axis
import numpy as np
v = np.array([tuple(x.co) for x in mesh.data.vertices])
c = v.mean(axis=0)
u, s, vt = np.linalg.svd(v - c, full_matrices=False)
axes = vt  # rows: principal directions
print("PCA stdev", s / math.sqrt(len(v)), "extent", v.max(0) - v.min(0))
long_axis = Vector(axes[0])
proj = (v - c) @ axes[0]
# muzzle = the END WITH THE SMALLER CROSS-SECTION (a thin barrel; the other end is the thick arms/cuffs)
def spread(mask):
    q = (v[mask] - c) - np.outer(proj[mask], axes[0])
    return float(np.sqrt((q ** 2).sum(1).mean()))
hi = proj > np.percentile(proj, 92)
lo = proj < np.percentile(proj, 8)
print("end spreads hi/lo", spread(hi), spread(lo))
long_axis = Vector(axes[0])
if spread(hi) > spread(lo):
    long_axis = -long_axis          # +long_axis points toward the thin muzzle end
# up: the lever loop and the hands hang BELOW the rifle, so the side with the longer vertex tail is "down"
perp = Vector(axes[2])
side = (v - c) @ axes[2]
if abs(side.min()) > abs(side.max()):
    perp = -perp                    # perp points toward the side with the shorter tail = up
up_guess = perp
y = -long_axis.normalized()                          # Blender +Y toward the STOCK; muzzle toward Blender -Y (= Godot +Z)
z = (up_guess - y * up_guess.dot(y)).normalized()
x = y.cross(z).normalized()
from mathutils import Matrix
rot = Matrix((x, y, z)).to_4x4()                     # rows = new axes: new coord = (x.p, y.p, z.p)
mesh.data.transform(rot)
# measured by render (tools/ep2_shots/glb_axes_shot.tscn): PCA leaves the muzzle at Godot -Z and the receiver on its
# side (up = -X). Turn it: Godot Z -90 deg then Godot Y 180 deg == Blender Y +90 then Blender Z 180.
mesh.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
mesh.data.transform(Matrix.Rotation(math.radians(180), 4, "Z"))
mesh.data.update()
v2 = np.array([tuple(p.co) for p in mesh.data.vertices])
ext = v2.max(0) - v2.min(0)
scale = 1.2 / ext[1]
mesh.data.transform(Matrix.Scale(scale, 4))
v3 = np.array([tuple(p.co) for p in mesh.data.vertices])
ctr = (v3.max(0) + v3.min(0)) / 2
mesh.data.transform(Matrix.Translation(-Vector(ctr)))
# which way is up? the sight/hammer side has more bounding extent above centre than below the receiver; leave as PCA's
d = mesh.dimensions
print("after: dims (x,y,z)", [round(a, 3) for a in d])
# --- decimate
dm = mesh.modifiers.new("dec", "DECIMATE")
dm.ratio = min(1.0, TRIS / len(mesh.data.polygons) / 1.0) * 2 / 2
bpy.ops.object.modifier_apply(modifier="dec")
print("tris after", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
# --- textures
for img in bpy.data.images:
    if img.size[0] > 1024:
        n = img.name.lower()
        target = 512 if "normal" in n or "rough" in n or "metal" in n else 1024
        img.scale(target, target)
        print("scaled", img.name[:30], "->", target)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_image_format="JPEG",
                          export_jpeg_quality=80, export_materials="EXPORT")
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
