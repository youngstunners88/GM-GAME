"""THE ARMORY'S RACK GUNS (founder 2026-11-08: "upstairs and downstairs must feature those models", no placeholder sticks).

Headless bpy:  blender -b --factory-startup -P tools/ep2_blender/build_rack_guns.py -- [--out src/episode2/extras/armory/rack_guns.glb]

The founder's own weapon GLBs, laid on one axis and cut to a rack budget, so ~120 of them can fill both floors in the web build (the
Compatibility renderer draws every triangle of a mesh at any distance: it has no mesh LODs). Nothing here is a new gun - each piece is a
decimated copy of a founder model. The GLB carries GEOMETRY ONLY (no images): Ep2ArmoryRacks puts each source GLB's own materials back
on at load, so the textures are the ones already shipped and nothing is stored twice.

  Rack_<family>   ~1.4k tris (long guns) / ~0.7k (sidearms): the wall racks, barrels and pegboards
  Near_<family>   ~4k / ~2.5k: the glass cases, the counter, the benches and the fascia, seen up close

Every piece: muzzle +x, top +y, side faces +z (game frame), origin at its bounding-box centre (the Gatling: centre of its feet), real
length in metres. Writes tools/ep2_blender/rack_guns_dims.json (each family's x/y/z extents) for build_armory2.py to seat them.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/armory/rack_guns.glb"
DIMS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "rack_guns_dims.json")
SC = "src/episode2/extras/armory/showcase/"
AW = "src/episode2/assets/weapons/armory/"

# family: source GLB (the same file Ep2ArmoryRacks.SOURCES takes materials from), Blender-frame yaw that turns its muzzle to +x (measured
# from ortho renders 2026-11-08), real overall length (m), triangle targets (rack, near)
FAMILIES = {
    "winchester": (SC + "winchester_1886.glb", 180.0, 1.05, 1400, 4000),
    "sharps":     (SC + "sharps.glb", 135.0, 1.22, 1400, 4000),
    "coach":      (SC + "coach_shotgun.glb", 180.0, 0.95, 1400, 4000),
    "tommy":      (SC + "golden_tommy.glb", 180.0, 0.85, 1400, 4000),
    "mp18":       (SC + "machine_gun.glb", 180.0, 0.82, 1400, 4000),
    "bergmann":   (AW + "bergmann_mp18.glb", 90.0, 0.82, 1400, 3000),
    "borchardt":  (SC + "borchardt.glb", 180.0, 0.36, 700, 2500),
    "remington":  (SC + "gold_remington.glb", 180.0, 0.33, 700, 2500),
    "goldrev":    (AW + "golden_revolver_gun.glb", 180.0, 0.33, 700, 2500),
    "rem75":      (AW + "remington_1875_gold.glb", 90.0, 0.33, 700, 2500),
    "longbow":    (AW + "bear_longbow.glb", None, 1.50, 2500, 2500),
    "gatling":    (AW.replace("weapons/armory/", "hideout/") + "gatling.glb", 180.0, 1.35, 4300, 4300),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
keep = []
dims = {}


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


for fam, (path, yaw, length, t_rack, t_near) in FAMILIES.items():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.data = o.data.copy()          # instanced data across nodes: make each one real before applying
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for o in [o for o in bpy.data.objects if o not in before and o != ob]:     # the import's empties (join already took the meshes)
        bpy.data.objects.remove(o, do_unlink=True)
    # lay it on the common axis (Blender frame: muzzle +x, top +z; glTF export makes that game +x / +y)
    if yaw is None:                      # the longbow stands along z with its curve in y: lay it along x, its curve in the wall's plane
        rot = Matrix.Rotation(math.radians(90.0), 4, "X") @ Matrix.Rotation(math.radians(-90.0), 4, "Y")
    else:
        rot = Matrix.Rotation(math.radians(yaw), 4, "Z")
    ob.data.transform(rot)
    vs = [v.co for v in ob.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = (lo + hi) / 2
    if fam == "gatling":
        c.z = lo.z                       # stands on its feet
    s = length / (hi.x - lo.x)
    ob.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-c))
    d = (hi - lo) * s
    dims[fam] = {"x": round(d.x, 4), "y": round(d.z, 4), "z": round(d.y, 4)}      # game frame: y up, z out of the side
    src_tris = tri_count(ob)
    for tag, target in (("Rack", t_rack), ("Near", t_near)):
        dup = ob.copy()
        dup.data = ob.data.copy()
        dup.name = "%s_%s" % (tag, fam)
        dup.data.name = dup.name
        bpy.context.scene.collection.objects.link(dup)
        if src_tris > target:
            m = dup.modifiers.new("dec", "DECIMATE")
            m.decimate_type = "COLLAPSE"
            m.ratio = target / src_tris
            m.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = dup
            bpy.ops.object.modifier_apply(modifier=m.name)
        dup.location = (0.0, 0.0, 0.0)
        keep.append(dup)
        print("@@GUN %s %s %d -> %d tris" % (tag, fam, src_tris, tri_count(dup)))
    bpy.data.objects.remove(ob, do_unlink=True)

# spread them out in the file (the game reads each mesh, never these positions)
for i, o in enumerate(keep):
    o.location = (0.0, i * 0.5, 0.0)
bpy.ops.object.select_all(action="DESELECT")
for o in keep:
    o.select_set(True)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                          export_image_format="NONE", export_materials="EXPORT", export_cameras=False, export_lights=False,
                          export_extras=False, export_animations=False)
with open(DIMS, "w") as f:
    json.dump(dims, f, indent=1, sort_keys=True)
    f.write("\n")
print("@@{\"ok\": true, \"out\": \"%s\", \"bytes\": %d, \"pieces\": %d}" % (OUT, os.path.getsize(OUT), len(keep)))
