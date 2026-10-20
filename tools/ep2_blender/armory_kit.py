"""Shared Blender pieces for the Armory's two hero guns (founder 2026-10-20, skill ep2-armory-guns).

  sharps(p, ...)      the Sharps Model 1874 "Buffalo Gun": walnut straight-grip stock, case-hardened falling-block receiver with an external
                      hammer and a finger-lever, double set triggers, a 30 in octagonal barrel, tang peep sight, globe front sight, sling swivels.
                      Muzzle +x, butt -x, ~1.21 m long (period-correct overall length). Duck-typed: `p` is any Piece with box()/cyl()/xf.
  Piece / mat()       the same primitive builder build_armory2.py uses, for the standalone GLBs (build_sharps_gatling.py).

Everything is written in the GAME frame (x right, y up, z toward the street) and converted once in Piece.build().
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

MATS = {}


def mat(name, rgb, rough=0.85, metal=0.0, alpha=1.0, emit=0.0):
    m = bpy.data.materials.new(name)
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*rgb, 1.0)                    # the viewport colour: Workbench review shots read it
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    MATS[name] = m


def standard_materials():
    for n, c, r, mt in [("Iron", (0.16, 0.15, 0.14), 0.6, 0.7), ("Brass", (0.72, 0.55, 0.25), 0.35, 1.0), ("DarkWood", (0.20, 0.12, 0.07), 0.55, 0.0),
                        ("GunWood", (0.34, 0.17, 0.07), 0.45, 0.0), ("GunSteel", (0.09, 0.095, 0.10), 0.35, 0.85), ("Leather", (0.36, 0.21, 0.11), 0.7, 0.0),
                        ("CaseHard", (0.17, 0.15, 0.21), 0.38, 0.85), ("Planks", (0.36, 0.28, 0.20), 0.9, 0.0), ("Trim", (0.30, 0.21, 0.14), 0.85, 0.0),
                        ("Stone", (0.46, 0.43, 0.38), 0.95, 0.0), ("Sand", (0.62, 0.52, 0.34), 0.97, 0.0), ("Cloth", (0.45, 0.10, 0.08), 0.9, 0.0),
                        ("Paper", (0.82, 0.74, 0.56), 0.95, 0.0), ("Rope", (0.55, 0.45, 0.30), 0.95, 0.0), ("Paint", (0.60, 0.07, 0.05), 0.7, 0.0),
                        ("Bone", (0.88, 0.84, 0.74), 0.7, 0.0)]:
        mat(n, c, r, mt)


class Piece:
    """Primitives in the GAME frame, grouped by material; `xf` is the current placement (game-frame 4x4)."""

    def __init__(self, name):
        self.name = name
        self.bms = {}
        self.empties = []
        self.xf = Matrix.Identity(4)
        self.root = None

    def bm(self, m):
        if m not in self.bms:
            self.bms[m] = bmesh.new()
        return self.bms[m]

    def at(self, pos=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0):
        """Translate, then yaw about y, pitch about x, roll about z (game frame)."""
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
        bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
        rot = {"y": Matrix.Identity(4), "x": Matrix.Rotation(-math.pi / 2, 4, "Z"), "z": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        self._add(m, tmp, Matrix.Translation(Vector(centre)) @ Matrix.Rotation(yaw, 4, "Y") @ rot)

    def prism(self, m, pts, depth, centre=(0, 0, 0)):
        """A side profile (x, y points, counter-clockwise) extruded `depth` along z - stocks, grips, hammers."""
        tmp = bmesh.new()
        vs = [tmp.verts.new((x, y, -depth / 2)) for x, y in pts]
        f = tmp.faces.new(vs)
        ext = bmesh.ops.extrude_face_region(tmp, geom=[f])
        bmesh.ops.translate(tmp, vec=(0, 0, depth), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
        bmesh.ops.recalc_face_normals(tmp, faces=list(tmp.faces))
        self._add(m, tmp, Matrix.Translation(Vector(centre)))

    def empty(self, name, pos, scale=(1, 1, 1)):
        self.empties.append((name, (self.xf @ Vector(pos).to_4d()).to_3d(), scale))

    def build(self, parent=None, location=(0, 0, 0)):
        """Merge to one mesh under an empty named `self.name`; `location` is the pivot in the GAME frame (the geometry was written
        around it, so a child piece's local origin IS its pivot)."""
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
            for poly in me.polygons:
                poly.use_smooth = False
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
        root.location = (location[0], -location[2], location[1])
        if parent is not None:
            root.parent = parent
        self.root = root
        return root, tris


# ---------------------------------------------------------------------------------------------------------------- the Sharps 1874

def sharps(p, pos=(0.0, 0.0, 0.0), yaw=0.0, pitch=0.0, roll=0.0, scale=1.0):
    """Sharps Model 1874 Sporting Rifle ("the Buffalo Gun"). Origin = the middle of the receiver; muzzle +x, butt -x, up +y.
    Overall ~1.21 m: 13 5/8 in length of pull + receiver + 30 in (0.76 m) octagonal barrel."""
    keep = p.xf
    p.xf = keep @ p.at(pos, yaw, pitch, roll) @ Matrix.Scale(scale, 4)
    # walnut straight-grip buttstock (13 5/8 in length of pull): a side profile extruded - heel-high comb, slim straight wrist, a steel crescent plate
    p.prism("GunWood", [(-0.352, 0.052), (-0.30, 0.058), (-0.22, 0.066), (-0.16, 0.060), (-0.10, 0.046), (-0.10, -0.030), (-0.16, -0.036),
                        (-0.24, -0.052), (-0.31, -0.080), (-0.357, -0.092)], 0.040)
    p.prism("GunSteel", [(-0.358, 0.056), (-0.352, 0.056), (-0.357, -0.096), (-0.365, -0.096), (-0.366, -0.01)], 0.046)       # crescent buttplate
    p.cyl("Brass", 0.007, 0.007, 0.046, (-0.352, 0.05, 0), "z", 6)                           # heel plate screws
    p.cyl("Brass", 0.007, 0.007, 0.046, (-0.362, -0.088, 0), "z", 6)
    # receiver: a heavy case-hardened block with the falling block mortise, the breech block and the lever pivot
    p.box("CaseHard", (0.200, 0.075, 0.046), (0.0, 0.010, 0))
    p.box("CaseHard", (0.070, 0.030, 0.052), (0.060, 0.052, 0))                              # breech block (shown lowered a little)
    p.box("GunSteel", (0.14, 0.012, 0.050), (0.02, 0.0055, 0))                               # block seam
    p.cyl("Brass", 0.012, 0.012, 0.052, (-0.03, -0.012, 0), "z", 8)                          # lever pivot screw head
    p.cyl("Brass", 0.010, 0.010, 0.052, (0.07, 0.020, 0), "z", 8)                            # block pin
    # external hammer: a lock plate, then the hammer as a profile (curved neck and a knurled spur)
    p.box("CaseHard", (0.070, 0.050, 0.010), (-0.058, 0.032, 0.027))
    p.prism("CaseHard", [(-0.085, 0.040), (-0.100, 0.046), (-0.122, 0.074), (-0.108, 0.082), (-0.092, 0.058), (-0.075, 0.048)], 0.014, (0, 0, 0.0))
    # finger lever = the trigger guard: a long loop hung under the wrist from the lever pivot, the set triggers inside it
    p.box("GunSteel", (0.215, 0.012, 0.018), (-0.015, -0.052, 0.0))                          # bottom bar
    p.box("GunSteel", (0.014, 0.060, 0.018), (-0.118, -0.024, 0.0))                          # rear arm up into the wrist
    p.box("GunSteel", (0.014, 0.060, 0.018), (0.086, -0.024, 0.0))                           # front arm up to the pivot
    p.box("GunSteel", (0.012, 0.030, 0.010), (-0.060, -0.034, 0.0), roll=0.12)               # rear (set) trigger
    p.box("GunSteel", (0.010, 0.024, 0.010), (-0.034, -0.032, 0.0), roll=0.18)               # front (firing) trigger
    # tang peep sight: a strap on the wrist's top, a vernier staff rising and leaning back, a small aperture disc
    p.box("Brass", (0.060, 0.008, 0.016), (-0.130, 0.049, 0))
    p.box("Brass", (0.010, 0.074, 0.008), (-0.134, 0.088, 0), roll=-0.20)
    p.cyl("Brass", 0.018, 0.018, 0.006, (-0.140, 0.121, 0), "x", 10)
    # barrel: heavy 30 in octagonal (8 sides), a short walnut forearm with a steel tip, a barrel band, bare steel to the globe sight
    p.cyl("GunSteel", 0.0185, 0.0165, 0.76, (0.47, 0.026, 0), "x", 8)
    p.box("GunWood", (0.25, 0.044, 0.042), (0.215, 0.0, 0))                                  # forearm
    p.box("GunSteel", (0.012, 0.050, 0.045), (0.343, 0.0, 0))                                # forearm tip
    p.box("GunSteel", (0.014, 0.060, 0.050), (0.098, 0.0, 0))                                # forearm cap at the receiver
    p.cyl("GunSteel", 0.026, 0.026, 0.020, (0.33, 0.026, 0), "x", 8)                         # barrel band
    p.box("GunSteel", (0.012, 0.014, 0.012), (0.33, -0.004, 0))                              # sling swivel on the band
    p.box("GunSteel", (0.012, 0.012, 0.014), (-0.30, -0.048, 0))                             # sling swivel under the butt
    # globe front sight and the open buckhorn rear on the barrel
    p.cyl("Brass", 0.012, 0.010, 0.030, (0.825, 0.062, 0), "x", 8)
    p.box("GunSteel", (0.020, 0.036, 0.012), (0.82, 0.044, 0))
    p.box("GunSteel", (0.012, 0.018, 0.024), (0.24, 0.054, 0))                               # rear sight base
    p.box("GunSteel", (0.010, 0.016, 0.006), (0.24, 0.070, 0.008))
    p.box("GunSteel", (0.010, 0.016, 0.006), (0.24, 0.070, -0.008))
    p.xf = keep


# ------------------------------------------------------------------------------------------------------- the Colt Gatling post
# A six-barrel Colt Gatling on a fixed iron pintle post (the kind bolted to a fort wall or a station roof), at the Armory's front yard.
# NOT FOR SALE: it is a showpiece Utah demonstrates, and Lil Blunt can take the crank. Four pieces so the game can move them:
#   GatPost (static)  ->  Gat_Yaw (turns about the post)  ->  Gat_Pitch (elevates on the trunnions)  ->  Gat_Barrels (spins), Gat_Crank (turns)
# Pivot-local geometry: each piece is written around its own origin and parented at its pivot (Piece.build(parent, location)).
GAT_YAW_Y = 1.12                    # the turntable above the plinth
GAT_TRUNNION_Y = 0.30               # the trunnion axis above the turntable
GAT_BARREL_X = 0.52                 # the barrel cluster's origin along the bore (pitch-local)
GAT_CRANK = (-0.02, 0.0, 0.21)      # the crank hub (pitch-local; +z is the gunner's right)


def gatling_post_geo(p):
    p.cyl("Stone", 0.64, 0.58, 0.28, (0, 0.14, 0), "y", 12)                                   # the plinth
    p.cyl("Stone", 0.70, 0.70, 0.05, (0, 0.025, 0), "y", 12)                                  # its footing
    p.cyl("Iron", 0.095, 0.085, 0.84, (0, 0.70, 0), "y", 10)                                  # the post
    p.cyl("Iron", 0.16, 0.16, 0.05, (0, 0.30, 0), "y", 10)                                    # flange
    p.cyl("Iron", 0.13, 0.10, 0.08, (0, 1.08, 0), "y", 10)                                    # collar under the turntable
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        p.cyl("Brass", 0.018, 0.018, 0.03, (0.14 * math.cos(ang), 0.335, 0.14 * math.sin(ang)), "y", 6)   # flange bolts
    # sandbags: two low flanks either side of the post (the gunner's back and the field of fire stay open)
    for row in range(2):
        for i in range(10):
            ang = math.radians((55 if i < 5 else 235 - 5 * 16) + i * 16 + (8 if row else 0))
            r = 1.0
            p.box("Sand", (0.42, 0.15, 0.24), (r * math.cos(ang), 0.075 + row * 0.15, r * math.sin(ang)), yaw=-ang + math.pi / 2)
            p.box("Rope", (0.02, 0.152, 0.245), (r * math.cos(ang), 0.075 + row * 0.15, r * math.sin(ang)), yaw=-ang + math.pi / 2)
    # ammunition: two plank crates and spare drums on them
    for k, (x, z, yw) in enumerate(((-0.55, -1.55, 0.2), (-0.55, 1.55, -0.2))):
        p.box("Planks", (0.62, 0.34, 0.40), (x, 0.17, z), yaw=yw)
        p.box("Trim", (0.64, 0.04, 0.42), (x, 0.36, z), yaw=yw)
        p.cyl("Brass", 0.17, 0.17, 0.09, (x, 0.44, z), "y", 12)
        p.cyl("Iron", 0.04, 0.04, 0.11, (x, 0.45, z), "y", 8)
    # a signboard on two stakes behind the gunner, facing the porch: "NOT FOR SALE" is drawn by the game (Label3D) on its -x face
    for sz in (-0.75, 0.75):
        p.box("DarkWood", (0.06, 1.15, 0.06), (-2.4, 0.575, sz))
    p.box("Planks", (0.06, 0.55, 1.70), (-2.4, 0.98, 0.0))
    p.box("Trim", (0.07, 0.04, 1.74), (-2.4, 1.27, 0.0))
    p.box("Trim", (0.07, 0.04, 1.74), (-2.4, 0.69, 0.0))
    p.empty("Gat_Sign", (-2.44, 0.98, 0.0))


def gatling_yaw_geo(p):
    p.cyl("Iron", 0.18, 0.18, 0.05, (0, 0.025, 0), "y", 12)                                   # the turntable
    p.box("Iron", (0.14, 0.06, 0.50), (0, 0.075, 0))                                          # cross-tree
    for sz in (-1, 1):
        p.box("Iron", (0.075, 0.30, 0.075), (0, 0.20, sz * 0.22))                              # yoke uprights, cradling the trunnions
        p.cyl("Brass", 0.065, 0.065, 0.04, (0, GAT_TRUNNION_Y, sz * 0.26), "z", 10)          # trunnion caps
    p.box("Iron", (0.05, 0.10, 0.14), (-0.10, 0.12, 0.0))                                     # elevating screw housing


def gatling_pitch_geo(p):
    p.cyl("Brass", 0.04, 0.04, 0.46, (0, 0, 0), "z", 8)                                       # trunnion pins
    p.cyl("Brass", 0.14, 0.14, 0.50, (-0.02, 0.0, 0), "x", 14)                                # the breech casing
    p.cyl("Brass", 0.15, 0.15, 0.04, (-0.28, 0.0, 0), "x", 14)                                # rear band
    p.cyl("Iron", 0.12, 0.10, 0.07, (-0.32, 0.0, 0), "x", 12)                                 # rear cap
    p.box("Iron", (0.34, 0.02, 0.012), (-0.02, 0.145, 0.0))                                   # top seam strap
    for sz in (-1, 1):
        p.box("Iron", (0.38, 0.20, 0.012), (-0.02, 0.0, sz * 0.143))                          # side plates
        for k in range(4):
            p.cyl("Brass", 0.012, 0.012, 0.016, (-0.16 + k * 0.1, 0.07, sz * 0.15), "z", 6)   # plate screws
    # the drum magazine (Broadwell feed): neck, drum, hub and a carry ring
    p.box("Brass", (0.14, 0.10, 0.14), (0.02, 0.17, 0))
    p.cyl("Brass", 0.22, 0.22, 0.11, (0.02, 0.27, 0), "y", 16)
    p.cyl("Iron", 0.225, 0.225, 0.02, (0.02, 0.325, 0), "y", 16)
    p.cyl("Iron", 0.06, 0.06, 0.15, (0.02, 0.30, 0), "y", 8)
    p.cyl("Brass", 0.03, 0.03, 0.04, (0.02, 0.385, 0), "y", 8)
    for k in range(10):
        a = k * 2 * math.pi / 10
        p.cyl("Iron", 0.012, 0.012, 0.13, (0.02 + 0.15 * math.cos(a), 0.27, 0.15 * math.sin(a)), "y", 5)   # cartridge lugs on the drum rim
    # front casing and the collar the barrel cluster turns in
    p.cyl("Brass", 0.12, 0.12, 0.26, (0.36, 0.0, 0), "x", 14)
    p.cyl("Iron", 0.135, 0.135, 0.035, (0.50, 0.0, 0), "x", 14)
    # simple open sights
    p.box("Iron", (0.012, 0.07, 0.012), (-0.16, 0.18, 0.0))                                   # rear post
    p.box("Iron", (0.03, 0.012, 0.05), (-0.16, 0.215, 0.0))                                   # rear leaf
    p.empty("Gat_Muzzle", (GAT_BARREL_X + 1.0, 0.0, 0.0))
    p.empty("Gat_Eye", (-0.64, 0.38, 0.0))
    p.empty("Gat_Eject", (0.10, 0.02, 0.145))


def gatling_barrels_geo(p):
    for i in range(6):
        a = i * math.pi / 3
        p.cyl("GunSteel", 0.022, 0.020, 0.98, (0.49, 0.072 * math.cos(a), 0.072 * math.sin(a)), "x", 8)
    p.cyl("Iron", 0.030, 0.030, 0.98, (0.49, 0, 0), "x", 8)
    for x in (0.03, 0.50, 0.96):
        p.cyl("Brass", 0.105, 0.105, 0.035, (x, 0, 0), "x", 14)                               # the clamp rings
    p.cyl("Brass", 0.10, 0.10, 0.02, (0.99, 0, 0), "x", 14)                                    # muzzle plate


def gatling_crank_geo(p):
    p.cyl("Iron", 0.055, 0.055, 0.07, (0, 0, 0.0), "z", 10)                                    # hub
    p.cyl("Brass", 0.03, 0.03, 0.09, (0, 0, 0.03), "z", 8)
    p.box("Iron", (0.045, 0.27, 0.03), (0, 0.13, 0.05))                                        # arm
    p.cyl("GunWood", 0.026, 0.024, 0.13, (0, 0.265, 0.12), "z", 8)                             # the wooden handle
    p.cyl("Brass", 0.032, 0.032, 0.02, (0, 0.265, 0.19), "z", 8)


def range_plate_geo(p):
    for sx in (-1, 1):
        p.box("Planks", (0.10, 1.75, 0.10), (sx * 0.55, 0.875, 0))
    p.box("Planks", (1.30, 0.10, 0.10), (0, 1.70, 0))
    p.box("Trim", (1.34, 0.04, 0.12), (0, 1.76, 0))


def range_swing_geo(p):
    """Pivot at the top bar; the plate hangs below on two chains."""
    for sx in (-1, 1):
        p.box("Iron", (0.015, 0.22, 0.015), (sx * 0.12, -0.11, 0))
    p.cyl("Iron", 0.26, 0.26, 0.028, (0, -0.48, 0), "z", 16)
    p.cyl("Bone", 0.215, 0.215, 0.032, (0, -0.48, 0), "z", 16)
    p.cyl("Paint", 0.15, 0.15, 0.036, (0, -0.48, 0), "z", 16)
    p.cyl("Bone", 0.085, 0.085, 0.040, (0, -0.48, 0), "z", 16)
    p.cyl("Paint", 0.03, 0.03, 0.044, (0, -0.48, 0), "z", 10)


def range_bale_geo(p):
    p.box("Sand", (1.10, 0.52, 0.55), (0, 0.26, 0))
    for x in (-0.35, 0.35):
        p.box("Rope", (0.03, 0.535, 0.56), (x, 0.26, 0))
    p.box("Paper", (0.62, 0.62, 0.012), (0, 0.85, 0.0), roll=0.0)
    p.cyl("Paint", 0.26, 0.26, 0.016, (0, 0.85, 0.0), "z", 16)
    p.cyl("Bone", 0.17, 0.17, 0.018, (0, 0.85, 0.0), "z", 16)
    p.cyl("Paint", 0.08, 0.08, 0.02, (0, 0.85, 0.0), "z", 12)
    p.box("DarkWood", (0.08, 0.85, 0.08), (-0.28, 0.42, -0.30))
    p.box("DarkWood", (0.08, 0.85, 0.08), (0.28, 0.42, -0.30))
