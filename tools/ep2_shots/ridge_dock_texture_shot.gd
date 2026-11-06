extends Node
## The ridge and Utah's dock, surface by surface (founder 2026-11-06: "texturing on the level going up the ridge looks very cheap,
## including the end section with Utah and the facility the shipment goes to"). The real session swap out of Logan's Lake (his light,
## the lake behind), then fixed poses: the climb, the cliff, the marker, each overlook, the bend, the drop between ledges, the dock from
## the last overlook and through the scope, the dock from the bank and from its own deck with Utah walking out of the warehouse.
## Same poses on any build, so a before/after pair is the same frame.
##   godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . res://tools/ep2_shots/ridge_dock_texture_shot.tscn -- out=<dir>
var out := ".farm/ridge-dock"
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
	lake.start_rig()
	var r: RiverCoverChamber = session.get_active() as RiverCoverChamber
	r.set_physics_process(false)
	var ov: Array = RiverCoverChamber.OVERLOOKS
	var pts: Array = RiverCoverChamber.RIDGE_POINTS
	await _at(r, pts[2], pts[4] + Vector3(0, 1.0, 0), "01_climb_path_ahead")
	await _at(r, pts[3], pts[3] + Vector3(14, -14, 6), "02_cliff_face_from_the_path")
	await _at(r, Vector3(14, 0.6, 20), Vector3(-30, 12, 4), "02b_cliff_from_the_far_bank")
	await _at(r, RiverCoverChamber.MARKER + Vector3(0, 0, -7), RiverCoverChamber.MARKER + Vector3(-2.2, 1.2, 0), "03_marker_cairn")
	await _at(r, (ov[0] as Vector3) + Vector3(-2.5, 0, -5), (ov[0] as Vector3) + Vector3(0.5, 0.2, 0), "04_overlook_stand")
	await _at(r, ov[0], r.river_point(r.river_s_of(RiverCoverChamber.LAUNCH_POINT)), "05_overlook_launch_pool")
	await _at(r, ov[0], r.river_point(r.river_s_of(Vector2(-4, 40))), "06_banks_downstream_gate_one")
	await _at(r, pts[9], pts[11], "07_drop_to_the_bend_ledge")
	await _at(r, ov[1], r.river_point(r.river_s_of(RiverCoverChamber.BEND_POINT)), "08_bend_rapids")
	await _at(r, ov[2], RiverCoverChamber.DOCK_DECK + Vector3(-4, 1.5, 1), "09_dock_from_last_overlook")
	r.set_aim(true)
	for i in 20:
		r.step(1.0 / 30.0)
	await _at(r, ov[2], RiverCoverChamber.DOCK_DECK + Vector3(-5, 1.8, 2), "10_dock_through_the_scope")
	r.set_aim(false)
	for i in 20:
		r.step(1.0 / 30.0)
	await _at(r, RiverCoverChamber.DOCK_DECK + Vector3(16, -1.0, 12), RiverCoverChamber.DOCK_DECK + Vector3(-5, 1.0, 1), "11_dock_and_warehouse_from_the_bank")
	var utah: Node3D = r.get("_utah")
	if utah != null:
		utah.visible = true
		utah.position = (RiverCoverChamber.DOCK_DECK + Vector3(-9, 0, 3.2)).lerp(RiverCoverChamber.DOCK_DECK + Vector3(0.5, 0, 1.8), 0.3)
		utah.call("play_clip", "Walk")
	await _at(r, RiverCoverChamber.DOCK_DECK + Vector3(5.2, 0, -1.2), RiverCoverChamber.DOCK_DECK + Vector3(-7.5, 1.4, 2.4), "12_handoff_utah_out_of_the_warehouse")
	await _at(r, RiverCoverChamber.DOCK_DECK + Vector3(-1.5, 0, -2.6), RiverCoverChamber.DOCK_DECK + Vector3(5.5, -0.2, 0.2), "13_deck_landing_and_crane")
	print("RIDGE_DOCK_TEXTURE_SHOT_DONE")
	get_tree().quit()


## Stand at `pos` (his feet), look at `at`, settle, capture.
func _at(r: RiverCoverChamber, pos: Vector3, at: Vector3, label: String) -> void:
	r._player_pos = pos
	r._ground_y = pos.y
	var eye: Vector3 = pos + Vector3(0, r.eye_height, 0)
	var d: Vector3 = at - eye
	r._look_yaw = atan2(d.x, d.z)
	r._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	r._update_camera(0)
	r._sync_visuals()
	for f in 8:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg("%s/%s.jpg" % [out, label], 0.88)
