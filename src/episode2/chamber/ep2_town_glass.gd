class_name Ep2TownGlass
extends Node3D
## The town's window glass (New Shit 1122 P3-B, 2026-11-24): how it LOOKS and how it BREAKS. Ep2TownLaw keeps the rules
## (which ray hit which pane, the fines, broken_windows); this node keeps the look.
##
## The streamed kit is geometry only: every pane is a thin box on one "GlassDay" surface per building mesh. Nothing is rebuilt in
## Blender: at runtime that surface is split into panes (triangle clusters), the glass material is transparent, and a broken pane is
## removed from a per-building copy of the glass surface and replaced by a jagged hole in a cracked rim, while a handful of shards from
## ONE town-wide MultiMesh pool fall to the boardwalk. A pane breaks once per play session (BROKEN survives a town rebuild).

const GLASS_MAT := "GlassDay"
const BACKING_MAT := "Dark"
const GLASS_NAMES: Array[String] = ["GlassDay", "GlassClear"]     # the town kit's day glass; the two-storey Armory's clear glass
const SHARD_POOL := 48
const SHARDS_PER_BREAK := 8
const GRAVITY := 9.8

## "<piece>@<x>,<z>#<pane>" -> true for every pane broken this play session.
static var BROKEN: Dictionary = {}
static var _glass_mat: StandardMaterial3D = null
static var _backing_mat: StandardMaterial3D = null
static var _broken_tex: ImageTexture = null
static var _pane_cache: Dictionary = {}          # Mesh RID -> [surface index, panes]

var _shards: MultiMeshInstance3D = null
var _shard_state: Array = []                     # per shard: [pos, vel, spin_axis, angle, spin, floor_y, moving]
var _shard_next: int = 0
var _buildings: Dictionary = {}                  # building key -> {mi, surface, panes, broken:{}, glass_mi}
var breaks: int = 0


## Transparent window glass, a slight cool tint, sharp highlight, no depth pre-pass (Compatibility renders it as the web build does).
static func glass_material() -> StandardMaterial3D:
	if _glass_mat == null:
		var m := StandardMaterial3D.new()
		m.resource_name = GLASS_MAT
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.62, 0.74, 0.78, 0.24)
		m.roughness = 0.04
		m.metallic_specular = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass_mat = m
	return _glass_mat


## The room behind the glass of a building with no interior: a dim, warm, faintly lit back wall instead of a black hole.
static func backing_material() -> StandardMaterial3D:
	if _backing_mat == null:
		var m := StandardMaterial3D.new()
		m.resource_name = BACKING_MAT
		m.albedo_color = Color(0.25, 0.18, 0.12)
		m.roughness = 0.95
		m.emission_enabled = true
		m.emission = Color(0.30, 0.20, 0.11)
		m.emission_energy_multiplier = 0.35
		_backing_mat = m
	return _backing_mat


## Ep2GoldTown._apply_mats calls this with its material map so every kit copy (town, roads) draws the same glass.
static func dress_materials(mats: Dictionary) -> void:
	mats[GLASS_MAT] = glass_material()
	mats[BACKING_MAT] = backing_material()


static func key_for(piece: String, xf: Transform3D) -> String:
	return "%s@%d,%d" % [piece, roundi(xf.origin.x * 10.0), roundi(xf.origin.z * 10.0)]


func _ready() -> void:
	name = "TownGlass"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.11)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.78, 0.88, 0.92, 0.55)
	sm.roughness = 0.05
	sm.metallic_specular = 1.0
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = sm
	mm.mesh = q
	mm.instance_count = SHARD_POOL
	mm.visible_instance_count = 0
	_shards = MultiMeshInstance3D.new()
	_shards.name = "GlassShards"
	_shards.multimesh = mm
	_shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shards)
	_shards.top_level = true
	_shards.global_transform = Transform3D.IDENTITY


## Find the building's glass surface and split it into panes. Returns the street-front panes in the building's own frame
## (z = 0 is the front plane, +z faces the street): [{"pane": i, "centre": Vector3, "size": Vector2}]. Empty when no kit glass.
func register(key: String, building: Node3D, xf: Transform3D) -> Array:
	if building == null:
		return []
	var found: Array = _glass_surface(building)
	if found.is_empty():
		return []
	var mi: MeshInstance3D = found[0]
	var si: int = found[1]
	var panes: Array = found[2]
	var to_local: Transform3D = xf.affine_inverse() * mi.global_transform if mi.is_inside_tree() else Transform3D.IDENTITY
	if not mi.is_inside_tree():
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != building:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		to_local = t
	_buildings[key] = {"mi": mi, "surface": si, "panes": panes, "broken": {}, "glass_mi": null, "to_local": to_local}
	var out: Array = []
	for i in panes.size():
		var box: AABB = panes[i]["aabb"]
		var c: Vector3 = to_local * box.get_center()
		var sz: Vector3 = (to_local.basis * box.size).abs()
		# a street-front pane: thin along z, in the front wall, at least hand-sized (skips the door transoms' slivers too)
		if sz.z < minf(sz.x, sz.y) and c.z > -0.6 and sz.x >= 0.25 and sz.y >= 0.25:
			out.append({"pane": i, "centre": c, "size": Vector2(sz.x, sz.y)})
	for i in panes.size():
		if BROKEN.has("%s#%d" % [key, i]):
			(_buildings[key]["broken"] as Dictionary)[i] = true
	if not (_buildings[key]["broken"] as Dictionary).is_empty():
		_rebuild_glass(key)
		for i in (_buildings[key]["broken"] as Dictionary).keys():
			_add_broken_rim(key, int(i), Vector3.INF)
	return out


func is_broken(key: String, pane: int) -> bool:
	return BROKEN.has("%s#%d" % [key, pane])


## Break one pane where the round hit it: the pane leaves the glass, a jagged hole in a cracked rim stays in the frame, shards fall.
## False when it was already broken (the second round passes through).
func break_pane(key: String, pane: int, hit_point: Vector3, normal: Vector3) -> bool:
	var b: Dictionary = _buildings.get(key, {})
	if b.is_empty() or (b["broken"] as Dictionary).has(pane):
		return false
	(b["broken"] as Dictionary)[pane] = true
	BROKEN["%s#%d" % [key, pane]] = true
	breaks += 1
	_rebuild_glass(key)
	_add_broken_rim(key, pane, hit_point)
	_spawn_shards(hit_point, normal, (b["panes"][pane]["aabb"] as AABB), b)
	return true


## Advance the falling shards (Ep2TownLaw.step drives it, so headless tests and the game share one clock).
func step(delta: float) -> void:
	if _shards == null:
		return
	var mm: MultiMesh = _shards.multimesh
	for i in _shard_state.size():
		var s: Array = _shard_state[i]
		if not bool(s[6]):
			continue
		var pos: Vector3 = s[0]
		var vel: Vector3 = s[1]
		vel.y -= GRAVITY * delta
		pos += vel * delta
		s[3] = float(s[3]) + float(s[4]) * delta
		if pos.y <= float(s[5]):
			pos.y = float(s[5])
			s[6] = false
			s[3] = PI * 0.5                      # lies flat on the boards
		s[0] = pos
		s[1] = vel
		mm.set_instance_transform(i, Transform3D(Basis((s[2] as Vector3), float(s[3])), pos))


func moving_shards() -> int:
	var n: int = 0
	for s in _shard_state:
		n += 1 if bool(s[6]) else 0
	return n


# --- internals -------------------------------------------------------------------------------------------------------------

func _glass_surface(building: Node3D) -> Array:
	for node in building.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.has_meta("town_glass_copy"):
			continue
		var rid: RID = mi.mesh.get_rid()
		if _pane_cache.has(rid):
			var c: Array = _pane_cache[rid]
			if int(c[0]) >= 0:
				return [mi, int(c[0]), c[1]]
			continue
		var found: int = -1
		for si in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(si)
			if m != null and String(m.resource_name) in GLASS_NAMES:
				found = si
				break
		var panes: Array = _split_panes(mi.mesh, found) if found >= 0 else []
		_pane_cache[rid] = [found, panes]
		if found >= 0:
			return [mi, found, panes]
	return []


## Cluster the glass surface's triangles into panes: two triangles belong to one pane when their boxes touch.
static func _split_panes(mesh: Mesh, si: int) -> Array:
	var arrays: Array = mesh.surface_get_arrays(si)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for i in verts.size():
			idx.append(i)
	var tri_n: int = idx.size() / 3
	var boxes: Array = []
	for t in tri_n:
		var bb := AABB(verts[idx[t * 3]], Vector3.ZERO)
		bb = bb.expand(verts[idx[t * 3 + 1]]).expand(verts[idx[t * 3 + 2]])
		boxes.append(bb.grow(0.004))
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(tri_n)
	for t in tri_n:
		parent[t] = t
	for a in tri_n:
		for b in range(a + 1, tri_n):
			if (boxes[a] as AABB).intersects(boxes[b]):
				var ra: int = a
				while parent[ra] != ra:
					ra = parent[ra]
				var rb: int = b
				while parent[rb] != rb:
					rb = parent[rb]
				if ra != rb:
					parent[rb] = ra
	var groups: Dictionary = {}
	for t in tri_n:
		var r: int = t
		while parent[r] != r:
			r = parent[r]
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(t)
	var panes: Array = []
	for r in groups.keys():
		var tris: Array = groups[r]
		var bb: AABB = (boxes[tris[0]] as AABB).grow(-0.004)
		for t in tris:
			bb = bb.merge((boxes[t] as AABB).grow(-0.004))
		panes.append({"aabb": bb, "tris": tris})
	return panes


## A per-building copy of the glass surface without its broken panes; the kit surface is hidden on this building only.
func _rebuild_glass(key: String) -> void:
	var b: Dictionary = _buildings[key]
	var mi: MeshInstance3D = b["mi"]
	var si: int = int(b["surface"])
	var arrays: Array = mi.mesh.surface_get_arrays(si)
	var src_idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if src_idx.is_empty():
		for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			src_idx.append(i)
	var keep := PackedInt32Array()
	var panes: Array = b["panes"]
	for p in panes.size():
		if (b["broken"] as Dictionary).has(p):
			continue
		for t in panes[p]["tris"]:
			keep.append(src_idx[int(t) * 3])
			keep.append(src_idx[int(t) * 3 + 1])
			keep.append(src_idx[int(t) * 3 + 2])
	var gm: MeshInstance3D = b["glass_mi"]
	if gm == null:
		gm = MeshInstance3D.new()
		gm.name = "TownGlassCopy"
		gm.set_meta("town_glass_copy", true)
		gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(gm)
		var hide := StandardMaterial3D.new()
		hide.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hide.albedo_color = Color(0, 0, 0, 0)
		hide.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.set_surface_override_material(si, hide)
		b["glass_mi"] = gm
	var am := ArrayMesh.new()
	if not keep.is_empty():
		arrays[Mesh.ARRAY_INDEX] = keep
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(0, mi.mesh.surface_get_material(si))      # the same glass the rest of the building wears
	gm.mesh = am


## The jagged hole and cracked rim left in the frame, centred where the round went through (the pane's centre after a reload).
func _add_broken_rim(key: String, pane: int, hit_point: Vector3) -> void:
	var b: Dictionary = _buildings[key]
	var mi: MeshInstance3D = b["mi"]
	var box: AABB = b["panes"][pane]["aabb"]
	var size: Vector3 = box.size
	var thin_z: bool = size.z <= minf(size.x, size.y)
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x, size.y) if thin_z else Vector2(size.z, size.y)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _broken_texture()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_repeat = false
	var rim := MeshInstance3D.new()
	rim.name = "BrokenPane_%d" % pane
	rim.mesh = quad
	rim.material_override = mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(rim)
	rim.position = box.get_center()
	if not thin_z:
		rim.rotation.y = PI * 0.5
	if hit_point != Vector3.INF and rim.is_inside_tree():
		# slide the hole under the bullet: the texture is clamped, so the rim's edge glass fills the rest of the frame
		var local: Vector3 = rim.global_transform.affine_inverse() * hit_point
		var off := Vector2(local.x / quad.size.x, -local.y / quad.size.y).clamp(Vector2(-0.28, -0.28), Vector2(0.28, 0.28))
		mat.uv1_offset = Vector3(-off.x, -off.y, 0.0)
	rim.set_meta("pane", pane)


func _spawn_shards(at: Vector3, normal: Vector3, box: AABB, b: Dictionary) -> void:
	var mm: MultiMesh = _shards.multimesh
	var mi: MeshInstance3D = b["mi"]
	var floor_y: float = (mi.global_transform * Vector3(box.position.x, 0.0, box.position.z)).y + 0.03 if mi.is_inside_tree() else 0.03
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(at))
	for k in SHARDS_PER_BREAK:
		var i: int = _shard_next % SHARD_POOL
		_shard_next += 1
		var vel: Vector3 = normal * rng.randf_range(0.6, 2.4) + Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.2, 1.4), rng.randf_range(-0.9, 0.9))
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		if axis == Vector3.ZERO:
			axis = Vector3.UP
		var state: Array = [at + normal * 0.03, vel, axis, rng.randf_range(0.0, TAU), rng.randf_range(-14.0, 14.0), floor_y, true]
		if i < _shard_state.size():
			_shard_state[i] = state
		else:
			_shard_state.append(state)
		mm.set_instance_transform(i, Transform3D(Basis(axis, float(state[3])), state[0]))
	mm.visible_instance_count = mini(SHARD_POOL, maxi(mm.visible_instance_count, _shard_state.size()))


## 128 px: clear jagged hole, glass shards still in the frame, white crack lines radiating from the hole to the frame.
static func _broken_texture() -> ImageTexture:
	if _broken_tex != null:
		return _broken_tex
	var n: int = 128
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1122
	var spokes: Array = []
	for i in 11:
		spokes.append(TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / 11.0)
	for y in n:
		for x in n:
			var p := Vector2(float(x) - 63.5, float(y) - 63.5) / 63.5
			var a: float = atan2(p.y, p.x)
			var r: float = p.length()
			# hole radius: sharp spikes, never a circle
			var edge: float = 0.30 + 0.10 * absf(sin(a * 5.0 + 0.7)) + 0.07 * sin(a * 13.0 + 2.1) + 0.05 * sin(a * 23.0)
			if r < edge:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var crack: float = 0.0
			for s in spokes:
				var d: float = absf(wrapf(a - float(s), -PI, PI)) * r
				crack = maxf(crack, clampf(1.0 - d * 70.0, 0.0, 1.0))
			# a concentric crack ring a little outside the hole
			crack = maxf(crack, clampf(1.0 - absf(r - edge - 0.16) * 60.0, 0.0, 1.0) * 0.8)
			var rim: float = clampf(1.0 - (r - edge) * 18.0, 0.0, 1.0)
			var glass := Color(0.70, 0.80, 0.84, 0.26 + 0.18 * rim)
			image.set_pixel(x, y, glass.lerp(Color(0.95, 0.97, 0.98, 0.85), crack))
	_broken_tex = ImageTexture.create_from_image(image)
	return _broken_tex
