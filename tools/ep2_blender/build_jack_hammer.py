"""JACK HAMMER (Jackson Mccree) - the Episode 2 main antagonist, built (founder 2026-10-21: "create Jack Hammer and make him mean with a patch eye";
skills ep2-jack-hammer-narrative, ep2-jack-hammer-character).

Headless bpy:
  blender -b --factory-startup -P tools/ep2_blender/build_jack_hammer.py -- --dir src/episode2/extras/people [--shots <dir>]

Built on the town's shared folk kit (tools/ep2_blender/build_armory_folk.py: one skeleton drives the lofted mesh and the armature, five authored clips
Idle / Walk / Greet / Point / Carry), so he moves and streams exactly like the townspeople. What makes him HIM - the founder fixed only "mean" and "a patch eye"; the rest
is this pass's design and is flagged as a proposal in the skill (the founder is the judge):
  - the tallest and broadest man in the town (1.96 m, girth 1.12): the silhouette alone says threat
  - a black leather patch over the LEFT eye with a strap slanting up across the head, a pale scar through the brow and cheek under it
  - the good eye pale and narrow under a heavy, down-slanting brow; a downturned mouth, a heavy jaw, black stubble, one gold tooth
  - a black wide hat pulled low, a long black duster with a blood-dark lining and a popped collar, black gloves, a heavy gun belt with two holsters
  - a sledgehammer slung across his back (the name; a prop, never used by the story as a weapon yet - proposal)
Prints @@{json}. One GLB (~0.2 MB), streamed with the Episode 2 extras (Ep2Extras.JACK_HAMMER).
"""
import importlib.util
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--dir") + 1] if "--dir" in argv else "src/episode2/extras/people"
SHOTS = argv[argv.index("--shots") + 1] if "--shots" in argv else ""

spec = importlib.util.spec_from_file_location("armory_folk", os.path.join(HERE, "build_armory_folk.py"))
AF = importlib.util.module_from_spec(spec)
spec.loader.exec_module(AF)

NAME = "jack_hammer"
HEIGHT = 1.96
GIRTH = 1.12

PAL = dict(AF.RICH_PAL)
PAL.update({
    "Skin": ((0.60, 0.43, 0.33), 0.74), "Hair": ((0.07, 0.065, 0.06), 0.92), "Beard": ((0.10, 0.095, 0.09), 0.95),
    "Duster": ((0.10, 0.095, 0.095), 0.86), "DusterLining": ((0.30, 0.045, 0.045), 0.80), "Shirt": ((0.30, 0.29, 0.28), 0.92),
    "Vest": ((0.07, 0.065, 0.065), 0.80), "Trouser": ((0.10, 0.09, 0.09), 0.92), "Boot": ((0.07, 0.05, 0.04), 0.50),
    "Glove": ((0.045, 0.04, 0.04), 0.55), "HatFelt": ((0.055, 0.05, 0.05), 0.92), "HatBand": ((0.11, 0.10, 0.09), 0.40),
    "Patch": ((0.015, 0.014, 0.014), 0.45), "Scar": ((0.78, 0.52, 0.46), 0.65), "Eye": ((0.84, 0.82, 0.76), 0.30),
    "Iris": ((0.55, 0.70, 0.78), 0.25), "Pupil": ((0.01, 0.01, 0.01), 0.20), "Mouth": ((0.12, 0.04, 0.04), 0.60),
    "Tooth": ((0.86, 0.66, 0.20), 0.25), "Iron": ((0.16, 0.16, 0.18), 0.38), "Handle": ((0.27, 0.17, 0.10), 0.62),
})
# the Compatibility renderer under the desert sun washes colour out: cloth and leather a third darker, skin / metal / eyes unchanged (as the townsfolk are)
NO_DARKEN = ("Skin", "Brass", "Steel", "Iron", "Lens", "Eye", "Iris", "Pupil", "Tooth", "Scar", "Mouth", "HatBand")

B = {
    "body": ["Hips", "Spine", "Chest", "Neck"], "head": ["Head", "Neck", "Chest"],
    "arm.L": ["Shoulder.L", "UpperArm.L", "Forearm.L", "Hand.L", "Chest"], "arm.R": ["Shoulder.R", "UpperArm.R", "Forearm.R", "Hand.R", "Chest"],
    "leg.L": ["Hips", "Thigh.L", "Shin.L", "Foot.L"], "leg.R": ["Hips", "Thigh.R", "Shin.R", "Foot.R"], "hips": ["Hips", "Spine"],
    "coat": ["Hips", "Spine", "Chest", "Neck", "Thigh.L", "Thigh.R"],
}


def duster(f, j):
    """A long coat to the shin, close at the shoulders and falling straight: a blood-dark lining panel down the open front, a collar popped up behind the neck."""
    z0 = j["neck"].z - 0.030
    c = f.part("Duster", B["coat"])
    c.loft([
        (0, -0.006, z0 + 0.012, 0.165, 0.112),
        (0, -0.010, j["chest"].z + 0.020, 0.205, 0.128),
        (0, -0.008, j["spine"].z + 0.030, 0.200, 0.128),
        (0, 0.002, j["hips"].z + 0.030, 0.208, 0.134),
        (0, 0.010, j["hips"].z - 0.200, 0.226, 0.146),
        (0, 0.018, j["knee.L"].z + 0.080, 0.240, 0.156),
        (0, 0.022, j["knee.L"].z - 0.110, 0.250, 0.162),
    ], 22, cap0=False, cap1=False)
    li = f.part("DusterLining", B["coat"])
    # the open front: a dark red panel from the chest to the hem, edged by two slim coat flaps standing proud
    li.box((0.074, 0.010, 0.370), (0.0, -0.1385, j["chest"].z - 0.075))
    li.box((0.078, 0.010, 0.620), (0.0, -0.1500, j["hips"].z - 0.300))
    li.box((0.082, 0.010, 0.430), (0.0, -0.1640, j["knee.L"].z - 0.020))
    for sx in (-1, 1):
        c.box((0.036, 0.020, 0.370), (sx * 0.058, -0.139, j["chest"].z - 0.075))
        c.box((0.040, 0.022, 0.620), (sx * 0.062, -0.152, j["hips"].z - 0.300))
        c.box((0.040, 0.022, 0.430), (sx * 0.064, -0.166, j["knee.L"].z - 0.020))
        # the collar, popped up beside and behind the neck
        c.box((0.080, 0.040, 0.130), (sx * 0.074, 0.050, j["neck"].z + 0.030), rot=(0.12, sx * 0.28, 0))
    c.box((0.180, 0.046, 0.120), (0.0, 0.064, j["neck"].z + 0.034), rot=(0.18, 0, 0))
    c.box((0.340, 0.140, 0.024), (0.0, 0.002, j["chest"].z + 0.150))


# the head's real profile (build_armory_folk.head): (dz from the eye line, centre y, y radius, x radius). The face is an ellipse that falls away to the sides, so a feature
# at x = 0.04 sits ~1.4 cm BEHIND the centre line: fy() gives the surface y at (dz, x) so everything lies ON the skin, not floating off it or buried in it.
_PROFILE = [(-0.075, -0.004, 0.084, 0.070), (-0.040, -0.012, 0.096, 0.078), (0.0, -0.014, 0.100, 0.082), (0.042, -0.010, 0.098, 0.082), (0.080, -0.004, 0.084, 0.070)]


def fy(dz, x=0.0, proud=0.0):
    dz = max(_PROFILE[0][0], min(_PROFILE[-1][0], dz))
    for (z0, c0, r0, x0), (z1, c1, r1, x1) in zip(_PROFILE, _PROFILE[1:]):
        if z0 <= dz <= z1:
            t = (dz - z0) / (z1 - z0)
            cy, ry, rx = c0 + (c1 - c0) * t, r0 + (r1 - r0) * t, x0 + (x1 - x0) * t
            u = min(abs(x) / rx, 0.97)
            return cy - ry * math.sqrt(1.0 - u * u) - proud
    return 0.0


def mean_face(f, j):
    """Everything that makes the face his: the patch + straps, the scar, the pale narrow eye, the scowling brow, the grimace and the gold tooth. Every feature is placed with fy()."""
    z = j["foramen"].z
    bones = B["head"]
    # --- the left-eye patch (character's left = +x; he faces -y): a domed black leather disc, rimmed
    px, pz = 0.040, 0.006
    yb = fy(pz, px, 0.0)
    pt = f.part("Patch", bones)
    pt.loft([(px, yb + 0.010, z + pz, 0.041, 0.037), (px, yb - 0.002, z + pz, 0.040, 0.036), (px, yb - 0.011, z + pz, 0.031, 0.027)], 18)
    # --- the straps: one slanting up over the forehead to behind the right ear, one short to behind the left; segments laid along the skin
    stp = f.part("Patch", bones)
    n = 9
    for k in range(n + 1):
        t = k / n
        x = 0.040 - 0.118 * t
        dz = 0.032 + 0.040 * t
        stp.box((0.020, 0.008, 0.008), (x, fy(dz, x, -0.0015), z + dz), rot=(0, 0, -0.30))
    for k in range(5):
        t = k / 4
        x = 0.072 + 0.006 * t
        dz = -0.004 - 0.020 * t
        stp.box((0.016, 0.008, 0.008), (x, fy(dz, x, -0.0015), z + dz), rot=(0, 0.4, 0.2))
    # --- the scar: a pale line from the brow down through the patch's edge and across the cheek, with stitch marks
    sc = f.part("Scar", bones)
    for k in range(9):
        t = k / 8
        x = 0.058 + 0.020 * t
        dz = 0.044 - 0.108 * t
        sc.box((0.008, 0.007, 0.016), (x, fy(dz, x, -0.0008), z + dz), rot=(0, 0.3, 0.30))
        if k % 2 == 0:
            sc.box((0.022, 0.006, 0.004), (x, fy(dz, x, -0.0012), z + dz), rot=(0, 0.3, 0.30))
    # --- the good eye (right): sclera, a pale cold iris, a hard pupil, a heavy lid above it so it narrows
    ex = -0.038
    ey = fy(0.010, ex, 0.0)
    e = f.part("Eye", bones)
    e.loft([(ex, ey + 0.004, z + 0.010, 0.0185, 0.0150), (ex, ey - 0.006, z + 0.010, 0.0160, 0.0130)], 12)
    ir = f.part("Iris", bones)
    ir.loft([(ex, ey - 0.005, z + 0.010, 0.0100, 0.0100), (ex, ey - 0.0085, z + 0.010, 0.0088, 0.0088)], 12)
    pu = f.part("Pupil", bones)
    pu.loft([(ex, ey - 0.0075, z + 0.010, 0.0034, 0.0034), (ex, ey - 0.0100, z + 0.010, 0.0030, 0.0030)], 10)
    lid = f.part("Skin", bones)
    lid.box((0.044, 0.014, 0.011), (ex, ey - 0.005, z + 0.0215), rot=(-0.10, 0, 0.10))
    # --- brows: heavy, thick, built as short pieces along the brow ridge, slanting DOWN toward the nose - the scowl
    for sx in (-1, 1):
        br = f.part("Hair", bones)
        for k in range(4):
            x = sx * (0.014 + 0.017 * k)
            dz = 0.026 + 0.0075 * k                      # outer end higher: the slant
            br.box((0.024, 0.014, 0.017), (x, fy(dz, x, -0.0015), z + dz + 0.012), rot=(0, 0, sx * -0.32))
    f.part("Skin", bones).box((0.014, 0.012, 0.030), (0.0, fy(0.022, 0.0, -0.001), z + 0.020), rot=(0.08, 0, 0))
    # --- the mouth: a flat downturned slit, the corners dragged down, a sneering upper lip, one gold tooth
    mz = -0.060
    mo = f.part("Mouth", bones)
    mo.box((0.060, 0.008, 0.008), (0.0, fy(mz, 0.0, -0.001), z + mz))
    for sx in (-1, 1):
        mo.box((0.020, 0.008, 0.008), (sx * 0.036, fy(mz - 0.007, sx * 0.036, -0.001), z + mz - 0.007), rot=(0, 0, sx * -0.55))
    f.part("Skin", bones).box((0.056, 0.012, 0.010), (0.0, fy(mz + 0.010, 0.0, -0.003), z + mz + 0.010), rot=(0.12, 0, 0))
    f.part("Tooth", bones).box((0.008, 0.005, 0.011), (0.014, fy(mz + 0.001, 0.014, 0.001), z + mz + 0.001))
    # --- a heavy squared jaw and chin on top of the base head
    jw = f.part("Skin", bones)
    jw.loft([(0, fy(-0.090) + 0.008, z - 0.094, 0.058, 0.044), (0, fy(-0.070) + 0.010, z - 0.072, 0.068, 0.056), (0, fy(-0.046) + 0.012, z - 0.048, 0.074, 0.064)], 12)


def hat(f, j):
    """The town's felt hat (AF.hat_felt), perched higher so the eyes are not lost under the brim at any distance, and cut for a menacing flat crown with a dark band."""
    z = j["foramen"].z + 0.094
    h = f.part("HatFelt", B["head"])
    h.lathe([(0.118, z - 0.014), (0.176, z - 0.030), (0.200, z - 0.024), (0.196, z - 0.008), (0.124, z + 0.004)], 26, cap_ends=False, ry_scale=0.92)
    h.lathe([(0.122, z + 0.002), (0.126, z + 0.046), (0.124, z + 0.090), (0.112, z + 0.126), (0.074, z + 0.150), (0.0, z + 0.156)], 26, ry_scale=0.96)
    f.part("HatFelt", B["head"]).box((0.070, 0.150, 0.100), (0.0, 0.0, z + 0.118))
    b = f.part("HatBand", B["head"])
    b.lathe([(0.128, z + 0.010), (0.132, z + 0.020), (0.128, z + 0.050), (0.124, z + 0.058)], 26, cap_ends=False, ry_scale=0.96)
    for k in range(5):                                    # silver conchos round the band
        a = -0.9 + 0.45 * k
        f.part("Steel", B["head"]).box((0.018, 0.010, 0.018), (math.sin(a) * 0.132, -math.cos(a) * 0.126, z + 0.036), rot=(0, 0, a))


def hammer(f, j):
    """The sledgehammer slung across his back, handle up over the right shoulder."""
    th = -0.46
    cz = j["chest"].z - 0.330
    cy = 0.150
    h = f.part("Handle", B["body"])
    h.box((0.030, 0.030, 0.980), (0.0, cy, cz), rot=(0.0, th, 0.0))
    top = Vector((math.sin(th) * 0.50, cy, cz + math.cos(th) * 0.50))
    ir = f.part("Iron", B["body"])
    ir.box((0.210, 0.090, 0.095), (top.x, top.y, top.z - 0.030), rot=(0.0, th, 0.0))
    for sx in (-1, 1):
        ir.box((0.020, 0.100, 0.105), (top.x + sx * 0.112 * math.cos(th), top.y, top.z - 0.030 - sx * 0.112 * math.sin(th)), rot=(0.0, th, 0.0))
    bot = Vector((-math.sin(th) * 0.50, cy, cz - math.cos(th) * 0.50))
    f.part("Handle", B["body"]).box((0.050, 0.050, 0.060), (bot.x, bot.y, bot.z - 0.010), rot=(0.0, th, 0.0))
    # the strap across the chest that holds it
    sp = f.part("BeltLeather", B["body"])
    sp.box((0.040, 0.030, 0.620), (0.020, -0.128, j["chest"].z - 0.020), rot=(0.0, 0.62, 0.0))


def build(f, j):
    for side in ("L", "R"):
        AF.leg(f, j, side, "Trouser", B["leg." + side], to_z=0.34)
        AF.foot(f, j, side, "Boot", "Boot", "Sole", B["leg." + side], heel_h=0.040)
    AF.torso(f, j, "Shirt", B["body"])
    AF.vest(f, j, "Vest", B["body"], buttons=5)
    AF.neck(f, j, "Skin", B["head"])
    for side in ("L", "R"):
        AF.arm(f, j, side, "Duster", "Glove", B["arm." + side], roll_up=False, sleeve_to=0.97, cuff=0.020, girth=1.08)
    duster(f, j)
    AF.belt(f, j, "BeltLeather", "Brass", B["hips"], buckle=True)
    AF.holsters(f, j, "Holster", "Steel", "Wood", B["hips"])
    AF.head(f, j, "Skin", B["head"], hair="Hair", beard="Beard")
    mean_face(f, j)
    hat(f, j)
    hammer(f, j)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = AF.FPS
AF.MATS.clear()
for k, v in PAL.items():
    d = 1.0 if k in NO_DARKEN else 0.66
    AF.mat(k, tuple(c * d for c in v[0]), v[1], 0.0)
j = AF.S(HEIGHT, girth=GIRTH)
f = AF.Figure(NAME, HEIGHT)
build(f, j)
geo, groups = f.build()
arm_ob = AF.make_armature(NAME, j)
AF.skin(geo, arm_ob, groups, j)
AF.build_clips(arm_ob, "utah")
os.makedirs(OUT, exist_ok=True)
path = os.path.join(OUT, NAME + ".glb")
AF.export(path, arm_ob, geo)
print("@@{\"person\": \"%s\", \"bytes\": %d, \"tris\": %d, \"height\": %.2f}" % (NAME, os.path.getsize(path), sum(len(p.vertices) - 2 for p in geo.data.polygons), HEIGHT))

if SHOTS:
    os.makedirs(SHOTS, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    for m in bpy.data.materials:
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.use_nodes else None
        if b is not None:
            m.diffuse_color = b.inputs["Base Color"].default_value
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.30, 0.34, 0.40)
    cam = bpy.data.objects.new("c", bpy.data.cameras.new("c"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "PERSP"
    cam.data.lens = 70
    views = [("front", (0, -1, 0), (0, 0, 0.98), 5.2, (700, 980)), ("three", (0.8, -0.7, 0.2), (0, 0, 0.98), 5.2, (700, 980)), ("side", (1, 0, 0), (0, 0, 0.98), 5.2, (700, 980)),
             ("back", (0, 1, 0), (0, 0, 0.98), 5.2, (700, 980)), ("face", (0.35, -1, 0.10), (0, -0.01, 1.66), 1.5, (800, 800)), ("face_front", (0.0, -1, 0.05), (0, -0.01, 1.66), 1.3, (800, 800))]
    for name, d, ctr, dist, res in views:
        sc.render.resolution_x, sc.render.resolution_y = res
        dv = Vector(d).normalized()
        cam.location = Vector(ctr) + dv * dist
        cam.rotation_euler = (Vector(ctr) - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(SHOTS, name + ".png")
        bpy.ops.render.render(write_still=True)
