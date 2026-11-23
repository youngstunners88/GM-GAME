"""Carriage harness for the rigged town horse (src/episode2/assets/town/horse.glb) - founder brief 2026-11-23 "option 5".

Every strap is fitted to the horse's own body: the mesh is sliced (bmesh bisect) where a strap goes round it, the slice's outline is
pushed out a little and a strap section is swept along it. Parts are named  Harness_<bone>_<part>  so the game can pin each one to
that bone (BoneAttachment3D) and it moves with the horse's idle:
  neck1: collar + hames        head: bridle, blinkers, bit, plume (royal only)        root: pad, girth, traces (wheel/lead)
  spine: breeching, hip strap, crupper
Materials: Leather / Brass (working teams); the game swaps them to BlackLeather / Gilt for the royal teams and shows the plumes.
  blender -b --factory-startup --python tools/ep2_blender/build_visitor_harness.py -- --out src/episode2/extras/auction/visitors/visitor_harness.glb [--preview dir]
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[ARGS.index("--out") + 1] if "--out" in ARGS else "src/episode2/extras/auction/visitors/visitor_harness.glb"
PREVIEW = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else None
HORSE = "src/episode2/assets/town/horse.glb"
TAU = math.tau

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=HORSE)
ARM = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
BODY = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.parent == ARM)
ARM.data.pose_position = "REST"
BONE = {b.name: (ARM.matrix_world @ b.head_local, ARM.matrix_world @ b.tail_local) for b in ARM.data.bones}
SRC = bmesh.new()
SRC.from_mesh(BODY.data)
SRC.transform(BODY.matrix_world)

MATS = {}
for name, col, met, rough in (("Leather", (0.13, 0.065, 0.03), 0.0, 0.5), ("Brass", (0.92, 0.68, 0.36), 1.0, 0.35),
                              ("Plume", (0.93, 0.91, 0.87), 0.0, 0.95), ("PlumeRed", (0.6, 0.03, 0.04), 0.0, 0.95)):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Metallic"].default_value = met
    b.inputs["Roughness"].default_value = rough
    MATS[name] = m
PARTS = []


def put(bm, mat, name):
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(MATS[mat])
    PARTS.append(o)
    return o


def merge_into(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    for p in objs[1:]:
        if p in PARTS:
            PARTS.remove(p)
    return o


def sweep(pts, shape, mat, name, closed=False, scales=None, up=None):
    pts = [Vector(p) for p in pts]
    n = len(pts)
    bm = bmesh.new()
    rings = []
    prev = None
    for i, p in enumerate(pts):
        t = (pts[(i + 1) % n] - pts[(i - 1) % n]) if closed else (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        t.normalize()
        u = up(p) if callable(up) else (up or Vector((0, 0, 1)))
        side = t.cross(u)
        if side.length < 1e-6:
            side = prev if prev is not None else t.orthogonal()
        side.normalize()
        prev = side
        nrm = side.cross(t).normalized()
        s = scales[i] if scales else 1.0
        rings.append([bm.verts.new(p + side * a * s + nrm * b * s) for a, b in shape])
    k = len(shape)
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for A, B in pairs:
        for j in range(k):
            bm.faces.new((A[j], A[(j + 1) % k], B[(j + 1) % k], B[j]))
    if not closed:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return put(bm, mat, name)


def lathe(prof, seg, m, mat, name, closed=False):
    bm = bmesh.new()
    rings = []
    for r, h in prof:
        rings.append([bm.verts.new((0, 0, h))] if r < 1e-6 else [bm.verts.new((r * math.cos(TAU * i / seg), r * math.sin(TAU * i / seg), h)) for i in range(seg)])
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for A, B in pairs:
        if len(A) == 1 and len(B) == 1:
            continue
        if len(A) == 1:
            for i in range(seg):
                bm.faces.new((A[0], B[i], B[(i + 1) % seg]))
        elif len(B) == 1:
            for i in range(seg):
                bm.faces.new((A[i], A[(i + 1) % seg], B[0]))
        else:
            for i in range(seg):
                bm.faces.new((A[i], A[(i + 1) % seg], B[(i + 1) % seg], B[i]))
    if not closed:
        for ring in (rings[0], rings[-1]):
            if len(ring) > 2:
                bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.transform(m)
    return put(bm, mat, name)


def rect(w, h):
    return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]


def circ(r, n=6):
    return [(r * math.cos(TAU * i / n), r * math.sin(TAU * i / n)) for i in range(n)]


def section(co, no, keep=None, radius=0.5):
    """Slice the horse with the plane (co, no): the outline (largest loop around the plane point), as ordered points."""
    bm = SRC.copy()
    geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
    res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=False, clear_outer=False)
    cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    pts = [v.co.copy() for e in cut for v in e.verts]
    bm.free()
    pts = [p for p in pts if (p - Vector(co)).length < radius]
    if keep:
        pts = [p for p in pts if keep(p)]
    # project to the plane basis and keep the convex hull (straps bridge hollows), ordered by angle
    no = Vector(no).normalized()
    a = no.orthogonal().normalized()
    if abs(a.dot(Vector((0, 0, 1)))) < 0.9 and abs(no.z) < 0.9:
        a = Vector((0, 0, 1)) - no * no.z
        a.normalize()
    b = no.cross(a).normalized()
    from mathutils.geometry import convex_hull_2d
    p2 = [((p - Vector(co)).dot(a), (p - Vector(co)).dot(b)) for p in pts]
    hull = convex_hull_2d(p2)
    ring = [Vector(co) + a * p2[i][0] + b * p2[i][1] for i in hull]
    return ring, a, b


def resample(ring, n, closed=True):
    segs = list(zip(ring, ring[1:] + ([ring[0]] if closed else [])))
    lens = [(q - p).length for p, q in segs]
    total = sum(lens)
    out = []
    for i in range(n):
        d = total * i / n if closed else total * i / (n - 1)
        for (p, q), L in zip(segs, lens):
            if d <= L or (p, q) == segs[-1]:
                out.append(p.lerp(q, min(1.0, d / max(L, 1e-9))))
                break
            d -= L
    return out


def puff(ring, centre, d):
    return [p + (p - centre).normalized() * d for p in ring]


def centroid(pts):
    c = Vector()
    for p in pts:
        c += p
    return c / len(pts)


# ------------------------------------------------------------------ collar + hames (neck1)
n1h, n1t = BONE["neck1"]
ndir = (n1t - n1h).normalized()
cpos = n1h + ndir * 0.13
ring, a, b = section(cpos, ndir, radius=0.42)
ring = resample(ring, 40)
cc = centroid(ring)
collar = puff(ring, cc, 0.045)
sweep(collar, circ(0.05, 8), "Leather", "Harness_neck1_collar", closed=True)
hames_pts = [p for p in puff(ring, cc, 0.075)]
for side in (1, -1):                       # hames: brass bars up each side of the collar, ball tips over the crest
    arc = [p for p in hames_pts if (p.y * side) > -0.02]
    arc.sort(key=lambda p: p.z)
    arc = resample(arc, 10, closed=False)
    sweep(arc, rect(0.03, 0.022), "Brass", f"Harness_neck1_hame{side}", up=lambda p: ndir)
    tip = arc[-1] + Vector((0, 0, 0.06))
    lathe([(0.0, -0.03), (0.025, -0.01), (0.025, 0.01), (0.0, 0.035)], 10, Matrix.Translation(tip), "Brass", f"Harness_neck1_knob{side}")
# collar side points (where the traces start)
SIDE_Z = cc.z - 0.08
trace_start = {}
for side in (1, -1):
    best = max(collar, key=lambda p: p.y * side - abs(p.z - SIDE_Z) * 0.6)
    trace_start[side] = best + Vector((0, 0.03 * side, 0))

# ------------------------------------------------------------------ pad + girth (root), terrets
rh, rt = BONE["root"]
px = rh.x + 0.05
ring, a, b = section(Vector((px, 0, 1.2)), Vector((1, 0, 0)), keep=lambda p: p.z > 0.86, radius=0.6)
ring = resample(ring, 48)
cc = centroid(ring)
girth = puff(ring, cc, 0.018)
sweep(girth, rect(0.07, 0.012), "Leather", "Harness_root_girth", closed=True, up=lambda p: Vector((1, 0, 0)))
top = [p for p in puff(ring, cc, 0.03) if p.z > cc.z + 0.12]
top.sort(key=lambda p: p.y)
sweep(top, rect(0.2, 0.035), "Leather", "Harness_root_pad", up=lambda p: Vector((1, 0, 0)))
crest = max(top, key=lambda p: p.z)
for side in (1, -1):
    tp = min(top, key=lambda p: abs(p.y - side * 0.09)) + Vector((0, 0, 0.03))
    m = Matrix.Translation(tp + Vector((0, 0, 0.04))) @ Matrix.Rotation(math.radians(90), 4, "X")
    lathe([(0.04, -0.006), (0.04, 0.006), (0.028, 0.006), (0.028, -0.006)], 14, m, "Brass", f"Harness_root_terret{side}", closed=True)

# ------------------------------------------------------------------ traces (root): along the flank to the bar behind the horse
def flank_point(x, z, side):
    ring, a, b = section(Vector((x, 0, z)), Vector((1, 0, 0)), keep=lambda p: p.z > 0.86, radius=0.6)
    cands = [p for p in ring if abs(p.z - z) < 0.12 and p.y * side > 0]
    if not cands:
        cands = ring
    p = max(cands, key=lambda q: q.y * side)
    return Vector((x, p.y + side * 0.035, z))

for kind, end_x in (("wheel", -1.5), ("lead", -2.0)):
    for side in (1, -1):
        st = trace_start[side]
        pts = [st]
        for x in (st.x - 0.25, px, -0.45, -0.85):
            z = st.z + (x - st.x) * 0.12
            pts.append(flank_point(x, z, side))
        last = pts[-1]
        pts.append(Vector((-1.2, last.y + side * 0.02, last.z - 0.08)))
        pts.append(Vector((end_x, side * 0.36, 0.86)))
        sweep(resample(pts, 16, closed=False), rect(0.045, 0.012), "Leather", f"Harness_root_trace_{kind}{side}", up=lambda p: Vector((0, 0, 1)))
    # the swingletree the traces hook to
    bar = Vector((end_x - 0.02, 0, 0.86))
    for side in (1, -1):
        lathe([(0.03, -0.012), (0.03, 0.012), (0.02, 0.012), (0.02, -0.012)], 10, Matrix.Translation(Vector((end_x, side * 0.36, 0.86))) @ Matrix.Rotation(math.radians(90), 4, "Y"), "Brass", f"Harness_root_hook_{kind}{side}", closed=True)

# ------------------------------------------------------------------ breeching, hip strap, crupper (spine)
sh, st_ = BONE["spine"]
bz = 1.05
ring, a, b = section(Vector((-0.6, 0, bz)), Vector((0, 0, 1)), keep=lambda p: p.x < -0.45)
ring = [p for p in ring if p.x < -0.5]
ring.sort(key=lambda p: math.atan2(p.y, -(p.x + 0.5)))
cc = Vector((-0.55, 0, bz))
breech = resample(puff(ring, cc, 0.03), 22, closed=False)
sweep(breech, rect(0.07, 0.014), "Leather", "Harness_spine_breeching", up=lambda p: Vector((0, 0, 1)))
ring, a, b = section(Vector((-0.75, 0, 1.2)), Vector((1, 0, 0)), keep=lambda p: p.z > bz)
ring = [p for p in ring if p.z > bz + 0.02]
ring.sort(key=lambda p: p.y)
hip = resample(puff(ring, Vector((-0.75, 0, 1.0)), 0.02), 14, closed=False)
sweep(hip, rect(0.05, 0.012), "Leather", "Harness_spine_hip", up=lambda p: Vector((1, 0, 0)))
spine_pts = []
for x in (crest.x, -0.2, -0.5, -0.8, -1.0):
    ring, a, b = section(Vector((x, 0, 1.2)), Vector((1, 0, 0)), keep=lambda p: p.z > 0.86, radius=0.6)
    tp = max(ring, key=lambda p: p.z - abs(p.y) * 2)
    spine_pts.append(Vector((x, 0, tp.z + 0.02)))
sweep(resample(spine_pts, 12, closed=False), rect(0.035, 0.012), "Leather", "Harness_spine_crupper", up=lambda p: Vector((0, 0, 1)))

# ------------------------------------------------------------------ bridle (head): noseband, browband, cheekpieces, blinkers, bit, plume
hh, ht = BONE["head"]
hdir = (ht - hh).normalized()
hl = (ht - hh).length + 0.09
nose_c = hh + hdir * (hl * 0.62)
brow_c = hh + hdir * (hl * 0.08)
ring, a, b = section(nose_c, hdir, radius=0.2)
nose = resample(puff(ring, centroid(ring), 0.012), 28)
sweep(nose, rect(0.035, 0.01), "Leather", "Harness_head_noseband", closed=True, up=lambda p: hdir)
ring, a, b = section(brow_c, hdir, radius=0.26)
brow = resample(puff(ring, centroid(ring), 0.012), 28)
sweep(brow, rect(0.035, 0.01), "Leather", "Harness_head_browband", closed=True, up=lambda p: hdir)
for side in (1, -1):
    np_ = max(nose, key=lambda p: p.y * side)
    bp = max(brow, key=lambda p: p.y * side)
    cheek = [bp.lerp(np_, t / 6) + Vector((0, side * 0.01 * math.sin(math.pi * t / 6), 0)) for t in range(7)]
    sweep(cheek, rect(0.03, 0.01), "Leather", f"Harness_head_cheek{side}", up=lambda p: Vector((0, side, 0)))
    eye = bp.lerp(np_, 0.25) + Vector((0, side * 0.02, 0.03))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((0.12, 0.012, 0.09)), verts=bm.verts)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.02, segments=2, affect="EDGES", clamp_overlap=True)
    bm.transform(Matrix.Translation(eye) @ Matrix.Rotation(math.radians(-25), 4, "Y"))
    put(bm, "Leather", f"Harness_head_blinker{side}")
    lathe([(0.026, -0.005), (0.026, 0.005), (0.018, 0.005), (0.018, -0.005)], 12, Matrix.Translation(eye + Vector((0, side * 0.01, 0))) @ Matrix.Rotation(math.radians(90), 4, "X"), "Brass", f"Harness_head_rosette{side}", closed=True)
    mouth = np_ + hdir * 0.05 + Vector((0, side * 0.005, -0.05))
    lathe([(0.03, -0.004), (0.03, 0.004), (0.022, 0.004), (0.022, -0.004)], 12, Matrix.Translation(mouth) @ Matrix.Rotation(math.radians(90), 4, "X"), "Brass", f"Harness_head_bit{side}", closed=True)
# plume: a gilt socket on the poll and a spray of feathers (royal teams only)
poll = max(brow, key=lambda p: p.z) + Vector((0, 0, 0.02))
lathe([(0.0, 0), (0.035, 0), (0.03, 0.05), (0.04, 0.09), (0.0, 0.1)], 10, Matrix.Translation(poll), "Brass", "Harness_head_plumesocket")
feathers = []
for k in range(7):
    a_ = TAU * k / 7
    lean = Vector((math.cos(a_) * 0.09 - 0.05, math.sin(a_) * 0.09, 0))
    pts = [poll + Vector((0, 0, 0.09)) + lean * (t / 6) ** 1.5 + Vector((-0.02 * t, 0, 0.07 * t)) for t in range(7)]
    feathers.append(sweep(pts, [(0.06 * math.cos(TAU * i / 6), 0.014 * math.sin(TAU * i / 6)) for i in range(6)], "Plume" if k % 2 == 0 else "PlumeRed",
                          f"Harness_head_feather{k}", scales=[0.4, 0.9, 1.1, 1.1, 0.95, 0.7, 0.3]))

# one object per (bone, part family), so the game pins a handful of meshes per horse
groups = {}
for o in list(PARTS):
    key = o.name.rstrip("-1").rstrip("0123456789")
    if "feather" in o.name:
        key = "Harness_head_plume_" + o.data.materials[0].name
    elif "plumesocket" in o.name:
        key = "Harness_head_plume_socket"
    elif "trace_wheel" in o.name or "hook_wheel" in o.name:
        key = "Harness_root_traces_wheel"
    elif "trace_lead" in o.name or "hook_lead" in o.name:
        key = "Harness_root_traces_lead"
    else:
        key = "_".join(o.name.split("_")[:2]) + "_" + o.data.materials[0].name
    groups.setdefault(key, []).append(o)
final = []
for key, objs in groups.items():
    final.append(merge_into(key, objs) if len(objs) > 1 else objs[0])
    final[-1].name = key
bpy.data.objects.remove(BODY, do_unlink=True)
for o in list(bpy.context.scene.objects):
    if o.type == "MESH" and not o.name.startswith("Harness_"):
        bpy.data.objects.remove(o, do_unlink=True)
tris = 0
for o in final:
    tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
bpy.ops.object.select_all(action="DESELECT")
for o in final:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format="GLB", export_normals=True, export_yup=True, export_vertex_color="NONE")
print("HARNESS", sorted(o.name for o in final), "tris", tris, "KB", os.path.getsize(OUT) // 1024)

if PREVIEW:
    bpy.ops.import_scene.gltf(filepath=HORSE)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 800, 600
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    next(n for n in w.node_tree.nodes if n.type == "BACKGROUND").inputs[1].default_value = 1.0
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.data.energy = 4
    sun.rotation_euler = (0.9, 0, -0.8)
    for o in sc.objects:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    tgt = Vector((0, 0, 1.1))
    for i, az in enumerate((60, 150, 240, 330)):
        a = math.radians(az)
        cam.location = tgt + Vector((math.sin(a) * 4.2, -math.cos(a) * 4.2, 1.0))
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(PREVIEW, f"harness_{i}.png")
        bpy.ops.render.render(write_still=True)
