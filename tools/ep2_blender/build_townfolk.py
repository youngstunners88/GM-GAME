"""TOWNSMEN AND TOWNSWOMEN for the Episode 2 gold-rush town (founder 2026-10-19; skill ep2-town-people).

Headless bpy:
  blender -b --factory-startup -P tools/ep2_blender/build_townfolk.py -- --dir src/episode2/extras/people [--only clerk]

Built on tools/ep2_blender/build_armory_folk.py (one shared skeleton drives the lofted mesh and the armature, five authored clips:
Idle / Walk / Greet / Point / Carry). Five people, each its own silhouette so they read apart down a street:
  clerk       townsman  1.76 m  tin spectacles, moustache, flat dark hat, white shirt, waistcoat, sleeve cuffs
  oldtimer    townsman  1.69 m  white beard, tan hat, suspenders over a work shirt, rope coil, stooped-looking proportions via girth
  rancher     townsman  1.84 m  brown canvas coat, red neckerchief, chaps, one holster, wide felt hat
  dressmaker  townswoman 1.66 m  long blue dress, white apron, hair bun, shawl
  lady        townswoman 1.72 m  wine-red dress, wide pale hat with a ribbon, long sleeves
Prints @@{json} per figure (path, bytes). One GLB each, ~0.2 MB, streamed with the Episode 2 extras (ADR-0005).
"""
import importlib.util
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--dir") + 1] if "--dir" in argv else "src/episode2/extras/people"
ONLY = argv[argv.index("--only") + 1] if "--only" in argv else ""

# the armory folk module parses "--dir" itself; load it as a library (its __main__ block does not run)
spec = importlib.util.spec_from_file_location("armory_folk", os.path.join(HERE, "build_armory_folk.py"))
AF = importlib.util.module_from_spec(spec)
spec.loader.exec_module(AF)

BASE = dict(AF.RICH_PAL)
BASE.update({
    "Dress": ((0.17, 0.30, 0.46), 0.90), "DressTrim": ((0.86, 0.82, 0.72), 0.90), "Apron": ((0.90, 0.88, 0.80), 0.92),
    "Shawl": ((0.50, 0.17, 0.14), 0.95), "Ribbon": ((0.62, 0.14, 0.16), 0.80), "Vest": ((0.20, 0.17, 0.15), 0.88),
    "Shirt": ((0.88, 0.86, 0.80), 0.92), "Canvas": ((0.40, 0.29, 0.18), 0.90), "Jean": ((0.30, 0.27, 0.24), 0.92),
    "Frame": ((0.70, 0.62, 0.40), 0.30), "HatFelt": ((0.20, 0.18, 0.17), 0.92), "HatBand": ((0.10, 0.09, 0.09), 0.80),
})


def pal(**kw):
    d = dict(BASE)
    d.update({k: v for k, v in kw.items()})
    return d


PALS = {
    "clerk": pal(Skin=((0.78, 0.60, 0.46), 0.72), Hair=((0.22, 0.17, 0.12), 0.92), Beard=((0.22, 0.17, 0.12), 0.92),
                 Jean=((0.27, 0.25, 0.24), 0.92), Vest=((0.33, 0.12, 0.12), 0.88), HatFelt=((0.17, 0.16, 0.16), 0.92)),
    "oldtimer": pal(Skin=((0.66, 0.48, 0.36), 0.72), Hair=((0.82, 0.80, 0.76), 0.92), Beard=((0.86, 0.84, 0.80), 0.92),
                    Trouser=((0.36, 0.30, 0.22), 0.92), Shirt=((0.70, 0.62, 0.52), 0.92), HatFelt=((0.52, 0.42, 0.28), 0.92),
                    Suspender=((0.30, 0.20, 0.12), 0.70)),
    "rancher": pal(Skin=((0.60, 0.42, 0.30), 0.72), Hair=((0.30, 0.20, 0.12), 0.92), Shirt=((0.34, 0.44, 0.52), 0.92),
                   Canvas=((0.43, 0.31, 0.19), 0.90), Jean=((0.22, 0.30, 0.42), 0.92), HatFelt=((0.62, 0.52, 0.36), 0.92),
                   BootShaft=((0.30, 0.20, 0.12), 0.70), Cloth=((0.62, 0.12, 0.10), 0.92)),
    "dressmaker": pal(Skin=((0.80, 0.62, 0.48), 0.72), Hair=((0.18, 0.12, 0.09), 0.92), Dress=((0.18, 0.32, 0.50), 0.90)),
    "accomplice": pal(Skin=((0.72, 0.54, 0.40), 0.72), Hair=((0.20, 0.14, 0.10), 0.95), Beard=((0.24, 0.18, 0.13), 0.95),
                      Shirt=((0.68, 0.62, 0.52), 0.95), Vest=((0.30, 0.25, 0.20), 0.92), Trouser=((0.30, 0.26, 0.21), 0.95),
                      Suspender=((0.28, 0.20, 0.13), 0.80), Boot=((0.24, 0.17, 0.11), 0.80), Rope=((0.58, 0.50, 0.34), 0.95)),
    "lady": pal(Skin=((0.86, 0.70, 0.58), 0.72), Hair=((0.55, 0.34, 0.16), 0.92), Dress=((0.50, 0.12, 0.17), 0.88),
                HatFelt=((0.86, 0.80, 0.68), 0.92), HatBand=((0.62, 0.14, 0.16), 0.80)),
}

LEG_BONES = ["Hips", "Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Spine"]


def bones():
    return {
        "body": ["Hips", "Spine", "Chest", "Neck"], "head": ["Head", "Neck", "Chest"],
        "arm.L": ["Shoulder.L", "UpperArm.L", "Forearm.L", "Hand.L", "Chest"], "arm.R": ["Shoulder.R", "UpperArm.R", "Forearm.R", "Hand.R", "Chest"],
        "leg.L": ["Hips", "Thigh.L", "Shin.L", "Foot.L"], "leg.R": ["Hips", "Thigh.R", "Shin.R", "Foot.R"], "hips": ["Hips", "Spine"],
    }


def skirt(f, j, mat, hem, flare=0.30, hem_z=0.12):
    """A long skirt from the waist to near the ankles, flaring; a hem band in `hem`."""
    p = f.part(mat, LEG_BONES)
    p.loft([
        (0, 0.006, j["hips"].z + 0.07, 0.172, 0.118),
        (0, 0.004, j["hips"].z - 0.10, 0.222, 0.156),
        (0, 0.0, j["knee.L"].z + 0.10, 0.262, 0.214),
        (0, 0.0, hem_z + 0.06, flare * 0.96, flare * 0.80),
        (0, 0.0, hem_z, flare, flare * 0.82),
    ], 24, cap0=False, cap1=False)
    h = f.part(hem, LEG_BONES)
    h.loft([(0, 0.0, hem_z + 0.07, flare * 0.975, flare * 0.81), (0, 0.0, hem_z - 0.01, flare * 1.01, flare * 0.835)], 24, cap0=False, cap1=False)


def apron(f, j, mat, trim):
    a = f.part(mat, ["Hips", "Spine", "Chest"])
    a.box((0.30, 0.020, 0.58), (0.0, -0.138, j["hips"].z - 0.16))
    a.box((0.20, 0.020, 0.24), (0.0, -0.126, j["chest"].z - 0.02))
    t = f.part(trim, ["Hips", "Spine", "Chest"])
    t.box((0.31, 0.022, 0.030), (0.0, -0.139, j["hips"].z - 0.45))
    t.box((0.34, 0.022, 0.026), (0.0, -0.131, j["hips"].z + 0.115))
    for sx in (-1, 1):
        t.box((0.020, 0.018, 0.17), (sx * 0.085, -0.108, j["chest"].z + 0.08), rot=(0, sx * 0.12, 0))


def bun(f, j, hair):
    z = j["foramen"].z
    b = f.part(hair, ["Head", "Neck"])
    b.loft([(0, 0.108, z + 0.070, 0.050, 0.050), (0, 0.118, z + 0.070, 0.058, 0.058), (0, 0.128, z + 0.066, 0.040, 0.040)], 14)
    c = f.part(hair, ["Head", "Neck"])
    c.loft([(0, -0.004, z + 0.002, 0.090, 0.106), (0, 0.020, z - 0.040, 0.084, 0.100), (0, 0.040, z - 0.110, 0.060, 0.070)], 16, cap0=False, cap1=True)


def shawl(f, j, mat):
    s = f.part(mat, ["Chest", "Spine", "Neck", "Shoulder.L", "Shoulder.R", "UpperArm.L", "UpperArm.R"])
    s.loft([(0, -0.012, j["neck"].z - 0.012, 0.170, 0.112), (0, -0.016, j["chest"].z + 0.030, 0.226, 0.150), (0, -0.010, j["chest"].z - 0.060, 0.205, 0.140)], 20, cap0=False, cap1=False)


def legs(f, j, trouser, boot, shaft=None, to_z=0.36):
    B = bones()
    for side in ("L", "R"):
        AF.leg(f, j, side, trouser, B["leg." + side], to_z=to_z)
        AF.foot(f, j, side, shaft or boot, boot, "Sole", B["leg." + side])


def b_clerk(f, j):
    B = bones()
    legs(f, j, "Jean", "Boot")
    AF.torso(f, j, "Shirt", B["body"])
    AF.vest(f, j, "Vest", B["body"], buttons=6)
    AF.neck(f, j, "Skin", B["head"])
    for side in ("L", "R"):
        AF.arm(f, j, side, "Shirt", "Skin", B["arm." + side], roll_up=False, sleeve_to=0.92, cuff=0.016, girth=0.95)
    AF.neckerchief(f, j, "Vest", B["body"])
    AF.head(f, j, "Skin", B["head"], hair="Hair", beard="Beard")
    AF.glasses(f, j, "Frame", "Lens", B["head"], kind="flat")
    AF.hat_felt(f, j, "HatFelt", "HatBand", B["head"])
    AF.belt(f, j, "BeltLeather", "Brass", B["hips"], buckle=True)


def b_oldtimer(f, j):
    B = bones()
    legs(f, j, "Trouser", "Boot")
    AF.torso(f, j, "Shirt", B["body"])
    AF.suspenders_shirt(f, j, "Shirt", B["body"])
    AF.suspenders(f, j, "Suspender", "Brass", B["body"])
    AF.neck(f, j, "Skin", B["head"])
    for side in ("L", "R"):
        AF.arm(f, j, side, "Shirt", "Skin", B["arm." + side], roll_up=True, sleeve_to=0.60, girth=0.96)
    AF.head(f, j, "Skin", B["head"], hair="Hair", beard="Beard")
    AF.hat_felt(f, j, "HatFelt", "HatBand", B["head"])
    AF.belt(f, j, "BeltLeather", "Brass", B["hips"])
    AF.rope_coil(f, j, "Rope", B["hips"])


def b_rancher(f, j):
    B = bones()
    legs(f, j, "Jean", "Boot", shaft="BootShaft", to_z=0.40)
    AF.chaps(f, j, "Chap", "Brass", B["hips"])
    AF.torso(f, j, "Shirt", B["body"])
    AF.neck(f, j, "Skin", B["head"])
    for side in ("L", "R"):
        AF.arm(f, j, side, "Canvas", "Skin", B["arm." + side], roll_up=False, sleeve_to=0.96, girth=1.0)
    AF.coat_short(f, j, "Canvas", B["body"])
    AF.neckerchief(f, j, "Cloth", B["body"])
    AF.head(f, j, "Skin", B["head"], hair="Hair")
    AF.hat_felt(f, j, "HatFelt", "HatBand", B["head"])
    AF.belt(f, j, "BeltLeather", "Brass", B["hips"])
    AF.holsters(f, j, "Holster", "Steel", "Wood", B["hips"])


def b_dressmaker(f, j):
    B = bones()
    for side in ("L", "R"):
        AF.foot(f, j, side, "Boot", "Boot", "Sole", B["leg." + side])
    AF.torso(f, j, "Dress", B["body"], widen=(-0.012, -0.006))
    skirt(f, j, "Dress", "DressTrim", flare=0.30, hem_z=0.13)
    apron(f, j, "Apron", "DressTrim")
    AF.neck(f, j, "Skin", B["head"])
    for side in ("L", "R"):
        AF.arm(f, j, side, "Dress", "Skin", B["arm." + side], roll_up=True, sleeve_to=0.62, girth=0.90)
    shawl(f, j, "Shawl")
    AF.head(f, j, "Skin", B["head"], hair="Hair")
    bun(f, j, "Hair")


def b_lady(f, j):
    B = bones()
    for side in ("L", "R"):
        AF.foot(f, j, side, "Boot", "Boot", "Sole", B["leg." + side])
    AF.torso(f, j, "Dress", B["body"], widen=(-0.014, -0.008))
    skirt(f, j, "Dress", "DressTrim", flare=0.34, hem_z=0.11)
    AF.neck(f, j, "Skin", B["head"])
    for side in ("L", "R"):
        AF.arm(f, j, side, "Dress", "Skin", B["arm." + side], roll_up=False, sleeve_to=0.97, cuff=0.015, girth=0.90)
    AF.head(f, j, "Skin", B["head"], hair="Hair")
    AF.hat_felt(f, j, "HatFelt", "HatBand", B["head"])
    AF.belt(f, j, "Ribbon", "Brass", B["hips"], buckle=False)


def b_accomplice(f, j):
    """The jailhouse's prisoner: a caught helper, not a boss - dirty work shirt with the sleeves rolled, a worn vest hanging open,
    suspenders, scuffed boots, hatless with matted hair and a rough beard, a rope still looped at his belt."""
    B = bones()
    legs(f, j, "Trouser", "Boot")
    AF.torso(f, j, "Shirt", B["body"])
    AF.suspenders_shirt(f, j, "Shirt", B["body"])
    AF.suspenders(f, j, "Suspender", "Brass", B["body"])
    AF.vest(f, j, "Vest", B["body"], buttons=2)
    AF.neck(f, j, "Skin", B["head"])
    for side in ("L", "R"):
        AF.arm(f, j, side, "Shirt", "Skin", B["arm." + side], roll_up=True, sleeve_to=0.58, girth=0.96)
    AF.head(f, j, "Skin", B["head"], hair="Hair", beard="Beard")
    AF.belt(f, j, "BeltLeather", "Brass", B["hips"], buckle=False)
    AF.rope_coil(f, j, "Rope", B["hips"])


PEOPLE = {
    "clerk": ("townsman_clerk", b_clerk, 1.76, 0.96), "oldtimer": ("townsman_oldtimer", b_oldtimer, 1.69, 0.98),
    "rancher": ("townsman_rancher", b_rancher, 1.84, 1.02), "dressmaker": ("townswoman_dressmaker", b_dressmaker, 1.66, 0.90),
    "lady": ("townswoman_lady", b_lady, 1.72, 0.92),
    # NOT part of Ep2TownPeople's street roster: the jailhouse's accomplice (Ep2Extras.PRISONER), placed by gold_town in cell A
    "accomplice": ("prisoner_accomplice", b_accomplice, 1.74, 0.97),
}

for key, (name, builder, height, girth) in PEOPLE.items():
    if ONLY and ONLY != key:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = AF.FPS
    AF.MATS.clear()
    for k, v in PALS[key].items():
        # the Compatibility renderer under the desert sun washes colour out: cloth and leather are built a third darker; skin and
        # metal keep their value (captured against the town, 2026-10-19)
        k_dark = 1.0 if k in ("Skin", "Brass", "Steel", "Lens", "Ember", "LampGlass", "Emblem", "Star") else 0.66
        AF.mat(k, tuple(c * k_dark for c in v[0]), v[1], 0.0)
    j = AF.S(height, girth=girth)
    f = AF.Figure(name, height)
    builder(f, j)
    geo, groups = f.build()
    arm_ob = AF.make_armature(name, j)
    AF.skin(geo, arm_ob, groups, j)
    AF.build_clips(arm_ob, "utah")                   # Idle / Carry / Greet / Point + Walk
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    AF.export(path, arm_ob, geo)
    print("@@{\"person\": \"%s\", \"bytes\": %d, \"tris\": %d}" % (name, os.path.getsize(path), sum(len(p.vertices) - 2 for p in geo.data.polygons)))
