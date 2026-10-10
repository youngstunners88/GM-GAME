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
    subprocess.run([sys.executable, "-I", os.path.join(os.path.dirname(os.path.abspath(__file__)), "make_gm_emblem.py"), arg("--logo"), work] + ([] if "--bold" in argv else ["--classic", "--disc"]), check=True)
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
    # relief toward the plate plane - ON THE SIDE PLATE ONLY. Founder 2026-10-10 (skill ep2-winchester-logo): "the top of the gun has random holes".
    # The old flatten + delete cylinder (r 0.134 / 0.10) reached past the plate's top edge (only ~0.075 above the emblem centre) and pulled the
    # top strap's side faces out / deleted them: the receiver top opened into a jagged channel. Now every edit is clipped to the measured plate.
    _ring = sorted(v.co.y for v in rifle.data.vertices if 0.105 < math.hypot(v.co.x - PX, v.co.z - PZ) < 0.14 and 0.09 < v.co.y < 0.125)
    _y0 = _ring[len(_ring) // 2] if _ring else PLATE_Y[1.0] - 0.015; _r0, _r1 = 0.108, 0.134; _n = 0
    PLATE_Y[1.0] = _y0
    def _walk(dx, dz, start):   # distance from the emblem centre to the plate edge along (dx, dz), measured on the RAW mesh. The plate = flat side-facing
        for j_ in range(40):                                           # surface (normal.y > 0.8) within (-4 mm, +2.5 cm) of the plate plane. The walk STARTS
            if _ok(PX + dx * start, PZ + dz * start): break             # beyond Tripo's emblem relief (its facets have scrambled normals; step on until the
            start += 0.0015                                             # plate shows) and stops at the first 3 mm that fall off the plate: the frame bevel /
        else: return start                                              # the receiver's curved edge.
        last = start; miss = 0
        for k_ in range(1, 120):
            d_ = start + k_ * 0.0015
            if _ok(PX + dx * d_, PZ + dz * d_): last = d_; miss = 0
            else:
                miss += 1
                if miss >= 2: break
        return last
    def _ok(x, z):
        h_ = _bvh.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
        return h_[0] is not None and h_[1].y > 0.8 and -0.004 < h_[0].y - _y0 < 0.025
    # relief extent on this rifle (measured 2026-10-10 on the raw mesh): +-0.045 vertically, +-0.08 along the barrel (pre-scale units)
    PLATE_BOX = (PX - _walk(-1, 0, 0.085), PX + _walk(1, 0, 0.085), PZ - _walk(0, -1, 0.05), PZ + _walk(0, 1, 0.05))     # x0, x1, z0, z1
    log("game: side plate box", [round(c, 4) for c in PLATE_BOX], "from emblem centre", (PX, PZ))
    def _edge_d(x, z):          # >0 inside the plate box: distance to its nearest edge
        return min(x - PLATE_BOX[0], PLATE_BOX[1] - x, z - PLATE_BOX[2], PLATE_BOX[3] - z)
    log("game: custom normals", rifle.data.has_custom_normals)
    _flat_k = {}; _proud_v = set()
    for v in rifle.data.vertices:
        r_ = math.hypot(v.co.x - PX, v.co.z - PZ)
        if r_ < _r1 and _y0 - 0.03 < v.co.y < 0.14:
            e_ = _edge_d(v.co.x, v.co.z)
            k_ = 1.0 if r_ < _r0 else 1.0 - (r_ - _r0) / (_r1 - _r0); k_ = k_ * k_ * (3 - 2 * k_)
            if v.co.y - _y0 > float(arg("--proud", 0.0015)):          # 1.5 mm: the oval's lower arc stood 2.4 mm proud at the plate's bottom rim
                _proud_v.add(v.index)                          # relief: full compression even at the plate rim (the edge ramp left a 1 cm arc standing)
            elif e_ > 0.002 and v.co.y >= _y0:
                pass        # anything standing above the plate inside it is relief residue: full strength (the rim ramp left a sky-lit crescent)
            elif e_ > 0.002:
                ke = min(1.0, (e_ - 0.002) / 0.008); k_ *= ke * ke * (3 - 2 * ke)   # below the plate: the receiver's curve - ease out toward the rim
            elif False:
                pass        # Tripo's oval ring OVERHANGS the plate onto the frame at the top and the ends: anything standing > 4 mm proud of the plate
                            # inside the emblem radius is relief, wherever it sits. The top strap curves AWAY below the plate plane, so it never qualifies.
            else: continue  # the plate's rim, the frame and everything beyond it (top strap, lever frame) stay as modelled
            v.co.y = _y0 + (v.co.y - _y0) * (1.0 - 0.97 * k_); _n += 1     # COMPRESS 33x (keeps shell order: 1.9 cm relief -> 0.6 mm), do not collapse
            _flat_k[v.index] = k_
            if r_ < float(arg("--sr", 0.05)) - 0.001: v.co.y = min(v.co.y, _y0 - 0.0006)        # under the GM disc: always below it, never poking through
    # Tripo ships CUSTOM split normals: a flattened relief keeps its old facet normals and still LIGHTS like the oval ring + shards (founder saw the
    # ghost of the old emblem). The flattened loops get the plate's normal (sign follows the face, so double-sided undersides light the same way).
    if rifle.data.has_custom_normals and _flat_k:
        _me = rifle.data; _cn = [Vector(c.vector) for c in _me.corner_normals]
        # the TARGET normal is the plate's own (its custom normals, ~1.7 deg off +Y) - not +Y: a pure +Y patch lit as a pale crescent with a dark
        # rim line where it met the untouched plate. Relief that sat on the frame takes the frame's own average normal.
        _pn = Vector(); _fn = Vector()
        for _pl in _me.polygons:
            if any(_vi in _flat_k for _vi in _pl.vertices) or _pl.normal.y < 0.3: continue
            _c = _pl.center; _r = math.hypot(_c.x - PX, _c.z - PZ); _e = _edge_d(_c.x, _c.z)
            if 0.11 < _r < 0.2 and _e > 0.004 and abs(_c.y - _y0) < 0.01:
                for _li in _pl.loop_indices: _pn += _cn[_li]
            elif 0.07 < _r < 0.2 and _e < -0.002 and abs(_c.y - _y0) < 0.02:
                for _li in _pl.loop_indices: _fn += _cn[_li]
        _pn = _pn.normalized() if _pn.length > 0 else Vector((0, 1, 0)); _fn = _fn.normalized() if _fn.length > 0 else _pn
        log("game: plate normal", [round(c, 3) for c in _pn], "frame normal", [round(c, 3) for c in _fn])
        for _pl in _me.polygons:
            _sg = 1.0 if _pl.normal.y >= 0 else -1.0
            for _li in _pl.loop_indices:
                _vi = _me.loops[_li].vertex_index; _kk = _flat_k.get(_vi, 0.0)
                if _kk > 0.0:
                    _co = _me.vertices[_vi].co; _tn = _pn if _edge_d(_co.x, _co.z) > 0.0 else _fn
                    _cn[_li] = (_cn[_li] * (1.0 - _kk) + _tn * (_sg * _kk)).normalized()
        _me.normals_split_custom_set([tuple(c) for c in _cn])
        log("game: plate normals reset on", len(_flat_k), "verts")
    rifle.data.update(); log("game: flattened", _n, "relief verts to y", round(_y0, 4))
    # THE PLATE'S OWN COLOUR (founder 2026-10-09: "a nasty brown outer layer kills it"): the old seat was the Tripo smudge darkened to 0.42,
    # which read as a wide olive-brown ring around the gold. Fill the whole emblem footprint with the average colour of the real plate just outside it.
    _cols = []
    for pl in rifle.data.polygons:
        if pl.material_index != 0 or pl.normal.y < 0.35: continue
        _c = pl.center
        _r = math.hypot(_c.x - PX, _c.z - PZ)
        if 0.125 < _r < 0.2 and abs(_c.y - PLATE_Y[1.0]) < 0.03 and _edge_d(_c.x, _c.z) > 0.004:
            _u = sum((uvl[i].uv for i in pl.loop_indices), Vector((0, 0))) / len(pl.loop_indices)
            _cols.append(base[min(N_ - 1, max(0, int((1 - _u.y) * N_))), min(N_ - 1, max(0, int(_u.x * N_)))])
    PLATE_AVG = np.median(np.array(_cols), axis=0) if len(_cols) > 8 else np.array([0.20, 0.19, 0.18], np.float32)   # x0.55: the engraved plate is darker than the lever-frame texels around it
    log("game: plate colour", [round(float(c), 3) for c in PLATE_AVG], "from", len(_cols), "faces")
    # the FRAME's own colour, for relief faces that overhung onto it (painting them plate-dark left a smear on the top rail)
    _fcols = []
    for pl in rifle.data.polygons:
        if pl.material_index != 0 or pl.normal.y < 0.3 or any(_vi in _proud_v for _vi in pl.vertices): continue
        _c = pl.center; _r = math.hypot(_c.x - PX, _c.z - PZ)
        if 0.07 < _r < 0.2 and _edge_d(_c.x, _c.z) < -0.002 and abs(_c.y - _y0) < 0.02:
            _u = sum((uvl[i].uv for i in pl.loop_indices), Vector((0, 0))) / len(pl.loop_indices)
            _fcols.append(base[min(N_ - 1, max(0, int((1 - _u.y) * N_))), min(N_ - 1, max(0, int(_u.x * N_)))])
    FRAME_AVG = np.median(np.array(_fcols), axis=0) if len(_fcols) > 8 else PLATE_AVG
    log("game: frame colour", [round(float(c), 3) for c in FRAME_AVG], "from", len(_fcols), "faces")
    _rng_ = np.random.RandomState(7)
    _mask = np.zeros(base.shape[:2], np.float32)          # where the old emblem was painted out: the SAME texels get plate roughness/metal (below)
    _col_px = []
    for pl in rifle.data.polygons:
        if pl.material_index != 0 or pl.normal.y < 0.35: continue
        _c = pl.center; _r = math.hypot(_c.x - PX, _c.z - PZ)
        if 0.125 < _r < 0.2 and abs(_c.y - PLATE_Y[1.0]) < 0.03 and _edge_d(_c.x, _c.z) > 0.004:
            _u = sum((uvl[i].uv for i in pl.loop_indices), Vector((0, 0))) / len(pl.loop_indices)
            _col_px.append((min(N_ - 1, max(0, int((1 - _u.y) * N_))), min(N_ - 1, max(0, int(_u.x * N_)))))
    done = 0
    for pl in rifle.data.polygons:
        if pl.material_index != 0: continue
        _pc = pl.center
        _relief = any(_vi in _proud_v for _vi in pl.vertices)
        _onplate = (abs(_pc.y - _y0) < 0.03 and _edge_d(_pc.x, _pc.z) > 0.0) or _relief
        if not _onplate and abs(pl.normal.y) < 0.08: continue
        side = 1.0 if (_onplate or pl.normal.y > 0) else -1.0
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
            ed = np.minimum(np.minimum(X3 - PLATE_BOX[0], PLATE_BOX[1] - X3), np.minimum(Z3 - PLATE_BOX[2], PLATE_BOX[3] - Z3))
            m = ins & (rr < 1.0) & ((ed > 0.0) | _relief)
            if not m.any(): continue
            ec = np.concatenate([np.zeros(rr.shape + (3,), np.float32), np.ones(rr.shape + (1,), np.float32)], -1); ee = np.zeros(rr.shape + (3,), np.float32)
            feather = np.clip((1.0 - rr) / 0.25, 0, 1) * (1.0 if _relief else np.clip(ed / 0.006, 0, 1))   # wide soft edge into the plate, off at the plate rim (old relief: full)
            alpha = (ec[..., 3] * feather)[..., None]
            py_, px_ = (gy - 0.5).astype(int), (gx - 0.5).astype(int)
            orig = base[py_, px_]; lum = orig.mean(-1, keepdims=True)
            wear = np.clip(0.90 + 0.30 * lum, 0.90, 1.10)                    # the plate's own scratches/grime show through the emblem
            _base_c = FRAME_AVG if (_relief and _edge_d(_pc.x, _pc.z) <= 0.0) else PLATE_AVG
            newc = np.clip(_base_c[None, None, :] * (0.88 + 0.24 * _rng_.rand(*rr.shape))[..., None] * wear, 0, 1)   # the old emblem is gone: plain plate colour + grain
            sel = m[..., None]
            base[py_, px_] = np.where(sel, orig * (1 - alpha) + newc * alpha, orig)
            _mask[py_, px_] = np.maximum(_mask[py_, px_], np.where(m, alpha[..., 0], 0.0))
            emit_img[py_, px_] = np.where(sel, ee * alpha * feather[..., None], emit_img[py_, px_])
        done += 1
    log("game: painted emblem into", done, "receiver faces")
    _I.fromarray((base * 255).astype(np.uint8)).save(pc)
    # GHOST FIX (founder still saw the old oval as a shine): the roughness / metallic bakes still carried the old gold ring, so it REFLECTED
    # differently from the plate. Same mask, the plate's own median roughness and metal.
    if _col_px:
        _ys = np.array([q[0] for q in _col_px]); _xs = np.array([q[1] for q in _col_px])
        for _path in (pr, pm):
            _arr = np.asarray(_I.open(_path).convert("RGB")).astype(np.float32) / 255.0
            _med = np.median(_arr[_ys, _xs], axis=0)
            _arr = _arr * (1 - _mask[..., None]) + _med[None, None, :] * _mask[..., None]
            _I.fromarray((np.clip(_arr, 0, 1) * 255).astype(np.uint8)).save(_path)
        log("game: rough/metal repainted under the old emblem, plate medians from", len(_col_px), "faces")
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

# 3b. THE GM DISC, NOTHING AROUND IT (founder 2026-10-10, skill ep2-winchester-logo: "I told you to remove this brown outer circle! NOT EXPAND IT").
#     History: v1 painted Tripo's smudge darker (a brown ring), v2 rebuilt a polar patch steel ring -> gold rim -> socket out to r 0.112 - wider than the
#     side plate itself (its top edge is ~0.075 above the centre) - so a dark scalloped disc stood out above and below the receiver and its delete
#     cylinder holed the top strap. Now: ONE dark disc (logo + its own dark edge, no bezel, no ring), radius clipped INSIDE the measured plate, 0.9 mm proud
#     of the flattened plate (flush to the eye, no z-fight). Only Tripo faces lying ENTIRELY under the disc are deleted, so the hole is always covered:
#     nothing beyond the disc is cut, the plate around it is the plate's own surface and colour.
BADGE_OBJS = []
if arg("--logo") and 'BADGE' in globals():
    import bmesh
    from mathutils.bvhtree import BVHTree as _BVH2
    from PIL import Image as _I2
    _I2.open(os.path.join(work, "emblem_color.png")).convert("RGB").save(os.path.join(tex_dir, "emblem_color.jpg"), quality=86)
    _I2.open(os.path.join(work, "emblem_emit.png")).convert("RGB").resize((256, 256), _I2.LANCZOS).save(os.path.join(tex_dir, "emblem_emit.png"), optimize=True)
    BX, BZ, YP = BADGE['PX'], BADGE['PZ'], BADGE['Y0']
    EDGE = _edge_d(BX, BZ)                                    # room from the emblem centre to the nearest plate edge
    RD = min(float(arg("--sr", 0.05)), EDGE - 0.010)          # disc radius: never closer than 1 cm to the plate edge
    LIFT = 0.0009; SEG = 120
    log("game: disc radius", round(RD, 4), "plate edge distance", round(EDGE, 4))
    bvh2 = _BVH2.FromObject(rifle, bpy.context.evaluated_depsgraph_get())
    def top_y(x, z):
        h = bvh2.ray_cast(Vector((x, 1.0, z)), Vector((0, -1, 0)))
        return h[0].y if h[0] else None
    # the plate is not level (it follows the receiver): fit y = a + b*x + c*z to the flattened plate just outside the disc, inside the plate box
    _pts = []
    for _r in (RD + 0.004, RD + 0.008, RD + 0.012):
        for _k in range(48):
            _a = math.tau * _k / 48; _x = BX - _r * math.cos(_a); _z = BZ + _r * math.sin(_a)
            if _edge_d(_x, _z) < 0.003: continue
            _y = top_y(_x, _z)
            if _y is not None and abs(_y - YP) < 0.01: _pts.append((_x, _z, _y))
    if len(_pts) > 20:
        _A = np.array([[1.0, p_[0], p_[1]] for p_ in _pts]); _b = np.array([p_[2] for p_ in _pts]); _co = np.linalg.lstsq(_A, _b, rcond=None)[0]
        PLANE = lambda x, z: _co[0] + _co[1] * x + _co[2] * z
    else: PLANE = lambda x, z: YP
    log("game: plate plane from", len(_pts), "samples")
    def prof(r):              # flat face, then a 1.5 mm roll down into the plate (no lip, no bezel)
        if r < RD - 0.0015: return LIFT
        t = min(1.0, (r - (RD - 0.0015)) / 0.0015); t = t * t * (3 - 2 * t); return LIFT * (1 - t) - 0.0003 * t
    radii = [0.0] + [RD * k / 10.0 for k in range(1, 10)] + [RD - 0.0015, RD - 0.0007, RD]
    bm = bmesh.new(); bm.from_mesh(rifle.data)
    def _under(f):            # every corner under the disc, on the plate's depth band
        return all(math.hypot(v.co.x - BX, v.co.z - BZ) < RD - 0.0008 and YP - 0.03 < v.co.y < YP + 0.05 for v in f.verts)
    kill = [f for f in bm.faces if _under(f)]
    bmesh.ops.delete(bm, geom=kill, context='FACES_ONLY')
    face_i = len(rifle.data.materials)
    fm_ = bpy.data.materials.new("Badge_Face"); fm_.use_nodes = True; t = fm_.node_tree; fb = t.nodes["Principled BSDF"]
    tcf = tex(os.path.join(tex_dir, "emblem_color.jpg"), 'sRGB'); t.links.new(tcf.outputs['Color'], fb.inputs['Base Color'])
    tef = tex(os.path.join(tex_dir, "emblem_emit.png"), 'sRGB'); t.links.new(tef.outputs['Color'], fb.inputs['Emission Color']); fb.inputs['Emission Strength'].default_value = 1.1
    fb.inputs['Metallic'].default_value = 0.4; fb.inputs['Roughness'].default_value = 0.34
    fm_.use_backface_culling = False
    rifle.data.materials.append(fm_)
    uvl_ = bm.loops.layers.uv.verify()
    vgrid = {}
    def getv(ri, si):
        key = (ri, si % SEG)
        if key not in vgrid:
            r = radii[ri]; a = math.tau * (si % SEG) / SEG; x = BX - r * math.cos(a); z = BZ + r * math.sin(a)
            vgrid[key] = bm.verts.new((x, PLANE(x, z) + prof(r), z))
        return vgrid[key]
    for ri in range(len(radii) - 1):
        for si in range(SEG):
            vs = [getv(0, 0), getv(1, si), getv(1, si + 1)] if ri == 0 else [getv(ri, si), getv(ri + 1, si), getv(ri + 1, si + 1), getv(ri, si + 1)]
            if len(set(map(id, vs))) < 3: continue
            try: f = bm.faces.new(vs)
            except ValueError: continue
            if f.normal.y < 0: f.normal_flip()
            f.material_index = face_i
            for lp in f.loops:
                co = lp.vert.co
                lp[uvl_].uv = (0.5 - (co.x - BX) / (2 * RD), 0.5 + (co.z - BZ) / (2 * RD))
    bm.normal_update(); bm.to_mesh(rifle.data); bm.free(); rifle.data.update()
    log("game: GM disc built - removed", len(kill), "Tripo faces under it; total polys", len(rifle.data.polygons))
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
