# post-hook for rifle_hero.py (exec'd inside it, shares its globals: bpy, S, rifle, arg, log, np, math, Matrix, Vector).
# Turns the node-graph "hero" materials into plain textures a GLB can carry and exports a game-ready rifle.
#   blender -b --python tools/ep2_blender/rifle_hero.py -- --glb <tripo.glb> --align --flipx --pre tools/ep2_blender/rifle_surgery.py \
#       --logo <GOLD_LOGO.png> --tex 1024 --post tools/ep2_blender/rifle_export_game.py --game-out src/episode2/assets/weapons/winchester_1886_founder.glb
# Output frame: muzzle +Z, up +Y, ~1.2 m long, centred (skill ep2-founder-weapon-glb). Never touches the GUI session.
import os, sys, tempfile
GAME_OUT = arg("--game-out"); BAKE = int(arg("--bake", 1024)); TRIS = int(arg("--tris", 12000))
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
    PX, PZ, DD = float(arg("--lx", -0.09)), float(arg("--lz", 0.443)), float(arg("--ld", 0.30))
    N_ = base.shape[0]; uvl = rifle.data.uv_layers.active.data
    from mathutils.bvhtree import BVHTree as _BVH
    _bvh = _BVH.FromObject(rifle, bpy.context.evaluated_depsgraph_get())
    PLATE_Y = {}
    for _sd in (1.0, -1.0):       # y of the receiver side plate on each side; only texels ON that plate get painted (not the lever loop behind it)
        _h = _bvh.ray_cast(Vector((PX, _sd, PZ)), Vector((0, -_sd, 0))); PLATE_Y[_sd] = _h[0].y if _h[0] else 0.26 * _sd
    log("game: plate y", PLATE_Y)
    # Tripo's emblem relief is a faceted, rippled surface (y 0.10..0.13); a texture painted on ripples reads as shattered glass. Flatten the
    # relief into a plain plate at the ray-hit plane (blend out over a ring) so the emblem is a flat inlay and reads cleanly.
    # level of the SURROUNDING plate (the Tripo boss stands ~1.7 cm proud of it; flattening the boss at its own top made the badge look like a fat coin)
    _ring = sorted(v.co.y for v in rifle.data.vertices if 0.105 < math.hypot(v.co.x - PX, v.co.z - PZ) < 0.14 and 0.09 < v.co.y < 0.125)
    _y0 = _ring[len(_ring) // 2] if _ring else PLATE_Y[1.0] - 0.015; _r0, _r1 = 0.108, 0.134; _n = 0
    PLATE_Y[1.0] = _y0
    for v in rifle.data.vertices:
        r_ = math.hypot(v.co.x - PX, v.co.z - PZ)
        if r_ < _r1 and _y0 - 0.03 < v.co.y < 0.14:
            k_ = 1.0 if r_ < _r0 else 1.0 - (r_ - _r0) / (_r1 - _r0); k_ = k_ * k_ * (3 - 2 * k_)
            _sd_ = r_ < 0.092; _ss = 1.0 if r_ < 0.074 else (max(0.0, 1.0 - (r_ - 0.074) / 0.018) if _sd_ else 0.0); _ss = _ss * _ss * (3 - 2 * _ss)
            _tgt = _y0                                  # ENGRAVED: the seat is sunk into the plate, the bezel stands flush with it
            v.co.y = v.co.y * (1 - k_) + _tgt * k_; _n += 1
    rifle.data.update(); log("game: flattened", _n, "relief verts to y", round(_y0, 4))
    # THE PLATE'S OWN COLOUR (founder 2026-10-09: "a nasty brown outer layer kills it"): the old seat was the Tripo smudge darkened to 0.42,
    # which read as a wide olive-brown ring around the gold. Fill the whole emblem footprint with the average colour of the real plate just outside it.
    _cols = []
    for pl in rifle.data.polygons:
        if pl.material_index != 0 or pl.normal.y < 0.35: continue
        _c = pl.center
        _r = math.hypot(_c.x - PX, _c.z - PZ)
        if 0.125 < _r < 0.18 and abs(_c.y - PLATE_Y[1.0]) < 0.03:
            _u = sum((uvl[i].uv for i in pl.loop_indices), Vector((0, 0))) / len(pl.loop_indices)
            _cols.append(base[min(N_ - 1, max(0, int((1 - _u.y) * N_))), min(N_ - 1, max(0, int(_u.x * N_)))])
    PLATE_AVG = (np.median(np.array(_cols), axis=0) * 0.85) if len(_cols) > 8 else np.array([0.20, 0.19, 0.18], np.float32)   # x0.55: the engraved plate is darker than the lever-frame texels around it
    log("game: plate colour", [round(float(c), 3) for c in PLATE_AVG], "from", len(_cols), "faces")
    _rng_ = np.random.RandomState(7)
    done = 0
    for pl in rifle.data.polygons:
        if pl.material_index != 0 or abs(pl.normal.y) < 0.08: continue
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
            ins = ins & (np.abs(Y3 - PLATE_Y[side]) < 0.07)
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
            newc = np.clip(PLATE_AVG[None, None, :] * (0.88 + 0.24 * _rng_.rand(*rr.shape))[..., None] * wear, 0, 1)   # the old emblem is gone: plain plate colour + grain
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

# 3b. CLEAN REBUILD OF THE EMBLEM PLATE (founder 2026-10-09: "one with the rifle - badge or engraving"). Tripo's emblem is several overlapping relief shells,
#     so displacing its vertices makes shards. Instead: sample the visible top surface by ray-casting, DELETE every Tripo face in the emblem cylinder, and
#     build ONE clean polar-grid patch in the same mesh: steel inset ring -> gold rim -> engraved socket floor carrying the GM logo. Same object, same surface.
BADGE_OBJS = []
if arg("--logo") and 'BADGE' in globals():
    import bmesh
    from mathutils.bvhtree import BVHTree as _BVH2
    from PIL import Image as _I2
    _I2.open(os.path.join(work, "emblem_color.png")).convert("RGB").save(os.path.join(tex_dir, "emblem_color.jpg"), quality=86)
    _I2.open(os.path.join(work, "emblem_emit.png")).convert("RGB").resize((256, 256), _I2.LANCZOS).save(os.path.join(tex_dir, "emblem_emit.png"), optimize=True)
    BX, BZ, YP = BADGE['PX'], BADGE['PZ'], BADGE['Y0']
    RI = float(arg("--sr", 0.05)); RO = RI + 0.010; RH = float(arg("--rh", 0.1)); RP = RH + 0.012; DEPTH = 0.0065; SEG = 120
    bvh2 = _BVH2.FromObject(rifle, bpy.context.evaluated_depsgraph_get())
    def top_y(x, z):
        h = bvh2.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
        return h[0].y if h[0] else None
    def prof(r):          # height above the plate plane
        if r < RI - 0.002: return -DEPTH                                                                                   # socket floor
        if r < RI + 0.003: t = (r - (RI - 0.002)) / 0.005; t = t * t * (3 - 2 * t); return -DEPTH + (DEPTH + 0.0016) * t   # inner wall up to the rim
        if r < RO - 0.002: return 0.0016                                                                                   # gold rim crown
        if r < RO + 0.003: t = (r - (RO - 0.002)) / 0.005; t = t * t * (3 - 2 * t); return 0.0016 * (1 - t)               # rim rolls back to the plate
        return 0.0
    # the plate is not level (it follows the receiver): fit a plane y = a + b*x + c*z to the visible surface in a ring OUTSIDE the old emblem boss
    _pts = []
    for _r in (0.125, 0.14, 0.155):
        for _k in range(36):
            _a = math.tau * _k / 36; _x = BX - _r * math.cos(_a); _z = BZ + _r * math.sin(_a); _y = top_y(_x, _z)
            if _y is not None and abs(_y - YP) < 0.03: _pts.append((_x, _z, _y))
    if len(_pts) > 20:
        _A = np.array([[1.0, p_[0], p_[1]] for p_ in _pts]); _b = np.array([p_[2] for p_ in _pts]); _co = np.linalg.lstsq(_A, _b, rcond=None)[0]
        PLANE = lambda x, z: _co[0] + _co[1] * x + _co[2] * z
    else: PLANE = lambda x, z: YP
    log("game: plate plane coef", [round(float(c), 4) for c in (_co if len(_pts) > 20 else [YP, 0, 0])], "from", len(_pts), "samples")
    radii = [0.0] + [RI * k / 8.0 for k in range(1, 9)]
    r_ = RI
    while r_ < RO + 0.012: r_ += 0.0032; radii.append(r_)
    while r_ < RP: r_ += 0.007; radii.append(min(r_, RP))
    # sampled outer heights (None = off the plate)
    ys = {}
    for ri, r in enumerate(radii):
        for si in range(SEG):
            a = math.tau * si / SEG; x = BX - r * math.cos(a); z = BZ + r * math.sin(a)
            if r < RO + 0.012: ys[(ri, si)] = PLANE(x, z) + prof(r)
            else:
                t_ = top_y(x, z)
                if t_ is None or abs(t_ - PLANE(x, z)) > 0.02: t_ = PLANE(x, z)      # never leave a hole (holes made the staircase edge)
                if True:
                    k = min(1.0, (r - (RO + 0.012)) / max(1e-6, (RP - (RO + 0.012))) * 1.6); k = k * k * (3 - 2 * k)
                    ys[(ri, si)] = (PLANE(x, z) + prof(r)) * (1 - k) + (t_ - 0.0008) * k
    bm = bmesh.new(); bm.from_mesh(rifle.data)
    kill = [f for f in bm.faces if math.hypot(f.calc_center_median().x - BX, f.calc_center_median().z - BZ) < RH
            and YP - 0.03 < f.calc_center_median().y < YP + 0.05]
    bmesh.ops.delete(bm, geom=kill, context='FACES_ONLY')
    gold_i = len(rifle.data.materials); face_i = gold_i + 1; steel_i = gold_i + 2
    gm_ = bpy.data.materials.new("Badge_Gold"); gm_.use_nodes = True; gb = gm_.node_tree.nodes["Principled BSDF"]
    gb.inputs['Base Color'].default_value = (0.74, 0.50, 0.11, 1); gb.inputs['Metallic'].default_value = 0.65; gb.inputs['Roughness'].default_value = 0.34
    fm_ = bpy.data.materials.new("Badge_Face"); fm_.use_nodes = True; t = fm_.node_tree; fb = t.nodes["Principled BSDF"]
    tcf = tex(os.path.join(tex_dir, "emblem_color.jpg"), 'sRGB'); t.links.new(tcf.outputs['Color'], fb.inputs['Base Color'])
    tef = tex(os.path.join(tex_dir, "emblem_emit.png"), 'sRGB'); t.links.new(tef.outputs['Color'], fb.inputs['Emission Color']); fb.inputs['Emission Strength'].default_value = 1.1
    fb.inputs['Metallic'].default_value = 0.4; fb.inputs['Roughness'].default_value = 0.34
    sm_ = bpy.data.materials.new("Badge_Steel"); sm_.use_nodes = True; sb = sm_.node_tree.nodes["Principled BSDF"]
    _lin = [float(max(c, 0.0)) ** 2.2 for c in PLATE_AVG]; sb.inputs['Base Color'].default_value = (_lin[0], _lin[1], _lin[2], 1); sb.inputs["Metallic"].default_value = 0.4; sb.inputs["Roughness"].default_value = 0.55
    for _m in (gm_, fm_, sm_): _m.use_backface_culling = False
    for _m in (gm_, fm_, sm_): rifle.data.materials.append(_m)
    uvl_ = bm.loops.layers.uv.verify()
    vgrid = {}
    def getv(ri, si):
        key = (ri, si % SEG)
        if key in vgrid: return vgrid[key]
        y = ys[key]
        if y is None: vgrid[key] = None; return None
        r = radii[ri]; a = math.tau * (si % SEG) / SEG
        v = bm.verts.new((BX - r * math.cos(a), y, BZ + r * math.sin(a))); vgrid[key] = v; return v
    nfl = nrm = nst = 0
    def mkface(vs, mat, rmid):
        global nfl, nrm, nst
        try: f = bm.faces.new(vs)
        except ValueError: return
        if f.normal.y < 0: f.normal_flip()
        f.material_index = mat
        for lp in f.loops:
            co = lp.vert.co
            lp[uvl_].uv = (0.5 - (co.x - BX) / (2 * (RI - 0.002)), 0.5 + (co.z - BZ) / (2 * (RI - 0.002))) if mat == face_i else (0.0, 0.0)
    for ri in range(len(radii) - 1):
        rmid = (radii[ri] + radii[ri + 1]) / 2
        mat = face_i if rmid < RI - 0.003 else (gold_i if rmid < RO + 0.0035 else steel_i)
        for si in range(SEG):
            if ri == 0:
                vs = [getv(0, 0), getv(1, si), getv(1, si + 1)]
            else:
                vs = [getv(ri, si), getv(ri + 1, si), getv(ri + 1, si + 1), getv(ri, si + 1)]
            if any(v is None for v in vs): continue
            if ri == 0 and len(set(map(id, vs))) < 3: continue
            mkface(vs, mat, rmid)
    bm.normal_update(); bm.to_mesh(rifle.data); bm.free(); rifle.data.update()
    log("game: plate rebuilt - removed", len(kill), "Tripo faces; total polys", len(rifle.data.polygons))
# 4b. SOLID from every side (founder 2026-10-05 "make the rifle solid"): the Tripo body is a set of single-sided shells; with
#     back-face culling the shouldered camera looked INTO open shells (dark boxes, a thin barrel sheet). Double-sided = glTF doubleSided.
for _m in rifle.data.materials: _m.use_backface_culling = False
if dec is not None:
    for _m in dec.data.materials: _m.use_backface_culling = False
# 4c. SHARD SWEEP (founder 2026-10-09: "fix this little thing on the rifle"). The decimate in step 1 leaves sub-centimetre floaters: a closed
#     4-face tetrahedron 6 mm tall stood above the fore-end at the muzzle like a thorn (found by splitting the FINAL glb into connected components - the
#     pre-decimate surgery rule could never see it, it did not exist yet). Delete every island that is tiny relative to the rifle: <= 2 faces and <= 1.15 %
#     of its length anywhere (~1.2 cm of 1.05 m), or <= 4 faces in the front quarter (the muzzle and fore-end are the most-looked-at part).
import bmesh as _bm4
_bx = _bm4.new(); _bx.from_mesh(rifle.data); _bx.verts.ensure_lookup_table(); _bx.faces.ensure_lookup_table()
_cos = np.array([tuple(v.co) for v in _bx.verts]); _L = float((_cos.max(0) - _cos.min(0)).max()); _x0 = float(_cos[:, 0].min())
_isl_id = {}; _isls = []
for _f0 in _bx.faces:
    if _f0.index in _isl_id: continue
    _stack = [_f0]; _comp = []; _isl_id[_f0.index] = len(_isls)
    while _stack:
        _cur = _stack.pop(); _comp.append(_cur)
        for _v in _cur.verts:
            for _nf in _v.link_faces:
                if _nf.index not in _isl_id: _isl_id[_nf.index] = len(_isls); _stack.append(_nf)
    _isls.append(_comp)
_kill_faces = []; _kill_isl = 0
for _comp in _isls:
    _vs = {v for f in _comp for v in f.verts}
    _co = np.array([tuple(v.co) for v in _vs]); _ext = float((_co.max(0) - _co.min(0)).max()); _tx = (float(_co[:, 0].mean()) - _x0) / _L
    _small = _ext <= 0.0115 * _L
    if _small and (len(_comp) <= 2 or (len(_comp) <= 4 and _tx >= 0.75)):
        _kill_faces += _comp; _kill_isl += 1
if _kill_faces:
    _bm4.ops.delete(_bx, geom=_kill_faces, context='FACES')
    _bm4.ops.delete(_bx, geom=[v for v in _bx.verts if not v.link_faces], context='VERTS')
    _bx.to_mesh(rifle.data); rifle.data.update()
_bx.free()
log("game: shard sweep removed", _kill_isl, "floating islands (", len(_kill_faces), "faces ) of", len(_isls))
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
