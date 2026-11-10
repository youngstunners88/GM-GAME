"""THE AUCTION HOUSE, IN CAD (founder brief PROMPT_AUCTION_HOUSE_RENEGADE_JACK_HAMMER_2026-11-08: "CAD / U3CAD ... required here for the
auction building and key interior furniture"; "Do not ship low-poly placeholder architecture where CAD can replace it").

    AUCTION_CAD_OUT=<out_dir> freecadcmd tools/ep2_cad/auction_house_cad.py
    blender -b --factory-startup -P tools/ep2_blender/build_town_interior_kit.py -- --cad <out_dir> --prefix Auc_ \
        --out src/episode2/extras/town/auction_house.glb

Real solids at real size, the town kit's material names (Ep2Pbr dresses Planks / Trim / DarkWood / Brass / Iron / Stone / Burlap with the
existing tileable PBR sets, so big walls show no paper seams under the stage light). Game frame, y up. The BUILDING's front faces -z and its
origin is the porch's front edge at the centre, ground level; the hall runs to +z. Every other piece stands on its own origin (base centre),
front -z. The numbers the game's collision uses are mirrored in Ep2AuctionHouse (W, D, DOOR_W, STAGE_*, RAIL_Z, BLEACH_*, SIDE_DOOR_Z):
change both together.
  building   porch (deck, 6 turned columns, roof), false-front facade with stepped parapet, double-door opening, four gallery windows,
             side walls with windows and Jack Hammer's side door, back wall, gable roof, three king-post trusses, plank floor
  stage      raised block with skirt panels, side steps, proscenium posts and header
  lectern    Renegade's turned rostrum with brass trim and a gavel block
  rail       one 1 m bay of brass-capped balustrade (the game repeats it)
  bleacher   one 4 m bay of three-tier side seating
  claim_board, strongbox (banded chest, lid up, bars inside), lamp_post, hitch_rail, paddle, tray, bunting (one 4 m run of pennants)
"""
import json
import math
import os

import FreeCAD  # noqa: F401  (freecadcmd)
import Mesh
import MeshPart
import Part
from FreeCAD import Vector

OUT = os.environ.get("AUCTION_CAD_OUT", os.path.abspath("auction_cad_out"))
os.makedirs(OUT, exist_ok=True)

W, D, WALL_H, RIDGE_H = 22.0, 30.0, 7.5, 11.0        # hall outer width, depth (front wall z=2 .. back z=32), eaves, ridge
PORCH_D, FACADE_H = 2.0, 10.0
DOOR_W, DOOR_H = 3.2, 3.6
SIDE_DOOR_Z, SIDE_DOOR_W, SIDE_DOOR_H = 26.0, 1.4, 2.6
STAGE_Z0, STAGE_Z1, STAGE_X, STAGE_H = 24.0, 31.6, 6.5, 1.1
T = 0.2                                               # wall thickness

GROUPS = {}


def add(piece, mat, shape, lod=1):
    GROUPS.setdefault((piece, mat), []).append((shape, lod))


def v(x, y, z):
    return Vector(x, y, z)


def box(size, centre):
    sx, sy, sz = size
    return Part.makeBox(sx, sy, sz, Vector(centre) - Vector(sx / 2.0, sy / 2.0, sz / 2.0))


def cyl(r, length, centre, axis=Vector(0, 1, 0)):
    return Part.makeCylinder(r, length, Vector(centre) - axis * (length / 2.0), axis)


def rot(shape, deg, axis=Vector(0, 0, 1), about=(0, 0, 0)):
    s = shape.copy()
    s.rotate(Vector(about), axis, deg)
    return s


def fillet(shape, r):
    try:
        return shape.makeFillet(r, shape.Edges)
    except Exception:
        return shape


def turned(profile, base):
    """A solid of revolution about +y from (height, radius) points, standing on `base`."""
    pts = [Vector(base) + v(r, h, 0) for h, r in profile]
    pts = [Vector(base) + v(0, profile[0][0], 0)] + pts + [Vector(base) + v(0, profile[-1][0], 0)]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).revolve(Vector(base), Vector(0, 1, 0), 360)


def prism_xy(points, depth, z0=0.0):
    pts = [v(x, y, z0) for x, y in points]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).extrude(v(0, 0, depth))


def column(x, z, h):
    """A turned porch column: plinth, fluted-looking shaft rings, capital."""
    prof = [(0.0, 0.16), (0.12, 0.16), (0.14, 0.12), (0.30, 0.10), (h * 0.5, 0.09), (h - 0.32, 0.085), (h - 0.24, 0.12), (h - 0.12, 0.12),
            (h - 0.1, 0.15), (h, 0.15)]
    return turned(prof, v(x, 0, z))


def wall_with_holes(size, centre, holes):
    w = box(size, centre)
    for hs, hc in holes:
        w = w.cut(box(hs, hc))
    return w


# ---------------------------------------------------------------------------------------------------------------------- building
def building():
    z0, z1 = PORCH_D, PORCH_D + D
    hw = W / 2.0
    # plank floor (one slab; Ep2Pbr's planks_weathered gives the boards) and a dressed-stone foundation lip
    add("building", "Planks", box((W - 0.1, 0.12, D - 0.1), (0, 0.06, (z0 + z1) / 2)))
    add("building", "Stone", box((W + 0.3, 0.35, 0.3), (0, 0.0, z0 - 0.05)))
    # porch deck, steps, columns, roof
    add("building", "Planks", box((W, 0.12, PORCH_D), (0, 0.06, PORCH_D / 2)))
    add("building", "Trim", box((DOOR_W + 2.0, 0.06, 0.4), (0, 0.03, -0.2)))
    for i in range(6):
        x = -hw + 0.4 + i * (W - 0.8) / 5.0
        add("building", "DarkWood", column(x, 0.25, 4.0), 0)
    add("building", "Trim", box((W + 0.4, 0.3, 0.3), (0, 4.1, 0.25)))
    porch_roof = rot(box((W + 0.6, 0.12, PORCH_D + 0.8), (0, 4.4, PORCH_D / 2 - 0.1)), -6.0, Vector(1, 0, 0), (0, 4.4, z0))
    add("building", "Planks", porch_roof)
    for i in range(12):                                               # porch rafter tails
        x = -hw + 0.2 + i * (W - 0.4) / 11.0
        add("building", "Trim", box((0.08, 0.14, PORCH_D + 0.7), (x, 4.28, PORCH_D / 2 - 0.1)), 2)
    # false front: wall with the double door and four gallery windows, a stepped parapet above the roof line
    holes = [((DOOR_W, DOOR_H, 1.0), (0, DOOR_H / 2 + 0.12, z0))]
    for x in (-7.5, -3.0, 3.0, 7.5):
        holes.append(((1.6, 2.4, 1.0), (x, 5.6, z0)))
    front = wall_with_holes((W, FACADE_H, T), (0, FACADE_H / 2, z0), holes)
    add("building", "Planks", front)
    step = prism_xy([(-hw, FACADE_H), (hw, FACADE_H), (hw, FACADE_H + 0.6), (hw * 0.55, FACADE_H + 0.6), (hw * 0.55, FACADE_H + 1.3),
                     (-hw * 0.55, FACADE_H + 1.3), (-hw * 0.55, FACADE_H + 0.6), (-hw, FACADE_H + 0.6)], T, z0 - T / 2)
    add("building", "Planks", step)
    add("building", "Trim", box((W + 0.3, 0.25, 0.4), (0, FACADE_H + 0.65, z0 - 0.05)))
    add("building", "Trim", box((W * 0.55 + 0.3, 0.25, 0.4), (0, FACADE_H + 1.35, z0 - 0.05)))
    add("building", "Trim", box((W + 0.2, 0.2, 0.35), (0, 4.75, z0 - 0.1)))             # the belt course under the gallery windows
    for x in (-7.5, -3.0, 3.0, 7.5):                                                    # window casings, glass that glows from inside
        add("building", "Trim", box((1.9, 0.15, 0.3), (x, 6.9, z0 - 0.1)))
        add("building", "Trim", box((1.9, 0.12, 0.35), (x, 4.33, z0 - 0.12)))
        for sx in (-0.88, 0.88):
            add("building", "Trim", box((0.14, 2.6, 0.26), (x + sx, 5.6, z0 - 0.08)), 2)
        add("building", "Glow", box((1.6, 2.4, 0.04), (x, 5.6, z0 + 0.02)), 2)
        add("building", "Trim", box((0.06, 2.4, 0.08), (x, 5.6, z0 - 0.02)), 2)
        add("building", "Trim", box((1.6, 0.06, 0.08), (x, 5.9, z0 - 0.02)), 2)
    for sx in (-1, 1):                                                                  # the door casing, a transom of glowing glass
        add("building", "DarkWood", box((0.25, DOOR_H + 0.3, 0.35), (sx * (DOOR_W / 2 + 0.12), (DOOR_H + 0.3) / 2, z0 - 0.08)))
    add("building", "DarkWood", box((DOOR_W + 0.6, 0.3, 0.38), (0, DOOR_H + 0.27, z0 - 0.08)))
    # doors stand open, swung back against the inside of the front wall (the player walks straight in: nothing to phase through)
    for sx in (-1, 1):
        leaf = box((DOOR_W / 2 - 0.05, DOOR_H - 0.1, 0.08), (0, (DOOR_H - 0.1) / 2 + 0.14, 0))
        for k in range(3):
            leaf = leaf.cut(box((DOOR_W / 2 - 0.45, 0.8, 0.06), (0, 0.7 + k * 1.05, -0.05)))
        leaf.translate(v(sx * (DOOR_W / 2 + 0.85), 0, z0 + T / 2 + 0.06))
        add("building", "DarkWood", leaf)
    # side walls (three windows each, Jack Hammer's side door low on the left by the stage), back wall
    for sx in (-1, 1):
        holes = [((1.0, 1.8, 1.4), (sx * hw, 3.6, z0 + 6.0 + 8.0 * k)) for k in range(3)]
        if sx < 0:
            holes.append(((1.0, SIDE_DOOR_H, SIDE_DOOR_W), (sx * hw, SIDE_DOOR_H / 2 + 0.12, SIDE_DOOR_Z)))
        add("building", "Planks", wall_with_holes((T, WALL_H, D), (sx * (hw - T / 2), WALL_H / 2, (z0 + z1) / 2), holes))
        for k in range(3):
            add("building", "Glow", box((0.04, 1.8, 1.4), (sx * (hw - 0.05), 3.6, z0 + 6.0 + 8.0 * k)), 2)
            add("building", "Trim", box((0.3, 0.14, 1.7), (sx * hw, 4.57, z0 + 6.0 + 8.0 * k)), 2)
        add("building", "Trim", box((0.3, 0.3, D + 0.2), (sx * hw, WALL_H, (z0 + z1) / 2)))
    add("building", "DarkWood", box((0.3, SIDE_DOOR_H + 0.25, 0.2), (-hw, (SIDE_DOOR_H + 0.25) / 2, SIDE_DOOR_Z - SIDE_DOOR_W / 2 - 0.1)))
    add("building", "DarkWood", box((0.3, SIDE_DOOR_H + 0.25, 0.2), (-hw, (SIDE_DOOR_H + 0.25) / 2, SIDE_DOOR_Z + SIDE_DOOR_W / 2 + 0.1)))
    add("building", "DarkWood", box((0.3, 0.25, SIDE_DOOR_W + 0.4), (-hw, SIDE_DOOR_H + 0.25, SIDE_DOOR_Z)))
    add("building", "Planks", box((W, WALL_H, T), (0, WALL_H / 2, z1 - T / 2)))
    gable = prism_xy([(-hw, WALL_H), (hw, WALL_H), (0, RIDGE_H)], T, z1 - T)
    add("building", "Planks", gable)
    # gable roof (two slabs) and the ridge cap
    pitch = math.degrees(math.atan2(RIDGE_H - WALL_H, hw))
    slope = math.hypot(hw, RIDGE_H - WALL_H)
    for sx in (-1, 1):
        slab = box((slope + 0.7, 0.14, D + 0.2), (0, 0, (z0 + z1) / 2))
        slab = rot(slab, -sx * pitch, Vector(0, 0, 1))
        slab.translate(v(sx * hw / 2, (WALL_H + RIDGE_H) / 2 + 0.12, 0))
        add("building", "Planks", slab)
    add("building", "Iron", box((0.35, 0.18, D + 0.3), (0, RIDGE_H + 0.15, (z0 + z1) / 2)))
    # three king-post trusses across the hall: tie beam, rafters, king post, struts
    for k in range(3):
        z = z0 + 7.5 + k * 7.5
        add("building", "DarkWood", box((W - 0.4, 0.32, 0.26), (0, WALL_H - 0.2, z)))
        for sx in (-1, 1):
            raf = box((slope, 0.28, 0.24), (0, 0, z))
            raf = rot(raf, -sx * pitch, Vector(0, 0, 1))
            raf.translate(v(sx * hw / 2, (WALL_H + RIDGE_H) / 2 - 0.25, 0))
            add("building", "DarkWood", raf)
            strut = box((0.18, 2.4, 0.2), (0, 0, z))
            strut = rot(strut, sx * 48.0, Vector(0, 0, 1))
            strut.translate(v(sx * 1.6, WALL_H + 1.1, 0))
            add("building", "DarkWood", strut, 2)
        add("building", "DarkWood", box((0.3, RIDGE_H - WALL_H - 0.3, 0.26), (0, (WALL_H + RIDGE_H) / 2 - 0.2, z)))
        for sx in (-1, 1):
            add("building", "Iron", cyl(0.05, 0.3, (sx * 0.2, WALL_H - 0.2, z), Vector(0, 0, 1)), 2)


# ---------------------------------------------------------------------------------------------------------------------- stage + furniture
def stage():
    zc, dz = (STAGE_Z0 + STAGE_Z1) / 2, STAGE_Z1 - STAGE_Z0
    add("stage", "Planks", box((STAGE_X * 2, 0.1, dz), (0, STAGE_H - 0.05, zc)))
    add("stage", "DarkWood", box((STAGE_X * 2 - 0.1, STAGE_H - 0.1, dz - 0.1), (0, (STAGE_H - 0.1) / 2, zc)))
    add("stage", "Trim", box((STAGE_X * 2 + 0.2, 0.12, 0.3), (0, STAGE_H - 0.06, STAGE_Z0 - 0.02)))
    for i in range(8):                                                  # raised skirt panels along the front
        x = -STAGE_X + 0.8 + i * (STAGE_X * 2 - 1.6) / 7.0
        p = fillet(box((1.2, STAGE_H - 0.45, 0.06), (x, STAGE_H / 2 - 0.05, STAGE_Z0 - 0.04)), 0.02)
        add("stage", "Trim", p, 2)
    for sx in (-1, 1):                                                  # side steps
        for k in range(3):
            h = STAGE_H * (k + 1) / 4.0
            add("stage", "Planks", box((0.9, h, 1.6), (sx * (STAGE_X + 0.45 + (2 - k) * 0.35), h / 2, STAGE_Z0 + 1.2)), 2)
    for sx in (-1, 1):                                                  # proscenium posts + header (the game paints its words)
        add("stage", "DarkWood", column(sx * (STAGE_X + 0.3), STAGE_Z0 - 0.2, 6.2), 0)
    add("stage", "DarkWood", box((STAGE_X * 2 + 1.2, 0.9, 0.3), (0, 6.5, STAGE_Z0 - 0.2)))
    add("stage", "Brass", box((STAGE_X * 2 + 1.3, 0.06, 0.34), (0, 6.03, STAGE_Z0 - 0.2)), 2)
    add("stage", "Brass", box((STAGE_X * 2 + 1.3, 0.06, 0.34), (0, 6.97, STAGE_Z0 - 0.2)), 2)


def lectern():
    body = turned([(0.0, 0.32), (0.08, 0.32), (0.12, 0.26), (0.25, 0.22), (0.7, 0.16), (0.95, 0.2), (1.02, 0.28), (1.08, 0.3)], v(0, 0, 0))
    add("lectern", "DarkWood", body, 0)
    add("lectern", "Brass", turned([(0.0, 0.31), (0.03, 0.31)], v(0, 1.08, 0)), 0)
    top = rot(box((0.7, 0.05, 0.5), (0, 1.15, 0)), 14.0, Vector(1, 0, 0), (0, 1.12, 0))
    add("lectern", "DarkWood", top)
    add("lectern", "Brass", rot(box((0.72, 0.03, 0.04), (0, 1.15, 0.25)), 14.0, Vector(1, 0, 0), (0, 1.12, 0)), 2)
    add("lectern", "DarkWood", box((0.16, 0.05, 0.12), (0.28, 1.12, -0.05)), 2)                    # the gavel block
    add("lectern", "DarkWood", cyl(0.035, 0.12, (0.28, 1.18, -0.05), Vector(1, 0, 0)), 2)
    add("lectern", "DarkWood", cyl(0.012, 0.2, (0.28, 1.18, 0.05), Vector(0, 0, 1)), 2)


def rail():
    add("rail", "Brass", cyl(0.04, 1.0, (0, 1.0, 0), Vector(1, 0, 0)), 0)
    add("rail", "DarkWood", box((1.0, 0.08, 0.1), (0, 0.12, 0)))
    for x in (-0.5, -0.25, 0.0, 0.25):
        add("rail", "DarkWood", turned([(0.0, 0.035), (0.15, 0.045), (0.45, 0.028), (0.75, 0.045), (0.92, 0.03)], v(x, 0.12, 0)), 2)
    add("rail", "DarkWood", box((0.12, 1.05, 0.12), (-0.5, 0.52, 0)))


def bleacher():
    for k in range(3):                                                  # three tiers, back against the wall (+x side of the bay)
        add("bleacher", "DarkWood", box((0.8, 0.45 * (k + 1), 4.0), (0.8 * k, 0.225 * (k + 1), 0)))   # dark risers: they read against the plank walls
        add("bleacher", "Trim", box((0.84, 0.06, 4.02), (0.8 * k, 0.45 * (k + 1) + 0.03, 0)), 2)
        add("bleacher", "Brass", box((0.02, 0.02, 4.0), (0.8 * k - 0.4, 0.45 * (k + 1) + 0.02, 0)), 2)


def claim_board():
    add("claim_board", "DarkWood", box((4.2, 2.7, 0.1), (0, 1.35, 0)))
    add("claim_board", "Burlap", box((3.9, 2.4, 0.04), (0, 1.35, -0.06)))
    for y in (0.05, 2.65):
        add("claim_board", "Trim", box((4.4, 0.14, 0.16), (0, y, -0.03)))
    for x in (-2.15, 2.15):
        add("claim_board", "Trim", box((0.14, 2.8, 0.16), (x, 1.35, -0.03)))
    for i in range(6):                                                  # tacked lot cards
        add("claim_board", "Paper", box((0.5, 0.36, 0.01), (-1.4 + (i % 3) * 1.4, 1.8 - (i // 3) * 0.75, -0.09)), 2)


def strongbox():
    shell = box((1.0, 0.55, 0.6), (0, 0.3, 0)).cut(box((0.9, 0.5, 0.5), (0, 0.36, 0)))
    add("strongbox", "DarkWood", fillet(shell, 0.01))
    for x in (-0.35, 0.0, 0.35):
        add("strongbox", "Brass", box((0.06, 0.57, 0.62), (x, 0.3, 0)), 2)
    lid = box((1.0, 0.1, 0.6), (0, 0, -0.3))
    lid = rot(lid, -105.0, Vector(1, 0, 0), (0, 0, 0))
    lid.translate(v(0, 0.58, 0.3))
    add("strongbox", "DarkWood", lid)
    for i in range(9):                                                  # stacked bars catching the stage key
        x, y = -0.3 + (i % 3) * 0.3, 0.45 + (i // 3) * 0.07
        bar = Part.makeLoft([Part.makePolygon([v(x - 0.12, y, -0.06), v(x + 0.12, y, -0.06), v(x + 0.12, y, 0.06), v(x - 0.12, y, 0.06), v(x - 0.12, y, -0.06)]),
                             Part.makePolygon([v(x - 0.1, y + 0.06, -0.045), v(x + 0.1, y + 0.06, -0.045), v(x + 0.1, y + 0.06, 0.045), v(x - 0.1, y + 0.06, 0.045), v(x - 0.1, y + 0.06, -0.045)])], True)
        add("strongbox", "Gold", bar, 2)


def lamp_post():
    add("lamp_post", "DarkWood", box((0.16, 3.2, 0.16), (0, 1.6, 0)))
    add("lamp_post", "DarkWood", box((0.7, 0.1, 0.1), (0.3, 3.0, 0)))
    add("lamp_post", "Iron", cyl(0.012, 0.25, (0.6, 2.82, 0)), 2)
    add("lamp_post", "Iron", turned([(0.0, 0.1), (0.04, 0.1), (0.06, 0.06), (0.32, 0.06), (0.36, 0.1), (0.4, 0.04)], v(0.6, 2.3, 0)), 2)
    add("lamp_post", "Flame", turned([(0.0, 0.0), (0.04, 0.035), (0.1, 0.025), (0.16, 0.0)], v(0.6, 2.42, 0)), 2)
    add("lamp_post", "LampGlass", cyl(0.055, 0.24, (0.6, 2.5, 0)), 2)


def hitch_rail():
    for x in (-2.0, 2.0):
        add("hitch_rail", "DarkWood", box((0.16, 1.1, 0.16), (x, 0.55, 0)))
    add("hitch_rail", "DarkWood", fillet(box((4.4, 0.12, 0.12), (0, 1.05, 0)), 0.02))
    for x in (-1.0, 0.6):
        add("hitch_rail", "Iron", Part.makeTorus(0.05, 0.01, v(x, 0.98, 0.07), v(0, 0, 1)), 2)


def paddle():
    add("paddle", "DarkWood", cyl(0.014, 0.32, (0, 0.16, 0)), 2)
    add("paddle", "Paper", Part.makeCylinder(0.11, 0.008, v(0, 0.42, -0.004), v(0, 0, 1)), 2)


def tray():
    add("tray", "Tin", Part.makeCylinder(0.2, 0.015, v(0, 0, 0)).fuse(Part.makeTorus(0.2, 0.012, v(0, 0.015, 0), v(0, 1, 0))), 2)
    for i in range(3):
        a = i * 2.1
        add("tray", "ClearGlass", turned([(0.0, 0.03), (0.06, 0.03), (0.07, 0.008), (0.1, 0.008), (0.14, 0.035), (0.15, 0.036)],
                                         v(0.1 * math.cos(a), 0.015, 0.1 * math.sin(a))), 2)
        add("tray", "Whiskey", Part.makeCylinder(0.027, 0.03, v(0.1 * math.cos(a), 0.12, 0.1 * math.sin(a))), 2)


def bunting():
    add("bunting", "Rope", cyl(0.008, 4.0, (0, 0, 0), Vector(1, 0, 0)), 2)
    for i in range(8):
        x = -1.75 + i * 0.5
        add("bunting", ["RedCloth", "Cloth", "GoldCloth"][i % 3], prism_xy([(x - 0.18, 0), (x + 0.18, 0), (x, -0.42)], 0.01, -0.005), 2)


BUILDERS = [("building", building), ("stage", stage), ("lectern", lectern), ("rail", rail), ("bleacher", bleacher), ("claim_board", claim_board),
            ("strongbox", strongbox), ("lamp_post", lamp_post), ("hitch_rail", hitch_rail), ("paddle", paddle), ("tray", tray), ("bunting", bunting)]
failed = {}
for name, fn in BUILDERS:
    try:
        fn()
    except Exception as ex:                           # report and carry on: one bad builder must not hide the rest
        failed[name] = repr(ex)
        for key in [k for k in GROUPS if k[0] == name]:
            del GROUPS[key]


def deflection(diag, lod):
    if lod == 2:
        return max(0.003, diag * 0.02), 1.5
    if lod == 0:
        return max(0.0015, diag * 0.004), 0.6
    return max(0.0015, diag * 0.006), 1.0


report = {"groups": {}, "tris": 0, "pieces": {}, "failed": failed}
for (piece, mat), shapes in sorted(GROUPS.items()):
    mesh = Mesh.Mesh()
    for shp, lod in shapes:
        lin, ang = deflection(max(shp.BoundBox.DiagonalLength, 1e-4), lod)
        mesh.addMesh(MeshPart.meshFromShape(Shape=shp, LinearDeflection=lin, AngularDeflection=ang, Relative=False))
    mesh.write(os.path.join(OUT, "%s__%s.obj" % (piece, mat)))
    report["groups"]["%s/%s" % (piece, mat)] = mesh.CountFacets
    report["pieces"][piece] = report["pieces"].get(piece, 0) + mesh.CountFacets
    report["tris"] += mesh.CountFacets
json.dump(report, open(os.path.join(OUT, "auction_house_cad.json"), "w"), indent=1)
print("@@" + json.dumps({"ok": not failed, "tris": report["tris"], "pieces": report["pieces"], "failed": failed}))
