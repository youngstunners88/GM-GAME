extends Node
## Founder 2026-10-19: Rich & Utah's Armory as a two-storey building with real windows, a proper entry, dense weaponry and both men
## working in it, no horse inside, streamed so the main pack stays under its gate (skills ep2-armory-two-story, ep2-armory-npc-autonomy,
## ep2-tripo-folk-to-game). Guards: the building and its fit-out come from the extras GLB at the Bldg_Armory LAYOUT transform; two
## floors; clear glass; a door gap; the stair and gallery waypoints; walk blockers; the lamps; no horse in any building; the Treasury
## untouched; Rich and Utah (Tripo bodies + mocap clips) working on their own across both floors, never on the stair together, never
## inside a counter or case, Rich greeting Lil Blunt when he walks in; and the streaming loader's contract.
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [PASS] " if ok else "  [FAIL] ", label, "" if ok or detail.is_empty() else "  (" + detail + ")")
	if not ok:
		failures += 1


func _ready() -> void:
	# --- the streamed extras exist in the project and the loader treats them as loadable
	check("the extras (Armory GLB, Tripo Rich, Tripo Utah) are in res://src/episode2/extras/", Ep2Extras.has(Ep2Extras.ARMORY)
		and Ep2Extras.has(Ep2Extras.RICH) and Ep2Extras.has(Ep2Extras.UTAH))
	check("off the web the loader never downloads and reports ready", Ep2Extras.state() == "ready")
	var world := Node3D.new()
	add_child(world)
	var info: Dictionary = Ep2GoldTown.build(world, true)
	check("the town draws the two-storey Armory when the extras are loadable", Ep2GoldTown.armory_v2)
	var bld: Node3D = world.find_child("Bldg_Armory2", true, false) as Node3D
	check("Bldg_Armory2 stands at the Bldg_Armory LAYOUT transform (wherever that row is moved)", bld != null
		and bld.global_transform.origin.distance_to(Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory")).origin) < 0.01)
	check("the one-storey kit shop is not drawn as well", world.find_child("Bldg_Armory", true, false) == null)
	var fit: Node3D = world.find_child("Arm2_Fit_Bldg_Armory", true, false) as Node3D
	check("its fit-out is in the room (counter, cases, racks, Gatling, crates)", fit != null)
	# --- two floors, clear glass, door, weaponry
	var top: float = 0.0
	var glass: int = 0
	var tris_fit: int = 0
	for mi in bld.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		top = maxf(top, (m.get_aabb().position + m.get_aabb().size).y)
		for si in m.mesh.get_surface_count():
			var mat: BaseMaterial3D = m.mesh.surface_get_material(si) as BaseMaterial3D
			if mat != null and String(mat.resource_name) == "GlassClear":
				glass += 1
				check("the window glass is see-through (alpha, not a black hole)", mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
					and mat.albedo_color.a < 0.5, "alpha %.2f" % mat.albedo_color.a)
	check("two storeys: the false front stands above 9 m", top > 9.0, "top %.2f" % top)
	check("the windows are glazed", glass >= 1)
	for mi in fit.find_children("*", "MeshInstance3D", true, false):
		var am: ArrayMesh = (mi as MeshInstance3D).mesh as ArrayMesh
		for si in am.get_surface_count():
			tris_fit += am.surface_get_array_len(si) / 3 if am.surface_get_format(si) & Mesh.ARRAY_FORMAT_INDEX == 0 else am.surface_get_array_index_len(si) / 3
	check("dense weaponry and stock (the fit-out is a real set, not three boxes)", tris_fit > 8000, "%d tris" % tris_fit)
	# --- navigation data: two floors connected by the stair
	var sp: Dictionary = Ep2GoldTown.armory_spots
	check("the building carries its waypoints (>= 25)", sp.size() >= 25, "%d" % sp.size())
	check("the gallery is up a floor (stair_top at 3.8 m) and the counter on the ground", sp.has("stair_top") and absf((sp["stair_top"] as Vector3).y - 3.8) < 0.05
		and sp.has("counter_rich") and absf((sp["counter_rich"] as Vector3).y) < 0.01)
	check("the shop floor has walk blockers (counter, cases, stair, posts)", Ep2GoldTown.armory_blocks.size() >= 10)
	check("warm oil lamps hang in the shop", Ep2GoldTown.armory_lights.size() >= 4)
	# --- the door gap: the front wall leaves a 2 m doorway; walls exist on the other three sides
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	var door_pt: Vector2 = Vector2((xf * Vector3(0, 0, 0)).x, (xf * Vector3(0, 0, 0)).z)
	var walls: Array = info["walls"]
	var pushed: Vector2 = Ep2GoldTown.collide(door_pt, 0.3, walls, [])
	check("the doorway is open (nothing pushes a body standing in it)", pushed.distance_to(door_pt) < 0.01, str(pushed - door_pt))
	var in_wall: Vector2 = Vector2((xf * Vector3(-3.5, 0, 0)).x, (xf * Vector3(-3.5, 0, 0)).z)
	check("the front wall either side of the door is solid", Ep2GoldTown.collide(in_wall, 0.3, walls, []).distance_to(in_wall) > 0.05)
	var counter_pt: Vector3 = xf * Vector3(-0.9, 0, -4.85)          # just past the counter's customer-side edge
	check("the counter is solid (he walks round it, not through it)", Ep2GoldTown.collide(Vector2(counter_pt.x, counter_pt.z), 0.3, walls, []).distance_to(Vector2(counter_pt.x, counter_pt.z)) > 0.05)
	# --- no horse inside any building
	var inside_horse: Array = []
	for h in Ep2TownLife.HORSES:
		var hp := Vector3(float(h[0]), 0, float(h[1]))
		for e in Ep2GoldTown.LAYOUT:
			var pc: String = "Bldg_Armory2" if str(e[0]) == "Bldg_Armory" and Ep2GoldTown.armory_v2 else str(e[0])
			var fp: Array = Ep2GoldTown.FOOTPRINT.get(pc, [8.0, 9.0, 0.0])
			var lp: Vector3 = Ep2GoldTown.building_xform(e).affine_inverse() * hp
			if absf(lp.x) < float(fp[0]) * 0.5 + 0.5 and lp.z < 0.5 and lp.z > -float(fp[1]) - 0.5:
				inside_horse.append([h, pc])
	check("no horse stands inside the Armory or any other building", inside_horse.is_empty(), str(inside_horse))
	check("the Treasury is untouched (still its own shut sandstone bank)", Ep2GoldTown.FOOTPRINT["Bldg_Treasury"] == [10.0, 12.0, 0.0]
		and world.find_child("Bldg_Treasury", true, false) != null)
	# --- Rich and Utah at work (deterministic seeds, 6000 steps = 100 s)
	var holder := Node3D.new()
	world.add_child(holder)
	var rich := Ep2TownFolk.new()
	holder.add_child(rich)
	var utah := Ep2TownFolk.new()
	holder.add_child(utah)
	check("Rich's Tripo body loads with its clips", rich.setup(Ep2Extras.RICH, 1.80) and rich.has_clips())
	check("Utah's Tripo body loads with its clips", utah.setup(Ep2Extras.UTAH, 1.85) and utah.has_clips())
	var need: Array = ["idle", "walk", "stairsup", "greet", "counter", "wiperifle", "carry", "pickup", "putdown", "inspectrifle", "cigarpuff", "talk"]
	var have: Array = []
	for a in rich.anim_player().get_animation_list():
		have.append(str(a).to_lower().get_file())
	var missing: Array = need.filter(func(n): return not have.any(func(x): return x.ends_with(n)))
	check("they move on real mocap clips (walk, stairs, greet, counter, rifle work, carry, cigar, talk)", missing.is_empty(), str(missing))
	var rb := Ep2ArmoryBrain.new()
	rb.walk_speed = 0.76
	rb.setup("rich", rich, xf, sp, "counter_rich", 7101)
	var ub := Ep2ArmoryBrain.new()
	ub.walk_speed = 0.86
	ub.setup("utah", utah, xf, sp, "bench", 7202)
	var outside: Vector3 = xf * Vector3(0, 0, 6.0)
	var at_counter: int = 0
	var both_on_stair: int = 0
	var in_block: int = 0
	var first_bad: String = ""
	var utah_up: int = 0
	var clips_seen: Dictionary = {}
	var foot_ok: bool = true
	var stair_rect := Rect2(3.55, -8.0, 1.15, 5.6)          # x, z, w, d of the stair run (local)
	var dt: float = 1.0 / 60.0
	for i in 6000:
		rb.step(dt, outside)
		ub.step(dt, outside)
		var rl: Vector3 = xf.affine_inverse() * rich.position
		var ul: Vector3 = xf.affine_inverse() * utah.position
		if rl.distance_to(sp["counter_rich"]) < 0.4 or rl.distance_to(sp["counter_till"]) < 0.4 or rl.distance_to(sp["case_revolvers"]) < 0.4:
			at_counter += 1
		if stair_rect.has_point(Vector2(rl.x, rl.z)) and rl.y > 0.2 and stair_rect.has_point(Vector2(ul.x, ul.z)) and ul.y > 0.2:
			both_on_stair += 1
		if ul.y > 3.0:
			utah_up += 1
		for who_l in [rl, ul]:
			if (who_l as Vector3).y < 0.2:
				for bl in Ep2GoldTown.armory_blocks:
					var c: Vector2 = bl[0]
					var h: Vector2 = bl[1]
					var q := Vector2((who_l as Vector3).x, (who_l as Vector3).z)
					# the stair block is walkable for staff (it is the stair); the rest never
					if absf(q.x - c.x) < h.x - 0.05 and absf(q.y - c.y) < h.y - 0.05 and not stair_rect.grow(0.05).has_point(q):
						in_block += 1
						if first_bad == "":
							first_bad = "block %s at %s (%s -> spot %s, state %s)" % [str(c), str(q), "rich" if who_l == rl else "utah",
								rb.spot if who_l == rl else ub.spot, rb.state if who_l == rl else ub.state]
		clips_seen[rich.current_clip()] = true
		clips_seen[utah.current_clip()] = true
		if rich.position.y < -0.05 or utah.position.y < -0.05 or rich.position.y > 4.0 or utah.position.y > 4.0:
			foot_ok = false
	check("Rich keeps to his counter most of the time (> 55%)", at_counter > 3300, "%.0f%%" % (100.0 * at_counter / 6000.0))
	check("Utah works both floors (he goes up the stair to the gallery)", ub.visits_upstairs >= 1 and utah_up > 300, "visits %d, %d steps up" % [ub.visits_upstairs, utah_up])
	check("never both on the stair at once", both_on_stair == 0, "%d steps" % both_on_stair)
	check("never standing inside the counter, a case, the shelves or a post", in_block == 0, "%d steps; first: %s" % [in_block, first_bad])
	check("they stand on the floors (0 m or the 3.8 m gallery), never sink or float", foot_ok)
	check("they vary their work (>= 6 different clips in 100 s)", clips_seen.size() >= 6, str(clips_seen.keys()))
	# --- Lil Blunt walks in: Rich turns and greets him
	var greeted: Array = []
	rb.greeted.connect(func(w): greeted.append(w))
	var door_in: Vector3 = xf * Vector3(0.2, 0, -2.0)
	var t_greet: float = -1.0
	for i in 120:
		rb.step(dt, door_in)
		ub.step(dt, door_in)
		if t_greet < 0.0 and greeted.has("rich"):
			t_greet = float(i) * dt
	check("Rich greets Lil Blunt within 1.2 s of him stepping inside", t_greet >= 0.0 and t_greet <= 1.2, "t %.2f" % t_greet)
	world.queue_free()
	print("EP2_ARMORY2: ALL PASS" if failures == 0 else "EP2_ARMORY2: FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
