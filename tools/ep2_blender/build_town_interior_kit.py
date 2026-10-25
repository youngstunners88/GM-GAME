"""THE TOWN'S INTERIOR FURNITURE FROM CAD (founder 2026-10-25: "Town interiors - more furnished furniture and subtle details (Certificate,
Saloon, Armory, Jail as touched)").

  TOWN_CAD_OUT=<dir> freecadcmd tools/ep2_cad/town_interior_cad.py                          # 1. the solids -> <dir>/<piece>__<Material>.obj
  blender -b --factory-startup -P tools/ep2_blender/build_town_interior_kit.py -- --cad <dir> \
      [--out src/episode2/extras/town/town_furniture.glb] [--shots <dir>]

One GLB, one root node per piece, every root at the origin (the game duplicates a root by name and places it): Twn_Bar, Twn_BackBar,
Twn_Table, Twn_Chair, Twn_PokerSet, Twn_TableDrinks, Twn_Piano, Twn_PianoStool, Twn_Spittoon, Twn_HangLamp, Twn_Chandelier, Twn_Clock,
Twn_ClockPendulum, Twn_HatRack, Twn_Counter, Twn_Pigeonholes, Twn_Desk, Twn_DeskLamp, Twn_DeskChair, Twn_Stove, Twn_WoodBox, Twn_Safe,
Twn_Bench, Twn_CoffeePot, Twn_Lantern, Twn_KeyRing, Twn_Bucket, Twn_TinPlate, Twn_Broom, Twn_Workbench, Twn_GunBoard. Each root holds one mesh
<root>_geo with one surface per material, named as the town kit names them (DarkWood, GunWood, Brass, Iron, Leather, Paper, Cloth, Mirror,
Bottle ... at the town kit's own values, so a CAD piece shows the brightness its old box did) so Ep2Pbr dresses it by name in the engine.
Shading as the CAD Gatling: merged seams, smooth by angle with sharp CAD edges kept. --shots renders a Workbench contact sheet.
Prints @@{json}.
"""
import glob
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(os.getcwd(), "tools", "ep2_blender"))     # run from the repo root
import armory_kit as K  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CAD = argv[argv.index("--cad") + 1] if "--cad" in argv else ""
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/town/town_furniture.glb"
SHOTS = argv[argv.index("--shots") + 1] if "--shots" in argv else ""
if not CAD or not glob.glob(os.path.join(CAD, "*.obj")):
    sys.exit("build_town_interior_kit: --cad <dir> with the FreeCAD OBJs is required (run tools/ep2_cad/town_interior_cad.py first)")

bpy.ops.wm.read_factory_settings(use_empty=True)
K.MATS.clear()
K.standard_materials()
# the town kit's own values where it has the name (build_town_kit.py), so a CAD piece reads as bright as the box it replaces
bpy.data.materials.remove(K.MATS.pop("Leather"))               # (re-made below at the town kit's value, keeping its plain name)
K.mat("Leather", (0.30, 0.16, 0.08), 0.6, 0.0)
K.mat("Mirror", (0.75, 0.75, 0.72), 0.05, 1.0)
K.mat("Bottle", (0.25, 0.14, 0.05), 0.15, 0.0)
for n, c, r, mt in [("BottleGreen", (0.05, 0.14, 0.06), 0.15, 0.0), ("Cork", (0.45, 0.32, 0.18), 0.85, 0.0), ("Label", (0.80, 0.72, 0.55), 0.9, 0.0),
                    ("Opal", (0.88, 0.86, 0.80), 0.35, 0.0), ("Ivory", (0.82, 0.78, 0.68), 0.35, 0.0), ("Ebony", (0.006, 0.005, 0.005), 0.3, 0.0),
                    ("Felt", (0.05, 0.16, 0.08), 0.95, 0.0), ("Cane", (0.30, 0.20, 0.10), 0.85, 0.0), ("HatFelt", (0.28, 0.22, 0.16), 0.95, 0.0),
                    ("HatFeltDark", (0.10, 0.085, 0.07), 0.95, 0.0), ("ChipRed", (0.62, 0.08, 0.06), 0.5, 0.0),
                    ("ChipWhite", (0.85, 0.83, 0.78), 0.5, 0.0), ("ChipBlue", (0.08, 0.16, 0.45), 0.5, 0.0), ("Tin", (0.50, 0.50, 0.48), 0.45, 0.5),
                    ("Nickel", (0.62, 0.62, 0.60), 0.3, 0.5), ("Wax", (0.88, 0.84, 0.72), 0.6, 0.0), ("Bark", (0.16, 0.11, 0.07), 0.95, 0.0),
                    ("Straw", (0.66, 0.55, 0.32), 0.95, 0.0), ("Water", (0.05, 0.07, 0.08), 0.05, 0.0), ("Beans", (0.30, 0.14, 0.07), 0.7, 0.0),
                    ("Newsprint", (0.74, 0.70, 0.60), 0.95, 0.0), ("Soot", (0.008, 0.007, 0.006), 0.95, 0.0),
                    ("Enamel", (0.10, 0.20, 0.42), 0.3, 0.0)]:
    K.mat(n, c, r, mt)
K.mat("ClearGlass", (0.72, 0.76, 0.76), 0.05, 0.0, alpha=0.35)
K.mat("Whiskey", (0.42, 0.18, 0.04), 0.1, 0.0, alpha=0.85)
K.mat("LampGlass", (0.85, 0.86, 0.84), 0.05, 0.0, alpha=0.25)
K.mat("Flame", (1.0, 0.70, 0.30), 0.5, 0.0, emit=4.0)
K.mat("Glow", (1.0, 0.42, 0.10), 0.5, 0.0, emit=3.0)
SC = bpy.context.scene


def root_name(piece):
    return "Twn_" + "".join(w.capitalize() for w in piece.split("_"))


PIECES = sorted({os.path.basename(p).split("__")[0] for p in glob.glob(os.path.join(CAD, "*__*.obj"))})


def import_part(path):
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=path, forward_axis="NEGATIVE_Z", up_axis="Y")      # the OBJ is in the game frame (y up)
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


roots = {}
report = {"pieces": {}}
missing = set()
for piece in PIECES:
    name = root_name(piece)
    parts = []
    for path in sorted(glob.glob(os.path.join(CAD, piece + "__*.obj"))):
        mat_name = os.path.basename(path)[len(piece) + 2:-4]
        if mat_name not in K.MATS:
            missing.add(mat_name)
            K.mat(mat_name, (0.5, 0.0, 0.5), 0.9, 0.0)                 # loud magenta: a material this script forgot
        for ob in import_part(path):
            ob.data.materials.clear()
            ob.data.materials.append(K.MATS[mat_name])
            parts.append(ob)
    if not parts:
        continue
    root = bpy.data.objects.new(name, None)
    SC.collection.objects.link(root)
    roots[name] = root
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    if len(parts) > 1:
        bpy.ops.object.join()
    geo = bpy.context.view_layer.objects.active
    geo.name = name + "_geo"
    geo.data.name = name + "_mesh"
    geo.parent = root
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.00005)            # FreeCAD writes each CAD face separately: weld the seams
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(32), keep_sharp_edges=True)
    tris = sum(len(p.vertices) - 2 for p in geo.data.polygons)
    dims = [round(d, 3) for d in geo.dimensions]
    report["pieces"][name] = {"tris": tris, "materials": [m.name for m in geo.data.materials], "dims_blender": dims}

for o in SC.objects:
    o.select_set(False)


def sel(o):
    o.select_set(True)
    for c in o.children:
        sel(c)


for r in roots.values():
    sel(r)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True, use_selection=True,
                          export_extras=False, export_cameras=False, export_lights=False)
report["tris"] = sum(p["tris"] for p in report["pieces"].values())
report["bytes"] = os.path.getsize(OUT)
report["missing_materials"] = sorted(missing)

if SHOTS:
    from mathutils import Vector
    os.makedirs(SHOTS, exist_ok=True)
    # a shelf layout for the contact sheet only (the GLB above was written with every root at the origin): rows of pieces by size
    bpy.context.view_layer.update()
    order = ["Twn_Bar", "Twn_BackBar", "Twn_Piano", "Twn_PianoStool", "Twn_Table", "Twn_Chair", "Twn_Spittoon", "Twn_HatRack",
             "Twn_Counter", "Twn_Pigeonholes", "Twn_Desk", "Twn_DeskChair", "Twn_DeskLamp", "Twn_Stove", "Twn_WoodBox", "Twn_Safe",
             "Twn_Bench", "Twn_Clock", "Twn_ClockPendulum", "Twn_HangLamp", "Twn_Chandelier", "Twn_Lantern", "Twn_KeyRing", "Twn_Bucket",
             "Twn_TinPlate", "Twn_Broom", "Twn_Workbench", "Twn_GunBoard", "Twn_PokerSet", "Twn_TableDrinks"]
    hang = {"Twn_HangLamp", "Twn_Chandelier", "Twn_ClockPendulum"}      # built hanging below their origin: lift them onto the floor
    x, row_y, row_w, row_depth = 0.0, 0.0, 9.5, 0.0
    placed = {}
    for name in order:
        if name not in roots:
            continue
        geo = roots[name].children[0]
        bb = [geo.matrix_world @ Vector(c) for c in geo.bound_box]
        w = max(p.x for p in bb) - min(p.x for p in bb)
        dpt = max(p.y for p in bb) - min(p.y for p in bb)
        zmin = min(p.z for p in bb)
        if x + w > row_w and x > 0.0:
            row_y -= row_depth + 0.6
            x, row_depth = 0.0, 0.0
        r = roots[name]
        r.location = (x - min(p.x for p in bb), row_y - max(p.y for p in bb), -zmin if name in hang else 0.0)
        bpy.context.view_layer.update()
        placed[name] = (x + w / 2, row_y - dpt / 2)
        x += w + 0.4
        row_depth = max(row_depth, dpt)
    sc = SC
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1800, 1100
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.55, 0.58, 0.62)

    def shot(fname, pos, target, lens=45):
        cam.data.lens = lens
        cam.location = pos
        cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(SHOTS, fname + ".png")
        bpy.ops.render.render(write_still=True)

    # Blender frame: x right, y = -game z (a piece's front faces -y here), z up
    shot("kit_overview", (4.8, -17.0, 9.5), (4.8, -4.5, 0.4), 26)
    for name, dist, h, lens in (("Twn_Chair", 1.6, 0.9, 50), ("Twn_Piano", 2.6, 1.3, 50), ("Twn_Stove", 4.0, 2.0, 45),
                                ("Twn_BackBar", 5.5, 1.9, 40), ("Twn_Counter", 3.5, 1.6, 45), ("Twn_Desk", 2.6, 1.6, 50),
                                ("Twn_Pigeonholes", 3.2, 1.5, 45), ("Twn_Chandelier", 2.6, 1.6, 45), ("Twn_HatRack", 2.4, 1.3, 45),
                                ("Twn_Safe", 1.8, 1.0, 50), ("Twn_Clock", 1.2, 0.7, 50), ("Twn_Bench", 2.4, 1.0, 45)):
        if name in placed:
            cx, cy = placed[name]
            # from the piece's front (game +z = Blender -y), a little to the right and above
            shot("kit_" + name[4:].lower(), (cx + dist * 0.45, cy - dist, h + dist * 0.25), (cx, cy, h * 0.55), lens)
print("@@" + json.dumps({"ok": True, **report}))
