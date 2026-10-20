"""THE ARMORY'S TWO HERO GUNS (founder 2026-10-20: "Rich and Utah introduce Lil Blunt to the Sharps 1874 Buffalo Gun and the Colt Gatling Gun").

  blender -b --factory-startup -P tools/ep2_blender/build_sharps_gatling.py -- [--dir src/episode2/extras/armory] [--shots shots/]

Writes, into the streamed extras (never into index.pck):
  sharps_1874.glb    Rich's Sharps Model 1874 Buffalo Gun (one mesh "Sharps1874_geo"; muzzle +x, ~1.21 m) - the rifle in the case, in his hands, and
                     the one Lil Blunt buys (the long rifle of the day-88 overlook).
  gatling_post.glb   Gatling_Post -> Gat_Yaw -> Gat_Pitch -> {Gat_Barrels, Gat_Crank} + empties Gat_Muzzle / Gat_Eye / Gat_Eject / Gat_Sign, plus
                     Range_Plate (with a swinging Range_Swing) and Range_Bale for the firing yard. The Gatling is NOT FOR SALE.
--shots renders review images (Workbench) of both so the build is judged by eye. Prints @@{json}.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import armory_kit as K  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--dir") + 1] if "--dir" in argv else "src/episode2/extras/armory"
SHOTS = argv[argv.index("--shots") + 1] if "--shots" in argv else ""
os.makedirs(OUT, exist_ok=True)


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    K.MATS.clear()
    K.standard_materials()


def export(path, roots):
    for o in bpy.context.scene.objects:
        o.select_set(False)

    def sel(o):
        o.select_set(True)
        for c in o.children:
            sel(c)
    for r in roots:
        sel(r)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True, use_selection=True,
                              export_extras=False, export_cameras=False, export_lights=False)
    return os.path.getsize(path)


def render_rig():
    """Workbench review rig (material colours, soft shadows). Returns shot(name, pos, target, lens)."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1100, 700
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.world = bpy.data.worlds.new("W")
    sc.world.color = (0.62, 0.70, 0.78)

    def shot(name, pos, target, lens=45):
        cam.data.lens = lens
        cam.location = pos
        cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(SHOTS, name + ".png")
        bpy.ops.render.render(write_still=True)
    return shot


def ground_plane():
    ground = bpy.data.meshes.new("g")
    ground.from_pydata([(-20, -20, -0.01), (20, -20, -0.01), (20, 20, -0.01), (-20, 20, -0.01)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", ground)
    gm = bpy.data.materials.new("S")
    gm.diffuse_color = (0.55, 0.43, 0.29, 1)
    ground.materials.append(gm)
    bpy.context.scene.collection.objects.link(gob)
    return gob


# game (x, y, z) -> blender (x, -z, y)
def g(x, y, z):
    return (x, -z, y)


report = {}

# ------------------------------------------------------------------------------------------------------------------ the Sharps
fresh()
S = K.Piece("Sharps1874")
K.sharps(S)
root, tris = S.build()
report["sharps"] = {"tris": tris, "bytes": export(os.path.join(OUT, "sharps_1874.glb"), [root])}
if SHOTS:
    os.makedirs(SHOTS, exist_ok=True)
    shot = render_rig()
    shot("sharps_side", g(0.2, 0.15, 1.9), g(0.2, 0.02, 0.0), 40)
    shot("sharps_action", g(0.0, 0.25, 0.75), g(-0.02, 0.0, 0.0), 55)
    shot("sharps_butt34", g(-1.1, 0.45, 1.0), g(-0.15, 0.0, 0.0), 45)
    shot("sharps_muzzle34", g(1.6, 0.45, 0.9), g(0.6, 0.03, 0.0), 45)

# ----------------------------------------------------------------------------------------------------------- the Gatling post
fresh()
POST = K.Piece("Gatling_Post")
K.gatling_post_geo(POST)
post_root, t0 = POST.build()
YAW = K.Piece("Gat_Yaw")
K.gatling_yaw_geo(YAW)
yaw_root, t1 = YAW.build(post_root, (0.0, K.GAT_YAW_Y, 0.0))
PITCH = K.Piece("Gat_Pitch")
K.gatling_pitch_geo(PITCH)
pitch_root, t2 = PITCH.build(yaw_root, (0.0, K.GAT_TRUNNION_Y, 0.0))
BAR = K.Piece("Gat_Barrels")
K.gatling_barrels_geo(BAR)
bar_root, t3 = BAR.build(pitch_root, (K.GAT_BARREL_X, 0.0, 0.0))
CR = K.Piece("Gat_Crank")
K.gatling_crank_geo(CR)
crank_root, t4 = CR.build(pitch_root, K.GAT_CRANK)
# pieces written around an origin: pitch/barrel geometry already carries its own offsets, so barrels (written from x=0.03) sit at the
# cluster's origin - shift them back by the pivot so the geometry stays where it was authored
bar_geo = next(c for c in bar_root.children if c.type == "MESH")
bar_geo.location = (0.0, 0.0, 0.0)
# range props
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
roots = [post_root, plate_root, bale_root]
report["gatling"] = {"tris": t0 + t1 + t2 + t3 + t4, "targets_tris": t5 + t6 + t7, "bytes": export(os.path.join(OUT, "gatling_post.glb"), roots)}

# --------------------------------------------------------------------------------------------------------------- review shots
if SHOTS:
    shot = render_rig()
    gob = ground_plane()
    gob.hide_render = True
    shot("gatling_front34", g(3.8, 2.2, 3.8), g(0.3, 1.2, 0.0), 40)
    shot("gatling_side", g(0.3, 1.7, 4.6), g(0.5, 1.5, 0.0), 40)
    shot("gatling_gunner", g(-1.9, 2.15, 0.0), g(1.2, 1.5, 0.0), 38)
    shot("gatling_top", g(0.2, 6.0, 0.6), g(0.2, 1.0, 0.0), 40)
    gob.hide_render = False
    shot("range_props", g(4.5, 1.4, 5.0), g(4.5, 0.9, 0.0), 35)

print("@@" + json.dumps({"ok": True, **report}))
