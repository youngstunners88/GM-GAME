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


# --- Chamber 0: the Smelting Facility -----------------------------------------
# Source: artifacts/episode2-gold-mine/chambers/00_SMELTING_FACILITY.md and
# references/inferno_bull_smelting.jpeg (Bull seated among molten gold, whiskey
# in hand, cigar lit, pour-crucibles working behind him).

MOLTEN     = (1.00, 0.62, 0.16)
GUN_STEEL  = (0.34, 0.35, 0.38)
GUN_WOOD   = (0.36, 0.19, 0.09)
BULL_HIDE  = (0.10, 0.09, 0.10)
WHISKEY    = (0.72, 0.38, 0.10)


def build_winchester_1886() -> None:
    """Lever-action rifle, period-silhouette. The Bull's hand-off prop.

    Hard-surface and parametric, so this is squarely Path E work — unlike the
    organic characters, a rifle IS a pile of cylinders and boxes. Proportions
    follow the 1886: 26" octagon barrel under a full-length magazine tube,
    straight-wrist stock, large loop lever.

    Built along +Y (Blender), which glTF's Y-up conversion turns into -Z, so in
    engine the muzzle points the way a held rifle should without extra rotation.
    """
    steel = _mat("Win_Steel", GUN_STEEL, 0.85, 0.30)
    wood = _mat("Win_Wood", GUN_WOOD, 0.0, 0.55)
    brass = _mat("Win_Brass", BRASS, 0.75, 0.32)

    # Barrel + magazine tube, muzzle at +Y.
    _cyl("Barrel", 0.021, 0.66, (0.0, 0.30, 0.0), (math.pi / 2, 0, 0), steel, verts=8)
    _cyl("MagTube", 0.016, 0.60, (0.0, 0.27, -0.036), (math.pi / 2, 0, 0), steel, verts=8)
    _box("Forearm", (0.052, 0.26, 0.058), (0.0, 0.06, -0.018), wood)
    _box("BarrelBand", (0.056, 0.030, 0.075), (0.0, 0.19, -0.018), brass)

    # Receiver — the boxy heart of a lever gun.
    _box("Receiver", (0.048, 0.26, 0.105), (0.0, -0.10, 0.005), steel)
    _box("LoadingGate", (0.052, 0.06, 0.035), (0.024, -0.06, -0.010), brass)
    _box("Hammer", (0.020, 0.030, 0.055), (0.0, -0.215, 0.062), steel)

    # Large-loop lever, the 1886's signature: three segments approximating the
    # closed loop a solid ring of geometry would cost far more to describe.
    _box("LeverArm", (0.020, 0.115, 0.022), (0.0, -0.145, -0.062), steel)
    _box("LeverLoopBack", (0.020, 0.022, 0.075), (0.0, -0.205, -0.092), steel)
    _box("LeverLoopBottom", (0.020, 0.110, 0.020), (0.0, -0.150, -0.126), steel)
    _box("Trigger", (0.014, 0.018, 0.036), (0.0, -0.130, -0.048), steel)

    # Straight-wrist stock + butt plate.
    o = _box("Stock", (0.052, 0.34, 0.098), (0.0, -0.40, -0.012), wood)
    o.rotation_euler = (0.055, 0.0, 0.0)
    _box("ButtPlate", (0.056, 0.022, 0.115), (0.0, -0.572, -0.024), brass)

    # Sights, so the silhouette reads as a rifle and not a stick.
    _box("FrontSight", (0.010, 0.012, 0.024), (0.0, 0.60, 0.030), steel)
    _box("RearSight", (0.030, 0.020, 0.016), (0.0, 0.05, 0.030), steel)


def build_crucible() -> None:
    """Tipping pour-crucible with molten gold. The facility's light source.

    The molten surface is the one place in Episode 2 where a high emission
    value is correct rather than a blowout: it IS the lamp.
    """
    iron = _mat("Cruc_Iron", (0.16, 0.15, 0.15), 0.6, 0.62)
    hot = _mat("Cruc_HotIron", (0.42, 0.16, 0.06), 0.5, 0.55, emit=(1.0, 0.30, 0.05, 1.4))
    gold = _mat("Cruc_Molten", MOLTEN, 0.3, 0.18, emit=(1.0, 0.58, 0.14, 6.0))

    _cyl("Vessel", 0.85, 1.10, (0, 0, 0.90), (0, 0, 0), iron, verts=20)
    _cyl("VesselLip", 0.92, 0.12, (0, 0, 1.46), (0, 0, 0), hot, verts=20)
    _cyl("Molten", 0.78, 0.06, (0, 0, 1.42), (0, 0, 0), gold, verts=20)
    for sx in (-1.0, 1.0):          # trunnion pins + frame
        _cyl("Trunnion%+d" % sx, 0.10, 0.34, (sx * 0.95, 0, 1.05), (0, math.pi / 2, 0), iron, verts=10)
        _box("Upright%+d" % sx, (0.16, 0.16, 1.30), (sx * 1.18, 0, 0.65), iron)
    _box("Base", (2.7, 0.9, 0.18), (0, 0, 0.09), iron)


def build_ingot_rack() -> None:
    """Rack of cast gold ingots — what the facility is FOR."""
    iron = _mat("Rack_Iron", (0.18, 0.17, 0.17), 0.6, 0.6)
    gold = _mat("Rack_Gold", GOLD, 0.85, 0.24, emit=(0.95, 0.74, 0.28, 0.4))
    for z in (0.10, 0.62, 1.14):
        _box("Shelf@%.2f" % z, (1.9, 0.7, 0.07), (0, 0, z), iron)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            _box("Post%+d%+d" % (sx, sy), (0.09, 0.09, 1.5), (sx * 0.88, sy * 0.28, 0.75), iron)
    for row, z in enumerate((0.19, 0.71, 1.23)):
        for i in range(4 - row):        # tapers upward, so it reads as stacked
            _box("Ingot%d_%d" % (row, i), (0.36, 0.19, 0.11),
                 (-0.62 + i * 0.42, 0.0, z), gold)


def build_whiskey_glass() -> None:
    """Tumbler and pour. Small, but it is the character beat."""
    glass = _mat("Whis_Glass", (0.80, 0.82, 0.84), 0.1, 0.08)
    liquor = _mat("Whis_Liquor", WHISKEY, 0.0, 0.15, emit=(0.85, 0.42, 0.10, 0.7))
    _cyl("Tumbler", 0.055, 0.12, (0, 0, 0.06), (0, 0, 0), glass, verts=16)
    _cyl("Pour", 0.048, 0.055, (0, 0, 0.045), (0, 0, 0), liquor, verts=16)
    _cyl("GlassBase", 0.058, 0.018, (0, 0, 0.009), (0, 0, 0), glass, verts=16)


def build_inferno_bull_placeholder() -> None:
    """PLACEHOLDER Inferno Bull — NOT the character.

    Same honesty rule as the Lil Blunt placeholder: a primitive-assembly script
    cannot author a hyper-real anthropomorphic bull, and this does not pretend
    to. It is the SILHOUETTE the founder's reference art is built on — massive
    black bull, long curved horns, copper hard-hat with a lit headlamp, dark
    flame-lensed aviators, cigar with an ember, red bandana, bandolier, gold
    bull-skull buckle — so the smelting-facility beat can be staged, blocked and
    played now, with the real GLB dropping into the same node slot later.

    Seated pose, matching references/inferno_bull_smelting.jpeg.
    """
    hide = _mat("Bull_Hide", BULL_HIDE, 0.0, 0.72)
    horn = _mat("Bull_Horn", (0.76, 0.72, 0.62), 0.0, 0.42)
    hat = _mat("Bull_Hat", (0.62, 0.34, 0.14), 0.7, 0.36)
    lamp = _mat("Bull_Lamp", LANTERN_LIT, 0.0, 0.35, emit=(1.0, 0.80, 0.45, 4.0))
    lens = _mat("Bull_Lens", (0.30, 0.06, 0.02), 0.4, 0.20, emit=(1.0, 0.35, 0.06, 2.2))
    bandana = _mat("Bull_Bandana", (0.55, 0.10, 0.09), 0.0, 0.75)
    leather = _mat("Bull_Leather", (0.24, 0.15, 0.09), 0.0, 0.72)
    gold = _mat("Bull_Gold", GOLD, 0.85, 0.26, emit=(0.95, 0.74, 0.28, 0.4))
    ember = _mat("Bull_Ember", (1.0, 0.42, 0.10), 0.0, 0.4, emit=(1.0, 0.35, 0.06, 5.0))

    # Seated: hips at z~0.55, torso leaning back a touch.
    _box("Hips", (0.92, 0.70, 0.42), (0.0, 0.0, 0.52), hide)
    t = _box("Torso", (1.06, 0.62, 0.95), (0.0, -0.06, 1.16), hide)
    t.rotation_euler = (-0.10, 0.0, 0.0)
    _box("Bandolier", (1.12, 0.20, 0.16), (0.0, -0.34, 1.24), leather, rot=(0.0, 0.55, 0.0))
    _box("Buckle", (0.22, 0.10, 0.16), (0.0, -0.34, 0.74), gold)
    # Thighs forward, shins down — a seated read from any angle.
    for sx in (-1.0, 1.0):
        _box("Thigh%+d" % sx, (0.34, 0.78, 0.34), (sx * 0.30, -0.44, 0.50), hide)
        _box("Shin%+d" % sx, (0.30, 0.30, 0.52), (sx * 0.30, -0.76, 0.22), hide)
        _box("Boot%+d" % sx, (0.32, 0.44, 0.20), (sx * 0.30, -0.88, 0.06), leather)
        _box("Arm%+d" % sx, (0.28, 0.30, 0.74), (sx * 0.62, -0.20, 1.20), hide)

    _box("Neck", (0.44, 0.36, 0.26), (0.0, -0.04, 1.74), hide)
    _box("Bandana", (0.58, 0.46, 0.16), (0.0, -0.04, 1.80), bandana)
    _box("Skull", (0.62, 0.56, 0.52), (0.0, -0.10, 2.06), hide)
    _box("Muzzle", (0.42, 0.34, 0.32), (0.0, -0.40, 1.98), hide)
    _cyl("NoseRing", 0.09, 0.025, (0.0, -0.56, 1.92), (0.0, math.pi / 2, 0.0), gold, verts=12)

    # Long curved horns — three segments each, sweeping out then up.
    for sx in (-1.0, 1.0):
        _cyl("HornA%+d" % sx, 0.075, 0.34, (sx * 0.42, -0.06, 2.22), (0.0, math.pi / 2, 0.0), horn, verts=8)
        _cyl("HornB%+d" % sx, 0.060, 0.28, (sx * 0.66, -0.06, 2.34), (0.5 * sx, 0.9 * sx, 0.0), horn, verts=8)
        _cyl("HornC%+d" % sx, 0.042, 0.24, (sx * 0.78, -0.06, 2.58), (0.0, 0.25 * sx, 0.0), horn, verts=8)

    # Copper hard-hat + headlamp, and the flame-lensed aviators.
    _ico("HardHat", 0.36, (0.0, -0.08, 2.30), hat, subdiv=2, scale=(1.0, 1.0, 0.62))
    _cyl("HatBrim", 0.40, 0.045, (0.0, -0.14, 2.22), (0.0, 0.0, 0.0), hat, verts=18)
    _ico("HeadLamp", 0.085, (0.0, -0.40, 2.26), lamp, subdiv=2)
    for sx in (-1.0, 1.0):
        _box("Lens%+d" % sx, (0.19, 0.05, 0.13), (sx * 0.14, -0.36, 2.06), lens)

    # Cigar with a live ember — permanently in mouth, per the profile.
    _cyl("Cigar", 0.028, 0.26, (0.10, -0.62, 1.94), (math.pi / 2, 0, 0), leather, verts=8)
    _ico("CigarEmber", 0.032, (0.10, -0.75, 1.94), ember, subdiv=1)


BUILDERS = {
    "lil_blunt_placeholder": build_lil_blunt_placeholder,
    "inferno_bull_placeholder": build_inferno_bull_placeholder,
    "winchester_1886": build_winchester_1886,
    "crucible": build_crucible,
    "ingot_rack": build_ingot_rack,
    "whiskey_glass": build_whiskey_glass,
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
