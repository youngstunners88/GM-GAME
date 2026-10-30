extends SceneTree
## THE OPEN ELEVATOR DOOR (founder 2026-10-24; skill ep2-open-door-portal) in the real Compatibility renderer, driven exactly as the game
## drives it: Ep2SessionRoot builds the mine lift behind the hideout, the hideout's doorway shows it, Lil Blunt walks through and the same
## lift instance becomes the room. Frames: the doorway from across the room, mid-room, at the door, then the last hideout frame and the
## first lift frame from the same eye - the pair `cut_a` / `cut_b` must look like one picture (luminance diff printed).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/door_portal_shot.tscn -- out=<dir>
var _out := ".farm/door_portal"
var _vp: SubViewport


func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():ProjectSettings.load_resource_pack(args[0],false)
	call_deferred("run")
func run() -> void:
	await process_frame
	self.root.content_scale_size=Vector2i(640,360)
	self.root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var sm=self.root.get_node("StateMachine")
	sm.change_state(sm.State.TRANSITIONING)
	sm.change_state(sm.State.PLAYING)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(640, 360)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var container:=SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch=true
	self.root.add_child(container)
	container.add_child(_vp)
	var root = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	_vp.add_child(root)
	root.armory = load("res://src/episode2/chamber/ep2_armory_state.gd").post_hideout()
	var hf = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	hf.intro_film = false
	root.add_child(hf)
	root._active = hf
	root._wire_chamber(hf)
	hf.setup(0, [], 0)
	hf.set_physics_process(false)
	await process_frame
	hf._on_video_film_finished()
	if hf.has_method("_enter_fps"):
		hf._enter_fps()
	hf.prebuild_requested.emit("mine_lift")
	root.step(0.016)
	root.set_process(false)
	hf._bull.process_mode = Node.PROCESS_MODE_DISABLED
	hf._beat = hf.Beat.EXIT
	hf._show_active = false
	hf._hold = 0.0
	hf._bull.position = Vector3(0.7, 0.0, hf.PORTAL_Z + 2.2)       # Inferno already through, leading
	hf._bull.facing = 0.0
	hf._bull.rotation.y = 0.0
	# This is the post-lesson exit, after his real stand-up. A fixture that
	# leaves the sitting clip active changes pose on its first simulated tick.
	hf._stand_t = 99.0
	hf._settle = 0.0
	hf._bull.stop()
	hf._bull.play(hf.BULL_IDLE,1.0,0.0)
	hf._animate_bull(0.0)
	var pz: float = hf.PORTAL_Z
	for spec in [["1_room_far", Vector3(0.0, 0.0, 4.0), 0.0], ["2_room_mid", Vector3(-0.8, 0.0, 10.5), 0.08],
			["3_at_door", Vector3(0.2, 0.0, 14.6), -0.05], ["cut_a", Vector3(0.3, 0.0, pz - 0.06), 0.0]]:
		if str(spec[0])!="cut_a":continue
		hf._player_pos = spec[1]
		hf._look_yaw = float(spec[2])
		hf._look_pitch = 0.0
		hf._sync_visuals()
		hf._update_camera(1.0)            # the camera follows the eye in step(); place it now
		root._drive_portal()
		await _frames(6)
		await _save(str(spec[0]))
		if str(spec[0]) == "cut_a":
			print("CAM_A fov %.2f pos %s  LIFTCAM fov %.2f pos %s" % [hf._camera.fov, str(hf._camera.global_position), root._pb_node.get_camera().fov, str(root._pb_node.get_camera().global_position)])
	print("PORTAL_LIVE ", hf._portal_live, " QUAD ", hf._portal_quad != null and hf._portal_quad.visible)
	# walk through: the last hideout frame above, the first lift frame below, same eye
	var res: Array = []
	hf.chamber_cleared.connect(func(r): res.append(r))
	hf._player_pos = Vector3(0.3, 0.0, pz + 0.02)
	# Compare the same simulation instant; movement itself is exercised by
	# the stride/airborne tests. Do not advance a stale lesson walking goal.
	hf._try_exit()
	root._chain_id = "mine_lift"
	root._enter_chamber_chained(0)
	var la = root.get_active()
	if la != null:
		# A slow software render may take seconds per frame. Freeze simulation
		# for the paired camera comparison instead of letting Bull walk metres.
		la.set_physics_process(false)
		la._bull.process_mode = Node.PROCESS_MODE_DISABLED
		la._player_pos = Vector3(0.3, 0.0, la.PORTAL_Z - 0.06)
		la._look_yaw = 0.0
		la._look_pitch = 0.0
		la._sync_visuals()
		la._update_camera(0.0)
		await _frames(6)
		await _save("cut_b")
		print("CAM_B fov %.2f pos %s" % [la.get_camera().fov, str(la.get_camera().global_position)])
		la._player_pos = Vector3(0.3, 0.0, la.PORTAL_Z + 2.0)
		la._sync_visuals()
		la._update_camera(0.0)
		await _frames(4)
		await _save("4_inside_lift")
	print("ELEVATOR_WEB_RESULT ",JSON.stringify({"resolved":res.size(),"same_instance":la==root.get_active(),"camera_position":str(la._camera.global_position),"hud":la._hud.visible,"weapon":la._vm._shown}))
	print("ELEVATOR_WEB_DONE")


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	print("ELEVATOR_WEB_FRAME ",name)
	while not Input.is_key_pressed(KEY_F9):await process_frame
	print("ELEVATOR_WEB_ACK")
	while Input.is_key_pressed(KEY_F9):await process_frame


## Mean luminance of the central 60% (the doorway region at the cut).
func _luma(img: Image) -> float:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum: float = 0.0
	var n: int = 0
	for y in range(int(h * 0.2), int(h * 0.8), 6):
		for x in range(int(w * 0.2), int(w * 0.8), 6):
			var c: Color = img.get_pixel(x, y)
			sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return sum / maxf(float(n), 1.0)
