"""Inferno Bull hero scene: forge-hideout set, lighting, haze, DOF and upgraded character material.

Run headless so the artist's Blender window never locks up (the box has 8 GB RAM / a 920MX):

    blender -b design/ep2/blender/inferno-bull-pbr_v3.blend --python tools/ep2_blender/bull_hero_scene.py -- \
        --out design/ep2/blender/renders/bull_test.png --pct 40 --samples 32 [--save]

Idempotent: it removes its own `Hideout_Set` collection / `HS_*` materials before rebuilding.
"""
import bpy, math, random, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default
OUT = arg("--out"); PCT = int(arg("--pct", 40)); SAMPLES = int(arg("--samples", 32))
SAVE = "--save" in argv; RT = arg("--rt", "1") == "1"

random.seed(7)
for _img in bpy.data.images:
    if _img.size[0] > 2048: _img.scale(2048, 2048)      # 8 GB box: never keep 4096 maps resident

# --- re-pose through the Tripo armature (measured with bull_pose_test.py): lift the bowed head so the aviators/cigar show,
#     and bring the viewer-left arm in so the hanging flap reads as a relaxed arm, not a glitch. "Bone:axis:degrees,..."
import math as _m
from mathutils import Euler as _E
_POSE = arg("--pose", "Head:x:-25,RightArm:z:-30")
_arm = bpy.data.objects["Armature"]
if _POSE != "none" and _arm.animation_data and _arm.animation_data.action:
    _ev = _arm.evaluated_get(bpy.context.evaluated_depsgraph_get())
    _baked = {pb.name: pb.matrix_basis.copy() for pb in _ev.pose.bones}     # frame-1 pose of the Idle_02 action
    _arm.animation_data.action = None
    for pb in _arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'; _l, _r, _s = _baked[pb.name].decompose(); pb.location = _l; pb.rotation_quaternion = _r; pb.scale = _s
    for _t in _POSE.split(","):
        _b, _ax, _dg = _t.split(":"); _a = _m.radians(float(_dg))
        pb = _arm.pose.bones[_b]; pb.rotation_quaternion = pb.rotation_quaternion @ _E((_a if _ax == "x" else 0, _a if _ax == "y" else 0, _a if _ax == "z" else 0)).to_quaternion()
    bpy.context.view_layer.update()
    print("[bull_hero] pose applied:", _POSE, flush=True)
S = bpy.context.scene

# ---------------------------------------------------------------- clean previous run
if "Hideout_Set" in bpy.data.collections:
    c = bpy.data.collections["Hideout_Set"]
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.collections.remove(c)
for m in [m for m in bpy.data.materials if m.name.startswith("HS_")]:
    bpy.data.materials.remove(m)
if "FaceKicker" in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects["FaceKicker"], do_unlink=True)
col = bpy.data.collections.new("Hideout_Set")
S.collection.children.link(col)

# ---------------------------------------------------------------- node helpers
def new_mat(name):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    return m, nt, nt.nodes.new("ShaderNodeOutputMaterial")
def N(nt, t, **kw):
    n = nt.nodes.new(t)
    for k, v in kw.items(): setattr(n, k, v)
    return n
def link(nt, a, b): nt.links.new(a, b)
def ramp(nt, stops):
    r = N(nt, "ShaderNodeValToRGB"); el = r.color_ramp.elements
    while len(el) > len(stops): el.remove(el[-1])
    while len(el) < len(stops): el.new(0.5)
    for e, (p, c) in zip(el, stops): e.position = p; e.color = c
    return r
def mix_rgb(nt, fac, a, b):
    n = N(nt, "ShaderNodeMix", data_type='RGBA', blend_type='MIX')
    A = [s for s in n.inputs if s.name == 'A' and s.enabled][0]
    B = [s for s in n.inputs if s.name == 'B' and s.enabled][0]
    if isinstance(fac, (int, float)): n.inputs[0].default_value = fac
    else: link(nt, fac, n.inputs[0])
    for sock, v in ((A, a), (B, b)):
        if isinstance(v, (tuple, list)): sock.default_value = v
        else: link(nt, v, sock)
    return [o for o in n.outputs if o.name == 'Result' and o.enabled][0]
def tcmap(nt, scale=(1, 1, 1), coord='Object'):
    tc = N(nt, "ShaderNodeTexCoord"); mp = N(nt, "ShaderNodeMapping")
    mp.inputs['Scale'].default_value = scale
    link(nt, tc.outputs[coord], mp.inputs['Vector'])
    return mp.outputs['Vector']
def noise(nt, vec, scale, detail=8, rough=0.55):
    n = N(nt, "ShaderNodeTexNoise"); n.inputs['Scale'].default_value = scale
    n.inputs['Detail'].default_value = detail; n.inputs['Roughness'].default_value = rough
    link(nt, vec, n.inputs['Vector']); return n

# ---------------------------------------------------------------- set materials
def wood_mat(name, axis, base, light):
    m, nt, out = new_mat(name)
    sc = {'Z': (6, 6, 0.35), 'X': (0.35, 6, 6)}[axis]
    nz = noise(nt, tcmap(nt, sc), 5, 10, 0.62)
    r = ramp(nt, [(0.3, base + (1,)), (0.75, light + (1,))]); link(nt, nz.outputs['Fac'], r.inputs['Fac'])
    nz2 = noise(nt, tcmap(nt, (0.6, 0.6, 0.6)), 2.2, 6)
    col_ = mix_rgb(nt, nz2.outputs['Fac'], r.outputs['Color'], (0.012, 0.008, 0.005, 1))
    bump = N(nt, "ShaderNodeBump"); bump.inputs['Strength'].default_value = 0.6; bump.inputs['Distance'].default_value = 0.02
    link(nt, nz.outputs['Fac'], bump.inputs['Height'])
    bs = N(nt, "ShaderNodeBsdfPrincipled"); bs.inputs['Roughness'].default_value = 0.58
    link(nt, col_, bs.inputs['Base Color']); link(nt, bump.outputs['Normal'], bs.inputs['Normal'])
    link(nt, bs.outputs['BSDF'], out.inputs['Surface']); return m

def floor_mat():
    m, nt, out = new_mat("HS_Floor"); vec = tcmap(nt)
    br = N(nt, "ShaderNodeTexBrick", offset=0.5, offset_frequency=2)
    for k, v in (('Scale', 1.0), ('Mortar Size', 0.012), ('Bias', 0), ('Brick Width', 2.2), ('Row Height', 0.34), ('Mortar Smooth', 0.3)):
        br.inputs[k].default_value = v
    br.inputs['Color1'].default_value = (0.035, 0.02, 0.012, 1); br.inputs['Color2'].default_value = (0.015, 0.009, 0.006, 1)
    link(nt, vec, br.inputs['Vector'])
    nz = noise(nt, vec, 24, 10)
    col_ = mix_rgb(nt, nz.outputs['Fac'], br.outputs['Color'], (0.17, 0.10, 0.055, 1))
    add = N(nt, "ShaderNodeMath", operation='ADD'); link(nt, br.outputs['Fac'], add.inputs[0]); link(nt, nz.outputs['Fac'], add.inputs[1])
    bump = N(nt, "ShaderNodeBump"); bump.inputs['Strength'].default_value = 0.45; bump.inputs['Distance'].default_value = 0.03
    link(nt, add.outputs['Value'], bump.inputs['Height'])
    rr = ramp(nt, [(0.0, (0.35, 0.35, 0.35, 1)), (1.0, (0.85, 0.85, 0.85, 1))]); link(nt, nz.outputs['Fac'], rr.inputs['Fac'])
    bs = N(nt, "ShaderNodeBsdfPrincipled"); bs.inputs['Specular IOR Level'].default_value = 0.6
    link(nt, col_, bs.inputs['Base Color']); link(nt, bump.outputs['Normal'], bs.inputs['Normal']); link(nt, rr.outputs['Color'], bs.inputs['Roughness'])
    link(nt, bs.outputs['BSDF'], out.inputs['Surface']); return m

def rock_mat():
    m, nt, out = new_mat("HS_Rock"); vec = tcmap(nt)
    vo = N(nt, "ShaderNodeTexVoronoi"); vo.inputs['Scale'].default_value = 2.2; link(nt, vec, vo.inputs['Vector'])
    nz = noise(nt, vec, 7, 12)
    comb = N(nt, "ShaderNodeMath", operation='MULTIPLY'); link(nt, vo.outputs['Distance'], comb.inputs[0]); link(nt, nz.outputs['Fac'], comb.inputs[1])
    r = ramp(nt, [(0.0, (0.012, 0.008, 0.006, 1)), (0.5, (0.05, 0.03, 0.02, 1)), (1.0, (0.14, 0.085, 0.05, 1))]); link(nt, comb.outputs['Value'], r.inputs['Fac'])
    bump = N(nt, "ShaderNodeBump"); bump.inputs['Strength'].default_value = 1.0; bump.inputs['Distance'].default_value = 0.25
    link(nt, comb.outputs['Value'], bump.inputs['Height'])
    bs = N(nt, "ShaderNodeBsdfPrincipled"); bs.inputs['Roughness'].default_value = 0.8
    link(nt, r.outputs['Color'], bs.inputs['Base Color']); link(nt, bump.outputs['Normal'], bs.inputs['Normal'])
    link(nt, bs.outputs['BSDF'], out.inputs['Surface']); return m

def gold_mat():
    m, nt, out = new_mat("HS_Gold"); vec = tcmap(nt)
    nz = noise(nt, vec, 40, 6)
    bump = N(nt, "ShaderNodeBump"); bump.inputs['Strength'].default_value = 0.12; bump.inputs['Distance'].default_value = 0.004
    link(nt, nz.outputs['Fac'], bump.inputs['Height'])
    rr = ramp(nt, [(0.0, (0.16, 0.16, 0.16, 1)), (1.0, (0.42, 0.42, 0.42, 1))]); link(nt, nz.outputs['Fac'], rr.inputs['Fac'])
    bs = N(nt, "ShaderNodeBsdfPrincipled"); bs.inputs['Base Color'].default_value = (1.0, 0.62, 0.14, 1); bs.inputs['Metallic'].default_value = 1.0
    link(nt, rr.outputs['Color'], bs.inputs['Roughness']); link(nt, bump.outputs['Normal'], bs.inputs['Normal'])
    link(nt, bs.outputs['BSDF'], out.inputs['Surface']); return m

def emit_mat(name, color, strength, gradient=False):
    m, nt, out = new_mat(name)
    em = N(nt, "ShaderNodeEmission"); em.inputs['Strength'].default_value = strength
    if gradient:
        vec = tcmap(nt, coord='Generated')
        sep = N(nt, "ShaderNodeSeparateXYZ"); link(nt, vec, sep.inputs['Vector'])
        nz = N(nt, "ShaderNodeTexNoise"); nz.inputs['Scale'].default_value = 3.5; nz.inputs['Detail'].default_value = 8; nz.inputs['Distortion'].default_value = 0.6
        link(nt, vec, nz.inputs['Vector'])
        add = N(nt, "ShaderNodeMath", operation='ADD'); link(nt, sep.outputs['Z'], add.inputs[0]); link(nt, nz.outputs['Fac'], add.inputs[1])
        r = ramp(nt, [(0.7, (0.35, 0.02, 0.0, 1)), (1.1, (1.0, 0.22, 0.02, 1)), (1.7, (1.0, 0.5, 0.08, 1))]); link(nt, add.outputs['Value'], r.inputs['Fac'])
        link(nt, r.outputs['Color'], em.inputs['Color'])
    else:
        em.inputs['Color'].default_value = color
    link(nt, em.outputs['Emission'], out.inputs['Surface']); return m

def iron_mat():
    m, nt, out = new_mat("HS_Iron"); bs = N(nt, "ShaderNodeBsdfPrincipled")
    bs.inputs['Base Color'].default_value = (0.05, 0.045, 0.04, 1); bs.inputs['Metallic'].default_value = 1; bs.inputs['Roughness'].default_value = 0.45
    link(nt, bs.outputs['BSDF'], out.inputs['Surface']); return m

MAT = {"floor": floor_mat(), "rock": rock_mat(), "gold": gold_mat(), "iron": iron_mat(),
       "woodZ": wood_mat("HS_WoodPost", 'Z', (0.09, 0.045, 0.02), (0.28, 0.15, 0.07)),
       "woodX": wood_mat("HS_WoodBeam", 'X', (0.09, 0.045, 0.02), (0.28, 0.15, 0.07)),
       "woodC": wood_mat("HS_WoodCrate", 'X', (0.06, 0.03, 0.014), (0.2, 0.105, 0.05)),
       "furnace": emit_mat("HS_Furnace", None, 1.4, gradient=True),
       "lantern": emit_mat("HS_Lantern", (1.0, 0.45, 0.1, 1), 9),
       "ember": emit_mat("HS_Ember", (1.0, 0.4, 0.06, 1), 40)}

# ---------------------------------------------------------------- geometry helpers
def add_obj(o):
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o); return o
def box(name, loc, size, mat, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new("Bevel", 'BEVEL'); b.width = bevel; b.segments = 2; b.limit_method = 'ANGLE'
    o.data.materials.append(mat); return add_obj(o)
def plane(name, loc, size, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name; o.scale = (size[0], size[1], 1)
    bpy.ops.object.transform_apply(scale=True); o.data.materials.append(mat); return add_obj(o)
def sphere(name, loc, r, mat, seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=seg // 2)
    o = bpy.context.active_object; o.name = name; o.data.materials.append(mat)
    bpy.ops.object.shade_smooth(); return add_obj(o)
def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); bpy.context.active_object.name = name; return bpy.context.active_object

plane("HS_Floor", (0, 2, 0), (40, 40), MAT["floor"])
plane("HS_BackWall", (0, 11, 5), (46, 12), MAT["rock"], rot=(math.pi / 2, 0, 0))
plane("HS_LeftWall", (-9, 3, 5), (30, 12), MAT["rock"], rot=(math.pi / 2, 0, math.pi / 2))
plane("HS_RightWall", (9, 3, 5), (30, 12), MAT["rock"], rot=(math.pi / 2, 0, math.pi / 2))
plane("HS_FurnaceGlow", (2.6, 10.6, 2.2), (4.2, 3.6), MAT["furnace"], rot=(math.pi / 2, 0, 0))
plane("HS_FurnaceGlow2", (-5.2, 10.5, 1.6), (2.4, 2.4), MAT["furnace"], rot=(math.pi / 2, 0, 0))
plane("HS_LavaStrip", (2.6, 9.0, 0.02), (4.4, 2.6), MAT["furnace"])

posts = [(-6.5, 8.5), (-3.2, 9.2), (0.4, 9.6), (4.9, 9.4), (7.5, 8.0), (-8.0, 5.5), (8.2, 4.5)]
for i, (x, y) in enumerate(posts):
    box(f"HS_Post{i}", (x, y, 3.6), (0.55, 0.55, 7.2), MAT["woodZ"], bevel=0.03)
for i, (y, z, w) in enumerate([(9.0, 5.6, 22), (7.0, 6.4, 22), (5.0, 7.0, 22)]):
    box(f"HS_Beam{i}", (0, y, z), (w, 0.45, 0.5), MAT["woodX"], bevel=0.03)
for i, x in enumerate([-7, -3.5, 0, 3.5, 7]):
    box(f"HS_Brace{i}", (x, 8.8, 5.0), (0.3, 0.3, 2.2), MAT["woodZ"], rot=(0, math.radians(38 if i % 2 else -38), 0), bevel=0.02)
for i, (x, y) in enumerate(posts[:4]):
    for z in (1.5, 3.4):
        box(f"HS_Strap{i}_{z}", (x, y, z), (0.62, 0.62, 0.18), MAT["iron"], bevel=0.02)

lantern_pts = [(-3.6, 1.4, 2.7), (-5.6, 4.2, 3.6), (-1.8, 6.0, 3.3), (1.9, 5.4, 3.9), (4.4, 3.3, 2.9),
               (6.1, 6.6, 3.4), (-7.0, 7.4, 2.6), (0.2, 8.6, 4.2), (3.3, 8.2, 2.6), (-2.2, 3.0, 4.4)]
for i, p in enumerate(lantern_pts):
    sphere(f"HS_LanternBulb{i}", p, 0.09, MAT["lantern"])
    box(f"HS_LanternCap{i}", (p[0], p[1], p[2] + 0.2), (0.3, 0.3, 0.06), MAT["iron"])
    bpy.ops.object.light_add(type='POINT', location=p)
    L = bpy.context.active_object; L.name = f"HS_LanternLight{i}"
    L.data.energy = 45; L.data.color = (1.0, 0.55, 0.2); L.data.shadow_soft_size = 0.15; add_obj(L)

for i, (x, y, rz, s) in enumerate([(-2.3, 3.2, 12, 0.9), (-2.9, 3.0, -18, 0.7), (2.7, 3.6, 8, 1.0), (3.4, 4.6, -24, 0.8), (-4.4, 5.2, 30, 1.2)]):
    box(f"HS_Crate{i}", (x, y, s / 2), (s, s, s), MAT["woodC"], rot=(0, 0, math.radians(rz)), bevel=0.02)

def gold_stack(prefix, origin, rows, cols, layers):
    bars = []
    for l in range(layers):
        for r in range(rows):
            for c_ in range(cols - (l % 2)):
                x = origin[0] + (c_ + 0.5 * (l % 2)) * 0.245 + random.uniform(-0.01, 0.01)
                y = origin[1] + r * 0.125 + random.uniform(-0.01, 0.01)
                bars.append(box(f"{prefix}_{l}_{r}_{c_}", (x, y, origin[2] + l * 0.075 + 0.0375), (0.23, 0.11, 0.07),
                                MAT["gold"], rot=(0, 0, random.uniform(-0.04, 0.04)), bevel=0.012))
    return join(bars, prefix)
gold_stack("HS_GoldFG_L", (-1.55, -2.2, 0), 3, 4, 4)
gold_stack("HS_GoldFG_R", (0.75, -2.5, 0), 4, 4, 5)
gold_stack("HS_GoldMid_R", (1.8, 1.6, 0), 3, 4, 3)

embers = [sphere(f"HS_Ember{i}", (random.uniform(-4.5, 5.5), random.uniform(-1.5, 8.5), random.uniform(0.4, 5.0)),
                 random.uniform(0.008, 0.022), MAT["ember"], seg=6) for i in range(40)]
join(embers, "HS_Embers")

bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 2.5, 4)); v = bpy.context.active_object
v.name = "HS_Haze"; v.scale = (30, 24, 8); v.display_type = 'WIRE'; add_obj(v)
vm, vnt, vout = new_mat("HS_HazeVol")
pv = N(vnt, "ShaderNodeVolumePrincipled"); pv.inputs['Color'].default_value = (1.0, 0.72, 0.5, 1); pv.inputs['Anisotropy'].default_value = 0.45
nz = N(vnt, "ShaderNodeTexNoise"); nz.inputs['Scale'].default_value = 0.35; nz.inputs['Detail'].default_value = 4
link(vnt, N(vnt, "ShaderNodeTexCoord").outputs['Object'], nz.inputs['Vector'])
mul = N(vnt, "ShaderNodeMath", operation='MULTIPLY'); mul.inputs[1].default_value = 0.012
link(vnt, nz.outputs['Fac'], mul.inputs[0]); link(vnt, mul.outputs['Value'], pv.inputs['Density'])
link(vnt, pv.outputs['Volume'], vout.inputs['Volume']); v.data.materials.append(vm)

# ---------------------------------------------------------------- character material upgrade
cm = bpy.data.materials["InfernoBull_RestoredPBR"]; nt = cm.node_tree
for _n in nt.nodes:
    if _n.bl_idname == 'ShaderNodeHueSaturation': _n.inputs['Saturation'].default_value = 1.0; _n.inputs['Value'].default_value = 1.0
if not any(n.label == "HERO_MASKS" for n in nt.nodes):
    bsdf = nt.nodes["Principled BSDF"]
    def src(sock):
        return sock.links[0].from_socket if sock.is_linked else None
    col_out = src(bsdf.inputs['Base Color']); rough_out = src(bsdf.inputs['Roughness']); metal_out = src(bsdf.inputs['Metallic']); nrm_out = src(bsdf.inputs['Normal'])
    hsv = N(nt, "ShaderNodeSeparateColor", mode='HSV', label="HERO_MASKS"); link(nt, col_out, hsv.inputs['Color'])
    def mr(inp, a, b, ta, tb, label):
        n = N(nt, "ShaderNodeMapRange", label=label, clamp=True)
        n.inputs['From Min'].default_value = a; n.inputs['From Max'].default_value = b
        n.inputs['To Min'].default_value = ta; n.inputs['To Max'].default_value = tb
        link(nt, inp, n.inputs['Value']); return n.outputs['Result']
    def mul(a, b):
        n = N(nt, "ShaderNodeMath", operation='MULTIPLY', use_clamp=True); link(nt, a, n.inputs[0]); link(nt, b, n.inputs[1]); return n.outputs['Value']
    def mixv(fac, a, b):   # float mix via Math: a + (b-a)*fac
        sub = N(nt, "ShaderNodeMath", operation='SUBTRACT')
        if isinstance(b, float): sub.inputs[0].default_value = b      # b may be a plain number (e.g. 0.28 brass roughness) or a socket
        else: link(nt, b, sub.inputs[0])
        if isinstance(a, float): sub.inputs[1].default_value = a
        else: link(nt, a, sub.inputs[1])
        m_ = N(nt, "ShaderNodeMath", operation='MULTIPLY'); link(nt, sub.outputs['Value'], m_.inputs[0]); link(nt, fac, m_.inputs[1])
        ad = N(nt, "ShaderNodeMath", operation='ADD'); link(nt, m_.outputs['Value'], ad.inputs[0])
        if isinstance(a, float): ad.inputs[1].default_value = a
        else: link(nt, a, ad.inputs[1])
        return ad.outputs['Value']
    H, Sat, V = hsv.outputs['Red'], hsv.outputs['Green'], hsv.outputs['Blue']
    fur = mul(mr(Sat, 0.10, 0.28, 1.0, 0.0, "fur_s"), mr(V, 0.06, 0.18, 0.0, 1.0, "fur_v"))
    brass = mul(mul(mr(Sat, 0.42, 0.62, 0.0, 1.0, "br_s"), mr(V, 0.45, 0.70, 0.0, 1.0, "br_v")),
                mul(mr(H, 0.04, 0.07, 0.0, 1.0, "br_h0"), mr(H, 0.15, 0.19, 1.0, 0.0, "br_h1")))
    # metallic: brass is real metal, everything else keeps (damped) the baked value
    damp = N(nt, "ShaderNodeMath", operation='MULTIPLY'); damp.inputs[1].default_value = 0.5; link(nt, metal_out, damp.inputs[0])
    brass95 = N(nt, "ShaderNodeMath", operation='MULTIPLY'); brass95.inputs[1].default_value = 0.95; link(nt, brass, brass95.inputs[0])
    mx_ = N(nt, "ShaderNodeMath", operation='MAXIMUM'); link(nt, damp.outputs['Value'], mx_.inputs[0]); link(nt, brass95.outputs['Value'], mx_.inputs[1])
    link(nt, mx_.outputs['Value'], bsdf.inputs['Metallic'])
    # roughness: baked map for leather, polished for brass, soft for fur
    r1 = mixv(brass, rough_out, 0.28)
    r2 = mixv(fur, r1, 0.88)
    link(nt, r2, bsdf.inputs['Roughness'])
    # fur sheen, leather coat
    sh = N(nt, "ShaderNodeMath", operation='MULTIPLY'); sh.inputs[1].default_value = 0.7; link(nt, fur, sh.inputs[0]); link(nt, sh.outputs['Value'], bsdf.inputs['Sheen Weight'])
    bsdf.inputs['Sheen Roughness'].default_value = 0.4; bsdf.inputs['Sheen Tint'].default_value = (0.85, 0.8, 0.75, 1)
    nf = N(nt, "ShaderNodeMath", operation='SUBTRACT'); nf.inputs[0].default_value = 1.0; link(nt, fur, nf.inputs[1])
    nb = N(nt, "ShaderNodeMath", operation='SUBTRACT'); nb.inputs[0].default_value = 1.0; link(nt, brass, nb.inputs[1])
    leather = mul(nf.outputs['Value'], nb.outputs['Value'])
    cw = N(nt, "ShaderNodeMath", operation='MULTIPLY'); cw.inputs[1].default_value = 0.15; link(nt, leather, cw.inputs[0]); link(nt, cw.outputs['Value'], bsdf.inputs['Coat Weight'])
    bsdf.inputs['Coat Roughness'].default_value = 0.4
    # micro-detail bump on top of the baked normal map
    uvn = N(nt, "ShaderNodeTexCoord"); mn = N(nt, "ShaderNodeTexNoise"); mn.inputs['Scale'].default_value = 700; mn.inputs['Detail'].default_value = 6
    link(nt, uvn.outputs['Object'], mn.inputs['Vector'])
    bm = N(nt, "ShaderNodeBump"); bm.inputs['Strength'].default_value = 0.2; bm.inputs['Distance'].default_value = 0.002
    link(nt, mn.outputs['Fac'], bm.inputs['Height'])
    if nrm_out: link(nt, nrm_out, bm.inputs['Normal'])
    link(nt, bm.outputs['Normal'], bsdf.inputs['Normal'])

# ---------------------------------------------------------------- camera / lights / world / render
bpy.data.objects["Floor"].hide_render = True; bpy.data.objects["Floor"].hide_viewport = True
ch = bpy.data.objects["char1"]; ev = ch.evaluated_get(bpy.context.evaluated_depsgraph_get())
pts = [ch.matrix_world @ Vector(c) for c in ev.bound_box]
mn_ = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx_v = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
tgt = Vector(((mn_.x + mx_v.x) / 2, (mn_.y + mx_v.y) / 2, mn_.z + (mx_v.z - mn_.z) * 0.52))

cam = bpy.data.objects["HeroCam"]; cam.data.lens = 55; cam.location = (0.45, -5.0, 1.0)
d = tgt - cam.location; cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
cam.data.dof.use_dof = True; cam.data.dof.focus_distance = d.length - 0.15; cam.data.dof.aperture_fstop = 2.2; cam.data.clip_end = 200

Lo = bpy.data.objects
def setl(name, loc, energy, color=None, size=None):
    o = Lo[name]; o.location = loc; o.data.energy = energy
    if color: o.data.color = color
    if size: o.data.size = size
    o.rotation_euler = (tgt - o.location).to_track_quat('-Z', 'Y').to_euler()
setl("Key", (-2.6, -4.2, 2.8), 520, (1.0, 0.9, 0.78), 0.9)
setl("Fill", (1.8, -4.0, 0.7), 70, (1.0, 0.85, 0.7), 2.5)
setl("Rim_Ember", (3.0, 3.2, 2.4), 2600)
setl("Rim_Cool", (-3.4, 2.8, 2.4), 260, (0.55, 0.65, 1.0))
bpy.ops.object.light_add(type='AREA', location=(-0.5, -3.2, 0.55)); fk = bpy.context.active_object; fk.name = "FaceKicker"
fk.data.energy = 140; fk.data.color = (1.0, 0.68, 0.38); fk.data.size = 0.9
fk.rotation_euler = (Vector((0, 0, 1.75)) - fk.location).to_track_quat('-Z', 'Y').to_euler()
for c in list(fk.users_collection): c.objects.unlink(fk)
S.collection.children["Presentation"].objects.link(fk)

bg = S.world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.045, 0.026, 0.014, 1); bg.inputs[1].default_value = 0.2

e = S.eevee
S.render.engine = 'BLENDER_EEVEE'
e.use_raytracing = RT; e.ray_tracing_method = 'SCREEN'
e.taa_render_samples = SAMPLES
e.use_shadows = True; e.shadow_ray_count = 2; e.shadow_step_count = 6
e.volumetric_start = 0.5; e.volumetric_end = 40; e.volumetric_samples = 48; e.volumetric_tile_size = '4'
e.use_volumetric_shadows = False
e.fast_gi_method = 'GLOBAL_ILLUMINATION'; e.gi_diffuse_bounces = 2; e.bokeh_max_size = 48
S.view_settings.view_transform = 'AgX'; S.view_settings.look = 'None'; S.view_settings.exposure = -0.6
S.render.resolution_x = 1600; S.render.resolution_y = 2000; S.render.resolution_percentage = PCT
S.render.image_settings.file_format = 'PNG'

if SAVE:
    bpy.ops.wm.save_mainfile()
if OUT:
    S.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
print("HERO_SCENE_DONE", OUT)
