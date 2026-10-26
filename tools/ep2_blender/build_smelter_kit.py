"""THE SMELTER'S PROP KIT FROM CAD (founder 2026-10-25: "Inferno hideout smelting facility - hyperreal props, furnace, kegs, tools ... not
grey primitives"; "weapons in facility ... match founder Winchester / revolver quality bar").

  SMELTER_CAD_OUT=<dir> freecadcmd tools/ep2_cad/smelter_kit_cad.py               # 1. the solids -> <dir>/<piece>__<Material>.obj
  blender -b --factory-startup -P tools/ep2_blender/build_smelter_kit.py -- --cad <dir> [--out src/episode2/extras/hideout/smelter_kit.glb] [--shots d]

One GLB, one root node per prop, every root at the origin (the game duplicates a root by name and places it): Kit_Revolver, Kit_Keg,
Kit_KegSmall, Kit_Chock, Kit_Anvil, Kit_Tongs, Kit_Ladle, Kit_Mould, Kit_Shovel, Kit_Sledge, Kit_Pick, Kit_ChainLink, Kit_Hook,
Kit_Cartridge, Kit_Crate, Kit_AmmoBox. Each root holds one mesh <root>_geo with one surface per kit material (GunSteel, CaseHard, GunWood,
Iron, Trim, Planks, DarkWood, Brass, Rope, Lead) so Ep2Pbr dresses it by name in the engine. Shading as the CAD Gatling: merged seams,
smooth by angle with sharp CAD edges kept. --shots renders a Workbench contact sheet of every prop (laid out in a grid only for the shot).
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
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/hideout/smelter_kit.glb"
SHOTS = argv[argv.index("--shots") + 1] if "--shots" in argv else ""
if not CAD or not glob.glob(os.path.join(CAD, "*.obj")):
    sys.exit("build_smelter_kit: --cad <dir> with the FreeCAD OBJs is required (run tools/ep2_cad/smelter_kit_cad.py first)")

bpy.ops.wm.read_factory_settings(use_empty=True)
K.MATS.clear()
K.standard_materials()
K.mat("Lead", (0.36, 0.35, 0.34), 0.5, 0.55)                    # the bullets: soft grey lead (no PBR set: a few pixels on screen)
K.mat("Soot", (0.008, 0.007, 0.006), 0.95, 0.0)                 # the furnace doors' peep port: the dark inside
SC = bpy.context.scene

PIECES = [("revolver", "Kit_Revolver"), ("keg", "Kit_Keg"), ("keg_small", "Kit_KegSmall"), ("chock", "Kit_Chock"),
          ("anvil", "Kit_Anvil"), ("tongs", "Kit_Tongs"), ("ladle", "Kit_Ladle"), ("mould", "Kit_Mould"), ("shovel", "Kit_Shovel"),
          ("sledge", "Kit_Sledge"), ("pick", "Kit_Pick"), ("chain_link", "Kit_ChainLink"), ("hook", "Kit_Hook"),
          ("cartridge", "Kit_Cartridge"), ("crate", "Kit_Crate"), ("ammo_box", "Kit_AmmoBox"),
          ("furnace_doors", "Kit_FurnaceDoors"), ("furnace_hood", "Kit_FurnaceHood"), ("bellows", "Kit_Bellows"), ("fire_tools", "Kit_FireTools")]


def import_part(path):
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=path, forward_axis="NEGATIVE_Z", up_axis="Y")      # the OBJ is in the game frame (y up)
    return [o for o in bpy.data.objects if o not in before and o.type == "MESH"]


roots = {}
report = {"pieces": {}}
for piece, name in PIECES:
    parts = []
    for path in sorted(glob.glob(os.path.join(CAD, piece + "__*.obj"))):
        mat_name = os.path.basename(path)[len(piece) + 2:-4]
        for ob in import_part(path):
            ob.data.materials.clear()
            ob.data.materials.append(K.MATS[mat_name])
            parts.append(ob)
    if not parts:
        print("build_smelter_kit: no parts for", piece)
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

if SHOTS:
    from mathutils import Vector
    os.makedirs(SHOTS, exist_ok=True)
    # a grid layout for the contact sheet only (the GLB above was written with every root at the origin)
    layout = {"Kit_Revolver": (0, 0, 1.0, 3.0), "Kit_Keg": (1.4, 0, 1.0, 0), "Kit_KegSmall": (2.2, 0, 1.0, 0), "Kit_Chock": (2.9, 0, 1.0, 0),
              "Kit_Anvil": (0.0, -1.2, 1.0, 0), "Kit_Tongs": (1.2, -1.4, 1.0, 90), "Kit_Ladle": (2.3, -1.4, 1.0, 90),
              "Kit_Mould": (3.3, -1.2, 1.0, 0), "Kit_Shovel": (0.0, -2.6, 1.0, 90), "Kit_Sledge": (1.1, -2.6, 1.0, 90),
              "Kit_Pick": (2.2, -2.6, 1.0, 90), "Kit_ChainLink": (3.1, -2.6, 3.0, 0), "Kit_Hook": (3.5, -2.6, 3.0, 0),
              "Kit_Cartridge": (3.9, -2.6, 4.0, 0), "Kit_Crate": (5.2, -0.4, 1.0, 20), "Kit_AmmoBox": (5.2, -2.2, 2.0, 0)}
    for name, (x, z, s, yaw) in layout.items():
        if name in roots:
            r = roots[name]
            r.location = (x, -z, 0.0)
            r.scale = (s, s, s)
            r.rotation_euler = (0.0, 0.0, math.radians(yaw))
    sc = SC
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1000
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

    # Blender frame here: x right, y = -game z, z up
    shot("kit_overview", (2.6, 6.5, 4.2), (2.6, 1.4, 0.3), 32)
    shot("kit_revolver", (0.25, 0.75, 1.05), (0.0, 0.0, 0.0), 60)
    shot("kit_keg_anvil", (1.0, 3.0, 1.2), (1.2, 0.3, 0.35), 45)
    shot("kit_tools", (1.6, 4.2, 1.6), (1.6, 2.3, 0.0), 45)
    shot("kit_crate_box", (6.6, 2.4, 1.8), (5.2, 1.2, 0.4), 40)
print("@@" + json.dumps({"ok": True, **report}))
