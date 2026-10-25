"""THE COLT GATLING, IN CAD (founder 2026-10-25: "Colt Gatling - full quality pass - readable, period, not a trash prop"; "use free CAD").

Run with FreeCAD's headless interpreter (FreeCAD 1.1.4 here: ~/tools/freecad/squashfs-root, `freecadcmd` on PATH):

    GATLING_CAD_OUT=<out_dir> freecadcmd tools/ep2_cad/gatling_cad.py

Builds the gun from real solids - filleted and chamfered breech casing, a cascabel, six bored barrels running THROUGH three barrel plates,
a Broadwell drum with its twenty cartridge columns, a forged yoke on a turntable, an elevating screw with a hand wheel, the crank with a
turned walnut grip, a dressed-stone plinth, pillow sandbags and planked ammunition boxes - and tessellates each (piece, material) group to
one OBJ in <out_dir>, plus <out_dir>/gatling_cad.json (triangle counts). tools/ep2_blender/build_gatling_cad.py assembles them into
gatling_post.glb with the SAME node tree and pivots the game drives (Ep2GatlingPost): Gatling_Post -> Gat_Yaw -> Gat_Pitch -> {Gat_Barrels,
Gat_Crank}.

Coordinates are the GAME's (y up, the bore along +x, +z the gunner's right), each piece around its own pivot, exactly like
tools/ep2_blender/armory_kit.py (GAT_YAW_Y 1.12 on the post, GAT_TRUNNION_Y 0.30 above the turntable, the barrel cluster at GAT_BARREL_X
0.52 along the bore, the crank hub at GAT_CRANK). Period facts: a Colt-built Gatling of the 1870s - six barrels turning past a fixed lock
cylinder, a bronze casing, a Broadwell drum feed, a hand crank on the right.
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

OUT = os.environ.get("GATLING_CAD_OUT", os.path.abspath("gatling_cad_out"))      # (freecadcmd treats unknown --flags as its own)
os.makedirs(OUT, exist_ok=True)

GAT_YAW_Y = 1.12
GAT_TRUNNION_Y = 0.30
GAT_BARREL_X = 0.52
GAT_CRANK = (-0.02, 0.0, 0.21)

X = Vector(1, 0, 0)
Y = Vector(0, 1, 0)
Z = Vector(0, 0, 1)

GROUPS = {}          # (piece, material) -> [shapes]


def add(piece, mat, shape):
    GROUPS.setdefault((piece, mat), []).append(shape)


def v(x, y, z):
    return Vector(x, y, z)


def axis_vec(a):
    return {"x": X, "y": Y, "z": Z}[a]


def cyl(r, length, centre, axis="x"):
    """A cylinder of radius r, `length` long, centred on `centre`, along `axis`."""
    d = axis_vec(axis)
    base = Vector(centre) - d * (length / 2.0)
    return Part.makeCylinder(r, length, base, d)


def cone(r0, r1, length, centre, axis="x"):
    d = axis_vec(axis)
    base = Vector(centre) - d * (length / 2.0)
    return Part.makeCone(r0, r1, length, base, d)


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


def circ_edges(shape):
    return [e for e in shape.Edges if hasattr(e.Curve, "Radius")]


def revolve(profile, axis="x", centre=(0, 0, 0)):
    """Revolve a closed (radial, axial) polyline profile about `axis` through `centre`. Points are (along_axis, radius)."""
    c = Vector(centre)
    pts = []
    for a, r in profile:
        if axis == "x":
            pts.append(c + Vector(a, r, 0))
        elif axis == "y":
            pts.append(c + Vector(r, a, 0))
        else:
            pts.append(c + Vector(0, r, a))
    pts.append(pts[0])
    face = Part.Face(Part.makePolygon(pts))
    return face.revolve(c, axis_vec(axis), 360)


def hex_nut(r, h, centre, axis="y"):
    d = axis_vec(axis)
    # a hexagon in the plane normal to d
    u = X if axis != "x" else Y
    w = d.cross(u)
    u = w.cross(d)
    u.normalize()
    w.normalize()
    base = Vector(centre) - d * (h / 2.0)
    pts = [base + u * (r * math.cos(k * math.pi / 3)) + w * (r * math.sin(k * math.pi / 3)) for k in range(6)]
    pts.append(pts[0])
    prism = Part.Face(Part.makePolygon(pts)).extrude(d * h)
    return chamfer(prism, r * 0.12, [e for e in prism.Edges if abs(e.tangentAt(e.FirstParameter).dot(d)) < 0.1])


def dome_head(r, centre, axis="z", sign=1.0):
    """A round (domed) screw head: a flattened hemisphere standing on `centre`, facing +axis*sign."""
    s = Part.makeSphere(r, Vector(0, 0, 0), Vector(0, 0, 1), 0, 90, 360)
    m = FreeCAD.Matrix()
    m.scale(Vector(1.0, 1.0, 0.5))
    s = s.transformGeometry(m)
    d = axis_vec(axis) * sign
    s = s.transformShape(FreeCAD.Placement(Vector(centre), FreeCAD.Rotation(Vector(0, 0, 1), d)).toMatrix(), True) or s
    return s


# ================================================================================================================ the post (static)
def build_post():
    P = "post"
    # dressed-stone plinth: chamfered drum on a broader footing course
    add(P, "Stone", revolve([(0.0, 0.0), (0.0, 0.705), (0.05, 0.705), (0.05, 0.645), (0.27, 0.605), (0.30, 0.575), (0.30, 0.0)], "y"))
    # the iron post: a flanged foot, a tapered column, a collar under the turntable
    add(P, "Iron", revolve([(0.30, 0.0), (0.30, 0.165), (0.335, 0.165), (0.345, 0.12), (0.37, 0.098), (1.03, 0.086), (1.045, 0.13),
                            (1.10, 0.112), (1.12, 0.10), (1.12, 0.0)], "y"))
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        add(P, "Iron", hex_nut(0.022, 0.026, (0.135 * math.cos(a), 0.348, 0.135 * math.sin(a)), "y"))
    # sandbags: soft pillows in two flanks (the gunner's back and the field of fire stay open), every bag slightly turned
    for row in range(2):
        for i in range(10):
            ang = math.radians((55 if i < 5 else 235 - 5 * 16) + i * 16 + (8 if row else 0))
            r = 1.0
            # long axis along the circle's tangent (a +Y turn of 90 deg - ang maps +x onto it), each bag a few degrees off
            turn = 90.0 - math.degrees(ang) + (3 if (i + row) % 2 else -4)
            centre = v(r * math.cos(ang), 0.075 + row * 0.148, r * math.sin(ang))
            bag = fillet(box((0.30, 0.15, 0.25), (0, 0, 0)), 0.06)
            bag.rotate(v(0, 0, 0), Y, turn)
            bag.translate(centre)
            add(P, "Sand", bag)
            tie = box((0.026, 0.156, 0.256), (0, 0, 0))                       # the cord band round its middle
            tie.rotate(v(0, 0, 0), Y, turn)
            tie.translate(centre)
            add(P, "Rope", tie)
    # ammunition boxes: planked, with iron corner straps, rope beckets and a spare drum on each lid
    for k, (x, z, yw) in enumerate(((-0.55, -1.55, 0.2), (-0.55, 1.55, -0.2))):
        parts_planks, parts_iron = [], []
        for j in range(4):                                       # side planks (with a 4 mm gap)
            parts_planks.append(box((0.62, 0.078, 0.40), (0, 0.045 + j * 0.082, 0)))
        parts_planks.append(chamfer(box((0.64, 0.035, 0.42), (0, 0.355, 0)), 0.006))          # lid
        for sx in (-1, 1):
            for sz in (-1, 1):
                parts_iron.append(box((0.05, 0.34, 0.006), (sx * 0.295, 0.17, sz * 0.203)))
                parts_iron.append(box((0.006, 0.34, 0.05), (sx * 0.313, 0.17, sz * 0.18)))
        for shapes, mat in ((parts_planks, "Planks"), (parts_iron, "Iron")):
            for s in shapes:
                s.rotate(v(0, 0, 0), Y, math.degrees(yw))
                s.translate(v(x, 0, z))
                add(P, mat, s)
        for sx in (-1, 1):
            becket = Part.makeTorus(0.05, 0.009, v(0, 0, 0), X)
            becket.rotate(v(0, 0, 0), Y, math.degrees(yw))
            becket.translate(v(x, 0.22, z) + v(sx * 0.32 * math.cos(yw), 0, -sx * 0.32 * math.sin(yw)))
            add(P, "Rope", becket)
        add(P, "Brass", drum_shape((x, 0.44, z), 0.17, 0.09))
    # the NOT FOR SALE board on two stakes behind the gunner (the game draws the words on its -x face, Gat_Sign)
    for sz in (-0.75, 0.75):
        add(P, "DarkWood", chamfer(box((0.06, 1.15, 0.06), (-2.4, 0.575, sz)), 0.006))
    for j in range(3):
        add(P, "Planks", chamfer(box((0.05, 0.175, 1.70), (-2.4, 0.80 + j * 0.18, 0.0)), 0.004))
    add(P, "Trim", chamfer(box((0.07, 0.04, 1.74), (-2.4, 1.27, 0.0)), 0.006))
    add(P, "Trim", chamfer(box((0.07, 0.04, 1.74), (-2.4, 0.69, 0.0)), 0.006))


def drum_shape(centre, r, h):
    """A Broadwell drum: a brass drum with a raised rim and a hub (used on the gun and as the spares on the boxes)."""
    cx, cy, cz = centre
    d = revolve([(-h / 2, 0.0), (-h / 2, r), (-h / 2 + 0.01, r + 0.006), (h / 2 - 0.01, r + 0.006), (h / 2, r), (h / 2, 0.04),
                 (h / 2 + 0.03, 0.035), (h / 2 + 0.03, 0.0)], "y", (cx, cy, cz))
    return d


# ================================================================================================================== the yaw (turns)
def build_yaw():
    P = "yaw"
    add(P, "Iron", revolve([(0.0, 0.0), (0.0, 0.185), (0.01, 0.19), (0.04, 0.19), (0.05, 0.175), (0.05, 0.0)], "y"))   # turntable
    for k in range(8):
        a = k * math.pi / 4
        add(P, "Iron", hex_nut(0.012, 0.014, (0.155 * math.cos(a), 0.056, 0.155 * math.sin(a)), "y"))
    add(P, "Iron", chamfer(box((0.15, 0.065, 0.52), (0, 0.08, 0)), 0.01))                    # cross-tree
    for sz in (-1, 1):
        # the forged yoke arms: a tapered upright with a rounded boss around each trunnion
        arm = chamfer(box((0.08, 0.26, 0.065), (0, 0.19, sz * 0.225)), 0.012)
        boss = cyl(0.062, 0.07, (0, GAT_TRUNNION_Y, sz * 0.225), "z")
        add(P, "Iron", arm.fuse(boss).removeSplitter())
        cap = revolve([(-0.012, 0.0), (-0.012, 0.068), (0.004, 0.068), (0.012, 0.058), (0.012, 0.0)], "z", (0, GAT_TRUNNION_Y, sz * 0.272))
        add(P, "Brass", cap)                                                                 # trunnion caps
        for dy in (-0.045, 0.045):
            add(P, "Iron", hex_nut(0.009, 0.01, (0.0, GAT_TRUNNION_Y + dy, sz * 0.285), "z"))
    # elevating gear: housing, the screw (threads as rings), and a spoked hand wheel on the gunner's left
    add(P, "Iron", chamfer(box((0.06, 0.11, 0.15), (-0.11, 0.125, 0.0)), 0.008))
    screw_rings = [cyl(0.016, 0.006, (-0.13, 0.19 + k * 0.011, 0.0), "y") for k in range(9)]
    add(P, "GunSteel", Part.makeCompound([cyl(0.012, 0.12, (-0.13, 0.235, 0.0), "y")] + screw_rings))
    wheel_c = (-0.11, 0.125, -0.115)
    rim = Part.makeTorus(0.07, 0.008, v(*wheel_c), Z)
    hub = cyl(0.016, 0.03, wheel_c, "z")
    spokes = []
    for k in range(5):
        a = k * 2 * math.pi / 5
        sp = cyl(0.0055, 0.066, (0, 0, 0), "x")
        sp.rotate(v(0, 0, 0), Z, math.degrees(a))
        sp.translate(v(wheel_c[0] + 0.035 * math.cos(a), wheel_c[1] + 0.035 * math.sin(a), wheel_c[2]))
        spokes.append(sp)
    knob = cyl(0.009, 0.035, (wheel_c[0] + 0.07, wheel_c[1], wheel_c[2] - 0.02), "z")
    add(P, "Iron", Part.makeCompound([rim, hub] + spokes))
    add(P, "GunWood", knob)


# ================================================================================================================ the pitch (elevates)
def build_pitch():
    P = "pitch"
    add(P, "Brass", cyl(0.04, 0.47, (0, 0, 0), "z"))                                        # trunnion pin
    # the bronze breech casing: a turned body with a raised rear band and a reinforce ring, filleted where it meets the cap
    body = revolve([(-0.29, 0.0), (-0.29, 0.148), (-0.27, 0.152), (-0.25, 0.152), (-0.245, 0.142), (0.19, 0.142), (0.20, 0.149),
                    (0.225, 0.149), (0.23, 0.128), (0.49, 0.124), (0.49, 0.0)], "x")
    add(P, "Brass", body)
    # the cascabel: an iron cap, a neck and the knob the gunner steadies
    add(P, "Iron", revolve([(-0.335, 0.0), (-0.335, 0.105), (-0.32, 0.122), (-0.29, 0.124), (-0.29, 0.0)], "x"))
    add(P, "Iron", revolve([(-0.42, 0.0), (-0.42, 0.012), (-0.405, 0.032), (-0.385, 0.036), (-0.37, 0.026), (-0.335, 0.03),
                            (-0.335, 0.0)], "x"))
    add(P, "Iron", Part.makeSphere(0.034, v(-0.445, 0.0, 0.0)))
    # side plates over the lock (the crank side carries the gear housing) with domed screws
    for sz in (-1, 1):
        plate = chamfer(box((0.40, 0.20, 0.012), (-0.03, 0.0, sz * 0.146)), 0.003)
        add(P, "Iron", plate)
        for k in range(4):
            for dy in (-0.07, 0.07):
                add(P, "Brass", dome_head(0.009, (-0.18 + k * 0.1, dy, sz * 0.153), "z", sz))
    add(P, "Iron", chamfer(box((0.11, 0.11, 0.05), (-0.02, -0.02, 0.18)), 0.01))          # gear housing behind the crank
    add(P, "Iron", chamfer(box((0.36, 0.022, 0.014), (-0.03, 0.147, 0.0)), 0.003))         # top seam strap
    # the feed: hopper neck and the Broadwell drum with its 20 cartridge columns between two plates
    add(P, "Brass", chamfer(box((0.15, 0.08, 0.15), (0.02, 0.17, 0.0)), 0.01))
    # the gunner's eye (Gat_Eye -0.86, 0.66) looks over the drum to the muzzle: that sightline crosses the drum's far edge at y 0.35, so the
    # drum's top stays at 0.32 and its hub at 0.355 (the old kit's drum topped out at 0.325 / 0.385 the same way)
    drum_c = (0.02, 0.265, 0.0)
    add(P, "Brass", revolve([(-0.055, 0.0), (-0.055, 0.225), (-0.046, 0.232), (-0.04, 0.232), (-0.036, 0.214), (0.036, 0.214),
                             (0.04, 0.232), (0.046, 0.232), (0.055, 0.225), (0.055, 0.07), (0.068, 0.058), (0.09, 0.052),
                             (0.09, 0.0)], "y", drum_c))
    cols = []
    for k in range(20):
        a = k * 2 * math.pi / 20
        cols.append(cyl(0.0095, 0.074, (drum_c[0] + 0.219 * math.cos(a), drum_c[1], drum_c[2] + 0.219 * math.sin(a)), "y"))
    add(P, "GunSteel", Part.makeCompound(cols))
    for k in range(10):                                                                         # radial ribs on the top plate
        a = k * 2 * math.pi / 10
        rib = chamfer(box((0.15, 0.008, 0.016), (0, 0, 0)), 0.0025)
        rib.rotate(v(0, 0, 0), Y, math.degrees(a))
        rib.translate(v(drum_c[0] + 0.12 * math.cos(a), drum_c[1] + 0.058, drum_c[2] - 0.12 * math.sin(a)))
        add(P, "Brass", rib)
    # the collar the barrel cluster turns in
    add(P, "Iron", revolve([(0.49, 0.0), (0.49, 0.136), (0.50, 0.14), (0.525, 0.14), (0.53, 0.13), (0.53, 0.0)], "x"))
    # sights: a folding rear leaf with an aperture, and a front blade on the stationary collar
    add(P, "GunSteel", chamfer(box((0.03, 0.016, 0.05), (-0.16, 0.152, 0.0)), 0.002))
    leaf = box((0.008, 0.075, 0.032), (-0.16, 0.20, 0.0)).cut(cyl(0.006, 0.02, (-0.16, 0.222, 0.0), "x"))
    add(P, "GunSteel", leaf)
    add(P, "GunSteel", chamfer(box((0.018, 0.04, 0.006), (0.515, 0.155, 0.0)), 0.0015))


# ================================================================================================================ the barrels (spin)
def build_barrels():
    P = "barrels"
    tubes = []
    for i in range(6):
        a = i * math.pi / 3
        cy, cz = 0.072 * math.cos(a), 0.072 * math.sin(a)
        t = revolve([(0.0, 0.0), (0.0, 0.022), (0.006, 0.023), (0.95, 0.0205), (0.975, 0.0205), (0.98, 0.019), (0.98, 0.0)], "x",
                    (0.0, cy, cz))
        bore = cyl(0.0118, 0.30, (0.98 - 0.15 + 0.001, cy, cz), "x")                       # a real, dark bore at the muzzle
        tubes.append(t.cut(bore))
    add(P, "GunSteel", Part.makeCompound(tubes))
    add(P, "GunSteel", cyl(0.03, 0.98, (0.49, 0.0, 0.0), "x"))                              # the arbor
    # three barrel plates the barrels pass through (rear, middle, the muzzle plate), chamfered
    for x, w, mat in ((0.035, 0.05, "Brass"), (0.50, 0.04, "Brass"), (0.952, 0.032, "Brass")):
        disc = cyl(0.108, w, (x, 0.0, 0.0), "x")
        plate = chamfer(disc, 0.006, circ_edges(disc))
        for i in range(6):
            a = i * math.pi / 3
            plate = plate.cut(cyl(0.0215, w + 0.02, (x, 0.072 * math.cos(a), 0.072 * math.sin(a)), "x"))
        add(P, mat, plate)
    add(P, "Iron", revolve([(0.96, 0.0), (0.96, 0.034), (0.99, 0.03), (1.0, 0.018), (1.0, 0.0)], "x"))     # arbor nose


# ================================================================================================================== the crank (turns)
def build_crank():
    P = "crank"
    add(P, "Iron", revolve([(-0.035, 0.0), (-0.035, 0.056), (0.03, 0.056), (0.035, 0.05), (0.035, 0.0)], "z"))     # hub
    add(P, "Brass", revolve([(0.035, 0.0), (0.035, 0.03), (0.07, 0.028), (0.078, 0.02), (0.078, 0.0)], "z"))
    # the arm: a forged, tapered bar with a rounded end
    pts = [v(-0.03, 0.0, 0.0), v(0.03, 0.0, 0.0), v(0.022, 0.265, 0.0), v(-0.022, 0.265, 0.0), v(-0.03, 0.0, 0.0)]
    arm = Part.Face(Part.makePolygon(pts)).extrude(v(0, 0, 0.026))
    arm.translate(v(0, 0, 0.04))
    arm = chamfer(arm, 0.004).fuse(cyl(0.024, 0.026, (0, 0.265, 0.053), "z")).removeSplitter()
    add(P, "Iron", arm)
    # the turned walnut grip on its pin, with brass ferrules
    add(P, "GunSteel", cyl(0.008, 0.16, (0, 0.265, 0.13), "z"))
    add(P, "GunWood", revolve([(0.072, 0.0), (0.072, 0.019), (0.09, 0.026), (0.13, 0.029), (0.17, 0.025), (0.188, 0.019),
                               (0.188, 0.0)], "z", (0, 0.265, 0.0)))
    add(P, "Brass", cyl(0.021, 0.008, (0, 0.265, 0.071), "z"))
    add(P, "Brass", cyl(0.021, 0.008, (0, 0.265, 0.19), "z"))


build_post()
build_yaw()
build_pitch()
build_barrels()
build_crank()

## Tessellation per SHAPE: the gun is seen from 0.6 m (the gunner's eye is over the drum), the sandbags and the plinth from metres away,
## and a screw head needs far fewer segments than the breech casing it sits on.
def deflection(piece, mat, shape):
    if mat in ("Sand", "Rope"):
        return 0.008, 1.0
    diag = max(shape.BoundBox.DiagonalLength, 1e-3)
    base_lin, base_ang = (0.003, 0.45) if piece == "post" else (0.0011, 0.30)
    # big stonework may go finer (the plinth read faceted); the gun's long thin parts (barrels) never need finer than base_ang
    ang = min(0.85, max(0.12 if piece == "post" else base_ang, base_ang * math.sqrt(0.30 / diag)))
    lin = max(base_lin, diag * 0.004)
    return lin, ang


report = {"groups": {}, "tris": 0}
for (piece, mat), shapes in sorted(GROUPS.items()):
    mesh = Mesh.Mesh()
    for shp in shapes:
        lin, ang = deflection(piece, mat, shp)
        mesh.addMesh(MeshPart.meshFromShape(Shape=shp, LinearDeflection=lin, AngularDeflection=ang, Relative=False))
    path = os.path.join(OUT, "%s__%s.obj" % (piece, mat))
    mesh.write(path)
    report["groups"]["%s/%s" % (piece, mat)] = mesh.CountFacets
    report["tris"] += mesh.CountFacets
report["pivots"] = {"GAT_YAW_Y": GAT_YAW_Y, "GAT_TRUNNION_Y": GAT_TRUNNION_Y, "GAT_BARREL_X": GAT_BARREL_X, "GAT_CRANK": GAT_CRANK}
json.dump(report, open(os.path.join(OUT, "gatling_cad.json"), "w"), indent=1)
print("@@" + json.dumps({"ok": True, "tris": report["tris"], "groups": len(report["groups"])}))
