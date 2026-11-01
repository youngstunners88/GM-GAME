"""RICH & UTAH'S NEW STOCK (founder 2026-11-01: "We also need more weapons like a shotgun. We also need a bergmann mp18 submachine gun
and a golden thompson submachine gun", with his reference photos of an MP18 with its snail drum and a gold-finish 1928 Thompson).

Three hard-surface guns built from bevelled primitives and extruded wood profiles, real-world size, in the game's weapon frame:
  coach_shotgun.glb      double-barrel coach gun with twin external hammers (the Western shotgun of the period)
  bergmann_mp18.glb      perforated barrel jacket, receiver tube, side-mounted snail drum, full wooden stock
  thompson_gold.glb      gold-finish 1928 Thompson: finned barrel, Cutts compensator, vertical foregrip, 50-round drum, walnut furniture

Frame (Blender): muzzle toward -Y, up +Z, the trigger at the origin; the glTF exporter turns that into the game frame (muzzle +Z, up +Y)
the viewmodel and the Armory showcase both expect. The shooter's left is +X (the MP18's magazine side).

  blender -b --factory-startup -P tools/ep2_blender/build_armory_new_guns.py -- [--which all|coach|mp18|thompson] [--icons] [--samples 32]

GLBs go to src/episode2/assets/weapons/armory/, icons (640 x 320 transparent, muzzle left, the same studio as the other cards, with
Lil Blunt's green mitten hands on the grip and the fore-end so the set stays consistent) to <name>_icon.png beside them.
Prints each file with its bounds and triangle count.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
OUT_DIR = os.path.join(ROOT, "src/episode2/assets/weapons/armory")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
WHICH = argv[argv.index("--which") + 1] if "--which" in argv else "all"
ICONS = "--icons" in argv
SAMPLES = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 32


# --- materials -------------------------------------------------------------------------------------------------------------------

def mat(name, rgb, metal, rough):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
        m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


def materials():
    return {
        "blued": mat("BluedSteel", (0.055, 0.058, 0.066), 0.85, 0.36),
        "case": mat("CaseHardened", (0.30, 0.27, 0.24), 0.8, 0.42),
        "black": mat("BlackSteel", (0.03, 0.03, 0.032), 0.7, 0.5),
        "walnut": mat("Walnut", (0.08, 0.03, 0.013), 0.0, 0.4),
        "beech": mat("Beech", (0.17, 0.07, 0.027), 0.0, 0.42),
        "gold": mat("GoldFinish", (1.0, 0.76, 0.33), 1.0, 0.24),
        "brass": mat("Brass", (0.86, 0.66, 0.30), 1.0, 0.32),
        "bead": mat("SightBead", (0.9, 0.86, 0.72), 0.6, 0.3),
    }


# --- primitives --------------------------------------------------------------------------------------------------------------------

PARTS = []


def _finish(obj, m, bevel=0.0, segments=2):
    obj.data.materials.append(m)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    PARTS.append(obj)
    return obj


def cyl(name, r, length, center, m, axis="Y", verts=28, bevel=0.0008, r2=None):
    """A cylinder of radius r (top radius r2 when tapered) along `axis`, centred at `center`."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=length, location=center)
    o = bpy.context.object
    o.name = name
    if axis == "Y":
        o.rotation_euler = (math.radians(90), 0, 0)
    elif axis == "X":
        o.rotation_euler = (0, math.radians(90), 0)
    return _finish(o, m, bevel)


def box(name, size, center, m, bevel=0.0015, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, m, bevel, 2)


def sphere(name, r, center, m, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=r, location=center)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, m)


def torus(name, major, minor, center, m, axis="X"):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=28, minor_segments=8, location=center)
    o = bpy.context.object
    o.name = name
    if axis == "X":
        o.rotation_euler = (0, math.radians(90), 0)
    return _finish(o, m)


def profile(name, pts_yz, width, m, x=0.0, bevel=0.004):
    """A wood part: the side profile (y, z) polygon extruded `width` across X, edges rounded."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x - width * 0.5, y, z)) for (y, z) in pts_yz]
    back = [bm.verts.new((x + width * 0.5, y, z)) for (y, z) in pts_yz]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(pts_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    _finish(o, m, bevel, 3)
    o.modifiers["Bevel"].angle_limit = math.radians(25)
    return o


def drill(target, holes):
    """Cut round holes through `target` (a list of (center, axis_vector, radius, depth))."""
    for i, (c, axis, r, depth) in enumerate(holes):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=depth, location=c)
        cutter = bpy.context.object
        cutter.rotation_euler = Vector(axis).to_track_quat("Z", "Y").to_euler()
        mod = target.modifiers.new("Hole%d" % i, "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = cutter
        try:
            mod.solver = "EXACT"
        except TypeError:
            pass
        cutter.hide_render = True
        cutter.hide_viewport = True
        cutter["cutter"] = True


# --- the three guns ----------------------------------------------------------------------------------------------------------------

def build_coach(M):
    for side in (-1, 1):
        cyl("Barrel", 0.0118, 0.50, (side * 0.0122, -0.32, 0.036), M["blued"], r2=0.0112)
        cyl("Muzzle", 0.0122, 0.012, (side * 0.0122, -0.566, 0.036), M["blued"])
        # an external hammer each side: a curved spur sitting back over the action
        box("Hammer", (0.006, 0.014, 0.03), (side * 0.0165, 0.012, 0.062), M["case"], 0.002, (math.radians(-28), 0, 0))
        box("HammerSpur", (0.008, 0.016, 0.006), (side * 0.0165, 0.022, 0.077), M["case"], 0.0015)
    box("TopRib", (0.009, 0.50, 0.006), (0, -0.32, 0.0485), M["blued"], 0.0012)
    box("UnderRib", (0.012, 0.48, 0.012), (0, -0.33, 0.022), M["blued"], 0.0015)
    sphere("FrontBead", 0.0022, (0, -0.565, 0.0535), M["bead"])
    box("Action", (0.038, 0.105, 0.052), (0, -0.028, 0.026), M["case"], 0.003)
    box("TopLever", (0.008, 0.03, 0.006), (0, 0.035, 0.054), M["case"], 0.0015)
    torus("TriggerGuard", 0.02, 0.0028, (0, 0.012, -0.012), M["blued"])
    box("TriggerFront", (0.004, 0.006, 0.02), (0, 0.004, -0.008), M["blued"], 0.001, (math.radians(15), 0, 0))
    box("TriggerRear", (0.004, 0.006, 0.02), (0, 0.016, -0.008), M["blued"], 0.001, (math.radians(15), 0, 0))
    profile("ForeEnd", [(-0.08, 0.0), (-0.30, 0.012), (-0.31, 0.028), (-0.08, 0.03)], 0.04, M["walnut"])
    profile("Stock", [(0.02, 0.046), (0.13, 0.034), (0.36, 0.052), (0.365, 0.05), (0.37, -0.105),
        (0.35, -0.112), (0.15, -0.035), (0.02, -0.004)], 0.042, M["walnut"])
    box("ButtPlate", (0.044, 0.006, 0.16), (0, 0.372, -0.028), M["black"], 0.0015, (math.radians(-3), 0, 0))
    return {"muzzle": (0, -0.575, 0.036), "rear_sight": (0, -0.08, 0.052), "grip": (0, 0.07, 0.0), "fore": (0, -0.2, 0.012)}


def build_mp18(M):
    jacket = cyl("BarrelJacket", 0.0188, 0.215, (0, -0.205, 0.0), M["blued"], verts=32)
    holes = []
    for k in range(7):                                    # rows of cooling holes along the jacket, six around (the reference)
        y = -0.12 - k * 0.028
        for a in range(6):
            ang = a * math.tau / 6.0 + (0.26 if k % 2 else 0.0)
            d = Vector((math.cos(ang), 0.0, math.sin(ang)))
            holes.append(((d.x * 0.0188, y, d.z * 0.0188), (d.x, 0.0, d.z), 0.0042, 0.02))
    drill(jacket, holes)
    cyl("Bore", 0.0135, 0.215, (0, -0.205, 0.0), M["black"], verts=20)          # the barrel seen through the holes
    cyl("JacketCap", 0.0192, 0.012, (0, -0.318, 0.0), M["blued"])
    cyl("Muzzle", 0.0075, 0.02, (0, -0.334, 0.0), M["blued"])
    box("FrontSight", (0.003, 0.008, 0.012), (0, -0.312, 0.024), M["blued"], 0.0008)
    cyl("Receiver", 0.0185, 0.25, (0, 0.025, 0.0), M["blued"], verts=32)
    cyl("EndCap", 0.0175, 0.016, (0, 0.157, 0.0), M["blued"])
    box("RearSight", (0.012, 0.016, 0.01), (0, 0.11, 0.022), M["blued"], 0.001)
    sphere("BoltKnob", 0.0065, (-0.026, 0.07, 0.006), M["blued"])
    box("BoltStem", (0.012, 0.004, 0.004), (-0.02, 0.07, 0.006), M["blued"], 0.0008)
    # the magazine well on the LEFT and the 32-round "snail" drum on its neck, disc face sideways (TM08, the reference photo)
    box("MagWell", (0.045, 0.034, 0.03), (0.036, -0.075, 0.004), M["blued"], 0.0015)
    box("DrumNeck", (0.03, 0.03, 0.05), (0.072, -0.075, 0.028), M["blued"], 0.0015, (0, math.radians(-25), 0))
    cyl("SnailDrum", 0.05, 0.034, (0.098, -0.075, 0.058), M["blued"], axis="X", verts=40)
    cyl("DrumHub", 0.016, 0.04, (0.098, -0.075, 0.058), M["black"], axis="X")
    profile("Stock", [(-0.10, -0.012), (0.12, -0.012), (0.20, -0.022), (0.50, 0.016), (0.505, 0.012), (0.51, -0.125),
        (0.49, -0.132), (0.24, -0.06), (0.15, -0.058), (0.13, -0.044), (-0.10, -0.04)], 0.04, M["beech"])
    torus("TriggerGuard", 0.019, 0.0028, (0, 0.135, -0.058), M["blued"])
    box("Trigger", (0.004, 0.006, 0.02), (0, 0.13, -0.054), M["blued"], 0.001, (math.radians(15), 0, 0))
    return {"muzzle": (0, -0.346, 0.0), "rear_sight": (0, 0.11, 0.027), "grip": (0, 0.18, -0.05), "fore": (0, -0.04, -0.03)}


def build_thompson(M):
    G, W = M["gold"], M["walnut"]
    box("Receiver", (0.036, 0.25, 0.062), (0, 0.005, 0.012), G, 0.003)
    box("ReceiverRail", (0.02, 0.2, 0.008), (0, 0.0, 0.047), G, 0.0015)
    sphere("ActuatorKnob", 0.007, (0, -0.06, 0.054), G)
    box("RearSight", (0.016, 0.02, 0.016), (0, 0.095, 0.054), G, 0.0015)
    cyl("Barrel", 0.0095, 0.30, (0, -0.27, 0.022), G, verts=24)
    for k in range(16):                                   # the finned cooling section
        cyl("Fin", 0.0165, 0.0035, (0, -0.135 - k * 0.0095, 0.022), G, verts=28, bevel=0.0)
    cyl("Compensator", 0.0135, 0.055, (0, -0.445, 0.022), G, verts=24)
    for k in range(3):
        box("CompSlot", (0.022, 0.004, 0.005), (0, -0.432 - k * 0.012, 0.035), M["black"], 0.0005)
    box("FrontSight", (0.003, 0.008, 0.014), (0, -0.465, 0.04), G, 0.0008)
    # vertical fore grip with finger grooves (wavy front edge)
    grip_pts = [(-0.195, 0.012), (-0.235, 0.012), (-0.24, -0.02), (-0.232, -0.035), (-0.24, -0.05), (-0.232, -0.065),
        (-0.24, -0.08), (-0.232, -0.095), (-0.236, -0.108), (-0.2, -0.112), (-0.196, -0.06)]
    profile("ForeGrip", grip_pts, 0.032, W, bevel=0.005)
    box("ForeGripMount", (0.02, 0.04, 0.012), (0, -0.215, 0.012), G, 0.0015)
    # the 50-round L drum hanging under the receiver's front
    cyl("Drum", 0.083, 0.046, (0, -0.07, -0.088), G, axis="X", verts=48)
    cyl("DrumKey", 0.013, 0.054, (0, -0.07, -0.088), M["brass"], axis="X")
    torus("DrumRim", 0.081, 0.003, (0.023, -0.07, -0.088), G)
    torus("DrumRim2", 0.081, 0.003, (-0.023, -0.07, -0.088), G)
    profile("PistolGrip", [(0.05, -0.018), (0.09, -0.018), (0.112, -0.11), (0.08, -0.118), (0.056, -0.05)], 0.034, W, bevel=0.005)
    torus("TriggerGuard", 0.019, 0.0028, (0, 0.038, -0.03), G)
    box("Trigger", (0.004, 0.006, 0.02), (0, 0.033, -0.026), G, 0.001, (math.radians(15), 0, 0))
    profile("Stock", [(0.125, 0.034), (0.15, 0.03), (0.44, 0.04), (0.445, 0.036), (0.45, -0.115), (0.43, -0.122),
        (0.2, -0.05), (0.125, -0.016)], 0.04, W)
    box("ButtPlate", (0.042, 0.006, 0.158), (0, 0.452, -0.04), G, 0.0015, (math.radians(-2), 0, 0))
    return {"muzzle": (0, -0.475, 0.022), "rear_sight": (0, 0.095, 0.062), "grip": (0, 0.085, -0.06), "fore": (0, -0.22, -0.05)}


GUNS = {
    "coach": ("coach_shotgun", build_coach),
    "mp18": ("bergmann_mp18", build_mp18),
    "thompson": ("thompson_gold", build_thompson),
}


# --- icon hands (the card set shows Lil Blunt's green mittens on every gun) ---------------------------------------------------------

def icon_hands(anchors):
    skin = mat("LeafSkin", (0.30, 0.62, 0.17), 0.0, 0.9)
    leather = mat("Bracer", (0.30, 0.17, 0.09), 0.0, 0.8)
    made = []
    for key, back in (("grip", Vector((0.0, 0.55, -0.6))), ("fore", Vector((0.0, 0.25, -0.9)))):
        c = Vector(anchors[key])
        made.append(sphere("IconPalm", 0.024, c + Vector((0.024, 0, 0)), skin, (0.7, 1.1, 1.0)))
        for i in range(4):
            made.append(sphere("IconFinger", 0.008, c + Vector((0.027, -0.018 + i * 0.012, 0.014)), skin, (0.8, 0.9, 1.6)))
        d = back.normalized()
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.026, depth=0.07, location=c + Vector((0.026, 0, 0)) + d * 0.05)
        bracer = bpy.context.object
        bracer.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        made.append(_finish(bracer, leather))
    return made


def studio(objs, out_png):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 320
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.65, 0.65, 0.68, 1)
    bg.inputs["Strength"].default_value = 0.7
    scene.world = world
    pts = []
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        if o.hide_render:
            continue
        eo = o.evaluated_get(dg)
        me = eo.to_mesh()
        pts += [eo.matrix_world @ v.co for v in me.vertices]
        eo.to_mesh_clear()
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    mid = (lo + hi) * 0.5
    span = max(hi.y - lo.y, (hi.z - lo.z) * 2.0)
    cam_data = bpy.data.cameras.new("IconCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = span * 1.08
    cam = bpy.data.objects.new("IconCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = mid + Vector((1.5, 0.0, 0.25))           # the +X flank: muzzle (-Y) lands on the LEFT of the card
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for name, loc, power in (("Key", (1.2, 0.6, 1.0), 26.0), ("Fill", (0.8, -0.9, 0.3), 11.0), ("Rim", (-1.0, 0.0, 0.8), 9.0)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = power
        ld.size = 0.8
        lo_ = bpy.data.objects.new(name, ld)
        scene.collection.objects.link(lo_)
        lo_.location = mid + Vector(loc)
        lo_.rotation_euler = (mid - lo_.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)


def export(stem):
    for o in bpy.data.objects:
        o.select_set(False)
    keep = [o for o in PARTS if not o.get("cutter")]
    for o in keep:
        o.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    path = os.path.join(OUT_DIR, stem + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    tris = 0
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in keep:
        eo = o.evaluated_get(dg)
        me = eo.to_mesh()
        me.calc_loop_triangles()
        tris += len(me.loop_triangles)
        pts += [eo.matrix_world @ v.co for v in me.vertices]
        eo.to_mesh_clear()
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    print("GLB %s tris=%d bounds_blender=%s..%s size=%s" % (path, tris, [round(v, 3) for v in lo], [round(v, 3) for v in hi],
        [round(hi[i] - lo[i], 3) for i in range(3)]))
    return keep


for key, (stem, builder) in GUNS.items():
    if WHICH not in ("all", key):
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PARTS.clear()
    anchors = builder(materials())
    print("ANCHORS %s %s" % (stem, anchors))
    keep = export(stem)
    if ICONS:
        hands = icon_hands(anchors)
        studio(keep + hands, os.path.join(OUT_DIR, stem + "_icon.png"))
        print("ICON %s" % os.path.join(OUT_DIR, stem + "_icon.png"))
