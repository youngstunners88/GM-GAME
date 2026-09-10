#!/usr/bin/env python3
"""Headless Blender GLB asset builder for Episode 2 (Gold Mine Runner).

Runs entirely inside the Claude Code cloud sandbox via the `bpy` PyPI wheel —
NO GPU and NO display required, because GLB export serializes geometry +
materials and invokes no render pass. (Path E in
artifacts/episode2-gold-mine/spec/ASSET_PIPELINE.md.)

    pip install "bpy==4.3.0" "numpy<2"

The numpy pin is not optional: bpy 4.3 links against the numpy 1.x C ABI, and
a default `pip install bpy` pulls numpy 2.x alongside it, after which every
import dies with "numpy.core.multiarray failed to import" while `bpy` itself
still reports a version. Pin it, or lose an hour.

Usage:
    python3 tools/blender/build_asset.py <asset> <out.glb>
    python3 tools/blender/build_asset.py all src/episode2/assets

Assets: minecart, gold_nugget, gold_pile, rail_segment, lantern, wood_beam,
        boulder.

MATERIAL VALUES ARE NOT FREEHAND. They mirror src/episode2/art/ep2_palette.gd,
which traces every colour to the founder reference images in
artifacts/founder-art/references/. A prop whose materials disagree with the
palette reads as a prop from a different game, so when one changes, change
both — there is no automated link between a Python dict and a GDScript table,
only this note.

The 2026-09-10 fidelity review's top finding was "darkness erases the playable
scene": the first generation of these props used albedo around 0.3 and
disappeared into the tunnel. Values here are deliberately a stop or two
brighter than the raw reference sample, because a lit photograph's dark
midtones are not the same thing as an albedo texture.
"""
import bpy
import sys
import os
import math

# --- palette (mirror of src/episode2/art/ep2_palette.gd) ----------------------
WOOD        = (0.42, 0.26, 0.14)
WOOD_DARK   = (0.28, 0.17, 0.09)
BRASS       = (0.72, 0.52, 0.24)
IRON        = (0.46, 0.46, 0.49)
GOLD        = (0.95, 0.78, 0.36)
ROCK        = (0.24, 0.22, 0.20)
GRANITE     = (0.50, 0.50, 0.48)
LANTERN_LIT = (1.00, 0.78, 0.42)


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
        b.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        b.inputs["Emission Strength"].default_value = emit[3]
    return m


def _box(name, size, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    o.rotation_euler = rot
    o.data.materials.append(mat)
    return o


def _cyl(name, radius, depth, loc, rot, mat, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    o.data.materials.append(mat)
    return o


def _ico(name, radius, loc, mat, subdiv=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, subdivisions=subdiv, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.data.materials.append(mat)
    return o


# --- assets -------------------------------------------------------------------

def build_minecart() -> None:
    """Open-topped timber cart with brass banding and a gold leaf emblem.

    Rebuilt 2026-09-10. The first version was a SOLID box with one thin disc
    stuck on the +X face: in the first browser capture the disc rendered as an
    unexplained bright vertical bar beside the cart, and the fidelity review
    flagged the foreground subject as having "little reference identity".
    This version has real walls (so it reads as a container you ride IN), and
    the emblem is on BOTH sides, which is both what a real cart looks like and
    removes any dependence on which way the model gets rotated in engine.
    """
    wood = _mat("Cart_Wood", WOOD, 0.0, 0.75)
    wood_d = _mat("Cart_WoodDark", WOOD_DARK, 0.0, 0.8)
    brass = _mat("Cart_Brass", BRASS, 0.65, 0.35)
    iron = _mat("Cart_Iron", IRON, 0.55, 0.42)
    gold = _mat("Cart_GoldEmblem", GOLD, 0.7, 0.28, emit=(0.95, 0.74, 0.28, 0.35))

    W, L, H = 1.9, 2.5, 1.15          # outer width, length, height
    T = 0.11                          # plank thickness

    _box("Floor", (W, L, T), (0.0, 0.0, 0.42), wood_d)
    for sx in (-1.0, 1.0):            # long sides
        _box("Side%+d" % sx, (T, L, H), (sx * (W / 2 - T / 2), 0.0, 0.42 + H / 2), wood)
    for sy in (-1.0, 1.0):            # ends
        _box("End%+d" % sy, (W, T, H), (0.0, sy * (L / 2 - T / 2), 0.42 + H / 2), wood)

    # Brass bands top and bottom — the strongest read in every reference.
    for z in (0.50, 0.42 + H - 0.12):
        _box("BandOuter@%.2f" % z, (W + 0.06, L + 0.06, 0.13), (0.0, 0.0, z), brass)
    # Corner rivet posts.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box("Rivet%+d%+d" % (sx, sy), (0.14, 0.14, H),
                 (sx * (W / 2 - 0.05), sy * (L / 2 - 0.05), 0.42 + H / 2), brass)

    # Undercarriage + four wheels on iron axles.
    _box("Chassis", (W - 0.2, L - 0.15, 0.16), (0.0, 0.0, 0.34), iron)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _cyl("Wheel%+d%+d" % (sx, sy), 0.34, 0.16,
                 (sx * (W / 2 + 0.04), sy * 0.78, 0.20), (0.0, math.pi / 2, 0.0), iron)
            _cyl("Hub%+d%+d" % (sx, sy), 0.11, 0.20,
                 (sx * (W / 2 + 0.04), sy * 0.78, 0.20), (0.0, math.pi / 2, 0.0), brass)

    # Gold cannabis-leaf emblem: a disc plus seven radiating leaflets. An
    # actual leaf outline needs a texture or a real mesh; at 12 m/s the radial
    # silhouette inside a circle is what reads.
    #
    # Placed on the SIDES *and* the REAR. The rear one is the one that matters:
    # this is a chase-camera runner, so the player spends the entire episode
    # looking at the back of the cart and never once sees its flanks. The first
    # build put the emblem only on the sides, and the browser capture showed it
    # edge-on as two pale vertical bars poking past the cart like handles —
    # which is also why the leaflets are now thin in their out-of-plane axis
    # and inset, instead of standing proud of the panel.
    def emblem(origin, axis):
        """axis 'x' = side panel (leaf in the Y-Z plane); 'y' = rear panel."""
        rot = (0.0, math.pi / 2, 0.0) if axis == "x" else (math.pi / 2, 0.0, 0.0)
        # Disc RADIUS 0.30, leaflets out to 0.40 and standing 0.03 PROUD of it.
        # The first version had a 0.40 disc with the leaflets flush inside it,
        # so the browser capture showed a featureless gold circle: the leaf —
        # the entire brand mark — was occluded by its own backing plate.
        _cyl("EmblemDisc_%s" % axis, 0.30, 0.04, origin, rot, gold, verts=20)
        out = 0.05 if origin[0] >= 0.0 else -0.05
        for i in range(7):
            ang = math.radians(-72.0 + i * 24.0)
            r = 0.30 if i in (0, 6) else (0.36 if i in (1, 5) else 0.42)
            if axis == "x":
                size = (0.035, 0.07, r)
                loc = (origin[0] + out, origin[1] + math.sin(ang) * r * 0.5, origin[2] + math.cos(ang) * r * 0.5)
                lrot = (ang, 0.0, 0.0)
            else:
                size = (0.07, 0.035, r)
                loc = (origin[0] + math.sin(ang) * r * 0.5, origin[1] - 0.05, origin[2] + math.cos(ang) * r * 0.5)
                lrot = (0.0, -ang, 0.0)
            _box("Leaflet_%s_%d" % (axis, i), size, loc, gold, rot=lrot)

    for sx in (-1.0, 1.0):
        emblem((sx * (W / 2 - 0.01), 0.0, 1.02), "x")
    emblem((0.0, -(L / 2 - 0.01), 1.02), "y")


def build_gold_nugget() -> None:
    gold = _mat("Nugget_Gold", GOLD, 0.85, 0.22, emit=(0.95, 0.74, 0.28, 0.5))
    _ico("GoldNugget", 0.35, (0, 0, 0), gold, subdiv=1, scale=(1.0, 0.8, 0.75))


def build_gold_pile() -> None:
    """A heap of nuggets. The references never show a lone nugget — gold is
    always CLUSTERED, in cart beds and in wall seams, which the fidelity review
    called out as the difference between 'ore' and 'isolated ochre tiles'."""
    gold = _mat("Pile_Gold", GOLD, 0.85, 0.22, emit=(0.95, 0.74, 0.28, 0.5))
    # Deterministic spiral, no RNG: the same pile every build, so a capture is
    # comparable to the last one.
    for i in range(14):
        a = i * 2.399963            # golden angle
        r = 0.09 * math.sqrt(i)
        _ico("Nug%d" % i, 0.10 + 0.035 * ((i * 7) % 3), (math.cos(a) * r, math.sin(a) * r, 0.06 + 0.05 * ((i * 5) % 3)),
             gold, subdiv=1, scale=(1.0, 0.85, 0.7))


def build_rail_segment() -> None:
    """Two rails + sleepers. Sleeper rhythm is what explains the route at speed
    (fidelity review finding #3), so the ties are deliberately wide and light
    enough to separate from the rail steel."""
    wood = _mat("Tie_Wood", WOOD_DARK, 0.0, 0.85)
    steel = _mat("Rail_Steel", IRON, 0.55, 0.35)
    _box("RailL", (0.14, 6.0, 0.16), (-0.9, 0.0, 0.22), steel)
    _box("RailR", (0.14, 6.0, 0.16), (0.9, 0.0, 0.22), steel)
    for i in range(9):
        _box("Tie%d" % i, (2.5, 0.34, 0.14), (0.0, -3.0 + i * 0.75, 0.08), wood)


def build_lantern() -> None:
    """Brass mine lantern: cage, glowing core, hanging hook. Every reference
    hangs these on the timber, and they are the mine's actual light source."""
    brass = _mat("Lantern_Brass", BRASS, 0.7, 0.34)
    glow = _mat("Lantern_Glow", LANTERN_LIT, 0.0, 0.4, emit=(1.0, 0.72, 0.37, 3.0))
    _cyl("Cap", 0.17, 0.08, (0, 0, 0.36), (0, 0, 0), brass, verts=12)
    _cyl("Base", 0.17, 0.08, (0, 0, 0.02), (0, 0, 0), brass, verts=12)
    _ico("Core", 0.13, (0, 0, 0.19), glow, subdiv=2)
    for i in range(4):
        a = math.radians(45.0 + i * 90.0)
        _box("Bar%d" % i, (0.03, 0.03, 0.34), (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.19), brass)
    _cyl("Hook", 0.06, 0.03, (0, 0, 0.44), (math.pi / 2, 0, 0), brass, verts=10)


def build_wood_beam() -> None:
    """A mine support post. Slightly tapered and chamfered so it catches a
    highlight edge instead of reading as a flat brown rectangle."""
    wood = _mat("Beam_Wood", WOOD, 0.0, 0.8)
    iron = _mat("Beam_Iron", IRON, 0.55, 0.45)
    o = _box("Post", (0.42, 0.42, 3.0), (0, 0, 1.5), wood)
    o.scale = (o.scale[0], o.scale[1], o.scale[2])
    _box("Cap", (0.56, 0.56, 0.12), (0, 0, 3.0), wood)
    _box("Boot", (0.56, 0.56, 0.12), (0, 0, 0.06), wood)
    for z in (0.7, 2.3):
        _box("Strap@%.1f" % z, (0.48, 0.48, 0.07), (0, 0, z), iron)


def build_boulder() -> None:
    """Irregular granite. Deliberately the PALEST large surface in the mine —
    that contrast against the dark wall is the whole reason a rolling hazard is
    readable at speed (Astra: '#777773 boulder versus #302D29 wall')."""
    rock = _mat("Boulder_Granite", GRANITE, 0.0, 0.85)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.75, subdivisions=2)
    o = bpy.context.active_object
    o.name = "Boulder"
    # Deterministic vertex jitter: index-hashed, not random, so every build of
    # this asset is byte-comparable and a diff means a real change.
    for i, v in enumerate(o.data.vertices):
        k = 1.0 + 0.14 * (((i * 2654435761) % 1000) / 1000.0 - 0.5)
        v.co *= k
    o.data.materials.append(rock)


def build_rock_chunk() -> None:
    rock = _mat("Chunk_Rock", ROCK, 0.0, 0.9)
    for i in range(3):
        _ico("Chunk%d" % i, 0.22 + 0.09 * (i % 2),
             (0.18 * (i - 1), 0.10 * ((i * 3) % 2), 0.14 + 0.06 * i), rock, subdiv=1,
             scale=(1.0, 0.8, 0.7))


def build_lil_blunt_placeholder() -> None:
    """PLACEHOLDER rider silhouette — NOT the hero character.

    Read the honesty note in .claude/skills/hero-character-pipeline/SKILL.md
    before touching this: a primitive-assembly script cannot author an organic,
    rigged hero, and this does not pretend to. What it IS is the silhouette
    anchor the fidelity review asked for — "no distinct green miner silhouette
    is visible above the live cart, whereas it anchors all three references" —
    built from the shapes those references actually show: a green bud head,
    pointed leaf fronds behind it, a brass helmet cap with a lamp, and
    shoulders clearing the cart rim.

    It exists so the runner reads correctly RIGHT NOW at 12 m/s, and so the
    real GLB has a slot to drop into. It must be replaced, and the STATUS
    report must never call it the hero character.
    """
    leaf = _mat("LB_Leaf", (0.30, 0.62, 0.20), 0.0, 0.6)
    leaf_d = _mat("LB_LeafDark", (0.20, 0.45, 0.14), 0.0, 0.65)
    helmet = _mat("LB_Helmet", BRASS, 0.7, 0.3)
    lamp = _mat("LB_Lamp", LANTERN_LIT, 0.0, 0.35, emit=(1.0, 0.8, 0.45, 2.5))
    cloth = _mat("LB_Cloth", (0.26, 0.28, 0.32), 0.0, 0.8)

    _box("Torso", (0.62, 0.40, 0.52), (0.0, 0.0, 0.26), cloth)
    _ico("Head", 0.30, (0.0, 0.0, 0.74), leaf, subdiv=2, scale=(1.0, 0.88, 1.05))
    # Leaf fronds fanned behind the head — the mascot's readable silhouette.
    for i in range(5):
        a = math.radians(-56.0 + i * 28.0)
        _box("Frond%d" % i, (0.10, 0.05, 0.46),
             (math.sin(a) * 0.26, 0.16, 0.92 + math.cos(a) * 0.16),
             leaf_d, rot=(0.35, -a, 0.0))
    _ico("Helmet", 0.30, (0.0, 0.0, 0.86), helmet, subdiv=2, scale=(1.05, 1.0, 0.62))
    _cyl("Brim", 0.34, 0.04, (0.0, -0.06, 0.80), (0.0, 0.0, 0.0), helmet, verts=18)
    _ico("HeadLamp", 0.09, (0.0, -0.28, 0.88), lamp, subdiv=2)
    for sx in (-1.0, 1.0):
        _box("Arm%+d" % sx, (0.14, 0.14, 0.40), (sx * 0.36, -0.04, 0.34), leaf)


BUILDERS = {
    "lil_blunt_placeholder": build_lil_blunt_placeholder,
    "minecart": build_minecart,
    "gold_nugget": build_gold_nugget,
    "gold_pile": build_gold_pile,
    "rail_segment": build_rail_segment,
    "lantern": build_lantern,
    "wood_beam": build_wood_beam,
    "boulder": build_boulder,
    "rock_chunk": build_rock_chunk,
}


def _export(path: str) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    try:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")
    except Exception:
        bpy.ops.preferences.addon_enable(module="io_scene_gltf2")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB")


def _build_one(asset: str, out: str) -> int:
    _reset()
    BUILDERS[asset]()
    _export(out)
    with open(out, "rb") as f:
        magic = f.read(4)
    ok = magic == b"glTF"
    print("BUILT %-13s -> %-44s %8d bytes  valid_glb=%s"
          % (asset, out, os.path.getsize(out), ok))
    return 0 if ok else 1


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: build_asset.py <%s|all> <out.glb|out_dir>" % "|".join(BUILDERS))
        return 2
    asset, out = sys.argv[1], sys.argv[2]
    if asset == "all":
        rc = 0
        for name in BUILDERS:
            rc |= _build_one(name, os.path.join(out, name + ".glb"))
        return rc
    if asset not in BUILDERS:
        print("unknown asset %r; known: %s" % (asset, list(BUILDERS)))
        return 2
    return _build_one(asset, out)


if __name__ == "__main__":
    sys.exit(main())
