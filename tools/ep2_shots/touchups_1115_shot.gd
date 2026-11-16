extends Node
## Evidence for the fix-pack 1115 touch-ups (2026-11-16): Dude's horses read as different coats on screen, and Rich's crate keeps the dock
## prop's size when he lifts and carries it. Real chambers, real renderer:
##   SHOT_OUT=/tmp/x godot --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 res://tools/ep2_shots/touchups_1115_shot.tscn
var vp: SubViewport
var out: String


func _ready() -> void:
	out = OS.get_environment("SHOT_OUT")
	if out.is_empty(): out = OS.get_user_data_dir().path_join("touchups_1115_shot")
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	await _horses()
	await _crate()
	print("TOUCHUPS_1115_SHOT: DONE")
	get_tree().quit()


func _horses() -> void:
	var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	vp.add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	var yard: Ep2StableYard = c._stable_yard
	var centre := Vector3.ZERO
	for h in yard.horses: centre += h.global_position
	centre /= maxf(1.0, yard.horses.size())
	_look_town(c, centre + Vector3(7.5, 0, 4.0), centre + Vector3(0, 1.0, 0))
	await _shot("horses_yard")
	for i in yard.horses.size():
		var h: Node3D = yard.horses[i]
		_look_town(c, h.global_position + Vector3(3.2, 0, 1.2), h.global_position + Vector3(0, 1.1, 0))
		await _shot("horse_%d_%s" % [i, Ep2HorseCoat.coat_of(h)])
	c.queue_free()
	await get_tree().process_frame


func _look_town(c: GoldTownChamber, ground: Vector3, focus: Vector3) -> void:
	c._player_pos = ground
	var d: Vector3 = focus - (ground + Vector3(0, c.eye_height, 0))
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	c._update_camera(0)
	c._sync_visuals()


func _crate() -> void:
	var st := Ep2ArmoryState.post_hideout()
	st.purchase_river_gear("btc")
	st.purchase_sniper("btc")
	st.purchase_sniper_ammo(10, "btc")
	var c: RiverCoverChamber = load("res://src/episode2/chamber/river_cover.tscn").instantiate() as RiverCoverChamber
	vp.add_child(c)
	c.set_physics_process(false)
	c.debug_no_ranged = true                         # as the river test: the archers' fire has its own test
	c.bind_armory(st)
	c.setup(0, [], 0)
	# the real run, as tests/ep2_river_cover_test.gd plays it: launch, clear the three gates, then the dock beat
	_stand(c, RiverCoverChamber.MARKER + Vector3(0, 0, 1.0))
	_adv(c, 1.0)
	_stand(c, RiverCoverChamber.OVERLOOKS[0])
	_aim(c, c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT)))
	_adv(c, 2.0)
	print("RUN launched=%s beat=%s gate=%d" % [c.is_launched(), c.get_beat_name(), c.get_gate()])
	_wave(c, 5)
	_kill(c)
	_adv(c, 70.0)
	_kill_all(c)
	_stand(c, RiverCoverChamber.OVERLOOKS[1])
	_adv(c, 0.5)
	_wave(c, 14)
	_kill(c)
	_adv(c, 70.0)
	_kill_all(c)
	_stand(c, RiverCoverChamber.OVERLOOKS[2])
	_adv(c, 0.5)
	print("RUN at dock ledge beat=%s gate=%d rich=%s" % [c.get_beat_name(), c.get_gate(), c.rich_state()])
	_wave(c, 22)
	_kill(c)
	var crate: Node3D = c.get_crate()
	var rich: Ep2TownFolk = c.get_rich()
	var shots := {"to_crate": false, "lift": false, "carry": false}
	var size_on_deck := Vector3.ZERO
	var lift_frames: int = 0
	for i in 30 * 120:
		c.step(1.0 / 30.0)
		var rs: String = c.rich_state()
		if rs == "to_crate" and not shots["to_crate"] and rich.position.distance_to(crate.position) < 2.2:
			shots["to_crate"] = true
			size_on_deck = crate.scale
			await _shot_river(c, "crate_1_on_deck", rich.position + Vector3(3.0, 0.0, 2.6), crate.position + Vector3(0, 0.6, 0))
		elif rs == "lift":
			lift_frames += 1
			if lift_frames == 15:
				await _shot_river(c, "crate_2_mid_lift", rich.position + Vector3(3.0, 0.0, 2.6), rich.position + Vector3(0, 0.9, 0))
		elif rs == "carry" and not shots["carry"]:
			shots["carry"] = true
			await _shot_river(c, "crate_3_in_his_arms", rich.position + Vector3(2.8, 0.0, 2.2), rich.position + Vector3(0, 0.9, 0))
		elif rs == "gone":
			break
	print("CRATE_SCALE on_deck=%s carried=%s reach=%.2f rich_state=%s" % [size_on_deck, crate.scale, c._carry_reach, c.rich_state()])


func _adv(c: RiverCoverChamber, seconds: float) -> void:
	for i in int(seconds * 30.0): c.step(1.0 / 30.0)


func _stand(c: RiverCoverChamber, at: Vector3) -> void:
	c._player_pos = at
	c._ground_y = at.y


func _aim(c: RiverCoverChamber, p: Vector3) -> void:
	var d: Vector3 = p - (c._player_pos + Vector3(0, c.eye_height, 0))
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _kill(c: RiverCoverChamber) -> void:
	for b in c.get_bears():
		if not bool(b["ridge"]): c.damage_bear(b, 99)
	for m in c.get_raiders(): c.damage_raider(m)


func _kill_all(c: RiverCoverChamber) -> void:
	for b in c.get_bears(): c.damage_bear(b, 99)


func _wave(c: RiverCoverChamber, n: int) -> void:
	for i in 80:
		c._crate_board = 0.0
		_adv(c, 0.5)
		var river: int = 0
		for b in c.get_bears():
			if not bool(b["ridge"]): river += 1
		if river >= n: break


func _shot_river(c: RiverCoverChamber, label: String, ground: Vector3, focus: Vector3) -> void:
	c._player_pos = ground
	c._ground_y = ground.y
	var d: Vector3 = focus - (ground + Vector3(0, c.eye_height, 0))
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	c._update_camera(0)
	c._sync_visuals()
	await _shot(label)


func _shot(label: String) -> void:
	for i in 4: await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), 0.9)
