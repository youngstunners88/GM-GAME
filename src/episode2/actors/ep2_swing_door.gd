class_name Ep2SwingDoor
extends Node3D
## A DOORWAY'S LEAVES THAT SWING FOR WHOEVER GOES THROUGH (ep2-world-common-sense, founder 2026-11-05: "saloon doors don't swing;
## characters walk straight through them"). The one shared door behaviour for the town: the room passes in every body near the doorway
## each tick (Lil Blunt, the townspeople, the story cast) and each leaf is pushed open away from the side the walker came from, held
## open while he is in the doorway, then let go to swing back on its spring hinge - a batwing's few diminishing swings - and settle shut.
##
## The frame is the building's: x along the front, +z out of the door into the street, the leaves hinged at x = +/- half_w on the front
## plane. Pure logic plus two plain meshes; `step()` is driven by the room so a headless gate can walk people through it.

const OPEN_MAX := 1.45           # rad: a leaf pushed fully open stands nearly square to the wall
const REACH := 1.05              # m either side of the door plane where a walker starts pushing the leaf
const BODY := 0.34               # a walker's half-width for the leaf's sweep
const PUSH_RATE := 7.0           # rad/s: how fast a walker can shove a leaf open
const SPRING := 38.0             # the hinge spring (rad/s^2 per rad): back toward shut once let go
const DAMP := 2.6                # its damping: a few swings past centre, then still within about two seconds

var half_w: float = 0.95
var leaf_len: float = 0.91
var leaves: Array = []           # {"pivot": Node3D, "side": -1 | +1, "a": open angle (+ = swung in), "v": rad/s, "dir": 0 | +-1}
var pushes: int = 0              # times a leaf was pushed from shut (evidence for the gate: a door that never moves has 0)


## Hang a pair of batwing leaves (waist-high, the saloon's) in the doorway of `building` (its local frame, door centred at `door_x`).
## `wood` / `brass` are the building's own materials so the swinging leaves look like the ones the kit drew.
static func batwings(building: Node3D, half_width: float, wood: Material, brass: Material, door_x: float = 0.0) -> Ep2SwingDoor:
	var door := Ep2SwingDoor.new()
	door.name = "SwingDoor"
	door.half_w = half_width
	door.leaf_len = half_width - 0.04
	door.position = Vector3(door_x, 0.0, -0.028)
	building.add_child(door)
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "Leaf_%s" % ("L" if side < 0 else "R")
		pivot.position = Vector3(float(side) * (half_width - 0.02), 1.25, 0.0)
		door.add_child(pivot)
		var leaf := MeshInstance3D.new()
		leaf.name = "Board"
		var bm := BoxMesh.new()
		bm.size = Vector3(door.leaf_len, 0.95, 0.045)
		leaf.mesh = bm
		leaf.material_override = wood
		leaf.position = Vector3(-float(side) * door.leaf_len * 0.5, 0.0, 0.0)
		pivot.add_child(leaf)
		var knob := MeshInstance3D.new()
		knob.name = "Knob"
		var km := BoxMesh.new()
		km.size = Vector3(0.06, 0.06, 0.06)
		knob.mesh = km
		knob.material_override = brass
		knob.position = Vector3(-float(side) * (door.leaf_len - 0.05), 0.0, 0.03)
		pivot.add_child(knob)
		door.leaves.append({"pivot": pivot, "side": side, "a": 0.0, "v": 0.0, "dir": 0})
	return door


## Every body near this doorway this tick (world positions; y ignored). Call once per room tick.
func step(delta: float, bodies: Array) -> void:
	if delta <= 0.0 or leaves.is_empty():
		return
	var to_local: Transform3D = global_transform.affine_inverse() if is_inside_tree() else transform.affine_inverse()
	var locals: Array = []
	for b in bodies:
		var lp: Vector3 = to_local * (b as Vector3)
		if absf(lp.z) < leaf_len + BODY + 0.35 and absf(lp.x) < half_w + 0.8:
			locals.append(lp)
	for leaf in leaves:
		var side: float = float(leaf["side"])
		var hinge_x: float = side * (half_w - 0.02)
		var want: float = 0.0
		var dir: int = int(leaf["dir"])
		var touched: bool = false
		for lp in locals:
			# only a walker whose body overlaps this leaf's half of the doorway pushes it (a narrow walker on the far side pushes one)
			var from_hinge: float = (hinge_x - lp.x) * side          # 0 at the hinge, leaf_len at the leaf's tip
			if from_hinge < -BODY or from_hinge > leaf_len + BODY:
				continue
			var depth: float = absf(lp.z)
			var past: bool = dir != 0 and signf(lp.z) == -float(dir)      # through, on the side the leaf swung into
			if past:
				# held open until he is clear of the leaf's whole sweep, so it never swings back into his back
				var clear: float = leaf_len + BODY
				if depth > clear + 0.3:
					continue
				touched = true
				want = maxf(want, OPEN_MAX * clampf((clear + 0.3 - depth) / 0.3, 0.0, 1.0))
				continue
			if depth > REACH:
				continue
			touched = true
			if dir == 0:
				dir = 1 if lp.z > 0.0 else -1                         # the side he comes from: the leaf swings away from him
			# fully open by the time his body reaches the plane
			want = maxf(want, OPEN_MAX * clampf((REACH - depth) / (REACH - BODY), 0.0, 1.0))
		var a: float = float(leaf["a"])
		var v: float = float(leaf["v"])
		if touched:
			if absf(a) < 0.05 and int(leaf["dir"]) == 0:
				pushes += 1
			leaf["dir"] = dir
			var target: float = float(dir) * want                   # dir +1 (he came from the street) swings the leaf in: a > 0
			if absf(target) > absf(a) or signf(target) != signf(a):
				var na: float = move_toward(a, target, PUSH_RATE * delta)
				v = (na - a) / delta
				a = na
			else:
				# he is past the leaf: it is held where he leaves it and starts back as he clears it
				v += (-SPRING * (a - target) - DAMP * v) * delta
				a += v * delta
		else:
			leaf["dir"] = 0
			v += (-SPRING * a - DAMP * v) * delta
			a += v * delta
			if absf(a) < 0.002 and absf(v) < 0.01:
				a = 0.0
				v = 0.0
		a = clampf(a, -OPEN_MAX - 0.15, OPEN_MAX + 0.15)
		leaf["a"] = a
		leaf["v"] = v
		(leaf["pivot"] as Node3D).rotation.y = -side * a


## How far leaf `i` stands open (rad, + = into the room). The gate's measure of what a player sees.
func leaf_angle(i: int) -> float:
	return float(leaves[i]["a"]) if i >= 0 and i < leaves.size() else 0.0


## The wider of the two leaves' openings (rad, unsigned).
func open_amount() -> float:
	var m: float = 0.0
	for leaf in leaves:
		m = maxf(m, absf(float(leaf["a"])))
	return m


## Strip the leaves a kit baked INTO the building mesh (the streamed kit's saloon drew its batwings fixed half open): the triangles of
## `surface_names` whose centre lies inside the doorway volume `box` (building frame). A surface left empty keeps one degenerate triangle
## so every other surface keeps its index (and its material overrides). Returns the number of triangles removed.
static func strip_baked_leaves(building: Node3D, box: AABB, surface_names: Array) -> int:
	var removed: int = 0
	for mi_node in building.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi.mesh == null or mi.get_parent() is Ep2SwingDoor or mi.get_parent().get_parent() is Ep2SwingDoor:
			continue
		var xf: Transform3D = _relative(building, mi)
		var src: Mesh = mi.mesh
		var hits: Array = []
		for si in src.get_surface_count():
			var mat: Material = src.surface_get_material(si)
			hits.append(mat != null and mat.resource_name in surface_names)
		if not hits.has(true):
			continue
		var out := ArrayMesh.new()
		var any: bool = false
		for si in src.get_surface_count():
			var arrays: Array = src.surface_get_arrays(si)
			if bool(hits[si]):
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var keep := PackedInt32Array()
				for t in idx.size() / 3:
					var va: Vector3 = verts[idx[t * 3]]
					var vb: Vector3 = verts[idx[t * 3 + 1]]
					var vc: Vector3 = verts[idx[t * 3 + 2]]
					var cen: Vector3 = xf * ((va + vb + vc) / 3.0)
					if (vb - va).cross(vc - va).length_squared() > 1e-12 and box.has_point(cen):
						removed += 1
						any = true
						continue
					keep.append(idx[t * 3])
					keep.append(idx[t * 3 + 1])
					keep.append(idx[t * 3 + 2])
				if keep.is_empty():
					keep = PackedInt32Array([0, 0, 0])
				arrays[Mesh.ARRAY_INDEX] = keep
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(si, src.surface_get_material(si))
			out.surface_set_name(si, src.surface_get_name(si))
		if any:
			mi.mesh = out
	return removed


## The first material named `name` on any mesh under `n` (its active one: a room's dressing may override the kit's), or null.
static func find_material(n: Node, name: String) -> Material:
	for mi_node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(si)
			if m != null and m.resource_name == name:
				var active: Material = mi.get_active_material(si)
				return active if active != null else m
	return null


static func _relative(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
