"""THE STOCKPILE KIT + THE RESERVE, IN BLENDER-PYTHON CAD (founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21).

    blender -b --factory-startup -P tools/ep2_blender/build_stockpile_kit.py -- <out stockpile_kit.glb> [render_dir]

Real sizes, flat named materials only (the game lays the town's own timber / fort-stone textures on them triplanar, so the kit ships
no texture bytes):
  Wheelbarrow   an 1880s wooden barrow. Origin = the wheel's AXLE, forward = glTF +Z, the two handle grips at the back (-Z). Built
                standing on its legs (the back raised by the legs, grips 0.52 m off the ground). Children: Wheel (spins about local
                X), Load (a heap of gold nuggets in the tray, shown when loaded). Grip_L / Grip_R empties mark where the hands go.
  Shovel        a long-handled square-point shovel, origin at the blade tip, handle along +Y (1.45 m), D-grip at the top.
  NuggetHeap    a low heap of gold nuggets on the ground (what the shovellers dig into), ~1.4 m across.
  Reserve       THE RESERVE: a sealed stone vault house - 8 m wide, 7 m deep, 4.4 m to the cornice, origin = middle of the front
                edge, front = glTF +Z. A recessed arched opening with a closed iron double door (three iron bands, rivets, a heavy
                bar), a lantern on a bracket beside it, a plain wooden placard reading RESERVE, a stone plinth. Nothing else.
"""
import bmesh
import bpy
import math
import os
import sys
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
RENDER = argv[1] if len(argv) > 1 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
SC = bpy.context.scene
MATS = {}


def mat(name, rgb, rough=0.85, metal=0.0, emit=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0.0:
        b.inputs["Emission Color"].default_value = (*rgb, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    MATS[name] = m
    return m


WOOD = mat("SP_Wood", (0.42, 0.30, 0.19), 0.9)
IRON = mat("SP_Iron", (0.16, 0.15, 0.14), 0.55, 0.85)
GOLD = mat("SP_Gold", (0.83, 0.62, 0.22), 0.3, 1.0)
STONE = mat("RS_Stone", (0.62, 0.58, 0.52), 0.92)
RIRON = mat("RS_Iron", (0.12, 0.12, 0.12), 0.5, 0.9)
RWOOD = mat("RS_Wood", (0.38, 0.27, 0.17), 0.9)
GLASS = mat("RS_Lamp", (1.0, 0.72, 0.36), 0.4, 0.0, 6.0)
INK = mat("RS_Ink", (0.08, 0.06, 0.05), 0.9)


def obj(name, bm, material, parent=None, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    o = bpy.data.objects.new(name, me)
    SC.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o


def empty(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    SC.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    return e


def box(bm, c, size, rot=None):
    """an axis box of `size` centred at c (then rotated about c by the 3x3 `rot`)"""
    r = bmesh.ops.create_cube(bm, size=1.0)
    vs = r["verts"]
    bmesh.ops.scale(bm, vec=Vector(size), verts=vs)
    if rot is not None:
        bmesh.ops.rotate(bm, cent=Vector((0, 0, 0)), matrix=rot, verts=vs)
    bmesh.ops.translate(bm, vec=Vector(c), verts=vs)
    return vs


def cyl(bm, c, r, depth, axis="z", seg=12, r2=None):
    res = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    vs = res["verts"]
    if axis == "x":
        bmesh.ops.rotate(bm, cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"), verts=vs)
    elif axis == "y":
        bmesh.ops.rotate(bm, cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "X"), verts=vs)
    bmesh.ops.translate(bm, vec=Vector(c), verts=vs)
    return vs


def nuggets(bm, centre, radius, height, count, seed, size=(0.05, 0.09), dome=0.0):
    import random
    rnd = random.Random(seed)
    for _ in range(count):
        a = rnd.uniform(0, math.tau)
        d = radius * math.sqrt(rnd.random())
        h = height * (1.0 - (d / radius) ** 2) * rnd.uniform(0.6, 1.0)
        if dome > 0.0:                          # on the dirt dome's skin (a half-buried nugget shows its top), not inside it
            h = dome * math.sqrt(max(0.0, 1.0 - (d / 0.7) ** 2)) - 0.015
        s = rnd.uniform(*size)
        res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=s)
        vs = res["verts"]
        for v in vs:
            v.co = Vector((v.co.x * rnd.uniform(0.7, 1.3), v.co.y * rnd.uniform(0.7, 1.3), v.co.z * rnd.uniform(0.6, 1.0)))
        bmesh.ops.rotate(bm, cent=Vector(), matrix=Matrix.Rotation(rnd.uniform(0, 6.28), 3, "Z"), verts=vs)
        bmesh.ops.translate(bm, vec=Vector(centre) + Vector((math.cos(a) * d, math.sin(a) * d, h)), verts=vs)


# ---------------------------------------------------------------- WHEELBARROW (Blender: forward -Y, axle at origin, ground z = -0.22)
WR = 0.22
TILT = math.atan2(0.30, 1.50)                      # the handles rise 0.30 m over their 1.5 m: the back sits on its legs
ROT = Matrix.Rotation(TILT, 3, "X")                # +X rotation lifts the +Y (back) end
barrow = empty("Wheelbarrow")
bm = bmesh.new()
for sx in (-1, 1):
    box(bm, (sx * 0.27, 0.80, 0.0), (0.05, 1.55, 0.05))                       # handle (level frame: along +Y from the axle)
    box(bm, (sx * 0.24, 0.95, -0.207), (0.045, 0.045, 0.414))                 # leg
    box(bm, (sx * 0.22, 0.95, -0.36), (0.02, 0.04, 0.10))                     # leg brace (short diagonal stub)
box(bm, (0.0, 0.10, 0.0), (0.60, 0.06, 0.05))                                # front cross piece by the wheel
box(bm, (0.0, 0.95, -0.03), (0.52, 0.05, 0.05))                              # rear cross piece over the legs
# the tray: a flared trapezoid prism of planks
tb = [(-0.25, 0.16, 0.04), (0.25, 0.16, 0.04), (0.25, 0.86, 0.04), (-0.25, 0.86, 0.04)]
tt = [(-0.36, 0.02, 0.36), (0.36, 0.02, 0.36), (0.36, 0.96, 0.36), (-0.36, 0.96, 0.36)]
vb = [bm.verts.new(p) for p in tb]
vt = [bm.verts.new(p) for p in tt]
bm.faces.new(vb[::-1])
for i in range(4):
    bm.faces.new([vb[i], vb[(i + 1) % 4], vt[(i + 1) % 4], vt[i]])
# inner skin so the open tray reads from above (the faces above point out; this set points in)
ib = [bm.verts.new((x * 0.92, y, z + 0.02)) for (x, y, z) in tb]
it = [bm.verts.new((x * 0.95, y + (0.03 if y < 0.5 else -0.03), z)) for (x, y, z) in tt]
bm.faces.new(ib)
for i in range(4):
    bm.faces.new([it[i], it[(i + 1) % 4], ib[(i + 1) % 4], ib[i]])
for i in range(4):                                                              # the rim between the skins
    bm.faces.new([vt[i], vt[(i + 1) % 4], it[(i + 1) % 4], it[i]])
for v in bm.verts:
    v.co = ROT @ v.co
frame = obj("Barrow_Frame", bm, WOOD, barrow)
bm = bmesh.new()
for sx in (-1, 1):                                                              # iron straps round the tray's top corners
    box(bm, (sx * 0.355, 0.49, 0.345), (0.02, 0.92, 0.03))
box(bm, (0.0, 0.03, 0.345), (0.70, 0.02, 0.03))
for v in bm.verts:
    v.co = ROT @ v.co
obj("Barrow_Straps", bm, IRON, barrow)
# the wheel: iron tyre (torus), hub, six spokes - all round the local X axle
wheel = empty("Wheel", barrow)
bm = bmesh.new()
res = bmesh.ops.create_circle(bm, segments=16, radius=WR - 0.015)
ring = bmesh.ops.extrude_edge_only(bm, edges=bm.edges[:])
for v in [e for e in ring["geom"] if isinstance(e, bmesh.types.BMVert)]:
    v.co *= (WR - 0.05) / (WR - 0.015)
bm.free()
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=False, segments=16, radius1=WR, radius2=WR, depth=0.06)
bmesh.ops.create_cone(bm, cap_ends=False, segments=16, radius1=WR - 0.03, radius2=WR - 0.03, depth=0.06)
for v in bm.verts:
    v.co = Matrix.Rotation(math.pi / 2, 3, "Y") @ v.co
obj("Wheel_Tyre", bm, IRON, wheel)
bm = bmesh.new()
cyl(bm, (0, 0, 0), 0.045, 0.10, "x", 10)
for k in range(6):
    a = k * math.pi / 3
    box(bm, (0, math.cos(a) * 0.1, math.sin(a) * 0.1), (0.03, 0.03, 0.19), Matrix.Rotation(-a + math.pi / 2, 3, "X"))
obj("Wheel_Spokes", bm, WOOD, wheel)
# the load: gold nuggets heaped in the tray
bm = bmesh.new()
nuggets(bm, (0, 0.50, 0.12), 0.27, 0.22, 26, 7)
for v in bm.verts:
    v.co = ROT @ v.co
obj("Load", bm, GOLD, barrow)
for sx, nm in ((-1, "Grip_L"), (1, "Grip_R")):
    empty(nm, barrow, ROT @ Vector((sx * 0.27, 1.52, 0.0)))

# ---------------------------------------------------------------- SHOVEL (origin at the blade tip, handle up +Z in Blender)
shovel = empty("Shovel")
bm = bmesh.new()
cyl(bm, (0, 0, 0.30 + 0.62), 0.018, 1.24, "z", 8)                              # ash handle
box(bm, (0, 0, 1.56), (0.13, 0.03, 0.025))                                    # D-grip top bar
for sx in (-1, 1):
    box(bm, (sx * 0.055, 0, 1.49), (0.02, 0.025, 0.12))
obj("Shovel_Handle", bm, WOOD, shovel)
bm = bmesh.new()
box(bm, (0, 0.0, 0.15), (0.26, 0.012, 0.30), Matrix.Rotation(0.18, 3, "X"))   # square-point blade, a little dished forward
cyl(bm, (0, 0, 0.33), 0.03, 0.10, "z", 8, 0.02)                               # socket
obj("Shovel_Blade", bm, IRON, shovel)

# ---------------------------------------------------------------- NUGGET HEAP (on the ground, ~1.4 m across)
heap = empty("NuggetHeap")
bm = bmesh.new()
res = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=6, radius=0.7)
bmesh.ops.delete(bm, geom=[v for v in res["verts"] if v.co.z < -0.01], context="VERTS")
for v in bm.verts:
    v.co.z *= 0.42
obj("Heap_Dirt", bm, mat("SP_Dirt", (0.40, 0.32, 0.22), 0.97), heap)
bm = bmesh.new()
nuggets(bm, (0, 0, 0.0), 0.6, 0.28, 44, 11, (0.05, 0.1), dome=0.7 * 0.42)
obj("Heap_Gold", bm, GOLD, heap)

# ---------------------------------------------------------------- THE RESERVE (Blender: front -Y at y = 0, the house behind it in +Y)
W, D, H = 8.0, 7.0, 4.4
reserve = empty("Reserve")
bm = bmesh.new()
box(bm, (0, D / 2, -0.05), (W + 0.8, D + 0.8, 0.5))                           # plinth
box(bm, (0, D / 2 + 0.1, H / 2 + 0.2), (W, D - 0.2, H))                       # the block (solid: nobody goes in)
box(bm, (0, D / 2, H + 0.32), (W + 0.4, D + 0.4, 0.24))                       # cornice
box(bm, (0, D / 2, H + 0.55), (W + 0.1, D + 0.1, 0.22))                       # parapet course
for sx in (-1, 1):                                                              # corner pilasters
    box(bm, (sx * (W / 2 - 0.25), 0.05, H / 2 + 0.2), (0.6, 0.3, H))
# the door surround: a stone frame standing proud of the face, with a keystone
box(bm, (0, -0.12, 3.35), (3.1, 0.35, 0.5))                                   # lintel
box(bm, (0, -0.2, 3.62), (0.5, 0.25, 0.55))                                   # keystone
for sx in (-1, 1):
    box(bm, (sx * 1.35, -0.12, 1.55), (0.45, 0.35, 3.1))                      # jambs
box(bm, (0, -0.35, 0.25), (3.4, 0.6, 0.12))                                  # threshold step
obj("Reserve_Stone", bm, STONE, reserve)
# the closed double door: two iron leaves set back in the opening, three bands, rivets, the drop bar across both
bm = bmesh.new()
for sx in (-1, 1):
    box(bm, (sx * 0.56, 0.06, 1.55), (1.1, 0.12, 2.9))
obj("Reserve_Door", bm, RIRON, reserve)
bm = bmesh.new()
for z in (0.55, 1.55, 2.55):
    box(bm, (0, -0.02, z), (2.26, 0.05, 0.14))                                # bands
    for k in range(9):
        cyl(bm, (-1.0 + k * 0.25, -0.06, z), 0.025, 0.04, "y", 6)            # rivet heads
box(bm, (0, -0.10, 1.25), (2.5, 0.09, 0.16))                                 # the drop bar
for sx in (-1, 1):
    box(bm, (sx * 1.18, -0.08, 1.25), (0.12, 0.14, 0.34))                    # its brackets
cyl(bm, (0.0, -0.13, 1.25), 0.09, 0.1, "y", 10)                              # the padlock body on the bar
obj("Reserve_Bands", bm, mat("RS_Bands", (0.22, 0.2, 0.18), 0.45, 0.9), reserve)
# the lantern on its bracket, right of the door
bm = bmesh.new()
box(bm, (2.05, -0.2, 2.9), (0.05, 0.4, 0.05))                                # bracket arm
box(bm, (2.05, -0.38, 2.78), (0.2, 0.2, 0.03))                               # lantern top
box(bm, (2.05, -0.38, 2.5), (0.2, 0.2, 0.03))                                # lantern base
for sx in (-1, 1):
    for sy in (-1, 1):
        box(bm, (2.05 + sx * 0.09, -0.38 + sy * 0.09, 2.64), (0.015, 0.015, 0.27))
cyl(bm, (2.05, -0.38, 2.86), 0.07, 0.12, "z", 8, 0.0)                        # cap
obj("Reserve_LanternFrame", bm, RIRON, reserve)
bm = bmesh.new()
box(bm, (2.05, -0.38, 2.64), (0.15, 0.15, 0.24))
obj("Reserve_LanternGlass", bm, GLASS, reserve)
empty("LightAnchor_Lantern", reserve, (2.05, -0.38, 2.64))
# the plain placard: a planked board on the wall left of the door, the word cut in dark paint
bm = bmesh.new()
box(bm, (-2.45, -0.04, 2.1), (1.5, 0.06, 0.5))
obj("Reserve_Placard", bm, RWOOD, reserve)
cu = bpy.data.curves.new("RS_Text", "FONT")
cu.body = "RESERVE"
cu.size = 0.26
cu.align_x = "CENTER"
cu.align_y = "CENTER"
cu.extrude = 0.0
cu.resolution_u = 2
t = bpy.data.objects.new("Reserve_Word", cu)
SC.collection.objects.link(t)
t.location = (-2.45, -0.075, 2.1)
t.rotation_euler = (math.pi / 2, 0, 0)
bpy.context.view_layer.objects.active = t
t.select_set(True)
bpy.ops.object.convert(target="MESH")
t = bpy.context.view_layer.objects.active
t.data.materials.clear()
t.data.materials.append(INK)
t.parent = reserve
t.matrix_parent_inverse.identity()
t.location = (-2.45, -0.075, 2.1)
empty("Inspect", reserve, (0.0, -1.6, 0.0))                                   # where Lil Blunt stands to read it

# kit pieces laid out apart (the game finds them by name and places its own copies)
barrow.location = (-4, 0, WR)
shovel.location = (-6, 0, 0)
heap.location = (-8, 0, 0)
reserve.location = (6, 0, 0)

if RENDER:
    os.makedirs(RENDER, exist_ok=True)
    SC.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    SC.render.resolution_x, SC.render.resolution_y = 768, 512
    w = bpy.data.worlds.new("w")
    SC.world = w
    w.use_nodes = True
    next(n for n in w.node_tree.nodes if n.type == "BACKGROUND").inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.9, 0.0, -0.6)
    SC.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    SC.collection.objects.link(cam)
    SC.camera = cam
    for name, (pos, tgt) in {"barrow": ((-1.8, -2.4, 1.4), (-4.4, 0.4, 0.3)), "heap": ((-6.2, -2.6, 1.6), (-7.2, 0, 0.4)),
                             "reserve": ((3.0, -11, 3.5), (6, 3, 2.2))}.items():
        cam.location = Vector(pos)
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
        SC.render.filepath = f"{RENDER}/{name}.png"
        bpy.ops.render.render(write_still=True)

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True)
print("OUT", OUT, os.path.getsize(OUT))
