"""THE SMELTER'S PROP KIT, IN CAD (founder 2026-10-25: "Inferno hideout smelting facility - hyperreal props, furnace, kegs, tools,
surfaces - not grey primitives"; "weapons in facility ... hyperreal; match founder Winchester / revolver quality bar").

Run with FreeCAD's headless interpreter (FreeCAD 1.1.4: ~/tools/freecad/squashfs-root, `freecadcmd` on PATH):

    SMELTER_CAD_OUT=<out_dir> freecadcmd tools/ep2_cad/smelter_kit_cad.py

Real solids at REAL size (the hideout scales each instance to Inferno Bull's 2.9 m world): a Colt Single Action Army (fluted cylinder
with its six chambers, ejector housing, case-hardened frame, hammer spur, trigger guard, one-piece walnut grip), oak kegs (sixteen bulged
staves with real seams, four iron hoops, a recessed head of three boards and a bung), a London-pattern anvil on an oak stump, smith's
tongs, a pouring ladle, a three-bar ingot mould, a coal shovel with its D-grip, an octagonal sledge, a pick, an oval chain link and a
hook, a .45-70 cartridge, a planked crate with iron corner plates and an open ammunition box. Each (piece, material) group is tessellated
to one OBJ in <out_dir> plus smelter_kit_cad.json (triangle counts); tools/ep2_blender/build_smelter_kit.py assembles one node per piece.

Coordinates are the GAME's (y up). Each piece stands on its own origin (base centre) unless noted: the revolver's origin is on its bore
axis at the cylinder's front face with the barrel along +z (the same frame as the hideout's old code-built revolver); the chain link is
centred, long axis along y; the tongs, ladle, shovel, sledge and pick lie along +z from their working end.
"""
import json
import math
import os

import FreeCAD  # noqa: F401  (freecadcmd)
import Mesh
import MeshPart
import Part
from FreeCAD import Vector

OUT = os.environ.get("SMELTER_CAD_OUT", os.path.abspath("smelter_cad_out"))      # (freecadcmd treats unknown --flags as its own)
os.makedirs(OUT, exist_ok=True)

X = Vector(1, 0, 0)
Y = Vector(0, 1, 0)
Z = Vector(0, 0, 1)
O = Vector(0, 0, 0)

GROUPS = {}          # (piece, material) -> [shapes]


def add(piece, mat, shape):
    GROUPS.setdefault((piece, mat), []).append(shape)


def v(x, y, z):
    return Vector(x, y, z)


def axis_vec(a):
    return {"x": X, "y": Y, "z": Z}[a]


def cyl(r, length, centre, axis="y"):
    d = axis_vec(axis)
    return Part.makeCylinder(r, length, Vector(centre) - d * (length / 2.0), d)


def cone(r0, r1, length, centre, axis="y"):
    d = axis_vec(axis)
    return Part.makeCone(r0, r1, length, Vector(centre) - d * (length / 2.0), d)


def box(size, centre):
    sx, sy, sz = size
    return Part.makeBox(sx, sy, sz, Vector(centre) - Vector(sx / 2.0, sy / 2.0, sz / 2.0))


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
    """A closed (y, z) outline extruded `depth` along +x from x0 (side profiles of a gun, a tool head)."""
    pts = [v(x0, y, z) for y, z in points]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).extrude(v(depth, 0, 0))


def prism_xz(points, depth, y0=0.0):
    pts = [v(x, y0, z) for x, z in points]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).extrude(v(0, depth, 0))


def dome(r, centre, normal):
    s = Part.makeSphere(r, O, Z, 0, 90, 360)
    m = FreeCAD.Matrix()
    m.scale(Vector(1.0, 1.0, 0.45))
    s = s.transformGeometry(m)
    s.Placement = FreeCAD.Placement(Vector(centre), FreeCAD.Rotation(Z, Vector(normal)))
    return s


# ====================================================================================================== Colt Single Action Army
def build_revolver():
    P = "revolver"
    # barrel: 7.5 in, slightly tapered, a real bore, a crowned muzzle, the front sight blade
    barrel = revolve([(0.0, 0.0), (0.0, 0.0090), (0.004, 0.0090), (0.186, 0.0078), (0.190, 0.0074), (0.190, 0.0)], "z")
    barrel = barrel.cut(cyl(0.00575, 0.06, (0, 0, 0.17), "z"))
    add(P, "GunSteel", barrel)
    add(P, "GunSteel", chamfer(prism_yz([(0.0074, 0.170), (0.0118, 0.176), (0.0118, 0.186), (0.0074, 0.188)], 0.0028, -0.0014), 0.0006))
    # ejector rod housing on the right of the barrel, its rod knob, the housing screw
    eh = cyl(0.0052, 0.118, (0.0102, -0.0058, 0.061), "z").fuse(box((0.006, 0.006, 0.118), (0.0062, -0.0042, 0.061))).removeSplitter()
    add(P, "GunSteel", eh)
    add(P, "GunSteel", cyl(0.0042, 0.008, (0.0102, -0.0058, 0.124), "z"))
    add(P, "GunSteel", dome(0.0026, (0.0154, -0.0058, 0.012), X))
    # cylinder: 6 chambers, 6 flutes between them, a chamfered front edge, the bolt notches
    cylr = 0.0212
    cylinder = cyl(cylr, 0.041, (0, -0.0005, -0.0215), "z")
    cylinder = chamfer(cylinder, 0.0015, [e for e in cylinder.Edges if hasattr(e.Curve, "Radius") and abs(e.Curve.Radius - cylr) < 1e-4])
    for k in range(6):
        a = k * math.pi / 3
        cylinder = cylinder.cut(cyl(0.0060, 0.05, (0.0133 * math.sin(a), -0.0005 + 0.0133 * math.cos(a), -0.0215), "z"))
        fa = a + math.pi / 6
        flute = cyl(0.0048, 0.024, ((cylr + 0.0014) * math.sin(fa), -0.0005 + (cylr + 0.0014) * math.cos(fa), -0.0175), "z")
        cylinder = cylinder.cut(flute)
    add(P, "GunSteel", cylinder)
    # frame (case hardened): top strap, recoil shield, the lower frame under the cylinder, the frame round the barrel threads
    frame = box((0.0175, 0.0070, 0.060), (0, 0.0235, -0.022))                                  # top strap
    frame = frame.fuse(box((0.0280, 0.0560, 0.0085), (0, -0.0060, -0.0465)))                   # recoil shield (behind the cylinder)
    frame = frame.fuse(box((0.0200, 0.0110, 0.052), (0, -0.0255, -0.022)))                     # lower frame
    frame = frame.fuse(cyl(0.0122, 0.012, (0, 0, 0.004), "z"))                                  # barrel shank
    frame = frame.fuse(box((0.0200, 0.0300, 0.012), (0, -0.0100, 0.004)))
    frame = frame.fuse(cyl(0.0028, 0.020, (0, -0.0005, 0.0), "x"))                             # base pin head
    frame = chamfer(frame.removeSplitter(), 0.0012)
    frame = frame.cut(box((0.004, 0.003, 0.050), (0, 0.0270, -0.025)))                          # the rear-sight groove in the top strap
    add(P, "CaseHard", frame)
    # the loading gate on the right of the recoil shield
    add(P, "CaseHard", chamfer(box((0.004, 0.016, 0.012), (0.0145, -0.0025, -0.044)), 0.0008))
    # the rear of the frame behind the recoil shield: the hammer slot and the top of the grip frame
    add(P, "CaseHard", chamfer(box((0.0170, 0.050, 0.012), (0, -0.007, -0.0565)), 0.0012))
    # Side profiles below are (y, z) outlines: y up from the bore axis, z forward (the barrel is +z, the butt is down and back).
    # hammer at rest: the body in its slot, the spur just proud of the top strap and curling back, its knurled top as ridges
    hammer = prism_yz([(0.016, -0.0505), (0.024, -0.0535), (0.0300, -0.0595), (0.0315, -0.0655), (0.0285, -0.0690), (0.0225, -0.0650),
                       (0.0160, -0.0610), (0.0040, -0.0600), (0.0040, -0.0505)], 0.0072, -0.0036)
    add(P, "CaseHard", chamfer(hammer, 0.0007))
    for k in range(5):
        add(P, "CaseHard", box((0.0074, 0.0010, 0.0014), (0, 0.0312 - k * 0.0011, -0.0605 - k * 0.0016)))
    # the trigger guard: a closed loop under the frame, open to the trigger at the top
    guard_out = [(-0.0290, -0.0080), (-0.0400, -0.0100), (-0.0500, -0.0160), (-0.0550, -0.0260), (-0.0540, -0.0360),
                 (-0.0480, -0.0440), (-0.0400, -0.0470), (-0.0300, -0.0465)]
    guard_in = [(-0.0280, -0.0130), (-0.0395, -0.0150), (-0.0470, -0.0200), (-0.0500, -0.0270), (-0.0490, -0.0345),
                (-0.0440, -0.0400), (-0.0375, -0.0420), (-0.0280, -0.0415)]
    guard = prism_yz(guard_out, 0.0080, -0.0040).cut(prism_yz(guard_in, 0.0120, -0.0060))
    add(P, "GunSteel", chamfer(guard, 0.0008))
    # the trigger: a curved blade from the frame into the guard
    add(P, "GunSteel", prism_yz([(-0.0300, -0.0235), (-0.0360, -0.0250), (-0.0425, -0.0285), (-0.0458, -0.0330), (-0.0440, -0.0342),
                                 (-0.0385, -0.0305), (-0.0310, -0.0285)], 0.0040, -0.0020))
    # the one-piece walnut grip: the plow-handle outline (narrow at the frame, swelling to the butt, the back curving round), rounded
    grip_front = [(-0.0300, -0.0465), (-0.0450, -0.0500), (-0.0650, -0.0560), (-0.0850, -0.0625), (-0.1030, -0.0690), (-0.1150, -0.0745)]
    grip_butt = [(-0.1200, -0.0810), (-0.1215, -0.0920), (-0.1180, -0.1025)]
    grip_back = [(-0.1050, -0.1060), (-0.0850, -0.1000), (-0.0620, -0.0890), (-0.0420, -0.0770), (-0.0270, -0.0670), (-0.0160, -0.0615)]
    grip_top = [(-0.0160, -0.0560), (-0.0250, -0.0500)]
    grip = prism_yz(grip_front + grip_butt + grip_back + grip_top, 0.0310, -0.0155)
    grip = fillet(grip, 0.0060, [e for e in grip.Edges if abs(e.tangentAt(e.FirstParameter).dot(X)) < 0.2])
    add(P, "GunWood", grip)
    # the backstrap: a steel band along the grip's back, from the hammer down round the butt
    strap_in = grip_back[::-1] + [(-0.1180, -0.1025)]
    strap_out = [(y + 0.0010, z - 0.0040) for y, z in strap_in]
    strap_out[-1] = (-0.1220, -0.1050)
    add(P, "GunSteel", chamfer(prism_yz(strap_in + strap_out[::-1], 0.0150, -0.0075), 0.0010))
    for sx in (-1, 1):
        add(P, "GunSteel", dome(0.0022, (sx * 0.0157, -0.074, -0.077), v(sx, 0, 0)))                # grip screw escutcheons


# ============================================================================================================== the oak keg
def keg_r(y, h, r_head, r_bilge):
    t = (y - h / 2.0) / (h / 2.0)
    return r_head + (r_bilge - r_head) * (1.0 - t * t)


def build_keg(P, h, r_head, r_bilge, staves=16):
    thick = 0.016
    n = 12
    ys = [h * k / n for k in range(n + 1)]
    outer = [(y, keg_r(y, h, r_head, r_bilge)) for y in ys]
    inner = [(y, keg_r(y, h, r_head, r_bilge) - thick) for y in reversed(ys)]
    sector = 360.0 / staves
    gap = 0.55
    for k in range(staves):
        st = revolve(outer + inner, "y", (0, 0, 0), sector - gap)
        st.rotate(O, Y, k * sector + gap * 0.5)
        add(P, "Trim", st)
    # heads: recessed below the chime, three boards with seams, a bung in the middle board
    chime = 0.028
    for yh in (chime, h - chime):
        rr = keg_r(yh, h, r_head, r_bilge) - thick + 0.002
        disc = cyl(rr, 0.016, (0, yh, 0), "y")
        for j, (z0, z1) in enumerate(((-rr, -rr / 3.0 - 0.0015), (-rr / 3.0 + 0.0015, rr / 3.0 - 0.0015), (rr / 3.0 + 0.0015, rr))):
            board = disc.common(box((2 * rr + 0.01, 0.02, z1 - z0), (0, yh, (z0 + z1) / 2.0)))
            add(P, "Planks", board)
        if yh > h / 2:
            add(P, "DarkWood", cyl(0.016, 0.012, (0.0, yh + 0.012, 0.0), "y"))                         # bung
    # hoops: two near each chime, a quarter hoop each side of the bilge
    for yc in (0.045, 0.11, h - 0.11, h - 0.045):
        w = 0.034
        prof = []
        for k in range(5):
            y = yc - w / 2 + w * k / 4
            prof.append((y, keg_r(y, h, r_head, r_bilge) + 0.0035))
        for k in range(4, -1, -1):
            y = yc - w / 2 + w * k / 4
            prof.append((y, keg_r(y, h, r_head, r_bilge) - 0.0005))
        add(P, "Iron", revolve(prof, "y"))
        for k in range(3):                                                                              # rivets
            a = k * 2 * math.pi / 3 + 0.4
            rr = keg_r(yc, h, r_head, r_bilge) + 0.0035
            add(P, "Iron", dome(0.004, (rr * math.cos(a), yc, rr * math.sin(a)), v(math.cos(a), 0, math.sin(a))))
    # the side bung on the bilge stave
    rb = keg_r(h / 2.0, h, r_head, r_bilge)
    add(P, "DarkWood", cyl(0.014, 0.02, (rb + 0.002, h / 2.0, 0.0), "x"))


def build_chock():
    """A wedge chock (two per lying keg): a sawn oak block with a curved cradle cut."""
    P = "chock"
    b = box((0.10, 0.09, 0.34), (0, 0.045, 0))
    b = b.cut(cyl(0.245, 0.2, (0, 0.30, 0), "x"))
    add(P, "Trim", chamfer(b, 0.006))


# ============================================================================================================= anvil on stump
def build_anvil():
    P = "anvil"
    stump_h = 0.50
    stump = cyl(0.21, stump_h, (0, stump_h / 2.0, 0), "y")
    add(P, "DarkWood", chamfer(stump, 0.012))
    for k in range(3):                                                                                # iron bands round the stump
        add(P, "Iron", revolve([(0.05 + k * 0.19, 0.2095), (0.05 + k * 0.19, 0.2135), (0.078 + k * 0.19, 0.2135),
                                (0.078 + k * 0.19, 0.2095)], "y"))
    y0 = stump_h
    feet = chamfer(box((0.30, 0.045, 0.20), (0, y0 + 0.0225, 0)), 0.012)
    # the waist: a loft from the feet to the body (narrower in the middle)
    def rect(w, d, y):
        return Part.makePolygon([v(-w / 2, y, -d / 2), v(w / 2, y, -d / 2), v(w / 2, y, d / 2), v(-w / 2, y, d / 2), v(-w / 2, y, -d / 2)])
    waist = Part.makeLoft([rect(0.26, 0.17, y0 + 0.045), rect(0.17, 0.10, y0 + 0.12), rect(0.22, 0.105, y0 + 0.165)], True)
    body = chamfer(box((0.36, 0.075, 0.108), (0.0, y0 + 0.2025, 0)), 0.006)
    # horn: a cone from the body's front, its top kept a little under the face
    horn = Part.makeCone(0.050, 0.006, 0.21, v(0.18, y0 + 0.200, 0), X)
    horn = horn.cut(box((0.3, 0.05, 0.2), (0.33, y0 + 0.2475, 0)))
    heel = chamfer(box((0.09, 0.055, 0.09), (-0.225, y0 + 0.2125, 0)), 0.006)
    anvil = feet.fuse(waist).fuse(body).fuse(horn).fuse(heel).removeSplitter()
    anvil = anvil.cut(box((0.024, 0.2, 0.024), (-0.235, y0 + 0.2, 0)))                                 # hardy hole
    anvil = anvil.cut(cyl(0.0075, 0.2, (-0.19, y0 + 0.2, 0), "y"))                                    # pritchel hole
    add(P, "Iron", anvil)
    # the face plate: a steel top a shade brighter (worn bright by the hammer)
    add(P, "GunSteel", chamfer(box((0.30, 0.008, 0.105), (0.005, y0 + 0.2445, 0)), 0.003))


# ============================================================================================================== smith's tongs
def build_tongs():
    P = "tongs"
    halves = []
    for s in (-1, 1):
        rein = cyl(0.0065, 0.40, (0, 0.0, -0.22), "z")
        rein.rotate(v(0, 0, -0.02), Y, s * 2.2)
        boss = cyl(0.020, 0.010, (0, s * 0.005, 0.0), "y")
        jaw = prism_xz([(0.0, 0.00), (s * 0.010, 0.03), (s * 0.016, 0.085), (s * 0.008, 0.10), (s * 0.002, 0.09), (-s * 0.004, 0.02)],
                       0.010, s * 0.005 - 0.005)
        half = rein.fuse(boss).fuse(jaw).removeSplitter()
        halves.append(half)
        add(P, "Iron", half)
    add(P, "Iron", cyl(0.0055, 0.026, (0, 0, 0), "y"))                                               # the rivet
    add(P, "Iron", dome(0.007, (0, 0.013, 0), Y))
    add(P, "Iron", dome(0.007, (0, -0.013, 0), v(0, -1, 0)))


# ================================================================================================================ pouring ladle
def build_ladle():
    P = "ladle"
    shell = Part.makeSphere(0.085, v(0, 0.085, 0), Z, -90, 0, 360)            # lower hemisphere: a bowl whose rim is at y 0.085
    inner = Part.makeSphere(0.078, v(0, 0.085, 0), Z, -90, 0, 360)
    bowl = shell.cut(inner)
    bowl = bowl.fuse(revolve([(0.080, 0.085), (0.080, 0.092), (0.088, 0.092), (0.088, 0.085)], "y")).removeSplitter()   # rolled rim
    lip = prism_xz([(0.07, -0.025), (0.12, -0.012), (0.12, 0.012), (0.07, 0.025)], 0.006, 0.083)        # the pouring lip
    add(P, "Iron", bowl.fuse(lip).removeSplitter())
    # the handle: a forged bar welded to the bowl, a wooden grip with an iron ferrule, a T-bar to steady the pour
    bar = cyl(0.0085, 0.74, (-0.085 - 0.37, 0.07, 0), "x")
    add(P, "Iron", bar)
    add(P, "Iron", chamfer(box((0.03, 0.02, 0.03), (-0.085, 0.07, 0)), 0.004))
    add(P, "GunWood", revolve([(-0.80, 0.0), (-0.80, 0.017), (-0.83, 0.019), (-0.98, 0.019), (-1.0, 0.016), (-1.0, 0.0)], "x", (0, 0.07, 0)))
    add(P, "Iron", cyl(0.0205, 0.018, (-0.80, 0.07, 0), "x"))
    add(P, "Iron", cyl(0.0075, 0.20, (-0.52, 0.07, 0), "z"))


# ================================================================================================================= ingot mould
def build_mould():
    P = "mould"
    block = chamfer(box((0.42, 0.07, 0.16), (0, 0.035, 0)), 0.006)
    def rect(w, d, y, x):
        return Part.makePolygon([v(x - w / 2, y, -d / 2), v(x + w / 2, y, -d / 2), v(x + w / 2, y, d / 2), v(x - w / 2, y, d / 2), v(x - w / 2, y, -d / 2)])
    for x in (-0.13, 0.0, 0.13):
        cav = Part.makeLoft([rect(0.084, 0.044, 0.032, x), rect(0.106, 0.056, 0.0705, x)], True)
        block = block.cut(cav)
    for sx in (-1, 1):                                                                                    # cast lug handles
        lug = cyl(0.016, 0.05, (sx * 0.225, 0.045, 0), "x").cut(cyl(0.008, 0.06, (sx * 0.232, 0.045, 0), "z"))
        block = block.fuse(lug)
    add(P, "Iron", block.removeSplitter())


# ======================================================================================================== shovel, sledge, pick
def build_shovel():
    P = "shovel"
    # blade along +z from the socket: a flat pan with turned-up sides and back, the cutting edge rounded at the corners
    pan = fillet(box((0.26, 0.003, 0.30), (0, 0.0015, 0.17)), 0.0, [])
    pan = chamfer(pan, 0.0008)
    sides = []
    for sx in (-1, 1):
        s = prism_yz([(0.0, 0.02), (0.0, 0.32), (0.006, 0.32), (0.050, 0.05), (0.050, 0.02)], 0.003, sx * 0.1315 - 0.0015)
        sides.append(s)
    back = box((0.26, 0.05, 0.003), (0, 0.025, 0.0215))
    blade = pan.fuse(sides[0]).fuse(sides[1]).fuse(back).removeSplitter()
    add(P, "Iron", blade)
    add(P, "Iron", cone(0.022, 0.017, 0.10, (0, 0.02, -0.03), "z"))                                      # the socket (frog)
    add(P, "Iron", chamfer(box((0.05, 0.006, 0.08), (0, 0.006, 0.03)), 0.001))                            # frog strap on the pan
    add(P, "Trim", cyl(0.017, 0.72, (0, 0.02, -0.08 - 0.36), "z"))                                       # ash shaft
    # the D-grip: two cheeks and a turned crossbar
    for sx in (-1, 1):
        ch = cyl(0.008, 0.13, (sx * 0.028, 0.02, -0.86), "z")
        ch.rotate(v(0, 0.02, -0.80), Y, sx * 14.0)
        add(P, "Trim", ch)
    add(P, "Trim", revolve([(-0.05, 0.0), (-0.05, 0.013), (-0.03, 0.016), (0.03, 0.016), (0.05, 0.013), (0.05, 0.0)], "x", (0, 0.02, -0.93)))
    add(P, "Iron", cyl(0.019, 0.03, (0, 0.02, -0.80), "z"))                                              # ferrule


def build_sledge():
    P = "sledge"
    # octagonal double-face head across the shaft (along x), its faces chamfered, the eye with the shaft through it
    r = 0.040
    pts = [v(-0.105, r * math.cos(k * math.pi / 4 + math.pi / 8), r * math.sin(k * math.pi / 4 + math.pi / 8)) for k in range(8)]
    pts.append(pts[0])
    head = Part.Face(Part.makePolygon(pts)).extrude(v(0.21, 0, 0))
    head = chamfer(head, 0.007, [e for e in head.Edges if abs(e.tangentAt(e.FirstParameter).dot(X)) < 0.1])
    head = head.cut(box((0.026, 0.2, 0.040), (0, 0, 0)))
    head.translate(v(0, 0, 0.04))
    add(P, "Iron", head)
    add(P, "Trim", revolve([(0.075, 0.0), (0.075, 0.0125), (0.02, 0.0125), (-0.60, 0.0150), (-0.80, 0.0170), (-0.85, 0.0160),
                            (-0.86, 0.0), ], "z"))
    add(P, "DarkWood", box((0.022, 0.008, 0.036), (0, 0.0, 0.08)))                                       # the wedge in the eye


def build_pick():
    P = "pick"
    # a curved head: two tapering arms from the eye, a point one side and a chisel the other
    arms = []
    for sx in (-1, 1):
        pts = []
        for k in range(9):
            t = k / 8.0
            x = sx * (0.02 + 0.26 * t)
            y = -0.06 * t * t
            pts.append((x, y))
        segs = []
        for k in range(8):
            (x0, y0), (x1, y1) = pts[k], pts[k + 1]
            r0 = 0.020 * (1.0 - 0.75 * k / 8.0)
            r1 = 0.020 * (1.0 - 0.75 * (k + 1) / 8.0)
            d = v(x1 - x0, y1 - y0, 0)
            seg = Part.makeCone(r0, max(r1, 0.0035), d.Length, v(x0, y0, 0), d)
            segs.append(seg)
        arm = segs[0]
        for s in segs[1:]:
            arm = arm.fuse(s)
        arms.append(arm.removeSplitter())
    head = arms[0].fuse(arms[1]).fuse(cyl(0.028, 0.06, (0, 0, 0), "z")).removeSplitter()
    head = head.cut(cyl(0.016, 0.1, (0, 0, 0), "z"))
    head.translate(v(0, 0.0, 0.03))
    add(P, "Iron", head)
    add(P, "Trim", revolve([(0.065, 0.0), (0.065, 0.016), (0.0, 0.016), (-0.75, 0.0175), (-0.80, 0.0165), (-0.81, 0.0)], "z"))


# ================================================================================================================ chain + hook
def build_chain():
    P = "chain_link"
    # an oval link: two half tori joined by two straight sides; long axis along y (pitch = inner length 0.050)
    wire_r = 0.0062
    half_w = 0.0185
    straight = 0.030
    top = Part.makeTorus(half_w, wire_r, v(0, straight / 2, 0), Z, 0, 360, 180)
    bot = Part.makeTorus(half_w, wire_r, v(0, -straight / 2, 0), Z, 0, 360, 180)
    bot.rotate(v(0, -straight / 2, 0), Z, 180)
    sides = [cyl(wire_r, straight, (sx * half_w, 0, 0), "y") for sx in (-1, 1)]
    link = top.fuse(bot).fuse(sides[0]).fuse(sides[1]).removeSplitter()
    add(P, "Iron", link)
    H = "hook"
    shank = cyl(0.009, 0.08, (0, -0.04, 0), "y")
    eye = Part.makeTorus(0.016, 0.006, v(0, 0.012, 0), Z)
    bend = Part.makeTorus(0.034, 0.009, v(0.034, -0.08, 0), Z, 0, 360, 180)
    bend.rotate(v(0.034, -0.08, 0), Z, 180)
    tip = cone(0.009, 0.002, 0.05, (0.068, -0.055, 0), "y")
    add(H, "Iron", shank.fuse(eye).fuse(bend).fuse(tip).removeSplitter())


# =========================================================================================================== cartridge, crate, box
def cartridge_shapes(base=(0, 0, 0), axis_rot=None):
    """A .45-70: a rimmed brass case (straight taper) and a round-nosed lead bullet; origin at the base."""
    bx, by, bz = base
    case = revolve([(0.0, 0.0), (0.0, 0.0077), (0.0016, 0.0077), (0.0016, 0.0064), (0.053, 0.0061), (0.053, 0.0)], "y", (bx, by, bz))
    nose = [(0.053, 0.0), (0.053, 0.0058), (0.065, 0.0058)]
    for k in (1, 2, 3):
        a = k * (math.pi / 2) / 3.5
        nose.append((0.065 + 0.012 * math.sin(a), 0.0058 * math.cos(a)))
    nose.append((0.077, 0.0))
    bullet = revolve(nose, "y", (bx, by, bz))
    return case, bullet


def build_cartridge():
    c, b = cartridge_shapes()
    add("cartridge", "Brass", c)
    add("cartridge", "Lead", b)


def build_crate():
    P = "crate"
    s = 1.0
    t = 0.022
    pw = (s - 3 * 0.005) / 4.0
    for face in range(6):
        for j in range(4):
            off = -s / 2 + pw / 2 + j * (pw + 0.005)
            if face < 2:                                     # +-z sides: horizontal planks
                b = box((s - 0.002, pw, t), (0, s / 2 + off, (s / 2 - t / 2) * (1 if face == 0 else -1)))
            elif face < 4:                                   # +-x sides
                b = box((t, pw, s - 2 * t), ((s / 2 - t / 2) * (1 if face == 2 else -1), s / 2 + off, 0))
            elif face == 4:                                  # lid
                b = box((s - 2 * t, t, pw), (0, s - t / 2, off))
            else:                                            # floor
                b = box((s - 2 * t, t, pw), (0, t / 2, off))
            add(P, "Planks", chamfer(b, 0.002))
    # battens round every edge of the four sides, a diagonal brace on the two broad faces
    bt = 0.060
    for sz in (-1, 1):
        for yy in (bt / 2 + 0.004, s - bt / 2 - 0.004):
            add(P, "Trim", chamfer(box((s + 0.004, bt, 0.016), (0, yy, sz * (s / 2 + 0.008))), 0.003))
        for xx in (-1, 1):
            add(P, "Trim", chamfer(box((bt, s - 2 * bt, 0.016), (xx * (s / 2 - bt / 2), s / 2, sz * (s / 2 + 0.008))), 0.003))
        brace = chamfer(box((s * 1.18, 0.07, 0.014), (0, 0, 0)), 0.003)
        brace.rotate(O, Z, 41.0 * sz)
        brace = brace.common(box((s - 2 * bt, s - 2 * bt, 0.05), (0, 0, 0)))
        brace.translate(v(0, s / 2, sz * (s / 2 + 0.017)))
        add(P, "Trim", brace)
    # iron corner plates (L-shaped, both faces) with domed bolt heads
    for cx in (-1, 1):
        for cz in (-1, 1):
            for cy in (0.06, s - 0.06):
                add(P, "Iron", box((0.004, 0.12, 0.10), (cx * (s / 2 + 0.018), cy, cz * (s / 2 - 0.05))))
                add(P, "Iron", box((0.10, 0.12, 0.004), (cx * (s / 2 - 0.05), cy, cz * (s / 2 + 0.018))))
                for dy in (-0.035, 0.035):
                    add(P, "Iron", dome(0.0075, (cx * (s / 2 + 0.020), cy + dy, cz * (s / 2 - 0.05)), v(cx, 0, 0)))
                    add(P, "Iron", dome(0.0075, (cx * (s / 2 - 0.05), cy + dy, cz * (s / 2 + 0.020)), v(0, 0, cz)))


def build_ammo_box():
    P = "ammo_box"
    w, h, t = 0.30, 0.12, 0.012
    add(P, "Planks", chamfer(box((w, t, w), (0, t / 2, 0)), 0.002))
    for sz in (-1, 1):
        add(P, "Planks", chamfer(box((w, h, t), (0, h / 2, sz * (w / 2 - t / 2))), 0.002))
        add(P, "Planks", chamfer(box((t, h, w - 2 * t), (sz * (w / 2 - t / 2), h / 2, 0)), 0.002))
    for sz in (-1, 1):                                                                                    # rope handles
        add(P, "Rope", Part.makeTorus(0.028, 0.004, v(sz * (w / 2 + 0.004), h * 0.62, 0), X))
    # packed rounds standing in rows (5 x 5), two lying spilled over the near rim
    for ix in range(5):
        for iz in range(5):
            c, b = cartridge_shapes((-0.104 + ix * 0.052, t, -0.104 + iz * 0.052))
            add(P, "Brass", c)
            add(P, "Lead", b)
    for k, (x, rot) in enumerate(((-0.05, 12.0), (0.06, -20.0))):
        c, b = cartridge_shapes((0, 0, 0))
        for shp, mat in ((c, "Brass"), (b, "Lead")):
            shp.rotate(O, X, 90.0)
            shp.rotate(O, Y, rot)
            shp.translate(v(x, 0.0078, -w / 2 - 0.05))
            add(P, mat, shp)


# ====================================================================================================== the furnace front
# (founder 2026-10-25: "Inferno hideout smelting facility - hyperreal props, FURNACE ..."). Built in the furnace stonework's own frame
# (HideoutDressing mounts both at (-6.3, 0, 16.05), unturned) and in HIDEOUT metres (no scale at placement): x across the mouth, y up,
# the ROOM is -z. The stone jambs' inner faces are at x +-1.23, their room faces at z -0.41; the arch springs at y 2.36 (outer top
# 3.58); the rock block's face is z +0.05. The bellows and the fire tools are real size (placed at Ep2KitProps.SCALE_HIDEOUT).
def prism_xy(points, depth, z0=0.0):
    pts = [v(x, y, z0) for x, y in points]
    pts.append(pts[0])
    return Part.Face(Part.makePolygon(pts)).extrude(v(0, 0, depth))


def build_furnace_doors():
    """Two riveted cast-iron doors hung on the jambs, swung open 100 degrees into the room: three straps with rivets, hinge knuckles on
    pintle plates, a peep port with its cover swung aside, a latch bar on the free edge."""
    P = "furnace_doors"
    W, H, T, y0 = 1.18, 2.08, 0.07, 0.27
    for side in (-1, 1):
        parts = []
        parts.append(("Iron", chamfer(box((W, H, T), (W / 2, y0 + H / 2, -T / 2)), 0.012)))
        for yy in (y0 + 0.30, y0 + H / 2, y0 + H - 0.30):
            parts.append(("Iron", box((W - 0.06, 0.12, 0.022), (W / 2 + 0.02, yy, -T - 0.011))))
            for k in range(7):
                parts.append(("Iron", Part.makeSphere(0.017, v(0.10 + k * 0.165, yy, -T - 0.022))))
        for yy in (y0 + 0.22, y0 + H - 0.22):
            parts.append(("Iron", cyl(0.045, 0.17, (0.0, yy, -T / 2))))
            parts.append(("Iron", box((0.20, 0.11, 0.035), (-0.10, yy, -T / 2))))
        parts.append(("Iron", cyl(0.012, H - 0.2, (0.0, y0 + H / 2, -T / 2))))
        pc = v(W * 0.56, y0 + H * 0.63, -T)
        parts.append(("Iron", Part.makeTorus(0.085, 0.016, pc - v(0, 0, 0.012), v(0, 0, -1))))
        parts.append(("Soot", cyl(0.07, 0.01, (pc.x, pc.y, pc.z + 0.002), "z")))
        cover = cyl(0.11, 0.018, (0, 0, 0), "z")
        cover.translate(v(pc.x + 0.12, pc.y - 0.10, pc.z - 0.03))
        parts.append(("Iron", cover))
        parts.append(("Iron", box((0.05, 0.42, 0.05), (W - 0.09, y0 + H / 2, -T - 0.07))))
        for dy in (-0.15, 0.15):
            parts.append(("Iron", box((0.04, 0.04, 0.07), (W - 0.09, y0 + H / 2 + dy, -T - 0.035))))
        for mat, shp in parts:
            if side > 0:
                shp = shp.mirror(O, X)                    # the right door: its leaf runs toward -x from the right jamb
            shp.rotate(O, Y, -100.0 if side > 0 else 100.0)
            shp.translate(v(side * 1.23, 0.0, -0.41))
            add(P, mat, shp)


def build_furnace_hood():
    """A riveted sheet-iron smoke hood over the arch, lofted from a 4.3 m rim to its flue collar, and the flue climbing into the rock
    roof (y 10.3) in banded sections with a damper handle."""
    P = "furnace_hood"
    y0, y1 = 3.64, 5.10
    rim = Part.makePolygon([v(-2.15, y0, -1.15), v(2.15, y0, -1.15), v(2.15, y0, 0.05), v(-2.15, y0, 0.05), v(-2.15, y0, -1.15)])
    top = Part.Wire(Part.makeCircle(0.44, v(0, y1, -0.45), Y))
    hood = Part.makeLoft([rim, top], True)
    add(P, "Iron", hood)
    add(P, "Iron", box((4.42, 0.12, 0.08), (0, y0 + 0.06, -1.17)))
    for sx in (-1, 1):
        add(P, "Iron", box((0.08, 0.12, 1.24), (sx * 2.19, y0 + 0.06, -0.55)))
    for k in range(15):
        add(P, "Iron", Part.makeSphere(0.028, v(-2.1 + k * 0.3, y0 + 0.06, -1.22)))
    add(P, "Iron", cyl(0.42, 10.3 - y1, (0, (y1 + 10.3) / 2, -0.45)))
    for yy in (y1 + 0.05, 6.4, 7.6, 8.8, 10.0):
        add(P, "Iron", cyl(0.46, 0.09, (0, yy, -0.45)))
    add(P, "Iron", cyl(0.02, 1.0, (0, 5.9, -0.45), "x"))
    add(P, "Iron", box((0.06, 0.25, 0.06), (0.52, 5.78, -0.45)))


def build_bellows():
    """A great forge bellows on its trestle (real size; origin base centre, the nozzle toward +x): pear-shaped top and bottom boards, the
    pleated leather between them, a brass nozzle, a lever pole on its post."""
    P = "bellows"
    yb, yt = 0.52, 0.80
    pear = [(0.55, 0.0)] + [(-0.15 + 0.32 * math.cos(math.radians(a)), 0.32 * math.sin(math.radians(a))) for a in range(60, 301, 20)] + [(0.55, 0.0)]
    pear = pear[:-1]

    def board(y):
        pts = [v(x, y, z) for x, z in pear]
        pts.append(pts[0])
        return Part.Face(Part.makePolygon(pts)).extrude(v(0, 0.035, 0))
    add(P, "DarkWood", board(yb))
    add(P, "DarkWood", board(yt))
    wires = []
    for y, sc in ((yb + 0.035, 0.94), ((yb + yt) / 2 + 0.02, 1.04), (yt, 0.94)):
        pts = [v(0.55 + (x - 0.55) * sc, y, z * sc) for x, z in pear]
        pts.append(pts[0])
        wires.append(Part.makePolygon(pts))
    add(P, "Leather", Part.makeLoft(wires, True))
    add(P, "Brass", cone(0.055, 0.022, 0.32, (0.71, (yb + yt) / 2, 0.0), "x"))
    add(P, "Brass", cyl(0.06, 0.05, (0.53, (yb + yt) / 2, 0.0), "x"))
    for x in (-0.30, 0.30):
        for sz in (-1, 1):
            leg = cyl(0.028, 0.56, (0, 0, 0))
            leg.rotate(O, X, sz * 14.0)
            leg.translate(v(x, 0.26, sz * 0.10))
            add(P, "Planks", leg)
        add(P, "Planks", box((0.07, 0.07, 0.36), (x, 0.50, 0.0)))
    add(P, "Planks", box((0.72, 0.05, 0.08), (0.0, 0.20, 0.0)))
    add(P, "DarkWood", cyl(0.03, 1.25, (-0.55, 0.62, 0.0)))
    pole = cyl(0.022, 1.3, (0, 0, 0), "x")
    pole.rotate(O, Z, -18.0)
    pole.translate(v(-0.30, 1.05, 0.0))
    add(P, "DarkWood", pole)
    add(P, "Iron", cyl_y_link(-0.05, 0.84, 0.93))


def cyl_y_link(x, y0, y1):
    return cyl(0.008, y1 - y0, (x, (y0 + y1) / 2, 0.0))


def build_fire_tools():
    """A poker, a rake and a slag skimmer leaning together (real size; origin = their feet, leaning back toward +z against the furnace)."""
    P = "fire_tools"
    for k, (dx, tip) in enumerate(((-0.07, "hook"), (0.0, "rake"), (0.08, "dish"))):
        rod = cyl(0.011, 1.12, (0, 0.56, 0))
        parts = [("Iron", rod), ("DarkWood", cyl(0.02, 0.18, (0, 1.06, 0)))]
        if tip == "hook":
            parts.append(("Iron", Part.makeTorus(0.035, 0.009, v(0.035, 0.04, 0), Z, -180, 180, 180)))
        elif tip == "rake":
            parts.append(("Iron", box((0.20, 0.07, 0.012), (0, 0.035, 0))))
        else:
            parts.append(("Iron", revolve([(0.0, 0.0), (0.0, 0.09), (0.02, 0.095), (0.02, 0.085), (0.006, 0.0)], "z", (0, 0.05, 0))))
        for mat, shp in parts:
            shp.rotate(O, X, 11.0)
            shp.rotate(O, Y, (k - 1) * 9.0)
            shp.translate(v(dx, 0.0, -0.03 * k))
            add(P, mat, shp)


build_revolver()
build_keg("keg", 0.62, 0.205, 0.245)
build_keg("keg_small", 0.42, 0.14, 0.168, 14)
build_chock()
build_anvil()
build_tongs()
build_ladle()
build_mould()
build_shovel()
build_sledge()
build_pick()
build_chain()
build_cartridge()
build_crate()
build_ammo_box()
build_furnace_doors()
build_furnace_hood()
build_bellows()
build_fire_tools()


def deflection(piece, mat, shape):
    """Per-shape tessellation: the revolver and the cartridges are seen at arm's length (finer), the crate and kegs from metres."""
    diag = max(shape.BoundBox.DiagonalLength, 1e-4)
    if piece == "revolver":
        return max(0.00025, diag * 0.004), 0.35
    if piece in ("chain_link", "hook"):                                  # a hoist chain is ~150 links: keep each one light
        return max(0.0012, diag * 0.02), 1.0
    if piece in ("cartridge", "ammo_box"):                               # instanced by the dozen: ~10 segments round is plenty
        return max(0.0008, diag * 0.015), 0.8
    if piece in ("crate",):
        return max(0.002, diag * 0.004), 0.6
    if piece in ("furnace_doors", "furnace_hood", "bellows", "fire_tools"):
        # (OCC cuts curves ~2x finer than the angle given: 1.0 rad is ~12 segments; rivets, knuckles and the flue bands are many)
        return max(0.004, diag * 0.004), 1.0
    return max(0.0008, diag * 0.004), 0.5


report = {"groups": {}, "tris": 0, "pieces": {}}
for (piece, mat), shapes in sorted(GROUPS.items()):
    mesh = Mesh.Mesh()
    for shp in shapes:
        lin, ang = deflection(piece, mat, shp)
        mesh.addMesh(MeshPart.meshFromShape(Shape=shp, LinearDeflection=lin, AngularDeflection=ang, Relative=False))
    path = os.path.join(OUT, "%s__%s.obj" % (piece, mat))
    mesh.write(path)
    report["groups"]["%s/%s" % (piece, mat)] = mesh.CountFacets
    report["pieces"][piece] = report["pieces"].get(piece, 0) + mesh.CountFacets
    report["tris"] += mesh.CountFacets
json.dump(report, open(os.path.join(OUT, "smelter_kit_cad.json"), "w"), indent=1)
print("@@" + json.dumps({"ok": True, "tris": report["tris"], "pieces": report["pieces"]}))
