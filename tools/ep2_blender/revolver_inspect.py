"""Inspect the founder's Tripo golden revolver GLB (headless).

blender -b --python tools/ep2_blender/revolver_inspect.py -- <glb>
Prints object/tri counts, bounding box, materials and texture sizes.
"""
import sys
import bpy

glb = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
tris = 0
lo = [1e9] * 3
hi = [-1e9] * 3
for o in bpy.context.scene.objects:
    if o.type != "MESH":
        continue
    tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    for c in o.bound_box:
        w = o.matrix_world @ __import__("mathutils").Vector(c)
        for i in range(3):
            lo[i] = min(lo[i], w[i])
            hi[i] = max(hi[i], w[i])
    print("OBJ", o.name, "verts", len(o.data.vertices), "uv", len(o.data.uv_layers),
          "mats", [m.name for m in o.data.materials if m])
print("TRIS", tris)
print("BBOX", [round(v, 3) for v in lo], [round(v, 3) for v in hi])
for im in bpy.data.images:
    print("IMG", im.name, tuple(im.size))
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    for n in m.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            print("MAT", m.name, "metal", n.inputs["Metallic"].default_value,
                  "rough", n.inputs["Roughness"].default_value,
                  "linked", [i.name for i in n.inputs if i.is_linked])
