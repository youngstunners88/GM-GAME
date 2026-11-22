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
	# Founder 2026-11-22 (images 1 and 3, "sand on the green trail", repeat): the town's desert floor rode along at the trail floor's height.
	var town_floor: MeshInstance3D=town._visuals.get_node_or_null(LakeTrailChamber.TOWN_FLOOR) as MeshInstance3D
	var trail_floor: MeshInstance3D=trail._visuals.get_node_or_null("TrailDesertFloor") as MeshInstance3D
	check("one floor under the ride: the town's desert floor is not drawn on the trail",town_floor!=null and not town_floor.is_visible_in_tree())
	var tf: AABB=trail_floor.global_transform*trail_floor.get_aabb() if trail_floor!=null else AABB()
	var gf: AABB=town_floor.global_transform*town_floor.get_aabb() if town_floor!=null else AABB(Vector3.ONE*1e6,Vector3.ONE)
	check("...and the trail's floor covers all of the town's ground (nothing goes bare)",trail_floor!=null and tf.position.x<=gf.position.x and tf.position.z<=gf.position.z and tf.end.x>=gf.end.x and tf.end.z>=gf.end.z)
	var sand_on_green: Array=[]
	var ground: Array=[]
	for n in trail._visuals.find_children("*","MeshInstance3D",true,false):
		var mi: MeshInstance3D=n as MeshInstance3D
		var m: BaseMaterial3D=mi.material_override as BaseMaterial3D
		if m==null or m.albedo_texture==null or not "tex_desert" in m.albedo_texture.resource_path or not mi.is_visible_in_tree():continue
		var box: AABB=mi.global_transform*mi.get_aabb()
		if box.size.y<0.3 and box.size.x>20.0 and box.size.z>20.0:ground.append([mi,box])
	var s: float=Ep2LakeRoad.GREEN_FROM_S
	while s<=trail._route_total:
		var at: Array=trail._route_sample(s)
		var side := Vector3(-cos(float(at[1])),0.0,sin(float(at[1])))
		for off in [-25.0,-10.0,0.0,10.0,25.0]:
			var p: Vector3=(at[0] as Vector3)+side*off
			for g in ground:
				var box: AABB=g[1]
				if p.x>box.position.x and p.x<box.end.x and p.z>box.position.z and p.z<box.end.z:sand_on_green.append("%s at s %.0f off %.0f"%[(g[0] as Node).name,s,off])
		s+=10.0
	print("  sand-textured ground under the green stretch: %d %s"%[sand_on_green.size(),str(sand_on_green.slice(0,3))])
	check("no sand-albedo ground within 25 m of the road on the green stretch (s %.0f to the shore)"%Ep2LakeRoad.GREEN_FROM_S,sand_on_green.is_empty())
	trail.restore_departure()
	check("...and back on foot the town has its own floor again",town_floor!=null and town_floor.is_visible_in_tree())
	check("returning on foot restores the original survey origin",road!=null and road.global_position.distance_to(before_origin)<.0001 and road.is_visible_in_tree())
	check("standalone trail remains usable after returning town",trail._road_survey.visible)
	trail.free()
	town.free()
	print("EP2_RANCH_ROAD_PRESENCE: %d checks, %d failed"%[checks,failed])
	get_tree().quit(failed)
