"""THE JAILHOUSE (founder lock PROMPT_EPISODE2_JAILHOUSE_BEARS_INVESTIGATION, 2026-10-20; skill ep2-jailhouse).

Headless bpy:  blender -b --factory-startup -P tools/ep2_blender/build_jailhouse.py -- [--out src/episode2/extras/jail/jailhouse.glb]

One GLB, three named pieces (same conventions as build_town_kit.py / build_armory2.py: origin = middle of the FRONT edge at street
level, front faces +Z in the game frame, named untextured materials that Ep2GoldTown._apply_mats skins - FortStone, Trim, Roof, Planks):
  Bldg_Jail   a small grey-stone jailhouse, 7.4 x 8.6 m: real hole-cut openings (open iron-strapped plank door, two barred front
              windows, barred side windows, high barred cell windows), parapet, brass sheriff's star over the door, lanterns, a hung sign
              board with SignAnchor_JAIL, wanted posters. Inside: an office (desk, chair, rifle rack, stove, key hook, wanted board) and a
              two-cell block behind a bar line - cell A (the accomplice's: cot, bucket, ankle ring) and cell B (empty).
  Jail_Fit    nothing separate (the fit-out is part of Bldg_Jail so it moves with the row) - kept as an empty root for symmetry.
  Jail_Nav    empties: Spot_<name> (NPC/player stand points), Block_<name> (scale = half extents of a walk blocker, floor plane),
              LightAnchor_<n> (warm lamp positions).
All written in GAME coordinates (x right, y up, z toward the street) and converted once at the end.
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "src/episode2/extras/jail/jailhouse.glb"

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
                    ("Felt", (0.12, 0.26, 0.16), 0.95, 0.0), ("Rope", (0.55, 0.45, 0.30), 0.95, 0.0), ("Soot", (0.05, 0.045, 0.04), 0.95, 0.0)]:
    mat(n, c, r, mt)
mat("FortStone", (0.55, 0.50, 0.42), 0.95, 0.0)
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
            e.location = (p.x, -p.z, p.y)
            e.scale = (s[0], s[2], s[1])
        return root, tris



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



T = 0.18                         # wall thickness (stone)
W, D = 7.4, 8.6
H = 3.9                          # wall height; parapet to 4.7
HX = W / 2
DOOR_W, DOOR_H = 1.5, 2.6
WALL = "FortStone"
BAR_Y = 3.4                      # bar height in the cell line


def window(p, x, y, w, h, zf, bars=5, glass=False, face=1.0):
    """A real window in a hole of the wall plane at z = zf (wall behind it z = zf .. zf - T): stone reveal frame, heavy iron bars set in
    the opening, a sill and a lintel. Jail windows carry bars and no glass (a dark clear pane only when glass=True)."""
    s = face
    for sx in (-1, 1):
        p.box("Trim", (0.10, h + 0.02, T + 0.05), (x + sx * (w / 2 - 0.05), y, zf - T / 2 + 0.02))
    p.box("Trim", (w, 0.10, T + 0.05), (x, y + h / 2 - 0.05, zf - T / 2 + 0.02))
    p.box("Trim", (w, 0.08, T + 0.04), (x, y - h / 2 + 0.04, zf - T / 2))
    if glass:
        p.box("GlassClear", (w - 0.2, h - 0.2, 0.03), (x, y, zf - T * 0.6))
    for i in range(bars):
        p.box("Iron", (0.05, h + 0.12, 0.05), (x - w / 2 + 0.13 + i * (w - 0.26) / max(bars - 1, 1), y, zf - T * 0.35))
    for yy in (y - h / 4, y + h / 4):
        p.box("Iron", (w - 0.1, 0.045, 0.05), (x, yy, zf - T * 0.35))
    p.box("Trim", (w + 0.28, 0.08, 0.17), (x, y - h / 2 - 0.05, zf + 0.06))
    p.box("Trim", (w + 0.30, 0.16, 0.14), (x, y + h / 2 + 0.10, zf + 0.04))


def lamp(p, pos, hang=0.7):
    x, y, z = pos
    p.box("Iron", (0.015, hang, 0.015), (x, y - hang / 2, z))
    p.cyl("Brass", 0.11, 0.06, 0.08, (x, y - hang - 0.02, z), "y", 8)
    p.cyl("LampGlow", 0.065, 0.065, 0.15, (x, y - hang - 0.13, z), "y", 8)
    p.cyl("Brass", 0.075, 0.095, 0.05, (x, y - hang - 0.22, z), "y", 8)


def rifle(p, pos, yaw=0.0, roll=0.0, scale=1.0):
    keep = p.xf
    p.xf = keep @ p.at(pos, yaw, 0.0, roll) @ Matrix.Scale(scale, 4)
    p.box("GunWood", (0.38, 0.13, 0.05), (-0.45, -0.045, 0))
    p.box("Brass", (0.02, 0.135, 0.052), (-0.645, -0.045, 0))
    p.box("Brass", (0.18, 0.07, 0.045), (-0.10, 0.0, 0))
    p.cyl("GunSteel", 0.015, 0.015, 0.78, (0.39, 0.015, 0), "x", 6)
    p.box("GunWood", (0.30, 0.035, 0.04), (0.12, -0.005, 0))
    p.xf = keep


# =============================================================================================================== the building
P = Piece("Bldg_Jail")
FRONT = [(0.0, DOOR_H / 2, DOOR_W, DOOR_H)] + [(sx * 2.35, 1.95, 1.1, 1.2) for sx in (-1, 1)]


def _front(m, ua, ub, va, vb):
    P.box(m, (ub - ua, vb - va, T), ((ua + ub) / 2, (va + vb) / 2, -T / 2))


wall_holes(P, WALL, -HX, HX, H, FRONT, _front)
SIDE = [(-2.1, 1.95, 0.9, 1.1), (-6.4, 2.7, 0.7, 0.5)]
for sx in (-1, 1):
    def _side(m, ua, ub, va, vb, sx=sx):
        P.box(m, (T, vb - va, ub - ua), (sx * (HX - T / 2), (va + vb) / 2, (ua + ub) / 2))
    wall_holes(P, WALL, -D, 0.0, H, SIDE, _side)
BACK = [(-2.0, 2.7, 0.7, 0.5), (2.0, 2.7, 0.7, 0.5)]


def _back(m, ua, ub, va, vb):
    P.box(m, (ub - ua, vb - va, T), ((ua + ub) / 2, (va + vb) / 2, -D + T / 2))


wall_holes(P, WALL, -HX, HX, H, BACK, _back)
for x, y in [(sx * 2.35, 1.95) for sx in (-1, 1)]:
    window(P, x, y, 1.1, 1.2, 0.0, bars=6)
for z in (-2.1,):
    for sx in (-1, 1):
        P.xf = P.at((sx * HX, 0, z), yaw=sx * math.pi / 2)
        window(P, 0.0, 1.95, 0.9, 1.1, 0.0, bars=5)
        P.xf = Matrix.Identity(4)
for sx in (-1, 1):
    P.xf = P.at((sx * HX, 0, -6.4), yaw=sx * math.pi / 2)
    window(P, 0.0, 2.7, 0.7, 0.5, 0.0, bars=4)
    P.xf = Matrix.Identity(4)
for x in (-2.0, 2.0):
    P.xf = P.at((x, 0, -D), yaw=math.pi)
    window(P, 0.0, 2.7, 0.7, 0.5, 0.0, bars=4)
    P.xf = Matrix.Identity(4)
# floor, ceiling, roof slab with a stone parapet
P.box("Planks", (W, 0.2, D), (0, -0.1, -D / 2))
P.box("Planks", (W - 2 * T, 0.05, D - 2 * T), (0, 0.025, -D / 2))
P.box("Trim", (W - 2 * T, 0.10, D - 2 * T), (0, H - 0.05, -D / 2))
P.box("Roof", (W + 0.4, 0.14, D + 0.4), (0, H + 0.07, -D / 2))
for sx in (-1, 1):
    P.box(WALL, (0.22, 0.75, D + 0.4), (sx * (HX + 0.09), H + 0.375, -D / 2))
P.box(WALL, (W + 0.4, 0.75, 0.22), (0, H + 0.375, -D + 0.1))
P.box(WALL, (W + 0.4, 1.35, 0.26), (0, H + 0.675, 0.05))                      # the taller front parapet
P.box("Trim", (W + 0.6, 0.16, 0.42), (0, H + 1.38, 0.10))
P.box("Trim", (W + 0.5, 0.14, 0.30), (0, H + 0.06, 0.10))
for sx in (-1, 1):
    P.box(WALL, (0.6, 0.4, 0.6), (sx * (HX - 0.1), H + 1.6, 0.05))            # corner finials
# door frame and an open iron-strapped plank door (one leaf swung back inward)
for sx in (-1, 1):
    P.box("Trim", (0.14, DOOR_H + 0.05, T + 0.12), (sx * (DOOR_W / 2 + 0.05), DOOR_H / 2, -T / 2 + 0.04))
P.box("Trim", (DOOR_W + 0.40, 0.16, T + 0.12), (0, DOOR_H + 0.05, -T / 2 + 0.04))
P.box("Planks", (DOOR_W + 0.3, 0.05, 0.5), (0, 0.025, 0.22))
P.xf = P.at((-DOOR_W / 2, 0, -0.10), yaw=1.2)
P.box("DarkWood", (DOOR_W - 0.06, DOOR_H - 0.06, 0.09), (DOOR_W / 2 - 0.03, DOOR_H / 2, 0))
for yy in (0.4, 1.3, 2.2):
    P.box("Iron", (DOOR_W - 0.12, 0.10, 0.03), (DOOR_W / 2 - 0.03, yy, 0.06))
P.cyl("Iron", 0.035, 0.035, 0.05, (DOOR_W - 0.22, 1.1, 0.07), "z", 6)
P.xf = Matrix.Identity(4)
# the sheriff's star over the door (five brass arms + disc), the sign board, lanterns, wanted posters
for k in range(5):
    a = k * 2 * math.pi / 5
    P.box("Brass", (0.16, 0.55, 0.05), (0.34 * math.sin(a), DOOR_H + 0.95 + 0.34 * math.cos(a), 0.17), roll=-a)
P.cyl("Brass", 0.20, 0.20, 0.06, (0, DOOR_H + 0.95, 0.18), "z", 16)
P.box("DarkWood", (3.5, 0.62, 0.10), (0, DOOR_H + 0.40, 0.14))
P.box("Trim", (3.7, 0.08, 0.14), (0, DOOR_H + 0.76, 0.16))
P.box("Trim", (3.7, 0.08, 0.14), (0, DOOR_H + 0.04, 0.16))
P.empty("SignAnchor_JAIL", (0, DOOR_H + 0.40, 0.20))
for sx in (-1, 1):
    P.box("Iron", (0.05, 0.05, 0.34), (sx * 1.2, 2.5, 0.19))
    P.cyl("Brass", 0.11, 0.08, 0.06, (sx * 1.2, 2.47, 0.36), "y", 8)
    P.cyl("LampGlow", 0.07, 0.07, 0.2, (sx * 1.2, 2.33, 0.36), "y", 8)
for x, y, r in ((-1.45, 1.55, 0.05), (1.55, 1.45, -0.04), (-3.3, 1.4, 0.03)):
    P.box("Paper", (0.40, 0.55, 0.012), (x, y, 0.006), roll=r)
    P.box("Soot", (0.30, 0.07, 0.014), (x, y + 0.17, 0.007), roll=r)
# ---- inside: the office
P.box("DarkWood", (1.5, 0.80, 0.85), (1.7, 0.40, -2.6))                          # desk
P.box("Trim", (1.6, 0.06, 0.95), (1.7, 0.82, -2.6))
P.box("Paper", (0.45, 0.012, 0.32), (1.5, 0.865, -2.55), yaw=0.2)
P.cyl("Brass", 0.05, 0.05, 0.12, (2.0, 0.90, -2.4), "y", 8)
P.box("DarkWood", (0.5, 0.06, 0.5), (1.65, 0.48, -3.55))                        # chair
P.box("DarkWood", (0.5, 0.55, 0.06), (1.65, 0.78, -3.82))
for sx in (-1, 1):
    for sz in (-1, 1):
        P.box("DarkWood", (0.05, 0.46, 0.05), (1.65 + sx * 0.21, 0.23, -3.55 + sz * 0.21))
P.box("Felt", (0.30, 1.3, 1.8), (-HX + T + 0.16, 1.5, -2.6))                      # the rifle rack on the left wall
for i in range(3):
    rifle(P, (-HX + T + 0.34, 1.0 + i * 0.28, -2.6 + (i - 1) * 0.5), yaw=math.pi / 2, roll=math.pi / 2 - 0.05, scale=1.0)
P.cyl("Iron", 0.30, 0.34, 0.75, (-2.95, 0.375, -1.0), "y", 10)                    # the stove
P.cyl("Iron", 0.06, 0.06, 2.6, (-2.95, 2.1, -1.0), "y", 8)
P.box("Felt", (0.05, 1.0, 1.5), (HX - T - 0.04, 1.8, -2.2))                       # the wanted board on the right wall
for i in range(4):
    P.box("Paper", (0.015, 0.34, 0.26), (HX - T - 0.075, 2.1 - (i % 2) * 0.45 + (i // 2) * 0.05, -1.8 - (i // 2) * 0.55), roll=0.05 * i)
P.box("Iron", (0.05, 0.30, 0.18), (0.2, 1.8, -4.82))                            # key hook beside the bar line
for k in range(3):
    P.cyl("Iron", 0.03, 0.03, 0.14, (0.2, 1.7 - k * 0.06, -4.76), "z", 5)
# ---- the bar line (z = -4.9) with a shut door per cell, the cell divider, two cots, a bucket
BZ = -4.9
for y in (0.12, 1.2, 2.3, BAR_Y):
    P.box("Iron", (W - 2 * T, 0.09, 0.09), (0, y, BZ))
n = 29
for i in range(n + 1):
    x = -HX + T + 0.06 + i * (W - 2 * T - 0.12) / n
    if abs(abs(x) - 1.85) < 0.5:
        continue                                  # leave the two cell doors (drawn below as framed grilles)
    P.box("Iron", (0.045, BAR_Y, 0.045), (x, BAR_Y / 2, BZ))
for sx in (-1, 1):
    cx = sx * 1.85
    for dx in (-0.46, 0.46):
        P.box("Iron", (0.09, BAR_Y - 0.4, 0.09), (cx + dx, (BAR_Y - 0.4) / 2 + 0.12, BZ + 0.02))
    P.box("Iron", (0.95, 0.09, 0.09), (cx, 2.75, BZ + 0.02))
    P.box("Iron", (0.95, 0.09, 0.09), (cx, 0.30, BZ + 0.02))
    for k in range(6):
        P.box("Iron", (0.035, 2.5, 0.035), (cx - 0.35 + k * 0.14, 1.5, BZ + 0.02))
    P.box("Brass", (0.12, 0.16, 0.08), (cx + 0.34, 1.10, BZ + 0.09))                      # the lock
P.box("Iron", (0.09, BAR_Y, 0.09), (0, BAR_Y / 2, BZ))
for z in (-5.6, -6.4, -7.2, -8.0):                # the divider between the cells (bars)
    P.box("Iron", (0.045, BAR_Y, 0.045), (0, BAR_Y / 2, z))
for y in (0.12, 1.2, 2.3, BAR_Y):
    P.box("Iron", (0.09, 0.09, D - 2 * T - 4.0), (0, y, (BZ - D + T) / 2))
for sx in (-1, 1):
    P.box("DarkWood", (0.62, 0.06, 1.9), (sx * 2.5, 0.52, -7.3))                      # cots
    for sz in (-0.8, 0.8):
        P.box("DarkWood", (0.55, 0.52, 0.06), (sx * 2.5, 0.26, -7.3 + sz))
    P.box("Cloth", (0.58, 0.07, 1.2), (sx * 2.5, 0.585, -7.55))                        # a thin blanket
# the privy in cell A (founder 2026-10-24: "the toilet with flies in the jail house"): a plank box against the cell divider, its seat
# board cut round a dark hole, the lid hinged up against the bars, a stained slop bucket showing through the open front, a wet stain on
# the floor, and news-sheet scraps on a nail. Flies + their buzz are added by the game at Spot_privy (Ep2JailFlies).
PX, PZ = -0.42, -6.35                             # box centre: back against the divider (x = 0), seat faces into the cell (-x)
P.box("DarkWood", (0.62, 0.46, 0.06), (PX, 0.23, PZ - 0.30))                   # sides (box runs along z)
P.box("DarkWood", (0.62, 0.46, 0.06), (PX, 0.23, PZ + 0.30))
P.box("DarkWood", (0.06, 0.46, 0.66), (PX + 0.28, 0.23, PZ))                    # back panel against the divider
P.box("DarkWood", (0.06, 0.20, 0.66), (PX - 0.28, 0.36, PZ))                    # front apron (the bucket shows below it)
for sz, w_ in ((-0.21, 0.24), (0.21, 0.24)):                                      # seat board in two halves round the hole
    P.box("Trim", (0.64, 0.05, w_), (PX, 0.485, PZ + sz))
for sx_, w_ in ((-0.22, 0.20), (0.22, 0.20)):
    P.box("Trim", (w_, 0.05, 0.18), (PX + sx_, 0.485, PZ))
P.box("Soot", (0.24, 0.02, 0.24), (PX, 0.475, PZ))                               # the hole: black under the cut (square, like the cut)
P.box("Trim", (0.06, 0.62, 0.58), (PX + 0.30, 0.82, PZ), roll=0.0)              # lid, hinged up against the divider bars
P.cyl("Brass", 0.02, 0.02, 0.10, (PX + 0.30, 0.52, PZ - 0.22), "z", 6)          # two hinges
P.cyl("Brass", 0.02, 0.02, 0.10, (PX + 0.30, 0.52, PZ + 0.22), "z", 6)
P.cyl("Iron", 0.16, 0.13, 0.30, (PX - 0.04, 0.15, PZ), "y", 12)                 # slop bucket under the seat
P.cyl("Soot", 0.13, 0.13, 0.01, (PX - 0.04, 0.305, PZ), "y", 12)                # what's in it
P.cyl("Soot", 0.34, 0.30, 0.004, (PX - 0.36, 0.003, PZ + 0.08), "y", 14)        # the wet stain spreading out in front
P.cyl("Iron", 0.008, 0.008, 0.07, (-0.06, 1.05, PZ - 0.52), "x", 5)             # a nail on the divider post ...
for k in range(3):                                                                # ... and torn news-sheet hung on it
    P.box("Paper", (0.012, 0.16, 0.13), (-0.03 - 0.004 * k, 0.98 - 0.01 * k, PZ - 0.52 + 0.012 * k), roll=0.08 * k - 0.06)
P.cyl("Iron", 0.045, 0.045, 0.30, (-2.5, 0.20, -5.35), "z", 6)                        # ankle ring + chain on the floor of cell A
P.cyl("Iron", 0.18, 0.18, 0.03, (-2.5, 0.02, -5.30), "y", 12)
# warm lamps: the office and the cell corridor
for k, (x, z) in enumerate(((0.0, -2.4), (0.0, -6.6))):
    lamp(P, (x, H, z), 0.7)
    P.empty("LightAnchor_%d" % k, (x, H - 0.7 - 0.13, z))
root_b, tris_b = P.build()

# =============================================================================================================== navigation data
N = Piece("Jail_Nav")
for name, pos in [("door", (0.0, 0.0, -0.5)), ("lane", (0.0, 0.0, 4.0)), ("sheriff", (0.7, 0.0, -3.95)), ("visit", (-1.85, 0.0, -4.05)),
                  ("accomplice", (-1.85, 0.0, -5.7)), ("desk", (1.7, 0.0, -3.1)), ("stove", (-2.5, 0.0, -1.0)),
                  ("privy", (PX, 0.5, PZ))]:                                     # y = seat height: where the flies hang
    N.empty("Spot_" + name, pos)
for name, c, half in [("desk", (1.7, -2.6), (0.8, 0.5)), ("bars", (0.0, BZ), (HX, 0.16)), ("divider", (0.0, -6.75), (0.12, 1.85)),
                      ("stove", (-2.95, -1.0), (0.38, 0.38)), ("rack", (-HX + T + 0.2, -2.6), (0.22, 0.95))]:
    N.empty("Block_" + name, (c[0], 0.0, c[1]), (half[0], 1.0, half[1]))
N.build()

import os
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
for o in bpy.context.scene.objects:
    o.select_set(o.name.split(".")[0].split("_geo")[0] in ("Bldg_Jail", "Jail_Nav") or (o.parent and o.parent.name in ("Bldg_Jail", "Jail_Nav")))
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True, use_selection=True,
                          export_extras=False, export_cameras=False, export_lights=False)
print("@@{\"ok\": true, \"tris_building\": %d, \"out\": \"%s\", \"bytes\": %d}" % (tris_b, OUT, os.path.getsize(OUT)))
