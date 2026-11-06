extends Node
## Evidence for the founder's five common-sense reports (2026-11-05, skill ep2-world-common-sense): each action as a SEQUENCE in the real
## Compatibility renderer, the real chambers stepped by this script, an observer camera of its own so the whole route shows:
##   1. townsfolk walking past Mike Dean while he kneels (top-down-ish and street level)
##   2. Inferno back on his quad, meeting Lil Blunt at the body: hello, what happened, the whiskey, off to the saloon
##   3. the saloon's batwings swinging as a townsman goes through, then settling
##   4. a shot raft man going over the side into the river, the raft going on
##   5. a raft taking hits and breaking up
##   xvfb-run -a -s "-screen 0 1280x720x24" .godot-cache/Godot_v4.3-stable_linux.x86_64 --rendering-driver opengl3 \
##     --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 res://tools/ep2_shots/common_sense_shot.tscn -- out=<dir>
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const RIVER := preload("res://src/episode2/chamber/river_cover.tscn")
var out := ".farm/common_sense"
var vp: SubViewport
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var only: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	if only in ["", "town"]:
		await _town_shots()
	if only in ["", "river"]:
		await _river_shots()
	print("COMMON_SENSE_SHOT: done ", out)
	get_tree().quit(0)


func _observer(parent: Node) -> void:
	cam = Camera3D.new()
	cam.name = "ObserverCam"
	cam.fov = 55.0
	parent.add_child(cam)
	cam.current = true


func _grab(label: String, from: Vector3, to: Vector3) -> void:
	cam.current = true
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	for frame in 3:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), 0.82)


func _step_town(c: GoldTownChamber, seconds: float, each: Callable = Callable()) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)
		if each.is_valid():
			each.call()


func _town_shots() -> void:
	var c: GoldTownChamber = TOWN.instantiate()
	vp.add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	c.set_process(false)
	c.set_physics_process(false)
	_observer(c)
	# the draw is won: the stranger down at his mark, Mike Dean kneeling by him
	var opp: Ep2TownFolk = c.get_opponent()
	opp.position = GoldTownChamber.OPP_MARK
	opp.fall_dead()
	var kneel: Vector3 = opp.position + GoldTownChamber.KNEEL_AT
	var mike: Ep2TownFolk = c.get_minister()
	mike.visible = true
	mike.position = kneel
	mike.face_point(opp.position)
	c._minister_task = "kneeling"
	c._minister_t = 3.0
	if c.minister_rigged():
		mike.hold_clip("Kneel")
	c._advance_to(GoldTownChamber.Beat.LOOT)
	c._won_t = -1000.0
	c._got_peacemaker = true
	c._player_pos = kneel + Vector3(-5.0, 0.0, -7.0)
	var ppl: Ep2TownPeople = c.get_people()
	var k2 := Vector2(kneel.x, kneel.z)
	var routes: Array = [[Vector2(0.0, -9.0), Vector2(0.0, 9.0)], [Vector2(0.4, 8.0), Vector2(-0.3, -8.0)], [Vector2(-4.0, 0.2), Vector2(4.0, -0.2)],
		[Vector2(4.0, 0.6), Vector2(-4.0, 0.0)], [Vector2(-0.6, -7.0), Vector2(0.8, 7.0)]]
	for i in mini(routes.size(), ppl.people.size()):
		var p = ppl.people[i]
		var a: Vector2 = ppl.navigation.closest(k2 + routes[i][0])
		var b: Vector2 = ppl.navigation.closest(k2 + routes[i][1])
		p.folk.position = Vector3(a.x, 0.0, a.y)
		p.state = "walk"
		p.destination = ""
		p.waypoints = ppl.navigation.path(a, b)
	var hold := func() -> void:
		c._minister_task = "kneeling"
		mike.position = kneel
	for k in 8:
		await _grab("1_minister_%02d_high" % k, kneel + Vector3(7.0, 9.0, 7.0), kneel)
		await _grab("1_minister_%02d_street" % k, kneel + Vector3(-7.5, 1.6, 1.0), kneel + Vector3(0.0, 0.6, 0.0))
		_step_town(c, 1.6, hold)
	# 2. Inferno rides back in; Lil Blunt stands at the body with Mike Dean
	var lb: Vector3 = kneel + Vector3(-1.8, 0.0, 2.6)
	c._player_pos = lb
	c._advance_to(GoldTownChamber.Beat.BULL_BACK)
	var bull: Ep2Actor = c.get_bull()
	var k: int = 0
	var t: float = 0.0
	var next_t: float = 0.0
	var seen_drinks: bool = false
	while t < 150.0:
		if c.get_beat_name() in ["BULL_BACK", "BODY"]:
			c._player_pos = lb
		else:
			c._player_pos = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT)
		if t >= next_t and k < 40:
			var focus: Vector3 = bull.position + Vector3(0.0, 1.2, 0.0)
			var talking: bool = c._bull_task in ["greeted", "at_body"] or (c._bull_task == "to_lb" and bull.position.distance_to(lb) < 4.0)
			if talking:
				# Lil Blunt's own eye at the body: Inferno, Mike Dean and the fallen stranger in one frame
				var mid: Vector3 = (bull.position + kneel) * 0.5
				var back: Vector3 = (lb - mid)
				back.y = 0.0
				await _grab("2_inferno_%02d_%s_%s_eye" % [k, c.get_beat_name().to_lower(), c._bull_task], lb + back.normalized() * 2.2 + Vector3(0.0, 1.9, 0.0), mid + Vector3(0.0, 1.0, 0.0))
			else:
				await _grab("2_inferno_%02d_%s_%s" % [k, c.get_beat_name().to_lower(), c._bull_task], Vector3(focus.x + 9.0, 14.0, focus.z + 11.0), focus)
			k += 1
			next_t = t + (2.5 if talking else 4.0)
		_step_town(c, 0.25, hold)
		t += 0.25
		if c.get_beat_name() == "DRINKS" and c._bull_task == "at_bar":
			seen_drinks = true
			break
	print("  inferno sequence: %d frames, reached the bar %s" % [k, str(seen_drinks)])
	# 3. the saloon's batwings: a townsman walks in through them, then they settle
	var walker: Ep2TownFolk = ppl.people[6].folk
	ppl.people[6].state = "pause"
	ppl.people[6].timer = 600.0
	var out_p: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 2.6)
	var in_p: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", -2.4)
	c._player_pos = Ep2GoldTown.door_world("Bldg_Saloon", 9.0) + Vector3(0.0, 0.0, 0.0)
	var side_cam: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 3.4) + Vector3(0.0, 1.5, 0.0)
	var dx: Vector3 = (Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(1.0, 0.0, 0.0)) - Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3.ZERO)).normalized()
	side_cam += dx * 2.2
	walker.face_point(in_p)
	for f in 14:
		walker.position = out_p.lerp(in_p, float(f) / 10.0) if f <= 10 else in_p + (in_p - out_p).normalized() * 0.3 * float(f - 10)
		_step_town(c, 0.3)
		walker.position = out_p.lerp(in_p, minf(float(f) / 10.0, 1.0)) if f <= 10 else walker.position
		await _grab("3_door_%02d_walk" % f, side_cam, Ep2GoldTown.door_world("Bldg_Saloon", 0.0) + Vector3(0.0, 1.2, 0.0))
	walker.position = in_p + (in_p - out_p).normalized() * 4.0
	for f in 6:
		_step_town(c, 0.35)
		await _grab("3_door_%02d_settle" % (14 + f), side_cam, Ep2GoldTown.door_world("Bldg_Saloon", 0.0) + Vector3(0.0, 1.2, 0.0))
	c.queue_free()
	await get_tree().process_frame


func _step_river(c: RiverCoverChamber, seconds: float) -> void:
	for i in int(seconds * 30.0):
		c.step(1.0 / 30.0)


func _river_shots() -> void:
	var st := Ep2ArmoryState.post_hideout()
	st.purchase_river_gear("btc")
	st.purchase_sniper("btc")
	st.purchase_sniper_ammo(10, "btc")
	var c: RiverCoverChamber = RIVER.instantiate() as RiverCoverChamber
	vp.add_child(c)
	c.set_physics_process(false)
	c.debug_no_ranged = true
	c.bind_armory(st)
	c.setup(0, [], 0)
	_observer(c)
	c._player_pos = RiverCoverChamber.MARKER + Vector3(0, 0, 1.0)
	c._ground_y = c._player_pos.y
	_step_river(c, 0.2)
	var o: Vector3 = RiverCoverChamber.OVERLOOKS[0]
	c._player_pos = o
	c._ground_y = o.y
	var pool: Vector3 = c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT))
	var eye: Vector3 = o + Vector3(0, c.eye_height, 0)
	c._look_yaw = atan2(pool.x - eye.x, pool.z - eye.z)
	c._look_pitch = atan2(pool.y - eye.y, Vector2(pool.x - eye.x, pool.z - eye.z).length())
	_step_river(c, 1.0)
	var r: Dictionary = {}
	for i in 300:
		_step_river(c, 0.1)
		if not c.get_rafts().is_empty() and float(c.get_rafts()[0]["s"]) > 20.0:
			r = c.get_rafts()[0]
			break
	if r.is_empty():
		print("  no raft came")
		return
	var node: Node3D = r["node"]
	var side: Vector3 = c.river_right(float(r["s"])) * (1.0 if float(r["lateral"]) > 0.0 else -1.0)
	var m: Dictionary = (r["men"] as Array)[0]
	# 4. a man is shot off the raft: from the bank beside it, and from the ridge (the player's own line)
	await _grab("4_rider_00_before", node.global_position + side * 9.0 + Vector3(0, 3.0, 0) - c.river_dir(float(r["s"])) * 4.0, node.global_position)
	c.damage_raider(m)
	for f in 12:
		_step_river(c, 0.12)
		var at: Vector3 = node.global_position
		await _grab("4_rider_%02d_bank" % (f + 1), at + side * 9.0 + Vector3(0, 3.0, 0) - c.river_dir(float(r["s"])) * 4.0, at + side * 1.5)
	_step_river(c, 1.0)
	await _grab("4_rider_13_ridge", o + Vector3(0, c.eye_height, 0), node.global_position)
	# 5. the raft takes hits: splinters and scars, a list at half, then it breaks up and the other man goes in
	for h in 3:
		var hit_at: Vector3 = node.global_transform * Vector3(0.3 - 0.4 * float(h), 0.18, 1.2 + 0.2 * float(h))
		c.damage_raft(r, 2 if h < 2 else 1, hit_at)
		_step_river(c, 0.1)
		var at: Vector3 = node.global_position
		await _grab("5_raft_%02d_hit%d" % [h * 2, h + 1], at + side * 6.0 + Vector3(0, 3.2, 0), at)
		_step_river(c, 0.4)
		await _grab("5_raft_%02d_after%d" % [h * 2 + 1, h + 1], node.global_position + side * 6.0 + Vector3(0, 3.2, 0), node.global_position)
	c.damage_raft(r, 2, node.global_position)
	for f in 8:
		_step_river(c, 0.4)
		var at: Vector3 = node.global_position
		await _grab("5_raft_%02d_break" % (6 + f), at + side * 9.0 + Vector3(0, 4.0, 0) - c.river_dir(float(r["s"])) * 3.0, at)
	print("  raft broken %s, hp %d" % [str(r["broken"]), Ep2CreatureHealth.of(node).hp])
	c.queue_free()
	await get_tree().process_frame
