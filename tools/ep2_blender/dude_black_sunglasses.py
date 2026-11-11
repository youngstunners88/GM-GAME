# Dude's sunglasses, black (founder 2026-11-11: "Dude's sunglasses need to be black").
#
# The founder's Tripo model (src/episode2/assets/town/dude_stable_owner.glb) has real black frames, but the lenses are the face mesh
# itself with a baked texture that is half skin, half jagged black patches. This paints every texel seen THROUGH the two lens
# openings from the front solid black, in the model's own base-colour texture - no geometry, rig, clip or UV is touched.
#
#   blender -b --factory-startup -P tools/ep2_blender/dude_black_sunglasses.py -- <dude.glb> <base_colour_in.png> <base_colour_out.png>
#
# Headless only (skill blender-headless-render-safety). The GLB's image is swapped afterwards by tools/ep2_blender/glb_swap_image.py.
import bpy, sys, mathutils
import numpy as np
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
glb, tex_in, tex_out = argv[0], argv[1], argv[2]

# The lens openings in the model's rest pose, front view (x right, z up, metres; the model is 1 m tall and faces -Y).
# Measured on an orthographic front render 0.08 m across 800 px centred on (-0.025, 0.783): px -> (cx + (px/800-0.5)*0.08, cz - (py/800-0.5)*0.08).
def m(px, py):
    return (-0.025 + (px / 800.0 - 0.5) * 0.08, 0.783 - (py / 800.0 - 0.5) * 0.08)
LENSES = [
    [m(62, 322), m(352, 322), m(372, 352), m(250, 540), m(88, 516)],        # his right eye (image left)
    [m(455, 320), m(745, 312), m(735, 400), m(692, 512), m(548, 500)],      # his left eye
]
BLACK = (0.012, 0.012, 0.014)       # near-black with a breath of blue: a dark lens, not a hole in the picture
STEP = 0.00004                      # ray spacing (m): finer than a texel of the face on the 1024 atlas

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
ob = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
# The mesh AS POSED on import (the glTF's first clip at frame 0), not its raw rest coordinates: the lens openings above were measured
# on a render of that pose, and the head sits ~10 cm away from where the undeformed vertices put it.
ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = ev.to_mesh()
mesh.calc_loop_triangles()
verts = [ev.matrix_world @ v.co for v in mesh.vertices]
tris = [tuple(t.vertices) for t in mesh.loop_triangles]
bvh = BVHTree.FromPolygons(verts, tris)
uv = mesh.uv_layers.active.data

img = bpy.data.images.load(tex_in)
w, h = img.size
px = np.empty(w * h * 4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(h, w, 4)

def inside(poly, x, z):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]; xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            hit = not hit
        j = i
    return hit

painted = np.zeros((h, w), dtype=bool)
rays = 0
for poly in LENSES:
    xs = [p[0] for p in poly]; zs = [p[1] for p in poly]
    x = min(xs)
    while x <= max(xs):
        z = min(zs)
        while z <= max(zs):
            if inside(poly, x, z):
                loc, nor, idx, dist = bvh.ray_cast(mathutils.Vector((x, -2.0, z)), mathutils.Vector((0.0, 1.0, 0.0)))
                if loc is not None:
                    rays += 1
                    lt = mesh.loop_triangles[idx]
                    a, b, c = (verts[i] for i in lt.vertices)
                    ua, ub, uc = (uv[l].uv for l in lt.loops)
                    bary = mathutils.geometry.barycentric_transform(loc, a, b, c, mathutils.Vector((ua.x, ua.y, 0)), mathutils.Vector((ub.x, ub.y, 0)), mathutils.Vector((uc.x, uc.y, 0)))
                    tx = min(w - 1, max(0, int(bary.x * w))); ty = min(h - 1, max(0, int(bary.y * h)))
                    painted[ty, tx] = True
            z += STEP
        x += STEP

# one texel of bleed so bilinear filtering and the mip chain do not pull skin back in at the lens edge
grown = painted.copy()
grown[1:, :] |= painted[:-1, :]; grown[:-1, :] |= painted[1:, :]
grown[:, 1:] |= painted[:, :-1]; grown[:, :-1] |= painted[:, 1:]
px[grown, 0] = BLACK[0]; px[grown, 1] = BLACK[1]; px[grown, 2] = BLACK[2]
img.pixels.foreach_set(px.reshape(-1))
img.filepath_raw = tex_out
img.file_format = "PNG"
img.save()
print("DUDE_SUNGLASSES rays=%d texels=%d of %d (%.2f%% of the atlas) -> %s" % (rays, int(grown.sum()), w * h, 100.0 * grown.sum() / (w * h), tex_out))
