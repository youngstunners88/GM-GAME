# diagnostic pre-hook: per-island bbox of faces whose centre x lies in a slice, plus floating small islands near the stock
import bmesh
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
for lo, hi in ((0.50, 0.58), (0.60, 0.64)):
    log("SLICE", lo, hi)
    for i, faces in enumerate(isl):
        if i in {201, 291, 199, 200, 204}: continue
        sel = [f for f in faces if lo <= f.calc_center_median().x <= hi]
        if len(sel) < 6: continue
        co = np.array([tuple(v.co) for f in sel for v in f.verts])
        log(" isl", i, "nf", len(sel), "y", [round(float(a), 3) for a in (co[:, 1].min(), co[:, 1].max())], "z", [round(float(a), 3) for a in (co[:, 2].min(), co[:, 2].max())])
log("FLOATERS (x<-0.30, z>0.25)")
for i, faces in enumerate(isl):
    if i in {201, 291, 199, 200, 204}: continue
    co = np.array([tuple(v.co) for f in faces for v in f.verts])
    if co[:, 0].max() < -0.30 and co[:, 2].min() > 0.2:
        log(" float", i, "nf", len(faces), "min", [round(float(a), 3) for a in co.min(0)], "max", [round(float(a), 3) for a in co.max(0)])
# receiver side-plate: histogram of face-centre y for faces with centre in x[-0.2,0.2], z[0.2,0.3]
ys = [f.calc_center_median().y for faces in isl for f in faces if -0.2 <= f.calc_center_median().x <= 0.2 and 0.2 <= f.calc_center_median().z <= 0.3]
log("PLATE y-range", round(min(ys), 3), round(max(ys), 3), "n", len(ys))
bm.free()
