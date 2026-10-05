# pre-hook (exec'd inside rifle_hero.py on the ALIGNED mesh: +X muzzle, +Z up, skill ep2-tripo-mesh-surgery).
# Island ids are stable for the founder's GLB (found with rifle_post_islandviz.py / rifle_pre_slice.py).
#  1. delete the duplicate second left hand (glove paddle + knuckles) and floating strap fragments
#  2. delete the broken barrel stub (a hollow slab), stretch the wood fore-end forward, shift its cap pieces
#  3. build a real barrel + magazine tube + band + front sight (second material slot "Barrel_Steel")
#  4. add the GM logo decal on the receiver side plate (skill ep2-weapon-logo-decal)
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
HAND2 = {201, 291, 199, 200, 204}
FLOATERS = {303, 304, 469, 470}
STUB = {137, 152, 161, 162, 163, 164, 165, 166}
CAP_SHIFT = {139, 140, 141, 142, 147, 153, 138, 434}
WOOD = {100, 435}
EXT = 0.17                        # fore-end gets 0.17 m longer: cap moves 0.63 -> 0.80
STRETCH = 1.0 + EXT / (0.63 - 0.50)
_a = math.radians(ROLL); _y0, _z0 = 0.323, 0.278   # barrel axis measured on the PCA frame (before the roll correction) from the fore-end / stub islands
BY, BZ = _y0 * math.cos(_a) - _z0 * math.sin(_a), _y0 * math.sin(_a) + _z0 * math.cos(_a)
MUZZLE_X = 1.035

bm = bmesh.new(); bm.from_mesh(rifle.data); bm.faces.ensure_lookup_table()
seen = [-1] * len(bm.faces); isl = []
for f in bm.faces:
    if seen[f.index] >= 0: continue
    k = len(isl); st = [f]; seen[f.index] = k; faces = []
    while st:
        cur = st.pop(); faces.append(cur)
        for e in cur.edges:
            for nf in e.link_faces:
                if seen[nf.index] < 0: seen[nf.index] = k; st.append(nf)
    isl.append(faces)
log("surgery: islands", len(isl))

# 2a. move/stretch BEFORE deleting (islands share no verts, so each vertex belongs to exactly one island)
for i in WOOD:
    for v in {v for f in isl[i] for v in f.verts}:
        if v.co.x > 0.50: v.co.x = 0.50 + (v.co.x - 0.50) * STRETCH
for i in CAP_SHIFT:
    for v in {v for f in isl[i] for v in f.verts}: v.co.x += EXT
# 1+2b. delete
dele = [f for i in (HAND2 | FLOATERS | STUB) for f in isl[i]]
bmesh.ops.delete(bm, geom=dele, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
log("surgery: deleted", len(dele), "faces")

# 3. new barrel group -> material slot 1
def add_cone(r1, r2, x0, x1, segs, y=BY, z=BZ, rot_z=0.0):
    M = Matrix.Translation(((x0 + x1) / 2, y, z)) @ Matrix.Rotation(math.pi / 2, 4, 'Y') @ Matrix.Rotation(rot_z, 4, 'Z')
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=x1 - x0, matrix=M)
    for f in {f for v in res['verts'] for f in v.link_faces}:
        f.material_index = 1; f.smooth = segs >= 16
def add_box(x0, x1, y0, y1, z0, z1):
    c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    M = Matrix.Translation(c) @ Matrix.Diagonal((x1 - x0, y1 - y0, z1 - z0, 1.0))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    for f in {f for v in res['verts'] for f in v.link_faces}:
        f.material_index = 1; f.smooth = False
R_B = 0.031                                          # barrel across-corners radius (octagon, 8 segs)
OCT = math.radians(22.5)
add_cone(R_B, R_B, 0.60, MUZZLE_X - 0.012, 8, rot_z=OCT)
add_cone(R_B, R_B * 0.9, MUZZLE_X - 0.012, MUZZLE_X, 8, rot_z=OCT)                    # crown chamfer
add_cone(0.0155, 0.0155, 0.60, 0.985, 24, z=BZ - 0.0475)                              # magazine tube
add_cone(0.0185, 0.0185, 0.972, 0.990, 24, z=BZ - 0.0475)                             # tube end cap
add_cone(R_B + 0.0045, R_B + 0.0045, 0.885, 0.903, 8, rot_z=OCT)                      # barrel band
add_cone(0.0215, 0.0215, 0.885, 0.903, 24, z=BZ - 0.0475)                             # band round the tube
add_box(0.955, 0.995, BY - 0.011, BY + 0.011, BZ + 0.025, BZ + 0.036)                 # front-sight dovetail base
add_box(0.968, 0.980, BY - 0.0038, BY + 0.0038, BZ + 0.036, BZ + 0.066)               # front-sight blade
bm.to_mesh(rifle.data); bm.free()
if len(rifle.data.materials) < 2:
    bs = bpy.data.materials.new("Barrel_Steel"); bs.use_nodes = True; t = bs.node_tree; b = t.nodes["Principled BSDF"]
    b.inputs['Base Color'].default_value = (0.16, 0.165, 0.18, 1); b.inputs['Metallic'].default_value = 1.0
    tc = t.nodes.new("ShaderNodeTexCoord"); mp = t.nodes.new("ShaderNodeMapping"); mp.inputs['Scale'].default_value = (4, 300, 300)
    t.links.new(tc.outputs['Object'], mp.inputs['Vector'])
    nz = t.nodes.new("ShaderNodeTexNoise"); nz.inputs['Scale'].default_value = 1.0; nz.inputs['Detail'].default_value = 8
    t.links.new(mp.outputs['Vector'], nz.inputs['Vector'])
    rr = t.nodes.new("ShaderNodeMapRange"); rr.inputs['To Min'].default_value = 0.22; rr.inputs['To Max'].default_value = 0.5
    t.links.new(nz.outputs['Fac'], rr.inputs['Value']); t.links.new(rr.outputs['Result'], b.inputs['Roughness'])
    bp = t.nodes.new("ShaderNodeBump"); bp.inputs['Strength'].default_value = 0.12; bp.inputs['Distance'].default_value = 0.0006
    t.links.new(nz.outputs['Fac'], bp.inputs['Height']); t.links.new(bp.outputs['Normal'], b.inputs['Normal'])
    rifle.data.materials.append(bs)
rifle.data.update()

# 4. GM logo decal on the receiver side plate (camera side = -Y)
LOGO = arg("--logo")
if LOGO:
    bvh = BVHTree.FromObject(rifle, bpy.context.evaluated_depsgraph_get())
    PX, PZ, D = float(arg("--lx", -0.075)), float(arg("--lz", 0.45)), float(arg("--ld", 0.12))
    hit = bvh.ray_cast(Vector((PX, -1.0, PZ)), Vector((0, 1, 0)))
    py = hit[0].y if hit[0] else 0.262
    log("decal: plate surface y at", PX, PZ, "=", round(py, 4))
    me = bpy.data.meshes.new("LogoDecal"); h = D / 2; yy = py - 0.0012
    me.from_pydata([(PX - h, yy, PZ - h), (PX + h, yy, PZ - h), (PX + h, yy, PZ + h), (PX - h, yy, PZ + h)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name="UVMap"); u0, u1, v0, v1 = 0.14, 0.86, 0.186, 0.926   # crop of Gold Logo.png around the emblem
    for li, (u, v) in zip(me.polygons[0].loop_indices, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))): uv.data[li].uv = (u, v)
    me.update(); dec = bpy.data.objects.new("LogoDecal", me); S.collection.objects.link(dec)
    dm = bpy.data.materials.new("LogoDecal"); dm.use_nodes = True; t = dm.node_tree
    for n in list(t.nodes): t.nodes.remove(n)
    out = t.nodes.new("ShaderNodeOutputMaterial"); b = t.nodes.new("ShaderNodeBsdfPrincipled")
    im = t.nodes.new("ShaderNodeTexImage"); im.image = bpy.data.images.load(LOGO); im.image.colorspace_settings.name = 'sRGB'
    uvn = t.nodes.new("ShaderNodeUVMap"); uvn.uv_map = "UVMap"; t.links.new(uvn.outputs['UV'], im.inputs['Vector'])
    sep = t.nodes.new("ShaderNodeSeparateXYZ"); t.links.new(uvn.outputs['UV'], sep.inputs['Vector'])
    def m(op, a, b_=None):
        n = t.nodes.new("ShaderNodeMath"); n.operation = op
        if isinstance(a, float): n.inputs[0].default_value = a
        else: t.links.new(a, n.inputs[0])
        if b_ is not None:
            if isinstance(b_, float): n.inputs[1].default_value = b_
            else: t.links.new(b_, n.inputs[1])
        return n.outputs['Value']
    du = m('SUBTRACT', sep.outputs['X'], 0.5); dv = m('SUBTRACT', sep.outputs['Y'], 0.556)
    r = m('SQRT', m('ADD', m('MULTIPLY', du, du), m('MULTIPLY', dv, dv)))
    radial = t.nodes.new("ShaderNodeMapRange"); radial.inputs['From Min'].default_value = 0.352; radial.inputs['From Max'].default_value = 0.37
    radial.inputs['To Min'].default_value = 1.0; radial.inputs['To Max'].default_value = 0.0; radial.clamp = True
    t.links.new(r, radial.inputs['Value'])
    s2 = t.nodes.new("ShaderNodeSeparateColor"); t.links.new(im.outputs['Color'], s2.inputs['Color'])
    mxv_ = m('MAXIMUM', m('MAXIMUM', s2.outputs['Red'], s2.outputs['Green']), s2.outputs['Blue'])   # value: dark disc becomes transparent
    vm = t.nodes.new("ShaderNodeMapRange"); vm.inputs['From Min'].default_value = 0.16; vm.inputs['From Max'].default_value = 0.30; vm.clamp = True
    t.links.new(mxv_, vm.inputs['Value'])
    alpha = m('MULTIPLY', radial.outputs['Result'], vm.outputs['Result'])
    gl = m('SUBTRACT', s2.outputs['Green'], m('MULTIPLY', s2.outputs['Red'], 1.15))                # neon-green outline mask
    gm = t.nodes.new("ShaderNodeMapRange"); gm.inputs['From Min'].default_value = 0.05; gm.inputs['From Max'].default_value = 0.35; gm.clamp = True
    t.links.new(gl, gm.inputs['Value'])
    t.links.new(im.outputs['Color'], b.inputs['Base Color']); b.inputs['Metallic'].default_value = 0.55; b.inputs['Roughness'].default_value = 0.30
    em_mix = t.nodes.new("ShaderNodeMix"); em_mix.data_type = 'RGBA'; t.links.new(gm.outputs['Result'], em_mix.inputs[0])
    _A = [s for s in em_mix.inputs if s.name == 'A' and s.enabled][0]; _B = [s for s in em_mix.inputs if s.name == 'B' and s.enabled][0]
    t.links.new(im.outputs['Color'], _A); _B.default_value = (0.2, 1.0, 0.08, 1)
    t.links.new([o for o in em_mix.outputs if o.name == 'Result' and o.enabled][0], b.inputs['Emission Color'])
    t.links.new(m('ADD', m('MULTIPLY', gm.outputs['Result'], 7.0), 0.45), b.inputs['Emission Strength'])   # gold self-lit (0.45), neon-green outline glows (7.45)
    t.links.new(alpha, b.inputs['Alpha']); t.links.new(b.outputs['BSDF'], out.inputs['Surface'])
    dec.data.materials.append(dm)
log("surgery: done; mesh now", len(rifle.data.polygons), "polys")
