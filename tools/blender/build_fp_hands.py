#!/usr/bin/env python3
"""Lil Blunt's first-person HANDS + studded leather bracers, modelled in Blender (headless bpy), exported as one GLB.
Skill ep2-fps-shooter-feel (hands). Founder 2026-10-05: "the hands look shit ... can you build this better in Blender?"
Reference: .farm/range_refs/ref_hands_crop.png (chunky knitted-yarn green mittens, wide studded leather bracers with a
brass steer-head concho).

Everything is authored in RIFLE-LOCAL metres (muzzle +Z, stock -Z, +Y up, +X = the rifle's left) so the GLB drops
straight onto the Winchester node: `Ep2ViewHands.attach` instances it as a child of the rifle and every viewmodel
motion carries it. Blender is Z-up/-Y-forward, so a rifle-local point (x, y, z) is built at Blender (x, -z, y).

Organic parts are built the way a modeller blocks them: spheres + tapered cylinders per joint, joined, VOXEL-REMESHED
into one watertight skin, smoothed and decimated, then UV-unwrapped for a procedural yarn texture.

    pip install "bpy==4.2.0"
    python3 tools/blender/build_fp_hands.py src/episode2/assets/fp_hands.glb [--preview out.png]
"""
import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix

OUT = sys.argv[1] if len(sys.argv) > 1 else "fp_hands.glb"
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else ""
TEXDIR = os.path.join(os.path.dirname(os.path.abspath(OUT)), "textures")
os.makedirs(TEXDIR, exist_ok=True)


def B(p):
    """rifle-local (x, y, z) -> Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


# ----------------------------------------------------------------------------------------------------------- textures
def make_textures():
    from PIL import Image, ImageDraw, ImageFilter
    import random
    random.seed(7)
    # --- knitted green yarn: diagonal plied strands, light/dark per strand, fuzzy
    n = 256
    im = Image.new("RGB", (n, n), (58, 112, 36))
    d = ImageDraw.Draw(im)
    for i in range(-n, n * 2, 9):
        g = random.randint(-14, 14)
        col = (62 + g, 122 + g + random.randint(-6, 6), 38 + g // 2)
        d.line([(i, 0), (i + n, n)], fill=col, width=6)
        d.line([(i + 3, 0), (i + 3 + n, n)], fill=(col[0] - 22, col[1] - 28, col[2] - 14), width=1)
    for _ in range(2600):
        x, y = random.randint(0, n - 1), random.randint(0, n - 1)
        c = random.choice([(96, 160, 58), (36, 80, 24), (80, 140, 48)])
        d.point((x, y), fill=c)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(TEXDIR, "fp_yarn.png"), optimize=True)
    # --- leather: dark brown, grain, stitched seam along the edges
    im = Image.new("RGB", (n, n), (78, 44, 24))
    d = ImageDraw.Draw(im)
    for _ in range(5000):
        x, y = random.randint(0, n - 1), random.randint(0, n - 1)
        v = random.randint(-18, 14)
        d.point((x, y), fill=(78 + v, 44 + v // 2, 24 + v // 3))
    for x in range(0, n, 10):                       # stitching top + bottom
        d.line([(x, 14), (x + 5, 14)], fill=(190, 150, 90), width=2)
        d.line([(x, n - 15), (x + 5, n - 15)], fill=(190, 150, 90), width=2)
    for _ in range(26):                             # scuffs
        x, y = random.randint(0, n - 1), random.randint(0, n - 1)
        d.line([(x, y), (x + random.randint(-30, 30), y + random.randint(-6, 6))], fill=(46, 26, 14), width=1)
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    im.save(os.path.join(TEXDIR, "fp_leather.png"), optimize=True)


def material(name, tex=None, color=(1, 1, 1, 1), rough=0.8, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        bsdf.inputs["Emission Color"].default_value = emit
        bsdf.inputs["Emission Strength"].default_value = 0.25
    if tex:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.join(TEXDIR, tex))
        m.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    return m


# ------------------------------------------------------------------------------------------------------------ builders
def sphere(c, r, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=20, ring_count=12, location=B(c))
    o = bpy.context.active_object
    o.scale = scale
    return o


def tube(a, b, ra, rb, seg=14):
    """Tapered cylinder from rifle-local point a to b."""
    pa, pb = B(a), B(b)
    d = pb - pa
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=ra, radius2=rb, depth=d.length, location=(pa + pb) * 0.5)
    o = bpy.context.active_object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def skin(o, voxel=0.0045, smooth=2, tris=5000):
    """One watertight organic skin: voxel remesh -> smooth -> decimate -> smart UV."""
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mod = o.modifiers.new("remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier="remesh")
    sm = o.modifiers.new("smooth", "SMOOTH")
    sm.iterations = smooth
    sm.factor = 0.8
    bpy.ops.object.modifier_apply(modifier="smooth")
    dm = o.modifiers.new("dec", "DECIMATE")
    dm.ratio = min(1.0, tris / max(1, len(o.data.polygons) * 2))
    bpy.ops.object.modifier_apply(modifier="dec")
    bpy.ops.object.shade_smooth()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    return o


def finger(root, dirn, side_dir, lengths, radii, curl_deg):
    """A curled finger: chain of joint spheres + tubes. `dirn` = initial direction, `side_dir` = the axis it curls about
    (a finger curls AROUND the grip: each segment rotates by curl_deg about side_dir)."""
    parts = []
    p = Vector(root)
    d = Vector(dirn).normalized()
    ax = Vector(side_dir).normalized()
    parts.append(sphere(p, radii[0]))
    for i, ln in enumerate(lengths):
        q = p + d * ln
        parts.append(tube(p, q, radii[i], radii[i + 1]))
        parts.append(sphere(q, radii[i + 1]))
        p = q
        d = Matrix.Rotation(math.radians(curl_deg), 3, ax) @ d
    return parts


def hand(name, palm_c, palm_scale, grip_axis, wrap_side, thumb_dir, finger_z0, finger_dz, curl):
    """A chunky mitten-style hand wrapping a grip. wrap_side = +1/-1 which rifle-local X side the palm presses on."""
    parts = [sphere(palm_c, 0.056, palm_scale)]
    ps = Vector(palm_c)
    # four fingers: knuckles along the grip axis, curling across the wood to the far side
    for i in range(4):
        root = (ps.x + wrap_side * 0.012, ps.y + 0.016, finger_z0 + finger_dz * i)
        start_dir = (wrap_side * 0.35, 0.55, 0.0)
        cur = 8.0 if i in (0, 3) else 0.0
        parts += finger(root, start_dir, (0, 0, 1), [0.036, 0.03, 0.026], [0.0155 - 0.001 * abs(i - 1.5), 0.0145, 0.0128, 0.0105],
                        -wrap_side * curl)
    # thumb: stout, pointing along thumb_dir
    t0 = (ps.x - wrap_side * 0.02, ps.y + 0.02, ps.z + 0.01)
    parts += finger(t0, thumb_dir, (0, 0, 1), [0.04, 0.034], [0.0185, 0.0165, 0.0135], wrap_side * 28)
    return skin(join(parts, name), tris=4500)


def forearm(name, wrist, back, length=0.5, r_wrist=0.036, r_elbow=0.044):
    w = Vector(wrist)
    b = Vector(back).normalized()
    parts = [tube(w, w + b * length, r_wrist, r_elbow, seg=18)]
    o = join(parts, name)
    return skin(o, voxel=0.006, smooth=1, tris=1800)


def bracer(name, wrist, back, c0=0.04, length=0.16, r=0.054):
    """Wide studded leather cuff with a brass band, studs and a steer-head concho."""
    w = Vector(wrist)
    b = Vector(back).normalized()
    a = w + b * c0
    z = w + b * (c0 + length)
    cuff = tube(a, z, r, r * 1.12, seg=28)
    cuff.name = name + "_cuff"
    objs = [cuff]
    # brass band at the wrist edge
    band = tube(w + b * (c0 - 0.012), w + b * (c0 + 0.02), r * 1.04, r * 1.04, seg=28)
    band.name = name + "_band"
    # studs: two rings of small brass domes round the cuff
    studs = []
    side = Vector((0, 0, 1)).cross(b)
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = b.cross(side).normalized()
    for ring_t in (0.25, 0.8):
        centre = a + (z - a) * ring_t
        rad = (r * (1 + 0.12 * ring_t)) * 1.0
        for k in range(14):
            ang = k * math.tau / 14
            pos = centre + (side * math.cos(ang) + up * math.sin(ang)) * (rad + 0.004)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0085, segments=10, ring_count=6, location=pos)
            studs.append(bpy.context.active_object)
    # concho: brass disc on the outside of the cuff with two horns
    cpos = a + (z - a) * 0.5 + up * (r * 1.1 + 0.004)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.034, depth=0.008, location=cpos)
    disc = bpy.context.active_object
    disc.rotation_mode = "QUATERNION"
    disc.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(up)
    studs.append(disc)
    for sgn in (-1, 1):
        horn = tube(Vector(cpos) + side * sgn * 0.01, Vector(cpos) + side * sgn * 0.03 + up * 0.012 + b * 0.012, 0.006, 0.0025, seg=8)
        studs.append(horn)
    brass = join([band] + studs, name + "_brass")
    return cuff, brass


# ------------------------------------------------------------------------------------------------------------------ main
bpy.ops.wm.read_factory_settings(use_empty=True)
make_textures()
yarn = material("Yarn", "fp_yarn.png", rough=0.95)
leather = material("Leather", "fp_leather.png", rough=0.7)
brass = material("Brass", color=(0.80, 0.58, 0.20, 1), rough=0.32, metal=0.85, emit=(0.8, 0.55, 0.2, 1))

# RIGHT hand (the camera's right = rifle-local -X): gripping the wrist of the stock behind the receiver.
rh = hand("RightHand", (-0.012, -0.072, -0.20), (1.0, 0.85, 1.2), "z", -1, (0.1, 0.6, 0.55), -0.235, 0.026, 62)
# LEFT hand (rifle-local +X): cupped under the fore-end, fingers up over the wood.
lh = hand("LeftHand", (0.0, -0.086, 0.22), (1.0, 0.8, 1.15), "z", 1, (-0.1, 0.55, -0.5), 0.17, 0.026, 62)
objs = []
for ob, mat in ((rh, yarn), (lh, yarn)):
    ob.data.materials.append(mat)
    objs.append(ob)
# forearms + bracers run back toward the camera and outward
for side_name, wrist, back in (("Right", (-0.03, -0.085, -0.235), (-0.62, -0.30, -0.72)), ("Left", (0.02, -0.095, 0.15), (0.68, -0.20, -0.70))):
    fa = forearm(side_name + "Forearm", wrist, back)
    fa.data.materials.append(leather)
    cuff, br = bracer(side_name + "Bracer", wrist, back)
    cuff.data.materials.append(leather)
    br.data.materials.append(brass)
    bpy.context.view_layer.objects.active = cuff
    bpy.ops.object.shade_smooth()
    bpy.context.view_layer.objects.active = br
    bpy.ops.object.shade_smooth()
    objs += [fa, cuff, br]

# unwrap the cuffs (simple cylinder UVs) so the leather texture lays out
for ob in bpy.data.objects:
    if ob.name.endswith("_cuff"):
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cylinder_project()
        bpy.ops.object.mode_set(mode="OBJECT")

tri = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
print("HANDS built, polygons ~", tri)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_texcoords=True,
                          export_normals=True, export_materials="EXPORT", export_image_format="AUTO")
print("wrote", OUT, os.path.getsize(OUT) // 1024, "KB")

if PREVIEW:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x, sc.render.resolution_y = 900, 600
    cam_d = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("c", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.location = Vector((0.15, 0.55, 0.28))
    d = Vector((0, 0.0, -0.05)) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render()
    bpy.data.images["Render Result"].save_render(PREVIEW)
    print("preview", PREVIEW)
