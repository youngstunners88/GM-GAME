# post-hook for rifle_hero.py (exec'd inside it, shares its globals: bpy, S, rifle, arg, log, np, math, Matrix, Vector).
# Turns the node-graph "hero" materials into plain textures a GLB can carry and exports a game-ready rifle.
#   blender -b --python tools/ep2_blender/rifle_hero.py -- --glb <tripo.glb> --align --flipx --pre tools/ep2_blender/rifle_surgery.py \
#       --logo <GOLD_LOGO.png> --tex 1024 --post tools/ep2_blender/rifle_export_game.py --game-out src/episode2/assets/weapons/winchester_1886_founder.glb
# Output frame: muzzle +Z, up +Y, ~1.2 m long, centred (skill ep2-founder-weapon-glb). Never touches the GUI session.
import os, sys, tempfile
GAME_OUT = arg("--game-out"); BAKE = int(arg("--bake", 2048)); TRIS = int(arg("--tris", 12000))
work = tempfile.mkdtemp(prefix="rifle_bake_")
def clean_stage():
    for o in list(bpy.data.objects):
        if o.name.startswith(("Stage_", "Cam", "Card_", "Key", "Fill", "Rim")) or o.type in ('LIGHT', 'CAMERA'): bpy.data.objects.remove(o, do_unlink=True)
clean_stage()
dec = bpy.data.objects.get("LogoDecal")
if dec is not None:      # founder 2026-10-09: "not a fucking sticker" - the logo is PAINTED INTO the rifle's own albedo (step 2b), no overlay mesh
    bpy.data.objects.remove(dec, do_unlink=True); dec = None
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
# 2b. ONE WITH THE RIFLE: planar-project the GM emblem into the baked albedo (and a small emission map) over the receiver side plates,
#     replacing the Tripo baked emblem in place. Engraved look: the emblem is modulated by the plate's own wear, edge feathered.
EMIT_PATH = None
if arg("--logo"):
    import subprocess
    from PIL import Image as _I
    subprocess.run([sys.executable, "-I", os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_gm_emblem.py"), arg("--logo"), work] + ([] if "--bold" in argv else ["--classic"]), check=True)
    emb = np.asarray(_I.open(os.path.join(work, "emblem_color.png")).convert("RGBA")).astype(np.float32) / 255.0
    embe = np.asarray(_I.open(os.path.join(work, "emblem_emit.png")).convert("RGB")).astype(np.float32) / 255.0
    EN = emb.shape[0]
    base = np.asarray(_I.open(pc).convert("RGB")).astype(np.float32) / 255.0
    emit_img = np.zeros_like(base)
    PX, PZ, DD = float(arg("--lx", -0.09)), float(arg("--lz", 0.455)), float(arg("--ld", 0.22))
    N_ = base.shape[0]; uvl = rifle.data.uv_layers.active.data
    from mathutils.bvhtree import BVHTree as _BVH
    _bvh = _BVH.FromObject(rifle, bpy.context.evaluated_depsgraph_get())
    PLATE_Y = {}
    for _sd in (1.0, -1.0):       # y of the receiver side plate on each side; only texels ON that plate get painted (not the lever loop behind it)
        _h = _bvh.ray_cast(Vector((PX, _sd, PZ)), Vector((0, -_sd, 0))); PLATE_Y[_sd] = _h[0].y if _h[0] else 0.26 * _sd
    log("game: plate y", PLATE_Y)
    # Tripo's emblem relief is a faceted, rippled surface (y 0.10..0.13); a texture painted on ripples reads as shattered glass. Flatten the
    # relief into a plain plate at the ray-hit plane (blend out over a ring) so the emblem is a flat inlay and reads cleanly.
    _y0 = PLATE_Y[1.0] + 0.001; _r0, _r1 = DD * 0.5, DD * 0.62; _n = 0
    for v in rifle.data.vertices:
        r_ = math.hypot(v.co.x - PX, v.co.z - PZ)
        if r_ < _r1 and 0.095 < v.co.y < 0.14:
            k_ = 1.0 if r_ < _r0 else 1.0 - (r_ - _r0) / (_r1 - _r0); k_ = k_ * k_ * (3 - 2 * k_)
            v.co.y = v.co.y * (1 - k_) + _y0 * k_; _n += 1
    rifle.data.update(); log("game: flattened", _n, "relief verts to y", round(_y0, 4))
    done = 0
    for pl in rifle.data.polygons:
        if pl.material_index != 0 or abs(pl.normal.y) < 0.35: continue
        side = 1.0 if pl.normal.y > 0 else -1.0
        if side < 0 and "--both" not in argv: continue      # only the side the shooter sees (the -Y plate shares UV texels with it)
        vs = [rifle.data.vertices[v].co for v in pl.vertices]
        if min(math.hypot(c.x - PX, c.z - PZ) for c in vs) > DD * 0.9: continue
        for k in range(1, len(pl.loop_indices) - 1):
            li = (pl.loop_indices[0], pl.loop_indices[k], pl.loop_indices[k + 1]); pv = (vs[0], vs[k], vs[k + 1])
            uvs = np.array([[uvl[i].uv.x * N_, (1 - uvl[i].uv.y) * N_] for i in li]); P3 = np.array([[c.x, c.y, c.z] for c in pv])
            x0, x1 = int(max(0, uvs[:, 0].min() - 1)), int(min(N_ - 1, uvs[:, 0].max() + 1)); y0, y1 = int(max(0, uvs[:, 1].min() - 1)), int(min(N_ - 1, uvs[:, 1].max() + 1))
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            a_, b_, c_ = uvs; den = (b_[1] - c_[1]) * (a_[0] - c_[0]) + (c_[0] - b_[0]) * (a_[1] - c_[1])
            if abs(den) < 1e-9: continue
            w0 = ((b_[1] - c_[1]) * (gx - c_[0]) + (c_[0] - b_[0]) * (gy - c_[1])) / den
            w1 = ((c_[1] - a_[1]) * (gx - c_[0]) + (a_[0] - c_[0]) * (gy - c_[1])) / den; w2 = 1 - w0 - w1
            ins = (w0 >= -0.12) & (w1 >= -0.12) & (w2 >= -0.12)   # 1-2 texel dilation so charts have no unpainted gaps (those bled black slivers)
            X3 = w0 * P3[0, 0] + w1 * P3[1, 0] + w2 * P3[2, 0]; Z3 = w0 * P3[0, 2] + w1 * P3[1, 2] + w2 * P3[2, 2]
            Y3 = w0 * P3[0, 1] + w1 * P3[1, 1] + w2 * P3[2, 1]
            ins = ins & (np.abs(Y3 - PLATE_Y[side]) < 0.03)
            u = (-(X3 - PX) * side) / DD + 0.5; v = 0.5 - (Z3 - PZ) / DD       # viewer on +Y sees -X to the right; on -Y sees +X to the right
            rr = np.hypot(u - 0.5, v - 0.5) * 2
            m = ins & (rr < 1.0)
            if not m.any(): continue
            ec = np.concatenate([np.zeros(rr.shape + (3,), np.float32), np.ones(rr.shape + (1,), np.float32)], -1); ee = np.zeros(rr.shape + (3,), np.float32)
            feather = np.clip((1.0 - rr) / 0.06, 0, 1)                       # soft edge into the plate, never a hard sticker rim
            alpha = (ec[..., 3] * feather)[..., None]
            py_, px_ = (gy - 0.5).astype(int), (gx - 0.5).astype(int)
            orig = base[py_, px_]; lum = orig.mean(-1, keepdims=True)
            wear = np.clip(0.90 + 0.30 * lum, 0.90, 1.10)                    # the plate's own scratches/grime show through the emblem
            newc = np.clip(orig * 0.42 * wear, 0, 1)      # a darkened, worn seat: the old Tripo emblem is gone, the plate grain stays
            sel = m[..., None]
            base[py_, px_] = np.where(sel, orig * (1 - alpha) + newc * alpha, orig)
            emit_img[py_, px_] = np.where(sel, ee * alpha * feather[..., None], emit_img[py_, px_])
        done += 1
    log("game: painted emblem into", done, "receiver faces")
    _I.fromarray((base * 255).astype(np.uint8)).save(pc)
    EMIT_PATH = None        # the glow lives on the badge face now
    BADGE = dict(PX=PX, PZ=PZ, Y0=_y0)
# keep the original normal map (downscaled), pack glTF metal-rough (G = roughness, B = metallic)
from PIL import Image
a, b = Image.open(pr).convert("RGB"), Image.open(pm).convert("RGB")
mr = Image.merge("RGB", (Image.new("L", a.size, 255), a.split()[0], b.split()[0])).resize((256, 256), Image.LANCZOS)
tex_dir = os.path.join(os.path.dirname(os.path.abspath(GAME_OUT)), "textures_tmp"); os.makedirs(tex_dir, exist_ok=True)
mr.save(os.path.join(tex_dir, "rifle_mr.png")); Image.open(pc).convert("RGB").save(os.path.join(tex_dir, "rifle_color.jpg"), quality=int(arg("--jq", 66)))
if EMIT_PATH is not None:
    Image.fromarray((np.clip(EMIT_PATH, 0, 1) * 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS).save(os.path.join(tex_dir, "rifle_emit.png"), optimize=True)
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
if EMIT_PATH is not None:
    te_ = tex(os.path.join(tex_dir, "rifle_emit.png"), 'sRGB'); t.links.new(te_.outputs['Color'], b0.inputs['Emission Color']); b0.inputs['Emission Strength'].default_value = 1.7
rifle.data.materials[0] = m
# barrel steel (slot 1): factor-only dark gunmetal (GLB cannot carry its procedural noise)
bs = rifle.data.materials[1]; bs.node_tree.nodes.clear(); o_ = bs.node_tree.nodes.new("ShaderNodeOutputMaterial"); bb = bs.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
bb.inputs['Base Color'].default_value = (0.13, 0.135, 0.15, 1); bb.inputs['Metallic'].default_value = 0.95; bb.inputs['Roughness'].default_value = 0.34
bs.node_tree.links.new(bb.outputs['BSDF'], o_.inputs['Surface'])

# 3b. THE BADGE (founder 2026-10-09: "it mustn't look painted on - it must be like a badge or engraving"): REAL geometry. A raised, bevelled gold
#     bezel ring seated in the worn plate, an inset enamel face carrying the GM logo (with its own chain ring), lit and parallaxing like metal.
if arg("--logo") and 'BADGE' in globals():
    from PIL import Image as _I2
    _lg = _I2.open(os.path.join(work, "emblem_color.png")).convert("RGB"); _lg.save(os.path.join(tex_dir, "emblem_color.jpg"), quality=86)
    _I2.open(os.path.join(work, "emblem_emit.png")).convert("RGB").resize((256, 256), _I2.LANCZOS).save(os.path.join(tex_dir, "emblem_emit.png"), optimize=True)
    BX, BZ, Y0 = BADGE['PX'], BADGE['PZ'], BADGE['Y0']
    RO, RI, H = float(arg("--br", 0.092)), None, 0.0048
    RI = RO * 0.80
    prof = [(RI, Y0 - 0.002), (RI, Y0 + H * 0.55), (RI + 0.0035, Y0 + H), (RO - 0.004, Y0 + H), (RO - 0.0008, Y0 + H * 0.55), (RO, Y0 - 0.002)]
    SEG = 72; verts = []; faces = []
    for si in range(SEG):
        a = math.tau * si / SEG
        for (r, y) in prof: verts.append((BX + r * math.cos(a), y, BZ + r * math.sin(a)))
    n = len(prof)
    for si in range(SEG):
        s2 = (si + 1) % SEG
        for pi in range(n - 1): faces.append((si * n + pi, s2 * n + pi, s2 * n + pi + 1, si * n + pi + 1))
    bez = bpy.data.meshes.new("BadgeBezel"); bez.from_pydata(verts, [], faces); bez.update()
    # face disc (slightly below the bezel crown), UV = planar through the logo, viewer on +Y sees -X to the right
    fv = [(BX, Y0 + H * 0.35, BZ)] + [(BX + RI * math.cos(math.tau * i / SEG), Y0 + H * 0.35, BZ + RI * math.sin(math.tau * i / SEG)) for i in range(SEG)]
    ff = [(0, 1 + i, 1 + (i + 1) % SEG) for i in range(SEG)]
    fc = bpy.data.meshes.new("BadgeFace"); fc.from_pydata(fv, [], ff); fc.update()
    uvf = fc.uv_layers.new(name="UVMap")
    for pl_ in fc.polygons:
        for li_ in pl_.loop_indices:
            co = fc.vertices[fc.loops[li_].vertex_index].co
            uvf.data[li_].uv = (0.5 - (co.x - BX) / (2 * RI), 0.5 + (co.z - BZ) / (2 * RI))
    for me_ in (bez, fc):
        for pl_ in me_.polygons:
            if pl_.normal.y < 0: pl_.flip()
        me_.update()
    gm_ = bpy.data.materials.new("Badge_Gold"); gm_.use_nodes = True; gb = gm_.node_tree.nodes["Principled BSDF"]
    gb.inputs['Base Color'].default_value = (0.62, 0.40, 0.08, 1); gb.inputs['Metallic'].default_value = 0.6; gb.inputs['Roughness'].default_value = 0.42
    fm_ = bpy.data.materials.new("Badge_Face"); fm_.use_nodes = True; t = fm_.node_tree; fb = t.nodes["Principled BSDF"]
    tcf = tex(os.path.join(tex_dir, "emblem_color.jpg"), 'sRGB'); t.links.new(tcf.outputs['Color'], fb.inputs['Base Color'])
    tef = tex(os.path.join(tex_dir, "emblem_emit.png"), 'sRGB'); t.links.new(tef.outputs['Color'], fb.inputs['Emission Color']); fb.inputs['Emission Strength'].default_value = 1.2
    fb.inputs['Metallic'].default_value = 0.45; fb.inputs['Roughness'].default_value = 0.34
    bez.materials.append(gm_); fc.materials.append(fm_)
    badge_b = bpy.data.objects.new("BadgeBezel", bez); badge_f = bpy.data.objects.new("BadgeFace", fc)
    S.collection.objects.link(badge_b); S.collection.objects.link(badge_f)
    for _o in (badge_b, badge_f):
        for _m in _o.data.materials: _m.use_backface_culling = False
    BADGE_OBJS = [badge_b, badge_f]
    for _o in BADGE_OBJS: bpy.data.objects[_o.name].select_set(False)
    log("game: badge built r", RO, "at", round(BX, 3), round(BZ, 3), "y", round(Y0, 4))
else:
    BADGE_OBJS = []
# 4b. SOLID from every side (founder 2026-10-05 "make the rifle solid"): the Tripo body is a set of single-sided shells; with
#     back-face culling the shouldered camera looked INTO open shells (dark boxes, a thin barrel sheet). Double-sided = glTF doubleSided.
for _m in rifle.data.materials: _m.use_backface_culling = False
if dec is not None:
    for _m in dec.data.materials: _m.use_backface_culling = False
# 5. frame: muzzle +X,up +Z  ->  Godot muzzle +Z, up +Y;  length 1.2 m, centred
parts = [rifle] + BADGE_OBJS
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
# Blender 4.2 writes alphaMode BLEND for any material with a linked alpha even when blend_method is CLIP. A blended decal sorts
# against the body and shows the receiver's inside; patch the JSON chunk to MASK (alpha scissor, opaque pass).
import json as _json, struct as _struct
_raw = open(GAME_OUT, "rb").read()
_jl = _struct.unpack("<I", _raw[12:16])[0]
_j = _json.loads(_raw[20:20 + _jl])
for _m in _j.get("materials", []):
    if _m.get("name") == "GM_Logo":
        _m["alphaMode"] = "MASK"; _m["alphaCutoff"] = 0.5
_jb = _json.dumps(_j, separators=(",", ":")).encode()
_jb += b" " * ((4 - len(_jb) % 4) % 4)
_rest = _raw[20 + _jl:]
open(GAME_OUT, "wb").write(_raw[:8] + _struct.pack("<I", 12 + 8 + len(_jb) + len(_rest)) + _struct.pack("<I", len(_jb)) + b"JSON" + _jb + _rest)
log("game: wrote", GAME_OUT, os.path.getsize(GAME_OUT) // 1024, "KB"); log("render done (game export)")
