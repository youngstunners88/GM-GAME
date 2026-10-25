"""THE TOWN'S INTERIOR FURNITURE, IN CAD (founder 2026-10-25: "Town interiors - more furnished furniture and subtle details (Certificate,
Saloon, Armory, Jail as touched)"; "Do not ship grey boxes or low-poly placeholders where CAD can replace them").

Run with FreeCAD's headless interpreter (FreeCAD 1.1.4: ~/tools/freecad/squashfs-root, `freecadcmd` on PATH), from the repo root:

    TOWN_CAD_OUT=<out_dir> [TOWN_CAD_ONLY=chair,table] freecadcmd tools/ep2_cad/town_interior_cad.py

Real solids at REAL size. The pieces that REPLACE the town kit's box-and-cylinder furniture keep the old piece's footprint, heights and
origin, so every seat, drinker's spot, walk blocker and story mark stays valid:
  bar (Bar_Counter: 8 m, top surface 1.20), back_bar (Bar_BackShelf), table (Bar_Table: top surface 0.785), chair (Bar_Chair: seat 0.48),
  piano (Bar_Piano), counter (Int_Counter: top surface 1.125), pigeonholes (Int_Shelves), desk (Int_Desk), stove (Int_Stove).
And the detail the rooms never had: a bentwood (Thonet No. 14) chair, a piano stool, brass cuspidors, a harp lamp and a wagon-wheel
chandelier (both hang from the ceiling by a chain the game adds), a Vienna regulator clock (its pendulum a separate piece the game
swings), a hall tree with two hats, a poker spread and a table of drinks, an office safe, a deacon's bench, a captain's chair, a desk
lamp, a box of split logs, an enamel coffee pot, a barn lantern, a jailer's key ring, a water bucket with its dipper, a prisoner's tin plate and cup, a broom,
a gunsmith's bench with its vise, and a peg board for revolvers.

Coordinates are the GAME's (y up); each piece's front faces +z and stands on its own origin (base centre) unless its builder says
otherwise. Each (piece, material) group is tessellated to one OBJ in <out_dir> plus town_interior_cad.json (triangle counts);
tools/ep2_blender/build_town_interior_kit.py assembles one Twn_* root per piece.
"""
import json
import math
import os
import sys

import FreeCAD  # noqa: F401  (freecadcmd)
import Mesh
import MeshPart
import Part
from FreeCAD import Vector

OUT = os.environ.get("TOWN_CAD_OUT", os.path.abspath("town_cad_out"))      # (freecadcmd treats unknown --flags as its own)
ONLY = [s for s in os.environ.get("TOWN_CAD_ONLY", "").split(",") if s]
os.makedirs(OUT, exist_ok=True)

X = Vector(1, 0, 0)
Y = Vector(0, 1, 0)
Z = Vector(0, 0, 1)
O = Vector(0, 0, 0)

GROUPS = {}          # (piece, material) -> [(shape, lod)]   lod: 0 = fine (big turned bodies), 1 = normal, 2 = coarse (small things)


def add(piece, mat, shape, lod=1):
    GROUPS.setdefault((piece, mat), []).append((shape, lod))


def v(x, y, z):
    return Vector(x, y, z)


def axis_vec(a):
    return {"x": X, "y": Y, "z": Z}[a] if isinstance(a, str) else Vector(a)


def cyl(r, length, centre, axis="y"):
    d = axis_vec(axis)
    return Part.makeCylinder(r, length, Vector(centre) - d * (length / 2.0), d)


def cone(r0, r1, length, centre, axis="y"):
    d = axis_vec(axis)
    return Part.makeCone(r0, r1, length, Vector(centre) - d * (length / 2.0), d)


def box(size, centre):
    sx, sy, sz = size
    return Part.makeBox(sx, sy, sz, Vector(centre) - Vector(sx / 2.0, sy / 2.0, sz / 2.0))


def sphere(r, centre):
    return Part.makeSphere(r, Vector(centre))


def fillet(shape, r, edges=None):
    try:
        return shape.makeFillet(r, edges if edges is not None else shape.Edges)
    except Exception:
        return shape


def chamfer(shape, d, edges=None):
    try:
        return shape.makeChamfer(d, edges if edges is not None else shape.Edges)
    except Exception:
        return shape


def front_edges(shape, z):
    """The edges of a box-like solid lying in its front plane (z), for a bevel on the face only."""
    return [e for e in shape.Edges if abs(e.BoundBox.ZMin - z) < 1e-6 and abs(e.BoundBox.ZMax - z) < 1e-6]


def revolve(profile, axis="y", centre=(0, 0, 0), angle=360.0):
    """Revolve a closed polyline profile of (along_axis, radius) points about `axis` through `centre`."""
    c = Vector(centre)
    pts = []
    for a, r in profile:
        if axis == "x":
            pts.append(c + Vector(a, r, 0))
        elif axis == "y":
            pts.append(c + Vector(r, a, 0))
        else:
            pts.append(c + Vector(r, 0, a))
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).revolve(c, axis_vec(axis), angle)


def prism_yz(points, depth, x0=0.0):
    """A closed (y, z) outline extruded `depth` along +x from x0 (side profiles: a moulding run along x, a cheek, a foot)."""
    pts = [v(x0, y, z) for y, z in points]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).extrude(v(depth, 0, 0))


def prism_xy(points, depth, z0=0.0):
    """A closed (x, y) outline extruded `depth` along +z from z0 (front profiles: a pediment, an arch)."""
    pts = [v(x, y, z0) for x, y in points]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).extrude(v(0, 0, depth))


def prism_xz(points, depth, y0=0.0):
    pts = [v(x, y0, z) for x, z in points]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).extrude(v(0, depth, 0))


def frame_placement(origin, xdir, ydir):
    """A placement whose local x / y axes are `xdir` / `ydir` (z = x cross y), at `origin`."""
    xd = Vector(xdir).normalize()
    yd = Vector(ydir)
    yd = (yd - xd * yd.dot(xd)).normalize()
    zd = xd.cross(yd)
    m = FreeCAD.Matrix(xd.x, yd.x, zd.x, origin[0], xd.y, yd.y, zd.y, origin[1], xd.z, yd.z, zd.z, origin[2], 0, 0, 0, 1)
    return FreeCAD.Placement(m)


def arc_tube(centre, start_dir, toward_dir, R, r, angle):
    """A bent tube: `angle` degrees of a torus of radius R (tube r) about `centre`, starting at centre + R * start_dir and sweeping
    toward `toward_dir` (bentwood, hooks, handles, a stovepipe elbow)."""
    t = Part.makeTorus(R, r, O, Z, -180, 180, angle)
    t.Placement = frame_placement(centre, start_dir, toward_dir)
    return t


def cyl_between(p0, p1, r):
    a, b = Vector(p0), Vector(p1)
    d = b - a
    return Part.makeCylinder(r, d.Length, a, d.normalize() if d.Length > 0 else Y)


def cone_between(p0, p1, r0, r1):
    a, b = Vector(p0), Vector(p1)
    d = b - a
    return Part.makeCone(r0, r1, d.Length, a, d.normalize())


def turned(profile, base, axis_to=None):
    """A turned part (revolved about y from `profile` (y, r) points), moved to `base`; `axis_to` tilts its axis (a splayed leg)."""
    s = revolve(profile, "y")
    if axis_to is not None:
        a = Vector(axis_to).normalize()
        ang = math.degrees(math.acos(max(-1.0, min(1.0, a.dot(Y)))))
        ax = Y.cross(a)
        if ax.Length > 1e-9 and ang > 1e-6:
            s.rotate(O, ax, ang)
    s.translate(Vector(base))
    return s


def rot_y(shape, deg, about=(0, 0, 0)):
    s = shape.copy()
    s.rotate(Vector(about), Y, deg)
    return s


def moved(shape, d):
    s = shape.copy()
    s.translate(Vector(d))
    return s


def hrand(i, k=0.0):
    """Deterministic 0..1 noise (the same kit every build)."""
    x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453
    return x - math.floor(x)


def wanted(name):
    return not ONLY or name in ONLY


# ====================================================================================================== shared small things
def bottle(P, kind, base, lod=2, mat=None, label=True, turn=0.0):
    """A bottle standing at `base`: whiskey (round, long neck), wine (tall shoulders), flask (squat), bitters (square-shouldered)."""
    profiles = {
        "whiskey": [(0.0, 0.0), (0.0, 0.034), (0.006, 0.037), (0.17, 0.037), (0.20, 0.030), (0.225, 0.014), (0.29, 0.012), (0.295, 0.014),
                    (0.305, 0.014), (0.305, 0.0)],
        "wine": [(0.0, 0.0), (0.0, 0.033), (0.006, 0.036), (0.19, 0.036), (0.235, 0.020), (0.255, 0.013), (0.315, 0.012), (0.32, 0.014),
                 (0.33, 0.014), (0.33, 0.0)],
        "flask": [(0.0, 0.0), (0.0, 0.040), (0.005, 0.044), (0.10, 0.044), (0.13, 0.026), (0.15, 0.012), (0.19, 0.011), (0.195, 0.013),
                  (0.20, 0.013), (0.20, 0.0)],
        "bitters": [(0.0, 0.0), (0.0, 0.030), (0.005, 0.032), (0.15, 0.032), (0.165, 0.026), (0.18, 0.011), (0.235, 0.010), (0.24, 0.012),
                    (0.25, 0.012), (0.25, 0.0)],
    }
    prof = profiles[kind]
    m = mat or {"whiskey": "Bottle", "wine": "BottleGreen", "flask": "Bottle", "bitters": "Bottle"}[kind]
    body = revolve(prof, "y")
    body.translate(Vector(base))
    add(P, m, body, lod)
    top = prof[-2][0]
    cork = cyl(0.0105, 0.018, (0, top + 0.006, 0))
    cork.translate(Vector(base))
    add(P, "Cork", cork, lod)
    if label:
        r = prof[3][1] + 0.0012
        y0, y1 = (0.05, 0.13) if kind != "flask" else (0.03, 0.085)
        lab = revolve([(y0, r - 0.0012), (y0, r), (y1, r), (y1, r - 0.0012)], "y", angle=110.0)
        lab.rotate(O, Y, -145.0 + turn)                 # centre the 110 degree band on the bottle's front (+z)
        lab.translate(Vector(base))
        add(P, "Label", lab, lod)


def shot_glass(P, base, lod=2, full=True):
    g = revolve([(0.0, 0.0), (0.0, 0.022), (0.012, 0.022), (0.060, 0.026), (0.060, 0.023), (0.014, 0.019), (0.014, 0.0)], "y")
    g.translate(Vector(base))
    add(P, "ClearGlass", g, lod)
    if full:
        w = cyl(0.0205, 0.022, (0, 0.026, 0))
        w.translate(Vector(base))
        add(P, "Whiskey", w, lod)


def tumbler(P, base, lod=2, full=False):
    g = revolve([(0.0, 0.0), (0.0, 0.030), (0.016, 0.031), (0.095, 0.036), (0.095, 0.033), (0.018, 0.028), (0.018, 0.0)], "y")
    g.translate(Vector(base))
    add(P, "ClearGlass", g, lod)
    if full:
        w = cyl(0.029, 0.035, (0, 0.036, 0))
        w.translate(Vector(base))
        add(P, "Whiskey", w, lod)


def raised_panel(P, mat, w, h, centre, proud=0.02, bevel=0.012):
    """A raised panel: a field with a bevelled edge, its back at centre.z, its face `proud` in front."""
    cx, cy, cz = centre
    s = box((w, h, proud), (cx, cy, cz + proud / 2.0))
    add(P, mat, chamfer(s, bevel, front_edges(s, cz + proud)))


def ogee_run(P, mat, x0, x1, y0, z0, height, depth, flip=False):
    """A moulding run along x from x0 to x1: an ogee-ish (y, z) profile `height` tall standing on y0, its back at z0, `depth` proud."""
    h, d = height, depth
    prof = [(0.0, 0.0), (0.0, d * 0.35), (h * 0.18, d * 0.42), (h * 0.40, d * 0.70), (h * 0.62, d * 0.95), (h * 0.80, d * 1.0),
            (h * 0.86, d * 0.92), (h, d * 0.92), (h, 0.0)]
    if flip:                                            # a crown: the wide part at the bottom
        prof = [(h - a, b) for a, b in prof][::-1]
    pts = [(y0 + a, z0 + b) for a, b in prof]
    add(P, mat, prism_yz(pts, x1 - x0, x0))


def brass_bail(P, centre, w=0.07, face=1.0):
    """A drawer's brass bail pull on a front at centre.z facing `face` (+1 = +z, -1 = -z): two posts and a hanging half-loop."""
    cx, cy, cz = centre
    for sx in (-1, 1):
        add(P, "Brass", cyl(0.0055, 0.016, (cx + sx * w / 2, cy, cz + face * 0.008), "z"), 2)
    add(P, "Brass", arc_tube((cx, cy, cz + face * 0.016), X, -Y, w / 2, 0.0035, 180.0), 2)


# ====================================================================================================== the saloon: the bar
def build_bar():
    """Bar_Counter's replacement: 8 m long (x -4..4), the customers' side +z. Raised-panel front in ten bays, a moulded plinth and a cove
    under a thick top with a bullnose (top surface 1.20, as the story's coin and glasses expect), the brass foot rail on its posts, and
    at the far left end (clear of every drinker's place) two bottles and three glasses."""
    P = "bar"
    L, D, H = 8.0, 0.75, 1.13
    zf = D / 2.0 - 0.03                                  # carcass face; the frame and panels stand proud of it to z 0.375
    add(P, "DarkWood", box((L, H - 0.15, D - 0.03), (0, 0.15 + (H - 0.15) / 2, -0.015)))
    add(P, "DarkWood", box((L - 0.04, 0.15, D - 0.10), (0, 0.075, -0.05)))                       # recessed kick
    # the frame: stiles between the bays and the top / bottom rails, 25 mm proud
    for i in range(11):
        x = -L / 2 + i * 0.8
        w = 0.10 if 0 < i < 10 else 0.07
        xc = x if 0 < i < 10 else x + (0.035 if i == 0 else -0.035)
        add(P, "DarkWood", chamfer(box((w, 0.86, 0.025), (xc, 0.62, zf + 0.0125)), 0.004))
    for y, h in ((0.215, 0.07), (1.025, 0.07)):
        add(P, "DarkWood", chamfer(box((L, h, 0.025), (0, y, zf + 0.0125)), 0.004))
    for i in range(10):
        raised_panel(P, "GunWood", 0.62, 0.68, (-L / 2 + 0.4 + i * 0.8, 0.62, zf + 0.012), 0.022, 0.014)
    ogee_run(P, "DarkWood", -L / 2, L / 2, 0.15, zf + 0.025, 0.06, 0.03)                           # base moulding on the rail
    ogee_run(P, "DarkWood", -L / 2, L / 2, 1.06, zf + 0.025, 0.07, 0.05, flip=True)               # cove under the top
    # the top: 70 mm thick, 0.95 deep, overhanging the front 0.15, a bullnose on the customers' edge
    top = box((L + 0.3, 0.07, 0.95), (0, 1.165, 0.05))
    top = fillet(top, 0.03, [e for e in top.Edges if abs(e.BoundBox.ZMin - 0.525) < 1e-6 and abs(e.BoundBox.ZMax - 0.525) < 1e-6])
    add(P, "GunWood", top)
    add(P, "GunWood", box((L + 0.3, 0.035, 0.05), (0, 1.2175, -0.40)))                            # the bartender's back lip
    # the brass foot rail on six floor posts, a ring round the rail at each, domed end caps
    add(P, "Brass", cyl(0.03, L - 0.1, (0, 0.20, 0.55), "x"))
    for sx in (-1, 1):
        add(P, "Brass", sphere(0.033, (sx * (L / 2 - 0.05), 0.20, 0.55)))
    for i in range(6):
        x = -3.5 + i * 1.4
        add(P, "Brass", cyl(0.014, 0.17, (x, 0.085, 0.55)))
        add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.035), (0.008, 0.035), (0.014, 0.018), (0.014, 0.0)], "y", (x, 0.0, 0.55)))
        add(P, "Brass", arc_tube((x, 0.20, 0.55), Y, Z, 0.034, 0.007, 360.0))                    # a ring round the rail
        add(P, "Brass", cyl(0.010, 0.15, (x, 0.20, 0.47), "z"))                                   # its arm back to the bar front
    # bottles and glasses at the far left end of the top
    bottle(P, "whiskey", (-3.82, 1.20, 0.10), 2)
    bottle(P, "flask", (-3.62, 1.20, -0.05), 2, turn=-30.0)
    for k, (x, z) in enumerate(((-3.45, 0.22), (-3.30, 0.14), (-3.52, 0.32))):
        shot_glass(P, (x, 1.20, z), 2, full=k != 2)


# ====================================================================================================== the saloon: the back bar
def build_register(P, base):
    """A brass cash register on the back bar's counter (front +z)."""
    bx, by, bz = base
    body = box((0.36, 0.20, 0.30), (bx, by + 0.10, bz))
    add(P, "Brass", chamfer(body, 0.012))
    add(P, "DarkWood", chamfer(box((0.40, 0.07, 0.34), (bx, by + 0.035, bz + 0.01)), 0.008))       # the cash drawer
    add(P, "Brass", box((0.08, 0.018, 0.012), (bx, by + 0.035, bz + 0.185)))                      # its pull
    keybank = prism_yz([(by + 0.20, bz + 0.15), (by + 0.20, bz + 0.0), (by + 0.33, bz - 0.08), (by + 0.33, bz + 0.0)], 0.34, bx - 0.17)
    add(P, "Brass", chamfer(keybank, 0.006))
    nrm = Vector(0, 0.756, 0.655)                                   # the key bank's sloped face (up and toward the bartender)
    for row in range(3):
        for col in range(6):
            t = (row + 0.5) / 3.0
            kp = Vector(bx - 0.125 + col * 0.05, by + 0.20 + 0.13 * t, bz + 0.15 - 0.15 * t) + nrm * 0.012
            add(P, "Ivory", cyl(0.012, 0.024, kp, nrm), 2)
    add(P, "Brass", chamfer(box((0.30, 0.13, 0.08), (bx, by + 0.395, bz - 0.06)), 0.01))         # the amount-purchased sign
    add(P, "Paper", box((0.22, 0.05, 0.004), (bx, by + 0.40, bz - 0.019)))
    add(P, "Brass", sphere(0.025, (bx, by + 0.475, bz - 0.06)))
    add(P, "Brass", cyl(0.012, 0.06, (bx + 0.21, by + 0.14, bz), "x"))                            # the crank
    add(P, "Brass", box((0.012, 0.11, 0.025), (bx + 0.245, by + 0.10, bz)))
    add(P, "DarkWood", cyl(0.012, 0.05, (bx + 0.27, by + 0.05, bz), "x"))


def build_back_bar():
    """Bar_BackShelf's replacement (6 m wide, its back at z -0.4, the old mirror where it was): a cabinet of six panelled doors under a
    counter, four turned columns, the arched mirror in a moulded frame, shelves of bottles either side (forty, of four kinds), a
    frieze, a dentil cornice, the brass register in the middle and two pyramids of glasses."""
    P = "back_bar"
    W = 6.0
    # base cabinet (doors face the bartender, +z), counter on it
    add(P, "DarkWood", box((W, 0.88, 0.50), (0, 0.48, -0.15)))
    add(P, "DarkWood", box((W - 0.04, 0.08, 0.44), (0, 0.04, -0.17)))
    for i in range(6):
        x = -2.5 + i * 1.0
        add(P, "DarkWood", chamfer(box((0.94, 0.70, 0.02), (x, 0.47, 0.11)), 0.004))
        raised_panel(P, "GunWood", 0.72, 0.50, (x, 0.47, 0.12), 0.018, 0.012)
        add(P, "Brass", sphere(0.013, (x + (0.38 if i % 2 == 0 else -0.38), 0.55, 0.13)))
    top = box((W + 0.1, 0.05, 0.56), (0, 0.945, -0.12))
    add(P, "GunWood", chamfer(top, 0.01))
    # back panel, end boards, shelves
    add(P, "DarkWood", box((W, 1.95, 0.04), (0, 0.97 + 0.975, -0.38)))
    for sx in (-1, 1):
        add(P, "DarkWood", box((0.05, 1.95, 0.40), (sx * (W / 2 - 0.025), 0.97 + 0.975, -0.20)))
        for y in (1.50, 2.03, 2.56):
            add(P, "DarkWood", chamfer(box((1.40, 0.03, 0.36), (sx * 2.18, y, -0.20)), 0.004))
    # four turned columns standing on the counter
    col = [(0.0, 0.0), (0.0, 0.075), (0.05, 0.075), (0.07, 0.062), (0.10, 0.058), (0.13, 0.050), (0.20, 0.046), (1.50, 0.040),
           (1.55, 0.050), (1.60, 0.042), (1.70, 0.058), (1.78, 0.072), (1.83, 0.072), (1.83, 0.0)]
    for x in (-2.93, -1.43, 1.43, 2.93):
        add(P, "GunWood", turned(col, (x, 0.97, -0.04)))
        add(P, "DarkWood", box((0.17, 0.05, 0.17), (x, 0.97 + 1.855, -0.04)))
    # the mirror and its frame, an arched pediment over it
    add(P, "Mirror", box((2.6, 1.6, 0.02), (0, 1.95, -0.35)))
    fr = 0.09
    for y in (1.15 - fr / 2, 2.75 + fr / 2):
        add(P, "GunWood", chamfer(box((2.6 + 2 * fr, fr, 0.05), (0, y, -0.33)), 0.012))
    for x in (-1.3 - fr / 2, 1.3 + fr / 2):
        add(P, "GunWood", chamfer(box((fr, 1.6, 0.05), (x, 1.95, -0.33)), 0.012))
    # frieze with a brass rosette, dentils, cornice
    add(P, "DarkWood", box((W + 0.1, 0.18, 0.05), (0, 2.98, -0.04)))
    add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.05), (0.012, 0.05), (0.025, 0.02), (0.03, 0.0)], "z", (0, 2.98, -0.015)))
    for i in range(44):
        add(P, "DarkWood", box((0.05, 0.05, 0.04), (-W / 2 + 0.07 + i * (W - 0.14) / 43, 3.095, 0.005)), 2)
    ogee_run(P, "GunWood", -W / 2 - 0.1, W / 2 + 0.1, 3.12, -0.06, 0.10, 0.16, flip=True)
    add(P, "DarkWood", box((W + 0.24, 0.03, 0.30), (0, 3.235, -0.02)))
    # bottles: four levels each side
    kinds = ["whiskey", "wine", "flask", "bitters", "whiskey"]
    n = 0
    for sx in (-1, 1):
        for li, y in enumerate((0.97, 1.515, 2.045, 2.575)):
            for b in range(5):
                x = sx * (1.62 + b * 0.27) + (hrand(n, 1) - 0.5) * 0.04
                kind = kinds[(b + li * 2 + (0 if sx < 0 else 1)) % 5]
                bottle(P, kind, (x, y, -0.22 + (hrand(n, 2) - 0.5) * 0.06), 2, turn=(hrand(n, 3) - 0.5) * 40.0)
                n += 1
    build_register(P, (0.0, 0.97, -0.12))
    for gx in (-0.85, 0.85):                                                                      # pyramids of glasses
        for row, cnt in ((0, 4), (1, 3), (2, 2), (3, 1)):
            for k in range(cnt):
                shot_glass(P, (gx + (k - (cnt - 1) / 2.0) * 0.055, 0.97 + row * 0.061, -0.10 - row * 0.0), 2, full=False)


# ====================================================================================================== the saloon: tables + chairs
def build_table():
    """Bar_Table's replacement: a 1.1 m round top with a moulded edge (surface 0.785), an apron ring, a turned pedestal and four
    cabriole feet with brass toes."""
    P = "table"
    add(P, "DarkWood", revolve([(0.745, 0.0), (0.745, 0.528), (0.752, 0.547), (0.765, 0.553), (0.777, 0.548), (0.785, 0.536),
                                (0.785, 0.0)], "y"), 0)                     # the old table's own dark wood (the saloon tones it)
    add(P, "DarkWood", revolve([(0.675, 0.40), (0.675, 0.43), (0.745, 0.43), (0.745, 0.40)], "y"))
    add(P, "DarkWood", revolve([(0.06, 0.0), (0.06, 0.078), (0.10, 0.078), (0.12, 0.062), (0.16, 0.050), (0.20, 0.066), (0.23, 0.066),
                                (0.26, 0.046), (0.45, 0.038), (0.55, 0.043), (0.58, 0.056), (0.60, 0.056), (0.63, 0.046), (0.66, 0.062),
                                (0.70, 0.075), (0.745, 0.075), (0.745, 0.0)], "y"))
    foot = prism_yz([(0.0, 0.04), (0.0, 0.33), (0.018, 0.355), (0.045, 0.345), (0.07, 0.27), (0.12, 0.17), (0.19, 0.08), (0.22, 0.04)],
                    0.05, -0.025)
    foot = fillet(foot, 0.008, [e for e in foot.Edges if abs(e.tangentAt(e.FirstParameter).dot(X)) < 0.2])
    for k in range(4):
        add(P, "DarkWood", rot_y(foot, 45.0 + k * 90.0))
        add(P, "Brass", rot_y(sphere(0.016, (0, 0.016, 0.345)), 45.0 + k * 90.0), 2)


def build_chair():
    """Bar_Chair's replacement: a bentwood (Thonet No. 14) saloon chair. A bent seat rim round a cane seat (top 0.48, the old seat
    height), the back's outer loop running down into the rear legs, an inner loop, splayed front legs and the leg ring. The sitter
    faces +z; the back is at -z like the old chair's."""
    P = "chair"
    W = "DarkWood"                                   # the old box chair's own dark wood, so the room keeps its tone
    add(P, W, arc_tube((0, 0.462, 0), X, -Z, 0.205, 0.019, 360.0))
    add(P, "Cane", cyl(0.198, 0.016, (0, 0.472, 0)))
    up = Vector(0.0, 0.33, -0.05).normalize()
    for R, r, x, y0, z0, length in ((0.17, 0.0165, 0.17, 0.47, -0.17, 0.33), (0.095, 0.011, 0.095, 0.48, -0.185, 0.21)):
        tops = []
        for sx in (-1, 1):
            b = Vector(sx * x, y0, z0)
            t = b + up * length
            add(P, W, cyl_between(b, t, r))
            add(P, W, sphere(r, t), 2)
            tops.append(t)
        centre = (tops[0] + tops[1]) * 0.5
        add(P, W, arc_tube(centre, X, up, R, r, 180.0))
    for sx in (-1, 1):
        add(P, W, cone_between((sx * 0.17, 0.47, -0.17), (sx * 0.205, 0.0, -0.30), 0.0175, 0.0135))      # rear legs (the loop's ends)
        add(P, W, sphere(0.0175, (sx * 0.17, 0.47, -0.17)), 2)
        add(P, W, cone_between((sx * 0.15, 0.462, 0.13), (sx * 0.18, 0.0, 0.19), 0.0175, 0.0135))       # front legs
        add(P, W, cyl_between((sx * 0.15, 0.40, 0.13), (sx * 0.17, 0.40, -0.17), 0.007), 2)                # seat brackets
    add(P, W, arc_tube((0, 0.19, -0.05), X, Z, 0.272, 0.0095, 360.0))


def build_poker_set():
    """A poker spread on a table top (origin = the table's top centre): the deck, two fanned hands, stacks of chips, the pot, a bottle
    and two glasses."""
    P = "poker_set"
    deck = box((0.063, 0.016, 0.088), (0, 0.008, 0))
    deck.rotate(O, Y, 22.0)
    add(P, "Paper", moved(deck, (0.10, 0.0, 0.06)), 2)
    for hand, (hx, hz, yaw) in enumerate(((0.0, 0.33, 0.0), (-0.32, -0.12, 110.0))):
        for k in range(5):
            c = box((0.063, 0.0012, 0.088), (0, 0.0008 + k * 0.0012, 0.03))
            c.rotate(v(0, 0, -0.03), Y, (k - 2) * 11.0)
            c.rotate(O, Y, yaw)
            add(P, "Paper", moved(c, (hx, 0.0, hz)), 2)
    cols = ["ChipRed", "ChipWhite", "ChipBlue"]
    stacks = [(0.20, 0.30, 9, 0), (0.24, 0.27, 6, 1), (0.235, 0.32, 4, 2), (-0.36, 0.08, 11, 0), (-0.40, 0.03, 7, 2), (-0.33, 0.02, 5, 1),
              (0.02, 0.04, 8, 1), (-0.03, -0.02, 5, 0), (0.05, -0.04, 3, 2)]
    for x, z, n, c in stacks:
        add(P, cols[c], cyl(0.019, 0.0034 * n, (x, 0.0017 * n, z)), 2)
    for k in range(5):
        a = k * 1.3
        ch = cyl(0.019, 0.0034, (0.0, 0.0017, 0.0))
        ch.rotate(O, X, 4.0 * k)
        add(P, cols[k % 3], moved(ch, (0.09 * math.cos(a) - 0.05, 0.0005 * k, 0.09 * math.sin(a) + 0.12)), 2)
    bottle(P, "whiskey", (-0.12, 0.0, -0.28), 2)
    shot_glass(P, (0.06, 0.0, 0.22), 2)
    shot_glass(P, (-0.28, 0.0, -0.05), 2, full=False)


def build_table_drinks():
    """A table's round (origin = the top centre): a bottle, two glasses, a folded newspaper."""
    P = "table_drinks"
    bottle(P, "whiskey", (0.05, 0.0, -0.08), 2, turn=20.0)
    tumbler(P, (-0.18, 0.0, 0.10), 2, full=True)
    shot_glass(P, (0.22, 0.0, 0.12), 2)
    paper = box((0.30, 0.008, 0.21), (0, 0.004, 0))
    paper.rotate(O, Y, -18.0)
    add(P, "Newsprint", moved(paper, (-0.12, 0.0, -0.25)), 2)


# ====================================================================================================== the saloon: piano, stool, cuspidor
def build_piano():
    """Bar_Piano's replacement: an upright cabinet piano (1.5 x 1.3 x 0.6 like the old box, keys toward +z): the case and lid, panelled
    upper and lower fronts, scrolled cheeks, 52 ivory and 36 ebony keys on the key bed, the name board, sheet music on the desk, swing
    candle sconces, turned front legs on toe blocks, two brass pedals."""
    P = "piano"
    add(P, "DarkWood", box((1.5, 1.24, 0.40), (0, 0.06 + 0.62, -0.10)))
    lid = box((1.56, 0.035, 0.47), (0, 1.3175, -0.075))
    add(P, "GunWood", fillet(lid, 0.012, [e for e in lid.Edges if e.BoundBox.ZMin > 0.15 and e.BoundBox.ZMax > 0.15 and abs(e.BoundBox.ZMax - e.BoundBox.ZMin) < 1e-6]))
    add(P, "DarkWood", box((1.5, 0.08, 0.44), (0, 0.04, -0.08)))                                     # plinth
    # upper front: frame + two raised panels + a fretwork centre on red cloth
    add(P, "DarkWood", box((1.42, 0.40, 0.02), (0, 1.06, 0.11)))
    for x in (-0.47, 0.47):
        raised_panel(P, "GunWood", 0.38, 0.28, (x, 1.06, 0.12), 0.016, 0.01)
    add(P, "Cloth", box((0.40, 0.28, 0.006), (0, 1.06, 0.121)))
    for k in range(7):
        add(P, "GunWood", box((0.012, 0.28, 0.012), (-0.18 + k * 0.06, 1.06, 0.128)), 2)
    add(P, "GunWood", box((0.40, 0.012, 0.012), (0, 1.06, 0.129)), 2)
    # lower front
    add(P, "DarkWood", box((1.42, 0.54, 0.02), (0, 0.36, 0.11)))
    for x in (-0.36, 0.36):
        raised_panel(P, "GunWood", 0.56, 0.40, (x, 0.36, 0.12), 0.016, 0.01)
    # cheeks
    cheek = [(0.66, 0.10), (0.66, 0.37), (0.69, 0.405), (0.745, 0.41), (0.79, 0.385), (0.835, 0.31), (0.89, 0.22), (0.93, 0.10)]
    for x0 in (-0.75, 0.69):
        add(P, "GunWood", chamfer(prism_yz(cheek, 0.06, x0), 0.006))
    # key bed, key slip, name board
    add(P, "DarkWood", box((1.38, 0.06, 0.30), (0, 0.69, 0.25)))
    add(P, "GunWood", chamfer(box((1.38, 0.045, 0.022), (0, 0.7175, 0.411)), 0.004))
    add(P, "GunWood", chamfer(box((1.38, 0.12, 0.12), (0, 0.80, 0.19)), 0.006))                   # the name board block behind the keys
    add(P, "Brass", box((0.18, 0.025, 0.003), (0, 0.80, 0.2515)))
    add(P, "GunWood", box((0.60, 0.015, 0.03), (0.05, 0.8675, 0.18)))                              # the music ledge
    pitch = 1.23 / 52.0
    for i in range(52):
        x = -0.615 + (i + 0.5) * pitch
        add(P, "Ivory", box((pitch - 0.0012, 0.022, 0.145), (x, 0.731, 0.3275)), 2)
        if "ABCDEFG"[i % 7] in "ACDFG" and i < 51:                     # a black key after A, C, D, F and G
            add(P, "Ebony", chamfer(box((0.0125, 0.022, 0.09), (x + pitch / 2, 0.753, 0.30)), 0.002), 2)
    # sheet music leaning on the upper front
    sheet = box((0.42, 0.28, 0.004), (0, 0.0, 0.0))
    sheet.rotate(O, X, -12.0)
    add(P, "Paper", moved(sheet, (0.05, 1.02, 0.15)), 2)
    # candle sconces
    for sx in (-1, 1):
        x = sx * 0.58
        add(P, "Brass", cyl(0.007, 0.12, (x, 1.12, 0.18), "z"), 2)
        add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.028), (0.012, 0.03), (0.03, 0.018), (0.03, 0.0)], "y", (x, 1.10, 0.25)), 2)
        add(P, "Wax", cyl(0.011, 0.12, (x, 1.19, 0.25)), 2)
    # turned front legs on toe blocks, pedals
    leg = [(0.0, 0.0), (0.0, 0.045), (0.04, 0.045), (0.07, 0.035), (0.25, 0.030), (0.31, 0.042), (0.35, 0.030), (0.52, 0.036), (0.56, 0.046),
           (0.61, 0.046), (0.61, 0.0)]
    for sx in (-1, 1):
        add(P, "GunWood", turned(leg, (sx * 0.665, 0.05, 0.36)))
        add(P, "DarkWood", chamfer(box((0.10, 0.05, 0.14), (sx * 0.665, 0.025, 0.34)), 0.008))
    for sx in (-1, 1):
        add(P, "Brass", chamfer(box((0.035, 0.014, 0.09), (sx * 0.05, 0.07, 0.165)), 0.004))


def build_piano_stool():
    """A revolving piano stool: leather-topped round seat on a turned column with its screw, three splayed legs ending in brass
    ball feet (origin base centre)."""
    P = "piano_stool"
    add(P, "Leather", revolve([(0.47, 0.0), (0.47, 0.168), (0.485, 0.172), (0.505, 0.165), (0.515, 0.14), (0.52, 0.0)], "y"))
    add(P, "GunWood", revolve([(0.44, 0.0), (0.44, 0.17), (0.47, 0.17), (0.47, 0.0)], "y"))
    add(P, "Iron", cyl(0.018, 0.08, (0, 0.42, 0)))
    add(P, "GunWood", revolve([(0.22, 0.0), (0.22, 0.05), (0.26, 0.05), (0.29, 0.035), (0.36, 0.032), (0.39, 0.045), (0.40, 0.045),
                               (0.40, 0.0)], "y"))
    for k in range(3):
        a = math.radians(k * 120.0)
        d = Vector(math.sin(a), 0, math.cos(a))
        top = Vector(0, 0.28, 0) + d * 0.04
        foot = Vector(0, 0.03, 0) + d * 0.25
        add(P, "GunWood", cone_between(top, foot, 0.022, 0.016))
        add(P, "Brass", sphere(0.026, foot + Vector(0, -0.004, 0)))


def build_spittoon():
    """A brass cuspidor: weighted base, belly, waist and the wide funnel rim dished toward the dark hole."""
    P = "spittoon"
    add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.105), (0.01, 0.112), (0.05, 0.140), (0.095, 0.128), (0.118, 0.090), (0.145, 0.128),
                             (0.155, 0.150), (0.163, 0.152), (0.160, 0.142), (0.138, 0.060), (0.126, 0.030), (0.124, 0.0)], "y"), 0)
    add(P, "Soot", cyl(0.029, 0.004, (0, 0.126, 0)), 2)


# ====================================================================================================== lamps, chandelier, clock, hats
def lamp_head(P, base, lod=1, chimney=0.18):
    """A burner, its glass chimney and a flame, on whatever font is below `base` (the font's top)."""
    bx, by, bz = base
    add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.030), (0.012, 0.034), (0.024, 0.028), (0.03, 0.0)], "y", (bx, by, bz)), lod)
    add(P, "Brass", cyl(0.006, 0.02, (bx + 0.028, by + 0.012, bz), "x"), 2)                       # the wick knob
    add(P, "LampGlass", revolve([(0.0, 0.026), (0.03, 0.040), (0.07, 0.036), (chimney, 0.020), (chimney, 0.0185), (0.07, 0.034),
                                 (0.03, 0.038), (0.0, 0.024)], "y", (bx, by + 0.03, bz)), lod)
    add(P, "Flame", revolve([(0.0, 0.0), (0.0, 0.006), (0.012, 0.008), (0.03, 0.004), (0.042, 0.0)], "y", (bx, by + 0.036, bz)), 2)


def build_hang_lamp():
    """A hanging harp lamp. Origin = its hanging ring; everything hangs below (-y): smoke bell, three harp rods, an opal glass shade,
    the brass font with its burner, chimney and flame (the flame is 0.47 m below the ring). The game hangs it on a chain."""
    P = "hang_lamp"
    add(P, "Brass", arc_tube((0, -0.02, 0), X, Y, 0.02, 0.0045, 360.0))
    add(P, "Brass", revolve([(-0.04, 0.0), (-0.04, 0.012), (-0.06, 0.03), (-0.085, 0.065), (-0.10, 0.07), (-0.10, 0.0)], "y"))
    for k in range(3):
        a = math.radians(k * 120.0)
        d = Vector(math.sin(a), 0, math.cos(a))
        p0 = Vector(0, -0.095, 0) + d * 0.06
        p1 = Vector(0, -0.30, 0) + d * 0.115
        p2 = Vector(0, -0.50, 0) + d * 0.10
        add(P, "Brass", cyl_between(p0, p1, 0.0045))
        add(P, "Brass", cyl_between(p1, p2, 0.0045))
        add(P, "Brass", sphere(0.0045, p1), 2)
    add(P, "Opal", revolve([(-0.27, 0.055), (-0.30, 0.10), (-0.34, 0.15), (-0.38, 0.185), (-0.385, 0.185), (-0.345, 0.15),
                            (-0.305, 0.10), (-0.275, 0.055)], "y"), 0)
    add(P, "Brass", arc_tube((0, -0.50, 0), X, Z, 0.10, 0.006, 360.0))
    add(P, "Brass", revolve([(-0.62, 0.0), (-0.62, 0.03), (-0.60, 0.065), (-0.56, 0.085), (-0.52, 0.08), (-0.50, 0.04), (-0.50, 0.0)], "y"))
    add(P, "Brass", revolve([(-0.67, 0.0), (-0.66, 0.012), (-0.63, 0.016), (-0.62, 0.02), (-0.62, 0.0)], "y"), 2)
    lamp_head(P, (0.0, -0.50, 0.0))


def build_chandelier():
    """A wagon-wheel chandelier: the felloe ring with its iron tyre, a banded hub, twelve tapered spokes, six oil lamps standing on the
    rim and three rods up to the ring it hangs from. Origin = that ring; the wheel is 0.9 m below it, its lamps' flames ~0.8 m below."""
    P = "chandelier"
    y = -0.90
    add(P, "DarkWood", revolve([(y - 0.04, 0.70), (y - 0.04, 0.78), (y + 0.04, 0.78), (y + 0.04, 0.70)], "y"))
    add(P, "Iron", revolve([(y - 0.045, 0.78), (y - 0.045, 0.792), (y + 0.045, 0.792), (y + 0.045, 0.78)], "y"))
    add(P, "DarkWood", revolve([(y - 0.11, 0.0), (y - 0.11, 0.07), (y - 0.08, 0.095), (y + 0.08, 0.095), (y + 0.11, 0.07), (y + 0.11, 0.0)], "y"))
    for yy in (y - 0.075, y + 0.075):
        add(P, "Iron", revolve([(yy - 0.012, 0.0955), (yy - 0.012, 0.104), (yy + 0.012, 0.104), (yy + 0.012, 0.0955)], "y"))
    for k in range(12):
        a = math.radians(k * 30.0)
        d = Vector(math.sin(a), 0, math.cos(a))
        add(P, "DarkWood", cone_between(Vector(0, y, 0) + d * 0.09, Vector(0, y, 0) + d * 0.71, 0.024, 0.016))
    for k in range(6):
        a = math.radians(k * 60.0 + 15.0)
        c = Vector(0.74 * math.sin(a), y + 0.04, 0.74 * math.cos(a))
        add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.045), (0.02, 0.05), (0.045, 0.04), (0.06, 0.02), (0.06, 0.0)], "y", c))
        lamp_head(P, (c.x, c.y + 0.06, c.z), 2, 0.16)
    for k in range(3):
        a = math.radians(k * 120.0 + 45.0)
        add(P, "Iron", cyl_between((0.74 * math.sin(a), y + 0.04, 0.74 * math.cos(a)), (0.03 * math.sin(a), -0.03, 0.03 * math.cos(a)), 0.006))
    add(P, "Iron", arc_tube((0, -0.03, 0), X, Z, 0.035, 0.007, 360.0))
    add(P, "Iron", arc_tube((0, 0.0, 0), X, Y, 0.022, 0.006, 360.0))


def build_clock():
    """A Vienna regulator wall clock. Origin = the middle of its back at the bottom of the case (hang it with the back on the wall):
    a glazed case 0.38 x 0.95, a pediment with three turned finials, a drop with a finial below, the paper dial in a brass bezel with
    hour marks and hands at ten past ten, two brass weights. Its pendulum is the separate clock_pendulum."""
    P = "clock"
    W, H, D = 0.38, 0.95, 0.12
    add(P, "DarkWood", box((W, H, 0.015), (0, H / 2, 0.0075)))
    for sx in (-1, 1):
        add(P, "GunWood", box((0.025, H, D), (sx * (W / 2 - 0.0125), H / 2, D / 2)))
    for yy in (0.0125, H - 0.0125):
        add(P, "GunWood", box((W, 0.025, D), (0, yy, D / 2)))
    for sx in (-1, 1):
        add(P, "GunWood", chamfer(box((0.035, H, 0.02), (sx * (W / 2 - 0.0175), H / 2, D + 0.01)), 0.006))
    for yy in (0.0175, H - 0.0175, 0.62):
        add(P, "GunWood", chamfer(box((W, 0.035, 0.02), (0, yy, D + 0.01)), 0.006))
    add(P, "ClearGlass", box((W - 0.07, H - 0.07, 0.004), (0, H / 2, D + 0.004)))
    # pediment + finials, base moulding + drop + finial
    add(P, "GunWood", chamfer(box((W + 0.08, 0.05, D + 0.05), (0, H + 0.025, D / 2 + 0.01)), 0.01))
    add(P, "GunWood", prism_xy([(-W / 2 - 0.02, H + 0.05), (W / 2 + 0.02, H + 0.05), (0, H + 0.17)], 0.03, D - 0.01))
    fin = [(0.0, 0.0), (0.0, 0.018), (0.02, 0.02), (0.045, 0.012), (0.06, 0.016), (0.075, 0.006), (0.085, 0.0)]
    for x, yy in ((-W / 2, H + 0.05), (W / 2, H + 0.05), (0, H + 0.165)):
        add(P, "GunWood", turned(fin, (x, yy, D / 2)), 2)
    add(P, "GunWood", chamfer(box((W + 0.06, 0.045, D + 0.04), (0, -0.0225, D / 2 + 0.01)), 0.01))
    add(P, "GunWood", prism_xy([(-W / 2, -0.045), (W / 2, -0.045), (0.06, -0.16), (-0.06, -0.16)], D - 0.02, 0.01))
    add(P, "GunWood", turned([(0.0, 0.0), (0.0, 0.02), (-0.03, 0.025), (-0.06, 0.012), (-0.08, 0.0)], (0, -0.16, D / 2)), 2)
    # dial, bezel, marks, hands
    dc = Vector(0, 0.78, 0.098)
    add(P, "Paper", cyl(0.11, 0.004, dc, "z"))
    add(P, "Brass", arc_tube(dc + Vector(0, 0, 0.004), X, Y, 0.112, 0.0065, 360.0))
    for k in range(12):
        a = math.radians(k * 30.0)
        mk = box((0.004, 0.016 if k % 3 else 0.022, 0.002), (0, 0, 0))
        mk.rotate(O, Z, -k * 30.0)
        add(P, "Ebony", moved(mk, dc + Vector(0.093 * math.sin(a), 0.093 * math.cos(a), 0.003)), 2)
    for length, w, ang in ((0.055, 0.006, -305.0), (0.085, 0.004, -60.0)):
        hd = box((w, length, 0.0015), (0, length / 2 - 0.01, 0))
        hd.rotate(O, Z, ang)
        add(P, "Ebony", moved(hd, dc + Vector(0, 0, 0.004)), 2)
    add(P, "Brass", cyl(0.006, 0.006, dc + Vector(0, 0, 0.005), "z"), 2)
    for sx in (-1, 1):
        add(P, "Brass", cyl(0.0015, 0.20, (sx * 0.09, 0.55, 0.05)), 2)
        add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.02), (0.01, 0.022), (0.12, 0.022), (0.13, 0.012), (0.135, 0.0)], "y", (sx * 0.09, 0.32, 0.05)))


def build_clock_pendulum():
    """The regulator's pendulum. Origin = its pivot (0.70 m up the case, 0.05 m off the back): a flat brass rod down to the bob."""
    P = "clock_pendulum"
    add(P, "Brass", box((0.008, 0.46, 0.003), (0, -0.23, 0)))
    add(P, "Brass", cyl(0.055, 0.008, (0, -0.47, 0), "z"))
    add(P, "Brass", arc_tube((0, -0.47, 0.004), X, Y, 0.055, 0.003, 360.0), 2)


def hat(P, base, tilt=(0.0, 0.0), yaw=0.0, felt="HatFelt"):
    """A Boss-of-the-Plains hat: an open crown with a crease, a curled brim, a leather band. `base` = the bottom of the crown."""
    parts = []
    parts.append((felt, revolve([(0.0, 0.080), (0.11, 0.074), (0.13, 0.060), (0.135, 0.030), (0.125, 0.0), (0.118, 0.0), (0.122, 0.028),
                                 (0.118, 0.056), (0.10, 0.068), (0.0, 0.072)], "y")))
    parts.append((felt, revolve([(0.0, 0.076), (0.003, 0.15), (0.012, 0.19), (0.026, 0.205), (0.030, 0.203), (0.018, 0.186), (0.008, 0.148),
                                 (-0.004, 0.076)], "y")))
    parts.append(("Leather", revolve([(0.0, 0.0805), (0.0, 0.0825), (0.022, 0.0805), (0.022, 0.0785)], "y")))
    parts.append((felt, box((0.006, 0.03, 0.10), (0, 0.13, 0))))                                   # the crown's crease
    for m, s in parts:
        s.rotate(O, Y, yaw)
        s.rotate(O, X, tilt[0])
        s.rotate(O, Z, tilt[1])
        s.translate(Vector(base))
        add(P, m, s, 0 if m != "Leather" else 1)


def build_hat_rack():
    """A hall tree: a turned pole on four feet, six brass hooks with ball tips, one hat on the top knob and one hung on a hook."""
    P = "hat_rack"
    add(P, "GunWood", revolve([(0.10, 0.0), (0.10, 0.04), (0.14, 0.04), (0.16, 0.028), (0.85, 0.024), (0.88, 0.034), (0.90, 0.024),
                               (1.58, 0.022), (1.61, 0.034), (1.64, 0.024), (1.80, 0.024), (1.83, 0.034), (1.86, 0.042), (1.89, 0.03),
                               (1.91, 0.0)], "y"))
    foot = prism_yz([(0.0, 0.02), (0.0, 0.30), (0.02, 0.32), (0.04, 0.30), (0.07, 0.20), (0.11, 0.10), (0.15, 0.045), (0.16, 0.02)], 0.045, -0.0225)
    for k in range(4):
        add(P, "GunWood", rot_y(fillet(foot, 0.006), 45.0 + k * 90.0))
    for k in range(6):
        a = math.radians(k * 60.0)
        d = Vector(math.sin(a), 0, math.cos(a))
        yy = 1.70 if k % 2 == 0 else 1.62
        p0 = Vector(0, yy, 0) + d * 0.02
        p1 = Vector(0, yy, 0) + d * 0.11
        add(P, "Brass", cyl_between(p0, p1, 0.006))
        add(P, "Brass", arc_tube(p1 + Vector(0, 0.04, 0), -Y, d, 0.04, 0.006, 150.0))
        tip = p1 + Vector(0, 0.04, 0) + (d * math.sin(math.radians(150.0)) - Y * math.cos(math.radians(150.0))) * 0.04
        add(P, "Brass", sphere(0.011, tip), 2)
    hat(P, (0.0, 1.835, 0.0), (8.0, -6.0), 30.0)
    hat(P, (0.0, 1.70, 0.09), (80.0, 5.0), 0.0, "HatFeltDark")             # hung by its crown on the front hook


# ====================================================================================================== the certificate office
def build_counter():
    """Int_Counter's replacement (4 m, top surface 1.125, the customer at +z): five raised-panel bays, a moulded plinth and cove, a
    thick walnut top; on it the brass desk bell (at the old BellAnchor), the open certificate book in front of Mike Dean, an inkwell
    and dip pen, a stamp on its tin pad and a few loose certificates."""
    P = "counter"
    L, D, H = 4.0, 0.70, 1.055
    zf = D / 2.0 - 0.03
    add(P, "DarkWood", box((L, H - 0.14, D - 0.03), (0, 0.14 + (H - 0.14) / 2, -0.015)))
    add(P, "DarkWood", box((L - 0.04, 0.14, D - 0.10), (0, 0.07, -0.05)))
    for i in range(6):
        x = -L / 2 + i * 0.8
        w = 0.10 if 0 < i < 5 else 0.07
        xc = x if 0 < i < 5 else x + (0.035 if i == 0 else -0.035)
        add(P, "DarkWood", chamfer(box((w, 0.80, 0.025), (xc, 0.58, zf + 0.0125)), 0.004))
    for y, h in ((0.205, 0.07), (0.955, 0.07)):
        add(P, "DarkWood", chamfer(box((L, h, 0.025), (0, y, zf + 0.0125)), 0.004))
    for i in range(5):
        raised_panel(P, "GunWood", 0.62, 0.62, (-L / 2 + 0.4 + i * 0.8, 0.58, zf + 0.012), 0.022, 0.014)
    ogee_run(P, "DarkWood", -L / 2, L / 2, 0.14, zf + 0.025, 0.06, 0.03)
    ogee_run(P, "DarkWood", -L / 2, L / 2, 0.99, zf + 0.025, 0.065, 0.045, flip=True)
    top = box((L + 0.2, 0.07, 0.85), (0, 1.09, 0.0))
    top = fillet(top, 0.025, [e for e in top.Edges if abs(e.BoundBox.ZMin - 0.425) < 1e-6 and abs(e.BoundBox.ZMax - 0.425) < 1e-6])
    add(P, "GunWood", top)
    T = 1.125
    # the bell
    add(P, "DarkWood", revolve([(0.0, 0.0), (0.0, 0.048), (0.012, 0.05), (0.014, 0.0)], "y", (1.3, T, 0.1)))
    add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.042), (0.012, 0.040), (0.026, 0.032), (0.036, 0.018), (0.042, 0.0)], "y", (1.3, T + 0.014, 0.1)))
    add(P, "Iron", cyl(0.004, 0.016, (1.3, T + 0.062, 0.1)), 2)
    add(P, "Iron", sphere(0.007, (1.3, T + 0.072, 0.1)), 2)
    # the open certificate book (spine along z, facing the customer), its ribbon
    book = []
    book.append(("Leather", box((0.46, 0.008, 0.33), (0, 0.004, 0))))
    for sx in (-1, 1):
        pg = box((0.215, 0.016, 0.31), (sx * 0.112, 0.016, 0))
        pg.rotate(v(0, 0.008, 0), Z, -sx * 3.0)
        book.append(("Paper", pg))
    book.append(("Cloth", box((0.008, 0.002, 0.24), (0.01, 0.0265, 0.06))))
    for m, s in book:
        s.rotate(O, Y, 6.0)
        s.translate(v(-0.05, T, 0.04))
        add(P, m, s)
    # inkwell + pen, stamp + pad, loose certificates
    add(P, "ClearGlass", chamfer(box((0.05, 0.045, 0.05), (0.32, T + 0.0225, -0.12)), 0.006), 2)
    add(P, "Ebony", box((0.042, 0.03, 0.042), (0.32, T + 0.017, -0.12)), 2)
    add(P, "Brass", cyl(0.014, 0.012, (0.32, T + 0.051, -0.12)), 2)
    pen = cyl(0.0042, 0.17, (0, 0, 0), "x")
    pen.rotate(O, Y, 28.0)
    pen.rotate(O, Z, 4.0)
    add(P, "GunWood", moved(pen, (0.42, T + 0.01, -0.02)), 2)
    add(P, "Tin", box((0.10, 0.012, 0.07), (0.70, T + 0.006, 0.05)), 2)
    add(P, "Ebony", box((0.088, 0.002, 0.058), (0.70, T + 0.0125, 0.05)), 2)
    add(P, "GunWood", revolve([(0.0, 0.0), (0.0, 0.022), (0.012, 0.022), (0.02, 0.009), (0.06, 0.008), (0.07, 0.014), (0.08, 0.0)], "y",
                              (0.86, T, 0.08)), 2)
    for k, (x, z, a) in enumerate(((-0.62, 0.10, 14.0), (-0.66, 0.08, -9.0), (0.95, -0.15, 31.0))):
        sh = box((0.21, 0.0015, 0.28), (0, 0.00075 + 0.0016 * k, 0))
        sh.rotate(O, Y, a)
        add(P, "Paper", moved(sh, (x, T, z)), 2)


def build_pigeonholes():
    """Int_Shelves' replacement (3.0 x 2.4, its back at z -0.4): a cabinet with a plinth and cornice, eight columns by six rows of
    pigeonholes holding rolled certificates tied with red tape, folded deed bundles and standing ledgers; ledgers and a tin deed box
    on top."""
    P = "pigeonholes"
    W, H, D = 3.0, 2.4, 0.4
    add(P, "DarkWood", box((W, H, 0.02), (0, H / 2, -D + 0.01)))
    for sx in (-1, 1):
        add(P, "DarkWood", box((0.04, H, D), (sx * (W / 2 - 0.02), H / 2, -D / 2)))
    add(P, "DarkWood", box((W, 0.04, D), (0, H - 0.02, -D / 2)))
    add(P, "DarkWood", box((W, 0.04, D), (0, 0.20, -D / 2)))
    add(P, "DarkWood", box((W - 0.04, 0.18, D - 0.04), (0, 0.09, -D / 2 - 0.02)))
    ogee_run(P, "GunWood", -W / 2 - 0.05, W / 2 + 0.05, H, -0.02, 0.10, 0.07, flip=True)
    add(P, "DarkWood", box((W + 0.14, 0.025, D + 0.09), (0, H + 0.1125, -D / 2 + 0.03)))
    ogee_run(P, "GunWood", -W / 2, W / 2, 0.18, 0.0, 0.05, 0.02)
    cols, rows = 8, 6
    cw = (W - 0.08) / cols
    rh = (H - 0.04 - 0.22) / rows
    for c in range(1, cols):
        add(P, "DarkWood", box((0.016, H - 0.26, D - 0.03), (-W / 2 + 0.04 + c * cw, 0.22 + (H - 0.26) / 2, -D / 2 + 0.005)), 2)
    for r in range(1, rows):
        add(P, "DarkWood", box((W - 0.08, 0.016, D - 0.03), (0, 0.22 + r * rh, -D / 2 + 0.005)), 2)
    n = 0
    for r in range(rows):
        for c in range(cols):
            x0 = -W / 2 + 0.04 + c * cw
            y0 = 0.22 + r * rh + 0.008
            kind = hrand(n, 7)
            n += 1
            if kind < 0.12:
                continue                                                  # an empty hole
            if kind < 0.70:                                               # rolled certificates tied with red tape
                k = 2 + int(hrand(n, 8) * 2.99)
                for i in range(k):
                    rr = 0.026 + hrand(n, 9 + i) * 0.008
                    x = x0 + 0.04 + i * (cw - 0.08) / max(1, k - 1) if k > 1 else x0 + cw / 2
                    y = y0 + rr + (0.045 if i == 1 and k == 3 else 0.0)
                    ln = 0.30 + hrand(n, 12 + i) * 0.06
                    add(P, "Paper", cyl(rr, ln, (x, y, -0.20 + (ln - 0.30) / 2), "z"), 2)
                    add(P, "Cloth", cyl(rr + 0.0012, 0.014, (x, y, -0.06 + hrand(n, 15 + i) * 0.03), "z"), 2)
            elif kind < 0.86:                                             # a tied bundle of folded deeds
                bh = 0.05 + hrand(n, 16) * 0.05
                add(P, "Paper", box((cw - 0.05, bh, 0.26), (x0 + cw / 2, y0 + bh / 2, -0.21)), 2)
                add(P, "Rope", box((0.006, bh + 0.003, 0.262), (x0 + cw / 2 + 0.03, y0 + bh / 2, -0.21)), 2)
            else:                                                         # standing ledgers
                for i in range(4):
                    bt = 0.04 + hrand(n, 17 + i) * 0.015
                    bh = rh - 0.06 - hrand(n, 21 + i) * 0.05
                    add(P, "Leather", box((bt, bh, 0.27), (x0 + 0.03 + i * 0.075, y0 + bh / 2, -0.22)), 2)
                    add(P, "Paper", box((bt * 0.6, 0.04, 0.003), (x0 + 0.03 + i * 0.075, y0 + bh * 0.72, -0.0835)), 2)   # spine label
    ytop = H + 0.125
    for i in range(5):                                                    # ledgers lying on top, a deed box
        bt = 0.05 + hrand(i, 30) * 0.02
        add(P, "Leather", box((0.32, bt, 0.25), (-1.1 + (hrand(i, 31) - 0.5) * 0.04, ytop + bt / 2, -0.18)), 2)
        ytop += bt
    add(P, "Iron", chamfer(box((0.36, 0.16, 0.24), (0.9, H + 0.205, -0.18)), 0.01))
    add(P, "Brass", arc_tube((0.9, H + 0.29, -0.18), X, Y, 0.05, 0.005, 180.0), 2)


def build_desk():
    """Int_Desk's replacement (1.8 x 0.9, top surface 0.81): a walnut top with a leather writing inlay over two panelled pedestals; the
    drawers (three a side, brass bail pulls, a lock on the top one) and a kneehole drawer face the sitter at -z, the room side (+z) is
    panelled. On it: papers, a closed ledger and a brass inkstand. The desk lamp is the separate desk_lamp."""
    P = "desk"
    top = box((1.8, 0.035, 0.9), (0, 0.7925, 0))
    add(P, "GunWood", chamfer(top, 0.008))
    add(P, "Leather", box((1.56, 0.002, 0.66), (0, 0.811, 0)))
    for sx in (-1, 1):
        cx = sx * 0.6
        add(P, "DarkWood", box((0.5, 0.70, 0.84), (cx, 0.075 + 0.35, 0)))
        add(P, "DarkWood", box((0.46, 0.075, 0.80), (cx, 0.0375, 0)))
        for (y, h) in ((0.20, 0.24), (0.45, 0.22), (0.655, 0.15)):
            add(P, "GunWood", chamfer(box((0.44, h - 0.02, 0.02), (cx, y, -0.43)), 0.006))
            brass_bail(P, (cx, y + 0.01, -0.44), 0.07, -1.0)
        add(P, "Brass", box((0.014, 0.022, 0.003), (cx, 0.70, -0.4415)), 2)
        for k in range(2):
            raised_panel(P, "GunWood", 0.36, 0.26, (cx, 0.25 + k * 0.32, 0.42), 0.016, 0.01)
    add(P, "GunWood", chamfer(box((0.66, 0.09, 0.02), (0, 0.725, -0.43)), 0.006))
    brass_bail(P, (0, 0.73, -0.44), 0.07, -1.0)
    add(P, "DarkWood", box((0.70, 0.40, 0.02), (0, 0.555, 0.40)))
    # papers, a ledger, the inkstand
    for k, (x, z, a) in enumerate(((-0.25, 0.05, 8.0), (-0.20, 0.10, -14.0), (-0.32, -0.02, 22.0))):
        sh = box((0.21, 0.0015, 0.28), (0, 0.00075 + 0.0016 * k, 0))
        sh.rotate(O, Y, a)
        add(P, "Paper", moved(sh, (x, 0.812, z)), 2)
    lg = box((0.30, 0.05, 0.40), (0, 0.025, 0))
    lg.rotate(O, Y, -6.0)
    add(P, "Leather", moved(chamfer(lg, 0.004), (0.25, 0.812, 0.12)), 2)
    add(P, "Brass", chamfer(box((0.22, 0.012, 0.10), (-0.05, 0.818, -0.27)), 0.003), 2)
    for x in (-0.11, 0.01):
        add(P, "ClearGlass", chamfer(box((0.04, 0.04, 0.04), (x, 0.844, -0.27)), 0.004), 2)
        add(P, "Ebony", box((0.032, 0.026, 0.032), (x, 0.838, -0.27)), 2)
        add(P, "Brass", cyl(0.011, 0.01, (x, 0.869, -0.27)), 2)
    pen = cyl(0.004, 0.16, (0, 0, 0), "x")
    pen.rotate(O, Y, 8.0)
    add(P, "GunWood", moved(pen, (0.0, 0.83, -0.24)), 2)


def build_desk_lamp():
    """A table oil lamp (origin base centre): a stepped brass foot and stem, an amber glass font, burner, chimney and flame."""
    P = "desk_lamp"
    add(P, "Brass", revolve([(0.0, 0.0), (0.0, 0.065), (0.008, 0.066), (0.018, 0.055), (0.03, 0.03), (0.07, 0.022), (0.09, 0.03),
                             (0.10, 0.035), (0.10, 0.0)], "y"))
    add(P, "Bottle", revolve([(0.10, 0.0), (0.10, 0.035), (0.13, 0.062), (0.17, 0.066), (0.20, 0.05), (0.215, 0.026), (0.215, 0.0)], "y"))
    add(P, "Brass", revolve([(0.21, 0.0), (0.21, 0.028), (0.225, 0.028), (0.225, 0.0)], "y"))
    lamp_head(P, (0.0, 0.225, 0.0), 1, 0.20)


def build_desk_chair():
    """A captain's chair (seat top 0.46, the sitter faces +z): a saddle seat, four turned splayed legs with H-stretchers, a horseshoe
    arm rail on seven spindles and two turned arm posts, a thicker crest across the back."""
    P = "desk_chair"
    seat = box((0.46, 0.045, 0.42), (0, 0.4375, 0))
    add(P, "GunWood", fillet(seat, 0.018))
    leg = [(0.0, 0.0), (0.0, 0.016), (0.10, 0.019), (0.14, 0.024), (0.16, 0.018), (0.30, 0.022), (0.33, 0.017), (0.425, 0.019), (0.425, 0.0)]
    feet = {}
    for sx in (-1, 1):
        for sz in (-1, 1):
            foot = Vector(sx * 0.20, 0.0, sz * 0.185)                    # splayed: the foot out, the top under the seat corner
            axis = Vector(-sx * 0.03, 0.415, -sz * 0.035)
            add(P, "GunWood", turned(leg, foot, axis))
            feet[(sx, sz)] = foot + axis * (0.17 / 0.415)                # where the H-stretcher meets the leg
    for sx in (-1, 1):
        add(P, "GunWood", cyl_between(feet[(sx, 1)], feet[(sx, -1)], 0.011))
    add(P, "GunWood", cyl_between((feet[(-1, 1)] + feet[(-1, -1)]) * 0.5, (feet[(1, 1)] + feet[(1, -1)]) * 0.5, 0.011))
    # the arm rail: a horseshoe open to the front, round the back at 0.72
    c = Vector(0, 0.72, -0.02)
    add(P, "GunWood", arc_tube(c, X, -Z, 0.235, 0.019, 180.0))
    for sx in (-1, 1):
        add(P, "GunWood", cyl_between(c + Vector(sx * 0.235, 0, 0), c + Vector(sx * 0.225, -0.01, 0.20), 0.019))
        add(P, "GunWood", sphere(0.024, c + Vector(sx * 0.225, -0.01, 0.20)), 2)
        add(P, "GunWood", turned([(0.0, 0.0), (0.0, 0.014), (0.06, 0.018), (0.12, 0.013), (0.20, 0.016), (0.255, 0.013), (0.255, 0.0)],
                                 (sx * 0.215, 0.46, 0.17)))
    for k in range(7):
        a = math.radians(-60.0 + k * 20.0)
        p_top = c + Vector(0.235 * math.sin(a), 0, -0.235 * math.cos(a))
        p_bot = Vector(0.19 * math.sin(a), 0.46, -0.02 - 0.17 * math.cos(a))
        add(P, "GunWood", cone_between(p_bot, p_top + Vector(0, -0.01, 0), 0.0095, 0.008), 2)
    add(P, "GunWood", arc_tube(c + Vector(0, 0.04, 0), Vector(math.sin(math.radians(-50)), 0, -math.cos(math.radians(-50))), X, 0.225, 0.026, 100.0))


def build_stove():
    """Int_Stove's replacement: a cast-iron pot-belly stove (r 0.33, the old envelope) on four cabriole legs: base plate, ash pit with
    its door and draft wheel, the belly with a nickel foot rail, the feed door with two glowing mica windows and a coil handle, the
    upper drum and dome; the pipe rises in sections with a damper, turns in an elbow at 3 m and runs into the wall at local -x 0.86
    (the certificate office's left wall), through a thimble."""
    P = "stove"
    body = revolve([(0.14, 0.0), (0.14, 0.27), (0.165, 0.282), (0.185, 0.25), (0.19, 0.238), (0.30, 0.238), (0.33, 0.27), (0.42, 0.318),
                    (0.52, 0.334), (0.62, 0.318), (0.70, 0.27), (0.74, 0.25), (0.755, 0.292), (0.79, 0.292), (0.805, 0.24), (0.92, 0.23),
                    (0.945, 0.272), (0.98, 0.272), (1.0, 0.22), (1.035, 0.15), (1.045, 0.09), (1.045, 0.0)], "y")
    add(P, "Iron", body, 0)
    leg = prism_yz([(0.0, 0.17), (0.0, 0.30), (0.025, 0.31), (0.05, 0.29), (0.09, 0.24), (0.13, 0.21), (0.16, 0.20), (0.16, 0.17)], 0.045, -0.0225)
    for k in range(4):
        add(P, "Iron", rot_y(fillet(leg, 0.006), 45.0 + k * 90.0))
    add(P, "Nickel", arc_tube((0, 0.43, 0), X, Z, 0.40, 0.011, 360.0))
    for k in range(4):
        a = math.radians(k * 90.0)
        d = Vector(math.sin(a), 0, math.cos(a))
        add(P, "Nickel", cyl_between(Vector(0, 0.43, 0) + d * 0.32, Vector(0, 0.43, 0) + d * 0.395, 0.007), 2)
    add(P, "Nickel", arc_tube((0, 0.77, 0), X, Z, 0.30, 0.008, 360.0))
    # feed door (front, +z) with mica windows, hinges and a coil handle; ash door with its draft wheel
    door = box((0.22, 0.17, 0.035), (0, 0.55, 0.325))
    add(P, "Iron", chamfer(door, 0.008))
    for x in (-0.05, 0.05):
        add(P, "Glow", box((0.06, 0.07, 0.004), (x, 0.56, 0.3445)))
        add(P, "Iron", box((0.07, 0.008, 0.008), (x, 0.598, 0.346)), 2)
        add(P, "Iron", box((0.07, 0.008, 0.008), (x, 0.522, 0.346)), 2)
    for y in (0.50, 0.60):
        add(P, "Iron", cyl(0.012, 0.03, (-0.115, y, 0.33)), 2)
    add(P, "Nickel", cyl(0.01, 0.06, (0.13, 0.55, 0.36)), 2)
    add(P, "Nickel", sphere(0.016, (0.13, 0.585, 0.36)), 2)
    add(P, "Iron", chamfer(box((0.17, 0.07, 0.025), (0, 0.255, 0.245)), 0.006))
    add(P, "Iron", cyl(0.032, 0.012, (0, 0.255, 0.263), "z"), 2)
    for k in range(5):
        a = math.radians(k * 72.0)
        add(P, "Soot", box((0.008, 0.016, 0.002), (0.02 * math.sin(a), 0.255 + 0.02 * math.cos(a), 0.2695)), 2)
    # the pipe: sections + damper, the elbow, the run into the wall, the thimble
    add(P, "Iron", cyl(0.075, 1.86, (0, 1.04 + 0.93, 0)))
    for y in (1.62, 2.22, 2.82):
        add(P, "Iron", arc_tube((0, y, 0), X, Z, 0.0765, 0.004, 360.0), 2)
    add(P, "Iron", cyl(0.005, 0.20, (0, 1.40, 0), "x"), 2)
    add(P, "Iron", arc_tube((0.10, 1.40, 0), Y, Z, 0.014, 0.003, 360.0), 2)
    add(P, "Iron", arc_tube((-0.15, 2.90, 0), X, Y, 0.15, 0.075, 90.0))
    add(P, "Iron", cyl(0.075, 0.74, (-0.15 - 0.37, 3.05, 0), "x"))
    add(P, "Iron", revolve([(0.0, 0.08), (0.0, 0.12), (0.02, 0.12), (0.02, 0.08)], "x", (-0.86, 3.05, 0)))


def build_coffee_pot():
    """A blue enamel camp coffee pot (origin base centre): a tapered body, its lid and knob, a spout and a bent wire handle."""
    P = "coffee_pot"
    add(P, "Enamel", revolve([(0.0, 0.0), (0.0, 0.074), (0.008, 0.078), (0.15, 0.060), (0.165, 0.052), (0.17, 0.0)], "y"), 0)
    add(P, "Enamel", revolve([(0.168, 0.0), (0.168, 0.054), (0.178, 0.05), (0.19, 0.02), (0.20, 0.0)], "y"))
    add(P, "Enamel", sphere(0.012, (0, 0.205, 0)), 2)
    add(P, "Enamel", cone_between((0.0, 0.05, 0.065), (0.0, 0.16, 0.125), 0.016, 0.008))
    add(P, "Iron", arc_tube((0.0, 0.11, -0.064), Y, -Z, 0.05, 0.004, 180.0), 2)


def build_wood_box():
    """A plank box of split stove wood (origin base centre, 0.62 x 0.42): iron corner straps, quarter and half logs and a couple of
    rounds, one log leaning on the side."""
    P = "wood_box"
    L, D, H, T = 0.62, 0.42, 0.40, 0.02
    add(P, "Planks", box((L, T, D), (0, T / 2, 0)))
    for sz in (-1, 1):
        add(P, "Planks", chamfer(box((L, H, T), (0, H / 2, sz * (D / 2 - T / 2))), 0.003))
    for sx in (-1, 1):
        add(P, "Planks", chamfer(box((T, H, D - 2 * T), (sx * (L / 2 - T / 2), H / 2, 0)), 0.003))
        for sz in (-1, 1):
            add(P, "Iron", box((0.004, H - 0.04, 0.06), (sx * (L / 2 + 0.002), H / 2, sz * (D / 2 - 0.03))), 2)
    logs = [(0.0, 0.08, -0.10, 90.0, 0.07), (0.0, 0.08, 0.06, 180.0, 0.065), (0.0, 0.08, 0.15, 360.0, 0.05), (0.0, 0.20, -0.05, 90.0, 0.07),
            (0.0, 0.20, 0.10, 180.0, 0.06), (0.0, 0.31, 0.0, 90.0, 0.065), (0.0, 0.33, -0.13, 360.0, 0.045)]
    for i, (x, y, z, ang, r) in enumerate(logs):
        lg = Part.makeCylinder(r, 0.56, v(-0.28, 0, 0), X, ang)
        lg.rotate(O, X, hrand(i, 40) * 360.0)
        add(P, "Bark", moved(lg, (x + (hrand(i, 41) - 0.5) * 0.03, y, z)))
    lean = Part.makeCylinder(0.05, 0.6, O, Y, 180.0)
    lean.rotate(O, Z, 14.0)
    add(P, "Bark", moved(lean, (L / 2 + 0.07, 0.0, 0.05)))


def build_safe():
    """An office safe on castors (origin base centre, door +z): chamfered iron body, a recessed door with a raised panel and brass
    pin-striping, the combination dial on its plate, a T-handle, the keyhole, two hinge barrels and a brass name plate."""
    P = "safe"
    W, H, D = 0.70, 0.94, 0.65
    y0 = 0.06
    add(P, "Iron", chamfer(box((W, H, D), (0, y0 + H / 2, 0)), 0.02))
    for sx in (-1, 1):
        for sz in (-1, 1):
            add(P, "Iron", cyl(0.028, 0.025, (sx * 0.27, 0.029, sz * 0.24), "x"), 2)
            add(P, "Iron", box((0.04, 0.03, 0.04), (sx * 0.27, 0.05, sz * 0.24)), 2)
    door = box((0.58, 0.80, 0.03), (0, y0 + H / 2, D / 2 + 0.015))
    add(P, "Iron", chamfer(door, 0.012, front_edges(door, D / 2 + 0.03)))
    pan = box((0.46, 0.64, 0.015), (0, y0 + H / 2, D / 2 + 0.0375))
    add(P, "Iron", chamfer(pan, 0.01, front_edges(pan, D / 2 + 0.045)))
    zf = D / 2 + 0.046
    for (w, h, x, y) in ((0.40, 0.004, 0, y0 + H / 2 + 0.29), (0.40, 0.004, 0, y0 + H / 2 - 0.29), (0.004, 0.58, -0.20, y0 + H / 2),
                         (0.004, 0.58, 0.20, y0 + H / 2)):
        add(P, "Brass", box((w, h, 0.0015), (x, y, zf)), 2)
    add(P, "Brass", cyl(0.062, 0.006, (0, 0.70, zf + 0.003), "z"), 2)
    add(P, "Brass", cyl(0.046, 0.022, (0, 0.70, zf + 0.017), "z"))
    for k in range(30):
        a = math.radians(k * 12.0)
        add(P, "Brass", box((0.004, 0.006, 0.018), (0.047 * math.sin(a), 0.70 + 0.047 * math.cos(a), zf + 0.017)), 2)
    add(P, "Brass", cyl(0.016, 0.02, (0, 0.70, zf + 0.037), "z"), 2)
    add(P, "Brass", cyl(0.02, 0.03, (0, 0.50, zf + 0.015), "z"), 2)
    add(P, "Brass", chamfer(box((0.17, 0.026, 0.018), (0, 0.50, zf + 0.035)), 0.005))
    add(P, "Brass", chamfer(box((0.03, 0.045, 0.004), (0, 0.38, zf + 0.002)), 0.002), 2)
    add(P, "Soot", box((0.006, 0.018, 0.002), (0, 0.38, zf + 0.0045)), 2)
    for y in (0.27, 0.75):
        add(P, "Iron", cyl(0.018, 0.11, (-0.30, y, D / 2 + 0.03)))
    add(P, "Brass", box((0.22, 0.045, 0.003), (0, 0.89, D / 2 + 0.0315)), 2)                     # on the door frame


def build_bench():
    """A deacon's bench (origin base centre, 1.6 m, seat 0.45, the sitter faces +z): a walnut seat, four turned legs with stretchers, a
    spindle back under a top rail, turned back posts and arms."""
    P = "bench"
    L = 1.6
    seat = box((L, 0.04, 0.42), (0, 0.43, 0))
    add(P, "GunWood", fillet(seat, 0.012))
    leg = [(0.0, 0.0), (0.0, 0.018), (0.08, 0.021), (0.12, 0.026), (0.14, 0.019), (0.30, 0.022), (0.33, 0.018), (0.41, 0.02), (0.41, 0.0)]
    for sx in (-1, 1):
        for sz in (-1, 1):
            add(P, "GunWood", turned(leg, (sx * 0.72, 0.0, sz * 0.17)))
        add(P, "GunWood", cyl_between((sx * 0.72, 0.15, -0.17), (sx * 0.72, 0.15, 0.17), 0.011))
        post = [(0.0, 0.0), (0.0, 0.02), (0.10, 0.017), (0.13, 0.024), (0.16, 0.017), (0.40, 0.019), (0.44, 0.024), (0.48, 0.0)]
        add(P, "GunWood", turned(post, (sx * 0.77, 0.45, -0.19)))
        add(P, "GunWood", fillet(box((0.05, 0.035, 0.42), (sx * 0.77, 0.68, 0.0)), 0.01))
        add(P, "GunWood", turned([(0.0, 0.0), (0.0, 0.013), (0.07, 0.016), (0.12, 0.012), (0.215, 0.014), (0.215, 0.0)], (sx * 0.77, 0.45, 0.17)))
    for z in (-0.17, 0.17):
        add(P, "GunWood", cyl_between((-0.72, 0.13, z), (0.72, 0.13, z), 0.011))
    add(P, "GunWood", fillet(box((L + 0.04, 0.07, 0.05), (0, 0.93, -0.20)), 0.012))
    for k in range(15):
        x = -0.70 + k * 0.10
        add(P, "GunWood", cone_between((x, 0.45, -0.19), (x, 0.90, -0.20), 0.011, 0.008), 2)


# ====================================================================================================== the jail / the armory
def build_lantern():
    """A barn lantern (tubular, origin base centre): tin font, two side tubes, the glass globe in its wire guard, the cap and a bail."""
    P = "lantern"
    add(P, "Tin", revolve([(0.0, 0.0), (0.0, 0.065), (0.01, 0.07), (0.05, 0.07), (0.065, 0.06), (0.065, 0.0)], "y"))
    add(P, "LampGlass", revolve([(0.065, 0.045), (0.11, 0.068), (0.17, 0.068), (0.215, 0.045), (0.215, 0.042), (0.17, 0.065), (0.11, 0.065),
                                 (0.065, 0.042)], "y"))
    add(P, "Flame", revolve([(0.0, 0.0), (0.0, 0.007), (0.014, 0.009), (0.035, 0.004), (0.048, 0.0)], "y", (0, 0.085, 0)), 2)
    for k in range(4):
        a = math.radians(45.0 + k * 90.0)
        d = Vector(math.sin(a), 0, math.cos(a))
        pts = [Vector(0, 0.07, 0) + d * 0.05, Vector(0, 0.13, 0) + d * 0.077, Vector(0, 0.21, 0) + d * 0.05]
        add(P, "Tin", cyl_between(pts[0], pts[1], 0.0025), 2)
        add(P, "Tin", cyl_between(pts[1], pts[2], 0.0025), 2)
    for sx in (-1, 1):
        add(P, "Tin", cyl(0.008, 0.21, (sx * 0.085, 0.155, 0)))
        add(P, "Tin", cyl_between((sx * 0.085, 0.05, 0), (sx * 0.06, 0.05, 0), 0.008), 2)
        add(P, "Tin", cyl_between((sx * 0.085, 0.26, 0), (sx * 0.04, 0.245, 0), 0.008), 2)
    add(P, "Tin", revolve([(0.215, 0.0), (0.215, 0.055), (0.235, 0.06), (0.255, 0.04), (0.27, 0.02), (0.28, 0.0)], "y"))
    add(P, "Iron", arc_tube((0, 0.28, 0), X, Y, 0.075, 0.003, 180.0), 2)


def build_key_ring():
    """The jailer's keys (origin = the wall plate's back, +z out from the wall): a plate and hook, an iron ring and three skeleton keys."""
    P = "key_ring"
    add(P, "Iron", chamfer(box((0.05, 0.08, 0.008), (0, 0, 0.004)), 0.002))
    add(P, "Iron", cyl(0.005, 0.05, (0, 0.0, 0.033), "z"), 2)
    add(P, "Iron", arc_tube((0, 0.012, 0.058), -Y, Z, 0.012, 0.005, 180.0), 2)
    add(P, "Iron", arc_tube((0, -0.04, 0.06), Y, X, 0.05, 0.004, 360.0))
    for k, (a, ln) in enumerate(((-28.0, 0.085), (2.0, 0.10), (26.0, 0.075))):
        key = []
        key.append(arc_tube((0, -0.012, 0), Y, X, 0.012, 0.003, 360.0))
        key.append(cyl(0.0032, ln, (0, -0.024 - ln / 2, 0)))
        key.append(box((0.003, 0.014, 0.012), (0, -0.024 - ln + 0.012, 0.006)))
        for s in key:
            s.rotate(O, Z, a)
            s.translate(v(0.05 * math.sin(math.radians(a)), -0.04 - 0.05 * math.cos(math.radians(a)) + 0.012, 0.06))
            add(P, "Iron", s, 2)


def build_bucket():
    """A staved water bucket (origin base centre): twelve tapered staves, two iron hoops, an iron bail, water, a tin dipper across."""
    P = "bucket"
    n = 12
    for k in range(n):
        st = revolve([(0.0, 0.125), (0.0, 0.142), (0.26, 0.162), (0.26, 0.145)], "y", angle=360.0 / n - 1.2)
        st.rotate(O, Y, k * 360.0 / n)
        add(P, "Planks", st)
    add(P, "Planks", cyl(0.13, 0.02, (0, 0.02, 0)))
    for y, r in ((0.05, 0.1445), (0.21, 0.1575)):
        add(P, "Iron", revolve([(y - 0.012, r), (y - 0.012, r + 0.004), (y + 0.012, r + 0.004), (y + 0.012, r)], "y"))
    add(P, "Water", cyl(0.15, 0.004, (0, 0.20, 0)))
    bail = arc_tube((0, 0.24, 0), X, Y, 0.165, 0.004, 180.0)
    bail.rotate(v(0, 0.24, 0), X, -55.0)
    add(P, "Iron", bail)
    add(P, "Tin", revolve([(0.0, 0.0), (0.0, 0.045), (0.06, 0.05), (0.06, 0.047), (0.004, 0.042), (0.004, 0.0)], "y", (0.04, 0.235, 0.0)))
    add(P, "Tin", cyl_between((0.09, 0.29, 0.0), (0.33, 0.27, 0.0), 0.006))


def build_tin_plate():
    """The prisoner's supper (origin = the plate's centre on the floor): a tin plate with beans, a tin cup, a spoon."""
    P = "tin_plate"
    add(P, "Tin", revolve([(0.0, 0.0), (0.0, 0.07), (0.016, 0.105), (0.02, 0.11), (0.016, 0.104), (0.003, 0.068), (0.003, 0.0)], "y"))
    add(P, "Beans", revolve([(0.003, 0.0), (0.003, 0.055), (0.012, 0.035), (0.016, 0.0)], "y"), 2)
    add(P, "Tin", revolve([(0.0, 0.0), (0.0, 0.038), (0.08, 0.041), (0.08, 0.038), (0.004, 0.035), (0.004, 0.0)], "y", (0.17, 0.0, 0.06)))
    add(P, "Tin", arc_tube((0.215, 0.045, 0.06), Y, X, 0.022, 0.0035, 180.0), 2)
    sp = cyl(0.003, 0.14, (0, 0, 0), "x")
    sp.rotate(O, Y, 35.0)
    add(P, "Tin", moved(sp, (-0.02, 0.017, 0.0)), 2)
    add(P, "Tin", moved(box((0.03, 0.004, 0.02), (0.0, 0.0, 0.0)), (-0.075, 0.018, -0.04)), 2)


def build_broom():
    """A broom (origin = the bristles' bottom centre, the handle up +y): a turned handle and a flat straw head with two bindings."""
    P = "broom"
    add(P, "GunWood", cyl(0.013, 1.25, (0, 0.36 + 0.625, 0)))
    head = Part.makeCone(0.13, 0.025, 0.38, O, Y)
    m = FreeCAD.Matrix()
    m.scale(Vector(1.0, 1.0, 0.28))
    add(P, "Straw", head.transformGeometry(m))
    for y in (0.27, 0.32):
        b = cyl(0.133 - 0.105 * y / 0.38, 0.012, (0, y, 0))             # just proud of the straw
        add(P, "Rope", b.transformGeometry(m), 2)


def build_workbench():
    """A gunsmith's bench (origin base centre, 1.8 x 0.65, top 0.90): a thick top, square legs with stretchers and a shelf of
    planks, a bench vise holding a rifle barrel, a hammer, a file, a screwdriver, an oil can and a rag."""
    P = "workbench"
    add(P, "GunWood", chamfer(box((1.8, 0.07, 0.65), (0, 0.865, 0)), 0.006))
    for sx in (-1, 1):
        for sz in (-1, 1):
            add(P, "DarkWood", box((0.08, 0.83, 0.08), (sx * 0.82, 0.415, sz * 0.26)))
        add(P, "DarkWood", box((0.06, 0.08, 0.50), (sx * 0.82, 0.16, 0)))
    for sz in (-1, 1):
        add(P, "DarkWood", box((1.60, 0.10, 0.04), (0, 0.78, sz * 0.28)))
    add(P, "Planks", box((1.62, 0.025, 0.52), (0, 0.21, 0)))
    # the vise at the front right, a barrel in its jaws
    vx = 0.62
    add(P, "Iron", chamfer(box((0.16, 0.10, 0.20), (vx, 0.95, 0.24)), 0.008))
    add(P, "Iron", chamfer(box((0.17, 0.09, 0.04), (vx, 0.96, 0.37)), 0.006))
    add(P, "Iron", chamfer(box((0.17, 0.05, 0.03), (vx, 0.975, 0.335)), 0.004))
    add(P, "Iron", cyl(0.012, 0.18, (vx, 0.94, 0.42), "z"))
    add(P, "Iron", cyl(0.007, 0.20, (vx, 0.94, 0.505), "x"))
    for sx in (-1, 1):
        add(P, "Iron", sphere(0.012, (vx + sx * 0.10, 0.94, 0.505)), 2)
    add(P, "GunSteel", cyl(0.012, 0.66, (vx - 0.33 + 0.08, 0.99, 0.35), "x"))
    # tools
    add(P, "GunWood", cyl(0.012, 0.30, (-0.30, 0.912, 0.10), v(1, 0, 0.4)))
    add(P, "Iron", chamfer(box((0.035, 0.035, 0.11), (-0.44, 0.918, 0.05)), 0.004))
    fl = box((0.20, 0.006, 0.02), (0, 0, 0))
    fl.rotate(O, Y, -20.0)
    add(P, "GunSteel", moved(fl, (-0.05, 0.904, -0.05)), 2)
    add(P, "GunWood", moved(rot_y(cyl(0.01, 0.10, (0.15, 0, 0), "x"), -20.0), (-0.05, 0.91, -0.05)), 2)
    add(P, "GunSteel", cyl(0.004, 0.14, (0.10, 0.906, -0.18), v(1, 0, -0.3)), 2)
    add(P, "GunWood", cyl(0.012, 0.09, (0.20, 0.912, -0.21), v(1, 0, -0.3)), 2)
    add(P, "Tin", revolve([(0.0, 0.0), (0.0, 0.05), (0.03, 0.05), (0.06, 0.02), (0.07, 0.008), (0.07, 0.0)], "y", (-0.70, 0.90, -0.15)))
    add(P, "Tin", cone_between((-0.70, 0.96, -0.15), (-0.62, 1.05, -0.15), 0.008, 0.003), 2)
    rag = box((0.20, 0.012, 0.14), (0, 0, 0))
    rag.rotate(O, Y, 25.0)
    add(P, "Cloth", moved(fillet(rag, 0.005), (-0.42, 0.906, -0.18)), 2)


def build_gun_board():
    """A wall board for revolvers (origin = its back centre on the wall, +z out; 1.2 x 0.8): a moulded frame round a felt field and six
    pairs of brass pegs - two rows of three - that the game hangs Kit_Revolver copies on."""
    P = "gun_board"
    W, H = 1.2, 0.8
    add(P, "DarkWood", box((W, H, 0.025), (0, 0, 0.0125)))
    add(P, "Felt", box((W - 0.12, H - 0.12, 0.004), (0, 0, 0.027)))
    for y in (H / 2 - 0.03, -H / 2 + 0.03):
        add(P, "GunWood", chamfer(box((W, 0.06, 0.03), (0, y, 0.04)), 0.01))
    for x in (W / 2 - 0.03, -W / 2 + 0.03):
        add(P, "GunWood", chamfer(box((0.06, H - 0.12, 0.03), (x, 0, 0.04)), 0.01))
    for row in range(2):
        for col in range(3):
            cx, cy = -0.36 + col * 0.36, 0.17 - row * 0.34
            for dx in (-0.07, 0.06):
                add(P, "Brass", cyl(0.006, 0.05, (cx + dx, cy - 0.02, 0.054), "z"), 2)
                add(P, "Brass", sphere(0.009, (cx + dx, cy - 0.02, 0.08)), 2)


BUILDERS = [("bar", build_bar), ("back_bar", build_back_bar), ("table", build_table), ("chair", build_chair), ("poker_set", build_poker_set),
            ("table_drinks", build_table_drinks), ("piano", build_piano), ("piano_stool", build_piano_stool), ("spittoon", build_spittoon),
            ("hang_lamp", build_hang_lamp), ("chandelier", build_chandelier), ("clock", build_clock), ("clock_pendulum", build_clock_pendulum),
            ("hat_rack", build_hat_rack), ("counter", build_counter), ("pigeonholes", build_pigeonholes), ("desk", build_desk),
            ("desk_lamp", build_desk_lamp), ("desk_chair", build_desk_chair), ("stove", build_stove), ("coffee_pot", build_coffee_pot), ("wood_box", build_wood_box),
            ("safe", build_safe), ("bench", build_bench), ("lantern", build_lantern), ("key_ring", build_key_ring), ("bucket", build_bucket),
            ("tin_plate", build_tin_plate), ("broom", build_broom), ("workbench", build_workbench), ("gun_board", build_gun_board)]

failed = {}
for name, fn in BUILDERS:
    if wanted(name):
        try:
            fn()
        except Exception as ex:                       # report and carry on: one bad builder must not hide the rest
            failed[name] = repr(ex)
            for key in [k for k in GROUPS if k[0] == name]:
                del GROUPS[key]


def deflection(diag, lod):
    """Per-shape tessellation: furniture is seen from a metre or two; lod 2 (bottles, keys, chips, spindles) is coarser. OCC's mesher
    cuts a curve about twice as finely as the angle given (0.5 rad gave 25 segments round a torus), so 1.0 is ~12 segments round a
    leg or a rail and 1.5 is ~8 round a bottle."""
    if lod == 2:
        return max(0.003, diag * 0.02), 1.5
    if lod == 0:
        return max(0.0015, diag * 0.004), 0.5
    return max(0.0015, diag * 0.006), 1.0


DEBUG = os.environ.get("TOWN_CAD_DEBUG", "") == "1"         # print every shape's triangle count (to find what to coarsen)
report = {"groups": {}, "tris": 0, "pieces": {}, "failed": failed}
for (piece, mat), shapes in sorted(GROUPS.items()):
    mesh = Mesh.Mesh()
    for i, (shp, lod) in enumerate(shapes):
        lin, ang = deflection(max(shp.BoundBox.DiagonalLength, 1e-4), lod)
        part = MeshPart.meshFromShape(Shape=shp, LinearDeflection=lin, AngularDeflection=ang, Relative=False)
        if DEBUG:
            bb = shp.BoundBox
            print("@tri %s/%s #%d lod%d %d  bb %.3f %.3f %.3f" % (piece, mat, i, lod, part.CountFacets, bb.XLength, bb.YLength, bb.ZLength))
        mesh.addMesh(part)
    path = os.path.join(OUT, "%s__%s.obj" % (piece, mat))
    mesh.write(path)
    report["groups"]["%s/%s" % (piece, mat)] = mesh.CountFacets
    report["pieces"][piece] = report["pieces"].get(piece, 0) + mesh.CountFacets
    report["tris"] += mesh.CountFacets
json.dump(report, open(os.path.join(OUT, "town_interior_cad.json"), "w"), indent=1)
print("@@" + json.dumps({"ok": not failed, "tris": report["tris"], "pieces": report["pieces"], "failed": failed}))
