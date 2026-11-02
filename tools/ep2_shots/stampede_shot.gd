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


## Run the herd until its leading animal is `dist` metres from him.
func _charge_until(trail: LakeTrailChamber, st: Ep2Stampede, away: Vector3, dist: float) -> void:
	for i in int(20.0 * 60.0):
		st.step(1.0 / 60.0, away)
		if i % 3 == 0:
			await get_tree().process_frame
		var near: float = 999.0
		for b in st.herd:
			near = minf(near, Vector2((b["pos"] as Vector3).x - trail._player_pos.x, (b["pos"] as Vector3).z - trail._player_pos.z).length())
		if near < dist:
			return


## Aim at the herd's front row (the first four formed).
func _look_at_front(trail: LakeTrailChamber, st: Ep2Stampede) -> void:
	var centre := Vector3.ZERO
	for i in 4:
		centre += st.herd[i]["pos"]
	centre /= 4.0
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
	# the herd aims at where a RIDING player will be; he holds still here, so its line is moved onto him (the room's trample never fires:
	# the herd's own check is fed a far-off player)
	var onto: Vector3 = trail._player_pos - st._target
	for b in st.herd:
		b["pos"] = (b["pos"] as Vector3) + onto
	st._target = trail._player_pos
	var away: Vector3 = trail._player_pos - st.heading * 200.0
	await _charge_until(trail, st, away, 30.0)
	_look_at_front(trail, st)
	await _shot("charge")
	await _charge_until(trail, st, away, 14.0)
	_look_at_front(trail, st)
	await _shot("close")
	st.herd[0]["dead"] = true
	st.herd[1]["dead"] = true
	st.killed += 2
	for i in 40:
		st.step(1.0 / 60.0, away)
		await get_tree().process_frame
	var down: Vector3 = st.herd[0]["pos"]
	var at_eye: Vector3 = trail.get_camera().global_position
	trail._look_yaw = atan2(down.x - at_eye.x, down.z - at_eye.z)
	trail._look_pitch = atan2(0.6 - at_eye.y, Vector2(down.x - at_eye.x, down.z - at_eye.z).length())
	trail._update_camera(0)
	await _shot("down")
	print("STAMPEDE_SHOTS_DONE")
	get_tree().quit()
