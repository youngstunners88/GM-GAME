"""Founder Meshy props (plants, trees) -> game weight, kept upright and at the model's own origin.
blender -b --factory-startup -P tools/ep2_forge/meshy_prop_to_game.py -- <src.glb> <out.glb> <height_m> [tris] [tex]
Scales so the model is <height_m> tall with its base on y = 0, decimates to <tris> (default 12000), textures to <tex> px (base) and half that
for normal / metal-rough, JPEG. Prints the result's size.
Foliage is loose leaf triangles, which an edge-collapse cannot reduce past a point (47k on the Grove) and an aggressive simplify shreds: whatever is
still over budget after the decimate is thinned evenly, and the surviving leaves grow (at most 2x) so the canopy keeps its coverage.
"""
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, H = a[0], a[1], float(a[2])
TRIS = int(a[3]) if len(a) > 3 else 12000
TEX = int(a[4]) if len(a) > 4 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in bpy.context.scene.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
for mat in obj.data.materials:
    if mat is None or not mat.use_nodes:
        continue
    b = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    for n in mat.node_tree.nodes:
        if n.type == 'TEX_IMAGE' and n.image is not None:
            base = b is not None and any(l.to_socket == b.inputs['Base Color'] for l in n.outputs[0].links)
            s = TEX if base else TEX // 2
            if n.image.size[0] > s:
                n.image.scale(s, s)
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > TRIS:
    m = obj.modifiers.new("dec", 'DECIMATE')
    m.ratio = TRIS / tris
    m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)
tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
if tris > TRIS:
    keep = TRIS / tris
    grow = min(2.0, math.sqrt(1.0 / keep))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    acc = 0.0
    drop = []
    for f in bm.faces:
        acc += keep
        if acc >= 1.0:           # an even stride: the canopy thins uniformly, never in patches
            acc -= 1.0
            c = f.calc_center_median()
            for v in f.verts:
                if len(v.link_faces) == 1:
                    v.co = c + (v.co - c) * grow
        else:
            drop.append(f)
    bmesh.ops.delete(bm, geom=drop, context='FACES_ONLY')
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    print("PROP_THINNED", tris, "keep", round(keep, 3), "grow", round(grow, 2))
co = [v.co for v in obj.data.vertices]
mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
k = H / max(mx.z - mn.z, 1e-6)
obj.data.transform(Matrix.Translation(Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))))
obj.data.transform(Matrix.Scale(k, 4))
obj.data.update()
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_image_format='JPEG', export_jpeg_quality=82, export_animations=False)
print("PROP_OK", OUT, "tris", sum(len(p.vertices) - 2 for p in obj.data.polygons), "size", [round(x * k, 2) for x in (mx - mn)])
