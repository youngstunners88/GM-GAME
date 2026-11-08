extends Node
## Founder 2026-11-08 ("PROMPT_EPISODE2_ARMORY_REAL_WEAPONS_DISPLAY"): Rich & Utah's Armory is stocked with the founder's real weapon GLBs on
## both floors - racks, glass cases, the counter, the gallery - never grey placeholder sticks. Guards: the fit-out no longer carries any
## primitive gun (its GunWood / GunSteel materials are gone); every slot gets a gun; every gun wears its founder source GLB's own
## material (the same resource the Tabs showcase loads); both floors are stocked; the cases hold sidearms below their glass; scale stays
## within 0.95 - 1.05; the guns stay inside the web triangle budget and are not drawn from across town.
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _tris(m: Mesh) -> int:
	var am := m as ArrayMesh
	var t: int = 0
	for si in am.get_surface_count():
		t += am.surface_get_array_len(si) / 3 if am.surface_get_format(si) & Mesh.ARRAY_FORMAT_INDEX == 0 else am.surface_get_array_index_len(si) / 3
	return t


func _ready() -> void:
	check("the cut founder guns are in the streamed extras", Ep2Extras.has(Ep2Extras.RACK_GUNS))
	var world := Node3D.new()
	add_child(world)
	Ep2GoldTown.build(world, true)
	check("the two-storey Armory is drawn", Ep2GoldTown.armory_v2)
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	# --- no placeholder sticks: the fit-out's own mesh has no gun materials left
	var fit: Node3D = world.find_child("Arm2_Fit_Bldg_Armory", true, false) as Node3D
	var stick_mats: Array = []
	for mi in fit.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for si in m.get_surface_count():
			var mat: Material = m.surface_get_material(si)
			if mat != null and String(mat.resource_name) in ["GunWood", "GunSteel"]:
				stick_mats.append(String(mat.resource_name))
	check("no primitive (placeholder) gun is left in the fit-out", stick_mats.is_empty(), str(stick_mats))
	# --- every slot is filled with a founder gun
	var guns: Node3D = world.find_child("Arm2_Guns_Bldg_Armory", true, false) as Node3D
	check("the guns are placed", guns != null)
	if guns == null:
		_finish(world)
		return
	var list: Array = guns.find_children("*", "MeshInstance3D", true, false)
	var a2_slots: int = 0
	var ps: PackedScene = load(Ep2Extras.ARMORY) as PackedScene
	var a2: Node = ps.instantiate()
	a2_slots = a2.find_child("Arm2_Guns", true, false).get_child_count()
	a2.free()
	check("every gun slot holds a gun (>= 120 of them)", list.size() == a2_slots and list.size() >= 120, "%d of %d" % [list.size(), a2_slots])
	# --- each wears its founder source's own material (the same resource the showcase loads)
	var src_mats: Dictionary = {}
	for fam in Ep2ArmoryRacks.SOURCES:
		var mats: Dictionary = {}
		var model: Node = (load(str(Ep2ArmoryRacks.SOURCES[fam])) as PackedScene).instantiate()
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m: Mesh = (mi as MeshInstance3D).mesh
			for si in m.get_surface_count():
				if m.surface_get_material(si) != null:
					mats[m.surface_get_material(si)] = true
		model.free()
		src_mats[fam] = mats
	var foreign: Array = []
	var families: Dictionary = {}
	var up: int = 0
	var down: int = 0
	var bad_scale: Array = []
	var tris: int = 0
	var far: Array = []
	for g in list:
		var mi := g as MeshInstance3D
		var fam: String = String(mi.name).split("_")[2]
		families[fam] = true
		for si in mi.mesh.get_surface_count():
			if not (src_mats.get(fam, {}) as Dictionary).has(mi.mesh.surface_get_material(si)):
				foreign.append(String(mi.name))
				break
		var local: Vector3 = xf.affine_inverse() * mi.global_position
		if local.y > 3.7:
			up += 1
		else:
			down += 1
		var s: float = mi.transform.basis.get_scale().x
		if s < 0.95 or s > 1.05:
			bad_scale.append("%s %.2f" % [mi.name, s])
		tris += _tris(mi.mesh)
		if mi.visibility_range_end <= 0.0 or mi.visibility_range_end > 60.0:
			far.append(String(mi.name))
	check("every gun wears its founder GLB's own material", foreign.is_empty(), str(foreign.slice(0, 5)))
	check("the stock is varied (>= 10 founder families)", families.size() >= 10, str(families.keys()))
	check("the shop floor is stocked (>= 50 guns downstairs)", down >= 50, "%d" % down)
	check("the gallery is stocked (>= 50 guns upstairs)", up >= 50, "%d" % up)
	check("sizes vary a little, never a giant (scale 0.95 - 1.05)", bad_scale.is_empty(), str(bad_scale.slice(0, 5)))
	check("the guns fit the web budget (< 220k triangles in all)", tris < 220000, "%d" % tris)
	check("the guns are not drawn from across town", far.is_empty(), str(far.slice(0, 5)))
	# --- the cases: real sidearms on the felt, under the glass
	var in_cases: int = 0
	for g in list:
		var mi := g as MeshInstance3D
		var local: Vector3 = xf.affine_inverse() * mi.global_position
		if String(mi.name).begins_with("Gun_Near_") and absf(absf(local.x) - 3.2) < 0.8 and absf(local.z + 2.2) < 0.33:
			var aabb: AABB = mi.get_aabb()
			var lo: float = 1e9
			var hi: float = -1e9
			for k in 8:
				var y: float = (xf.affine_inverse() * (mi.global_transform * aabb.get_endpoint(k))).y
				lo = minf(lo, y)
				hi = maxf(hi, y)
			if lo > 0.80 and hi < 1.155:
				in_cases += 1
	check("both window cases show four real sidearms each, on the felt and under the glass", in_cases == 8, "%d" % in_cases)
	_finish(world)


func _finish(world: Node) -> void:
	world.queue_free()
	print("EP2_ARMORY_REAL_WEAPONS: ALL PASS" if failures == 0 else "EP2_ARMORY_REAL_WEAPONS: FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
