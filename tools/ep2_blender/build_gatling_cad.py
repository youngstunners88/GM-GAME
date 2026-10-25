"""THE COLT GATLING FROM CAD (founder 2026-10-25: "Colt Gatling - full quality pass - readable, period, not a trash prop").

  GATLING_CAD_OUT=<dir> freecadcmd tools/ep2_cad/gatling_cad.py                 # 1. the solids -> <dir>/<piece>__<Material>.obj
  blender -b --factory-startup -P tools/ep2_blender/build_gatling_cad.py -- --cad <dir> [--out src/episode2/extras/armory/gatling_post.glb] [--shots d]

Assembles the FreeCAD parts into gatling_post.glb with EXACTLY the node tree, pivots and marker empties the game drives (Ep2GatlingPost,
skill ep2-armory-guns): Gatling_Post -> Gat_Yaw -> Gat_Pitch -> {Gat_Barrels, Gat_Crank}, Gat_Muzzle / Gat_Eye / Gat_Eject / Gat_Sign, plus the
firing yard's Range_Plate (+ Range_Swing) and Range_Bale (unchanged, from armory_kit). Materials keep the kit's names (GunSteel, Brass,
Iron, GunWood, Stone, Sand, Rope, Planks, Trim, DarkWood) so Ep2Pbr dresses them with the photo-scanned PBR sets in the engine.
Shading: merged seams, smooth by angle (sharp CAD edges stay crisp), weighted normals. Prints @@{json}.
"""
import glob
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import armory_kit as K  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CAD = argv[argv.index("--cad") + 1] if "--cad" in argv else ""
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/armory/gatling_post.glb"
SHOTS = argv[argv.index("--shots") + 1] if "--shots" in argv else ""
if not CAD or not glob.glob(os.path.join(CAD, "*.obj")):
    sys.exit("build_gatling_cad: --cad <dir> with the FreeCAD OBJs is required (run tools/ep2_cad/gatling_cad.py first)")

bpy.ops.wm.read_factory_settings(use_empty=True)
K.MATS.clear()
K.standard_materials()
SC = bpy.context.scene

# (piece in the CAD files, node name, parent node, pivot in the PARENT's game frame)
PIECES = [
    ("post", "Gatling_Post", None, (0.0, 0.0, 0.0)),
    ("yaw", "Gat_Yaw", "Gatling_Post", (0.0, K.GAT_YAW_Y, 0.0)),
    ("pitch", "Gat_Pitch", "Gat_Yaw", (0.0, K.GAT_TRUNNION_Y, 0.0)),
    ("barrels", "Gat_Barrels", "Gat_Pitch", (K.GAT_BARREL_X, 0.0, 0.0)),
    ("crank", "Gat_Crank", "Gat_Pitch", K.GAT_CRANK),
]
EMPTIES = {   # node -> [(name, position in that node's game frame)] - the same markers as armory_kit (the game reads them)
    "Gat_Pitch": [("Gat_Muzzle", (K.GAT_BARREL_X + 1.0, 0.0, 0.0)), ("Gat_Eye", (-0.86, 0.66, 0.0)), ("Gat_Eject", (0.10, 0.02, 0.145))],
    "Gatling_Post": [("Gat_Sign", (-2.44, 0.98, 0.0))],
}


def g(p):
    """game (x, y, z) -> blender (x, -z, y)"""
    return (p[0], -p[2], p[1])


def import_part(path):
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=path, forward_axis="NEGATIVE_Z", up_axis="Y")      # the OBJ is in the game frame (y up)
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    return new


nodes = {}
report = {"pieces": {}}
for piece, name, parent, pivot in PIECES:
    root = bpy.data.objects.new(name, None)
    SC.collection.objects.link(root)
    root.location = g(pivot)
    if parent:
        root.parent = nodes[parent]
    nodes[name] = root
    parts = []
    for path in sorted(glob.glob(os.path.join(CAD, piece + "__*.obj"))):
        mat_name = os.path.basename(path)[len(piece) + 2:-4]
        for ob in import_part(path):
            ob.data.materials.clear()
            ob.data.materials.append(K.MATS[mat_name])
            parts.append(ob)
    if not parts:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    geo = bpy.context.view_layer.objects.active
    geo.name = name + "_geo"
    geo.data.name = name + "_mesh"
    # the geometry was written around this piece's pivot: it sits at the root's origin
    geo.parent = root
    geo.location = (0.0, 0.0, 0.0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.00015)            # FreeCAD writes each CAD face separately: weld the seams
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(32), keep_sharp_edges=True)   # (no weighted normals: FreeCAD's long thin
    # triangles on turned parts streak under face-area weighting)
    tris = sum(len(p.vertices) - 2 for p in geo.data.polygons)
    report["pieces"][name] = {"tris": tris, "materials": [m.name for m in geo.data.materials]}

for node, marks in EMPTIES.items():
    for ename, pos in marks:
        e = bpy.data.objects.new(ename, None)
        e.empty_display_size = 0.2
        SC.collection.objects.link(e)
        e.parent = nodes[node]
        e.location = g(pos)

# the firing yard's targets, unchanged (armory_kit): a plate on chains and a straw bale
PL = K.Piece("Range_Plate")
K.range_plate_geo(PL)
plate_root, t5 = PL.build()
SW = K.Piece("Range_Swing")
K.range_swing_geo(SW)
swing_root, t6 = SW.build(plate_root, (0.0, 1.70, 0.0))
BL = K.Piece("Range_Bale")
K.range_bale_geo(BL)
bale_root, t7 = BL.build()
plate_root.location.x = 3.0
bale_root.location.x = 6.0

for o in SC.objects:
    o.select_set(False)


def sel(o):
    o.select_set(True)
    for c in o.children:
        sel(c)


for r in (nodes["Gatling_Post"], plate_root, bale_root):
    sel(r)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True, use_selection=True,
                          export_extras=False, export_cameras=False, export_lights=False)
report["tris"] = sum(p["tris"] for p in report["pieces"].values())
report["targets_tris"] = t5 + t6 + t7
report["bytes"] = os.path.getsize(OUT)

if SHOTS:
    os.makedirs(SHOTS, exist_ok=True)
    sc = SC
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.62, 0.70, 0.78)
    from mathutils import Vector

    def shot(fname, pos, target, lens=45):
        cam.data.lens = lens
        cam.location = g(pos)
        cam.rotation_euler = (Vector(g(target)) - Vector(g(pos))).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(SHOTS, fname + ".png")
        bpy.ops.render.render(write_still=True)

    shot("gatling_front34", (3.0, 2.0, 3.0), (0.3, 1.35, 0.0), 40)
    shot("gatling_side", (0.4, 1.6, 3.2), (0.4, 1.45, 0.0), 45)
    shot("gatling_gunner", (-1.45, 2.1, 0.0), (1.2, 1.45, 0.0), 38)
    shot("gatling_breech", (-0.9, 1.75, 0.9), (0.05, 1.45, 0.05), 50)
    shot("gatling_muzzle", (2.6, 1.55, 0.7), (1.4, 1.42, 0.0), 55)
print("@@" + json.dumps({"ok": True, **report}))
