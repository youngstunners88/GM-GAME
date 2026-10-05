"""Headless Blender builder for the target-practice range props (founder 2026-10-05: "the targets are trash").

    python3 tools/blender/build_range_props.py src/episode2/assets/hideout

Writes (deterministic, no RNG - index arithmetic only):
  range_wall.glb     bevelled, staggered plank wall with nails, cross-braces and chipped edges. Front face at origin
                     facing Godot +Z (toward the firing line), body running back along Godot -Z.
  range_plaque.glb   a target mount: chamfered timber board, a riveted iron rim and a dark steel face disc. Origin = hit
                     centre. The glowing ring and the logo quad stay in GDScript so they can dim / swap per hit.

Blender is Z-up; glTF Y-up. Godot +Z (toward the player) == Blender -Y, so every "front" below faces Blender -Y.
Skill: range-blender-props.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

OUT = os.path.abspath(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1])
os.makedirs(OUT, exist_ok=True)
TEX = os.path.join(OUT, "textures")
os.makedirs(TEX, exist_ok=True)
PLATE_R = 0.42


def make_textures():
    from PIL import Image, ImageDraw, ImageFilter
    import random
    random.seed(11)
    n = 256
    for name, base in (("range_plank_a.png", (112, 74, 42)), ("range_plank_b.png", (96, 62, 36)),
                       ("range_plank_c.png", (126, 86, 50))):
        im = Image.new("RGB", (n, n), base)
        d = ImageDraw.Draw(im)
        for y in range(0, n, 2):                       # long grain lines
            v = random.randint(-16, 12)
            d.line([(0, y), (n, y + random.randint(-2, 2))], fill=(base[0] + v, base[1] + v * 2 // 3, base[2] + v // 2), width=1)
        for _ in range(5):                             # knots
            x, y = random.randint(20, n - 20), random.randint(20, n - 20)
            for rr in (11, 8, 5, 2):
                c = 40 + (11 - rr) * 4
                d.ellipse([x - rr, y - rr * 2, x + rr, y + rr * 2], outline=(c, c * 2 // 3, c // 3))
        for _ in range(900):                           # soot / dirt speckle
            d.point((random.randint(0, n - 1), random.randint(0, n - 1)), fill=(36, 24, 14))
        im.filter(ImageFilter.GaussianBlur(0.4)).save(os.path.join(TEX, name), optimize=True)


def material(name, tex=None, color=(0.5, 0.5, 0.5, 1), rough=0.85, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if tex:
        t = m.node_tree.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(os.path.join(TEX, tex))
        m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    return m


def box(name, size, loc, bevel=0.01, mat=None, rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.rotation_euler[2] = rot_z
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    if bevel:
        m = o.modifiers.new("bev", "BEVEL")
        m.width = bevel
        m.segments = 2
        bpy.ops.object.modifier_apply(modifier="bev")
    if mat:
        o.data.materials.append(mat)
    return o


def cyl(name, r, depth, loc, axis_y=True, verts=20, mat=None, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    if axis_y:
        o.rotation_euler[0] = math.pi / 2
        bpy.ops.object.transform_apply(rotation=True)
    if bevel:
        m = o.modifiers.new("bev", "BEVEL")
        m.width = bevel
        m.segments = 2
        bpy.ops.object.modifier_apply(modifier="bev")
    if mat:
        o.data.materials.append(mat)
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


def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_texcoords=True, export_normals=True, export_materials="EXPORT")
    print("wrote", path, os.path.getsize(path) // 1024, "KB")


def build_wall():
    """Staggered vertical planks (11 m x 6.4 m): each slightly different in width, depth, height and tint; two
    horizontal braces with iron nails; chipped top edges. Front face of the planks at y=0, body toward +Y."""
    mats = [material("PlankA", "range_plank_a.png"), material("PlankB", "range_plank_b.png"),
            material("PlankC", "range_plank_c.png")]
    iron = material("Iron", color=(0.10, 0.10, 0.11, 1), rough=0.55, metal=0.8)
    parts_by_mat = {0: [], 1: [], 2: [], "iron": []}
    n = 20
    total = 11.0
    w = total / n
    for i in range(n):
        h = 6.4 - ((i * 7) % 5) * 0.09                  # ragged tops
        depth = 0.14 + ((i * 3) % 4) * 0.012
        x = -total / 2 + w * (i + 0.5)
        gap = 0.012 + ((i * 5) % 3) * 0.004
        o = box("plank%d" % i, (w - gap, depth, h), (x, depth / 2 - ((i * 3) % 3) * 0.008, h / 2), bevel=0.012,
                mat=mats[(i * 2 + i // 3) % 3])
        o.rotation_euler[1] = (((i * 11) % 7) - 3) * 0.0008
        parts_by_mat[(i * 2 + i // 3) % 3].append(o)
    # braces + nails
    for bz in (1.4, 4.6):
        brace = box("brace", (total - 0.2, 0.09, 0.26), (0.0, -0.04, bz), bevel=0.016, mat=mats[1])
        parts_by_mat[1].append(brace)
        for i in range(n):
            x = -total / 2 + w * (i + 0.5)
            nail = cyl("nail", 0.014, 0.03, (x, -0.09, bz), verts=8, mat=iron)
            parts_by_mat["iron"].append(nail)
    objs = []
    for key, lst in parts_by_mat.items():
        if lst:
            objs.append(join(lst, "wall_%s" % key))
    # bake: single object per material, parent to an empty at the origin
    export(os.path.join(OUT, "range_wall.glb"), objs)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)


def build_plaque():
    r = PLATE_R
    wood = material("PlaqueWood", "range_plank_b.png")
    iron = material("PlaqueIron", color=(0.13, 0.13, 0.14, 1), rough=0.5, metal=0.85)
    brass = material("PlaqueRivet", color=(0.75, 0.55, 0.2, 1), rough=0.35, metal=0.85)
    parts = []
    # chamfered board: a square with its corners cut (octagon-ish) from a bevelled box
    parts.append(box("board", (r * 2.6, 0.07, r * 2.6), (0, 0.06, 0), bevel=0.03, mat=wood))
    # dark steel face disc, just behind the logo quad plane (y = 0 is the logo plane, facing -Y)
    face = cyl("face", r * 1.0, 0.012, (0, 0.012, 0), verts=40, mat=iron)
    parts.append(face)
    # riveted iron rim (outside the green ring at r*1.14)
    bpy.ops.mesh.primitive_torus_add(major_radius=r * 1.26, minor_radius=0.026, major_segments=40, minor_segments=10,
                                     location=(0, -0.006, 0), rotation=(math.pi / 2, 0, 0))
    rim = bpy.context.active_object
    rim.name = "rim"
    rim.data.materials.append(iron)
    parts.append(rim)
    for k in range(8):                                  # rivets on the board corners / edges
        a = k * math.tau / 8 + math.pi / 8
        c = r * 1.26
        parts.append(cyl("rivet", 0.02, 0.02, (math.cos(a) * c * 1.0, -0.02, math.sin(a) * c * 1.0), verts=10, mat=brass))
    o = join(parts, "plaque")
    export(os.path.join(OUT, "range_plaque.glb"), [o])


bpy.ops.wm.read_factory_settings(use_empty=True)
make_textures()
build_wall()
build_plaque()
