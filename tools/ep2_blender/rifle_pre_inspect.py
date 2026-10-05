# pre-hook (exec'd inside rifle_hero.py): report connected islands of the aligned rifle mesh
import bmesh
bm = bmesh.new(); bm.from_mesh(rifle.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
seen = [-1] * len(bm.faces); isl = []
for f in bm.faces:
    if seen[f.index] >= 0: continue
    k = len(isl); stack = [f]; seen[f.index] = k; cnt = 0; vs = set()
    while stack:
        cur = stack.pop(); cnt += 1
        for vtx in cur.verts: vs.add(vtx.index)
        for e in cur.edges:
            for nf in e.link_faces:
                if seen[nf.index] < 0: seen[nf.index] = k; stack.append(nf)
    isl.append((cnt, vs))
isl.sort(key=lambda t: -t[0])
for n, vs in isl[:12]:
    co = np.array([tuple(bm.verts[i].co) for i in vs])
    log("island faces", n, "min", [round(x, 3) for x in co.min(0)], "max", [round(x, 3) for x in co.max(0)])
log("islands total", len(isl))
bm.free()
