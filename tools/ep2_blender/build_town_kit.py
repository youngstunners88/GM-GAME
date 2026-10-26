"""GOLD-RUSH TOWN KIT (skills ep2-gold-rush-town, ep2-surface-to-town; founder target
artifacts/episode2-gold-mine/references/founder_2026-10-13_town/goldmine_town_target.jpg, Muapi street still
artifacts/episode2-gold-mine/references/fort_knox_prep/town_street/hero.jpg).

Headless bpy (`python3 tools/ep2_blender/build_town_kit.py`). ONE GLB of named pieces the Godot chambers place:
  Bldg_Certificates  two-storey false-front office, porch + posts, door you can walk through, a real interior (floor, walls, ceiling)
  Bldg_Saloon        two-storey false front with a balcony on posts, swing-door opening, a big interior (14 x 11 m)
  Bldg_Treasury      sandstone bank front: pilasters, pediment, double door (shut)
  Bldg_Armory        weathered arms shop: barred windows, muted sign, walk-in door, lean-to loading shed (side lane)
  Bldg_A / Bldg_B / Bldg_C / Bldg_D   street fillers (one / two storeys, different fronts, shut doors)
  Church             white clapboard church with steeple
  FortKnox           stone castle-fort: curtain walls + merlons, three towers, the gate arch (sits on a rock hill placed in Godot)
  HitchRail Wagon Trough LampPost Bench Boardwalk4m
  Int_Counter Int_Shelves Int_Desk Int_Stove Bar_Counter Bar_BackShelf Bar_Table Bar_Chair Bar_Piano
  Arm_Counter Arm_Rack Arm_Case Arm_SniperCase Arm_PowderKeg River_Crate River_Skiff
Every building's origin is the middle of its FRONT edge at street level; its front faces +Z (game frame). Sign boards carry an empty
child "SignAnchor_<WORD>" where Godot hangs the painted sign (a texture), so no text is modelled. Materials are NAMED and untextured
(Siding, Trim, Roof, Sandstone, FortStone, PaintWhite, Planks, Glass, Iron, Brass, Bottle, Mirror, Cloth, DarkWood); the chambers assign
triplanar textures. Frame: everything is written in GAME coordinates (x right, y up, z toward the street) and converted (x, -z, y).
"""
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/assets/town/town_kit.glb"
# --cad-trim (the streamed town_kit2 only, founder 2026-10-25 "better facades"): leave the box porch posts, cornice brackets, window heads
# and balcony balusters out and put a TrimAnchor-style empty where each was; Ep2GoldTown hangs the CAD trim (town_furniture.glb) there.
CAD_TRIM = "--cad-trim" in argv

bpy.ops.wm.read_factory_settings(use_empty=True)
MATS = {}


def mat(name, rgb, rough=0.85, metal=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    MATS[name] = m
    return m


for n, c, r, mt in [("Siding", (0.42, 0.33, 0.24), 0.9, 0.0), ("Trim", (0.30, 0.21, 0.14), 0.85, 0.0), ("Roof", (0.40, 0.37, 0.33), 0.6, 0.5),
                    ("Sandstone", (0.66, 0.54, 0.38), 0.9, 0.0), ("FortStone", (0.55, 0.50, 0.42), 0.95, 0.0), ("PaintWhite", (0.86, 0.84, 0.78), 0.8, 0.0),
                    ("Planks", (0.36, 0.28, 0.20), 0.9, 0.0), ("Iron", (0.16, 0.15, 0.14), 0.6, 0.7), ("Brass", (0.72, 0.55, 0.25), 0.35, 1.0),
                    ("Mirror", (0.75, 0.75, 0.72), 0.05, 1.0), ("Cloth", (0.45, 0.10, 0.08), 0.9, 0.0), ("DarkWood", (0.20, 0.12, 0.07), 0.55, 0.0),
                    ("Green", (0.10, 0.25, 0.14), 0.8, 0.0)]:
    mat(n, c, r, mt)
mat("Glass", (0.08, 0.09, 0.10), 0.1, 0.0)
mat("GlassDay", (0.40, 0.50, 0.55), 0.06, 0.0)      # openings pass: window glass that reads as glass in daylight (not a dark sticker)
mat("Dark", (0.025, 0.02, 0.016), 0.95, 0.0)       # the shaded room behind the glass of buildings with no interior
mat("Shutter", (0.16, 0.30, 0.20), 0.85, 0.0)
mat("Bottle", (0.25, 0.14, 0.05), 0.15, 0.0)
# shop interiors (founder 2026-10-24: "the interiors of the buildings in the town ... aren't detailed enough"): goods read by colour
for n, c, r, mt in [("TinRed", (0.55, 0.10, 0.07), 0.45, 0.6), ("TinBlue", (0.10, 0.20, 0.42), 0.45, 0.6), ("TinYellow", (0.70, 0.55, 0.12), 0.45, 0.6),
                    ("TinGreen", (0.12, 0.32, 0.16), 0.45, 0.6), ("Burlap", (0.52, 0.42, 0.28), 1.0, 0.0), ("Paper", (0.82, 0.74, 0.56), 0.95, 0.0),
                    ("Brick", (0.46, 0.22, 0.14), 0.95, 0.0), ("Ore", (0.32, 0.29, 0.26), 0.9, 0.1), ("Rug", (0.42, 0.13, 0.10), 1.0, 0.0),
                    ("Leather", (0.30, 0.16, 0.08), 0.6, 0.0), ("Candy", (0.80, 0.30, 0.40), 0.4, 0.0)]:
    mat(n, c, r, mt)


def G(p):
    """game (x, y, z) -> blender (x, -z, y)"""
    return Vector((p[0], -p[2], p[1]))


class Piece:
    def __init__(self, name):
        self.name = name
        self.bms = {}
        self.anchors = []
        self.yaw = 0.0                       # placement for the next primitives (game frame): rotation about y, then offset
        self.off = (0.0, 0.0, 0.0)

    def place(self, yaw=0.0, off=(0.0, 0.0, 0.0)):
        self.yaw, self.off = yaw, off

    def _pc(self, c):
        a = self.yaw
        x = c[0] * math.cos(a) + c[2] * math.sin(a)
        z = -c[0] * math.sin(a) + c[2] * math.cos(a)
        return (x + self.off[0], c[1] + self.off[1], z + self.off[2])

    def _bm(self, m):
        if m not in self.bms:
            self.bms[m] = bmesh.new()
        return self.bms[m]

    def box(self, m, size, centre, rot_y=0.0, rot_x=0.0, rot_z=0.0):
        """size (x, y, z) and centre in game frame; rotations in game frame (radians)."""
        bm = self._bm(m)
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector((size[0], size[2], size[1])), verts=tmp.verts)
        # game rot about y = blender rot about z; game x = blender x; game z = blender -y
        r = Matrix.Rotation(rot_y + self.yaw, 4, "Z") @ Matrix.Rotation(rot_x, 4, "X") @ Matrix.Rotation(-rot_z, 4, "Y")
        bmesh.ops.transform(tmp, matrix=Matrix.Translation(G(self._pc(centre))) @ r, verts=tmp.verts)
        self._merge(bm, tmp)

    def cyl(self, m, r1, r2, h, centre, axis="y", seg=10):
        bm = self._bm(m)
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
        rot = Matrix.Identity(4)
        if axis == "x":
            rot = Matrix.Rotation(math.pi / 2, 4, "Y")
        elif axis == "z":
            rot = Matrix.Rotation(math.pi / 2, 4, "X")
        bmesh.ops.transform(tmp, matrix=Matrix.Translation(G(centre)) @ rot, verts=tmp.verts)
        self._merge(bm, tmp)

    def _merge(self, bm, tmp):
        me = bpy.data.meshes.new("t")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def anchor(self, name, pos):
        self.anchors.append((name, pos))

    def trim_anchor(self, name, pos):
        """An empty where the streamed kit's CAD trim hangs (--cad-trim): at the current placement, turned with it."""
        self.anchors.append((name, self._pc(pos), self.yaw))

    def build(self):
        root = bpy.data.objects.new(self.name, None)
        bpy.context.scene.collection.objects.link(root)
        me = bpy.data.meshes.new(self.name + "_mesh")
        big = bmesh.new()
        names = list(self.bms.keys())
        for i, mname in enumerate(names):
            bm = self.bms[mname]
            for f in bm.faces:
                f.material_index = i
            me_tmp = bpy.data.meshes.new("t")
            bm.to_mesh(me_tmp)
            bm.free()
            n0 = len(big.faces)
            big.from_mesh(me_tmp)
            big.faces.ensure_lookup_table()
            for f in big.faces[n0:]:
                f.material_index = i
            bpy.data.meshes.remove(me_tmp)
        big.to_mesh(me)
        big.free()
        for mname in names:
            me.materials.append(MATS[mname])
        ob = bpy.data.objects.new(self.name + "_geo", me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = root
        for a in self.anchors:
            e = bpy.data.objects.new(a[0], None)
            bpy.context.scene.collection.objects.link(e)
            e.parent = root
            e.location = G(a[1])
            if len(a) > 2 and abs(a[2]) > 1e-9:
                e.rotation_euler = (0.0, 0.0, a[2])          # game yaw about y = blender about z
        return root


T = 0.14   # wall thickness


def wall_holes(p, m, u0, u1, h, holes, place):
    """A wall rectangle u0..u1 x 0..h built in boxes AROUND its openings (real holes, not a skin). holes: [(uc, vc, w, h)];
    place(ua, ub, va, vb) -> one box in the caller's wall frame."""
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


def window(p, x, y, w=0.9, h=1.4, zf=0.0, shutters=True, sill_out=0.12, backing=False, lintel=None):
    """A real window in a hole of the front plane (z = zf .. zf - T): pale reveal frame lining the hole, a recessed pane of day-glass,
    a muntin cross, a projecting sill and head, open shutters flush to the wall either side, optionally a dark room behind (no interior)."""
    P = "PaintWhite"
    for sx in (-1, 1):
        p.box(P, (0.07, h + 0.02, T + 0.05), (x + sx * (w / 2 - 0.035), y, zf - T / 2 + 0.02))
    p.box(P, (w, 0.07, T + 0.05), (x, y + h / 2 - 0.035, zf - T / 2 + 0.02))
    p.box(P, (w, 0.06, T + 0.02), (x, y - h / 2 + 0.03, zf - T / 2))
    p.box("GlassDay", (w - 0.14, h - 0.14, 0.025), (x, y, zf - T * 0.55))
    p.box(P, (0.035, h - 0.14, 0.04), (x, y, zf - T * 0.55 + 0.02))
    p.box(P, (w - 0.14, 0.035, 0.04), (x, y + 0.08, zf - T * 0.55 + 0.02))
    p.box(P, (w + 0.28, 0.07, sill_out + 0.06), (x, y - h / 2 - 0.04, zf + sill_out / 2 - 0.02))                  # the sill
    if CAD_TRIM and abs(w - 0.95) < 0.01 and not lintel:
        p.trim_anchor("HoodAnchor", (x, y + h / 2 + 0.02, zf))                                                    # the CAD hood
    else:
        p.box(P, (w + 0.24, 0.10, 0.12), (x, y + h / 2 + 0.07, zf + 0.04))                                       # the head
    if lintel:
        p.box(lintel, (w + 0.4, 0.14, 0.22), (x, y + h / 2 + 0.22, zf + 0.06))
    if shutters:
        for sx in (-1, 1):
            p.box("Shutter", (0.40, h, 0.05), (x + sx * (w / 2 + 0.24), y, zf + 0.03))
            for k in range(3):
                p.box("Trim", (0.34, 0.025, 0.02), (x + sx * (w / 2 + 0.24), y - h / 2 + 0.25 + k * (h - 0.5) / 2, zf + 0.065))
    if backing:
        p.box("Dark", (w - 0.1, h - 0.1, 0.03), (x, y, zf - T - 0.45))


def door_unit(p, x, w, hgt, style, zf=0.0):
    """The doorway's dressing (the hole itself is cut by shell): frame, threshold and, by style, leaves.
    open = walkable, no leaf; shut = one panelled leaf + knob + transom; double = two leaves, brass pulls, fan-light; batwing = two
    waist-high swing doors (the saloon)."""
    P = "PaintWhite"
    for sx in (-1, 1):
        p.box(P, (0.10, hgt + 0.05, T + 0.10), (x + sx * (w / 2 - 0.05), hgt / 2, zf - T / 2 + 0.03))
    p.box(P, (w + 0.10, 0.12, T + 0.12), (x, hgt + 0.02, zf - T / 2 + 0.04))
    p.box("Planks", (w + 0.1, 0.05, 0.50), (x, 0.025, zf + 0.20))                                               # threshold step
    if style == "shut":
        p.box("DarkWood", (w - 0.14, hgt - 0.62, 0.07), (x, (hgt - 0.62) / 2, zf - T * 0.45))
        for ty in (0.72, 1.55):
            p.box("Trim", (w - 0.44, 0.62, 0.025), (x, ty, zf - T * 0.45 + 0.05))
        p.box("Brass", (0.07, 0.07, 0.10), (x + w / 2 - 0.22, 1.02, zf - T * 0.45 + 0.08))
        p.box("GlassDay", (w - 0.30, 0.28, 0.02), (x, hgt - 0.46, zf - T * 0.45 + 0.04))
    elif style == "double":
        for sx in (-1, 1):
            p.box("DarkWood", (w / 2 - 0.09, hgt - 0.62, 0.07), (x + sx * (w / 4 - 0.015), (hgt - 0.62) / 2, zf - T * 0.45))
            for ty in (0.75, 1.65):
                p.box("Trim", (w / 2 - 0.32, 0.64, 0.025), (x + sx * (w / 4 - 0.015), ty, zf - T * 0.45 + 0.05))
            p.box("Brass", (0.05, 0.50, 0.07), (x + sx * 0.12, 1.1, zf - T * 0.45 + 0.09))
        p.box("GlassDay", (w - 0.24, 0.40, 0.02), (x, hgt - 0.40, zf - T * 0.45 + 0.04))
    elif style == "batwing":
        for sx in (-1, 1):
            p.box("DarkWood", (w / 2 - 0.04, 0.95, 0.045), (x + sx * (w / 4), 1.25, zf - T * 0.2), rot_y=sx * 0.55)
            p.box("Brass", (0.06, 0.06, 0.06), (x + sx * (w / 2 - 0.05), 1.25, zf - T * 0.2 + 0.03))


def shell(p, w, d, h, door_w, door_x=0.0, open_door=True, interior=False, mat_wall="Siding", wins=(), upper_wins=(), door_style=None,
          side_wins=True, back_wins=True, door_h=2.5):
    """The walls of a building whose front plane is z = 0 and back is z = -d. Every opening is a real hole in the wall (wall_holes):
    the door in the front, ground and upper windows, and (side_wins) windows in both side walls and (back_wins) the back, so the
    building reads as inhabited from the lane and from behind."""
    hw = w / 2
    style = door_style or ("open" if open_door else "shut")
    ww, wh = 0.95, 1.45
    front = [(door_x, door_h / 2, door_w, door_h)]
    front += [(x, 1.6, ww, wh) for x in wins] + [(x, h - 1.6, ww, wh) for x in upper_wins]

    def fplace(m, ua, ub, va, vb):
        p.box(m, (ub - ua, vb - va, T), ((ua + ub) / 2, (va + vb) / 2, -T / 2))
    wall_holes(p, mat_wall, -hw, hw, h, front, fplace)
    door_unit(p, door_x, door_w, door_h, style)
    for x in wins:
        window(p, x, 1.6, ww, wh, 0.0, backing=not interior)
    for x in upper_wins:
        window(p, x, h - 1.6, ww, wh, 0.0, backing=not interior)
    # side + back walls with their own openings
    zs = [-d * 0.30, -d * 0.68] if side_wins else []
    sholes = [(z, 1.6, ww, wh) for z in zs] + ([(z, h - 1.6, ww, wh) for z in zs] if h > 5.5 else [])
    for sx in (-1, 1):
        def splace(m, ua, ub, va, vb, sx=sx):
            p.box(m, (T, vb - va, ub - ua), (sx * (hw - T / 2), (va + vb) / 2, (ua + ub) / 2))
        wall_holes(p, mat_wall, -d, 0.0, h, sholes, splace)
        for z, y, _, _ in sholes:
            p.place(sx * math.pi / 2, (sx * hw, 0.0, z))
            window(p, 0.0, y, ww, wh, 0.0, shutters=False, sill_out=0.08, backing=not interior)
            p.place()
    bholes = [(-hw * 0.5, 1.6, ww, wh), (hw * 0.5, 1.6, ww, wh)] if back_wins else []

    def bplace(m, ua, ub, va, vb):
        p.box(m, (ub - ua, vb - va, T), ((ua + ub) / 2, (va + vb) / 2, -d + T / 2))
    wall_holes(p, mat_wall, -hw, hw, h, bholes, bplace)
    for x, y, _, _ in bholes:
        p.place(math.pi, (x, 0.0, -d))
        window(p, 0.0, y, ww, wh, 0.0, shutters=False, sill_out=0.06, backing=not interior)
        p.place()
    # floor, ceiling, gable roof behind the false front
    p.box("Planks", (w, 0.2, d), (0.0, 0.1 - 0.2, -d / 2))
    if interior:
        p.box("Planks", (w - 2 * T, 0.06, d - 2 * T), (0.0, 0.03, -d / 2))
        p.box("Trim", (w - 2 * T, 0.08, d - 2 * T), (0.0, h - 0.04, -d / 2))
    ang = 0.42
    half = (w / 2 + 0.3) / math.cos(ang)
    for sx in (-1, 1):
        p.box("Roof", (half, 0.06, d + 0.4), (sx * (w / 4 + 0.075), h + math.tan(ang) * (w / 4) + 0.02, -d / 2), rot_z=-sx * ang)


def false_front(p, w, h_top, sign_word, sign_y, sign_w, sign_h, mat_wall="Siding", y0=0.0):
    """The flat false front ABOVE the roofline (y0 = the wall top) with a cornice, a sign board and its anchor. The slab used to run
    from the ground up and stood in front of every window and door (the blank boards, 2026-10-19), so it now starts at y0."""
    if h_top - y0 > 0.05:
        p.box(mat_wall, (w + 0.2, h_top - y0, T), (0.0, y0 + (h_top - y0) / 2, 0.02))
    p.box("Trim", (w + 0.6, 0.22, 0.45), (0.0, h_top + 0.05, 0.12))
    p.box("Trim", (w + 0.4, 0.12, 0.3), (0.0, h_top - 0.2, 0.1))
    for i in range(6):
        if CAD_TRIM:
            p.trim_anchor("CorbelAnchor", (-w / 2 + 0.3 + i * (w - 0.6) / 5, h_top - 0.26, 0.06))     # the CAD scroll corbel
        else:
            p.box("Trim", (0.14, 0.24, 0.3), (-w / 2 + 0.3 + i * (w - 0.6) / 5, h_top - 0.34, 0.12))
    if sign_word:
        p.box("DarkWood", (sign_w + 0.3, sign_h + 0.3, 0.1), (0.0, sign_y, 0.12))
        p.box("Trim", (sign_w + 0.45, 0.12, 0.16), (0.0, sign_y + sign_h / 2 + 0.17, 0.14))
        p.box("Trim", (sign_w + 0.45, 0.12, 0.16), (0.0, sign_y - sign_h / 2 - 0.17, 0.14))
        p.anchor("SignAnchor_" + sign_word, (0.0, sign_y, 0.19))


def porch(p, w, depth=2.6, h=3.0, posts=4, steps=True):
    p.box("Planks", (w + 0.4, 0.22, depth), (0.0, 0.33, depth / 2))
    for i in range(posts):
        x = -w / 2 + i * w / (posts - 1)
        if CAD_TRIM and abs(h - 3.0) < 1e-6:
            p.trim_anchor("PostAnchor", (x, 0.44, depth - 0.15))                              # the CAD chamfered post + brackets
            continue
        p.box("Trim", (0.18, h, 0.18), (x, 0.44 + h / 2, depth - 0.15))
        p.box("Trim", (0.32, 0.12, 0.32), (x, 0.47, depth - 0.15))
    p.box("Roof", (w + 0.6, 0.06, depth + 0.5), (0.0, 0.44 + h + 0.18, depth / 2), rot_x=0.12)
    p.box("Trim", (w + 0.4, 0.2, 0.16), (0.0, 0.44 + h, depth - 0.15))
    if steps:
        for k in range(2):
            p.box("Planks", (1.8, 0.16, 0.35), (0.0, 0.16 * (k + 0.5), depth + 0.18 + 0.35 * (1 - k)))


def building(name, w, d, storeys, h_front, sign_word=None, door_open=False, interior=False, balcony=False, mat_wall="Siding", door_style=None):
    p = Piece(name)
    h = 3.6 * storeys
    wins = (-w / 2 + 1.3, w / 2 - 1.3) if w > 6.5 else ()
    shell(p, w, d, h, 1.5 if not balcony else 1.9, 0.0, door_open, interior, mat_wall, wins,
          tuple(-w / 2 + 1.1 + i * (w - 2.2) / 2 for i in range(3)) if storeys > 1 else (), door_style=door_style)
    false_front(p, w, h_front, sign_word, h + (h_front - h) * 0.5 if h_front > h + 1.0 else h - 0.9, min(w - 1.2, 6.0), 1.0, mat_wall, y0=h)
    porch(p, w)
    if balcony:
        y = 3.6
        p.box("Planks", (w, 0.16, 1.6), (0.0, y + 0.3, 0.8))
        for i in range(int(w / 0.35)):
            if CAD_TRIM:
                p.trim_anchor("BalusterAnchor", (-w / 2 + 0.2 + i * 0.35, y + 0.38, 1.5))       # the CAD turned baluster
            else:
                p.box("Trim", (0.06, 0.9, 0.06), (-w / 2 + 0.2 + i * 0.35, y + 0.83, 1.5))
        p.box("Trim", (w, 0.08, 0.1), (0.0, y + 1.3, 1.5))
    return p


# --- the street ---------------------------------------------------------------------------------------------------------------
building("Bldg_Certificates", 8.0, 9.0, 2, 9.4, "CERTIFICATES", door_open=True, interior=True).build()
building("Bldg_Saloon", 12.0, 12.0, 2, 9.6, "SALOON", door_open=True, interior=True, balcony=True, door_style="batwing").build()
building("Bldg_A", 7.0, 8.0, 1, 6.2, "GENERAL", door_open=True, interior=True).build()     # walk-in shops (2026-10-24)
building("Bldg_B", 8.0, 9.0, 2, 8.6, "HOTEL", door_open=True, interior=True).build()
building("Bldg_C", 6.0, 8.0, 1, 5.6, "ASSAY", door_open=True, interior=True).build()
building("Bldg_D", 9.0, 9.0, 2, 9.0, "AUCTIONS").build()
building("Bldg_E", 7.0, 8.0, 1, 6.0, "STATS").build()
building("Bldg_F", 8.0, 9.0, 2, 8.4, "RESERVE").build()

# the Armory: Rich & Utah's shop. Weathered false front, barred windows, a muted sign, a walk-in door and a
# lean-to loading shed behind for kegs, crates and river gear. Sits on a side lane, off the Main Street sightline.
p = Piece("Bldg_Armory")
w, d, h = 8.0, 9.0, 7.2
shell(p, w, d, h, 1.4, 0.0, True, True, "Siding", (-w / 2 + 1.6, w / 2 - 1.6), (-w / 2 + 1.6, w / 2 - 1.6))
for wx in (-w / 2 + 1.6, w / 2 - 1.6):          # barred ground-floor windows
    for i in range(5):
        p.box("Iron", (0.045, 1.5, 0.045), (wx - 0.32 + i * 0.16, 1.6, 0.05))
false_front(p, w, h, "ARMS", h - 0.9, 4.2, 0.9, "Siding", y0=h)
porch(p, w)
p.box("Roof", (4.0, 0.06, 3.0), (0.0, 2.7, -d - 1.3), rot_z=0.18)     # lean-to loading shed, behind
for sx in (-1.7, 1.7):
    for sz in (-d - 0.2, -d - 2.6):
        p.box("Trim", (0.16, 2.5, 0.16), (sx, 1.25, sz))
p.build()

# the Treasury: sandstone, pilasters, pediment, shut double door
p = Piece("Bldg_Treasury")
w, d, h = 10.0, 12.0, 7.6
shell(p, w, d, h, 2.0, 0.0, False, False, "Sandstone", (-3.2, 3.2), (-3.2, 3.2), door_style="double", door_h=2.7)
for sx in (-1, 1):
    for kx in (1.25, 4.4):
        p.cyl("Sandstone", 0.32, 0.28, h - 0.6, (sx * kx, (h - 0.6) / 2 + 0.6, 0.35), "y", 14)
        p.box("Sandstone", (0.9, 0.6, 0.9), (sx * kx, 0.3, 0.35))
p.box("Sandstone", (w + 0.6, 0.7, 1.0), (0.0, h + 0.35, 0.3))
p.box("Sandstone", (w + 1.0, 1.4, 0.4), (0.0, h + 1.4, 0.1))
p.anchor("SignAnchor_TREASURY", (0.0, h + 1.4, 0.32))
for k in range(3):
    p.box("Sandstone", (5.0 - k * 0.6, 0.18, 0.5), (0.0, 0.09 + k * 0.18, 1.2 - k * 0.4))
p.build()

# the church
p = Piece("Church")
shell(p, 8.0, 14.0, 6.0, 1.6, 0.0, False, False, "PaintWhite", (-2.6, 2.6))
ang = 0.75
for sx in (-1, 1):
    p.box("Roof", (5.8, 0.08, 14.6), (sx * 2.05, 6.0 + 1.9, -7.0), rot_z=-sx * ang)
p.box("PaintWhite", (2.6, 4.0, 2.6), (0.0, 8.0, -0.9))
p.box("PaintWhite", (1.8, 2.6, 1.8), (0.0, 11.3, -0.9))
p.cyl("Roof", 1.35, 0.02, 4.4, (0.0, 14.8, -0.9), "y", 4)
p.box("PaintWhite", (0.1, 1.4, 0.1), (0.0, 17.6, -0.9))
p.box("PaintWhite", (0.8, 0.1, 0.1), (0.0, 17.8, -0.9))
p.cyl("Glass", 0.55, 0.55, 0.06, (0.0, 4.8, 0.03), "z", 16)
p.build()

# Fort Knox: curtain walls with merlons, three towers, the gate arch. Origin = middle of the gate at ground.
p = Piece("FortKnox")
W, D, H = 46.0, 30.0, 11.0


def merlons(p, x0, x1, z0, z1, y, m="FortStone"):
    n = int(max(abs(x1 - x0), abs(z1 - z0)) / 1.6)
    for i in range(n + 1):
        t = i / max(n, 1)
        if i % 2 == 0:
            p.box(m, (1.0, 1.1, 1.0), (x0 + (x1 - x0) * t, y + 0.55, z0 + (z1 - z0) * t))


for sx in (-1, 1):
    p.box("FortStone", (2.4, H, D), (sx * W / 2, H / 2, -D / 2))
    merlons(p, sx * W / 2, sx * W / 2, 0.0, -D, H)
p.box("FortStone", (W, H, 2.4), (0.0, H / 2, -D))
merlons(p, -W / 2, W / 2, -D, -D, H)
for sx in (-1, 1):
    p.box("FortStone", (W / 2 - 4.0, H, 2.4), (sx * (W / 4 + 2.0), H / 2, 0.0))
p.box("FortStone", (8.0, H - 6.5, 2.4), (0.0, 6.5 + (H - 6.5) / 2, 0.0))
p.box("DarkWood", (5.6, 6.2, 0.3), (0.0, 3.1, -0.4))
merlons(p, -W / 2, W / 2, 0.0, 0.0, H)
for (tx, tz, tw, th) in [(-W / 2, 0.0, 7.0, 17.0), (W / 2, 0.0, 7.0, 17.0), (0.0, -D, 9.0, 21.0), (-5.5, 0.0, 5.0, 15.0), (5.5, 0.0, 5.0, 15.0)]:
    p.box("FortStone", (tw, th, tw), (tx, th / 2, tz))
    p.box("FortStone", (tw + 0.8, 0.8, tw + 0.8), (tx, th + 0.4, tz))
    for cx in (-1, 1):
        merlons(p, tx - tw / 2, tx + tw / 2, tz + cx * tw / 2, tz + cx * tw / 2, th + 0.8)
        merlons(p, tx + cx * tw / 2, tx + cx * tw / 2, tz - tw / 2, tz + tw / 2, th + 0.8)
    for wy in (th * 0.45, th * 0.7):
        p.box("Glass", (0.5, 1.4, 0.2), (tx, wy, tz + tw / 2 + 0.02))
p.box("DarkWood", (6.0, 0.9, 0.2), (0.0, 13.2, 1.3))
p.anchor("SignAnchor_FORTKNOX", (0.0, 13.2, 1.42))
for fx, fy, fz in [(-W / 2, 18.6, 0.0), (0.0, 22.6, -D), (W / 2, 18.6, 0.0)]:
    p.box("Iron", (0.12, 4.0, 0.12), (fx, fy + 2.0, fz))
    p.anchor("FlagAnchor", (fx + 0.9, fy + 3.4, fz))
p.build()

# --- street props -----------------------------------------------------------------------------------------------------------
p = Piece("HitchRail")
for sx in (-1, 1):
    p.box("Trim", (0.16, 1.1, 0.16), (sx * 1.4, 0.55, 0.0))
p.cyl("Trim", 0.07, 0.07, 3.2, (0.0, 1.0, 0.0), "x", 8)
p.build()

p = Piece("Wagon")
p.box("Planks", (1.6, 0.12, 3.4), (0.0, 1.0, 0.0))
for sx in (-1, 1):
    p.box("Planks", (0.06, 0.55, 3.4), (sx * 0.8, 1.33, 0.0))
for ez in (-1, 1):
    p.box("Planks", (1.6, 0.55, 0.06), (0.0, 1.33, ez * 1.7))
for sx in (-1, 1):
    for wz, r in ((1.2, 0.55), (-1.2, 0.7)):
        p.cyl("DarkWood", r, r, 0.08, (sx * 0.95, r, wz), "x", 18)
        p.cyl("Iron", r + 0.03, r + 0.03, 0.06, (sx * 0.97, r, wz), "x", 18)
        p.cyl("Trim", 0.1, 0.1, 0.2, (sx * 0.95, r, wz), "x", 8)
p.box("Trim", (0.1, 0.1, 2.2), (0.0, 0.7, 2.6), rot_x=0.15)
p.box("Iron", (1.9, 0.08, 0.08), (0.0, 0.62, 1.2))
p.box("Iron", (1.9, 0.08, 0.08), (0.0, 0.75, -1.2))
p.build()

p = Piece("Trough")
p.box("Planks", (2.2, 0.08, 0.7), (0.0, 0.25, 0.0))
for sx in (-1, 1):
    p.box("Planks", (2.2, 0.55, 0.06), (0.0, 0.5, sx * 0.35))
    p.box("Planks", (0.06, 0.55, 0.7), (sx * 1.1, 0.5, 0.0))
p.box("Glass", (2.1, 0.02, 0.6), (0.0, 0.66, 0.0))
p.build()

p = Piece("LampPost")
p.box("DarkWood", (0.16, 3.4, 0.16), (0.0, 1.7, 0.0))
p.box("DarkWood", (0.7, 0.08, 0.08), (0.3, 3.3, 0.0))
p.box("Iron", (0.28, 0.4, 0.28), (0.62, 3.0, 0.0))
p.anchor("LampLight", (0.62, 3.0, 0.0))
p.build()

p = Piece("Bench")
p.box("Planks", (1.8, 0.06, 0.45), (0.0, 0.48, 0.0))
p.box("Planks", (1.8, 0.4, 0.05), (0.0, 0.85, -0.2), rot_x=-0.15)
for sx in (-1, 1):
    p.box("Trim", (0.08, 0.48, 0.4), (sx * 0.8, 0.24, 0.0))
p.build()

p = Piece("Boardwalk4m")
p.box("Planks", (4.0, 0.12, 2.4), (0.0, 0.36, 0.0))
for sx in (-1, 1):
    p.box("Trim", (0.2, 0.36, 0.2), (sx * 1.8, 0.18, 1.0))
p.build()

# --- interiors ------------------------------------------------------------------------------------------------------------
p = Piece("Int_Counter")    # the certificate office counter: panelled front, top, a brass bell anchor
p.box("DarkWood", (4.0, 1.05, 0.7), (0.0, 0.525, 0.0))
p.box("Trim", (4.2, 0.07, 0.85), (0.0, 1.09, 0.0))
for i in range(5):
    p.box("Trim", (0.62, 0.62, 0.04), (-1.6 + i * 0.8, 0.55, 0.37))
p.anchor("BellAnchor", (1.3, 1.13, 0.1))
p.build()

p = Piece("Int_Shelves")    # pigeonholes of rolled certificates
p.box("DarkWood", (3.0, 2.4, 0.4), (0.0, 1.2, -0.2))
for r in range(6):
    p.box("Trim", (3.0, 0.04, 0.42), (0.0, 0.3 + r * 0.38, -0.18))
for c in range(9):
    p.box("Trim", (0.04, 2.2, 0.42), (-1.5 + c * 0.375, 1.2, -0.18))
for r in range(5):
    for c in range(8):
        if (r * 7 + c * 3) % 4 != 0:
            p.cyl("PaintWhite", 0.05, 0.05, 0.36, (-1.31 + c * 0.375, 0.5 + r * 0.38, -0.15), "z", 6)
p.build()

p = Piece("Int_Desk")
p.box("DarkWood", (1.8, 0.06, 0.9), (0.0, 0.78, 0.0))
for sx in (-1, 1):
    p.box("DarkWood", (0.5, 0.75, 0.85), (sx * 0.6, 0.375, 0.0))
p.anchor("LampAnchor", (0.6, 0.81, -0.2))
p.build()

p = Piece("Int_Stove")
p.cyl("Iron", 0.32, 0.32, 0.9, (0.0, 0.55, 0.0), "y", 14)
p.cyl("Iron", 0.08, 0.08, 2.4, (0.0, 2.2, 0.0), "y", 8)
for a in range(3):
    p.box("Iron", (0.05, 0.25, 0.05), (0.22 * math.cos(a * 2.1), 0.12, 0.22 * math.sin(a * 2.1)))
p.build()

p = Piece("Bar_Counter")     # 8 m saloon bar, front along +z, with a brass foot rail
p.box("DarkWood", (8.0, 1.12, 0.75), (0.0, 0.56, 0.0))
p.box("DarkWood", (8.3, 0.08, 0.95), (0.0, 1.16, 0.05))
for i in range(10):
    p.box("Trim", (0.6, 0.7, 0.04), (-3.6 + i * 0.8, 0.6, 0.39))
p.cyl("Brass", 0.035, 0.035, 8.0, (0.0, 0.2, 0.55), "x", 8)
for i in range(6):
    p.box("Brass", (0.03, 0.2, 0.03), (-3.5 + i * 1.4, 0.1, 0.55))
p.build()

p = Piece("Bar_BackShelf")   # shelves of bottles round a big mirror
p.box("DarkWood", (6.0, 3.0, 0.4), (0.0, 1.5, -0.2))
p.box("Mirror", (2.6, 1.6, 0.04), (0.0, 1.9, 0.02))
for sx in (-1, 1):
    for r in range(4):
        y = 0.9 + r * 0.55
        p.box("Trim", (1.6, 0.04, 0.38), (sx * 2.15, y, 0.0))
        for b in range(7):
            p.cyl("Bottle", 0.04, 0.035, 0.3, (sx * 2.15 - 0.72 + b * 0.24, y + 0.17, 0.02), "y", 8)
p.box("Trim", (6.4, 0.14, 0.5), (0.0, 3.05, -0.05))
p.build()

p = Piece("Bar_Table")
p.cyl("DarkWood", 0.55, 0.55, 0.05, (0.0, 0.76, 0.0), "y", 16)
p.cyl("DarkWood", 0.06, 0.06, 0.74, (0.0, 0.37, 0.0), "y", 8)
p.cyl("DarkWood", 0.32, 0.32, 0.04, (0.0, 0.02, 0.0), "y", 12)
p.build()

p = Piece("Bar_Chair")
p.box("DarkWood", (0.42, 0.04, 0.42), (0.0, 0.46, 0.0))
p.box("DarkWood", (0.42, 0.5, 0.04), (0.0, 0.73, -0.2))
for sx in (-1, 1):
    for sz in (-1, 1):
        p.box("DarkWood", (0.04, 0.46, 0.04), (sx * 0.18, 0.23, sz * 0.18))
p.build()

p = Piece("Bar_Piano")
p.box("DarkWood", (1.5, 1.3, 0.6), (0.0, 0.65, 0.0))
p.box("PaintWhite", (1.3, 0.04, 0.16), (0.0, 0.74, 0.36))
for i in range(18):
    p.box("Iron", (0.025, 0.045, 0.1), (-0.6 + i * 0.07, 0.765, 0.33))
p.build()

# --- the armory interior + river gear --------------------------------------------------------------------------------------
p = Piece("Arm_Counter")     # the trade counter: panelled front, top, a brass round anchor
p.box("DarkWood", (5.0, 1.05, 0.7), (0.0, 0.525, 0.0))
p.box("Trim", (5.2, 0.07, 0.85), (0.0, 1.09, 0.0))
for i in range(7):
    p.box("Trim", (0.6, 0.62, 0.04), (-2.1 + i * 0.7, 0.55, 0.37))
p.anchor("TradeAnchor", (0.0, 1.13, 0.2))
p.build()

p = Piece("Arm_Rack")        # wall rack of lever rifles: backboard + three silhouettes
p.box("DarkWood", (2.4, 1.9, 0.12), (0.0, 1.0, -0.06))
for i in range(3):
    x = -0.75 + i * 0.75
    p.box("Iron", (0.05, 1.5, 0.05), (x, 1.05, 0.02))
    p.box("DarkWood", (0.09, 0.8, 0.10), (x, 0.5, 0.03))
    p.box("Brass", (0.10, 0.12, 0.12), (x, 0.95, 0.03))
p.build()

p = Piece("Arm_Case")        # glass case of revolvers on a wooden pedestal
p.box("DarkWood", (2.0, 0.9, 0.8), (0.0, 0.45, 0.0))
p.box("Trim", (2.06, 0.06, 0.86), (0.0, 0.92, 0.0))
p.box("Glass", (2.0, 0.5, 0.8), (0.0, 1.23, 0.0))
for i in range(3):
    p.box("Iron", (0.34, 0.05, 0.05), (-0.7 + i * 0.7, 1.05, 0.0))
    p.cyl("DarkWood", 0.09, 0.09, 0.12, (-0.7 + i * 0.7, 1.02, 0.2), "x", 12)
p.build()

p = Piece("Arm_SniperCase")  # the lit case for the period long rifle
p.box("DarkWood", (2.6, 0.2, 0.7), (0.0, 0.5, 0.0))
p.box("Glass", (2.6, 1.4, 0.7), (0.0, 1.3, 0.0))
p.box("Iron", (1.9, 0.06, 0.06), (0.0, 1.2, 0.0))
p.box("Brass", (0.14, 0.16, 0.16), (0.7, 1.2, 0.0))
# the period long rifle itself, laid across the case on two cradles: a long octagon barrel, a
# walnut stock, a set trigger and a brass tube sight. It is what Rich sells for the day-88
# overlook, so the silhouette has to read from the shop floor.
for cx in (-0.75, 0.55):                              # the display cradles
    p.box("Trim", (0.16, 0.10, 0.24), (cx, 1.06, 0.0))
    p.box("Trim", (0.16, 0.06, 0.12), (cx, 1.14, 0.0))
RY = 1.30                                             # the rifle lies along x on the cradles
p.box("DarkWood", (0.46, 0.16, 0.13), (-0.92, RY - 0.01, 0.0))          # butt
p.box("DarkWood", (0.30, 0.11, 0.12), (-0.60, RY + 0.01, 0.0))          # wrist of the stock
p.box("DarkWood", (0.72, 0.09, 0.11), (0.06, RY, 0.0))                  # fore-stock
p.box("Iron", (0.34, 0.13, 0.14), (-0.30, RY, 0.0))                     # receiver
p.cyl("Iron", 0.028, 0.024, 1.30, (0.72, RY, 0.0), "x", 12)             # long barrel
p.box("Iron", (0.10, 0.05, 0.06), (1.36, RY, 0.0))                      # muzzle crown
p.cyl("Brass", 0.030, 0.030, 0.36, (0.14, RY + 0.10, 0.0), "x", 10)     # brass tube sight
p.box("Brass", (0.05, 0.10, 0.05), (-0.02, RY + 0.06, 0.0))             # sight mount
p.box("Brass", (0.20, 0.05, 0.05), (-0.30, RY - 0.09, 0.0))             # set trigger / lever
p.box("Iron", (0.05, 0.10, 0.05), (-0.44, RY + 0.06, 0.0))              # hammer
p.anchor("SniperAnchor", (0.0, 1.95, 0.0))
p.build()

p = Piece("Arm_PowderKeg")   # powder keg with brass hoops
p.cyl("DarkWood", 0.34, 0.34, 0.8, (0.0, 0.4, 0.0), "y", 16)
for y in (0.18, 0.62):
    p.cyl("Brass", 0.355, 0.355, 0.05, (0.0, y, 0.0), "y", 16)
p.cyl("Iron", 0.08, 0.08, 0.06, (0.0, 0.82, 0.0), "y", 8)
p.build()

p = Piece("River_Crate")     # sealed buoyant river crate: planked box with rope lashings
p.box("Planks", (1.1, 0.7, 0.8), (0.0, 0.35, 0.0))
p.box("Trim", (1.16, 0.08, 0.86), (0.0, 0.35, 0.0))
for sx in (-0.4, 0.4):
    p.box("Cloth", (0.06, 0.74, 0.84), (sx, 0.35, 0.0))
p.build()

p = Piece("River_Skiff")     # flat-bottom river skiff with thwarts and a raised stem
p.box("Planks", (1.5, 0.16, 4.6), (0.0, 0.22, 0.0))
for sx in (-1, 1):
    p.box("Planks", (0.14, 0.55, 4.6), (sx * 0.68, 0.5, 0.0), rot_z=-sx * 0.06)
for sz in (-1.3, 0.1, 1.5):
    p.box("Planks", (1.3, 0.06, 0.34), (0.0, 0.62, sz))
p.box("Planks", (0.22, 1.0, 1.1), (0.0, 0.8, -2.5), rot_x=0.5)
p.build()

# --- the walk-in shops (founder 2026-10-24: "differences in the buildings and interiors thereof are particular ... people ... entering the
# stores and leaving, buying things"). Each shop's trade reads from the door: the general store's walls of tins and sacks, the hotel's desk
# and key board under its stair, the assay office's grilled counter, scales and furnace. Placed by Ep2GoldTown._furnish (local frames).
def tin_row(p, x0, y, z, n, step=0.15, r=0.055, h=0.16):
    cols = ["TinRed", "TinBlue", "TinYellow", "TinGreen"]
    for i in range(n):
        p.cyl(cols[(i * 7 + int(y * 10)) % 4], r, r, h, (x0 + i * step, y + h / 2, z), "y", 10)


p = Piece("Gen_Counter")       # long counter, brass scale, candy jars, coffee mill, the till; front along +z
p.box("DarkWood", (3.6, 0.98, 0.72), (0.0, 0.49, 0.0))
p.box("Trim", (3.8, 0.06, 0.86), (0.0, 1.01, 0.0))
for i in range(4):
    p.box("Trim", (0.78, 0.62, 0.035), (-1.35 + i * 0.9, 0.5, 0.37))
p.box("GlassDay", (1.0, 0.5, 0.04), (-1.1, 0.66, 0.37))                          # a glass front panel showing goods
for i in range(5):
    p.box(["TinRed", "Paper", "TinYellow", "Burlap", "TinBlue"][i], (0.16, 0.12, 0.14), (-1.45 + i * 0.18, 0.5, 0.25))
p.box("Brass", (0.34, 0.03, 0.26), (0.9, 1.06, 0.05))                            # scale platform
p.box("Brass", (0.05, 0.36, 0.05), (1.02, 1.24, -0.04))
p.cyl("Brass", 0.15, 0.12, 0.05, (0.9, 1.44, 0.05), "y", 14)                     # scoop pan
for i, c in enumerate(["Candy", "TinYellow", "TinGreen"]):
    p.cyl("GlassDay", 0.09, 0.09, 0.26, (-0.6 + i * 0.24, 1.17, -0.12), "y", 12)   # jars
    p.cyl(c, 0.075, 0.075, 0.16, (-0.6 + i * 0.24, 1.12, -0.12), "y", 10)       # what is in them
    p.cyl("Brass", 0.095, 0.095, 0.03, (-0.6 + i * 0.24, 1.315, -0.12), "y", 12)
p.box("Iron", (0.22, 0.24, 0.22), (0.15, 1.16, -0.15))                           # coffee mill
p.cyl("Iron", 0.12, 0.12, 0.02, (0.15, 1.34, -0.15), "z", 12)
p.box("Brass", (0.48, 0.34, 0.34), (1.45, 1.21, -0.12))                          # the till
for k in range(8):
    p.box("PaintWhite", (0.05, 0.03, 0.05), (1.29 + (k % 4) * 0.1, 1.40, -0.03 + (k // 4) * 0.08))
p.cyl("Paper", 0.07, 0.07, 0.42, (-1.55, 1.12, -0.2), "x", 10)                   # wrapping paper roll
p.anchor("CustomerSpot", (0.0, 0.0, 0.9))
p.anchor("KeeperSpot", (0.4, 0.0, -0.8))
p.build()

p = Piece("Gen_Shelves")       # the back wall of goods: five shelves of tins, boxes and bottles
p.box("DarkWood", (4.6, 2.7, 0.42), (0.0, 1.35, -0.21))
for r in range(6):
    p.box("Trim", (4.6, 0.04, 0.44), (0.0, 0.25 + r * 0.46, -0.19))
for c in range(5):
    p.box("Trim", (0.05, 2.6, 0.44), (-2.28 + c * 1.14, 1.35, -0.19))
for r in range(5):
    y = 0.27 + r * 0.46
    for bay in range(4):
        x0 = -2.15 + bay * 1.14
        kind = (r + bay) % 3
        if kind == 0:
            tin_row(p, x0 + 0.05, y, -0.12, 6)
        elif kind == 1:
            for k in range(4):
                p.box(["Paper", "TinRed", "Burlap", "TinBlue"][(k + r) % 4], (0.2, 0.26 - 0.03 * (k % 2), 0.26), (x0 + 0.13 + k * 0.24, y + 0.13, -0.13))
        else:
            for k in range(6):
                p.cyl("Bottle", 0.04, 0.035, 0.28, (x0 + 0.1 + k * 0.17, y + 0.14, -0.12), "y", 8)
p.build()

p = Piece("Gen_FloorGoods")    # sacks of flour and beans, the cracker barrel, a crate of apples, the tool rack, a coil of rope
for i, (x, z) in enumerate([(-0.5, 0.0), (0.1, 0.15), (-0.2, 0.62)]):
    p.cyl("Burlap", 0.24, 0.3, 0.72 - 0.08 * i, (x, 0.36 - 0.04 * i, z), "y", 10)
    p.cyl("Burlap", 0.12, 0.2, 0.14, (x, 0.76 - 0.08 * i, z), "y", 8)
p.cyl("DarkWood", 0.3, 0.27, 0.78, (1.0, 0.39, 0.0), "y", 14)                   # cracker barrel
for y in (0.12, 0.66):
    p.cyl("Iron", 0.305, 0.305, 0.04, (1.0, y, 0.0), "y", 14)
p.cyl("Trim", 0.3, 0.3, 0.03, (1.0, 0.8, 0.0), "y", 14)
p.box("Planks", (0.6, 0.32, 0.42), (1.0, 0.16, 0.8))                            # apple crate
for k in range(6):
    p.cyl("TinRed", 0.05, 0.05, 0.08, (0.8 + (k % 3) * 0.18, 0.34, 0.68 + (k // 3) * 0.2), "y", 8)
p.box("DarkWood", (0.1, 1.5, 0.1), (-1.4, 0.75, -0.3))                         # tool rack: two posts and a rail
p.box("DarkWood", (0.1, 1.5, 0.1), (-1.4, 0.75, 0.9))
p.box("DarkWood", (0.08, 0.08, 1.3), (-1.4, 1.3, 0.3))
for k in range(4):
    z = -0.15 + k * 0.3
    p.box("Planks", (0.04, 1.3, 0.04), (-1.33, 0.68, z), rot_z=0.12)            # handles leaning on the rail
    p.box("Iron", (0.03, 0.3, 0.22) if k % 2 == 0 else (0.03, 0.12, 0.42), (-1.26, 0.12, z))   # shovel blades / pick heads
p.cyl("Burlap", 0.28, 0.28, 0.16, (0.0, 0.08, -0.6), "y", 14)                   # rope coil
p.build()

p = Piece("Hotel_Desk")        # the front desk, register, bell, and the key board with its brass keys on the wall behind
p.box("DarkWood", (2.4, 1.05, 0.7), (0.0, 0.525, 0.0))
p.box("Trim", (2.6, 0.06, 0.82), (0.0, 1.08, 0.0))
for i in range(3):
    p.box("Trim", (0.66, 0.66, 0.035), (-0.78 + i * 0.78, 0.53, 0.36))
p.box("Leather", (0.42, 0.04, 0.3), (-0.3, 1.13, 0.05))                          # the register, open
p.box("Paper", (0.38, 0.012, 0.27), (-0.3, 1.155, 0.05))
p.cyl("Brass", 0.06, 0.07, 0.06, (0.55, 1.14, 0.12), "y", 12)                   # the bell
p.cyl("Brass", 0.012, 0.012, 0.03, (0.55, 1.185, 0.12), "y", 6)
p.box("DarkWood", (1.8, 1.2, 0.06), (0.0, 1.9, -0.95))                          # key board
for r in range(3):
    for c in range(6):
        x = -0.75 + c * 0.3
        y = 2.3 - r * 0.38
        p.box("Brass", (0.02, 0.02, 0.06), (x, y, -0.9))
        if (r * 6 + c) % 4 != 1:                                                  # a few rooms are out: no key
            p.box("Brass", (0.035, 0.13, 0.012), (x, y - 0.08, -0.88))
            p.box("Paper", (0.06, 0.05, 0.01), (x, y - 0.17, -0.88))
p.anchor("CustomerSpot", (0.0, 0.0, 0.85))
p.anchor("KeeperSpot", (0.3, 0.0, -0.6))
p.build()

p = Piece("Hotel_Stairs")      # the stair to the rooms: rising along -z from the front, a stringer each side, newel posts and a rail
n = 14
for i in range(n):
    p.box("Planks", (1.1, 0.06, 0.32), (0.0, 0.2 + i * 0.25, -0.3 - i * 0.3))
    p.box("DarkWood", (1.1, 0.25, 0.03), (0.0, 0.08 + i * 0.25, -0.15 - i * 0.3))
for sx in (-1, 1):
    p.box("DarkWood", (0.06, 0.3, n * 0.31), (sx * 0.58, 1.85, -0.3 - n * 0.15), rot_x=math.atan2(0.25, 0.3))
p.box("Trim", (0.12, 1.1, 0.12), (-0.62, 0.55, -0.1))                           # newel post
for i in range(0, n, 2):
    p.box("Trim", (0.035, 0.85, 0.035), (-0.6, 0.6 + i * 0.25, -0.3 - i * 0.3))   # balusters
p.box("Trim", (0.07, 0.07, n * 0.39), (-0.6, 1.4 + n * 0.125, -0.3 - n * 0.15), rot_x=math.atan2(0.25, 0.3))
p.build()

p = Piece("Hotel_Lounge")      # a settee and a side table on a rug, a potted cactus, a spittoon
p.box("Rug", (2.4, 0.015, 1.6), (0.0, 0.008, 0.0))
p.box("DarkWood", (1.6, 0.14, 0.62), (0.0, 0.38, -0.3))
p.box("Cloth", (1.5, 0.12, 0.56), (0.0, 0.5, -0.28))
p.box("Cloth", (1.5, 0.5, 0.12), (0.0, 0.78, -0.56))
for sx in (-1, 1):
    p.box("DarkWood", (0.1, 0.55, 0.62), (sx * 0.78, 0.55, -0.3))
    for sz in (-0.55, -0.05):
        p.box("DarkWood", (0.06, 0.32, 0.06), (sx * 0.72, 0.16, sz))
p.cyl("DarkWood", 0.3, 0.3, 0.04, (1.4, 0.62, 0.3), "y", 14)
p.cyl("DarkWood", 0.04, 0.04, 0.6, (1.4, 0.31, 0.3), "y", 8)
p.cyl("Brick", 0.17, 0.13, 0.3, (-1.4, 0.15, 0.4), "y", 12)                     # cactus in a clay pot
p.cyl("Green", 0.08, 0.1, 0.62, (-1.4, 0.6, 0.4), "y", 10)
p.cyl("Green", 0.045, 0.05, 0.28, (-1.27, 0.7, 0.4), "y", 8)
p.cyl("Brass", 0.12, 0.09, 0.2, (0.95, 0.1, -0.7), "y", 12)                     # spittoon
p.build()

p = Piece("Assay_Counter")     # the assay counter behind a brass grille, the balance in its glass case, ore samples, the ledger
p.box("DarkWood", (3.8, 1.0, 0.7), (0.0, 0.5, 0.0))
p.box("Trim", (4.0, 0.06, 0.82), (0.0, 1.03, 0.0))
for i in range(19):                                                               # the grille, a pass-through window in the middle
    x = -1.8 + i * 0.2
    if abs(x) > 0.35:
        p.box("Brass", (0.02, 0.8, 0.02), (x, 1.46, 0.3))
p.box("Brass", (3.8, 0.04, 0.04), (0.0, 1.88, 0.3))
p.box("Brass", (0.74, 0.04, 0.04), (0.0, 1.5, 0.3))
for sx in (-1, 1):                                                                # the balance in its glass case
    p.box("GlassDay", (0.03, 0.5, 0.42), (1.0 + sx * 0.32, 1.31, -0.1))
p.box("GlassDay", (0.66, 0.03, 0.42), (1.0, 1.57, -0.1))
p.box("Brass", (0.04, 0.34, 0.04), (1.0, 1.23, -0.1))
p.box("Brass", (0.48, 0.02, 0.02), (1.0, 1.4, -0.1))
for sx in (-1, 1):
    p.cyl("Brass", 0.07, 0.07, 0.015, (1.0 + sx * 0.22, 1.24, -0.1), "y", 12)
for k in range(5):                                                               # ore samples on the counter, flecks of gold
    p.box("Ore", (0.12, 0.08, 0.1), (-1.3 + k * 0.17, 1.1, -0.15 + (k % 2) * 0.1), rot_y=0.4 * k)
    p.box("Brass", (0.03, 0.02, 0.03), (-1.28 + k * 0.17, 1.15, -0.13 + (k % 2) * 0.1))
p.box("Leather", (0.36, 0.05, 0.26), (-0.55, 1.08, 0.12))
p.anchor("CustomerSpot", (0.0, 0.0, 0.85))
p.anchor("KeeperSpot", (0.0, 0.0, -0.7))
p.build()

p = Piece("Assay_Furnace")     # the brick assay furnace, its iron door glowing, crucibles and tongs on the hearth
p.box("Brick", (1.3, 1.2, 1.0), (0.0, 0.6, 0.0))
p.box("Brick", (1.4, 0.12, 1.1), (0.0, 1.26, 0.0))
p.box("Iron", (0.5, 0.42, 0.04), (0.0, 0.62, 0.51))
p.box("Candy", (0.3, 0.12, 0.02), (0.0, 0.66, 0.535))                           # the glow at the door's slot (warm in the shop lamp)
p.cyl("Iron", 0.12, 0.12, 2.4, (0.0, 2.5, -0.2), "y", 10)                       # flue
for k in range(3):
    p.cyl("Iron", 0.07, 0.05, 0.12, (-0.45 + k * 0.2, 1.38, 0.3), "y", 10)       # crucibles
p.box("Iron", (0.03, 0.03, 0.7), (0.55, 1.35, 0.1), rot_y=0.3)                   # tongs
p.build()

p = Piece("Assay_Shelves")     # samples in labelled trays, jars of reagent, a mortar and pestle
p.box("DarkWood", (2.6, 2.2, 0.4), (0.0, 1.1, -0.2))
for r in range(5):
    p.box("Trim", (2.6, 0.04, 0.42), (0.0, 0.25 + r * 0.45, -0.18))
for r in range(4):
    y = 0.27 + r * 0.45
    for k in range(6):
        if (r + k) % 3 == 0:
            p.cyl("GlassDay", 0.06, 0.06, 0.2, (-1.05 + k * 0.42, y + 0.1, -0.12), "y", 10)
        else:
            p.box("Paper", (0.3, 0.05, 0.22), (-1.05 + k * 0.42, y + 0.025, -0.13))
            p.box("Ore", (0.1, 0.07, 0.08), (-1.05 + k * 0.42, y + 0.08, -0.13), rot_y=0.5 * k)
p.cyl("Ore", 0.1, 0.08, 0.1, (0.9, 2.12, -0.12), "y", 12)
p.build()

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True)
print("wrote", OUT)
