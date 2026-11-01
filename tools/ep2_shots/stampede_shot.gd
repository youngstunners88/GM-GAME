extends Node
## The buffalo stampede (Guns Buff §5) seen from the saddle: the telegraph (dust wall, far), the charge (close), a bison down.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/stampede_shot.tscn

var out: String = ""


func _shot(name: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("STAMPEDE_SHOT ", name)


func _look_at_herd(trail: LakeTrailChamber, st: Ep2Stampede) -> void:
	var centre := Vector3.ZERO
	var n: int = 0
	for b in st.herd:
		centre += b["pos"]
		n += 1
	centre /= float(maxi(n, 1))
	var eye: Vector3 = trail.get_camera().global_position
	trail._look_yaw = atan2(centre.x - eye.x, centre.z - eye.z)
	trail._look_pitch = atan2(centre.y + 1.0 - eye.y, Vector2(centre.x - eye.x, centre.z - eye.z).length())
	trail._update_camera(0)


func _ready() -> void:
	out = OS.get_environment("OUT")
	if out == "":
		out = "user://stampede"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	GameManager.ep2_stampede_done = false
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail)
	session._active = trail
	session._wire_chamber(trail)
	trail.setup()
	trail.set_physics_process(false)
	trail.debug_invulnerable = true
	trail._route_s = LakeTrailChamber.STAMPEDE_S + 1.0
	trail._place_at_distance(trail._route_s)
	trail._speed = 0.0
	trail._tick_stampede(0.1)
	var st: Ep2Stampede = trail._stampede
	for i in 90:
		st.step(1.0 / 60.0, trail._player_pos)
		await get_tree().process_frame
	_look_at_herd(trail, st)
	await _shot("telegraph")
	# he holds still in the herd's path (rides to the point it aims at); charge until the front row is ~28 m from him
	trail._route_s = clampf(trail._route_s + 2.5 * (Ep2Stampede.TELEGRAPH + Ep2Stampede.START_DIST / Ep2Stampede.SPEED), 0.0, trail._route_total)
	trail._place_at_distance(trail._route_s)
	for i in int(20.0 * 60.0):
		st.step(1.0 / 60.0, trail._player_pos - st.heading * 60.0)
		if i % 6 == 0:
			await get_tree().process_frame
		var fp: Vector3 = st.herd[0]["pos"]
		if Vector2(fp.x - trail._player_pos.x, fp.z - trail._player_pos.z).length() < 28.0:
			break
	_look_at_herd(trail, st)
	await _shot("charge")
	st.herd[0]["dead"] = true
	st.herd[1]["dead"] = true
	for i in 40:
		st.step(1.0 / 60.0, trail._player_pos - st.heading * 60.0)
		await get_tree().process_frame
	_look_at_herd(trail, st)
	await _shot("down")
	print("STAMPEDE_SHOTS_DONE")
	get_tree().quit()
