"""Visitor carriages for the auction grounds, modelled by hand (no generators) - founder brief 2026-11-23 "option 5".

Four rigs, same slots and the same exuberant size as the 2026-11-20 Tripo set, rebuilt as real parts:
  visitor_royal_palace   towering gilded palace coach (C-springs, gallery tier, dome, crown, red-carpet steps)
  visitor_royal_coach    black lacquer + brass state coach (Irish State Coach family)
  visitor_common_pair    plain mud wagon for a pair: weathered wood, iron, canvas curtains, thoroughbraces
  visitor_common_single  buckboard in shafts with a spring seat and a tarped load

The horses are NOT in these files: each GLB carries `Hitch_<i>` empties (horse origin, nose toward +Z) and the game hitches the
rigged town horse there with harness (tools/ep2_blender/build_visitor_harness.py). Material NAMES are the contract with
src/episode2/chamber/ep2_carriage_look.gd, which gives each one its real PBR look in Godot (gilt = metal, no emission).
Vertex colour COLOR_0 carries baked ambient occlusion and the red-ground dust on the lower parts.

  blender -b --factory-startup --python tools/ep2_blender/build_visitor_carriages.py -- --out src/episode2/extras/auction/visitors \
      [--only visitor_royal_palace] [--preview <dir>] [--no-bake]
Conventions: x = right, f = forward (toward the horses), z = up; wheels touch z = 0. Exported +Z forward (glTF), Y up.
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default
OUT = arg("--out", "src/episode2/extras/auction/visitors")
ONLY = arg("--only")
PREVIEW = arg("--preview")
BAKE = "--no-bake" not in ARGS
TAU = math.tau

def V(x, f, z):
    return Vector((x, -f, z))

# ---------------------------------------------------------------- materials (Blender look is only for review renders)
MAT_SPEC = {
    "Gilt": ((1.0, 0.72, 0.30), 1.0, 0.28), "Brass": ((0.92, 0.68, 0.36), 1.0, 0.36),
    "Lacquer": ((0.012, 0.012, 0.014), 0.0, 0.12), "RedPaint": ((0.48, 0.045, 0.03), 0.0, 0.32),
    "WoodWeathered": ((0.36, 0.29, 0.22), 0.0, 0.88), "WoodOiled": ((0.30, 0.17, 0.08), 0.0, 0.55),
    "Iron": ((0.09, 0.085, 0.08), 0.8, 0.62), "Leather": ((0.14, 0.07, 0.035), 0.0, 0.55),
    "BlackLeather": ((0.025, 0.022, 0.02), 0.0, 0.38), "Velvet": ((0.30, 0.015, 0.03), 0.0, 0.92),
    "Glass": ((0.55, 0.62, 0.66), 0.0, 0.04), "Canvas": ((0.66, 0.60, 0.48), 0.0, 0.95),
    "Carpet": ((0.42, 0.02, 0.03), 0.0, 1.0), "Plume": ((0.92, 0.90, 0.86), 0.0, 0.95),
    "PlumeRed": ((0.55, 0.03, 0.04), 0.0, 0.95), "Rope": ((0.52, 0.42, 0.28), 0.0, 0.95),
    "Shadow": ((0.0, 0.0, 0.0), 0.0, 1.0),
}
MATS = {}
def mats_init():
    for name, (col, met, rough) in MAT_SPEC.items():
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Metallic"].default_value = met
        bsdf.inputs["Roughness"].default_value = rough
        if name in ("Glass", "Shadow"):
            bsdf.inputs["Alpha"].default_value = 0.25 if name == "Glass" else 0.5
        MATS[name] = m


# ---------------------------------------------------------------- mesh builder
class Rig:
    def __init__(self, name):
        self.name = name
        self.objs = []
        self.hitches = []          # (pos Vector(x,f,z) game-space, kind)

    def put(self, bm, mat, smooth_angle=34.0):
        for f in bm.faces:
            f.smooth = True
        lim = math.radians(smooth_angle)
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > lim:
                e.smooth = False
        me = bpy.data.meshes.new(f"{self.name}_{mat}")
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(me.name, me)
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.append(MATS[mat])
        self.objs.append(o)
        return o

    # -- primitives (all return the object) --
    def cyl(self, a, b, r0, r1=None, seg=10, mat="Iron", caps=True, sx=1.0, sy=1.0):
        r1 = r0 if r1 is None else r1
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=1.0)
        for v in bm.verts:
            v.co.x *= sx
            v.co.y *= sy
        d = b - a
        m = Matrix.Translation((a + b) * 0.5) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Diagonal((1, 1, max(d.length, 1e-4), 1))
        bm.transform(m)
        return self.put(bm, mat)

    def box(self, c, size, mat, bev=0.0, seg=2, rot=None):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=Vector((abs(size[0]), abs(size[1]), abs(size[2]))), verts=bm.verts)
        if bev > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bev, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        m = Matrix.Translation(c) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4))
        bm.transform(m)
        return self.put(bm, mat)

    def lathe(self, prof, seg, m, mat, mod=None, closed=False, smooth_angle=34.0):
        """prof: [(r, h)] around local +Z. r == 0 makes a pole. mod(phi) scales the radius (flutes, petals)."""
        bm = bmesh.new()
        rings = []
        for r, h in prof:
            if r < 1e-6:
                rings.append([bm.verts.new((0, 0, h))])
            else:
                ring = []
                for i in range(seg):
                    ph = TAU * i / seg
                    rr = r * (mod(ph) if mod else 1.0)
                    ring.append(bm.verts.new((rr * math.cos(ph), rr * math.sin(ph), h)))
                rings.append(ring)
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
        return self.put(bm, mat, smooth_angle)

    def sweep(self, pts, shape, mat, up=None, scales=None, closed=False, caps=True, smooth_angle=40.0):
        """Sweep a closed 2D section [(u, v)] along pts. u follows `up` x tangent, v follows the projected up."""
        pts = [Vector(p) for p in pts]
        n = len(pts)
        up = up or Vector((0, 0, 1))
        bm = bmesh.new()
        rings = []
        prev_side = None
        for i, p in enumerate(pts):
            if closed:
                t = (pts[(i + 1) % n] - pts[(i - 1) % n])
            else:
                t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
            t = t.normalized() if t.length > 1e-9 else Vector((0, 1, 0))
            side = t.cross(up)
            if side.length < 1e-6:
                side = prev_side if prev_side is not None else t.orthogonal()
            side.normalize()
            prev_side = side
            nrm = side.cross(t).normalized()
            s = scales[i] if scales else 1.0
            rings.append([bm.verts.new(p + side * (u * s) + nrm * (v * s)) for u, v in shape])
        k = len(shape)
        pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
        for A, B in pairs:
            for j in range(k):
                bm.faces.new((A[j], A[(j + 1) % k], B[(j + 1) % k], B[j]))
        if caps and not closed:
            bm.faces.new(rings[0])
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        return self.put(bm, mat, smooth_angle)

    def prism(self, outline, x0, x1, mat, bev=0.0, seg=2):
        """Extrude a side outline [(f, z)] across x0..x1 (a body panel, a step, a bracket)."""
        bm = bmesh.new()
        a = [bm.verts.new(V(x0, f, z)) for f, z in outline]
        b = [bm.verts.new(V(x1, f, z)) for f, z in outline]
        n = len(outline)
        bm.faces.new(a)
        bm.faces.new(list(reversed(b)))
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if bev > 0:
            rim = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(50)]
            bmesh.ops.bevel(bm, geom=rim, offset=bev, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        return self.put(bm, mat)

    def join(self):
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objs[0]
        bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = self.name
        o.data.name = self.name
        # merge material slots that share a material (join keeps one slot per source)
        return o


# ---------------------------------------------------------------- shapes
def circle_sec(r, n=8, sx=1.0, sy=1.0):
    return [(r * sx * math.cos(TAU * i / n), r * sy * math.sin(TAU * i / n)) for i in range(n)]

def rect_sec(w, h, bev=0.0):
    if bev <= 0:
        return [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
    out = []
    for cx, cy, a0 in ((w / 2 - bev, -h / 2 + bev, -90), (w / 2 - bev, h / 2 - bev, 0), (-w / 2 + bev, h / 2 - bev, 90), (-w / 2 + bev, -h / 2 + bev, 180)):
        for k in range(3):
            a = math.radians(a0 + 45 * k)
            out.append((cx + bev * math.cos(a), cy + bev * math.sin(a)))
    return out

def half_round(r, n=6):
    """Moulding section, flat side on the panel (v = 0 is the panel, bulging toward +v)."""
    pts = [(r * math.cos(math.pi * i / n), r * math.sin(math.pi * i / n)) for i in range(n + 1)]
    return [(u, v) for u, v in reversed(pts)]

def catmull(ctrl, steps=6, closed=True):
    out = []
    n = len(ctrl)
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = ctrl[(i - 1) % n] if closed else ctrl[max(i - 1, 0)]
        p1, p2 = ctrl[i], ctrl[(i + 1) % n]
        p3 = ctrl[(i + 2) % n] if closed else ctrl[min(i + 2, n - 1)]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in range(len(p1))))
    if not closed:
        out.append(tuple(ctrl[-1]))
    return out

def offset_poly(poly, d):
    """Inset a closed 2D polygon (counter-clockwise) by d."""
    n = len(poly)
    out = []
    area = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sgn = 1.0 if area > 0 else -1.0
    for i in range(n):
        p0, p1, p2 = Vector(poly[i - 1]), Vector(poly[i]), Vector(poly[(i + 1) % n])
        e0 = (p1 - p0).normalized()
        e1 = (p2 - p1).normalized()
        n0 = Vector((-e0.y, e0.x)) * sgn
        n1 = Vector((-e1.y, e1.x)) * sgn
        nn = (n0 + n1)
        nn = nn.normalized() if nn.length > 1e-6 else n0
        cosh = max(0.35, nn.dot(n0))
        q = p1 + nn * (d / cosh)
        out.append((q.x, q.y))
    return out

def rrect(f0, f1, z0, z1, r, n=4):
    """Rounded rectangle path in the (f, z) plane, counter-clockwise."""
    pts = []
    for cf, cz, a0 in ((f1 - r, z0 + r, -90), (f1 - r, z1 - r, 0), (f0 + r, z1 - r, 90), (f0 + r, z0 + r, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            pts.append((cf + r * math.cos(a), cz + r * math.sin(a)))
    return pts


# ---------------------------------------------------------------- parts
def wheel(rig, x, f, R, spokes, wood, tyre="Iron", hub_mat=None, width=0.075, dish=0.012):
    """A real wheel on its axle end: iron tyre, felloe, tapered staggered spokes, turned hub with bands. Touches z = 0."""
    s = 1.0 if x >= 0 else -1.0
    c = V(x, f, R)
    ax = Matrix.Translation(c) @ Matrix.Rotation(math.radians(90) * s, 4, "Y")   # local +Z = outward
    rig.lathe([(R, -width / 2), (R, width / 2), (R - 0.016, width / 2), (R - 0.016, -width / 2)], 72, ax, tyre, closed=True, smooth_angle=60)
    fi = R - 0.016
    fo = R - 0.016 - 0.065
    rig.lathe([(fi, -width / 2 + 0.006), (fi, width / 2 - 0.006), (fo, width / 2 - 0.01), (fo, -width / 2 + 0.01)], 64, ax, wood, closed=True, smooth_angle=60)
    hub_r = 0.075 + R * 0.06
    hl = 0.17 + R * 0.06
    hub_mat = hub_mat or wood
    rig.lathe([(0.0, -hl * 0.55), (hub_r * 0.55, -hl * 0.55), (hub_r * 0.8, -hl * 0.4), (hub_r, -hl * 0.12), (hub_r, hl * 0.1),
               (hub_r * 0.82, hl * 0.32), (hub_r * 0.6, hl * 0.55), (hub_r * 0.5, hl * 0.62), (0.0, hl * 0.66)], 20, ax, hub_mat)
    band = "Brass" if hub_mat in ("Gilt", "Brass", "RedPaint", "Lacquer") else "Iron"
    if hub_mat == "Gilt":
        band = "Gilt"
    for hz, rr in ((-hl * 0.42, hub_r * 0.84), (hl * 0.34, hub_r * 0.86)):
        rig.lathe([(rr + 0.008, hz - 0.012), (rr + 0.008, hz + 0.012), (rr - 0.004, hz + 0.012), (rr - 0.004, hz - 0.012)], 20, ax, band, closed=True, smooth_angle=60)
    rig.lathe([(0.0, hl * 0.64), (hub_r * 0.42, hl * 0.6), (hub_r * 0.45, hl * 0.72), (hub_r * 0.3, hl * 0.82), (0.0, hl * 0.86)], 16, ax, band)
    for i in range(spokes):
        a = TAU * i / spokes
        st = dish if i % 2 == 0 else -dish * 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = ax @ (d * hub_r * 0.92 + Vector((0, 0, st * 0.2)))
        p1 = ax @ (d * (fo + 0.012) + Vector((0, 0, st)))
        rig.cyl(p0, p1, 0.026 + R * 0.006, 0.017 + R * 0.004, seg=8, mat=wood, sx=0.7)
    return c


def axle(rig, f, R, half, mat="Iron", bed=None):
    rig.cyl(V(-half, f, R), V(half, f, R), 0.035, seg=10, mat=mat)
    if bed is not None:
        rig.box(V(0, f, R + 0.07), (half * 1.7, 0.11, 0.1), bed, bev=0.012)


def elliptic_spring(rig, x, f, z, length, gap=0.16, leaves=4, mat="Iron", along="f"):
    for side in (1, -1):
        for k in range(leaves):
            L = length * (1.0 - 0.16 * k)
            pts = []
            for i in range(17):
                t = -1 + 2 * i / 16
                h = side * (gap * 0.5 * (1 - t * t)) + side * k * 0.011 * 0  # leaves nest
                zz = z + side * (gap * 0.5) * (1 - t * t) - side * k * 0.012 * (1 - abs(t))
                if along == "f":
                    pts.append(V(x, f + t * L / 2, zz))
                else:
                    pts.append(V(x + t * L / 2, f, zz))
            rig.sweep(pts, rect_sec(0.06, 0.011), mat, up=Vector((0, 0, 1)) if along == "f" else Vector((0, 0, 1)))
    for t in (-1, 1):
        p = V(x, f + t * length / 2, z) if along == "f" else V(x + t * length / 2, f, z)
        rig.cyl(p + Vector((0.04, 0, 0)), p - Vector((0.04, 0, 0)), 0.02, seg=8, mat=mat)


def c_spring(rig, x, f, z0, height, reach, mat="Iron", strap="Leather", tip_to=None):
    """A C-spring standing on the perch at (x, f, z0), curling up and over toward +reach in f; a leather brace hangs from its tip."""
    pts = []
    scales = []
    for i in range(21):
        t = i / 20
        a = math.radians(-90 + 260 * t)
        r = height * 0.5
        pts.append(V(x, f + reach * 0.15 - r * math.cos(a) * 0.55 * math.copysign(1, reach), z0 + r + r * math.sin(a)))
        scales.append(1.25 - 0.55 * t)
    rig.sweep(pts, rect_sec(0.055, 0.045, 0.01), mat, scales=scales)
    tip = pts[-1]
    if tip_to is not None:
        rig.sweep([tip, tip_to], rect_sec(0.07, 0.014), strap, up=Vector((1, 0, 0)))
    return tip


def scroll(rig, origin, u, v, size, mat="Gilt", tube=0.03, turns=1.25, mirror=False, curl2=True):
    """A C-scroll volute (carved ornament) in the plane (u, v) through origin. Made once per call; mirrored by `mirror`."""
    pts = []
    sc = []
    sgn = -1.0 if mirror else 1.0
    n1 = 26
    for i in range(n1 + 1):                       # big volute, curling inward
        t = i / n1
        th = TAU * turns * t
        r = size * 0.5 * math.exp(-1.1 * th / TAU * 2.2)
        p2 = Vector((sgn * (-size * 0.5 + r * math.cos(th + math.pi)), size * 0.35 + r * math.sin(th + math.pi)))
        pts.insert(0, p2)
        sc.insert(0, max(0.25, 1.0 - 0.75 * t))
    if curl2:
        n2 = 22
        for i in range(1, n2 + 1):                # the sweep down and the small counter-curl
            t = i / n2
            ang = math.pi * t
            p2 = Vector((sgn * (-size * 0.5 + size * 0.9 * t), size * 0.35 - size * 0.55 * math.sin(ang * 0.9)))
            pts.append(p2)
            sc.append(1.0 - 0.5 * t)
        last = pts[-1]
        for i in range(1, 14):
            t = i / 13
            th = TAU * 0.8 * t
            r = size * 0.12 * (1 - 0.6 * t)
            pts.append(Vector((last.x + sgn * r * math.sin(th), last.y + size * 0.12 - r * math.cos(th) * 1.0)))
            sc.append(0.5 - 0.25 * t)
    p3 = [origin + u * p.x + v * p.y for p in pts]
    sec = [(c * 0.8, s) for c, s in circle_sec(tube, 7)]
    return rig.sweep(p3, sec, mat, up=u.cross(v).normalized(), scales=sc)


def rosette(rig, center, normal, r, mat="Gilt", petals=8):
    m = Matrix.Translation(center) @ normal.to_track_quat("Z", "Y").to_matrix().to_4x4()
    rig.lathe([(0.0, 0.0), (r, 0.0), (r * 0.85, r * 0.25), (r * 0.5, r * 0.4), (r * 0.2, r * 0.55), (0.0, r * 0.6)], 32, m, mat,
              mod=lambda ph: 1.0 + 0.16 * math.cos(petals * ph))


def finial(rig, base, h, mat="Gilt", kind="urn"):
    m = Matrix.Translation(base)
    if kind == "urn":
        prof = [(0.0, 0), (0.22, 0), (0.22, 0.05), (0.12, 0.09), (0.1, 0.14), (0.2, 0.3), (0.24, 0.42), (0.18, 0.55), (0.08, 0.62),
                (0.1, 0.68), (0.05, 0.75), (0.07, 0.84), (0.0, 1.0)]
    elif kind == "spire":
        prof = [(0.0, 0), (0.2, 0), (0.2, 0.06), (0.14, 0.1), (0.16, 0.2), (0.1, 0.26), (0.13, 0.32), (0.07, 0.4), (0.045, 0.7),
                (0.06, 0.74), (0.025, 0.78), (0.035, 0.85), (0.0, 1.0)]
    else:  # ball
        prof = [(0.0, 0), (0.12, 0), (0.12, 0.05), (0.07, 0.1)] + [(0.2 * math.sin(math.pi * k / 8), 0.1 + 0.4 * (1 - math.cos(math.pi * k / 8)) / 2 * 1.0) for k in range(1, 8)] + [(0.0, 0.5), (0.0, 0.5)]
        prof = prof[:-1]
    prof = [(r * h, z * h) for r, z in prof]
    rig.lathe(prof, 16, m, mat, mod=(lambda ph: 1.0 + 0.06 * math.cos(8 * ph)) if kind == "urn" else None)


def crown(rig, base, r, mat="Gilt", cap="Velvet"):
    m = Matrix.Translation(base)
    rig.lathe([(r, 0.0), (r * 1.08, 0.02), (r * 1.08, r * 0.32), (r, r * 0.36), (r * 0.95, r * 0.34), (r * 0.95, 0.02)], 32, m, mat, closed=True)
    rig.lathe([(0.0, r * 0.05)] + [(r * 0.93 * math.cos(math.pi / 2 * k / 6), r * 0.3 + r * 0.75 * math.sin(math.pi / 2 * k / 6)) for k in range(7)][::-1][:-1] + [(r * 0.93, r * 0.3)], 24, m, cap)
    for k in range(8):                       # the arches meet over the cap
        a = TAU * k / 8
        pts = []
        for i in range(13):
            t = i / 12
            rr = r * 1.0 * math.cos(t * math.pi / 2)
            pts.append(base + Vector((rr * math.cos(a), rr * math.sin(a), r * 0.34 + r * 0.95 * math.sin(t * math.pi / 2) - r * 0.18 * math.sin(t * math.pi) ** 2)))
        rig.sweep(pts, circle_sec(r * 0.06, 6), mat)
        jewel = base + Vector((r * 1.1 * math.cos(a + TAU / 16), r * 1.1 * math.sin(a + TAU / 16), r * 0.18))
        rig.lathe([(0.0, -r * 0.08), (r * 0.08, 0.0), (0.0, r * 0.08)], 8, Matrix.Translation(jewel), "RedPaint")
        finial(rig, base + Vector((r * 1.04 * math.cos(a), r * 1.04 * math.sin(a), r * 0.34)), r * 0.35, mat, "ball")
    top = base + Vector((0, 0, r * 1.28))
    rig.lathe([(0.0, 0.0)] + [(r * 0.2 * math.sin(math.pi * k / 10), r * 0.2 * (1 - math.cos(math.pi * k / 10))) for k in range(1, 10)] + [(0.0, r * 0.4)], 16, Matrix.Translation(top - Vector((0, 0, r * 0.05))), mat)
    cx = top + Vector((0, 0, r * 0.35))
    rig.box(cx + Vector((0, 0, r * 0.22)), (r * 0.08, r * 0.08, r * 0.5), mat, bev=r * 0.015)
    rig.box(cx + Vector((0, 0, r * 0.3)), (r * 0.32, r * 0.08, r * 0.08), mat, bev=r * 0.015)


def lantern(rig, base, h, metal="Brass", glass="Glass", arm_from=None):
    m = Matrix.Translation(base)
    s = h
    rig.lathe([(0.0, 0.0), (0.06 * s, 0.0), (0.1 * s, 0.06 * s), (0.2 * s, 0.12 * s), (0.22 * s, 0.16 * s), (0.0, 0.16 * s)], 6, m, metal, smooth_angle=20)
    rig.lathe([(0.19 * s, 0.16 * s), (0.21 * s, 0.6 * s), (0.0, 0.6 * s), (0.0, 0.16 * s)], 6, m, glass, smooth_angle=20)
    for k in range(6):
        a = TAU * k / 6
        rig.cyl(base + Vector((0.2 * s * math.cos(a), 0.2 * s * math.sin(a), 0.16 * s)), base + Vector((0.215 * s * math.cos(a), 0.215 * s * math.sin(a), 0.6 * s)), 0.012 * s, seg=4, mat=metal)
    rig.lathe([(0.0, 0.6 * s), (0.25 * s, 0.6 * s), (0.25 * s, 0.64 * s), (0.12 * s, 0.78 * s), (0.08 * s, 0.86 * s), (0.1 * s, 0.9 * s), (0.0, 1.0 * s)], 6, m, metal, smooth_angle=20)
    if arm_from is not None:
        mid = (arm_from + base) * 0.5 + Vector((0, 0, -0.05))
        rig.sweep([arm_from, mid, base + Vector((0, 0, 0.3 * s))], circle_sec(0.014, 6), metal)


def shadow_blob(rig, f, half_x, half_f, z=0.006):
    """Soft contact shadow under the rig (Godot draws it with a radial-alpha material)."""
    bm = bmesh.new()
    vs = [bm.verts.new(V(sx * half_x, f + sf * half_f, z)) for sx, sf in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for fc in bm.faces:
        if fc.normal.z < 0:
            fc.normal_flip()
    uv = bm.loops.layers.uv.new("UVMap")
    for fc in bm.faces:
        for lp, (u, w) in zip(fc.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            lp[uv].uv = (u, w)
    return rig.put(bm, "Shadow")


def strap_path(rig, pts, w, t, mat):
    rig.sweep(pts, rect_sec(w, t), mat, up=Vector((0, 0, 1)))


# ---------------------------------------------------------------- the coach body (berline): profile extruded across, hollowed, windows cut
def coach_body(rig, prof, half_w, shell, windows, body_mat, frame_mat, inner_mat="Velvet", bev=0.035, edge_mat=None):
    """prof: closed side outline [(f, z)] (ccw seen from +x). windows: [(f0, f1, z0, z1, r)] through both sides.
    Built as an explicit shell (no booleans): side panels with real window holes, the outer band round the profile, a velvet lining,
    framed reveals in `frame_mat`, glass, and a moulding along each side edge. Returns nothing (parts go into the rig)."""
    from mathutils.geometry import tessellate_polygon
    n = len(prof)
    inner = offset_poly(prof, shell)
    holes = [rrect(f0, f1, z0, z1, r, 4) for f0, f1, z0, z1, r in windows]
    c2 = Vector((sum(p[0] for p in prof) / n, sum(p[1] for p in prof) / n))

    def face_out(bm, verts, want):
        f = bm.faces.new(verts)
        f.normal_update()
        if f.normal.dot(want) < 0:
            f.normal_flip()
        return f

    for s_ in (1, -1):
        for x, mat, loops, want in ((s_ * half_w, body_mat, [prof] + holes, Vector((s_, 0, 0))),
                                    (s_ * (half_w - shell), inner_mat, [inner] + holes, Vector((-s_, 0, 0)))):
            polys = [[Vector((x, -f, z)) for f, z in loop] for loop in loops]
            tris = tessellate_polygon(polys)
            flat = [v for loop in polys for v in loop]
            bm = bmesh.new()
            vs = [bm.verts.new(v) for v in flat]
            for t in tris:
                face_out(bm, [vs[t[0]], vs[t[1]], vs[t[2]]], want)
            rig.put(bm, mat, smooth_angle=10)
        for hole in holes:                       # the reveal: a framed jamb through the wall
            bm = bmesh.new()
            a = [bm.verts.new(V(s_ * half_w, f, z)) for f, z in hole]
            b = [bm.verts.new(V(s_ * (half_w - shell), f, z)) for f, z in hole]
            hc = Vector((sum(p[0] for p in hole) / len(hole), sum(p[1] for p in hole) / len(hole)))
            for i in range(len(hole)):
                j = (i + 1) % len(hole)
                mid = Vector(((hole[i][0] + hole[j][0]) / 2, (hole[i][1] + hole[j][1]) / 2))
                d = (hc - mid).normalized()
                face_out(bm, [a[i], a[j], b[j], b[i]], Vector((0, -d.x, d.y)))
            rig.put(bm, frame_mat, smooth_angle=50)
            ring = [V(s_ * (half_w - shell * 0.4), f, z) for f, z in hole]
            bm = bmesh.new()
            bm.faces.new([bm.verts.new(v) for v in ring])
            rig.put(bm, "Glass")
            pts = [V(s_ * (half_w + 0.004), f, z) for f, z in hole]
            rig.sweep(pts, [(v * s_, u) for u, v in half_round(0.022, 5)], frame_mat, up=Vector((1, 0, 0)), closed=True)
    for loop, x0, mat, sign in ((prof, half_w, body_mat, 1.0), (inner, half_w - shell, inner_mat, -1.0)):
        bm = bmesh.new()
        a = [bm.verts.new(V(-x0, f, z)) for f, z in loop]
        b = [bm.verts.new(V(x0, f, z)) for f, z in loop]
        for i in range(len(loop)):
            j = (i + 1) % len(loop)
            mid = Vector(((loop[i][0] + loop[j][0]) / 2, (loop[i][1] + loop[j][1]) / 2))
            d = (mid - c2).normalized() * sign
            face_out(bm, [a[i], a[j], b[j], b[i]], Vector((0, -d.x, d.y)))
        rig.put(bm, mat, smooth_angle=40)
    em = edge_mat or frame_mat
    for s_ in (1, -1):                           # a moulding hides the corner where each side meets the band
        pts = [V(s_ * half_w, f, z) for f, z in prof]
        rig.sweep(pts, circle_sec(0.022, 6), em, closed=True)


def panel_moulding(rig, half_w, path2d, mat, r=0.016, out=0.004):
    for s in (1, -1):
        pts = [V(s * (half_w + out), f, z) for f, z in path2d]
        sec = [(u, v) for u, v in half_round(r, 5)]
        rig.sweep(pts, [(v * s, u) for u, v in sec], mat, up=Vector((1, 0, 0)), closed=True)


def seat_cushion(rig, c, size, mat="Velvet"):
    rig.box(c, size, mat, bev=min(size) * 0.3, seg=3)


# ---------------------------------------------------------------- the four rigs
def team_hitches(rig, splinter_f, pairs, single=False, lead_gap=2.0):
    """Horse origins (nose +f): the wheelers' traces end 1.5 m behind their origin, the leaders' at the pole head."""
    if single:
        rig.hitches.append((V(0, splinter_f + 1.5, 0), "wheeler"))
        return
    wf = splinter_f + 1.5
    for s in (-1, 1):
        rig.hitches.append((V(s * 0.5, wf, 0), "wheeler"))
    for p in range(1, pairs):
        lf = wf + 0.9 + lead_gap * p
        for s in (-1, 1):
            rig.hitches.append((V(s * 0.5, lf, 0), "lead"))


def pole(rig, f0, z0, f1, z1, mat, cap_mat):
    rig.cyl(V(0, f0, z0), V(0, f1, z1), 0.05, 0.035, seg=10, mat=mat)
    rig.lathe([(0.0, 0.0), (0.05, 0.0), (0.06, 0.06), (0.04, 0.12), (0.0, 0.16)], 10, Matrix.Translation(V(0, f1, z1)) @ Matrix.Rotation(math.radians(-90), 4, "X"), cap_mat)
    for s in (-1, 1):                               # pole chains / pole straps to the collars
        rig.sweep([V(0, f1 - 0.05, z1), V(s * 0.32, f1 + 0.05, z1 + 0.22)], circle_sec(0.012, 5), cap_mat)


def splinter_bar(rig, f, z, half, wood, metal, whipple=True):
    rig.cyl(V(-half, f, z), V(half, f, z), 0.04, seg=10, mat=wood)
    if whipple:
        for s in (-1, 1):
            x = s * 0.5
            rig.cyl(V(x - 0.36, f + 0.03, z), V(x + 0.36, f + 0.03, z), 0.025, 0.025, seg=8, mat=wood)
            for e in (-1, 1):
                rig.lathe([(0.03, -0.015), (0.03, 0.015), (0.022, 0.015), (0.022, -0.015)], 10, Matrix.Translation(V(x + e * 0.36, f + 0.03, z)) @ Matrix.Rotation(math.radians(90), 4, "Y"), metal, closed=True)


def build_buckboard():
    rig = Rig("visitor_common_single")
    wood, metal = "WoodWeathered", "Iron"
    Rf, Rr = 0.5, 0.62
    ff, fr = 0.75, -1.05          # axle positions (f)
    half = 0.72
    wheel(rig, half, ff, Rf, 12, wood)
    wheel(rig, -half, ff, Rf, 12, wood)
    wheel(rig, half, fr, Rr, 14, wood)
    wheel(rig, -half, fr, Rr, 14, wood)
    axle(rig, ff, Rf, half - 0.06, bed=wood)
    axle(rig, fr, Rr, half - 0.06, bed=wood)
    deck = 0.86
    for i in range(7):                             # springy long boards, gaps between, slightly sagging
        x = -0.48 + i * 0.16
        pts = [V(x, -1.55 + t * 3.0 / 8, deck - 0.03 * math.sin(math.pi * t / 8)) for t in range(9)]
        rig.sweep(pts, rect_sec(0.14, 0.028, 0.004), wood, up=Vector((0, 0, 1)))
    for f in (-1.5, 1.3):
        rig.box(V(0, f, deck - 0.05), (1.2, 0.09, 0.07), wood, bev=0.01)
    for s in (-1, 1):                              # iron side rails + stake pockets
        rig.sweep([V(s * 0.6, -1.5, deck + 0.02), V(s * 0.6, -1.5, deck + 0.2), V(s * 0.6, 0.5, deck + 0.2), V(s * 0.6, 0.5, deck + 0.02)], circle_sec(0.013, 6), metal, caps=True)
        for f in (-1.0, -0.4, 0.2):
            rig.cyl(V(s * 0.6, f, deck), V(s * 0.6, f, deck + 0.2), 0.011, seg=6, mat=metal)
    # spring seat: two elliptic springs, a box seat with a curved back and a leather cushion
    for s in (-1, 1):
        elliptic_spring(rig, s * 0.42, 0.55, deck + 0.12, 0.46, gap=0.14, leaves=3, along="f")
    rig.box(V(0, 0.55, deck + 0.29), (1.12, 0.52, 0.08), wood, bev=0.012)
    seat_cushion(rig, V(0, 0.55, deck + 0.37), (1.02, 0.44, 0.08), "Leather")
    back = [V(-0.56 + 1.12 * t / 10, 0.33 + 0.06 * math.sin(math.pi * t / 10), deck + 0.55) for t in range(11)]
    rig.sweep(back, rect_sec(0.035, 0.34, 0.01), wood, up=Vector((0, 0, 1)))
    for s in (-1, 1):
        rig.sweep([V(s * 0.56, 0.75, deck + 0.33), V(s * 0.58, 0.55, deck + 0.52), V(s * 0.56, 0.33, deck + 0.72)], circle_sec(0.014, 6), metal)
    rig.box(V(0, 1.42, deck + 0.12), (1.1, 0.04, 0.32), wood, bev=0.01, rot=Matrix.Rotation(math.radians(-18), 3, "X"))   # dash board
    # the load: tarped crate, sacks, a coil of rope, a shovel
    rig.box(V(-0.12, -0.8, deck + 0.24), (0.7, 0.6, 0.42), wood, bev=0.02)
    tarp = [(-1.15, deck + 0.03), (-1.13, deck + 0.4), (-0.95, deck + 0.52), (-0.6, deck + 0.53), (-0.46, deck + 0.4), (-0.44, deck + 0.03)]
    rig.prism([(f, z) for f, z in tarp], -0.5, 0.28, "Canvas", bev=0.06, seg=3)
    for k, (x, f) in enumerate(((0.34, -0.3), (0.38, -0.85), (0.3, -1.3))):
        seat_cushion(rig, V(x, f, deck + 0.17), (0.38, 0.5, 0.3), "Canvas")
        rig.sweep([V(x - 0.2, f + 0.18, deck + 0.29), V(x, f + 0.2, deck + 0.34), V(x + 0.2, f + 0.18, deck + 0.29)], circle_sec(0.01, 5), "Rope")
    coil = Matrix.Translation(V(-0.32, -0.1, deck + 0.06))
    rig.lathe([(0.16, -0.035), (0.2, -0.035), (0.2, 0.035), (0.16, 0.035)], 24, coil, "Rope", closed=True)
    rig.cyl(V(0.1, -1.45, deck + 0.08), V(-0.25, 0.1, deck + 0.38), 0.016, seg=6, mat=wood)
    rig.box(V(-0.27, 0.2, deck + 0.4), (0.2, 0.05, 0.26), metal, bev=0.01, rot=Matrix.Rotation(math.radians(-60), 3, "X"))
    # shafts to the horse's collar
    bar_f = 1.3
    splinter_bar(rig, bar_f, deck - 0.16, 0.6, wood, metal, whipple=False)
    for s in (-1, 1):
        pts = [V(s * 0.55, bar_f - 0.25, deck - 0.12), V(s * 0.56, bar_f + 0.8, deck - 0.05), V(s * 0.45, bar_f + 2.3, 1.08), V(s * 0.38, bar_f + 2.95, 1.12)]
        rig.sweep(catmull(pts, 5, closed=False), circle_sec(0.034, 8), wood, scales=None)
        rig.lathe([(0.0, 0.0), (0.03, 0.0), (0.03, 0.05), (0.0, 0.07)], 8, Matrix.Translation(V(s * 0.38, bar_f + 2.95, 1.12)) @ Matrix.Rotation(math.radians(-90), 4, "X"), metal)
    rig.hitches.append((V(0, bar_f + 1.5, 0), "shaft"))
    shadow_blob(rig, -0.15, 0.95, 1.9)
    return rig


def build_mud_wagon():
    rig = Rig("visitor_common_pair")
    wood, metal = "WoodWeathered", "Iron"
    Rf, Rr = 0.55, 0.72
    ff, fr = 1.0, -1.15
    half = 0.8
    for x in (half, -half):
        wheel(rig, x, ff, Rf, 12, wood)
        wheel(rig, x, fr, Rr, 14, wood)
    axle(rig, ff, Rf, half - 0.06, bed=wood)
    axle(rig, fr, Rr, half - 0.06, bed=wood)
    rig.box(V(0, -0.05, 0.66), (0.12, 2.4, 0.1), wood, bev=0.015)                  # reach / perch
    # thoroughbrace standards and the leather braces the body hangs on
    zb = 0.95
    for s in (-1, 1):
        for f, R in ((ff, Rf), (fr, Rr)):
            rig.sweep([V(s * 0.55, f, R + 0.1), V(s * 0.55, f + (0.15 if f > 0 else -0.15), R + 0.45)], rect_sec(0.05, 0.04, 0.008), metal)
        rig.sweep(catmull([(s * 0.55, ff + 0.15, Rf + 0.45), (s * 0.55, 0.6, zb - 0.06), (s * 0.55, -0.6, zb - 0.06), (s * 0.55, fr - 0.15, Rr + 0.45)], 5, closed=False)
                  and [V(p[0], p[1], p[2]) for p in catmull([(s * 0.55, ff + 0.15, Rf + 0.45), (s * 0.55, 0.6, zb - 0.06), (s * 0.55, -0.6, zb - 0.06), (s * 0.55, fr - 0.15, Rr + 0.45)], 5, closed=False)],
                  rect_sec(0.085, 0.022, 0.005), "Leather", up=Vector((1, 0, 0)))
    # the body: a light box with flared top rail, open sides under a flat roof on posts
    hw = 0.66
    prof = [(-1.05, zb), (0.95, zb), (1.02, zb + 0.08), (1.0, zb + 0.55), (-1.08, zb + 0.55), (-1.1, zb + 0.08)]
    rig.prism(prof, -hw, hw, wood, bev=0.02)
    rig.box(V(0, -0.05, zb + 0.6), (hw * 2 - 0.08, 1.9, 0.06), wood)                 # floor inside (seats on it)
    for f in (-0.75, 0.05, 0.8):
        seat_cushion(rig, V(0, f, zb + 0.8), (hw * 2 - 0.2, 0.36, 0.1), "Leather")
        rig.box(V(0, f, zb + 0.68), (hw * 2 - 0.2, 0.3, 0.2), wood)
    for s in (-1, 1):
        rig.sweep([V(s * (hw + 0.01), -1.08, zb + 0.56), V(s * (hw + 0.01), 1.0, zb + 0.56)], rect_sec(0.04, 0.05, 0.008), wood)
        rig.sweep([V(s * (hw + 0.012), -1.0, zb + 0.28), V(s * (hw + 0.012), 0.95, zb + 0.28)], half_round(0.012), "Iron", up=Vector((1, 0, 0)))
    roof_z = zb + 1.55
    for s in (-1, 1):
        for f in (-1.0, -0.05, 0.92):
            rig.box(V(s * (hw - 0.02), f, (zb + 0.55 + roof_z) / 2), (0.05, 0.05, roof_z - zb - 0.55), wood, bev=0.008)
    roof = [(-1.18, roof_z), (1.06, roof_z), (1.1, roof_z + 0.06), (0.0, roof_z + 0.12), (-1.22, roof_z + 0.06)]
    rig.prism(roof, -hw - 0.06, hw + 0.06, "Canvas", bev=0.02)
    for s in (-1, 1):                               # rolled-up side curtains + their straps
        rig.cyl(V(s * (hw + 0.03), -1.0, roof_z - 0.1), V(s * (hw + 0.03), 0.92, roof_z - 0.1), 0.065, seg=10, mat="Canvas")
        for f in (-0.6, 0.45):
            rig.lathe([(0.072, -0.02), (0.072, 0.02), (0.06, 0.02), (0.06, -0.02)], 10, Matrix.Translation(V(s * (hw + 0.03), f, roof_z - 0.1)) @ Matrix.Rotation(math.radians(90), 4, "X"), "Leather", closed=True)
    # a canvas curtain let down on the back
    rig.box(V(0, -1.11, zb + 1.05), (hw * 2 - 0.06, 0.02, 0.95), "Canvas", bev=0.008)
    # roof rail with luggage
    for s in (-1, 1):
        rig.sweep([V(s * (hw - 0.02), -1.1, roof_z + 0.08), V(s * (hw - 0.02), 0.95, roof_z + 0.08)], circle_sec(0.012, 6), metal)
    rig.box(V(0.1, -0.5, roof_z + 0.24), (0.62, 0.5, 0.3), "Leather", bev=0.04)
    rig.box(V(-0.25, 0.2, roof_z + 0.2), (0.5, 0.42, 0.24), wood, bev=0.02)
    # driver's box, footboard, brake lever, leather boot at the back
    rig.box(V(0, 1.12, zb + 0.75), (hw * 2 - 0.1, 0.4, 0.12), wood, bev=0.015)
    seat_cushion(rig, V(0, 1.12, zb + 0.85), (hw * 2 - 0.2, 0.34, 0.07), "Leather")
    rig.box(V(0, 1.45, zb + 0.35), (hw * 2 - 0.1, 0.36, 0.035), wood, rot=Matrix.Rotation(math.radians(30), 3, "X"))
    rig.sweep([V(hw + 0.05, 0.85, zb + 0.1), V(hw + 0.08, 1.0, zb + 0.95)], circle_sec(0.018, 6), metal)
    rig.box(V(0, -1.38, zb + 0.32), (hw * 2 - 0.1, 0.5, 0.55), "Leather", bev=0.06)
    lantern(rig, V(hw + 0.06, 1.25, zb + 0.75), 0.36, "Iron", arm_from=V(hw, 1.25, zb + 0.6))
    # pole for the pair
    splinter_bar(rig, ff + 0.45, 0.78, 0.95, wood, metal)
    pole(rig, ff - 0.1, 0.72, ff + 2.95, 1.05, wood, metal)
    team_hitches(rig, ff + 0.48, 1)
    shadow_blob(rig, -0.1, 1.05, 1.9)
    return rig


def berline_profile(L, H, z0, front_bow=0.18, rear_bow=0.22, belly=0.32):
    """Side outline of a state-coach body (ccw from +x): flat roof, bowed front/rear, deep curved underbody."""
    f0, f1 = -L / 2, L / 2
    ctrl = [(f1 - 0.25, z0 + 0.05), (f1 + front_bow * 0.4, z0 + H * 0.28), (f1 + front_bow, z0 + H * 0.62), (f1 + front_bow * 0.6, z0 + H * 0.95),
            (f1 - 0.1, z0 + H), (f0 + 0.1, z0 + H), (f0 - rear_bow * 0.6, z0 + H * 0.95), (f0 - rear_bow, z0 + H * 0.6),
            (f0 - rear_bow * 0.5, z0 + H * 0.25), (f0 + 0.3, z0 + 0.02), (0.0, z0 - belly * 0.25)]
    return catmull(ctrl, 6, closed=True)


def build_state_coach():
    rig = Rig("visitor_royal_coach")
    lac, gold, red = "Lacquer", "Brass", "RedPaint"
    Rf, Rr = 0.6, 0.86
    ff, fr = 1.3, -1.25
    half = 0.86
    for x in (half, -half):
        wheel(rig, x, ff, Rf, 12, red, tyre="Iron", hub_mat=red)
        wheel(rig, x, fr, Rr, 14, red, tyre="Iron", hub_mat=red)
    axle(rig, ff, Rf, half - 0.07, mat="Iron", bed=lac)
    axle(rig, fr, Rr, half - 0.07, mat="Iron", bed=lac)
    # perch (twin, curved, lacquered with brass), C-springs at the back, elliptic in front, leather braces to the body
    for s in (-1, 1):
        pts = [V(s * 0.3, fr - 0.45, Rr + 0.1), V(s * 0.3, -0.4, 0.62), V(s * 0.3, 0.6, 0.6), V(s * 0.3, ff + 0.1, Rf + 0.12)]
        rig.sweep(catmull(pts, 5, closed=False) and [V(*p) for p in catmull([(s * 0.3, fr - 0.45, Rr + 0.1), (s * 0.3, -0.4, 0.62), (s * 0.3, 0.6, 0.6), (s * 0.3, ff + 0.1, Rf + 0.12)], 5, closed=False)],
                  rect_sec(0.07, 0.09, 0.015), lac)
    zb, H, L = 0.95, 1.55, 1.85
    body_z = zb
    for s in (-1, 1):
        c_spring(rig, s * 0.42, fr - 0.4, Rr + 0.05, 0.75, 0.7, mat="Iron", strap="BlackLeather", tip_to=V(s * 0.42, -L / 2 + 0.1, body_z + 0.05))
        elliptic_spring(rig, s * 0.42, ff, Rf + 0.2, 0.75, gap=0.18, leaves=4, mat="Iron", along="f")
        rig.sweep([V(s * 0.42, ff, Rf + 0.29), V(s * 0.42, L / 2 - 0.1, body_z + 0.04)], rect_sec(0.07, 0.016), "BlackLeather", up=Vector((1, 0, 0)))
    prof = berline_profile(L, H, body_z)
    hw = 0.74
    wins = [(-0.8, -0.32, body_z + 0.78, body_z + 1.38, 0.06), (-0.22, 0.22, body_z + 0.76, body_z + 1.4, 0.05), (0.32, 0.8, body_z + 0.78, body_z + 1.38, 0.06)]
    coach_body(rig, prof, hw, 0.05, wins, lac, gold)
    # mouldings: belt line, lower panels, door
    panel_moulding(rig, hw, rrect(-0.92, 0.92, body_z + 0.2, body_z + 0.66, 0.12), gold)
    panel_moulding(rig, hw, rrect(-0.27, 0.27, body_z + 0.12, body_z + 1.46, 0.06), gold)
    for s in (-1, 1):
        rig.sweep([V(s * (hw + 0.006), -1.0, body_z + 0.72), V(s * (hw + 0.006), 1.0, body_z + 0.72)], [(v * s, u) for u, v in half_round(0.02, 5)], gold, up=Vector((1, 0, 0)))
        rosette(rig, V(s * (hw + 0.01), 0.0, body_z + 0.42), Vector((s, 0, 0)), 0.12, gold)
        crest = V(s * (hw + 0.012), 0.0, body_z + 0.42)
        crown(rig, crest + Vector((s * 0.03, 0, 0.12)), 0.05, gold, "RedPaint")
        rig.cyl(V(s * (hw + 0.02), 0.2, body_z + 0.75), V(s * (hw + 0.06), 0.2, body_z + 0.75), 0.018, seg=8, mat=gold)   # door handle
        for f in (-0.6, 0.6):
            scroll(rig, V(s * (hw + 0.012), f, body_z + 0.28), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.26, gold, tube=0.016, mirror=(f > 0) ^ (s < 0))
    # roof: brass rail on turned posts, corner urns, the crown
    top = body_z + H
    for s in (-1, 1):
        rig.sweep([V(s * (hw - 0.08), -0.85, top + 0.16), V(s * (hw - 0.08), 0.85, top + 0.16)], circle_sec(0.016, 6), gold)
        for k in range(7):
            f = -0.85 + k * 1.7 / 6
            rig.lathe([(0.0, 0), (0.018, 0), (0.012, 0.06), (0.018, 0.12), (0.0, 0.16)], 8, Matrix.Translation(V(s * (hw - 0.08), f, top)), gold)
    for f in (-0.85, 0.85):
        rig.sweep([V(-(hw - 0.08), f, top + 0.16), V(hw - 0.08, f, top + 0.16)], circle_sec(0.016, 6), gold)
        for s in (-1, 1):
            finial(rig, V(s * (hw - 0.08), f, top + 0.02), 0.32, gold, "urn")
    crown(rig, V(0, 0, top + 0.02), 0.2, gold, "RedPaint")
    # interior: velvet seats + quilting visible through the glass
    for f in (-0.55, 0.55):
        seat_cushion(rig, V(0, f, body_z + 0.5), (hw * 2 - 0.16, 0.45, 0.14), "Velvet")
        rig.box(V(0, f + (-0.2 if f < 0 else 0.2), body_z + 0.85), (hw * 2 - 0.16, 0.1, 0.6), "Velvet", bev=0.04)
    # coachman's box with hammercloth (velvet, gilt fringe), footboard; footmen's platform behind
    bx = L / 2 + 0.55
    rig.box(V(0, bx, body_z + 1.05), (1.05, 0.55, 0.16), lac, bev=0.02)
    seat_cushion(rig, V(0, bx, body_z + 1.17), (0.95, 0.48, 0.08), "Velvet")
    ham = [(bx - 0.32, body_z + 1.12), (bx + 0.32, body_z + 1.12), (bx + 0.4, body_z + 0.55), (bx - 0.25, body_z + 0.55)]
    rig.prism(ham, -0.6, 0.6, "Velvet", bev=0.03)
    for s in (-1, 1):
        rig.sweep([V(s * 0.61, bx - 0.25, body_z + 0.56), V(s * 0.61, bx + 0.4, body_z + 0.56)], rect_sec(0.02, 0.07), gold, up=Vector((1, 0, 0)))
    rig.sweep([V(-0.6, bx + 0.41, body_z + 0.56), V(0.6, bx + 0.41, body_z + 0.56)], rect_sec(0.02, 0.07), gold, up=Vector((0, 1, 0)))
    for s in (-1, 1):
        rig.sweep([V(s * 0.45, L / 2 - 0.05, body_z + 0.4), V(s * 0.45, bx - 0.1, body_z + 0.98)], rect_sec(0.04, 0.03, 0.006), "Iron")
    rig.box(V(0, bx + 0.55, body_z + 0.45), (1.0, 0.35, 0.035), lac, rot=Matrix.Rotation(math.radians(35), 3, "X"))
    for s in (-1, 1):
        lantern(rig, V(s * 0.62, L / 2 + 0.12, body_z + 1.15), 0.42, gold, arm_from=V(s * 0.55, L / 2 + 0.05, body_z + 1.05))
    pf = -L / 2 - 0.45
    rig.box(V(0, pf, body_z + 0.15), (1.1, 0.42, 0.05), lac, bev=0.01)
    for s in (-1, 1):
        rig.sweep([V(s * 0.52, pf - 0.18, body_z + 0.15), V(s * 0.52, pf - 0.18, body_z + 1.25), V(s * 0.45, -L / 2 - 0.15, body_z + 1.4)], circle_sec(0.016, 6), gold)
    rig.sweep([V(-0.52, pf - 0.18, body_z + 1.25), V(0.52, pf - 0.18, body_z + 1.25)], circle_sec(0.016, 6), gold)
    # door steps (folded) and the pole for a team of four
    for s in (-1, 1):
        rig.box(V(s * (hw + 0.12), 0.0, body_z - 0.12), (0.22, 0.4, 0.03), "Iron", bev=0.005)
    splinter_bar(rig, ff + 0.5, Rf + 0.18, 1.0, lac, gold)
    pole(rig, ff, Rf + 0.1, ff + 3.1, 1.08, lac, gold)
    team_hitches(rig, ff + 0.52, 2)
    shadow_blob(rig, 0.0, 1.15, 2.4)
    return rig


def build_palace():
    rig = Rig("visitor_royal_palace")
    gilt = "Gilt"
    Rf, Rr = 0.88, 1.12
    ff, fr = 1.95, -1.9
    half = 1.55
    for x in (half, -half):
        wheel(rig, x, ff, Rf, 14, gilt, tyre="Iron", hub_mat=gilt, width=0.1)
        wheel(rig, x, fr, Rr, 16, gilt, tyre="Iron", hub_mat=gilt, width=0.11)
    axle(rig, ff, Rf, half - 0.08, mat="Iron", bed=gilt)
    axle(rig, fr, Rr, half - 0.08, mat="Iron", bed=gilt)
    zb, H, L = 1.25, 2.3, 3.1
    for s in (-1, 1):                               # carved perch: twin gilded beams with scrolls riding on them
        pts = [(s * 0.45, fr - 0.6, Rr + 0.15), (s * 0.45, -0.8, 0.85), (s * 0.45, 0.8, 0.82), (s * 0.45, ff + 0.15, Rf + 0.18)]
        rig.sweep([V(*p) for p in catmull(pts, 6, closed=False)], rect_sec(0.1, 0.13, 0.025), gilt)
        for f in (-0.9, 0.0, 0.9):
            scroll(rig, V(s * 0.52, f, 0.95), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.4, gilt, tube=0.03, mirror=f > 0)
        c_spring(rig, s * 0.6, fr - 0.55, Rr + 0.1, 1.15, 0.9, mat=gilt, strap="Velvet", tip_to=V(s * 0.6, -L / 2 + 0.2, zb + 0.05))
        c_spring(rig, s * 0.6, ff + 0.55, Rf + 0.15, 1.0, -0.9, mat=gilt, strap="Velvet", tip_to=V(s * 0.6, L / 2 - 0.2, zb + 0.05))
    prof = berline_profile(L, H, zb, front_bow=0.3, rear_bow=0.34, belly=0.45)
    hw = 1.12
    wins = [(-1.2, -0.45, zb + 1.05, zb + 2.0, 0.1), (-0.32, 0.32, zb + 0.95, zb + 2.05, 0.08), (0.45, 1.2, zb + 1.05, zb + 2.0, 0.1)]
    coach_body(rig, prof, hw, 0.06, wins, "RedPaint", gilt, bev=0.05)
    # gilt everywhere it counts: frames around panels, belt, a carved crest on each door, scrolls on every panel corner
    panel_moulding(rig, hw, rrect(-1.42, 1.42, zb + 0.25, zb + 0.88, 0.16), gilt, r=0.028)
    panel_moulding(rig, hw, rrect(-0.4, 0.4, zb + 0.12, zb + 2.15, 0.1), gilt, r=0.03)
    for s in (-1, 1):
        rig.sweep([V(s * (hw + 0.008), -1.5, zb + 0.95), V(s * (hw + 0.008), 1.5, zb + 0.95)], [(v * s, u) for u, v in half_round(0.035, 6)], gilt, up=Vector((1, 0, 0)))
        rig.sweep([V(s * (hw + 0.008), -1.45, zb + 2.22), V(s * (hw + 0.008), 1.45, zb + 2.22)], [(v * s, u) for u, v in half_round(0.04, 6)], gilt, up=Vector((1, 0, 0)))
        rosette(rig, V(s * (hw + 0.012), 0.0, zb + 0.55), Vector((s, 0, 0)), 0.2, gilt, petals=12)
        crown(rig, V(s * (hw + 0.06), 0.0, zb + 0.72), 0.09, gilt, "Velvet")
        rig.cyl(V(s * (hw + 0.02), 0.28, zb + 1.0), V(s * (hw + 0.08), 0.28, zb + 1.0), 0.024, seg=8, mat=gilt)
        for f in (-1.05, -0.7, 0.7, 1.05):
            scroll(rig, V(s * (hw + 0.015), f, zb + 0.4), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.34, gilt, tube=0.024, mirror=(f > 0) ^ (s < 0))
        for f in (-1.55, 1.55):                     # big carved corner brackets curling off the body
            scroll(rig, V(s * (hw - 0.1), f, zb + 0.2), Vector((0, 1 if f > 0 else -1, 0)), Vector((0, 0, 1)), 0.75, gilt, tube=0.055, mirror=False)
        for f in (-0.42, 0.42):                     # carved pilasters beside the door
            rig.lathe([(0.0, 0), (0.07, 0), (0.07, 0.05), (0.05, 0.08), (0.05, 1.02), (0.07, 1.06), (0.08, 1.12), (0.0, 1.14)], 12,
                      Matrix.Translation(V(s * (hw + 0.01), f, zb + 0.98)), gilt, mod=lambda ph: 1.0 + 0.1 * math.cos(10 * ph))
    # interior: velvet seats, quilted back, gilt ceiling rose
    for f in (-0.85, 0.85):
        seat_cushion(rig, V(0, f, zb + 0.6), (hw * 2 - 0.2, 0.62, 0.18), "Velvet")
        rig.box(V(0, f + (-0.25 if f < 0 else 0.25), zb + 1.15), (hw * 2 - 0.2, 0.12, 0.9), "Velvet", bev=0.05)
    top = zb + H
    # gallery tier: arcaded pavilion, columns, cornice
    g0, gh, gw, gl = top + 0.05, 1.6, 0.85, 1.25
    def arch_loop(c, half, z0, zs):
        return [(c - half, z0), (c + half, z0)] + [(c + half * math.cos(math.pi * k / 8), zs + half * math.sin(math.pi * k / 8)) for k in range(9)][::1][1:]

    def arcade_wall(M, length, height, arches, thick, mat, inner_mat, frame):
        """A flat wall in the plane of M (u = along, v = up, its +Z = outward) with arched openings, lined, framed reveals, glazed."""
        from mathutils.geometry import tessellate_polygon
        outline = [(-length / 2, 0.0), (length / 2, 0.0), (length / 2, height), (-length / 2, height)]
        holes = [arch_loop(c, w, 0.25, 0.95) for c, w in arches]
        for depth, m, sgn in ((0.0, mat, 1.0), (-thick, inner_mat, -1.0)):
            polys = [[M @ Vector((u, v, depth)) for u, v in loop] for loop in [outline] + holes]
            flat = [q for loop in polys for q in loop]
            bm = bmesh.new()
            vs = [bm.verts.new(q) for q in flat]
            want = (M.to_3x3() @ Vector((0, 0, sgn)))
            for t in tessellate_polygon(polys):
                f = bm.faces.new([vs[t[0]], vs[t[1]], vs[t[2]]])
                f.normal_update()
                if f.normal.dot(want) < 0:
                    f.normal_flip()
            rig.put(bm, m, smooth_angle=10)
        for hole in holes:
            bm = bmesh.new()
            A = [bm.verts.new(M @ Vector((u, v, 0.0))) for u, v in hole]
            B = [bm.verts.new(M @ Vector((u, v, -thick))) for u, v in hole]
            for i in range(len(hole)):
                bm.faces.new([A[i], A[(i + 1) % len(hole)], B[(i + 1) % len(hole)], B[i]])
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            for f in bm.faces:
                f.normal_flip()
            rig.put(bm, frame, smooth_angle=50)
            bm = bmesh.new()
            bm.faces.new([bm.verts.new(M @ Vector((u, v, -thick * 0.5))) for u, v in hole])
            rig.put(bm, "Glass")

    base = V(0, 0, g0)
    for s in (-1, 1):                                # the long walls (3 arches) and the end walls (2 arches)
        u = Vector((0, -1, 0)) if s > 0 else Vector((0, 1, 0))
        M = Matrix.Translation(base + Vector((s * gw, 0, 0))) @ Matrix(((u.x, 0, s, 0), (u.y, 0, 0, 0), (u.z, 1, 0, 0), (0, 0, 0, 1)))
        arcade_wall(M, 2 * gl, gh, [(f, 0.26) for f in (-0.75, 0.0, 0.75)], 0.08, "RedPaint", "Velvet", gilt)
        u = Vector((1, 0, 0)) if s > 0 else Vector((-1, 0, 0))
        n_ = Vector((0, -s, 0))                      # +f end is Blender -y
        M = Matrix.Translation(base + Vector((0, -s * gl, 0))) @ Matrix(((u.x, 0, n_.x, 0), (u.y, 0, n_.y, 0), (u.z, 1, n_.z, 0), (0, 0, 0, 1)))
        arcade_wall(M, 2 * gw, gh, [(x, 0.22) for x in (-0.45, 0.45)], 0.08, "RedPaint", "Velvet", gilt)
    rig.box(V(0, 0, g0 + gh - 0.04), (2 * gw, 2 * gl, 0.08), "RedPaint")
    rig.box(V(0, 0, g0 + 0.03), (2 * gw, 2 * gl, 0.06), "Velvet")
    for s in (-1, 1):
        for f in (-0.75, 0.0, 0.75):
            arc = [V(s * (gw + 0.01), f + 0.3 * math.cos(math.pi * (1 - k / 10)), g0 + 0.95 + 0.3 * math.sin(math.pi * (1 - k / 10))) for k in range(11)]
            rig.sweep(arc, [(v * s, u) for u, v in half_round(0.03, 5)], gilt, up=Vector((1, 0, 0)))
            rosette(rig, V(s * (gw + 0.012), f, g0 + 1.45), Vector((s, 0, 0)), 0.08, gilt)
        for f in (-1.2, -0.38, 0.38, 1.2):          # twisted columns between the arches
            rig.lathe([(0.0, 0), (0.1, 0), (0.1, 0.08), (0.07, 0.12)] + [(0.065, 0.12 + 1.3 * k / 10) for k in range(1, 10)] + [(0.08, 1.45), (0.11, 1.52), (0.11, 1.6), (0.0, 1.6)], 10,
                      Matrix.Translation(V(s * (gw + 0.07), f, g0)), gilt, mod=lambda ph: 1.0 + 0.18 * math.cos(6 * ph))
    for f in (-1.2, 1.2):
        for x in (-0.45, 0.45):
            rig.lathe([(0.0, 0), (0.1, 0), (0.1, 0.08), (0.07, 0.12), (0.065, 1.4), (0.08, 1.45), (0.11, 1.52), (0.11, 1.6), (0.0, 1.6)], 10,
                      Matrix.Translation(V(x, f + (0.07 if f > 0 else -0.07), g0)), gilt, mod=lambda ph: 1.0 + 0.18 * math.cos(6 * ph))
    # cornices (profile swept round the rectangle) at the body top and gallery top
    def cornice(z, hx, hf, depth, mat=gilt):
        path = [V(x, f, z) for f, x in [(-hf, -hx), (-hf, hx), (hf, hx), (hf, -hx)]]
        sec = [(0.0, 0.0), (depth * 0.4, 0.0), (depth * 0.5, depth * 0.25), (depth, depth * 0.45), (depth, depth * 0.7), (depth * 0.7, depth * 0.8), (0.0, depth * 0.8)]
        pts = []
        for i in range(4):
            a, b = path[i], path[(i + 1) % 4]
            for k in range(2):
                pts.append(a.lerp(b, k * 0.5))
        rig.sweep(pts, [(-u, v) for u, v in sec], mat, up=Vector((0, 0, 1)), closed=True, smooth_angle=30)
    cornice(top - 0.08, hw + 0.04, L / 2 + 0.12, 0.2)
    cornice(g0 + gh - 0.04, gw + 0.12, gl + 0.12, 0.24)
    # balustrade on the body roof round the gallery
    for s in (-1, 1):
        for k in range(13):
            f = -1.45 + k * 2.9 / 12
            rig.lathe([(0.0, 0), (0.045, 0), (0.03, 0.05), (0.055, 0.14), (0.025, 0.24), (0.04, 0.28), (0.0, 0.3)], 8, Matrix.Translation(V(s * (hw - 0.05), f, top + 0.1)), gilt)
        rig.box(V(s * (hw - 0.05), 0, top + 0.42), (0.1, 3.0, 0.05), gilt, bev=0.01)
    # lantern tier, dome with ribs, the crown
    l0 = g0 + gh + 0.15
    rig.lathe([(0.0, 0), (0.72, 0), (0.72, 0.08), (0.62, 0.12), (0.62, 0.85), (0.7, 0.9), (0.7, 0.98), (0.0, 0.98)], 8,
              Matrix.Translation(V(0, 0, l0)) @ Matrix.Rotation(math.pi / 8, 4, "Z"), "RedPaint", smooth_angle=20)
    for k in range(8):
        a = TAU * k / 8 + math.pi / 8
        p = V(0, 0, l0) + Vector((0.64 * math.cos(a + math.pi / 8), 0.64 * math.sin(a + math.pi / 8), 0.15))
        rig.lathe([(0.0, 0), (0.05, 0), (0.04, 0.7), (0.06, 0.74), (0.0, 0.75)], 8, Matrix.Translation(p), gilt)
        w = V(0, 0, l0) + Vector((0.6 * math.cos(a + 2 * math.pi / 8 - math.pi / 8 + math.pi / 8), 0.6 * math.sin(a + math.pi / 4), 0.48))
        rosette(rig, V(0, 0, l0) + Vector((0.64 * math.cos(a), 0.64 * math.sin(a), 0.5)), Vector((math.cos(a), math.sin(a), 0)), 0.13, gilt)
    d0 = l0 + 0.98
    dome = [(0.0, 0.0), (0.7, 0.0)] + [(0.7 * math.cos(math.pi / 2 * k / 10) * (1.0 + 0.08 * math.sin(math.pi * k / 10)), 1.1 * math.sin(math.pi / 2 * k / 10)) for k in range(1, 10)] + [(0.0, 1.1)]
    rig.lathe(dome, 32, Matrix.Translation(V(0, 0, d0)), gilt, mod=lambda ph: 1.0 + 0.03 * math.cos(16 * ph))
    for k in range(8):
        a = TAU * k / 8
        pts = [V(0, 0, d0) + Vector((0.72 * math.cos(math.pi / 2 * t / 10) * (1.0 + 0.08 * math.sin(math.pi * t / 10)) * math.cos(a), 0.72 * math.cos(math.pi / 2 * t / 10) * (1.0 + 0.08 * math.sin(math.pi * t / 10)) * math.sin(a), 1.12 * math.sin(math.pi / 2 * t / 10))) for t in range(11)]
        rig.sweep(pts, circle_sec(0.035, 6), gilt, scales=[1.0 - 0.6 * t / 10 for t in range(11)])
    crown(rig, V(0, 0, d0 + 1.08), 0.42, gilt, "Velvet")
    # spires on every corner of each tier
    for s in (-1, 1):
        for f in (-1, 1):
            finial(rig, V(s * (hw - 0.02), f * (L / 2 + 0.02), top + 0.05), 1.35, gilt, "spire")
            finial(rig, V(s * (gw + 0.07), f * (gl + 0.07), g0 + gh + 0.16), 1.05, gilt, "spire")
            finial(rig, V(s * 0.5, f * 0.5, l0 + 0.98), 0.55, gilt, "urn")
    for s in (-1, 1):                               # giant scrolls flying off the gallery roof corners
        for f in (-1, 1):
            scroll(rig, V(s * (gw + 0.05), f * (gl - 0.1), g0 + gh + 0.2), Vector((0, -f, 0)), Vector((0, 0, 1)), 0.6, gilt, tube=0.04)
    # coachman's throne-box, hammercloth with gilt fringe, the footmen's gilded stand
    bx = L / 2 + 0.75
    rig.box(V(0, bx, zb + 1.35), (1.3, 0.7, 0.2), gilt, bev=0.04)
    seat_cushion(rig, V(0, bx, zb + 1.5), (1.2, 0.62, 0.1), "Velvet")
    ham = [(bx - 0.4, zb + 1.42), (bx + 0.42, zb + 1.42), (bx + 0.55, zb + 0.6), (bx - 0.3, zb + 0.6)]
    rig.prism(ham, -0.75, 0.75, "Velvet", bev=0.04)
    for s in (-1, 1):
        rig.sweep([V(s * 0.77, bx - 0.3, zb + 0.62), V(s * 0.77, bx + 0.55, zb + 0.62)], rect_sec(0.025, 0.1), gilt, up=Vector((1, 0, 0)))
        scroll(rig, V(s * 0.77, bx + 0.05, zb + 1.0), Vector((0, -1, 0)), Vector((0, 0, 1)), 0.32, gilt, tube=0.022, mirror=s < 0)
        rig.sweep([V(s * 0.55, L / 2, zb + 0.5), V(s * 0.6, bx - 0.15, zb + 1.28)], rect_sec(0.06, 0.05, 0.01), gilt)
        lantern(rig, V(s * 0.82, L / 2 + 0.25, zb + 1.5), 0.6, gilt, arm_from=V(s * 0.7, L / 2 + 0.1, zb + 1.35))
    rig.sweep([V(-0.75, bx + 0.56, zb + 0.62), V(0.75, bx + 0.56, zb + 0.62)], rect_sec(0.025, 0.1), gilt, up=Vector((0, 1, 0)))
    rig.box(V(0, bx + 0.7, zb + 0.5), (1.2, 0.45, 0.04), gilt, rot=Matrix.Rotation(math.radians(35), 3, "X"))
    pf = -L / 2 - 0.65
    rig.box(V(0, pf, zb + 0.2), (1.4, 0.55, 0.07), gilt, bev=0.015)
    for s in (-1, 1):
        rig.sweep([V(s * 0.66, pf - 0.24, zb + 0.22), V(s * 0.66, pf - 0.24, zb + 1.6), V(s * 0.6, -L / 2 - 0.25, zb + 1.85)], circle_sec(0.024, 6), gilt)
    rig.sweep([V(-0.66, pf - 0.24, zb + 1.6), V(0.66, pf - 0.24, zb + 1.6)], circle_sec(0.024, 6), gilt)
    # red-carpet steps unfolded from the road-side (-x) door to the ground, and the runner (the palace parks right of the road)
    sx = -1.0
    steps = 4
    for k in range(steps):
        z = zb - 0.05 - k * (zb - 0.05) / steps
        x = hw + 0.18 + k * 0.32
        rig.box(V(sx * x, 0.0, z - 0.03), (0.34, 0.75, 0.06), "Carpet", bev=0.01)
        rig.box(V(sx * x, 0.0, z - 0.075), (0.36, 0.78, 0.03), gilt, bev=0.006)
    for e in (-1, 1):
        rig.sweep([V(sx * (hw + 0.1), e * 0.4, zb - 0.04), V(sx * (hw + 0.18 + steps * 0.32), e * 0.4, 0.0)], rect_sec(0.04, 0.06, 0.01), gilt, up=Vector((0, 1, 0)))
    run0 = hw + 0.18 + steps * 0.32
    rig.box(V(sx * (run0 + 1.0), 0.0, 0.008), (2.3, 0.85, 0.016), "Carpet")
    for e in (-1, 1):
        rig.box(V(sx * (run0 + 1.0), e * 0.43, 0.012), (2.3, 0.05, 0.02), gilt)
    # pole for the team
    splinter_bar(rig, ff + 0.55, Rf + 0.2, 1.05, gilt, gilt)
    pole(rig, ff, Rf + 0.1, ff + 3.15, 1.1, gilt, gilt)
    team_hitches(rig, ff + 0.57, 2)
    shadow_blob(rig, 0.0, 1.9, 3.2)
    return rig


BUILDERS = {"visitor_common_single": build_buckboard, "visitor_common_pair": build_mud_wagon,
            "visitor_royal_coach": build_state_coach, "visitor_royal_palace": build_palace}


# ---------------------------------------------------------------- finishing: AO + dust into COLOR_0, export
def bake_vertex_ao(obj):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    ground = bpy.data.objects.new("ground", bpy.data.meshes.new("ground"))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    bm.to_mesh(ground.data)
    bm.free()
    sc.collection.objects.link(ground)
    if not obj.data.color_attributes.get("Col"):
        obj.data.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    obj.data.color_attributes.active_color = obj.data.color_attributes["Col"]
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    bpy.data.objects.remove(ground, do_unlink=True)


def finish_colors(obj, top):
    """AO (baked) times a red-dust tint that rises from the ground; shadows and glass stay clean."""
    me = obj.data
    col = me.color_attributes.get("Col")
    if col is None:
        col = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
        for d in col.data:
            d.color = (1, 1, 1, 1)
    dust = Vector((0.80, 0.55, 0.42))
    clean = set()
    vmat = {}
    for poly in me.polygons:
        mname = obj.material_slots[poly.material_index].material.name
        for vi in poly.vertices:
            if mname in ("Shadow", "Glass"):
                clean.add(vi)
            vmat.setdefault(vi, mname)
    for vi, v in enumerate(me.vertices):
        if vi in clean:
            col.data[vi].color = (1, 1, 1, 1)
            continue
        c = col.data[vi].color
        ao = (0.5 + 0.5 * max(0.0, min(1.0, c[0] * 1.25))) if BAKE else 1.0
        k = max(0.0, min(1.0, 1.0 - v.co.z / 0.75)) * (0.5 if vmat.get(vi) not in ("Gilt", "Brass") else 0.3)
        tint = Vector((1, 1, 1)).lerp(dust, k)
        col.data[vi].color = (ao * tint.x, ao * tint.y, ao * tint.z, 1.0)


def dedupe_slots(obj):
    names = {}
    remap = {}
    mats = [s.material for s in obj.material_slots]
    keep = []
    for i, m in enumerate(mats):
        if m.name not in names:
            names[m.name] = len(keep)
            keep.append(m)
        remap[i] = names[m.name]
    idx = [remap[p.material_index] for p in obj.data.polygons]
    obj.data.materials.clear()                 # (this also drops every face's material index - reassign after)
    for m in keep:
        obj.data.materials.append(m)
    for p, i in zip(obj.data.polygons, idx):
        p.material_index = i


def export(rig, obj):
    for i, (p, kind) in enumerate(rig.hitches):
        e = bpy.data.objects.new(f"Hitch_{i}_{kind}", None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        e.parent = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for c in obj.children:
        c.select_set(True)
    path = os.path.join(OUT, rig.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_vertex_color="ACTIVE",
                              export_all_vertex_colors=False, export_normals=True, export_tangents=False, export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    lo = [min((obj.matrix_world @ v.co)[k] for v in obj.data.vertices) for k in range(3)]
    hi = [max((obj.matrix_world @ v.co)[k] for v in obj.data.vertices) for k in range(3)]
    print(f"RIG {rig.name} tris={tris} verts={len(obj.data.vertices)} size={os.path.getsize(path)//1024}KB "
          f"x {lo[0]:.2f}..{hi[0]:.2f} f {-hi[1]:.2f}..{-lo[1]:.2f} z {lo[2]:.3f}..{hi[2]:.2f} mats={[m.name for m in obj.data.materials]} hitches={len(rig.hitches)}")


def preview(obj, name):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 800, 600
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.9, 0.55, 0.35, 1)
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(55), 0, math.radians(-50))
    g = bpy.data.objects.new("g", bpy.data.meshes.new("g"))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=40)
    bm.to_mesh(g.data)
    bm.free()
    gm = bpy.data.materials.new("gm")
    gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.45, 0.22, 0.12, 1)
    g.data.materials.append(gm)
    sc.collection.objects.link(g)
    for m in obj.data.materials:          # show the vertex AO/dust in the review render
        if m.name in ("Shadow",):
            continue
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 1.0
        mix.inputs[6].default_value = bsdf.inputs["Base Color"].default_value
        nt.links.new(attr.outputs[0], mix.inputs[7])
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    shadow = bpy.data.materials.get("Shadow")
    if shadow:
        shadow.surface_render_method = "BLENDED" if hasattr(shadow, "surface_render_method") else shadow.blend_method
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 35
    lo = Vector([min(v.co[k] for v in obj.data.vertices) for k in range(3)])
    hi = Vector([max(v.co[k] for v in obj.data.vertices) for k in range(3)])
    ctr = (lo + hi) / 2
    size = (hi - lo).length
    views = [(35, 12, 1.15, ctr), (115, 8, 1.15, ctr), (230, 18, 1.2, ctr), (300, 30, 1.3, ctr)]
    for i, (az, el, dk, tgt) in enumerate(views):
        a, e = math.radians(az), math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        cam.location = tgt + d * size * dk
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(PREVIEW, f"{name}_{i}.png")
        bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in BUILDERS.items():
        if ONLY and name not in ONLY.split(","):
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        MATS.clear()
        mats_init()
        rig = fn()
        obj = rig.join()
        dedupe_slots(obj)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if BAKE:
            bake_vertex_ao(obj)
        finish_colors(obj, 0)
        export(rig, obj)
        if PREVIEW:
            os.makedirs(PREVIEW, exist_ok=True)
            preview(obj, name)


main()
