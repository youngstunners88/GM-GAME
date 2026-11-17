extends Node
## Inspect the real drawn bills, including the cabin and hideout; the billboard cannot inflate the street census.
var failures: int = 0
var checks: int = 0
var counts := {"jack_hammer": 0, "rh": 0}
var areas := {"jack_hammer": 0.0, "rh": 0.0}
var armory_bills: Array[MeshInstance3D] = []
var armory_backings: Array[MeshInstance3D] = []

func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)

func census(node: Node) -> void:
	if node is MeshInstance3D and node.mesh is BoxMesh and node.get_parent().name == "WantedPosters":
		var arm_xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
		var at: Vector3 = arm_xf.affine_inverse() * node.global_position
		if absf(at.z - 0.023) < 0.001 and absf(at.x) < 5.0: armory_backings.append(node)
	if node is Sprite3D and node.texture != null and "poster_jack_hammer." in node.texture.resource_path:
		check("auction bill uses the official PNG", node.texture.resource_path.ends_with("poster_jack_hammer.png"))
		counts.jack_hammer += 1
		areas.jack_hammer += float(node.texture.get_width() * node.texture.get_height()) * node.pixel_size * node.pixel_size
	if node is MeshInstance3D and node.mesh is QuadMesh:
		var mat: StandardMaterial3D = node.material_override as StandardMaterial3D
		if mat != null and mat.albedo_texture != null:
			var path: String = mat.albedo_texture.resource_path
			for id in counts:
				if ("poster_" + id + ".") in path:
					counts[id] += 1
					var size: Vector2 = node.mesh.size
					areas[id] += size.x * size.y
					if id == "jack_hammer":
						check("Jack Hammer bill uses the official PNG: " + str(node.get_path()), path.ends_with("poster_jack_hammer.png"))
						check("official bill keeps square aspect and torn alpha", absf(size.x - size.y) < 0.002 and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
			if node.get_parent().name == "WantedPosters":
				var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
				var local: Vector3 = xf.affine_inverse() * node.global_position
				if absf(local.z - 0.04) < 0.001 and absf(local.x) < 5.0:
					armory_bills.append(node)
	for child in node.get_children(): census(child)

func _ready() -> void:
	var town: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(town)
	town.setup(0, [], 0)
	await get_tree().process_frame
	census(town)
	var world := Node3D.new()
	add_child(world)
	var cabin := Ep2LoganCabin.new()
	cabin.build(world)
	check("real cabin art built", cabin.ready_art)
	await HideoutDressing.build(world)
	var auction := Ep2AuctionHouse.new()
	world.add_child(auction)
	check("auction shell builds", not auction.build_next())
	auction.build_next()  # actual furnishing step hangs the canonical bill
	census(world)
	check("old JPEG cannot resolve", not ResourceLoader.exists(Ep2TownPosters.DIR + "poster_jack_hammer.jpg") and not FileAccess.file_exists(Ep2TownPosters.DIR + "poster_jack_hammer.jpg.import"))
	check("official source provenance matches founder hash", FileAccess.get_sha256("res://artifacts/episode2-gold-mine/references/founder_2026-11-05_jackhammer_wanted.jpg").begins_with("2f8056dc2537b898"))
	var tex: Texture2D = load(Ep2LoganCabin.JACK)
	check("official texture is 1024 square", tex.get_width() == 1024 and tex.get_height() == 1024)
	check("Jack Hammer outnumbers RH; some RH remains", counts.jack_hammer > counts.rh and counts.rh >= 1)
	check("Jack Hammer paper area is at least twice RH WITHOUT the range billboard", areas.jack_hammer >= 2.0 * areas.rh)
	print("CENSUS Jack Hammer=%d / %.4f m2; RH=%d / %.4f m2" % [counts.jack_hammer, areas.jack_hammer, counts.rh, areas.rh])
	check("largest saloon bill belongs to Jack Hammer", Ep2TownPosters.WALL[2][3] == "jack_hammer" and float(Ep2TownPosters.WALL[2][2]) >= 0.62)
	check("notice board gives Jack Hammer the large slot and RH the small slot", Ep2TownPosters.BOARD_BILLS[2][2] == "jack_hammer" and Ep2TownPosters.BOARD_BILLS[1][2] == "rh")
	check("Armory has three actual rendered bills", armory_bills.size() == 3)
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	for centre in [Vector3(-1.75, 1.6, 0.04), Vector3(1.8, 1.45, 0.04), Vector3(-4.6, 1.5, 0.04)]:
		var covered: bool = false
		for bill in armory_bills:
			if (xf.affine_inverse() * bill.global_position).distance_to(centre) < 0.001 and absf(bill.mesh.size.x - 0.42) < 0.001: covered = true
		check("Armory bill covers baked paper centre " + str(centre), covered)
	# Read the actual Paper surface in the founder Armory GLB: its roll is mirrored by Blender->Godot conversion.
	# Centre-only tests missed exposed corners; every baked vertex must project behind a real opaque backing.
	var baked: Node3D = load(Ep2Extras.ARMORY).instantiate()
	world.add_child(baked)
	var paper_vertices: int = 0
	var paper_covered: bool = armory_backings.size() == 3
	for mesh in baked.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var mat: Material = mesh.mesh.surface_get_material(surface)
			if mat == null or not "Paper" in mat.resource_name: continue
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var point: Vector3 = baked.to_local(mesh.to_global(vertex))
				if absf(point.z - 0.005) >= 0.006: continue
				paper_vertices += 1
				var covered: bool = false
				for backing in armory_backings:
					var local: Vector3 = backing.to_local(xf * point)
					var half: Vector3 = backing.mesh.size * 0.5
					if absf(local.x) <= half.x and absf(local.y) <= half.y and local.z < half.z: covered = true
				paper_covered = paper_covered and covered
	check("opaque backings hide every actual baked Paper corner", paper_vertices >= 72 and paper_covered)
	var clear: bool = true
	var walls: Dictionary = {}
	for row in Ep2TownPosters.WALL:
		var size := Vector2(float(row[2]), float(row[2]))
		if row[3] not in ["jack_hammer", "rh", "crypto_queen"]: size.y *= Ep2TownPosters.ASPECT_PAINTED
		var roll: float = float(row[4])
		var half := Vector2(absf(cos(roll)) * size.x + absf(sin(roll)) * size.y, absf(sin(roll)) * size.x + absf(cos(roll)) * size.y) * 0.5
		var rect := Rect2(Vector2(row[1].x, row[1].y) - half, half * 2.0)
		for other in walls.get(row[0], []):
			if rect.intersects(other): clear = false
		if not walls.has(row[0]): walls[row[0]] = []
		walls[row[0]].append(rect)
	check("no wall bills overlap (rotated building-local AABBs)", clear)
	town.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("EP2_WANTED_REBALANCE: %d checks, %d failed" % [checks, failures])
	get_tree().quit(failures)
