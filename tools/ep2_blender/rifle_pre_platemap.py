# diagnostic pre-hook: ASCII depth map of the camera-side (-Y) surface over the receiver, to locate the engraved side plate
from mathutils import Vector
from mathutils.bvhtree import BVHTree
exec(open("tools/ep2_blender/rifle_surgery.py").read().split("# 4. GM logo decal")[0], globals())   # run the geometry edits (no decal) so the map matches the final mesh
bvh = BVHTree.FromObject(rifle, bpy.context.evaluated_depsgraph_get())
xs = [round(-0.26 + 0.02 * i, 2) for i in range(0, 22)]
log("PLATEMAP y*1000 of first hit from -Y; columns x =", xs[0], "..", xs[-1], "step .02")
for zi in range(62, 24, -2):
    z = zi / 100.0
    row = []
    for x in xs:
        h = bvh.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))
        row.append("%4d" % round(h[0].y * 1000) if h[0] else "   .")
    log("z=%.2f" % z, "".join(row))
