class_name Ep2HammerLoadout
extends RefCounted
## What Jack Hammer's men carry, per zone - the ONE table (New Shit 1122 P3-C, 2026-11-24) - and how a Winchester man lets go of his
## rifle when he is shot.
##
## The riflemen are the founder's Hammer rifleman (river_assets/hammer_rifleman.glb, two baked poses: Idle = low ready, Draw = aimed),
## both hands on the 1886 in both poses (rifle_pose decision: route a, reuse - it passes the contact check by construction). The rifle is
## part of his mesh, so at death split_rifle() lifts the rifle's triangles out of the visible pose into their own node (no new asset in
## the pack): the body keeps its empty gripping hands, the rifle becomes the Ep2WeaponDrop's gun lying in the dirt. The capsule that
## selects the rifle was measured on the GLB (tools: p3/evidence/P3-C/cut.py, contact sheet cut9/sheet.png).

const RIFLEMAN_MODEL := "res://src/episode2/extras/river_assets/hammer_rifleman.glb"
## Muzzle in the aimed pose as a fraction of his height (measured in the bake; RiverCoverChamber.RIFLE_MUZZLE is the same point).
const RIFLE_MUZZLE := Vector3(-0.194, 0.836, 0.422)

## Lake trail: the gun each ambusher carries, by BANDIT_SPECS index (18 men; the chasing rider keeps his revolver). Riflemen are
## holdouts (they fight from their rock); the rushers (index % 5 in 1, 3) stay pistol men. Crew totals are unchanged.
const LAKE_TRAIL: Array = [
	Ep2ArmoryState.BORCH, Ep2ArmoryState.BORCH, Ep2ArmoryState.WIN, Ep2ArmoryState.BORCH, Ep2ArmoryState.BORCH, Ep2ArmoryState.WIN,
	Ep2ArmoryState.BORCH, Ep2ArmoryState.BORCH, Ep2ArmoryState.BORCH, Ep2ArmoryState.WIN, Ep2ArmoryState.BORCH, Ep2ArmoryState.BORCH,
	Ep2ArmoryState.WIN, Ep2ArmoryState.BORCH, Ep2ArmoryState.WIN, Ep2ArmoryState.BORCH, Ep2ArmoryState.BORCH, Ep2ArmoryState.WIN,
]
## The day-88 ridge: Hammer's watchers at their lookouts above the river, all Winchester men (RiverCoverChamber.WATCH_POSTS).
const RIDGE: Array = [Ep2ArmoryState.WIN, Ep2ArmoryState.WIN, Ep2ArmoryState.WIN]
## What a dead man's gun holds: one magazine / one tube.
const ROUNDS: Dictionary = {Ep2ArmoryState.BORCH: 8, Ep2ArmoryState.WIN: 6}

## The rifle in each baked pose, in the GLB's own units (model space, Y up): muzzle point, barrel direction (toward the muzzle).
const RIFLE_LINE: Dictionary = {
	"idle": [Vector3(-0.2008, 0.6059, 0.4089), Vector3(-0.3418, -0.4384, 0.8313)],
	"draw": [Vector3(-0.2008, 0.8310, 0.4202), Vector3(-0.3480, 0.0215, 0.9373)],
}
const RIFLE_RADIUS := 0.03          # a triangle whose three corners are all this close to the rifle's line is rifle
const RIFLE_BACK := 0.55            # the rifle runs this far behind its muzzle (butt plate)
const RIFLE_PAST := 0.01

static var _split_cache: Dictionary = {}       # "<mesh rid>" -> [body ArrayMesh, rifle ArrayMesh, rifle centre, basis]


static func gun_for(zone: Array, index: int) -> String:
	return str(zone[index]) if index >= 0 and index < zone.size() else Ep2ArmoryState.BORCH


static func rounds_for(gun: String) -> int:
	return int(ROUNDS.get(gun, 6))


## A Winchester man can be drawn only when the streamed rifleman is mounted; otherwise he is a pistol man (never an empty slot).
static func rifle_available() -> bool:
	return Ep2Extras.has(RIFLEMAN_MODEL)


## His muzzle in his own (folk) frame at `height`: where the flash and the glint belong, never his chest.
static func muzzle_local(height: float) -> Vector3:
	return RIFLE_MUZZLE * height


## Lift the rifle out of the dead man's visible pose. Returns the rifle as its own node (centred on the rifle, barrel along +z, at his
## scale), or null when he is not a rifleman. His body keeps everything else, hands included.
static func split_rifle(folk: Ep2TownFolk) -> Node3D:
	if folk == null or folk.model == null:
		return null
	var mi: MeshInstance3D = null
	for node in folk.model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).visible and RIFLE_LINE.has(String(node.name).to_lower()):
			mi = node
			break
	if mi == null or mi.mesh == null:
		return null
	var key: String = str(mi.mesh.get_rid().get_id())
	if not _split_cache.has(key):
		var line: Array = RIFLE_LINE[String(mi.name).to_lower()]
		_split_cache[key] = _split(mi.mesh, line[0], (line[1] as Vector3).normalized())
	var parts: Array = _split_cache[key]
	if parts.is_empty():
		return null
	mi.mesh = parts[0]
	var rifle := MeshInstance3D.new()
	rifle.name = "HammerWinchester"
	rifle.mesh = parts[1]
	# his size lives on the nodes above the mesh (the folk's height fit): the rifle keeps the size it had in his hands
	var s: float = mi.global_transform.basis.get_scale().y if mi.is_inside_tree() else absf(folk.model.scale.y)
	rifle.scale = Vector3(s, s, s)
	return rifle


static func _split(mesh: Mesh, muzzle: Vector3, d: Vector3) -> Array:
	var tip: Vector3 = muzzle + d * RIFLE_PAST
	var butt: Vector3 = muzzle - d * RIFLE_BACK
	var centre: Vector3 = (tip + butt) * 0.5
	var x: Vector3 = d.cross(Vector3.UP).normalized()
	var basis := Basis(x, d.cross(x), d)               # right-handed: x across, y up-ish, z along the barrel
	var to_rifle := Transform3D(basis, centre).affine_inverse()
	var body := ArrayMesh.new()
	var rifle := ArrayMesh.new()
	var found: int = 0
	for si in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for i in verts.size():
				idx.append(i)
		var near := PackedByteArray()
		near.resize(verts.size())
		var seg: Vector3 = tip - butt
		var seg_l2: float = seg.length_squared()
		for i in verts.size():
			var w: Vector3 = verts[i] - butt
			var t: float = clampf(w.dot(seg) / seg_l2, 0.0, 1.0)
			near[i] = 1 if (w - seg * t).length() < RIFLE_RADIUS else 0
		var keep := PackedInt32Array()
		var take := PackedInt32Array()
		for t in idx.size() / 3:
			var a: int = idx[t * 3]
			var b: int = idx[t * 3 + 1]
			var c: int = idx[t * 3 + 2]
			if near[a] == 1 and near[b] == 1 and near[c] == 1:
				take.append_array([a, b, c])
			else:
				keep.append_array([a, b, c])
		found += take.size() / 3
		var mat: Material = mesh.surface_get_material(si)
		if not keep.is_empty():
			var ba: Array = arrays.duplicate()
			ba[Mesh.ARRAY_INDEX] = keep
			body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ba)
			body.surface_set_material(body.get_surface_count() - 1, mat)
		if not take.is_empty():
			# only the rifle's own vertices, in the rifle's frame (so its bounds are the rifle, not the whole man)
			var remap: Dictionary = {}
			var order := PackedInt32Array()
			var ri := PackedInt32Array()
			for v in take:
				if not remap.has(v):
					remap[v] = order.size()
					order.append(v)
				ri.append(int(remap[v]))
			var ra: Array = []
			ra.resize(Mesh.ARRAY_MAX)
			var rv := PackedVector3Array()
			for v in order:
				rv.append(to_rifle * verts[v])
			ra[Mesh.ARRAY_VERTEX] = rv
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var nn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var rn := PackedVector3Array()
				for v in order:
					rn.append((to_rifle.basis * nn[v]).normalized())
				ra[Mesh.ARRAY_NORMAL] = rn
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var ru := PackedVector2Array()
				for v in order:
					ru.append(uv[v])
				ra[Mesh.ARRAY_TEX_UV] = ru
			if arrays[Mesh.ARRAY_COLOR] != null:
				var col: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var rc := PackedColorArray()
				for v in order:
					rc.append(col[v])
				ra[Mesh.ARRAY_COLOR] = rc
			ra[Mesh.ARRAY_INDEX] = ri
			rifle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ra)
			rifle.surface_set_material(rifle.get_surface_count() - 1, mat)
	if found == 0:
		return []
	return [body, rifle]
