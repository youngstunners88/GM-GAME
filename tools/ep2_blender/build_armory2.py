"""RICH & UTAH'S ARMORY, TWO STOREYS (founder 2026-10-19; skill ep2-armory-two-story).

Headless bpy:  blender -b --factory-startup -P tools/ep2_blender/build_armory2.py -- [--out src/episode2/extras/armory/armory2.glb]

One GLB, named pieces (Bldg_Armory2, Arm2_Fit, Arm2_Guns, Arm2_Nav and the case rifle Arm2_Sharps) the town places (same conventions as build_town_kit.py: origin = middle of the FRONT edge at street level,
front faces +Z in the game frame, named untextured materials that Ep2GoldTown._apply_mats skins - Siding, Trim, Roof, Planks - and
plain coloured ones for the rest):
  Bldg_Armory2      the building: 10 x 12 m, ground floor 3.8 m + upper floor 3.4 m, false front with cornice and sign board, porch with
                    steps, posts, brackets and an awning that is also a small upper balcony, a double door (one leaf swung in), two barred
                    display windows and three upper sash windows with open shutters - all with CLEAR glass (never a black hole) - side and
                    back windows, corner boards, belt course, bullet holes, posters, a longhorn skull over the door, two door lanterns.
                    Inside: an L-shaped upper gallery (back + left) with railings over an open shop floor, a stair up the right wall,
                    hanging oil lamps.
  Arm2_Fit          the fit-out ("dense but readable"): the long counter with a glass-topped revolver section, two glass revolver cases,
                    the lit long-rifle case (the day-88 sniper), ammunition shelves by calibre, rifles standing in barrels, powder kegs,
                    a cleaning bench, the back-wall and gallery rifle racks and pegboards, brass pegs under the mounted guns,
                    the gallery fascia's gun boards, crates of dynamite and cartridges,
                    bandoliers, Utah's upstairs workbench and river gear (sealed crates, a skiff on the wall), a chain across the stair foot.
  Arm2_Guns         empties only, Gun_<Rack|Near>_<family>_<n>: where each of the founder's guns goes (72 racked long guns, 12 in the
                    barrels, ~45 sidearms in the cases, the counter and on the pegboards, a longbow, the Gatling at the gallery rail, the
                    fascia's Sharps, Tommy and Winchester, the benches' guns). Ep2ArmoryRacks fills them from rack_guns.glb.
  Arm2_Sharps       Rich's Sharps Model 1874 in the lit case (its own piece so the introduction can lift it out into his hand)
  Arm2_CaseLid      the lit case's glass lid with its brass pull, and the empty Hinge_case on its hinge edge (the game opens it)
  Arm2_Nav          empties only: Spot_<name> (NPC waypoints, y = floor height), Block_<name> (scale = half extents of a walk blocker in
                    the shop floor plane), LightAnchor_<n> (warm lamp positions), SignAnchor_ARMS (the painted sign).
Everything is written in GAME coordinates (x right, y up, z toward the street) and converted once at the end.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import armory_kit as K          # the Sharps 1874 (shared with build_sharps_gatling.py)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/armory/armory2.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
MATS = {}


def mat(name, rgb, rough=0.85, metal=0.0, alpha=1.0, emit=0.0):
    m = bpy.data.materials.new(name)
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    MATS[name] = m


# kit names (skinned with the town's triplanar textures in Godot) + the armory's own
for n, c, r, mt in [("Siding", (0.42, 0.33, 0.24), 0.9, 0.0), ("Trim", (0.30, 0.21, 0.14), 0.85, 0.0), ("Roof", (0.40, 0.37, 0.33), 0.6, 0.5),
                    ("Planks", (0.36, 0.28, 0.20), 0.9, 0.0), ("Iron", (0.16, 0.15, 0.14), 0.6, 0.7), ("Brass", (0.72, 0.55, 0.25), 0.35, 1.0),
                    ("DarkWood", (0.20, 0.12, 0.07), 0.55, 0.0), ("Cloth", (0.45, 0.10, 0.08), 0.9, 0.0), ("Green", (0.10, 0.25, 0.14), 0.8, 0.0),
                    ("GunWood", (0.34, 0.17, 0.07), 0.45, 0.0), ("GunSteel", (0.09, 0.095, 0.10), 0.35, 0.85), ("Leather", (0.36, 0.21, 0.11), 0.7, 0.0),
                    ("Paper", (0.82, 0.74, 0.56), 0.95, 0.0), ("Bone", (0.88, 0.84, 0.74), 0.7, 0.0), ("Dynamite", (0.62, 0.10, 0.06), 0.8, 0.0),
                    ("Felt", (0.12, 0.26, 0.16), 0.95, 0.0), ("Rope", (0.55, 0.45, 0.30), 0.95, 0.0), ("Soot", (0.05, 0.045, 0.04), 0.95, 0.0), ("CaseHard", (0.17, 0.15, 0.21), 0.38, 0.85)]:
    mat(n, c, r, mt)
mat("GlassClear", (0.62, 0.70, 0.72), 0.05, 0.0, alpha=0.22)
mat("LampGlow", (1.0, 0.72, 0.36), 0.4, 0.0, emit=4.0)


class Piece:
    """Primitives in the GAME frame, grouped by material; `xf` is the current placement (game-frame 4x4)."""

    def __init__(self, name):
        self.name = name
        self.bms = {}
        self.empties = []
        self.xf = Matrix.Identity(4)

    def bm(self, m):
        if m not in self.bms:
            self.bms[m] = bmesh.new()
        return self.bms[m]

    def at(self, pos=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0):
        """Placement for the next primitives: translate, then yaw about y, pitch about x, roll about z (game frame)."""
        return Matrix.Translation(Vector(pos)) @ Matrix.Rotation(yaw, 4, "Y") @ Matrix.Rotation(pitch, 4, "X") @ Matrix.Rotation(roll, 4, "Z")

    def _add(self, m, tmp, local):
        bmesh.ops.transform(tmp, matrix=self.xf @ local, verts=tmp.verts)
        me = bpy.data.meshes.new("t")
        tmp.to_mesh(me)
        tmp.free()
        self.bm(m).from_mesh(me)
        bpy.data.meshes.remove(me)

    def box(self, m, size, centre, yaw=0.0, pitch=0.0, roll=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
        self._add(m, tmp, self.at(centre, yaw, pitch, roll))

    def cyl(self, m, r1, r2, h, centre, axis="y", seg=8, yaw=0.0):
        """Cone/cylinder along game y (or x / z), centred."""
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
        # create_cone builds along its local z: stand it on game y first
        bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
        rot = {"y": Matrix.Identity(4), "x": Matrix.Rotation(-math.pi / 2, 4, "Z"), "z": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        self._add(m, tmp, Matrix.Translation(Vector(centre)) @ Matrix.Rotation(yaw, 4, "Y") @ rot)

    def empty(self, name, pos, scale=(1, 1, 1)):
        self.empties.append((name, (self.xf @ Vector(pos).to_4d()).to_3d(), scale))

    def slot(self, name, local):
        """An empty with a full placement (game-frame 4x4, rotation and scale kept)."""
        self.empties.append((name, self.xf @ local, None))

    def build(self):
        conv = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))     # game (x, y, z) -> blender (x, -z, y)
        root = bpy.data.objects.new(self.name, None)
        bpy.context.scene.collection.objects.link(root)
        tris = 0
        if self.bms:
            me = bpy.data.meshes.new(self.name + "_mesh")
            big = bmesh.new()
            names = list(self.bms.keys())
            for i, mname in enumerate(names):
                part = self.bms[mname]
                tmp = bpy.data.meshes.new("t")
                part.to_mesh(tmp)
                part.free()
                n0 = len(big.faces)
                big.from_mesh(tmp)
                big.faces.ensure_lookup_table()
                for f in big.faces[n0:]:
                    f.material_index = i
                bpy.data.meshes.remove(tmp)
            bmesh.ops.transform(big, matrix=conv, verts=big.verts)
            bmesh.ops.remove_doubles(big, verts=big.verts, dist=0.0005)
            big.to_mesh(me)
            big.free()
            for mname in names:
                me.materials.append(MATS[mname])
            ob = bpy.data.objects.new(self.name + "_geo", me)
            bpy.context.scene.collection.objects.link(ob)
            ob.parent = root
            tris = sum(len(p.vertices) - 2 for p in me.polygons)
        for n, p, s in self.empties:
            e = bpy.data.objects.new(n, None)
            e.empty_display_size = 0.2
            bpy.context.scene.collection.objects.link(e)
            e.parent = root
            if s is None:                # a slot: the whole placement, carried into the Blender frame
                e.matrix_world = conv @ p @ conv.inverted()
                continue
            e.location = (p.x, -p.z, p.y)
            e.scale = (s[0], s[2], s[1])
        return root, tris


Piece.prism = K.Piece.prism      # profile extrusions for the shared Sharps (armory_kit.py)

T = 0.16                         # wall thickness
W, D = 10.0, 12.0                # footprint (x across the front, depth into -z)
H1, H2 = 3.8, 3.4                # ground floor, upper floor
HW = H1 + H2                     # wall top (7.2)
HF = 9.8                         # false front top
HX = W / 2


def wall_holes(p, m, u0, u1, h, holes, place):
    """A wall rectangle u0..u1 x 0..h built in boxes AROUND its openings (real holes). holes: [(uc, vc, w, h)]."""
    us = sorted({u0, u1, *[min(max(c - w_ / 2, u0), u1) for c, _, w_, _ in holes], *[min(max(c + w_ / 2, u0), u1) for c, _, w_, _ in holes]})
    for ua, ub in zip(us, us[1:]):
        if ub - ua < 1e-4:
            continue
        um = (ua + ub) / 2
        cuts = sorted((v - hh / 2, v + hh / 2) for c, v, w_, hh in holes if c - w_ / 2 <= um <= c + w_ / 2)
        v = 0.0
        for lo, hi in cuts:
            if lo - v > 1e-4:
                place(m, ua, ub, v, lo)
            v = max(v, hi)
        if h - v > 1e-4:
            place(m, ua, ub, v, h)


def window(p, x, y, w, h, zf, bars=0, shutters=False, face=1.0):
    """A real window in a hole of the wall plane at z = zf (the wall behind it is z = zf .. zf - T): reveal frame lining the hole, a
    recessed clear pane, sash bars, sill and head, optional iron bars and open shutters."""
    s = face
    for sx in (-1, 1):
        p.box("Trim", (0.08, h + 0.02, T + 0.05), (x + sx * (w / 2 - 0.04), y, zf - T / 2 + 0.02))
    p.box("Trim", (w, 0.08, T + 0.05), (x, y + h / 2 - 0.04, zf - T / 2 + 0.02))
    p.box("Trim", (w, 0.06, T + 0.02), (x, y - h / 2 + 0.03, zf - T / 2))
    p.box("GlassClear", (w - 0.16, h - 0.16, 0.03), (x, y, zf - T * 0.55))
    p.box("Trim", (0.04, h - 0.16, 0.04), (x, y, zf - T * 0.55 + 0.02))
    p.box("Trim", (w - 0.16, 0.04, 0.04), (x, y, zf - T * 0.55 + 0.02))
    p.box("Trim", (w + 0.26, 0.07, 0.17), (x, y - h / 2 - 0.05, zf + 0.06))                  # sill
    p.box("Trim", (w + 0.22, 0.10, 0.12), (x, y + h / 2 + 0.08, zf + 0.04))                  # head
    for i in range(bars):
        p.box("Iron", (0.04, h + 0.1, 0.04), (x - w / 2 + (i + 0.5) * w / bars, y, zf + s * 0.10))
    if bars:
        for yy in (y - h / 2 + 0.1, y + h / 2 - 0.1):
            p.box("Iron", (w + 0.1, 0.05, 0.05), (x, yy, zf + s * 0.10))
    if shutters:
        for sx in (-1, 1):
            p.box("DarkWood", (w * 0.45, h, 0.05), (x + sx * (w / 2 + w * 0.24), y, zf + s * 0.03))
            for k in range(3):
                p.box("Trim", (w * 0.4, 0.03, 0.02), (x + sx * (w / 2 + w * 0.24), y - h / 2 + 0.25 + k * (h - 0.5) / 2, zf + s * 0.065))


# THE GUNS ARE THE FOUNDER'S OWN MODELS (founder 2026-11-08: "no placeholder sticks"). Every rifle, pistol, bow and the Gatling in the
# shop is a slot empty in Arm2_Guns, Gun_<Rack|Near>_<family>_<n>; Ep2ArmoryRacks puts that family's piece from rack_guns.glb
# (tools/ep2_blender/build_rack_guns.py: muzzle +x, top +y, side +z, centred, real length) on it. GUN_DIMS seats them on shelves and felt.
with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "rack_guns_dims.json")) as _f:
    GUN_DIMS = json.load(_f)
G = Piece("Arm2_Guns")
_gun_n = [0]


def gun(fam, pos, yaw=0.0, pitch=0.0, roll=0.0, scale=1.0, near=False):
    """One founder gun at `pos` (its centre; the Gatling: its feet), turned like the Piece primitives. `near` = the close-up cut."""
    _gun_n[0] += 1
    G.slot("Gun_%s_%s_%d" % ("Near" if near else "Rack", fam, _gun_n[0]), G.at(pos, yaw, pitch, roll) @ Matrix.Scale(scale, 4))


def gun_flat(fam, x, top, z, yaw=0.0, near=True, scale=1.0):
    """Lying on its side on a surface at height `top` (case felt, bench, counter)."""
    gun(fam, (x, top + GUN_DIMS[fam]["z"] * scale / 2 + 0.002, z), yaw=yaw, pitch=-math.pi / 2, near=near, scale=scale)


def gun_racked(fam, x, shelf_top, back, yaw=0.0, scale=1.0):
    """Standing muzzle up, its butt on a rack shelf at `shelf_top`, its back against the board face at z = `back`."""
    gun(fam, (x, shelf_top + GUN_DIMS[fam]["x"] * scale / 2, back + GUN_DIMS[fam]["z"] * scale / 2 + 0.004), yaw=yaw, roll=math.pi / 2, scale=scale)


def gun_wall(fam, wall_x, y, z, near=False, scale=1.0):
    """Hung flat on the left wall's board (face at x = `wall_x`), muzzle toward the back of the shop, on two brass pegs."""
    gun(fam, (wall_x + GUN_DIMS[fam]["z"] * scale / 2 + 0.004, y, z), yaw=math.pi / 2, near=near, scale=scale)
    for dz in (-0.3, 0.3):
        F.cyl("Brass", 0.008, 0.008, 0.06, (wall_x + 0.03, y - GUN_DIMS[fam]["y"] * scale / 2 - 0.008, z + dz * GUN_DIMS[fam]["x"] * scale), "x", 5)


def gun_fascia(fam, x, y, face_z, scale=1.0):
    """Mounted broadside on a fascia board (face at z = `face_z`), on two brass pegs under it."""
    gun(fam, (x, y, face_z + GUN_DIMS[fam]["z"] * scale / 2 + 0.004), near=True, scale=scale)
    for dx in (-0.3, 0.3):
        F.cyl("Brass", 0.01, 0.01, 0.08, (x + dx * GUN_DIMS[fam]["x"] * scale, y - GUN_DIMS[fam]["y"] * scale / 2 - 0.01, face_z + 0.04), "z", 5)


def vary(k):
    """A small, repeatable variation for slot k: (yaw, scale) within +-0.06 rad and 0.96 - 1.04."""
    return 0.06 * math.sin(k * 2.39), 1.0 + 0.04 * math.sin(k * 1.71 + 0.5)


def crate(p, pos, size=(0.8, 0.5, 0.5), yaw=0.0, label="Planks"):
    keep = p.xf
    p.xf = keep @ p.at(pos, yaw)
    sx, sy, sz = size
    p.box("Planks", (sx, sy, sz), (0, sy / 2, 0))
    for e in (-1, 1):
        p.box("Trim", (0.06, sy + 0.01, sz + 0.02), (e * (sx / 2 - 0.03), sy / 2, 0))
    p.box(label, (sx * 0.5, sy * 0.35, 0.01), (0, sy * 0.55, sz / 2 + 0.005))
    p.xf = keep


def keg(p, pos, r=0.28, h=0.62):
    p.cyl("DarkWood", r * 0.9, r * 0.9, h, (pos[0], pos[1] + h / 2, pos[2]), "y", 10)
    p.cyl("DarkWood", r, r, h * 0.55, (pos[0], pos[1] + h / 2, pos[2]), "y", 10)
    for k in (0.12, 0.5, 0.88):
        p.cyl("Brass", r * 1.01, r * 1.01, 0.035, (pos[0], pos[1] + h * k, pos[2]), "y", 10)


def lamp(p, pos, hang=0.9):
    x, y, z = pos
    p.box("Iron", (0.015, hang, 0.015), (x, y - hang / 2, z))
    p.cyl("Brass", 0.12, 0.06, 0.08, (x, y - hang - 0.02, z), "y", 8)
    p.cyl("LampGlow", 0.07, 0.07, 0.16, (x, y - hang - 0.14, z), "y", 8)
    p.cyl("Brass", 0.08, 0.10, 0.05, (x, y - hang - 0.24, z), "y", 8)


def railing(p, a, b, y, h=0.95, spacing=0.22):
    a, b = Vector(a), Vector(b)
    n = max(2, int((b - a).length / spacing))
    dirv = (b - a)
    yaw = math.atan2(-dirv.z, dirv.x)
    mid = (a + b) * 0.5
    p.box("DarkWood", (dirv.length + 0.08, 0.07, 0.09), (mid.x, y + h, mid.z), yaw=yaw)
    p.box("DarkWood", (dirv.length, 0.05, 0.06), (mid.x, y + 0.12, mid.z), yaw=yaw)
    for i in range(n + 1):
        q = a + dirv * (i / n)
        thick = 0.09 if i in (0, n) or i % 6 == 0 else 0.035
        p.box("DarkWood", (thick, h, thick), (q.x, y + h / 2, q.z))


# =============================================================================================================== the building
P = Piece("Bldg_Armory2")
# front wall around the double door (2.0 x 2.7) and the two display windows; side and back walls; floor
DOOR_W, DOOR_H = 2.0, 2.7
FRONT = [(0.0, DOOR_H / 2, DOOR_W, DOOR_H)] + [(sx * 3.3, 1.75, 2.2, 1.8) for sx in (-1, 1)] + [(x, H1 + 1.75, 1.0, 1.5) for x in (-3.3, 0.0, 3.3)]


def _front(m, ua, ub, va, vb):
    P.box(m, (ub - ua, vb - va, T), ((ua + ub) / 2, (va + vb) / 2, -T / 2))


wall_holes(P, "Siding", -HX, HX, HW, FRONT, _front)
SIDE_Z = (-3.5, -8.5)
SIDE = [(z, y, 1.0, 1.4) for z in SIDE_Z for y in (1.7, H1 + 1.7)]
for sx in (-1, 1):
    def _side(m, ua, ub, va, vb, sx=sx):
        P.box(m, (T, vb - va, ub - ua), (sx * (HX - T / 2), (va + vb) / 2, (ua + ub) / 2))
    wall_holes(P, "Siding", -D, 0.0, HW, SIDE, _side)
BACK = [(-3.0, H1 + 1.7, 1.0, 1.4), (3.0, H1 + 1.7, 1.0, 1.4)]


def _back(m, ua, ub, va, vb):
    P.box(m, (ub - ua, vb - va, T), ((ua + ub) / 2, (va + vb) / 2, -D + T / 2))


wall_holes(P, "Siding", -HX, HX, HW, BACK, _back)
P.box("Planks", (W, 0.2, D), (0, -0.1, -D / 2))
P.box("Planks", (W - 2 * T, 0.05, D - 2 * T), (0, 0.025, -D / 2))
P.box("Trim", (W - 2 * T, 0.1, D - 2 * T), (0, HW - 0.05, -D / 2))                      # upper ceiling
# windows: punched openings are faked by framing glass over the siding (cheap, reads right at street distance), but the display
# windows and the door are real openings: the front wall pieces above leave the door; the display windows get a dark "inside" box
for sx in (-1, 1):
    window(P, sx * 3.3, 1.75, 2.2, 1.8, 0.0, bars=7)
    window(P, sx * 3.3, H1 + 1.75, 1.0, 1.5, 0.0, shutters=True)
window(P, 0.0, H1 + 1.75, 1.0, 1.5, 0.0, shutters=True)
for sx in (-1, 1):                                                                        # side windows, both floors
    for zz in (-3.5, -8.5):
        keep = P.xf
        P.xf = P.at((sx * HX, 0, zz), yaw=sx * math.pi / 2)
        window(P, 0.0, 1.7, 1.0, 1.4, 0.0)
        window(P, 0.0, H1 + 1.7, 1.0, 1.4, 0.0)
        P.xf = keep
for xx in (-3.0, 3.0):                                                                    # back windows (upper)
    keep = P.xf
    P.xf = P.at((xx, 0, -D), yaw=math.pi)
    window(P, 0.0, H1 + 1.7, 1.0, 1.4, 0.0)
    P.xf = keep
# door frame and the double door: left leaf swung in, right leaf ajar
for sx in (-1, 1):
    P.box("Trim", (0.14, DOOR_H + 0.05, 0.26), (sx * (DOOR_W / 2 + 0.05), DOOR_H / 2, 0.02))
P.box("Trim", (DOOR_W + 0.4, 0.18, 0.3), (0, DOOR_H + 0.07, 0.03))
P.box("Trim", (DOOR_W + 0.1, 0.3, 0.06), (0, DOOR_H + 0.35, 0.05))                       # transom board
for sx, ang in ((-1, 1.25), (1, -1.2)):          # both leaves swung back inward: the doorway is fully clear
    keep = P.xf
    P.xf = P.at((sx * DOOR_W / 2, 0, -0.08), yaw=ang)
    P.box("DarkWood", (DOOR_W / 2 - 0.02, DOOR_H - 0.05, 0.06), (-sx * DOOR_W / 4, DOOR_H / 2, 0))
    P.box("GlassClear", (DOOR_W / 2 - 0.3, 0.9, 0.02), (-sx * DOOR_W / 4, 1.85, 0.035))
    for k in (0.45, 1.25):
        P.box("Trim", (DOOR_W / 2 - 0.2, 0.06, 0.08), (-sx * DOOR_W / 4, k, 0.04))
    P.cyl("Brass", 0.025, 0.025, 0.06, (-sx * (DOOR_W / 2 - 0.12), 1.05, 0.06), "z", 6)
    P.xf = keep
# corner boards, belt course between the floors, base board
for sx in (-1, 1):
    P.box("Trim", (0.22, HW, 0.22), (sx * (HX - 0.05), HW / 2, 0.0))
    P.box("Trim", (0.22, HW, 0.22), (sx * (HX - 0.05), HW / 2, -D + 0.05))
P.box("Trim", (W + 0.3, 0.2, 0.22), (0, H1, 0.04))
P.box("Trim", (W + 0.1, 0.3, 0.18), (0, 0.15, 0.03))
for sx in (-1, 1):
    P.box("Trim", (0.18, 0.2, D), (sx * (HX + 0.02), H1, -D / 2))
# false front, cornice with brackets, sign board, parapet cap
P.box("Siding", (W + 0.3, HF - HW, T), (0, HW + (HF - HW) / 2, 0.02))
P.box("Trim", (W + 0.8, 0.26, 0.5), (0, HF + 0.05, 0.14))
P.box("Trim", (W + 0.55, 0.14, 0.34), (0, HF - 0.22, 0.12))
for i in range(9):
    P.box("Trim", (0.16, 0.34, 0.34), (-HX + 0.4 + i * (W - 0.8) / 8, HF - 0.48, 0.15))
P.box("DarkWood", (6.6, 1.3, 0.1), (0, HW + 1.15, 0.14))
for yy in (HW + 1.15 + 0.8, HW + 1.15 - 0.8):
    P.box("Trim", (6.9, 0.14, 0.18), (0, yy, 0.16))
# gable roof behind the false front
ang = 0.38
half = (HX + 0.35) / math.cos(ang)
for sx in (-1, 1):
    P.box("Roof", (half, 0.07, D), (sx * (HX / 2 + 0.08), HW + math.tan(ang) * (HX / 2) + 0.03, -D / 2 - 0.3), roll=sx * ang)   # stops behind the false front
P.box("Siding", (W, math.tan(ang) * HX, T), (0, HW + math.tan(ang) * HX / 2, -D + T / 2))
# porch: boardwalk, three steps, posts with brackets, an awning that doubles as a little upper balcony with a rail
PD = 2.8
P.box("Planks", (W + 0.6, 0.24, PD), (0, 0.32, PD / 2))
for k in range(3):
    P.box("Planks", (3.2, 0.15, 0.32), (0, 0.075 + 0.15 * k * 0.0 + 0.15 * (2 - k) * 0.0 + 0.15 * k, PD + 0.16 + 0.32 * (2 - k)))
for i in range(4):
    x = -HX + 0.2 + i * (W - 0.4) / 3
    P.box("Trim", (0.2, H1 - 0.44, 0.2), (x, 0.44 + (H1 - 0.44) / 2, PD - 0.15))
    P.box("Trim", (0.34, 0.14, 0.34), (x, 0.5, PD - 0.15))
    for sx in (-1, 1):
        if -HX < x + sx * 0.3 < HX:
            P.box("Trim", (0.5, 0.1, 0.1), (x + sx * 0.22, H1 - 0.3, PD - 0.15), roll=-sx * 0.75)
P.box("Planks", (W + 0.6, 0.18, PD + 0.2), (0, H1 + 0.02, PD / 2))
P.box("Trim", (W + 0.6, 0.26, 0.18), (0, H1 - 0.1, PD + 0.05))
railing(P, (-HX - 0.2, 0, PD), (HX + 0.2, 0, PD), H1 + 0.1)
for sx in (-1, 1):
    railing(P, (sx * (HX + 0.2), 0, 0.15), (sx * (HX + 0.2), 0, PD), H1 + 0.1)
# hanging sign under the awning on two chains, between the middle posts
P.box("DarkWood", (2.6, 0.62, 0.06), (0, H1 - 0.95, PD - 0.15))
P.box("Trim", (2.75, 0.06, 0.08), (0, H1 - 0.62, PD - 0.15))
for sx in (-1, 1):
    P.box("Iron", (0.02, 0.5, 0.02), (sx * 1.1, H1 - 0.42, PD - 0.15))
P.empty("SignAnchor_ARMS", (0, HW + 1.15, 0.2))
P.empty("SignAnchor_ARMS_hang", (0, H1 - 0.95, PD - 0.11))
# door lanterns, longhorn skull over the door, posters and bullet holes beside it
for sx in (-1, 1):
    P.box("Iron", (0.05, 0.05, 0.32), (sx * 1.45, 2.35, 0.17))
    P.cyl("Brass", 0.11, 0.08, 0.06, (sx * 1.45, 2.32, 0.34), "y", 8)
    P.cyl("LampGlow", 0.07, 0.07, 0.2, (sx * 1.45, 2.18, 0.34), "y", 8)
    P.cyl("Iron", 0.09, 0.03, 0.12, (sx * 1.45, 2.4, 0.34), "y", 8)
P.cyl("Bone", 0.13, 0.09, 0.32, (0, DOOR_H + 0.75, 0.16), "y", 8)
for sx in (-1, 1):
    P.cyl("Bone", 0.07, 0.015, 0.75, (sx * 0.42, DOOR_H + 0.82, 0.16), "x", 6, yaw=0)
    P.cyl("Bone", 0.03, 0.01, 0.25, (sx * 0.82, DOOR_H + 0.98, 0.16), "y", 5)
for x, y in ((-1.75, 1.6), (1.8, 1.45), (-4.6, 1.5)):
    P.box("Paper", (0.42, 0.58, 0.01), (x, y, 0.005), roll=0.04 * x)
    P.box("Soot", (0.3, 0.06, 0.012), (x, y + 0.18, 0.006), roll=0.04 * x)
for x, y in ((-1.45, 2.05), (-1.62, 2.2), (2.2, 1.0), (4.1, 2.6), (-3.9, 3.1), (1.3, 3.0)):
    P.cyl("Soot", 0.02, 0.02, 0.02, (x, y, 0.004), "z", 6)
# ---- inside: the L-shaped gallery (back + left) at H1 with railings, its posts, the stair up the right wall, hanging lamps
GZ = -8.0          # back gallery front edge
GX = -2.6          # left gallery inner edge
P.box("Planks", (W - 2 * T, 0.22, D - 2 * T + GZ), (0, H1 - 0.11, (GZ + (-D + T)) / 2))       # back gallery slab
P.box("Planks", (GX + HX - T, 0.22, -GZ - T - 0.2), (( -HX + T + GX) / 2, H1 - 0.11, GZ / 2 - 0.1))   # left gallery slab
P.box("Trim", (W - 2 * T, 0.3, 0.12), (0, H1 - 0.2, GZ))                                    # fascia
P.box("Trim", (0.12, 0.3, -GZ - 0.4), (GX, H1 - 0.2, GZ / 2 - 0.2))
for x, z in ((GX, GZ), (GX, -2.0), (1.0, GZ), (3.4, GZ)):
    P.box("DarkWood", (0.22, H1 - 0.2, 0.22), (x, (H1 - 0.2) / 2, z))
railing(P, (GX, 0, GZ), (3.3, 0, GZ), H1)
railing(P, (GX, 0, GZ), (GX, 0, -0.6), H1)
# stair: 21 risers up the right wall from z = -2.4 (floor) to the back gallery at z = -8.0 (y = 3.8), 1.15 m wide
STAIR_X0, STAIR_X1 = 3.55, 4.7
n = 21
run = (GZ + 2.4) / n
for k in range(n):
    y = (k + 1) * H1 / n
    z = -2.4 + run * (k + 0.5)
    P.box("Planks", (STAIR_X1 - STAIR_X0, 0.05, abs(run) + 0.04), ((STAIR_X0 + STAIR_X1) / 2, y - 0.025, z))
    P.box("Trim", (STAIR_X1 - STAIR_X0, H1 / n, 0.03), ((STAIR_X0 + STAIR_X1) / 2, y - H1 / n / 2, z + abs(run) / 2))
slen = math.hypot(GZ + 2.4, H1)
sang = math.atan2(H1, -(GZ + 2.4))
P.box("DarkWood", (0.08, 0.3, slen), (STAIR_X0, H1 / 2 - 0.1, (GZ - 2.4) / 2), pitch=sang)
for k in range(0, n + 1, 3):
    y = k * H1 / n
    z = -2.4 + run * k
    P.box("DarkWood", (0.05, 0.95, 0.05), (STAIR_X0, y + 0.47, z))
P.box("DarkWood", (0.07, 0.07, slen), (STAIR_X0, H1 / 2 + 0.95, (GZ - 2.4) / 2), pitch=sang)
for k, (x, z) in enumerate(((-0.8, -3.2), (1.4, -5.6), (-1.0, -6.6), (0.5, -10.0), (-3.8, -5.0), (2.4, -10.4))):
    y_top = HW if z > GZ and x > GX else H1
    lamp(P, (x, y_top, z), 0.9 if y_top == HW else 0.5)
    P.empty("LightAnchor_%d" % k, (x, y_top - (0.9 if y_top == HW else 0.5) - 0.14, z))
root_b, tris_b = P.build()

# =============================================================================================================== the fit-out
F = Piece("Arm2_Fit")
# the long counter (Rich's side), glass-topped revolver section, brass rail
CZ = -5.2
F.box("DarkWood", (5.2, 1.0, 0.75), (-0.9, 0.5, CZ))
F.box("Trim", (5.4, 0.08, 0.9), (-0.9, 1.04, CZ))
for i in range(6):
    F.box("Trim", (0.06, 0.7, 0.02), (-3.3 + i * 0.95, 0.5, CZ + 0.385))
F.cyl("Brass", 0.022, 0.022, 5.2, (-0.9, 0.22, CZ + 0.45), "x", 6)
F.box("GlassClear", (1.9, 0.22, 0.7), (-2.4, 1.19, CZ))
F.box("Felt", (1.85, 0.02, 0.66), (-2.4, 1.09, CZ))
for i, fam in enumerate(("remington", "borchardt", "goldrev", "rem75", "remington")):          # the sidearms Rich sells, in the tray
    gun_flat(fam, -3.2 + i * 0.4, 1.10, CZ - 0.05, yaw=math.pi / 2 + (0.12 if i % 2 else -0.12))
F.box("Brass", (0.3, 0.25, 0.2), (0.9, 1.2, CZ))                                     # the scale / till
for i in range(3):
    F.box("Paper", (0.14, 0.09 + 0.02 * i, 0.09), (0.3 + i * 0.18, 1.12 + 0.05, CZ + 0.15))   # cartridge boxes on the counter
# glass revolver cases by the display windows
for sx in (-1, 1):
    x = sx * 3.2
    F.box("DarkWood", (1.6, 0.8, 0.7), (x, 0.4, -2.2))
    F.box("GlassClear", (1.6, 0.35, 0.7), (x, 0.98, -2.2))
    F.box("Felt", (1.55, 0.02, 0.65), (x, 0.81, -2.2))
    for i, fam in enumerate(("borchardt", "remington", "rem75", "goldrev") if sx < 0 else ("goldrev", "rem75", "remington", "borchardt")):
        gun_flat(fam, x - 0.55 + i * 0.37, 0.82, -2.2, yaw=math.pi / 2 + (0.15 if i % 2 else -0.15))
# the lit long-rifle case: Rich's Sharps Model 1874 Buffalo Gun (the day-88 long rifle), end of the counter
F.box("DarkWood", (0.5, 0.9, 1.7), (2.6, 0.45, CZ))
# its glass: four walls here, and the lid as its own piece (Arm2_CaseLid, below) so Rich can lift it to take the rifle out (founder 2026-11-07,
# "not tacky": the old one-piece glass box let the rifle pass through a closed case). Same outer box as before: 0.5 x 0.45 x 1.7 at y 0.905 - 1.355.
for sx in (-1, 1):
    F.box("GlassClear", (0.012, 0.436, 1.7), (2.6 + sx * 0.244, 1.123, CZ))
    F.box("GlassClear", (0.476, 0.436, 0.012), (2.6, 1.123, CZ + sx * 0.844))
F.box("Felt", (0.46, 0.02, 1.66), (2.6, 0.91, CZ))
# (the rifle itself is its own piece, Arm2_Sharps, built below: Rich lifts it out of the case in the introduction)
F.cyl("LampGlow", 0.02, 0.02, 1.5, (2.6, 1.34, CZ), "z", 6)
# ammunition shelves along the left wall, under the left gallery (by calibre: three shelves of boxes)
for k in range(4):
    F.box("DarkWood", (0.45, 0.04, 4.6), (-HX + T + 0.25, 0.5 + k * 0.6, -4.6))
F.box("DarkWood", (0.45, 2.3, 0.05), (-HX + T + 0.25, 1.15, -2.3))
F.box("DarkWood", (0.45, 2.3, 0.05), (-HX + T + 0.25, 1.15, -6.9))
for k in range(4):
    for j in range(14):
        F.box(("Paper", "Leather", "Dynamite", "Green")[(j + k) % 4] if k < 3 else "Brass", (0.3, 0.16, 0.24), (-HX + T + 0.25, 0.6 + k * 0.6, -2.6 - j * 0.31))
# rifles standing in barrels and powder kegs in the front corners
for x, z in ((-4.2, -0.9), (4.2, -1.0)):
    keg(F, (x, 0, z), 0.32, 0.8)
    for i in range(6):                   # butts down in the barrel, leaning out over its rim, lever side in
        a = i * math.pi / 3 + (0.3 if x > 0 else 0.0)
        fam = ("coach", "winchester", "bergmann", "coach", "winchester", "mp18")[(i + (2 if x > 0 else 0)) % 6]
        h = GUN_DIMS[fam]["x"] / 2
        lean = 0.12
        gun(fam, (x + (0.12 + h * math.sin(lean)) * math.cos(a), 0.3 + h * math.cos(lean), z + (0.12 + h * math.sin(lean)) * math.sin(a)),
            yaw=-a, roll=math.pi / 2 - lean)
for x, z in ((-3.4, -0.7), (-3.0, -1.1), (3.0, -6.6), (3.4, -6.9)):
    keg(F, (x, 0, z))
# the back wall under the gallery: three long racks of rifles (two rows), the cleaning bench
# (the short guns - coach guns, Tommys, machine pistols - stand on the low shelf, the long rifles above them, so no muzzle meets a shelf)
SHORT_ROW = ("coach", "tommy", "mp18", "bergmann")
LONG_ROW = ("winchester", "sharps", "winchester", "coach")
for r, x0 in enumerate((-3.6, -0.6, 2.2)):
    F.box("Felt", (2.6, 2.2, 0.08), (x0 + 1.2, 1.4, -D + T + 0.05))
    F.box("Trim", (2.75, 0.1, 0.12), (x0 + 1.2, 2.55, -D + T + 0.07))
    for row, y in enumerate((0.95, 2.05)):
        F.box("DarkWood", (2.6, 0.08, 0.2), (x0 + 1.2, y - 0.62, -D + T + 0.14))
        for i in range(6):
            k = r * 12 + row * 6 + i
            vy, vs = vary(k)
            gun_racked((SHORT_ROW, LONG_ROW)[row][(i + r) % 4], x0 + 0.1 + i * 0.44, y - 0.58, -D + T + 0.13, yaw=vy, scale=vs)
F.box("DarkWood", (2.0, 0.9, 0.7), (-3.2, 0.45, -9.6))                                 # cleaning bench
F.box("Felt", (1.9, 0.02, 0.6), (-3.2, 0.91, -9.6))
gun_flat("winchester", -3.2, 0.92, -9.6, yaw=0.15)                                       # a Winchester down for cleaning
F.box("Leather", (0.3, 0.12, 0.2), (-2.6, 0.98, -9.4))
F.box("Iron", (0.5, 0.25, 0.25), (-3.8, 1.03, -9.7))                                    # vice
# the gallery: rifle racks on the upper back and left walls, a Gatling gun at the rail, crates, Utah's bench and river gear
for r, x0 in enumerate((-4.2, -1.2, 1.8)):
    F.box("Felt", (2.6, 2.3, 0.08), (x0 + 1.2, H1 + 1.6, -D + T + 0.05))
    F.box("Trim", (2.75, 0.1, 0.12), (x0 + 1.2, H1 + 2.8, -D + T + 0.07))
    for row, y in enumerate((H1 + 1.1, H1 + 2.25)):
        F.box("DarkWood", (2.6, 0.08, 0.2), (x0 + 1.2, y - 0.62, -D + T + 0.14))
        for i in range(6):
            k = 40 + r * 12 + row * 6 + i
            vy, vs = vary(k)
            gun_racked((SHORT_ROW, LONG_ROW)[row][(i + r + 2) % 4], x0 + 0.1 + i * 0.44, y - 0.58, -D + T + 0.13, yaw=vy, scale=vs)
# the left gallery wall: two pegboards of sidearms (the second under the skiff only above it), Utah's bear longbow over them
SIDEARMS = ("remington", "borchardt", "goldrev", "rem75")
WALL_X = -HX + T + 0.09
for b, z0 in enumerate((-1.8, -4.6)):
    F.box("Felt", (0.08, 2.3, 2.4), (-HX + T + 0.05, H1 + 1.6, z0 - 1.1))
    rows = (H1 + 0.95, H1 + 1.4, H1 + 1.85, H1 + 2.3) if b == 0 else (H1 + 1.95,)
    for j, y in enumerate(rows):
        for i in range(5):
            gun_wall(SIDEARMS[(i + j + b) % 4], WALL_X, y, z0 - 0.3 - i * 0.44)
gun_wall("longbow", WALL_X, H1 + 2.45, -5.75)
# the Colt Gatling at the back gallery rail on its tripod, looking down on the shop
gun("gatling", (0.2, H1, GZ - 0.9), yaw=-math.pi / 2, near=True)
# the hero pieces on the gallery fascia over the counter: a Sharps and the golden Tommy, a Winchester on the short board
F.box("DarkWood", (2.8, 0.25, 0.06), (-0.6, H1 - 0.5, GZ + 0.09))
gun_fascia("sharps", -1.3, H1 - 0.5, GZ + 0.12)
gun_fascia("tommy", 0.2, H1 - 0.5, GZ + 0.12)
F.box("DarkWood", (1.8, 0.2, 0.06), (2.0, H1 - 0.85, GZ + 0.09))
gun_fascia("winchester", 2.0, H1 - 0.85, GZ + 0.12)
# crates of dynamite and cartridges stacked on the gallery, Utah's bench, sealed river crates and a skiff hung on the left wall
for i, (x, z, s) in enumerate(((-4.0, -10.8, (0.9, 0.5, 0.6)), (-4.0, -10.8, (0.8, 0.45, 0.55)), (-3.0, -11.0, (0.9, 0.5, 0.6)),
                               (-4.1, -7.6, (0.7, 0.45, 0.5)), (-4.1, -6.6, (0.7, 0.45, 0.5)))):
    crate(F, (x, H1 + (0.5 if i == 1 else 0.0), z), s, yaw=0.1 * i, label="Dynamite" if i % 2 == 0 else "Paper")
F.box("DarkWood", (2.0, 0.9, 0.8), (1.6, H1 + 0.45, -10.6))                               # Utah's bench
F.box("Felt", (1.9, 0.02, 0.7), (1.6, H1 + 0.91, -10.6))
gun_flat("sharps", 1.35, H1 + 0.92, -10.6, yaw=-0.2)                                     # Utah's work: a Sharps and a C93 down for cleaning
gun_flat("borchardt", 2.3, H1 + 0.92, -10.75, yaw=math.pi / 2)
for i in range(3):
    F.cyl("Brass", 0.03, 0.03, 0.12, (2.2 + i * 0.1, H1 + 0.97, -10.4), "y", 6)
for x, z in ((3.6, -10.9), (4.3, -10.2)):
    crate(F, (x, H1, z), (0.7, 0.55, 0.55), yaw=0.2, label="Brass")                     # sealed, buoyant river crates
    F.cyl("Rope", 0.29, 0.29, 0.05, (x, H1 + 0.3, z), "y", 10)
keep = F.xf
F.xf = F.at((-HX + T + 0.3, H1 + 1.4, -6.2), yaw=math.pi / 2, roll=0.0)
F.box("DarkWood", (3.2, 0.35, 0.7), (0, 0, 0))                                          # skiff on wall pegs, keel out
F.box("DarkWood", (3.6, 0.12, 0.5), (0, -0.2, 0))
F.box("Trim", (0.06, 0.1, 1.6), (0.4, 0.25, 0.0))
F.xf = keep
# bandoliers on wall hooks by the door, a chain across the stair foot (staff only)
for i in range(3):
    F.box("Leather", (0.08, 1.1, 0.04), (-4.7, 1.5, -1.6 - i * 0.25), roll=0.5)
    for j in range(8):
        F.cyl("Brass", 0.012, 0.012, 0.06, (-4.66, 1.1 + j * 0.1, -1.6 - i * 0.25), "z", 5)
for k in range(12):
    F.cyl("Iron", 0.02, 0.02, 0.07, (STAIR_X0 - 0.05 + 0.0, 0.85 - 0.08 * math.sin(k / 11 * math.pi), -2.3 + 0.0), "x", 5)
F.box("Iron", (1.25, 0.02, 0.02), ((STAIR_X0 + STAIR_X1) / 2, 0.8, -2.3))
F.box("Paper", (0.3, 0.16, 0.01), ((STAIR_X0 + STAIR_X1) / 2, 0.7, -2.28))
root_f, tris_f = F.build()
G.build()
# the case's glass lid, hinged along its far (+x) top edge; Hinge_case marks that edge's middle (the game turns the lid about the edge, which runs along z)
LID = Piece("Arm2_CaseLid")
LID.box("GlassClear", (0.5, 0.014, 1.7), (2.6, 1.348, CZ))
LID.box("Brass", (0.012, 0.012, 0.16), (2.36, 1.36, CZ - 0.25))                          # a brass pull on Rich's edge
LID.empty("Hinge_case", (2.85, 1.355, CZ))
root_lid, tris_lid = LID.build()
SH = Piece("Arm2_Sharps")
K.sharps(SH, (2.6, 1.012, CZ + 0.245), yaw=math.pi / 2)
root_sh, tris_sh = SH.build()

# =============================================================================================================== the navigation data
N = Piece("Arm2_Nav")
for name, pos in [("door", (0.0, 0.0, -0.4)), ("porch", (0.0, 0.0, 1.6)), ("lane", (0.0, 0.0, 4.5)), ("player", (0.2, 0.0, -3.4)),
                  ("counter_rich", (-0.9, 0.0, CZ - 0.75)), ("counter_till", (0.7, 0.0, CZ - 0.75)), ("case_revolvers", (-2.4, 0.0, CZ - 0.7)),
                  ("sniper_case", (2.0, 0.0, -6.25)), ("case_left", (-3.2, 0.0, -3.0)), ("case_right", (3.0, 0.0, -3.0)),
                  ("shelves", (-4.0, 0.0, -4.6)), ("rack_back", (-0.4, 0.0, -10.9)), ("bench", (-3.2, 0.0, -10.2)),
                  ("kegs", (2.6, 0.0, -6.2)), ("stair_bottom", (4.1, 0.0, -1.7)), ("stair_top", (4.1, H1, -8.6)),
                  ("gallery_rack", (-0.2, H1, -10.9)), ("gallery_crates", (-3.2, H1, -10.2)),
                  ("gallery_bench", (1.6, H1, -9.9)), ("gallery_river", (3.4, H1, -10.0)), ("gallery_window", (3.0, H1, -11.2)),
                  ("gallery_left", (-3.9, H1, -5.0)), ("well_view", (-1.6, H1, -8.6)), ("gallery_gatling", (-0.9, H1, -8.6)),
                  ("gap_left", (-3.95, 0.0, CZ)), ("gap_right", (3.22, 0.0, CZ)), ("behind_left", (-3.95, 0.0, -6.2)), ("behind_right", (3.25, 0.0, -6.2)), ("back_mid", (0.0, 0.0, -7.0)), ("front_mid", (0.0, 0.0, -1.6)),
                  ("stair_foot", (4.12, 0.0, -2.4)), ("stair_head", (4.12, H1, GZ))]:
    N.empty("Spot_" + name, pos)
for name, c, half in [("counter", (-0.9, CZ), (2.7, 0.45)), ("sniper_case", (2.6, CZ), (0.3, 0.9)), ("case_left", (-3.2, -2.2), (0.85, 0.4)),
                      ("case_right", (3.2, -2.2), (0.85, 0.4)), ("shelves", (-HX + T + 0.25, -4.6), (0.3, 2.35)),
                      ("stair", ((STAIR_X0 + STAIR_X1) / 2, (GZ - 2.4) / 2), (0.62, 2.85)), ("barrel_l", (-4.2, -0.9), (0.4, 0.4)),
                      ("barrel_r", (4.2, -1.0), (0.4, 0.4)), ("kegs_l", (-3.2, -0.9), (0.45, 0.45)), ("kegs_r", (3.2, -6.75), (0.45, 0.45)),
                      ("bench", (-3.2, -9.6), (1.05, 0.4)), ("rack_back", (0.0, -D + T + 0.14), (4.6, 0.2)),
                      ("post_a", (GX, GZ), (0.15, 0.15)), ("post_b", (GX, -2.0), (0.15, 0.15)), ("post_c", (1.0, GZ), (0.15, 0.15)),
                      ("post_d", (3.4, GZ), (0.15, 0.15))]:
    N.empty("Block_" + name, (c[0], 0.0, c[1]), (half[0], 1.0, half[1]))
N.build()

# export just these three pieces
for o in bpy.context.scene.objects:
    o.select_set(o.name.split(".")[0].split("_geo")[0] in ("Bldg_Armory2", "Arm2_Fit", "Arm2_Guns", "Arm2_Nav", "Arm2_Sharps", "Arm2_CaseLid") or (o.parent and o.parent.name in ("Bldg_Armory2", "Arm2_Fit", "Arm2_Guns", "Arm2_Nav", "Arm2_Sharps", "Arm2_CaseLid")))
import os
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True, use_selection=True,
                          export_extras=False, export_cameras=False, export_lights=False)
print("@@{\"ok\": true, \"tris_building\": %d, \"tris_fit\": %d, \"out\": \"%s\", \"bytes\": %d}" % (tris_b, tris_f, OUT, os.path.getsize(OUT)))
