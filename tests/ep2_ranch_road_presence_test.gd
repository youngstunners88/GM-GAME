extends Node
var checks := 0
var failed := 0
func check(label: String,ok: bool) -> void:
	checks+=1
	if not ok: failed+=1
	print("[PASS] "+label if ok else "[FAIL] "+label)
func _ready() -> void:
	var town: GoldTownChamber=load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(town)
	town.setup()
	town.set_physics_process(false)
	var road: Node3D=town._visuals.find_child("LakeRoadSurvey",true,false)
	check("the surveyed lake road is visible on foot before any horse purchase",road!=null and road.is_visible_in_tree() and not town.horse_bought() and not town._depart_mounted)
	var trail: LakeTrailChamber=load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	add_child(trail)
	trail.setup()
	trail.set_physics_process(false)
	for name in ["LakeTrail","TownReturnRoad"]:
		var before: MeshInstance3D=road.get_node(name) if road!=null else null
		var after: MeshInstance3D=trail._road_survey.get_node(name)
		var equal: bool=before!=null
		if equal:
			var a: PackedVector3Array=before.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var b: PackedVector3Array=after.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			equal=a.size()==b.size()
			if equal:
				for i in a.size():
					if (before.global_transform*a[i]).distance_to(after.global_transform*b[i]+GoldTownChamber.DEPART_HORSE)>.0001:equal=false;break
		check(name+" every vertex maps exactly before and after mounting",equal)
		var mat_a: ShaderMaterial=before.material_override as ShaderMaterial if before!=null else null
		var mat_b: ShaderMaterial=after.material_override as ShaderMaterial
		var same_material: bool=mat_a!=null and mat_b!=null
		if same_material:
			same_material=mat_a.shader==mat_b.shader
			for texture in ["sand_tex","gravel_tex"]:
				same_material=same_material and mat_a.get_shader_parameter(texture)==mat_b.get_shader_parameter(texture)
		check(name+" uses the same dust and gravel surface across mounting",same_material)
	var before_origin: Vector3=road.global_position if road!=null else Vector3.ZERO
	trail.adopt_departure(town)
	check("the exact on-foot road instance travels with the retained town",road!=null and road.is_visible_in_tree() and road.global_position.distance_to(Vector3.ZERO)<.0001)
	check("mounting renders one road rather than overlapping copies",not trail._road_survey.visible and trail._visuals.get_node_or_null("DepartureTown")==null)
	trail.restore_departure()
	check("returning on foot restores the original survey origin",road!=null and road.global_position.distance_to(before_origin)<.0001 and road.is_visible_in_tree())
	check("standalone trail remains usable after returning town",trail._road_survey.visible)
	trail.free()
	town.free()
	print("EP2_RANCH_ROAD_PRESENCE: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
