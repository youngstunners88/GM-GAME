"""Founder Winchester GLB -> photoreal PBR hero render (headless, low-RAM).

    blender -b --python tools/ep2_blender/rifle_hero.py -- --glb <file.glb> --out <png> \
        [--w 960 --h 540 --samples 24 --tex 2048 --save <file.blend> --view 3q|side|top]

Never opens the artist's GUI session. Textures are downscaled in-process (the GLB ships 3x 4096^2).
Materials are split by albedo HSV masks: steel / brass / wood+leather / green skin (see skill ep2-rifle-realism).
"""
import bpy, math, sys, traceback
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(n, d=None): return argv[argv.index(n) + 1] if n in argv else d
GLB = arg("--glb"); OUT = arg("--out"); W = int(arg("--w", 960)); H = int(arg("--h", 540))
NEUTRAL = "--neutral" in argv
OC = [float(t) for t in arg("--oc", "").split(",")] if arg("--oc") else None; OS = float(arg("--os", 0) or 0)
ROLL = float(arg("--roll", 46.4))
ALIGN = "--align" in argv; FLIPX = "--flipx" in argv; FLIPZ = "--flipz" in argv; PRE = arg("--pre"); POST = arg("--post")
SAMPLES = int(arg("--samples", 24)); TEX = int(arg("--tex", 2048)); SAVE = arg("--save"); VIEW = arg("--view", "3q")

def log(*a): print("[rifle_hero]", *a, flush=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
S = bpy.context.scene
log("import", GLB)
bpy.ops.import_scene.gltf(filepath=GLB)
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and len(o.data.polygons) > 1000]
rifle = max(meshes, key=lambda o: len(o.data.polygons))
for o in list(bpy.data.objects):
    if o is not rifle: bpy.data.objects.remove(o, do_unlink=True)      # armature + helper sphere
rifle.parent = None
for m in list(rifle.modifiers): rifle.modifiers.remove(m)
rifle.vertex_groups.clear(); rifle.matrix_world.identity()
bpy.context.view_layer.objects.active = rifle
log("mesh", len(rifle.data.vertices), "verts", len(rifle.data.polygons), "polys")

# --- memory: downscale the 4096 maps
for img in bpy.data.images:
    if img.size[0] > TEX:
        img.scale(TEX, TEX); log("scaled", img.name[-30:], "->", TEX)

# --- orientation via PCA: long axis = barrel
import numpy as np
from mathutils import Matrix
if ALIGN:   # barrel -> +X, width -> Y, up -> Z (sign flips are chosen by looking at an ortho render, then passed as --flipx / --flipz)
    _v = np.array([tuple(p.co) for p in rifle.data.vertices]); _c = _v.mean(0)
    _u, _s, _vt = np.linalg.svd(_v - _c, full_matrices=False)
    ex = Vector(_vt[0]); ey = Vector(_vt[2]); ez = ex.cross(ey)
    if FLIPX: ex = -ex; ez = ex.cross(ey)
    if FLIPZ: ez = -ez; ey = ez.cross(ex)
    R = Matrix((ex, ey, ez))   # rows = new axes
    rifle.data.transform(R.to_4x4())
    # PCA is pulled off-axis by the diagonal forearm: measured on the receiver side plate, the rifle comes out rolled ~46 deg about the barrel.
    rifle.data.transform(Matrix.Rotation(math.radians(ROLL), 4, 'X')); rifle.data.update()
    log("aligned; extents", [round(x, 3) for x in rifle.dimensions])
if PRE:     # geometry-surgery hook, runs on the aligned mesh before materials/camera (shares this script's globals)
    exec(open(PRE).read(), globals()); log("pre-hook done", PRE)
v = np.array([tuple(p.co) for p in rifle.data.vertices]); c = v.mean(0)
u, s, vt = np.linalg.svd(v - c, full_matrices=False)
long_axis = Vector(vt[0]).normalized()
mn, mxv = v.min(0), v.max(0)
ctr = Vector(((mn + mxv) / 2).tolist()); size = float(np.linalg.norm(mxv - mn))
log("long axis", [round(x, 3) for x in long_axis], "size", round(size, 3))

# --- material: split by albedo masks
mat = rifle.data.materials[0]; nt = mat.node_tree
bsdf = [n for n in nt.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
def src(sock): return sock.links[0].from_socket if sock.is_linked else None
col_out, rough_out, metal_out, nrm_out = (src(bsdf.inputs[k]) for k in ("Base Color", "Roughness", "Metallic", "Normal"))
if col_out is None: raise SystemExit("albedo not linked - unexpected GLB layout")
def N(t, **kw):
    n = nt.nodes.new(t)
    for k, val in kw.items(): setattr(n, k, val)
    return n
def L(a, b): nt.links.new(a, b)
def mr(inp, a, b, ta, tb):
    n = N("ShaderNodeMapRange", clamp=True)
    n.inputs['From Min'].default_value = a; n.inputs['From Max'].default_value = b
    n.inputs['To Min'].default_value = ta; n.inputs['To Max'].default_value = tb
    L(inp, n.inputs['Value']); return n.outputs['Result']
def mul(a, b):
    n = N("ShaderNodeMath", operation='MULTIPLY', use_clamp=True); L(a, n.inputs[0]); L(b, n.inputs[1]); return n.outputs['Value']
def mulc(a, k):
    n = N("ShaderNodeMath", operation='MULTIPLY'); n.inputs[1].default_value = k; L(a, n.inputs[0]); return n.outputs['Value']
def lerp(fac, a, b):   # a, b: socket or float
    sub = N("ShaderNodeMath", operation='SUBTRACT')
    if isinstance(b, float): sub.inputs[0].default_value = b
    else: L(b, sub.inputs[0])
    if isinstance(a, float): sub.inputs[1].default_value = a
    else: L(a, sub.inputs[1])
    m = N("ShaderNodeMath", operation='MULTIPLY'); L(sub.outputs['Value'], m.inputs[0]); L(fac, m.inputs[1])
    ad = N("ShaderNodeMath", operation='ADD'); L(m.outputs['Value'], ad.inputs[0])
    if isinstance(a, float): ad.inputs[1].default_value = a
    else: L(a, ad.inputs[1])
    return ad.outputs['Value']
def inv(a):
    n = N("ShaderNodeMath", operation='SUBTRACT'); n.inputs[0].default_value = 1.0; L(a, n.inputs[1]); return n.outputs['Value']

hsv = N("ShaderNodeSeparateColor", mode='HSV'); L(col_out, hsv.inputs['Color'])
Hh, Ss, Vv = hsv.outputs['Red'], hsv.outputs['Green'], hsv.outputs['Blue']
green = mul(mr(Hh, 0.18, 0.22, 0.0, 1.0), mul(mr(Hh, 0.45, 0.40, 0.0, 1.0), mr(Ss, 0.30, 0.45, 0.0, 1.0)))
brass = mul(mul(mr(Ss, 0.45, 0.65, 0.0, 1.0), mr(Vv, 0.45, 0.70, 0.0, 1.0)), mul(mr(Hh, 0.05, 0.08, 0.0, 1.0), mr(Hh, 0.15, 0.19, 1.0, 0.0)))
steel = mul(mr(Ss, 0.42, 0.20, 0.0, 1.0), mr(Vv, 0.06, 0.16, 0.0, 1.0))
steel = mul(steel, inv(green))
# metallic
met_base = mulc(metal_out, 0.5) if metal_out else None
mn_ = N("ShaderNodeMath", operation='MAXIMUM')
L(mulc(steel, 0.92), mn_.inputs[0]); L(mulc(brass, 0.97), mn_.inputs[1])
mx2 = N("ShaderNodeMath", operation='MAXIMUM'); L(mn_.outputs['Value'], mx2.inputs[0]); L(met_base, mx2.inputs[1])
L(mx2.outputs['Value'], bsdf.inputs['Metallic'])
# roughness: baked map for the base, brass polished, steel satin-worn, skin soft
r = lerp(brass, rough_out, 0.3); r = lerp(steel, r, 0.38); r = lerp(green, r, 0.55)
L(r, bsdf.inputs['Roughness'])
# coat on organic/dielectric surfaces (varnished walnut, waxed leather), subsurface on the leaf-skin
dielec = mul(inv(steel), inv(brass)); dielec = mul(dielec, inv(green))
L(mulc(dielec, 0.22), bsdf.inputs['Coat Weight']); bsdf.inputs['Coat Roughness'].default_value = 0.35
# --- grade wood/leather: Tripo's walnut is orange; the reference is deep walnut. Only touches the dielectric mask.
hs = N("ShaderNodeHueSaturation"); hs.inputs['Hue'].default_value = 0.535; hs.inputs['Saturation'].default_value = 0.9; hs.inputs['Value'].default_value = 0.8
L(col_out, hs.inputs['Color'])
gm = N("ShaderNodeMix", data_type='RGBA', blend_type='MIX')
L(dielec, gm.inputs[0])
_A = [s for s in gm.inputs if s.name == 'A' and s.enabled][0]; _B = [s for s in gm.inputs if s.name == 'B' and s.enabled][0]
L(col_out, _A); L(hs.outputs['Color'], _B)
L([o for o in gm.outputs if o.name == 'Result' and o.enabled][0], bsdf.inputs['Base Color'])
# --- steel grade: Tripo bakes a warm cast into the metal; pull it to a cool dark gunmetal
hs2 = N("ShaderNodeHueSaturation"); hs2.inputs['Saturation'].default_value = 0.25; hs2.inputs['Value'].default_value = 0.62
L(col_out, hs2.inputs['Color'])
gm2 = N("ShaderNodeMix", data_type='RGBA', blend_type='MIX')
L(steel, gm2.inputs[0])
_A2 = [s for s in gm2.inputs if s.name == 'A' and s.enabled][0]; _B2 = [s for s in gm2.inputs if s.name == 'B' and s.enabled][0]
L(gm.outputs[[o.name for o in gm.outputs].index('Result') if False else [o for o in gm.outputs if o.name == 'Result' and o.enabled][0].identifier], _A2) if False else L([o for o in gm.outputs if o.name == 'Result' and o.enabled][0], _A2)
L(hs2.outputs['Color'], _B2)
L([o for o in gm2.outputs if o.name == 'Result' and o.enabled][0], bsdf.inputs['Base Color'])
L(mulc(green, 0.25), bsdf.inputs['Subsurface Weight']); bsdf.inputs['Subsurface Scale'].default_value = 0.01
bsdf.inputs['Subsurface Radius'].default_value = (0.4, 0.8, 0.2)
bsdf.inputs['Sheen Weight'].default_value = 0.0
# micro surface: fine noise bump over the baked normal
tc = N("ShaderNodeTexCoord"); nz = N("ShaderNodeTexNoise"); nz.inputs['Scale'].default_value = 900; nz.inputs['Detail'].default_value = 7
L(tc.outputs['Object'], nz.inputs['Vector'])
bm = N("ShaderNodeBump"); bm.inputs['Strength'].default_value = 0.18; bm.inputs['Distance'].default_value = 0.0015
L(nz.outputs['Fac'], bm.inputs['Height'])
if nrm_out: L(nrm_out, bm.inputs['Normal'])
L(bm.outputs['Normal'], bsdf.inputs['Normal'])
for o in bpy.data.objects:
    if o.type == 'MESH':
        for p in o.data.polygons:
            if p.material_index == 0 and o.name != "LogoDecal": p.use_smooth = True   # keep the octagonal barrel flats hard

# --- stage: dark glossy floor + gradient world
S.world = bpy.data.worlds.new("W"); S.world.use_nodes = True
bg = S.world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.02, 0.014, 0.010, 1); bg.inputs[1].default_value = 0.12
fl_z = mn[2] if False else float(min(p.co.z for p in rifle.data.vertices)) - 0.02
bpy.ops.mesh.primitive_plane_add(size=20, location=(ctr.x, ctr.y, fl_z)); floor = bpy.context.active_object; floor.name = "Stage_Floor"
fm = bpy.data.materials.new("Stage_Floor"); fm.use_nodes = True
fb = fm.node_tree.nodes["Principled BSDF"]; fb.inputs['Base Color'].default_value = (0.006, 0.004, 0.003, 1); fb.inputs['Roughness'].default_value = 0.3
floor.data.materials.append(fm)

# --- camera
cam_d = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cam_d); S.collection.objects.link(cam); S.camera = cam
cam_d.lens = 85; cam_d.dof.use_dof = True; cam_d.dof.aperture_fstop = 5.6
side = Vector((0, 0, 1)).cross(long_axis).normalized()      # horizontal-ish perpendicular to the barrel
dist = size * 1.9 * float(arg("--dm", 1.0))
view = {"3q": (side * 0.8 + long_axis * 0.55, 0.42), "side": (side, 0.12), "top": (side * 0.2, 1.4)}.get(VIEW, (side, 0.12))
aim = ctr
if VIEW == "fps" and ALIGN:      # shooter's-eye: behind and slightly beside the stock, looking down the barrel (matches the founder's FPS reference)
    view = (Vector((-1.0, -0.55, 0.0)), 0.22); aim = ctr + Vector((0.22 * size, 0, 0))
cam.location = ctr + view[0].normalized() * dist + Vector((0, 0, view[1] * size))
cam.rotation_euler = (aim - cam.location).to_track_quat('-Z', 'Y').to_euler()
if VIEW in ("oside", "otop", "obot"):   # orthographic inspection views in the aligned frame
    cam_d.type = 'ORTHO'; cam_d.ortho_scale = (mxv[0] - mn[0]) * 1.3; cam_d.dof.use_dof = False
    off = {"oside": Vector((0, -5, 0)), "otop": Vector((0, 0, 5)), "obot": Vector((0, 0, -5))}[VIEW]
    cam.location = ctr + off
    if OS: cam_d.ortho_scale = OS
    if OC: cam.location = Vector(OC) + off
    cam.rotation_euler = {"oside": (math.pi / 2, 0, 0), "otop": (0, 0, 0), "obot": (math.pi, 0, 0)}[VIEW]
cam_d.dof.focus_distance = (ctr - cam.location).length
S.render.resolution_x = W; S.render.resolution_y = H

# --- lights: warm key, ember rim, cool kicker + emissive soft-box cards so the metal has something to reflect
def area(name, loc, energy, color, sz):
    d = bpy.data.lights.new(name, 'AREA'); d.energy = energy; d.color = color; d.size = sz
    o = bpy.data.objects.new(name, d); S.collection.objects.link(o); o.location = loc
    o.rotation_euler = (ctr - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); return o
k = size
# lights are placed from the ACTUAL camera direction: key front-left of camera, rim/kick BEHIND the subject.
# (An earlier version put the orange rim on the camera side, front-lighting the gun orange and tinting every metal copper.)
dcam = cam.location - ctr; dcam.z = 0
dcam = dcam.normalized() if dcam.length > 1e-6 else Vector((0, -1, 0))
right_ = Vector((0, 0, 1)).cross(dcam).normalized()      # camera-right
up_ = Vector((0, 0, 1))
area("Key", ctr + dcam * 0.8 * k - right_ * 0.8 * k + up_ * 1.0 * k, 320 * k * k, (1.0, 0.93, 0.84), 0.35 * k)
area("Rim", ctr - dcam * 0.9 * k + right_ * 0.6 * k + up_ * 0.6 * k, 160 * k * k, (1.0, 0.5, 0.18), 0.4 * k)
area("Kick", ctr - dcam * 0.7 * k - right_ * 0.9 * k + up_ * 0.4 * k, 40 * k * k, (0.55, 0.68, 1.0), 0.5 * k)
def card(name, loc, sz, strength, color):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc); o = bpy.context.active_object; o.name = name; o.scale = (sz[0], sz[1], 1)
    o.rotation_euler = (ctr - Vector(loc)).to_track_quat('Z', 'Y').to_euler()
    m = bpy.data.materials.new(name); m.use_nodes = True; e = m.node_tree.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = color; e.inputs[1].default_value = strength
    m.node_tree.links.new(e.outputs[0], m.node_tree.nodes["Material Output"].inputs[0]); o.data.materials.append(m)
    o.visible_camera = False
card("Card_Top", ctr + Vector((0, 0, 1.3 * k)), (1.6 * k, 0.07 * k), 9.0, (1.0, 0.9, 0.75, 1))
card("Card_Side", ctr + dcam * 0.4 * k - right_ * 1.3 * k + Vector((0, 0, 0.25 * k)), (0.06 * k, 0.9 * k), 5.0, (1.0, 0.7, 0.4, 1))

# --- render settings
e = S.eevee; S.render.engine = 'BLENDER_EEVEE'
e.taa_render_samples = SAMPLES; e.use_raytracing = True; e.ray_tracing_method = 'SCREEN'
e.use_shadows = True; e.fast_gi_method = 'GLOBAL_ILLUMINATION'
if NEUTRAL:
    S.view_settings.view_transform = 'Standard'
    for o in S.objects:
        if o.type == 'LIGHT': o.data.color = (1, 1, 1)
else:
    S.view_settings.view_transform = 'AgX'; S.view_settings.look = 'None'; S.view_settings.exposure = 0.5
S.render.image_settings.file_format = 'PNG'
if POST:
    exec(open(POST).read(), globals()); log("post-hook done", POST)
if SAVE: bpy.ops.wm.save_as_mainfile(filepath=SAVE); log("saved", SAVE)
if OUT:
    S.render.filepath = OUT; log("render start", W, H, SAMPLES)
    bpy.ops.render.render(write_still=True); log("render done", OUT)
