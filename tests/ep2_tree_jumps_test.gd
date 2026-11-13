extends Node
var failures: int = 0
var checks: int = 0
var w: WoodsQuadChamber
var capture: bool = false
func check(label: String, ok: bool) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("capture")
	await get_tree().process_frame
	w = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	add_child(w)
	w.setup(0, [], 0)
	w.set_physics_process(false)
	w.debug_invulnerable = true
	w._beat = w.Beat.RIDE
	w._begin_ride()
	var trees: Array = w.get_bears("road").filter(func(b): return b.routine() == "tree_jump")
	check("exactly three tree sections and thirteen original ground pickets", trees.size() == 3 and w.get_bears("road").size() == 16)
	var said: Array = []
	w.line_spoken.connect(func(id): said.append(id))
	for br in trees:
		var section: float = float(br.p["at"]) * w.PICKET_ROAD_LEN
		check("perch is elevated and inside woods", br.actor.position.y >= 5.0 and br.actor.position.z < w.FOREST_END_Z)
		var home: Vector3 = br.actor.position
		br.hear(home, 1000.0, "engine"); br.alarm(home); br.look(home, 1.0, false, 10.0)
		br.step(1.0, home)
		check("engine and sight cannot dislodge perch", br.actor.position.is_equal_approx(home) and br.tree_phase == "perch")
		w._riding = false; w._ride_s = section - 28.0
		w._quad.position = w._ride_sample(w._ride_s)[0]; w._hold = 0.0
		w._tick_tree_waves()
		check("no jump before ride", br.tree_phase == "perch")
		w._riding = true; w._ride_speed = 10.0
		w._player_pos = w._quad.position
		w._tick_bears(0.01)
		var eye: Vector3 = w._player_pos + Vector3(0, 2.3, 0)
		var aim: Vector3 = br.actor.position + Vector3(0, 1.1, 0)
		check("perched body is shootable through shared ray", w._bear_on_ray(eye, (aim-eye).normalized()) == br)
		w._tick_tree_waves()
		check("Inferno warns before each wave", br.tree_phase == "warning" and said.count("vo_bull_road_bows") == trees.find(br) + 1)
		br.step(0.6, w._player_pos)
		check("telegraph holds the visible perch", br.tree_phase == "warning" and br.actor.position.is_equal_approx(home))
		if capture:
			await shot("perch_%s" % br.display_name(), aim)
		br.step(0.61, w._player_pos)
		br.step(0.45, w._player_pos)
		check("air follows a continuous elevated arc toward road", br.tree_phase == "air" and br.actor.position.distance_to(home) > 0.5 and br.actor.position.y > 0.0)
		if capture:
			await shot("air_%s" % br.display_name(), br.actor.position + Vector3.UP)
		if trees.find(br) < 2:
			var strikes: Array = []
			br.swiped.connect(func(_b): strikes.append(1))
			var target: Vector3 = br._tree_to if trees.find(br) == 0 else br._tree_to + Vector3(10,0,0)
			for i in 120: br.step(1.0/60.0, target)
			check("landing contact checks range once", strikes.size() == (1 if trees.find(br) == 0 else 0) and br.tree_phase == "landed")
			check("landing remains on woods road", br.actor.position.y == 0.0 and br.actor.position.z < w.FOREST_END_Z)
		else:
			var kills: int = w.get_kills()
			br.set_meta("killed_by", "player")
			br.take_hit(eye)
			for i in 180: br.step(1.0/60.0, br._tree_to)
			var landed: Vector3 = br.actor.position
			br.step(4.0, br._tree_to)
			check("midair kill counts and corpse falls then stays", br.is_dead() and w.get_kills() == kills + 1 and landed.y == 0.0 and br.actor.position.is_equal_approx(landed))
		w._hold = 0.0; w._tick_tree_waves()
		check("section warning cannot repeat", said.count("vo_bull_road_bows") == trees.find(br) + 1)
	# Independent perch kill: cancel warning and falling corpse can never damage riders.
	var victim: Ep2BearBrain = trees[0]
	victim.aware = Ep2BearBrain.Aware.UNAWARE; victim.hp = 1
	victim.actor.position = victim.home; victim.tree_phase = "perch"
	var hit_count: Array = []
	victim.swiped.connect(func(_b): hit_count.append(1))
	victim.take_hit(w._player_pos)
	for i in 180: victim.step(1.0/60.0, victim.actor.position)
	check("perch kill falls and cancels damage", victim.is_dead() and victim.actor.position.y == 0.0 and hit_count.is_empty())
	victim.aware = Ep2BearBrain.Aware.UNAWARE; victim.hp = 1; victim.tree_phase = "perch"
	w._quad.position.z = w.FOREST_END_Z + 10.0; w._hold = 0.0
	w._tick_tree_waves()
	check("desert never triggers tree jump", victim.tree_phase == "perch")
	# Concurrency budget applies even if multiple section gates are artificially overlapped.
	w._quad.position = w._ride_sample(float(trees[0].p["at"]) * w.PICKET_ROAD_LEN - 28.0)[0]
	w._ride_s = float(trees[0].p["at"]) * w.PICKET_ROAD_LEN - 28.0
	trees[1].tree_phase = "air"
	w._tick_tree_waves()
	check("active jumper cap", victim.tree_phase == "perch")
	w._retry_from_surface()
	check("surface retry restores three perches and ordinary three hearts", w.get_bears("road").filter(func(b): return b.routine() == "tree_jump" and b.tree_phase == "perch" and not b.is_dead()).size() == 3 and w.get_health() == 3 and not w.is_riding())
	# Run the actual rail loop with its engine, ground pickets and speech contention.
	w.debug_invulnerable = true
	w._beat = w.Beat.RIDE
	w._begin_ride()
	var waves: Dictionary = {}
	var desert_jump: bool = false
	for frame in 10000:
		w.step(1.0 / 60.0)
		for b in w.get_bears("road"):
			if b.routine() == "tree_jump" and b.tree_phase in ["warning", "air", "landed"]:
				if not waves.has(b.display_name()):
					waves[b.display_name()] = w._quad.position.z
					desert_jump = desert_jump or w._quad.position.z >= w.FOREST_END_Z
		if w._ride_done: break
	check("actual rail ride triggers all three waves with ground combat and speech", waves.size() == 3)
	check("actual rail reaches dropoff without desert jumps or soft lock", w._ride_done and not desert_jump)
	w.queue_free()
	await get_tree().process_frame
	print("EP2_TREE_JUMPS: %d checks, %d failures" % [checks, failures])
	print("EP2_TREE_JUMPS: ALL PASS" if failures == 0 else "EP2_TREE_JUMPS: FAILED")
	get_tree().quit(0 if failures == 0 else 1)
func shot(label: String, target: Vector3) -> void:
	w._quad_yaw = float(w._ride_sample(w._ride_s)[1])
	w._quad.rotation.y = w._quad_yaw
	w._seat_riders()
	w.release_look()
	w._cam_goal_active = false
	var dir: Vector3 = target - (w._player_pos + Vector3(0, w.eye_height, 0))
	w._look_yaw = atan2(dir.x, dir.z)
	w._look_pitch = atan2(dir.y, Vector2(dir.x,dir.z).length())
	w._update_camera(0)
	w.get_camera().current = true
	print("CAPTURE ", label, " camera ", w.get_camera().position, " target ", target, " projection ", w.get_camera().unproject_position(target))
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://work/tree-jumps/%s.png" % label)
