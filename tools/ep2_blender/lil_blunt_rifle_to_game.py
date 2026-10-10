"""LIL BLUNT'S RIFLE -> the game's first-person rifle (founder 2026-10-10: "The rifle that I gave you is Lil Blunt's rifle, you can
see that his arm is green. I want you to fix the issue of the logo on it, but don't fuck it up like before"; skills ep2-winchester-logo,
ep2-founder-weapon-glb).

Input: the founder's Tripo "rifle 3d.glb" AFTER tools/ep2_forge/repaint_rifle_logo.py (texture-only logo fix + dish flatten).
Output: src/episode2/assets/weapons/winchester_1886_founder.glb in the frame the viewmodel code already expects of that file
(Ep2ViewHands.attach, interlude_base._hold_rifle): muzzle +Z, up +Y, 1.2 m long, barrel axis on x = 0, the GM logo on the +X side
(the side the first-person camera sees once the rifle node is yawed PI) at the old logo's z, and ~22k triangles.

Raw frame of the Tripo file (measured): muzzle at -X, up +Y, the logo the founder's reference shows on +Z, 0.996 m long.
So: rotate +90 deg about Y (-X -> +Z, +Z -> +X), scale to 1.2 m, centre the barrel laterally, slide the receiver to the old logo z.

    python3 tools/ep2_blender/lil_blunt_rifle_to_game.py -- --src .farm/drive_1010/rifle_logo_fixed.glb \
        --out src/episode2/assets/weapons/winchester_1886_founder.glb [--tris 22000] [--logo-z -0.246]
"""
import math
import sys

import bpy  # noqa: F401  (bpy before bmesh)
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = arg("--src", ".farm/drive_1010/rifle_logo_fixed.glb")
OUT = arg("--out", "src/episode2/assets/weapons/winchester_1886_founder.glb")
TRIS = int(arg("--tris", "22000"))
LOGO_Z = float(arg("--logo-z", "-0.246"))
RAW_LOGO = Vector((0.2636, 0.2247, 0.0657))          # glTF frame, +Z side (logo_report.json side 1)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in list(bpy.data.objects):
    if o.type not in ("MESH",):
        bpy.data.objects.remove(o)
ob = meshes[0]
bpy.context.view_layer.objects.active = ob
ob.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def g2b(v):            # glTF (x, y, z) -> Blender (x, -z, y)
    return Vector((v[0], -v[2], v[1]))


me = ob.data
co = [v.co.copy() for v in me.vertices]
# the gun's own axis in plan (Blender XY): PCA of the vertices ABOVE the hanging arm (Blender z > 0.15) - the Tripo rifle is turned
# ~17 deg in plan, so a flat 90 deg turn put the logo 0.39 m off the barrel line (first build)
import numpy as np
P = np.array([[c.x, c.y, c.z] for c in co])
gun = P[P[:, 2] > 0.15]
cxy = gun[:, :2].mean(0)
_, _, vt = np.linalg.svd(gun[:, :2] - cxy, full_matrices=False)
ax = vt[0]
proj = (gun[:, :2] - cxy) @ ax
# the muzzle is the THIN end: compare the cross-section spread of the 8 cm at each end
lo_end = gun[proj < proj.min() + 0.08]; hi_end = gun[proj > proj.max() - 0.08]
if np.ptp(lo_end[:, 2]) < np.ptp(hi_end[:, 2]):
    ax = -ax                                            # make ax point from the muzzle to the stock... flip so +ax = stock end
    proj = -proj
# now -ax points to the muzzle; it must end on glTF +Z = Blender -Y
muzzle_dir = -ax
yaw = math.atan2(-1.0, 0.0) - math.atan2(muzzle_dir[1], muzzle_dir[0])
length = float(proj.max() - proj.min())
s = 1.2 / length
rot = Matrix.Rotation(yaw, 4, "Z")
M = Matrix.Scale(s, 4) @ rot
# barrel axis: the gun vertices within 8 cm of the muzzle end
muz = gun[proj > proj.max() - 0.08] if False else gun[(gun[:, :2] - cxy) @ muzzle_dir > ((gun[:, :2] - cxy) @ muzzle_dir).max() - 0.08]
bar = Vector(muz.mean(0).tolist())
logo_b = g2b(RAW_LOGO)
logo_after = M @ logo_b
bar_after = M @ bar
tip_after = bar_after
T = Matrix.Translation(Vector((-bar_after.x, (-LOGO_Z) - logo_after.y, 0.0)))
me.transform(T @ M)
me.update()
logo_final = T @ M @ logo_b
P2 = np.array([[v.co.x, v.co.y, v.co.z] for v in me.vertices])
print("yaw deg", round(math.degrees(yaw), 2), "scale", round(s, 4), "length", round(length, 3),
      "glTF z range", round(float(-P2[:, 1].max()), 3), round(float(-P2[:, 1].min()), 3),
      "muzzle glTF z", round(float(-(T @ M @ bar).y), 3),
      "logo glTF (x,y,z)", (round(logo_final.x, 3), round(logo_final.z, 3), round(-logo_final.y, 3)))
# decimate (keeps UVs; the logo is in the texture, the plate under it is flat)
n0 = len(me.polygons)
tris0 = sum(len(p.vertices) - 2 for p in me.polygons)
if tris0 > TRIS:
    dm = ob.modifiers.new("dec", "DECIMATE")
    dm.ratio = TRIS / tris0
    dm.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=dm.name)
tris1 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
print("tris", tris0, "->", tris1)
# textures: albedo 2048 (the logo needs the texels), metal-rough / normal 1024, emission 512
for img in bpy.data.images:
    w, h = img.size
    nm = img.name.lower()
    tgt = 2048 if ("base" in nm or "color" in nm or w >= 4096) else (512 if "emis" in nm else 1024)
    if max(w, h) > tgt:
        img.scale(tgt, tgt)
    print("image", img.name, img.size[:])
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=False, export_texcoords=True, export_normals=True,
                          export_materials="EXPORT", export_image_format="AUTO", export_apply=True)
import os
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")
