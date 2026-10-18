"""List connected islands of the hero revolver GLB with bbox + metal fraction (decide gun vs glove).
blender -b --python tools/ep2_blender/revolver_islands.py -- <hero.glb>
"""
import sys

import bmesh
import bpy
import numpy as np

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[sys.argv.index("--") + 1])
obj = max([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: len(o.data.polygons))
me = obj.data
bm = bmesh.new()
bm.from_mesh(me)
seen = set()
rows = []
for f in bm.faces:
    if f.index in seen:
        continue
    stack, isl = [f], []
    seen.add(f.index)
    while stack:
        c = stack.pop()
        isl.append(c)
        for e in c.edges:
            for n in e.link_faces:
                if n.index not in seen:
                    seen.add(n.index)
                    stack.append(n)
    vs = {v.index: v.co for c in isl for v in c.verts}
    xs = np.array([v.x for v in vs.values()])
    ys = np.array([v.y for v in vs.values()])
    zs = np.array([v.z for v in vs.values()])
    rows.append((len(isl), xs.min(), xs.max(), ys.min(), ys.max(), zs.min(), zs.max()))
rows.sort(reverse=True)
print("ISLANDS", len(rows))
for r in rows[:25]:
    print("ISL faces=%d x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]" % r)
