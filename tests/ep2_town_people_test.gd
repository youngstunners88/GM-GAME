extends Node
## Founder 2026-10-19: the town has no townsmen and townswomen, and its windows and doors are blank boards. Guards (a) the streamed
## kit's openings are REAL holes (a ray through each window and door centre meets no wall triangle; glass and frames are there) and
## (b) the five townspeople walk the street on routes clear of every prop and wall, pause, greet Lil Blunt, and are not in lock-step.
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


## Does a vertical ray (along -z) at local (x, y) starting in front of the wall hit a triangle of any `wall_mats` surface within `reach` m?
func _wall_hit(root: Node3D, wall_mats: Array, x: float, y: float, reach: float) -> bool:
	var from := Vector3(x, y, 1.0)
	var dir := Vector3(0, 0, -1)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var inv: Transform3D = root.global_transform.affine_inverse() * m.global_transform
		for si in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(si)
			if mat == null or not (String(mat.resource_name) in wall_mats):
				continue
			var arr: Array = m.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n: int = idx.size() if idx.size() > 0 else vs.size()
			for t in range(0, n, 3):
				var a: Vector3 = inv * vs[idx[t] if idx.size() > 0 else t]
				var b: Vector3 = inv * vs[idx[t + 1] if idx.size() > 0 else t + 1]
				var c: Vector3 = inv * vs[idx[t + 2] if idx.size() > 0 else t + 2]
				var hit: Variant = Geometry3D.ray_intersects_triangle(from, dir, a, b, c)
				if hit != null and (hit as Vector3).distance_to(from) < 1.0 + reach:
					return true
	return false


func _ready() -> void:
	check("the extras (kit with openings, five townspeople) are in the project", Ep2Extras.has(Ep2Extras.TOWN_KIT) and Ep2Extras.has(Ep2Extras.PEOPLE_DIR + "townsman_clerk.glb"))
	# ---- (a) openings are real
	var kit: Node3D = (load(Ep2Extras.TOWN_KIT) as PackedScene).instantiate() as Node3D
	add_child(kit)
	var wall_mats: Array = ["Siding", "Sandstone", "PaintWhite_wall"]
	var specs: Array = [
		["Bldg_Certificates", [Vector2(-2.7, 1.6), Vector2(2.7, 1.6), Vector2(0.0, 1.2)], ["Siding"]],
		["Bldg_Saloon", [Vector2(-4.7, 1.6), Vector2(4.7, 1.6), Vector2(0.0, 1.2)], ["Siding"]],
		["Bldg_Treasury", [Vector2(-3.2, 1.6), Vector2(3.2, 1.6), Vector2(0.0, 1.3)], ["Sandstone"]],
		["Bldg_B", [Vector2(-2.7, 1.6), Vector2(2.7, 1.6)], ["Siding"]],
		["Bldg_D", [Vector2(-3.2, 1.6), Vector2(3.2, 1.6)], ["Siding"]],
		["Bldg_A", [Vector2(-2.2, 1.6), Vector2(2.2, 1.6)], ["Siding"]],
	]
	for sp in specs:
		var b: Node3D = kit.find_child(str(sp[0]), true, false) as Node3D
		check("%s exists in the kit" % sp[0], b != null)
		if b == null:
			continue
		var open_ok: bool = true
		for pt in sp[1]:
			if _wall_hit(b, sp[2], (pt as Vector2).x, (pt as Vector2).y, 0.25):
				open_ok = false
		check("%s: a ray through each window and the doorway meets no wall (the openings are real holes)" % sp[0], open_ok)
		var glass: int = 0
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			var mm := (mi as MeshInstance3D).mesh
			for si in mm.get_surface_count():
				var mat: Material = mm.surface_get_material(si)
				if mat != null and String(mat.resource_name) in ["GlassDay", "GlassClear", "Glass"]:
					glass += mm.surface_get_array_len(si) / 24
		check("%s: window glass and frames are modelled (>= 5 panes)" % sp[0], glass >= 5, "%d" % glass)
	# a solid wall still blocks (the test can fail): a ray at a wall-only spot of the Certificates front meets siding
	var cert: Node3D = kit.find_child("Bldg_Certificates", true, false) as Node3D
	check("control: a ray at a wall-only point DOES hit the wall (the check can fail)", _wall_hit(cert, ["Siding"], -3.7, 3.0, 0.25))
	kit.queue_free()
	# ---- (b) the people
	var world := Node3D.new()
	add_child(world)
	var info: Dictionary = Ep2GoldTown.build(world, true)
	check("the town draws the improved kit when the extras are loadable", Ep2GoldTown.kit_v2)
	var holder := Node3D.new()
	world.add_child(holder)
	var tp := Ep2TownPeople.new()
	tp.configure_space(info)
	var n: int = tp.build(holder, 4101)
	check("all supplied public townspeople are placed", n == Ep2TownPeople.ROSTER.size(), "%d" % n)
	var walls: Array = info["walls"]
	var props: Array = info["props"]
	var bad_route: Array = []
	for r in Ep2TownPeople.ROSTER:
		var pts: Array = r["route"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var bb: Vector2 = pts[i + 1]
			for k in 21:
				var q: Vector2 = a.lerp(bb, float(k) / 20.0)
				if Ep2GoldTown.collide(q, 0.35, walls, props).distance_to(q) > 0.02:
					bad_route.append("%s %s" % [r["id"], str(q)])
					break
	check("every route is clear of every wall, rail, horse, trough, wagon and lamp (0.35 m body)", bad_route.is_empty(), str(bad_route))
	var far := Vector3(60.0, 0.0, 1300.0)
	var dt: float = 1.0 / 60.0
	var bad_pos: int = 0
	var started: Dictionary = {}
	for i in 7200:
		tp.step(dt, far)
		for p in tp.people:
			var pos: Vector3 = (p as Ep2TownPeople.Person).folk.position
			var q := Vector2(pos.x, pos.z)
			var shopping: bool = (p as Ep2TownPeople.Person).state in Ep2TownPeople.SHOP_STATES     # scripted shop visit: porch / indoors, heights legal
			if is_nan(pos.x) or (not shopping and (Ep2GoldTown.collide(q, 0.30, walls, props).distance_to(q) > 0.05 or absf(pos.y) > 0.06)) or (shopping and (pos.y < -0.01 or (pos.y > 0.5 and absf(pos.y - Ep2GoldTown.BALCONY_Y) > 0.05))):   # the saloon balcony's drinkers sit 3.98 m up          # the walking bob lifts a figure up to 3.5 cm
				bad_pos += 1
			if i < 3000 and (p as Ep2TownPeople.Person).state == "walk" and not started.has((p as Ep2TownPeople.Person).id):
				started[(p as Ep2TownPeople.Person).id] = i
	check("in 120 s nobody ever stands inside a wall or prop, or off the ground", bad_pos == 0, "%d" % bad_pos)
	var walkers: int = 0
	for p in tp.people:
		print("TOWN_TRAVEL ", p.id, " metres=", p.walked_m, " state=", p.state, " destination=", p.destination, " position=", p.folk.position, " recoveries=", p.recoveries)
		if (p as Ep2TownPeople.Person).walked_m > 12.0:
			walkers += 1
	# the two balcony regulars sit drinking over the street all day (founder 2026-10-24); everyone else walks it
	var street_cast: int = Ep2TownPeople.ROSTER.size() - Ep2TownPeople.BALCONY_REGULARS.size()
	check("they really walk the street (every one covers > 12 m in 120 s; the balcony regulars sit)", walkers >= street_cast, "%d of %d" % [walkers, street_cast])
	var starts: Array = started.values()
	starts.sort()
	check("they are not in lock-step (their first steps are spread over > 2 s)", starts.size() >= 4 and float(starts[starts.size() - 1] - starts[0]) * dt > 2.0, str(starts))
	# greeting: put Lil Blunt beside the clerk
	var clerk: Ep2TownPeople.Person = tp.people[0] as Ep2TownPeople.Person
	var near: Vector3 = clerk.folk.position + Vector3(1.6, 0.0, 0.0)
	for i in 240:
		tp.step(dt, near)
	check("a townsman turns and greets Lil Blunt when he comes close", clerk.greets >= 1, "%d" % clerk.greets)
	var g0: int = clerk.greets
	for i in 600:
		tp.step(dt, near)
	check("and does not greet him again every step (cooldown)", clerk.greets - g0 <= 1, "%d" % (clerk.greets - g0))
	world.queue_free()
	print("EP2_TOWN_PEOPLE: ALL PASS" if failures == 0 else "EP2_TOWN_PEOPLE: FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
