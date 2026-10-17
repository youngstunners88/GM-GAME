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
mat("Bottle", (0.25, 0.14, 0.05), 0.15, 0.0)


def G(p):
    """game (x, y, z) -> blender (x, -z, y)"""
    return Vector((p[0], -p[2], p[1]))


class Piece:
    def __init__(self, name):
        self.name = name
        self.bms = {}
        self.anchors = []

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
        r = Matrix.Rotation(rot_y, 4, "Z") @ Matrix.Rotation(rot_x, 4, "X") @ Matrix.Rotation(-rot_z, 4, "Y")
        bmesh.ops.transform(tmp, matrix=Matrix.Translation(G(centre)) @ r, verts=tmp.verts)
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
        for an, p in self.anchors:
            e = bpy.data.objects.new(an, None)
            bpy.context.scene.collection.objects.link(e)
            e.parent = root
            e.location = G(p)
        return root


T = 0.14   # wall thickness


def window(p, x, y, w=0.9, h=1.4, zf=0.0):
    """A sash window in a front wall at front plane z = zf: frame + glass + muntins."""
    p.box("Glass", (w - 0.08, h - 0.08, 0.04), (x, y, zf - 0.02))
    p.box("Trim", (w + 0.16, 0.12, 0.18), (x, y + h / 2 + 0.06, zf + 0.02))
    p.box("Trim", (w + 0.22, 0.08, 0.26), (x, y - h / 2 - 0.04, zf + 0.06))
    for sx in (-1, 1):
        p.box("Trim", (0.08, h, 0.12), (x + sx * (w / 2), y, zf + 0.01))
    p.box("Trim", (0.04, h, 0.05), (x, y, zf + 0.0))
    p.box("Trim", (w, 0.04, 0.05), (x, y, zf + 0.0))


def shell(p, w, d, h, door_w, door_x=0.0, open_door=True, interior=False, mat_wall="Siding", wins=(), upper_wins=()):
    """The walls of a building whose front plane is z = 0 and back is z = -d; door opening in the front."""
    hw = w / 2
    # front wall pieces around the door
    left_w = (door_x - door_w / 2) + hw
    right_w = hw - (door_x + door_w / 2)
    p.box(mat_wall, (left_w, h, T), (-hw + left_w / 2, h / 2, -T / 2))
    p.box(mat_wall, (right_w, h, T), (hw - right_w / 2, h / 2, -T / 2))
    p.box(mat_wall, (door_w, h - 2.5, T), (door_x, 2.5 + (h - 2.5) / 2, -T / 2))
    # door frame
    for sx in (-1, 1):
        p.box("Trim", (0.12, 2.55, 0.22), (door_x + sx * (door_w / 2 + 0.04), 1.275, 0.0))
    p.box("Trim", (door_w + 0.3, 0.14, 0.24), (door_x, 2.55, 0.0))
    if not open_door:
        p.box("DarkWood", (door_w, 2.5, 0.08), (door_x, 1.25, -0.08))
    # side + back walls
    for sx in (-1, 1):
        p.box(mat_wall, (T, h, d), (sx * (hw - T / 2), h / 2, -d / 2))
    p.box(mat_wall, (w, h, T), (0.0, h / 2, -d + T / 2))
    # floor, ceiling, gable roof behind the false front
    p.box("Planks", (w, 0.2, d), (0.0, 0.1 - 0.2, -d / 2))
    if interior:
        p.box("Planks", (w - 2 * T, 0.06, d - 2 * T), (0.0, 0.03, -d / 2))
        p.box("Trim", (w - 2 * T, 0.08, d - 2 * T), (0.0, h - 0.04, -d / 2))
    ang = 0.42
    half = (w / 2 + 0.3) / math.cos(ang)
    for sx in (-1, 1):
        p.box("Roof", (half, 0.06, d + 0.4), (sx * (w / 4 + 0.075), h + math.tan(ang) * (w / 4) + 0.02, -d / 2), rot_z=-sx * ang)
    for wx in wins:
        window(p, wx, 1.6, zf=0.0)
    for wx in upper_wins:
        window(p, wx, h - 1.6, zf=0.0)


def false_front(p, w, h_top, sign_word, sign_y, sign_w, sign_h, mat_wall="Siding"):
    """The flat false front above the roofline with a cornice, a sign board and its anchor."""
    p.box(mat_wall, (w + 0.2, h_top, T), (0.0, h_top / 2, 0.02))
    p.box("Trim", (w + 0.6, 0.22, 0.45), (0.0, h_top + 0.05, 0.12))
    p.box("Trim", (w + 0.4, 0.12, 0.3), (0.0, h_top - 0.2, 0.1))
    for i in range(6):
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
        p.box("Trim", (0.18, h, 0.18), (x, 0.44 + h / 2, depth - 0.15))
        p.box("Trim", (0.32, 0.12, 0.32), (x, 0.47, depth - 0.15))
    p.box("Roof", (w + 0.6, 0.06, depth + 0.5), (0.0, 0.44 + h + 0.18, depth / 2), rot_x=0.12)
    p.box("Trim", (w + 0.4, 0.2, 0.16), (0.0, 0.44 + h, depth - 0.15))
    if steps:
        for k in range(2):
            p.box("Planks", (1.8, 0.16, 0.35), (0.0, 0.16 * (k + 0.5), depth + 0.18 + 0.35 * (1 - k)))


def building(name, w, d, storeys, h_front, sign_word=None, door_open=False, interior=False, balcony=False, mat_wall="Siding"):
    p = Piece(name)
    h = 3.6 * storeys
    wins = (-w / 2 + 1.3, w / 2 - 1.3) if w > 6.5 else ()
    shell(p, w, d, h, 1.5 if not balcony else 1.9, 0.0, door_open, interior, mat_wall, wins,
          tuple(-w / 2 + 1.1 + i * (w - 2.2) / 2 for i in range(3)) if storeys > 1 else ())
    false_front(p, w, h_front, sign_word, h + (h_front - h) * 0.5 if h_front > h + 1.0 else h - 0.9, min(w - 1.2, 6.0), 1.0, mat_wall)
    porch(p, w)
    if balcony:
        y = 3.6
        p.box("Planks", (w, 0.16, 1.6), (0.0, y + 0.3, 0.8))
        for i in range(int(w / 0.35)):
            p.box("Trim", (0.06, 0.9, 0.06), (-w / 2 + 0.2 + i * 0.35, y + 0.83, 1.5))
        p.box("Trim", (w, 0.08, 0.1), (0.0, y + 1.3, 1.5))
    return p


# --- the street ---------------------------------------------------------------------------------------------------------------
building("Bldg_Certificates", 8.0, 9.0, 2, 9.4, "CERTIFICATES", door_open=True, interior=True).build()
building("Bldg_Saloon", 12.0, 12.0, 2, 9.6, "SALOON", door_open=True, interior=True, balcony=True).build()
building("Bldg_A", 7.0, 8.0, 1, 6.2, "GENERAL").build()
building("Bldg_B", 8.0, 9.0, 2, 8.6, "HOTEL").build()
building("Bldg_C", 6.0, 8.0, 1, 5.6, "ASSAY").build()
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
false_front(p, w, h, "ARMS", h - 0.9, 4.2, 0.9, "Siding")
porch(p, w)
p.box("Roof", (4.0, 0.06, 3.0), (0.0, 2.7, -d - 1.3), rot_z=0.18)     # lean-to loading shed, behind
for sx in (-1.7, 1.7):
    for sz in (-d - 0.2, -d - 2.6):
        p.box("Trim", (0.16, 2.5, 0.16), (sx, 1.25, sz))
p.build()

# the Treasury: sandstone, pilasters, pediment, shut double door
p = Piece("Bldg_Treasury")
w, d, h = 10.0, 12.0, 7.6
shell(p, w, d, h, 2.0, 0.0, False, False, "Sandstone", (-3.2, 3.2), (-3.2, 3.2))
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

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True)
print("wrote", OUT)
