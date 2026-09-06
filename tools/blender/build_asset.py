#!/usr/bin/env python3
"""Headless Blender GLB asset builder for Episode 2 (Gold Mine Runner).

Runs entirely inside the Claude Code cloud sandbox via the `bpy` PyPI wheel —
NO GPU and NO display required, because GLB export serializes geometry +
materials and invokes no render pass. (Verified: Blender/bpy 5.0.1, Python
3.11; see artifacts/episode2-gold-mine/spec/ASSET_PIPELINE.md and the founder
research brief BLENDER_MCP_SETUP.md / the headless-3D follow-up.)

This is the pragmatic, in-container route for STYLIZED, hard-surface /
parametric props (minecart, rails, beams, lanterns, gold nuggets). It is NOT
a generative model — a hyper-real organic hero character still needs an
external text/image-to-3D API (Meshy/Rodin) or a human Blender artist. Set
expectations accordingly (both aesthetic reviews agree).

Usage:
    python3 tools/blender/build_asset.py <asset> <out.glb>
    python3 tools/blender/build_asset.py minecart src/episode2/assets/minecart.glb

Assets: minecart, gold_nugget, rail_segment.

Design rules (from the aesthetic review): low-poly, readable silhouette,
strong albedo/roughness contrast, emissive gold accents, cannabis-leaf
emblem on the cart. Kept deliberately modest so it web-exports and reads in
motion — not a cinematic sculpt.
"""
import bpy
import sys
import os
import math


def _reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _mat(name: str, color, metallic: float, rough: float, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        # Emissive gold-vein / lantern glow (cheap "glow" per the art review).
        b.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        b.inputs["Emission Strength"].default_value = emit[3]
    return m


def _box(name, size, loc, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    o.data.materials.append(mat)
    return o


def _cyl(name, radius, depth, loc, rot, mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=16)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    o.data.materials.append(mat)
    return o


def build_minecart() -> None:
    wood = _mat("Cart_Wood", (0.32, 0.18, 0.08), 0.0, 0.7)
    metal = _mat("Cart_Metal", (0.18, 0.16, 0.15), 1.0, 0.4)
    gold = _mat("Cart_GoldEmblem", (0.95, 0.75, 0.2), 1.0, 0.3, emit=(0.9, 0.7, 0.15, 0.6))
    # Hull (open-topped look faked with a solid box; refined later).
    _box("Hull", (1.8, 2.4, 1.1), (0.0, 0.0, 0.75), wood)
    # Metal rim band around the top.
    _box("Rim", (1.9, 2.5, 0.18), (0.0, 0.0, 1.32), metal)
    # Four wheels (cylinders on the X axis).
    for i, (x, y) in enumerate([(-0.95, -0.8), (0.95, -0.8), (-0.95, 0.8), (0.95, 0.8)]):
        _cyl("Wheel%d" % i, 0.42, 0.18, (x, y, 0.25), (0.0, math.pi / 2, 0.0), metal)
    # Cannabis-leaf gold emblem disc on the +X side (flat readable decal, per art review).
    emblem = _cyl("LeafEmblem", 0.62, 0.08, (0.96, 0.0, 0.78), (0.0, math.pi / 2, 0.0), gold)
    emblem.scale = (1.0, 1.0, 1.0)


def build_gold_nugget() -> None:
    gold = _mat("Nugget_Gold", (0.98, 0.78, 0.22), 1.0, 0.25, emit=(0.95, 0.72, 0.18, 1.2))
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, subdivisions=1)
    o = bpy.context.active_object
    o.name = "GoldNugget"
    o.data.materials.append(gold)


def build_rail_segment() -> None:
    wood = _mat("Tie_Wood", (0.28, 0.16, 0.08), 0.0, 0.8)
    steel = _mat("Rail_Steel", (0.22, 0.22, 0.24), 1.0, 0.35)
    # Two steel rails running along +Y, ties across.
    _box("RailL", (0.14, 6.0, 0.14), (-0.9, 0.0, 0.2), steel)
    _box("RailR", (0.14, 6.0, 0.14), (0.9, 0.0, 0.2), steel)
    for i in range(7):
        _box("Tie%d" % i, (2.4, 0.3, 0.14), (0.0, -3.0 + i * 1.0, 0.07), wood)


BUILDERS = {
    "minecart": build_minecart,
    "gold_nugget": build_gold_nugget,
    "rail_segment": build_rail_segment,
}


def _export(path: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    try:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")
    except Exception:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: build_asset.py <%s> <out.glb>" % "|".join(BUILDERS))
        return 2
    asset, out = sys.argv[1], sys.argv[2]
    if asset not in BUILDERS:
        print("unknown asset %r; known: %s" % (asset, list(BUILDERS)))
        return 2
    _reset()
    BUILDERS[asset]()
    _export(out)
    with open(out, "rb") as f:
        magic = f.read(4)
    ok = magic == b"glTF"
    print("BUILT %s -> %s (%d bytes) valid_glb=%s" % (asset, out, os.path.getsize(out), ok))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
