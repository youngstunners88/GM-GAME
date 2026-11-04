extends Node
## The walk out of Logan's Lake and on up the ridge, through the real session swap (founder 2026-11-04: "Right now the stage inverts after pressing E"):
## the last frame of the lake, the first frame of the ridge at the same gaze, then the climb, the marker and the run with its archers and rafts.
##   godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . res://tools/ep2_shots/ridge_walk_shot.tscn -- out=<dir>
var out := ".farm/ridge-walk"
var vp: SubViewport


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var session = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	vp.add_child(session)
	session.set_process(false)
	var st := Ep2ArmoryState.post_hideout()
	st.river_gear = true
	st.sniper_owned = true
	st.sniper_rounds = 40
	session.armory = st
	var lake: LogansLakeChamber = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	session.add_child(lake)
	session._active = lake
	session._mode = session.Mode.CHAMBER
	session._chain_id = "logans_lake"
	session._chamber_segment = 0
	session._wire_chamber(lake)
	lake.setup(0, [], 0)
	lake.set_physics_process(false)
	lake.chamber_cleared.connect(session._on_chamber_cleared, CONNECT_ONE_SHOT)
	lake._staged = true
	lake._talk_t = 0.0
	lake._beat = LogansLakeChamber.Beat.OVERLOOK
	session._on_prebuild_requested("river_cover")
	session._drive_prebuild(1e9)
	lake._player_pos = Vector3(-8.0, 6.0, 60.0)
	lake._look_yaw = 0.0
	lake._look_pitch = -0.02
	lake._update_camera(0)
	lake._sync_visuals()
	await _shot("01_lake_on_the_overlook_path")
	lake._look_yaw = PI
	lake._update_camera(0)
	lake._sync_visuals()
	await _shot("02_lake_looking_back_at_logan")
	lake._look_yaw = 0.0
	print("LAKE yaw ", lake._look_yaw, " pos ", lake._player_pos)
	lake.start_rig()
	var r: RiverCoverChamber = session.get_active() as RiverCoverChamber
	print("RIDGE ", r, " yaw ", r._look_yaw, " pos ", r._player_pos, " s ", r.ridge_s(r._player_pos))
	r.set_physics_process(false)
	r._update_camera(0)
	r._sync_visuals()
	await _shot("03_ridge_first_frame_same_gaze")
	r._look_yaw = PI
	r._update_camera(0)
	r._sync_visuals()
	await _shot("04_ridge_looking_back_the_lake_is_behind_him")
	r._look_yaw = 0.0
	# he keeps walking forward (W): only the movement input, the room does the rest
	r.set_move_input(Vector2(0, 1), true)
	for k in [2.0, 6.0, 12.0, 20.0]:
		await _walk(r, k)
		r._update_camera(0)
		r._sync_visuals()
		print("WALK t=", k, " pos ", r._player_pos, " yaw ", r._look_yaw)
		await _shot("05_climb_%02d_s" % int(k))
	# the marker, the overlook, the run
	r._player_pos = (RiverCoverChamber.OVERLOOKS[0] as Vector3)
	r._ground_y = r._player_pos.y
	r.set_move_input(Vector2.ZERO, false)
	var pool: Vector3 = r.river_point(r.river_s_of(RiverCoverChamber.LAUNCH_POINT))
	_look(r, pool)
	await _steps(r, 2.0)
	_look(r, pool)
	await _shot("06_overlook_launch_pool")
	await _steps(r, 8.0)
	_look(r, r.get_crate().position)
	await _shot("07_gate_one_bears_coming")
	await _steps(r, 12.0)
	r._crate_board = 0.0
	if not r.get_rafts().is_empty():
		_look(r, (r.get_rafts()[0]["node"] as Node3D).position)
		await _shot("08_hammers_raft")
	for b in r.get_bears():
		if str(b["state"]) == "archer":
			_look(r, (b["actor"] as Node3D).position)
			await _shot("09_archer_on_the_far_bank")
			break
	_look(r, Vector3(-120, 0, 370))
	await _shot("10_river_curves_right_to_the_railway")
	print("RIDGE_WALK_SHOT_DONE")
	get_tree().quit()


func _look(r: RiverCoverChamber, at: Vector3) -> void:
	var eye: Vector3 = r._player_pos + Vector3(0, r.eye_height, 0)
	var d: Vector3 = at - eye
	r._look_yaw = atan2(d.x, d.z)
	r._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	r._update_camera(0)
	r._sync_visuals()


func _walk(r: RiverCoverChamber, seconds: float) -> void:
	await _steps(r, seconds)


func _steps(r: RiverCoverChamber, seconds: float) -> void:
	for i in int(seconds * 30.0):
		r.step(1.0 / 30.0)
		if i % 15 == 0:
			await get_tree().process_frame


func _shot(label: String) -> void:
	for f in 6:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg("%s/%s.jpg" % [out, label], 0.85)
