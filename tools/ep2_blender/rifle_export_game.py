# post-hook for rifle_hero.py (exec'd inside it, shares its globals: bpy, S, rifle, arg, log, np, math, Matrix, Vector).
# Turns the node-graph "hero" materials into plain textures a GLB can carry and exports a game-ready rifle.
#   blender -b --python tools/ep2_blender/rifle_hero.py -- --glb <tripo.glb> --align --flipx --pre tools/ep2_blender/rifle_surgery.py \
#       --logo <GOLD_LOGO.png> --tex 1024 --post tools/ep2_blender/rifle_export_game.py --game-out src/episode2/assets/weapons/winchester_1886_founder.glb
# Output frame: muzzle +Z, up +Y, ~1.2 m long, centred (skill ep2-founder-weapon-glb). Never touches the GUI session.
import os, tempfile
GAME_OUT = arg("--game-out"); BAKE = int(arg("--bake", 1024)); TRIS = int(arg("--tris", 12000))
work = tempfile.mkdtemp(prefix="rifle_bake_")
def clean_stage():
    for o in list(bpy.data.objects):
        if o.name.startswith(("Stage_", "Cam", "Card_", "Key", "Fill", "Rim")) or o.type in ('LIGHT', 'CAMERA'): bpy.data.objects.remove(o, do_unlink=True)
clean_stage()
dec = bpy.data.objects.get("LogoDecal")
# 1. decimate the body (barrel pieces are low-poly already; the Tripo body is ~50k)
bpy.context.view_layer.objects.active = rifle
dm = rifle.modifiers.new("dec", "DECIMATE"); dm.ratio = min(1.0, TRIS / max(1, len(rifle.data.polygons)))
bpy.ops.object.modifier_apply(modifier="dec"); log("game: decimated to", len(rifle.data.polygons), "polys")
# 2. bake slot 0 (the graded Tripo material) to color / roughness / metallic with Cycles on the CPU
S.render.engine = 'CYCLES'; S.cycles.device = 'CPU'; S.cycles.samples = 8; S.cycles.use_denoising = False
mat0 = rifle.data.materials[0]; nt0 = mat0.node_tree
bsdf0 = [n for n in nt0.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
def bake_to(kind, path):
    img = bpy.data.images.new("bake_" + kind, BAKE, BAKE, alpha=False); img.colorspace_settings.name = 'sRGB' if kind == 'color' else 'Non-Color'
    tn = nt0.nodes.new("ShaderNodeTexImage"); tn.image = img; nt0.nodes.active = tn
    for p in rifle.data.polygons: pass
    S.cycles.bake_type = {'color': 'DIFFUSE', 'rough': 'ROUGHNESS', 'metal': 'EMIT'}[kind]
    bpy.ops.object.select_all(action='DESELECT'); rifle.select_set(True); bpy.context.view_layer.objects.active = rifle
    if kind == 'color':
        bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=6, use_clear=True)
    elif kind == 'rough':
        bpy.ops.object.bake(type='ROUGHNESS', margin=6, use_clear=True)
    else:   # metallic via emission: route the Metallic input into an Emission shader, bake EMIT, restore
        out = [n for n in nt0.nodes if n.bl_idname == "ShaderNodeOutputMaterial"][0]
        em = nt0.nodes.new("ShaderNodeEmission"); old = out.inputs['Surface'].links[0].from_socket
        if bsdf0.inputs['Metallic'].is_linked:
            col = nt0.nodes.new("ShaderNodeCombineColor")
            for ch in ('Red', 'Green', 'Blue'): nt0.links.new(bsdf0.inputs['Metallic'].links[0].from_socket, col.inputs[ch])
            nt0.links.new(col.outputs['Color'], em.inputs['Color'])
        else: em.inputs['Color'].default_value = (bsdf0.inputs['Metallic'].default_value,) * 3 + (1,)
        nt0.links.new(em.outputs['Emission'], out.inputs['Surface'])
        bpy.ops.object.bake(type='EMIT', margin=6, use_clear=True)
        nt0.links.new(old, out.inputs['Surface'])
    img.filepath_raw = path; img.file_format = 'PNG'; img.save(); nt0.nodes.remove(tn); log("game: baked", kind)
    return path
pc = bake_to('color', os.path.join(work, "c.png")); pr = bake_to('rough', os.path.join(work, "r.png")); pm = bake_to('metal', os.path.join(work, "m.png"))
# keep the original normal map (downscaled), pack glTF metal-rough (G = roughness, B = metallic)
from PIL import Image
a, b = Image.open(pr).convert("RGB"), Image.open(pm).convert("RGB")
mr = Image.merge("RGB", (Image.new("L", a.size, 255), a.split()[0], b.split()[0])).resize((256, 256), Image.LANCZOS)
tex_dir = os.path.join(os.path.dirname(os.path.abspath(GAME_OUT)), "textures_tmp"); os.makedirs(tex_dir, exist_ok=True)
mr.save(os.path.join(tex_dir, "rifle_mr.png")); Image.open(pc).convert("RGB").save(os.path.join(tex_dir, "rifle_color.jpg"), quality=78)
nimg = None
for n in nt0.nodes:
    if n.bl_idname == "ShaderNodeTexImage" and n.image and "normal" in n.image.name.lower(): nimg = n.image
if nimg and "--normal" in argv:      # off by default: the web pack has ~2 MiB of headroom, the normal map alone was 1 MB
    nimg.scale(512, 512); nimg.filepath_raw = os.path.join(tex_dir, "rifle_normal.png"); nimg.file_format = 'PNG'; nimg.save()
# 3. rebuild slot 0 as a plain glTF-friendly material
m = bpy.data.materials.new("Winchester_Body"); m.use_nodes = True; t = m.node_tree; b0 = t.nodes["Principled BSDF"]
def tex(path, cs):
    n = t.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(path); n.image.colorspace_settings.name = cs; return n
tc_ = tex(os.path.join(tex_dir, "rifle_color.jpg"), 'sRGB'); t.links.new(tc_.outputs['Color'], b0.inputs['Base Color'])
tm_ = tex(os.path.join(tex_dir, "rifle_mr.png"), 'Non-Color'); sp = t.nodes.new("ShaderNodeSeparateColor"); t.links.new(tm_.outputs['Color'], sp.inputs['Color'])
t.links.new(sp.outputs['Green'], b0.inputs['Roughness']); t.links.new(sp.outputs['Blue'], b0.inputs['Metallic'])
if nimg and "--normal" in argv:
    tn_ = tex(os.path.join(tex_dir, "rifle_normal.png"), 'Non-Color'); nm = t.nodes.new("ShaderNodeNormalMap"); t.links.new(tn_.outputs['Color'], nm.inputs['Color']); t.links.new(nm.outputs['Normal'], b0.inputs['Normal'])
rifle.data.materials[0] = m
# barrel steel (slot 1): factor-only dark gunmetal (GLB cannot carry its procedural noise)
bs = rifle.data.materials[1]; bs.node_tree.nodes.clear(); o_ = bs.node_tree.nodes.new("ShaderNodeOutputMaterial"); bb = bs.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
bb.inputs['Base Color'].default_value = (0.13, 0.135, 0.15, 1); bb.inputs['Metallic'].default_value = 0.95; bb.inputs['Roughness'].default_value = 0.34
bs.node_tree.links.new(bb.outputs['BSDF'], o_.inputs['Surface'])
# 4. GM logo decal: PIL re-creation of the node math (circle mask * value key; green-outline emission)
if dec is not None and arg("--logo"):
    L_ = Image.open(arg("--logo")).convert("RGBA"); w, h = L_.size
    crop = L_.crop((int(0.14 * w), int((1 - 0.926) * h), int(0.86 * w), int((1 - 0.186) * h))).resize((256, 256))
    arr = np.asarray(crop).astype(np.float32) / 255.0; yy, xx = np.mgrid[0:256, 0:256] / 255.0
    r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) / 0.72   # crop is 0.72 wide in uv; normalised radius
    radial = np.clip((0.37 / 0.72 * 1.0 - r) / ((0.37 - 0.352) / 0.72), 0, 1)
    val = arr[..., :3].max(-1)
    # The dark disc behind the emblem used to be keyed TRANSPARENT; on the rifle that showed whatever lay under the decal
    # (the receiver's open shell = a black see-through hole - founder 2026-10-06 "we see through the rifle"). It is now an
    # OPAQUE dark gunmetal enamel disc, cut to a circle with a hard alpha-mask (no blend sorting).
    key = np.clip((val - 0.16) / 0.14, 0, 1)
    enamel = np.array([0.075, 0.072, 0.068], dtype=np.float32)
    rgb = arr[..., :3] * key[..., None] + enamel * (1.0 - key[..., None])
    alpha = (radial > 0.5).astype(np.float32)
    gl = np.clip(((arr[..., 1] - arr[..., 0] * 1.15) - 0.05) / 0.30, 0, 1)
    emit = np.clip(arr[..., :3] * key[..., None] * 0.45 + gl[..., None] * np.array([0.2, 1.0, 0.08]) * 0.9, 0, 1)
    Image.fromarray((np.dstack([rgb, alpha]) * 255).astype(np.uint8), "RGBA").save(os.path.join(tex_dir, "logo_color.png"))
    Image.fromarray((emit * 255).astype(np.uint8)).save(os.path.join(tex_dir, "logo_emit.png"))
    dm_ = bpy.data.materials.new("GM_Logo"); dm_.use_nodes = True; t = dm_.node_tree; b1 = t.nodes["Principled BSDF"]; dm_.blend_method = 'CLIP'; dm_.alpha_threshold = 0.5
    tc2 = tex(os.path.join(tex_dir, "logo_color.png"), 'sRGB'); t.links.new(tc2.outputs['Color'], b1.inputs['Base Color']); t.links.new(tc2.outputs['Alpha'], b1.inputs['Alpha'])
    te2 = tex(os.path.join(tex_dir, "logo_emit.png"), 'sRGB'); t.links.new(te2.outputs['Color'], b1.inputs['Emission Color']); b1.inputs['Emission Strength'].default_value = 1.0
    b1.inputs['Metallic'].default_value = 0.55; b1.inputs['Roughness'].default_value = 0.3
    dec.data.materials.clear(); dec.data.materials.append(dm_)
# 4b. SOLID from every side (founder 2026-10-05 "make the rifle solid"): the Tripo body is a set of single-sided shells; with
#     back-face culling the shouldered camera looked INTO open shells (dark boxes, a thin barrel sheet). Double-sided = glTF doubleSided.
for _m in rifle.data.materials: _m.use_backface_culling = False
if dec is not None:
    for _m in dec.data.materials: _m.use_backface_culling = False
# 5. frame: muzzle +X,up +Z  ->  Godot muzzle +Z, up +Y;  length 1.2 m, centred
parts = [rifle] + ([dec] if dec else [])
for o in parts: o.data.transform(Matrix.Rotation(math.radians(-90), 4, 'Z'))
allv = np.array([tuple(p.co) for o in parts for p in o.data.vertices]); mn_, mx_ = allv.min(0), allv.max(0)
sc = 1.2 / (mx_[1] - mn_[1]); cen = (mn_ + mx_) / 2
# the barrel/mag-tube pieces (material slot 1) sit on the true gun axis; the gloved forearm sticks out sideways and would
# drag a bounding-box centre off it. Centre the LATERAL axis (x after the turn) on the barrel so ADS looks down the barrel.
_bv = np.array([tuple(rifle.data.vertices[v].co) for pl in rifle.data.polygons if pl.material_index == 1 for v in pl.vertices])
cen[0] = float(_bv[:, 0].mean()); log("game: barrel axis x", round(cen[0], 4))
for o in parts: o.data.transform(Matrix.Scale(sc, 4) @ Matrix.Translation(-Vector(cen)))
log("game: scale", round(sc, 3), "extent", [round(float(x * sc), 3) for x in (mx_ - mn_)])
if "--rays" in argv:      # DEBUG: what does the shouldered camera actually SEE? (Blender frame now: muzzle -Y, up +Z)
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(rifle, bpy.context.evaluated_depsgraph_get())
    camp = Vector((0.0, -0.14, 0.19)); t29 = math.tan(math.radians(29))
    for py in (150, 250, 350, 450, 520):
        for px in (300, 480, 660):
            nx = (px - 480) / 270.0; ny = (270 - py) / 270.0
            d = Vector((nx * t29, -1.0, ny * t29)).normalized()
            h = bvh.ray_cast(camp, d)
            if h[0] is None: log("ray", px, py, "miss"); continue
            poly = rifle.data.polygons[h[2]]
            log("ray", px, py, "hit mat", poly.material_index, "dist", round(h[3], 3), "n.d", round(h[1].dot(d), 2), "at", [round(c, 3) for c in h[0]])
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
os.makedirs(os.path.dirname(os.path.abspath(GAME_OUT)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=GAME_OUT, export_format="GLB", use_selection=True, export_apply=True, export_image_format="AUTO", export_jpeg_quality=78, export_texcoords=True, export_normals=True, export_materials="EXPORT")
log("game: wrote", GAME_OUT, os.path.getsize(GAME_OUT) // 1024, "KB"); log("render done (game export)")
