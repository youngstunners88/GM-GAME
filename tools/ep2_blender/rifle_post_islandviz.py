# post-hook: colour the 14 biggest islands (flat emission) and print color -> bbox so a human can pick which to delete/move
import bmesh
bm = bmesh.new(); bm.from_mesh(rifle.data); bm.faces.ensure_lookup_table()
seen = [-1] * len(bm.faces); isl = []
for f in bm.faces:
    if seen[f.index] >= 0: continue
    k = len(isl); st = [f]; seen[f.index] = k; faces = []
    while st:
        cur = st.pop(); faces.append(cur.index)
        for e in cur.edges:
            for nf in e.link_faces:
                if seen[nf.index] < 0: seen[nf.index] = k; st.append(nf)
    isl.append(faces)
order = sorted(range(len(isl)), key=lambda i: -len(isl[i]))
PAL = [("red", (1, 0, 0)), ("green", (0, 1, 0)), ("blue", (0.1, 0.3, 1)), ("yellow", (1, 1, 0)), ("magenta", (1, 0, 1)), ("cyan", (0, 1, 1)),
       ("orange", (1, 0.5, 0)), ("white", (1, 1, 1)), ("purple", (0.5, 0, 1)), ("pink", (1, 0.5, 0.7)), ("lime", (0.6, 1, 0.1)), ("teal", (0, 0.5, 0.5)),
       ("brown", (0.5, 0.25, 0.05)), ("navy", (0, 0, 0.5))]
cols = {}
for rank, idx in enumerate(order[:len(PAL)]):
    for fi in isl[idx]: cols[fi] = PAL[rank][1]
    co = np.array([tuple(bm.faces[fi].calc_center_median()) for fi in isl[idx]])
    log("ISLAND", PAL[rank][0], "idx", idx, "faces", len(isl[idx]), "min", [round(float(x), 3) for x in co.min(0)], "max", [round(float(x), 3) for x in co.max(0)])
attr = rifle.data.color_attributes.new("isl", 'FLOAT_COLOR', 'CORNER')
loops = rifle.data.loops
for p in rifle.data.polygons:
    c = cols.get(p.index, (0.15, 0.15, 0.15))
    for li in p.loop_indices: attr.data[li].color = (c[0], c[1], c[2], 1)
m = bpy.data.materials.new("viz"); m.use_nodes = True; t = m.node_tree
for n in list(t.nodes): t.nodes.remove(n)
o = t.nodes.new("ShaderNodeOutputMaterial"); e = t.nodes.new("ShaderNodeEmission"); a = t.nodes.new("ShaderNodeAttribute"); a.attribute_name = "isl"
t.links.new(a.outputs['Color'], e.inputs['Color']); t.links.new(e.outputs[0], o.inputs[0])
rifle.data.materials.clear(); rifle.data.materials.append(m)
bm.free()
