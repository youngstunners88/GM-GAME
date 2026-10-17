"""RICH & UTAH - the Armory's two shopkeepers (founder lock PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md).

Run headless:
  blender --background --python tools/ep2_blender/build_armory_folk.py -- --dir src/episode2/assets/town [--only rich|utah]

References (the founder's own art):
  Rich  src/assets/portals/companions/rich_the_claim_recorder.png - the gold-rush miner-cowboy: a dark
        leather miner's helmet with a brass headlamp, gold aviator shades, a cigar, a red neckerchief,
        a cream shirt with the sleeves rolled, leather suspenders, the brass GM medallion, a tool belt
        with pouches and a brass lantern, worn leather chaps over tall boots - and, in this room, the
        claim book and its brass stamp in his left hand.
  Utah  the founder's Drive reference - the older, wiry cowboy: a brown felt hat, dark shades, a grey
        goatee, a black leather jacket over a dark vest with a star, a heavy tooled belt, twin low-slung
        holsters, charcoal jeans, two-tone boots (leather foot, bone shaft) and a coil of river rope.

Quality bar: one shared skeleton drives BOTH the mesh (limbs lofted along the joints) and the armature,
so the rig always fits; clothing is layered over the body; and each man ships authored clips
(Idle / Counter / Greet / Point / Carry / Walk) played in game through the glTF AnimationPlayer.
Frame matches Ep2TownFolk and the town kit: feet at z = 0, up = +z, FRONT = -y.
"""
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUTDIR = argv[argv.index("--dir") + 1] if "--dir" in argv else "src/episode2/assets/town"
ONLY = argv[argv.index("--only") + 1] if "--only" in argv else ""

TAU = math.pi * 2.0
FPS = 24


# ---------------------------------------------------------------- materials

MATS = {}


def mat(name, rgb, rough=0.85, metal=0.0):
	if name in MATS:
		return MATS[name]
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	MATS[name] = m
	return m


# ---------------------------------------------------------------- the skeleton
# Every measure is in metres for a 1.86 m man; S(h) rescales for the shorter/wiry figure.
# The mesh limbs are lofted along these exact joints, and the armature is built from the same
# numbers, so skin and rig can never drift apart.

def S(h=1.86, girth=1.0):
	s = h / 1.86
	j = {}

	def p(x, y, z):
		return Vector((x * s * girth, y * s * girth, z * s))

	j["hips"] = p(0.0, 0.0, 0.955)
	j["spine"] = p(0.0, -0.010, 1.115)
	j["chest"] = p(0.0, -0.014, 1.300)
	j["neck"] = p(0.0, -0.006, 1.487)
	j["head"] = p(0.0, -0.010, 1.575)
	j["head_top"] = p(0.0, -0.012, 1.795)
	j["chin"] = p(0.0, -0.078, 1.588)
	j["foramen"] = p(0.0, -0.012, 1.672)          # eye line
	for side, sx in (("L", 1.0), ("R", -1.0)):
		j["clav." + side] = p(sx * 0.045, -0.012, 1.442)
		j["arm." + side] = p(sx * 0.180, -0.004, 1.432)
		j["elbow." + side] = p(sx * 0.205, 0.014, 1.108)
		j["wrist." + side] = p(sx * 0.214, -0.006, 0.815)
		j["hand." + side] = p(sx * 0.218, -0.026, 0.720)
		j["thigh." + side] = p(sx * 0.092, 0.0, 0.925)
		j["knee." + side] = p(sx * 0.100, 0.010, 0.512)
		j["ankle." + side] = p(sx * 0.104, 0.016, 0.098)
		j["toe." + side] = p(sx * 0.104, -0.128, 0.032)
	return j


# ---------------------------------------------------------------- the parts

class Part:
	"""One material's geometry, built from lofts / boxes / lathes, merged into the figure at the end."""

	def __init__(self, name, bones=None):
		self.name = name
		self.bones = bones
		self.bm = bmesh.new()
		self.smooth = True

	def _face(self, verts):
		try:
			f = self.bm.faces.new(verts)
			f.smooth = self.smooth
			return f
		except ValueError:
			return None

	def ring(self, c, rx, ry, sides, roll=0.0, xform=None):
		out = []
		for i in range(sides):
			a = TAU * i / sides + roll
			pt = Vector((c[0] + rx * math.cos(a), c[1] + ry * math.sin(a), c[2]))
			if xform is not None:
				pt = xform @ pt
			out.append(self.bm.verts.new(pt))
		return out

	def bridge(self, a, b, sides):
		for i in range(sides):
			n = (i + 1) % sides
			self._face((a[i], a[n], b[n], b[i]))

	def loft(self, sections, sides=16, cap0=True, cap1=True, roll=0.0, xform=None):
		"""sections: [(x, y, z, rx, ry), ...] stacked along the local z, optionally transformed."""
		rings = [self.ring(s, s[3], s[4], sides, roll, xform) for s in sections]
		for a, b in zip(rings, rings[1:]):
			self.bridge(a, b, sides)
		if cap0:
			self._face(list(reversed(rings[0])))
		if cap1:
			self._face(rings[-1])
		return rings

	def limb(self, pts, radii, sides=12, cap0=True, cap1=True, roll=0.0):
		"""A tube through a joint chain: each ring is perpendicular to the local bone direction."""
		n = len(pts)
		rings = []
		for i, c in enumerate(pts):
			if i == 0:
				t = pts[1] - pts[0]
			elif i == n - 1:
				t = pts[-1] - pts[-2]
			else:
				t = pts[i + 1] - pts[i - 1]
			xf = Matrix.Translation(c) @ t.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
			rx, ry = radii[i] if isinstance(radii[i], (tuple, list)) else (radii[i], radii[i])
			rings.append(self.ring((0, 0, 0), rx, ry, sides, roll, xf))
		for a, b in zip(rings, rings[1:]):
			self.bridge(a, b, sides)
		if cap0:
			self._face(list(reversed(rings[0])))
		if cap1:
			self._face(rings[-1])
		return rings

	def box(self, size, centre, rot=(0.0, 0.0, 0.0), xform=None):
		sides = [(-size[0] / 2, -size[1] / 2), (size[0] / 2, -size[1] / 2), (size[0] / 2, size[1] / 2), (-size[0] / 2, size[1] / 2)]
		r = Matrix.Rotation(rot[0], 4, "X") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[2], 4, "Z")
		xf = Matrix.Translation(Vector(centre)) @ r
		if xform is not None:
			xf = xform @ xf
		vs = [[self.bm.verts.new(xf @ Vector((sx, sy, z))) for (sx, sy) in sides] for z in (-size[2] / 2, size[2] / 2)]
		lo, hi = vs
		self._face((lo[0], lo[1], lo[2], lo[3]))
		self._face((hi[3], hi[2], hi[1], hi[0]))
		for i in range(4):
			n = (i + 1) % 4
			self._face((lo[n], lo[i], hi[i], hi[n]))

	def lathe(self, profile, sides=20, xform=None, cap_ends=True, ry_scale=1.0):
		"""profile: [(r, z), ...] revolved about the local z axis. An r of 0 is a single pole vertex."""
		rings = []
		for (r, z) in profile:
			if r < 1e-5:
				pt = Vector((0.0, 0.0, z))
				rings.append(self.bm.verts.new(xform @ pt if xform is not None else pt))
				continue
			out = []
			for i in range(sides):
				a = TAU * i / sides
				pt = Vector((r * math.cos(a), r * math.sin(a) * ry_scale, z))
				out.append(self.bm.verts.new(xform @ pt if xform is not None else pt))
			rings.append(out)
		for a, b in zip(rings, rings[1:]):
			if isinstance(a, bmesh.types.BMVert):
				for i in range(sides):
					n = (i + 1) % sides
					self._face((a, b[n], b[i]))
			elif isinstance(b, bmesh.types.BMVert):
				for i in range(sides):
					n = (i + 1) % sides
					self._face((a[i], a[n], b))
			else:
				self.bridge(a, b, sides)
		if cap_ends:
			if not isinstance(rings[0], bmesh.types.BMVert):
				self._face(list(reversed(rings[0])))
			if not isinstance(rings[-1], bmesh.types.BMVert):
				self._face(rings[-1])
		return rings

	def plate(self, pts, thickness=0.012, xform=None):
		"""A flat polygon (in the local x/y plane) extruded along z - stars, badges, buckles."""
		lo, hi = [], []
		for pt in pts:
			a = Vector((pt[0], pt[1], -thickness / 2))
			b = Vector((pt[0], pt[1], thickness / 2))
			if xform is not None:
				a, b = xform @ a, xform @ b
			lo.append(self.bm.verts.new(a))
			hi.append(self.bm.verts.new(b))
		self._face(list(reversed(lo)))
		self._face(hi)
		for i in range(len(pts)):
			n = (i + 1) % len(pts)
			self._face((lo[i], lo[n], hi[n], hi[i]))

	def torus(self, centre, r, tube, sides=14, ring_n=9, xform=None):
		pts = []
		for i in range(sides):
			a = TAU * i / sides
			row = []
			for k in range(ring_n):
				b = TAU * k / ring_n
				pt = Vector(((r + tube * math.cos(b)) * math.cos(a), (r + tube * math.cos(b)) * math.sin(a), tube * math.sin(b)))
				if xform is not None:
					pt = xform @ pt
				row.append(self.bm.verts.new(pt + centre))
			pts.append(row)
		for i in range(sides):
			n = (i + 1) % sides
			for k in range(ring_n):
				m = (k + 1) % ring_n
				self._face((pts[i][k], pts[i][m], pts[n][m], pts[n][k]))


class Figure:
	def __init__(self, name, height):
		self.name = name
		self.height = height
		self.parts = []

	def part(self, mat_name, bones=None, smooth=True):
		p = Part(mat_name, bones)
		p.smooth = smooth
		self.parts.append(p)
		return p

	def build(self):
		"""One mesh object, one material slot per part, shade smooth, feet on z = 0."""
		me = bpy.data.meshes.new(self.name + "_mesh")
		big = bmesh.new()
		groups = []                       # (bone hint list, first vert, last vert)
		for i, p in enumerate(self.parts):
			bmesh.ops.recalc_face_normals(p.bm, faces=p.bm.faces[:])
			tme = bpy.data.meshes.new("t")
			p.bm.to_mesh(tme)
			p.bm.free()
			n0 = len(big.verts)
			n0f = len(big.faces)
			big.from_mesh(tme)
			big.verts.ensure_lookup_table()
			big.faces.ensure_lookup_table()
			for f in big.faces[n0f:]:
				f.material_index = i
			bpy.data.meshes.remove(tme)
			groups.append((p.bones, n0, len(big.verts) - 1))
		if os.environ.get("PART_DEBUG"):
			big.verts.ensure_lookup_table()
			for i, (bones, a, b) in enumerate(groups):
				vs = [big.verts[k].co for k in range(a, b + 1)]
				xs = [v.x for v in vs]
				ys = [v.y for v in vs]
				zs = [v.z for v in vs]
				print(f"PART {i:3d} {self.parts[i].name:14s} x=[{min(xs):.3f},{max(xs):.3f}] y=[{min(ys):.3f},{max(ys):.3f}] z=[{min(zs):.3f},{max(zs):.3f}]")
		big.to_mesh(me)
		big.free()
		for p in self.parts:
			me.materials.append(MATS[p.name])
		ob = bpy.data.objects.new(self.name + "_geo", me)
		bpy.context.scene.collection.objects.link(ob)
		bpy.context.view_layer.update()
		zs = [v.co.z for v in me.vertices]
		s = self.height / max(max(zs) - min(zs), 0.001)
		for v in me.vertices:
			v.co = Vector((v.co.x * s, v.co.y * s, (v.co.z - min(zs)) * s))
		me.update()
		return ob, groups


# ---------------------------------------------------------------- body

def torso(f, j, mat_name, bones, widen=(0.0, 0.0), cap_top=True):
	p = f.part(mat_name, bones)
	p.loft([
		(0, 0.006, j["hips"].z - 0.10, 0.160 + widen[0], 0.111 + widen[1]),
		(0, 0.004, j["hips"].z, 0.166 + widen[0], 0.114 + widen[1]),
		(0, -0.004, j["spine"].z - 0.05, 0.152 + widen[0], 0.106 + widen[1]),
		(0, -0.010, j["spine"].z + 0.03, 0.163 + widen[0], 0.110 + widen[1]),
		(0, -0.014, j["chest"].z, 0.182 + widen[0], 0.117 + widen[1]),
		(0, -0.010, j["chest"].z + 0.075, 0.188 + widen[0], 0.110 + widen[1]),
		(0, -0.004, j["neck"].z - 0.02, 0.146 + widen[0], 0.096 + widen[1]),
	], 20, cap0=False, cap1=cap_top)
	# pectorals
	pec = f.part(mat_name, bones)
	for sx in (-1, 1):
		pec.loft([(sx * 0.085, -0.086, j["chest"].z + 0.015, 0.058, 0.040), (sx * 0.090, -0.070, j["chest"].z + 0.055, 0.052, 0.036)], 12)
	return p


def neck(f, j, mat_name, bones):
	p = f.part(mat_name, bones)
	p.limb([j["neck"] + Vector((0, 0.004, -0.055)), j["neck"], j["head"] + Vector((0, -0.004, 0.01))],
		[(0.068, 0.070), (0.057, 0.060), (0.052, 0.056)], 14, cap0=False, cap1=False)
	return p


def head(f, j, skin, bones, hair=None, beard=None):
	z = j["foramen"].z
	p = f.part(skin, bones)
	# skull: occiput back, brow forward, jaw tapering to the chin
	p.loft([
		(0, 0.010, j["head"].z + 0.005, 0.056, 0.062),
		(0, -0.004, z - 0.075, 0.070, 0.084),
		(0, -0.012, z - 0.040, 0.078, 0.096),
		(0, -0.014, z, 0.082, 0.100),
		(0, -0.010, z + 0.042, 0.082, 0.098),
		(0, -0.004, z + 0.080, 0.070, 0.084),
		(0, 0.006, z + 0.116, 0.040, 0.048),
	], 18)
	# nose and brow
	n = f.part(skin, bones)
	n.loft([(0, -0.092, z + 0.006, 0.017, 0.014), (0, -0.112, z - 0.010, 0.014, 0.014), (0, -0.104, z - 0.030, 0.019, 0.014)], 10)
	b = f.part(skin, bones)
	b.box((0.150, 0.030, 0.020), (0.0, -0.084, z + 0.014), rot=(-0.15, 0, 0))
	# cheeks, ears, jaw
	for sx in (-1, 1):
		ch = f.part(skin, bones)
		ch.loft([(sx * 0.062, -0.070, z - 0.038, 0.030, 0.026), (sx * 0.070, -0.052, z - 0.008, 0.034, 0.030)], 10)
		ear = f.part(skin, bones)
		ear.loft([(sx * 0.084, 0.000, z - 0.006, 0.012, 0.030), (sx * 0.098, 0.002, z - 0.004, 0.010, 0.026)], 10)
	if hair:
		hr = f.part(hair, bones)
		hr.loft([(0, -0.004, z + 0.006, 0.086, 0.104), (0, -0.006, z + 0.060, 0.078, 0.094), (0, 0.004, z + 0.108, 0.046, 0.056)], 18, cap0=False)
	if beard:
		bd = f.part(beard, bones)
		# moustache, goatee and a stubbled jaw
		bd.box((0.088, 0.034, 0.024), (0.0, -0.092, z - 0.034), rot=(0.10, 0, 0))
		bd.loft([(0, -0.086, z - 0.070, 0.040, 0.030), (0, -0.080, z - 0.050, 0.046, 0.038), (0, -0.074, z - 0.030, 0.052, 0.046)], 12, cap0=False)
		for sx in (-1, 1):
			bd.loft([(sx * 0.076, -0.028, z - 0.052, 0.018, 0.040), (sx * 0.080, -0.010, z + 0.030, 0.016, 0.044)], 8)


def arm(f, j, side, sleeve, skin, bones, roll_up=False, sleeve_to=0.62, cuff=0.013, girth=1.0):
	"""Upper arm, forearm and a hand with four fingers and a thumb, lofted along the joints."""
	a = j["arm." + side]
	e = j["elbow." + side]
	w = j["wrist." + side]
	h = j["hand." + side]
	up_mid = a.lerp(e, 0.5)
	fa_mid = e.lerp(w, 0.5)
	r_arm = [(0.056 * girth, 0.058 * girth), (0.050 * girth, 0.052 * girth), (0.044 * girth, 0.046 * girth)]
	r_fa = [(0.046 * girth, 0.048 * girth), (0.040 * girth, 0.041 * girth), (0.030 * girth, 0.032 * girth)]
	# the deltoid, so the sleeve grows out of the shoulder instead of hanging off it
	d = f.part(sleeve, bones)
	d.lathe([(0.0, -0.080), (0.040, -0.066), (0.062, -0.044), (0.071, -0.010), (0.070, 0.028), (0.058, 0.058), (0.028, 0.076), (0.0, 0.082)],
		14, xform=Matrix.Translation(a + Vector((0, -0.004, 0.010))))
	# the shirt sleeve
	s = f.part(sleeve, bones)
	s.limb([a + (a - e).normalized() * 0.030, a, up_mid, e], [(0.070, 0.072), (0.058, 0.060), (0.053, 0.055), (0.049, 0.051)], 12)
	if roll_up:
		s.limb([e, fa_mid, e.lerp(w, sleeve_to)], [(0.052, 0.054), (0.048, 0.050), (0.043, 0.045)], 12)
		cf = f.part(sleeve, bones)
		cf.limb([e.lerp(w, sleeve_to - 0.06), e.lerp(w, sleeve_to + 0.02)], [(0.049, 0.051), (0.052, 0.054)], 12)
		k = f.part(skin, bones)
		k.limb([e.lerp(w, sleeve_to - 0.02), e.lerp(w, 0.86), w], [(0.041, 0.043), (0.036, 0.038), (0.031, 0.033)], 12)
	else:
		s.limb([e, fa_mid, e.lerp(w, sleeve_to)], [(0.050, 0.052), (0.046, 0.048), (0.042, 0.044)], 12)
		cf = f.part(sleeve, bones)
		cf.limb([e.lerp(w, sleeve_to - 0.05), e.lerp(w, sleeve_to + 0.02)], [(0.044, 0.046), (0.047, 0.049)], 12)
		k = f.part(skin, bones)
		k.limb([e.lerp(w, sleeve_to - 0.02), e.lerp(w, 0.88), w], [(0.040, 0.042), (0.034, 0.036), (0.030, 0.032)], 12)
	# the hand: built in the hand bone's frame, palm rolled to face the thigh
	hz = (h - w).normalized()
	xf = Matrix.Translation(w) @ hz.to_track_quat("Z", "Y").to_matrix().to_4x4()
	roll = Matrix.Rotation(math.radians(-78.0 if side == "L" else 78.0), 4, "Z")
	xf = xf @ roll
	hand = f.part(skin, bones)
	L = (h - w).length
	hand.loft([(0, 0, 0, 0.030, 0.038), (0, 0, L * 0.45, 0.034, 0.044), (0, 0, L * 0.95, 0.036, 0.046)], 12, xform=xf)
	for i in range(4):
		fx = -0.024 + i * 0.016
		ln = 0.062 - abs(i - 1.5) * 0.004
		a0 = Vector((fx, 0.004, L * 0.92))
		a1 = Vector((fx, -0.006, L * 0.92 + ln * 0.55))
		a2 = Vector((fx, -0.024, L * 0.92 + ln))
		fg = f.part(skin, bones)
		for (p0, p1) in ((a0, a1), (a1, a2)):
			d = p1 - p0
			fg.limb([xf @ p0, xf @ p1], [0.0105, 0.0095], 8, cap0=False)
	th = f.part(skin, bones)
	t0 = Vector((-0.030, 0.014, L * 0.30))
	t1 = Vector((-0.052, 0.004, L * 0.58))
	t2 = t1.lerp(t0, -1.2)
	th.limb([xf @ t0, xf @ t1, xf @ t2], [0.013, 0.011, 0.010], 8, cap0=False)


def leg(f, j, side, mat_name, bones, to_z=None, girth=1.0, cap_bottom=False):
	t = j["thigh." + side]
	k = j["knee." + side]
	a = j["ankle." + side]
	stop = a if to_z is None else Vector((a.x, a.y, to_z))
	pts = [t + Vector((0, 0, 0.055)), t, t.lerp(k, 0.42), k, k.lerp(stop, 0.5), stop]
	p = f.part(mat_name, bones)
	p.limb(pts, [(0.098 * girth, 0.101 * girth), (0.094 * girth, 0.098 * girth), (0.084 * girth, 0.088 * girth),
		(0.074 * girth, 0.078 * girth), (0.066 * girth, 0.070 * girth), (0.058 * girth, 0.062 * girth)],
		14, cap0=False, cap1=cap_bottom or to_z is not None)
	return p


def foot(f, j, side, shaft, foot_mat, sole, bones, heel_h=0.030):
	"""A boot: a shaft up the shin, a foot that rolls from heel to ball, a toe and a sole.
	`shaft` is the shin leather, `foot_mat` the foot (Utah's two-tone boots: bone shaft, dark foot)."""
	a = j["ankle." + side]
	t = j["toe." + side]
	k = j["knee." + side]
	p = f.part(shaft, bones)
	p.limb([a, a.lerp(k, 0.35), a.lerp(k, 0.70)], [(0.066, 0.070), (0.072, 0.078), (0.078, 0.084)], 12, cap0=False, cap1=False)
	fp = f.part(foot_mat, bones)
	ball = Vector((a.x, a.y - 0.095, 0.040))
	tip = Vector((t.x, t.y - 0.030, 0.038))
	fp.limb([Vector((a.x, a.y + 0.062, 0.058)), a, ball, tip],
		[(0.058, 0.070), (0.062, 0.074), (0.062, 0.064), (0.048, 0.046)], 12)
	sl = f.part(sole, bones)
	sl.box((0.116, 0.292, 0.026), (a.x, a.y - 0.046, 0.013))
	hl = f.part(sole, bones)
	hl.box((0.094, 0.072, 0.040), (a.x, a.y + 0.080, 0.020))


# ---------------------------------------------------------------- gear

def belt(f, j, cloth, metal, bones, z_off=0.020, buckle=True):
	z = j["hips"].z + z_off
	b = f.part(cloth, bones)
	b.loft([(0, 0.0, z - 0.040, 0.181, 0.129), (0, 0.0, z + 0.038, 0.181, 0.129)], 20, cap0=False, cap1=False)
	if buckle:
		m = f.part(metal, bones)
		m.box((0.070, 0.016, 0.052), (0.0, -0.136, z + 0.004))
		m.box((0.046, 0.014, 0.032), (0.0, -0.144, z + 0.004))


def holsters(f, j, leather, steel, wood, bones):
	z = j["hips"].z
	for sx in (-1, 1):
		x = sx * 0.196
		h = f.part(leather, bones)
		# the holster, canted back over the thigh, with the belt loop above it
		h.loft([(x, 0.030, z - 0.055, 0.048, 0.042), (x + sx * 0.006, 0.036, z - 0.130, 0.046, 0.040), (x + sx * 0.008, 0.040, z - 0.205, 0.040, 0.036)], 10)
		h.box((0.040, 0.030, 0.110), (x, 0.062, z - 0.020))
		st = f.part(steel, bones)
		st.box((0.022, 0.026, 0.120), (x, 0.028, z - 0.075))
		st.box((0.030, 0.038, 0.026), (x, 0.030, z - 0.020))
		w = f.part(wood, bones)
		w.box((0.026, 0.042, 0.070), (x + sx * 0.010, 0.052, z - 0.014), rot=(-0.22, 0, sx * 0.10))


def suspenders(f, j, colour, metal, bones):
	s = f.part(colour, bones)
	for sx in (-1, 1):
		s.box((0.044, 0.018, 0.250), (sx * 0.078, -0.108, j["chest"].z + 0.020), rot=(0.06, 0, 0))
		s.box((0.044, 0.018, 0.170), (sx * 0.090, 0.020, j["neck"].z - 0.060), rot=(0.30, 0, 0))
		s.box((0.044, 0.018, 0.230), (sx * 0.070, 0.104, j["chest"].z - 0.030), rot=(-0.10, 0, 0))
	m = f.part(metal, bones)
	for sx in (-1, 1):
		m.box((0.050, 0.014, 0.040), (sx * 0.078, -0.118, j["chest"].z - 0.070))


def medallion(f, j, metal, emblem, bones):
	z = j["chest"].z - 0.005
	c = f.part(metal, bones)
	for sx in (-1, 1):
		c.box((0.012, 0.010, 0.128), (sx * 0.062, -0.126, z + 0.078), rot=(0, sx * 0.30, 0))
	md = f.part(metal, bones)
	md.lathe([(0.0, -0.008), (0.036, -0.007), (0.040, 0.0), (0.036, 0.007), (0.0, 0.008)], 18,
		xform=Matrix.Translation(Vector((0, -0.130, z - 0.062))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	em = f.part(emblem, bones)
	em.lathe([(0.0, -0.010), (0.029, -0.008), (0.029, 0.002), (0.0, 0.002)], 18,
		xform=Matrix.Translation(Vector((0, -0.132, z - 0.062))) @ Matrix.Rotation(math.pi / 2, 4, "X"))


def star_badge(f, j, metal, bones, x, z):
	s = f.part(metal, bones)
	pts = []
	for i in range(10):
		r = 0.032 if i % 2 == 0 else 0.013
		a = math.pi / 2 + TAU * i / 10.0
		pts.append((r * math.cos(a), r * math.sin(a)))
	s.plate(pts, 0.008, xform=Matrix.Translation(Vector((x, -0.121, z))) @ Matrix.Rotation(math.pi / 2, 4, "X"))


def glasses(f, j, frame, lens, bones, kind="aviator"):
	z = j["foramen"].z
	fr = f.part(frame, bones)
	for sx in (-1, 1):
		pts = []
		for i in range(14):
			a = TAU * i / 14
			rx, ry = (0.036, 0.026) if kind == "aviator" else (0.034, 0.030)
			pts.append((sx * 0.042 + rx * math.cos(a), ry * math.sin(a)))
		fr.plate(pts, 0.007, xform=Matrix.Translation(Vector((0, -0.098, z))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	fr.box((0.026, 0.008, 0.012), (0.0, -0.101, z))
	for sx in (-1, 1):
		fr.box((0.072, 0.008, 0.010), (sx * 0.098, -0.050, z + 0.006), rot=(0, 0, sx * 0.62))
	ln = f.part(lens, bones)
	for sx in (-1, 1):
		pts = []
		for i in range(14):
			a = TAU * i / 14
			rx, ry = (0.032, 0.022) if kind == "aviator" else (0.030, 0.026)
			pts.append((sx * 0.042 + rx * math.cos(a), ry * math.sin(a)))
		ln.plate(pts, 0.004, xform=Matrix.Translation(Vector((0, -0.102, z))) @ Matrix.Rotation(math.pi / 2, 4, "X"))


def cigar(f, j, wrap, ember, bones):
	z = j["foramen"].z
	c = f.part(wrap, bones)
	c.limb([Vector((0.018, -0.100, z - 0.042)), Vector((0.042, -0.118, z - 0.048)), Vector((0.070, -0.126, z - 0.050))],
		[0.011, 0.010, 0.010], 8)
	e = f.part(ember, bones)
	e.lathe([(0.0, 0.0), (0.010, 0.0), (0.010, 0.006), (0.0, 0.006)], 10,
		xform=Matrix.Translation(Vector((0.072, -0.127, z - 0.050))) @ Matrix.Rotation(math.pi / 2, 4, "Y"))


def neckerchief(f, j, cloth, bones):
	n = f.part(cloth, bones)
	n.loft([(0, -0.006, j["neck"].z - 0.048, 0.086, 0.082), (0, -0.010, j["neck"].z + 0.012, 0.064, 0.062)], 16, cap0=False, cap1=False)
	n.box((0.086, 0.026, 0.130), (0.010, -0.108, j["chest"].z + 0.100), rot=(0.30, 0, 0.08))


def hat_miner(f, j, leather, brass, glass, bones):
	z = j["foramen"].z + 0.075
	h = f.part(leather, bones)
	# a soft leather miner's cap with a short duck bill
	h.loft([(0, -0.004, z - 0.030, 0.090, 0.104), (0, -0.006, z + 0.010, 0.096, 0.110), (0, -0.004, z + 0.055, 0.086, 0.098), (0, 0.004, z + 0.090, 0.046, 0.056)], 18)
	br = f.part(leather, bones)
	br.loft([(0, -0.098, z - 0.036, 0.096, 0.078), (0, -0.132, z - 0.056, 0.088, 0.062), (0, -0.150, z - 0.068, 0.062, 0.036)], 12, cap0=False)
	seam = f.part(leather, bones)
	seam.box((0.014, 0.150, 0.060), (0.0, -0.010, z + 0.048))
	# the headlamp
	lamp = f.part(brass, bones)
	lamp.box((0.036, 0.030, 0.036), (0.0, -0.104, z + 0.014))
	lamp.lathe([(0.030, 0.0), (0.034, 0.008), (0.026, 0.020)], 12,
		xform=Matrix.Translation(Vector((0.0, -0.106, z + 0.014))) @ Matrix.Rotation(-math.pi / 2, 4, "X"))
	g = f.part(glass, bones)
	g.lathe([(0.0, 0.0), (0.027, 0.0)], 12,
		xform=Matrix.Translation(Vector((0.0, -0.112, z + 0.014))) @ Matrix.Rotation(math.pi / 2, 4, "X"))


def hat_felt(f, j, felt, band, bones):
	z = j["foramen"].z + 0.066
	h = f.part(felt, bones)
	# the brim: wide, curled down at the sides, flat in front
	h.lathe([(0.118, z - 0.014), (0.176, z - 0.030), (0.196, z - 0.024), (0.192, z - 0.010), (0.124, z + 0.004)],
		26, cap_ends=False, ry_scale=0.92)
	# the crown, front-peaked with a centre crease
	h.lathe([(0.122, z + 0.002), (0.126, z + 0.050), (0.124, z + 0.098), (0.112, z + 0.140), (0.070, z + 0.170), (0.0, z + 0.178)],
		26, ry_scale=0.96)
	cr = f.part(felt, bones)
	cr.box((0.070, 0.150, 0.120), (0.0, 0.0, z + 0.136), rot=(0, 0, 0))
	b = f.part(band, bones)
	b.lathe([(0.128, z + 0.010), (0.132, z + 0.022), (0.128, z + 0.056), (0.124, z + 0.064)], 26, cap_ends=False, ry_scale=0.96)
	bd = f.part(band, bones)
	bd.box((0.030, 0.012, 0.030), (0.108, -0.062, z + 0.036), rot=(0, 0.5, 0.5))


def coat_short(f, j, cloth, bones, z0=None):
	"""A hip-length open coat with lapels (Utah's leather jacket)."""
	z0 = j["neck"].z - 0.030 if z0 is None else z0
	c = f.part(cloth, bones)
	c.loft([
		(0, -0.006, z0 + 0.010, 0.155, 0.106),
		(0, -0.010, j["chest"].z + 0.020, 0.199, 0.126),
		(0, -0.008, j["spine"].z + 0.030, 0.188, 0.124),
		(0, 0.0, j["hips"].z + 0.040, 0.190, 0.126),
		(0, 0.006, j["hips"].z - 0.070, 0.196, 0.134),
	], 20, cap0=False, cap1=False)
	for sx in (-1, 1):
		# the front panel, opened past the chest so the vest reads through
		c.box((0.088, 0.022, 0.190), (sx * 0.126, -0.122, j["chest"].z + 0.030))
		c.box((0.100, 0.024, 0.220), (sx * 0.132, -0.126, j["spine"].z - 0.020))
		# the lapel folded back
		c.box((0.086, 0.020, 0.150), (sx * 0.108, -0.134, j["chest"].z + 0.080), rot=(0, sx * 0.34, 0))
		c.box((0.070, 0.018, 0.070), (sx * 0.150, 0.040, j["neck"].z - 0.050), rot=(0, sx * 0.9, 0))


def vest(f, j, cloth, bones, buttons=5):
	v = f.part(cloth, bones)
	v.loft([
		(0, -0.010, j["chest"].z + 0.055, 0.150, 0.104),
		(0, -0.014, j["chest"].z, 0.168, 0.110),
		(0, -0.012, j["spine"].z + 0.020, 0.158, 0.110),
		(0, -0.006, j["hips"].z + 0.055, 0.168, 0.116),
	], 18, cap0=False, cap1=False)
	pl = f.part(cloth, bones)
	pl.box((0.024, 0.014, 0.230), (0.0, -0.118, j["chest"].z - 0.010))
	for i in range(buttons):
		bz = j["chest"].z + 0.045 - i * 0.048
		bt = f.part(cloth, bones)
		bt.lathe([(0.0, 0.0), (0.009, 0.0), (0.009, 0.006), (0.0, 0.006)], 8,
			xform=Matrix.Translation(Vector((0.0, -0.126, bz))) @ Matrix.Rotation(math.pi / 2, 4, "X"))


def belt_pouches(f, j, cloth, metal, bones):
	z = j["hips"].z + 0.020
	p = f.part(cloth, bones)
	for (px, py, s) in [(-0.150, -0.108, 1.0), (-0.222, -0.052, 0.8)]:
		p.box((0.088 * s, 0.056 * s, 0.115 * s), (px, py, z - 0.085 * s))
		p.box((0.092 * s, 0.060 * s, 0.026 * s), (px, py - 0.002, z - 0.030 * s))
	m = f.part(metal, bones)
	m.box((0.022, 0.014, 0.022), (-0.150, -0.140, z - 0.050))


def lantern(f, j, brass, glass, bones):
	"""The brass hand lantern that hangs from Rich's tool belt."""
	x, y, z = -0.238, -0.020, j["hips"].z - 0.120
	l = f.part(brass, bones)
	l.box((0.060, 0.060, 0.016), (x, y, z + 0.070))
	for sx in (-1, 1):
		l.box((0.010, 0.010, 0.104), (x + sx * 0.028, y, z + 0.006))
	l.box((0.066, 0.066, 0.016), (x, y, z - 0.058))
	l.torus(Vector((x, y, z + 0.098)), 0.026, 0.005, 12, 6, Matrix.Rotation(math.pi / 2, 4, "X"))
	g = f.part(glass, bones)
	g.box((0.044, 0.044, 0.096), (x, y, z + 0.002))


def chaps(f, j, leather, metal, bones):
	"""Batwing chaps: a worn leather shell that wraps the outer thigh, buckled at the belt."""
	c = f.part(leather, bones)
	for side in ("L", "R"):
		sx = 1.0 if side == "L" else -1.0
		t = j["thigh." + side]
		k = j["knee." + side]
		c.limb([Vector((sx * 0.132, -0.004, j["hips"].z - 0.055)), Vector((sx * 0.136, 0.000, t.z - 0.130)),
			Vector((sx * 0.144, 0.004, k.z + 0.120)), Vector((sx * 0.152, 0.006, k.z - 0.075))],
			[(0.056, 0.102), (0.062, 0.108), (0.070, 0.116), (0.078, 0.122)], 14, cap0=False, cap1=False)
		# the knee flap and the thigh strap that holds the chap on
		c.limb([Vector((sx * 0.120, 0.000, k.z + 0.110)), Vector((sx * 0.156, 0.000, k.z + 0.030)), Vector((sx * 0.128, 0.000, k.z - 0.060))],
			[(0.052, 0.130), (0.056, 0.140), (0.052, 0.132)], 12, cap0=False, cap1=False)
		st = f.part(leather, bones)
		st.limb([Vector((t.x, t.y, t.z - 0.045)), Vector((t.x, t.y, t.z - 0.075))],
			[(0.102, 0.106), (0.106, 0.110)], 14, cap0=False, cap1=False)
	m = f.part(metal, bones)
	for side in ("L", "R"):
		sx = 1.0 if side == "L" else -1.0
		m.box((0.026, 0.018, 0.026), (sx * 0.196, -0.030, j["thigh." + side].z - 0.060))


def rope_coil(f, j, cloth, bones):
	"""Utah's river rope, coiled on his left hip."""
	r = f.part(cloth, bones)
	c = Vector((0.196, 0.028, j["hips"].z - 0.030))
	for i in range(3):
		r.torus(c + Vector((0.0, 0.0, i * 0.026 - 0.026)), 0.052, 0.010, 12, 6,
			Matrix.Rotation(math.radians(72), 4, "Y") @ Matrix.Rotation(math.radians(8), 4, "Z"))


def claim_book(f, j, leather, paper, brass, bones, hold="L"):
	"""Rich's claim book and its brass stamp, sitting open in the left hand."""
	w = j["wrist." + hold]
	h = j["hand." + hold]
	xf = (Matrix.Translation(w.lerp(h, 0.62)) @ Matrix.Rotation(math.radians(-16), 4, "X")
		@ Matrix.Rotation(math.radians(20 if hold == "L" else -20), 4, "Y")
		@ Matrix.Translation(Vector((0.0, -0.058, -0.020))))
	b = f.part(leather, bones)
	b.box((0.150, 0.115, 0.024), (0, 0, 0), xform=xf)
	b.box((0.150, 0.018, 0.030), (0, -0.058, 0), xform=xf)
	p = f.part(paper, bones)
	p.box((0.138, 0.104, 0.016), (0, 0.004, 0.008), xform=xf)
	s = f.part(brass, bones)
	s.lathe([(0.0, 0.0), (0.015, 0.0), (0.015, 0.022), (0.0, 0.022)], 10,
		xform=xf @ Matrix.Translation(Vector((0.044, -0.012, 0.018))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
	s.box((0.036, 0.036, 0.012), (0.044, -0.012, 0.032), xform=xf)


def suspenders_shirt(f, j, cloth, bones):
	"""Shirt shell for a man who wears it out, with a placket and two chest pockets."""
	s = f.part(cloth, bones)
	s.loft([
		(0, -0.010, j["chest"].z + 0.055, 0.152, 0.107),
		(0, -0.014, j["chest"].z, 0.190, 0.124),
		(0, -0.010, j["spine"].z + 0.030, 0.165, 0.116),
		(0, -0.004, j["spine"].z - 0.090, 0.164, 0.118),
		(0, 0.006, j["hips"].z - 0.115, 0.172, 0.122),
	], 20, cap0=False, cap1=False)
	pl = f.part(cloth, bones)
	pl.box((0.030, 0.014, 0.300), (0.0, -0.126, j["chest"].z - 0.030))
	for sx in (-1, 1):
		pk = f.part(cloth, bones)
		pk.box((0.078, 0.016, 0.090), (sx * 0.092, -0.120, j["chest"].z - 0.010))
		pk.box((0.080, 0.010, 0.018), (sx * 0.092, -0.126, j["chest"].z + 0.040))
	cl = f.part(cloth, bones)
	cl.loft([(0, -0.006, j["neck"].z - 0.030, 0.088, 0.076), (0, -0.010, j["neck"].z + 0.030, 0.076, 0.070)], 14, cap0=False, cap1=False)


# ---------------------------------------------------------------- the two men

def build_rich(f, j):
	B = {
		"body": ["Hips", "Spine", "Chest", "Neck"],
		"head": ["Head", "Neck", "Chest"],
		"arm.L": ["Shoulder.L", "UpperArm.L", "Forearm.L", "Hand.L", "Chest"],
		"arm.R": ["Shoulder.R", "UpperArm.R", "Forearm.R", "Hand.R", "Chest"],
		"leg.L": ["Hips", "Thigh.L", "Shin.L", "Foot.L"],
		"leg.R": ["Hips", "Thigh.R", "Shin.R", "Foot.R"],
		"hips": ["Hips", "Spine"],
	}
	for side in ("L", "R"):
		leg(f, j, side, "Trouser", B["leg." + side], to_z=0.335)
		foot(f, j, side, "Boot", "Boot", "Sole", B["leg." + side])
	chaps(f, j, "Chap", "Brass", B["hips"])
	torso(f, j, "Shirt", B["body"])
	suspenders_shirt(f, j, "Shirt", B["body"])
	suspenders(f, j, "Suspender", "Brass", B["body"])
	neck(f, j, "Skin", B["head"])
	medallion(f, j, "Brass", "Emblem", B["body"])
	for side in ("L", "R"):
		arm(f, j, side, "Shirt", "Skin", B["arm." + side], roll_up=True, sleeve_to=0.60, girth=1.0)
	neckerchief(f, j, "Cloth", B["body"])
	head(f, j, "Skin", B["head"], hair="Hair")
	glasses(f, j, "Brass", "Lens", B["head"], kind="aviator")
	cigar(f, j, "Cigar", "Ember", B["head"])
	hat_miner(f, j, "HatLeather", "Brass", "LampGlass", B["head"])
	belt(f, j, "BeltLeather", "Brass", B["hips"])
	belt_pouches(f, j, "Pouch", "Brass", B["hips"])
	lantern(f, j, "Brass", "LampGlass", B["hips"])
	claim_book(f, j, "BookLeather", "Paper", "Brass", ["Hand.L"], hold="L")


def build_utah(f, j):
	B = {
		"body": ["Hips", "Spine", "Chest", "Neck"],
		"head": ["Head", "Neck", "Chest"],
		"arm.L": ["Shoulder.L", "UpperArm.L", "Forearm.L", "Hand.L", "Chest"],
		"arm.R": ["Shoulder.R", "UpperArm.R", "Forearm.R", "Hand.R", "Chest"],
		"leg.L": ["Hips", "Thigh.L", "Shin.L", "Foot.L"],
		"leg.R": ["Hips", "Thigh.R", "Shin.R", "Foot.R"],
		"hips": ["Hips", "Spine"],
	}
	for side in ("L", "R"):
		leg(f, j, side, "Jean", B["leg." + side], to_z=0.395)
		foot(f, j, side, "BootShaft", "Boot", "Boot", B["leg." + side])
	torso(f, j, "Shirt", B["body"])
	vest(f, j, "Vest", B["body"])
	neck(f, j, "Skin", B["head"])
	for side in ("L", "R"):
		arm(f, j, side, "JacketLeather", "Skin", B["arm." + side], roll_up=False, sleeve_to=0.96, girth=0.97)
	coat_short(f, j, "JacketLeather", B["body"])
	star_badge(f, j, "Star", ["Chest"], 0.112, j["chest"].z + 0.062)
	head(f, j, "Skin", B["head"], hair="Hair", beard="Beard")
	glasses(f, j, "Frame", "Lens", B["head"], kind="flat")
	hat_felt(f, j, "HatFelt", "HatBand", B["head"])
	belt(f, j, "BeltLeather", "Brass", B["hips"])
	holsters(f, j, "Holster", "Steel", "Wood", B["hips"])
	rope_coil(f, j, "Rope", B["hips"])


RICH_PAL = {
	"Trouser": ((0.31, 0.24, 0.16), 0.90), "Chap": ((0.38, 0.28, 0.17), 0.72), "Boot": ((0.34, 0.22, 0.12), 0.55),
	"Sole": ((0.16, 0.12, 0.09), 0.80), "BeltLeather": ((0.33, 0.22, 0.12), 0.68), "Pouch": ((0.42, 0.30, 0.17), 0.76),
	"Suspender": ((0.45, 0.30, 0.15), 0.70), "Shirt": ((0.87, 0.83, 0.73), 0.92), "Cloth": ((0.46, 0.10, 0.07), 0.92),
	"Skin": ((0.68, 0.47, 0.32), 0.72), "Hair": ((0.50, 0.38, 0.21), 0.92), "Beard": ((0.55, 0.50, 0.44), 0.92),
	"Brass": ((0.72, 0.54, 0.18), 0.30), "Emblem": ((0.19, 0.44, 0.20), 0.40), "Star": ((0.82, 0.80, 0.74), 0.28),
	"Lens": ((0.14, 0.11, 0.08), 0.18), "Frame": ((0.30, 0.28, 0.26), 0.35), "LampGlass": ((0.94, 0.88, 0.68), 0.25),
	"Ember": ((0.86, 0.33, 0.10), 0.60), "Cigar": ((0.42, 0.30, 0.17), 0.80), "HatLeather": ((0.20, 0.16, 0.13), 0.55),
	"HatFelt": ((0.34, 0.25, 0.17), 0.92), "HatBand": ((0.20, 0.14, 0.09), 0.80),
	"BookLeather": ((0.27, 0.18, 0.11), 0.66), "Paper": ((0.89, 0.86, 0.77), 0.95),
	"Steel": ((0.23, 0.23, 0.25), 0.38), "Wood": ((0.30, 0.19, 0.11), 0.55), "Rope": ((0.62, 0.54, 0.36), 0.95),
	"Jean": ((0.23, 0.23, 0.25), 0.92), "Vest": ((0.17, 0.16, 0.15), 0.86), "JacketLeather": ((0.14, 0.12, 0.11), 0.55),
	"BootShaft": ((0.72, 0.66, 0.54), 0.72), "Holster": ((0.27, 0.19, 0.12), 0.70),
}

# Utah wears his own gear, but he shares Rich's leathers, brass and steel.
UTAH_PAL = dict(RICH_PAL)
UTAH_PAL.update({
	"Jean": ((0.24, 0.24, 0.27), 0.92), "Vest": ((0.18, 0.17, 0.16), 0.86), "JacketLeather": ((0.15, 0.13, 0.12), 0.55),
	"BootShaft": ((0.70, 0.64, 0.52), 0.72), "Boot": ((0.30, 0.20, 0.11), 0.55), "Holster": ((0.28, 0.20, 0.13), 0.70),
	"Rope": ((0.66, 0.58, 0.40), 0.95), "Shirt": ((0.27, 0.28, 0.31), 0.92), "Skin": ((0.62, 0.43, 0.29), 0.72),
	"Hair": ((0.28, 0.26, 0.24), 0.92), "Beard": ((0.72, 0.70, 0.66), 0.92), "HatFelt": ((0.36, 0.26, 0.17), 0.92),
	"Frame": ((0.10, 0.10, 0.11), 0.30), "Suspender": ((0.36, 0.25, 0.13), 0.70),
})


# ---------------------------------------------------------------- the rig

BONE_PARENTS = [
	("Root", None), ("Hips", "Root"), ("Spine", "Hips"), ("Chest", "Spine"), ("Neck", "Chest"), ("Head", "Neck"),
	("Shoulder.L", "Chest"), ("UpperArm.L", "Shoulder.L"), ("Forearm.L", "UpperArm.L"), ("Hand.L", "Forearm.L"),
	("Shoulder.R", "Chest"), ("UpperArm.R", "Shoulder.R"), ("Forearm.R", "UpperArm.R"), ("Hand.R", "Forearm.R"),
	("Thigh.L", "Hips"), ("Shin.L", "Thigh.L"), ("Foot.L", "Shin.L"),
	("Thigh.R", "Hips"), ("Shin.R", "Thigh.R"), ("Foot.R", "Shin.R"),
]


def bone_ends(j):
	e = {
		"Root": (Vector((0, 0, 0.0)), Vector((0, 0, 0.16))),
		"Hips": (j["hips"], j["spine"]), "Spine": (j["spine"], j["chest"]), "Chest": (j["chest"], j["neck"]),
		"Neck": (j["neck"], j["head"]), "Head": (j["head"], j["head_top"]),
	}
	for side in ("L", "R"):
		e["Shoulder." + side] = (j["clav." + side], j["arm." + side])
		e["UpperArm." + side] = (j["arm." + side], j["elbow." + side])
		e["Forearm." + side] = (j["elbow." + side], j["wrist." + side])
		e["Hand." + side] = (j["wrist." + side], j["hand." + side])
		e["Thigh." + side] = (j["thigh." + side], j["knee." + side])
		e["Shin." + side] = (j["knee." + side], j["ankle." + side])
		e["Foot." + side] = (j["ankle." + side], j["toe." + side])
	return e


def make_armature(name, j):
	ends = bone_ends(j)
	arm_data = bpy.data.armatures.new(name + "_arm")
	arm_ob = bpy.data.objects.new(name + "_rig", arm_data)
	bpy.context.scene.collection.objects.link(arm_ob)
	bpy.context.view_layer.objects.active = arm_ob
	bpy.ops.object.mode_set(mode="EDIT")
	eb = arm_data.edit_bones
	for (bname, parent) in BONE_PARENTS:
		head, tail = ends[bname]
		b = eb.new(bname)
		b.head = head
		b.tail = tail
		if (tail - head).length < 1e-4:
			b.tail = head + Vector((0, 0, 0.02))
		b.use_deform = bname != "Root"
		if parent:
			b.parent = eb[parent]
			b.use_connect = (ends[parent][1] - head).length < 1e-5
	bpy.ops.object.mode_set(mode="OBJECT")
	return arm_ob


def skin(ob, arm_ob, groups, j):
	"""Distance weighting over each part's allowed bones - deterministic, no heat solve."""
	ends = bone_ends(j)
	seg = {}
	for bname, _ in BONE_PARENTS:
		if bname == "Root":
			continue
		seg[bname] = (ends[bname][0], ends[bname][1] - ends[bname][0])
	for bname in seg:
		ob.vertex_groups.new(name=bname)
	groups_by_name = {g.name: g for g in ob.vertex_groups}
	for (allowed, v0, v1) in groups:
		bones = allowed or list(seg.keys())
		for vi in range(v0, v1 + 1):
			co = ob.data.vertices[vi].co
			best = []
			for bname in bones:
				a, d = seg[bname]
				t = max(0.0, min(1.0, (co - a).dot(d) / max(d.length_squared, 1e-9)))
				dist = (co - (a + d * t)).length
				best.append((dist, bname))
			best.sort()
			best = best[:3]
			ws = [(1.0 / max(dist, 0.012) ** 4, bname) for (dist, bname) in best]
			total = sum(w for (w, _) in ws)
			for (w, bname) in ws:
				groups_by_name[bname].add([vi], w / total, "REPLACE")
	mod = ob.modifiers.new("Armature", "ARMATURE")
	mod.object = arm_ob
	ob.parent = arm_ob


# ---------------------------------------------------------------- the clips
# Pose values are bone euler angles in degrees: (x = pitch, y = roll along the bone, z = twist).
# Each clip lists (frame, overrides); every listed frame keys the full base pose plus overrides, so
# clips are self-contained and loop cleanly when the last frame matches the first.

def base_pose():
	return {
		"Hips": (0, 0, 0), "Spine": (0, 0, 0), "Chest": (0, 0, 0), "Neck": (0, 0, 0), "Head": (0, 0, 0),
		"Shoulder.L": (0, 0, 0), "UpperArm.L": (0, 0, -4), "Forearm.L": (0, 0, -12), "Hand.L": (0, 0, 0),
		"Shoulder.R": (0, 0, 0), "UpperArm.R": (0, 0, 4), "Forearm.R": (0, 0, 12), "Hand.R": (0, 0, 0),
		"Thigh.L": (0, 0, 0), "Shin.L": (0, 0, 0), "Foot.L": (0, 0, 0),
		"Thigh.R": (0, 0, 0), "Shin.R": (0, 0, 0), "Foot.R": (0, 0, 0),
	}


def arm_pose(side, upper, fore, hand=(0, 0, 0)):
	return {"UpperArm." + side: upper, "Forearm." + side: fore, "Hand." + side: hand}


def merge(*dicts):
	out = {}
	for d in dicts:
		out.update(d)
	return out


def clip(name, frames, extra_bones=()):
	return {"name": name, "frames": frames, "extra": list(extra_bones)}


CLIPS = {
	"rich": [
		clip("Idle", [
			(1, {"Chest": (-1.0, 0, 0), "Spine": (0.6, 0, 0), "Head": (0, 0, 3.0), "Hips": (0, 0, 0)}),
			(24, {"Chest": (1.2, 0, 0), "Spine": (-0.5, 0, -1.0), "Head": (1.4, 0, -2.0), "Neck": (-1.0, 0, 0)}),
			(48, {"Chest": (-1.0, 0, 0), "Spine": (0.6, 0, 0), "Head": (0, 0, 3.0)}),
		], ["Head", "Neck"]),
		clip("Counter", [
			(1, merge(arm_pose("L", (-52, 0, -16), (-56, 0, -30), (0, 0, -14)),
				{"Chest": (6.0, 0, -4.0), "Spine": (3.0, 0, 0), "Neck": (7.0, 0, -3.0), "Head": (10.0, 0, -6.0),
				 "Shoulder.L": (0, 0, -6), "Shoulder.R": (0, 0, -5),
				 "UpperArm.R": (-46, 0, 22), "Forearm.R": (-70, 0, 34), "Hand.R": (-16, 0, 12)})),
			(18, merge(arm_pose("L", (-52, 0, -16), (-56, 0, -30), (0, 0, -14)),
				{"Chest": (7.5, 0, -3.0), "Spine": (3.4, 0, 0), "Neck": (8.0, 0, -2.0), "Head": (12.0, 0, -4.0),
				 "Shoulder.L": (0, 0, -6), "Shoulder.R": (0, 0, -3),
				 "UpperArm.R": (-44, 0, 26), "Forearm.R": (-76, 0, 30), "Hand.R": (-10, 0, 6)})),
			(36, merge(arm_pose("L", (-52, 0, -16), (-56, 0, -30), (0, 0, -14)),
				{"Chest": (6.4, 0, -4.0), "Spine": (3.0, 0, 0), "Neck": (6.0, 0, -3.0), "Head": (8.0, 0, -7.0),
				 "Shoulder.L": (0, 0, -6), "Shoulder.R": (0, 0, -5),
				 "UpperArm.R": (-48, 0, 20), "Forearm.R": (-66, 0, 36), "Hand.R": (-20, 0, 16)})),
			(54, merge(arm_pose("L", (-52, 0, -16), (-56, 0, -30), (0, 0, -14)),
				{"Chest": (5.4, 0, -5.0), "Spine": (2.6, 0, 0.6), "Neck": (5.0, 0, -4.0), "Head": (6.0, 0, -8.0),
				 "Shoulder.L": (0, 0, -6), "Shoulder.R": (0, 0, -5),
				 "UpperArm.R": (-45, 0, 24), "Forearm.R": (-72, 0, 32), "Hand.R": (-14, 0, 10)})),
			(73, merge(arm_pose("L", (-52, 0, -16), (-56, 0, -30), (0, 0, -14)),
				{"Chest": (6.0, 0, -4.0), "Spine": (3.0, 0, 0), "Neck": (7.0, 0, -3.0), "Head": (10.0, 0, -6.0),
				 "Shoulder.L": (0, 0, -6), "Shoulder.R": (0, 0, -5),
				 "UpperArm.R": (-46, 0, 22), "Forearm.R": (-70, 0, 34), "Hand.R": (-16, 0, 12)})),
		]),
		clip("Greet", [
			(1, base_pose()),
			(10, merge(arm_pose("R", (-30, 0, 12), (-92, 0, 6), (-8, 0, 0)), {"Head": (-4, 0, -4), "Chest": (-2, 0, 3)})),
			(20, merge(arm_pose("R", (-38, 0, 8), (-106, 0, 2), (-14, 0, 0)), {"Head": (-7, 0, -2), "Chest": (-3, 0, 2)})),
			(30, merge(arm_pose("R", (-28, 0, 14), (-88, 0, 8), (-8, 0, 0)), {"Head": (-2, 0, -3), "Chest": (-1, 0, 2)})),
			(43, base_pose()),
		]),
		clip("Point", [
			(1, merge(arm_pose("R", (-40, 0, 30), (-30, 0, 20)), {"Chest": (0, 0, -6), "Head": (0, 0, -18)})),
			(21, merge(arm_pose("R", (-72, 0, 44), (-14, 0, 26)), {"Chest": (0, 0, -9), "Head": (0, 0, -24), "Neck": (0, 0, -6)})),
			(48, merge(arm_pose("R", (-40, 0, 30), (-30, 0, 20)), {"Chest": (0, 0, -6), "Head": (0, 0, -18)})),
		], ["Head", "Neck"]),
	],
	"utah": [
		clip("Idle", [
			(1, {"Chest": (-0.8, 0, 1.5), "Head": (0, 0, -4.0), "Hips": (0, 0, 0.8)}),
			(30, {"Chest": (1.0, 0, -0.5), "Spine": (0.6, 0, 0), "Head": (1.6, 0, 3.0), "Neck": (-0.8, 0, 0)}),
			(60, {"Chest": (-0.8, 0, 1.5), "Head": (0, 0, -4.0)}),
		], ["Head", "Neck"]),
		clip("Carry", [
			(1, merge(arm_pose("L", (-20, 0, 4), (-80, 0, -2)), {"Spine": (-6, 0, 0), "Chest": (-4, 0, 0), "Head": (5, 0, 0),
				"Thigh.L": (-6, 0, 0), "Thigh.R": (-6, 0, 0)})),
			(24, merge(arm_pose("L", (-22, 0, 6), (-84, 0, 0)), {"Spine": (-8, 0, 0), "Chest": (-6, 0, 0), "Head": (7, 0, 2),
				"Thigh.L": (-7, 0, 0), "Thigh.R": (-5, 0, 0), "Foot.L": (2, 0, 0)})),
			(48, merge(arm_pose("L", (-20, 0, 4), (-80, 0, -2)), {"Spine": (-6, 0, 0), "Chest": (-4, 0, 0), "Head": (5, 0, 0),
				"Thigh.L": (-6, 0, 0), "Thigh.R": (-6, 0, 0)})),
		], ["Head", "Neck", "Thigh.L", "Thigh.R", "Foot.L", "Foot.R"]),
		clip("Greet", [
			(1, base_pose()),
			(12, merge(arm_pose("R", (-30, 0, 12), (-92, 0, 6), (-8, 0, 0)), {"Head": (-5, 0, -5), "Chest": (-2, 0, 4)})),
			(22, merge(arm_pose("R", (-36, 0, 9), (-104, 0, 3), (-12, 0, 0)), {"Head": (-8, 0, -3), "Chest": (-3, 0, 3)})),
			(32, merge(arm_pose("R", (-28, 0, 14), (-88, 0, 8), (-6, 0, 0)), {"Head": (-3, 0, -4), "Chest": (-1, 0, 2)})),
			(45, base_pose()),
		]),
		clip("Point", [
			(1, merge(arm_pose("R", (-44, 0, 26), (-26, 0, 18)), {"Chest": (0, 0, -5), "Head": (0, 0, -16)})),
			(24, merge(arm_pose("R", (-78, 0, 40), (-10, 0, 24)), {"Chest": (0, 0, -8), "Head": (0, 0, -22), "Neck": (0, 0, -5)})),
			(52, merge(arm_pose("R", (-44, 0, 26), (-26, 0, 18)), {"Chest": (0, 0, -5), "Head": (0, 0, -16)})),
		], ["Head", "Neck"]),
	],
}

WALK = clip("Walk", [
	(1, merge(arm_pose("L", (-18, 0, 6), (-14, 0, -6)), arm_pose("R", (20, 0, 8), (-18, 0, 8)),
		{"Thigh.L": (24, 0, 0), "Shin.L": (-6, 0, 0), "Foot.L": (-8, 0, 0), "Hips": (0, 0, -6), "Spine": (2, 0, 4), "Chest": (0, 0, -3), "Head": (0, 0, 2)})),
	(7, merge(arm_pose("L", (-8, 0, 6), (-14, 0, -6)), arm_pose("R", (10, 0, 8), (-16, 0, 8)),
		{"Thigh.L": (6, 0, 0), "Shin.L": (-2, 0, 0), "Foot.L": (2, 0, 0), "Thigh.R": (-12, 0, 0), "Shin.R": (16, 0, 0), "Foot.R": (6, 0, 0),
		 "Hips": (0, 0, -2), "Spine": (3, 0, 2), "Chest": (0, 0, -1)})),
	(13, merge(arm_pose("R", (-18, 0, 8), (-14, 0, -6)), arm_pose("L", (20, 0, 6), (-18, 0, -8)),
		{"Thigh.R": (24, 0, 0), "Shin.R": (-6, 0, 0), "Foot.R": (-8, 0, 0), "Hips": (0, 0, 6), "Spine": (2, 0, -4), "Chest": (0, 0, 3), "Head": (0, 0, -2)})),
	(19, merge(arm_pose("R", (-8, 0, 8), (-14, 0, -6)), arm_pose("L", (10, 0, 6), (-16, 0, -8)),
		{"Thigh.R": (6, 0, 0), "Shin.R": (-2, 0, 0), "Foot.R": (2, 0, 0), "Thigh.L": (-12, 0, 0), "Shin.L": (16, 0, 0), "Foot.L": (6, 0, 0),
		 "Hips": (0, 0, 2), "Spine": (3, 0, -2), "Chest": (0, 0, 1)})),
	(25, merge(arm_pose("L", (-18, 0, 6), (-14, 0, -6)), arm_pose("R", (20, 0, 8), (-18, 0, 8)),
		{"Thigh.L": (24, 0, 0), "Shin.L": (-6, 0, 0), "Foot.L": (-8, 0, 0), "Hips": (0, 0, -6), "Spine": (2, 0, 4), "Chest": (0, 0, -3), "Head": (0, 0, 2)})),
], ["Head", "Neck", "Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Foot.L", "Foot.R", "Hips"])


def action_fcurves(act):
	"""Blender 4.4+ actions are layered (slots/channelbags); older ones expose .fcurves directly."""
	if hasattr(act, "fcurves"):
		try:
			return list(act.fcurves)
		except Exception:
			pass
	out = []
	for layer in getattr(act, "layers", []):
		for strip in getattr(layer, "strips", []):
			for bag in getattr(strip, "channelbags", []):
				out.extend(bag.fcurves)
	return out


def apply_clip(arm_ob, c):
	scene = bpy.context.scene
	act = bpy.data.actions.new(c["name"])
	act.use_fake_user = True
	arm_ob.animation_data_create()
	arm_ob.animation_data.action = act
	try:
		if hasattr(arm_ob.animation_data, "action_slot") and len(act.slots) == 0:
			arm_ob.animation_data.action_slot = act.slots.new(id_type="OBJECT", name="Rig")
	except Exception as exc:
		print("slot note:", exc)
	base = base_pose()
	for (frame, over) in c["frames"]:
		pose = dict(base)
		pose.update(over)
		scene.frame_set(int(frame))
		for bname, (rx, ry, rz) in pose.items():
			pb = arm_ob.pose.bones.get(bname)
			if pb is None:
				continue
			pb.rotation_mode = "XYZ"
			pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
			pb.keyframe_insert("rotation_euler", frame=frame)
	# ease the interpolation so movement reads soft rather than robotic
	for fc in action_fcurves(act):
		for kp in fc.keyframe_points:
			kp.interpolation = "BEZIER"
			kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
	arm_ob.animation_data.action = None
	return act


def build_clips(arm_ob, which):
	clips = list(CLIPS[which]) + [WALK]
	for c in clips:
		apply_clip(arm_ob, c)
	bpy.context.scene.frame_start = 1
	bpy.context.scene.frame_end = 73
	arm_ob.animation_data.action = bpy.data.actions[CLIPS[which][0]["name"]]


# ---------------------------------------------------------------- assembly

def make(name, palette, builder, height, which):
	for k, v in palette.items():
		mat(k, v[0], v[1], 0.0)
	j = S(height, girth=1.0 if which == "rich" else 0.96)
	f = Figure(name, height)
	builder(f, j)
	geo, groups = f.build()
	arm_ob = make_armature(name, j)
	skin(geo, arm_ob, groups, j)
	build_clips(arm_ob, which)
	return arm_ob, geo


def export(path, arm_ob, geo):
	"""Selection-only: the MCP addon leaves an Icosphere in the scene, so never export the scene."""
	bpy.ops.object.select_all(action="DESELECT")
	for ob in (arm_ob, geo):
		ob.select_set(True)
	bpy.context.view_layer.objects.active = arm_ob
	bpy.ops.export_scene.gltf(
		filepath=path, export_format="GLB", export_yup=True, export_apply=False,
		use_selection=True,
		export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
		export_influence_nb=4, export_def_bones=False, export_optimize_animation_size=False,
		export_bake_animation=False, export_frame_range=False,
	)
	print("wrote", os.path.basename(path), os.path.getsize(path))


if __name__ == "__main__":
	bpy.context.scene.render.fps = FPS
	if ONLY != "utah":
		bpy.ops.wm.read_factory_settings(use_empty=True)
		bpy.context.scene.render.fps = FPS
		MATS.clear()
		a, g = make("rich_armory", RICH_PAL, build_rich, 1.86, "rich")
		export(os.path.join(OUTDIR, "rich_armory.glb"), a, g)
	if ONLY != "rich":
		bpy.ops.wm.read_factory_settings(use_empty=True)
		bpy.context.scene.render.fps = FPS
		MATS.clear()
		a, g = make("utah_armory", UTAH_PAL, build_utah, 1.80, "utah")
		export(os.path.join(OUTDIR, "utah_armory.glb"), a, g)
	print("done")
