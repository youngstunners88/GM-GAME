extends Node
## P1-10 (founder 2026-11-22: "I dont understand why we are teleporting to the fucking auction road"): the real hand-over. The after-day-88
## lake (Ep2Playtest.AUCTION), mounted, at the signpost looking down the road: the last lake frame, the first road frame with the same gaze,
## a few seconds on, and the look back at the lake from the road.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/auction_handover_shot.tscn -- out=<dir>
var _out := ".farm/auction_handover"


func _save(name: String) -> void:
	for j in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var s := Ep2SessionRoot.new()
	add_child(s)
	s.set_process(false)
	s.configure(Episode2Tracks.LEGS, true)
	s.start_playtest(Ep2Playtest.AUCTION)
	var lake: LogansLakeChamber = s.get_active() as LogansLakeChamber
	lake.set_physics_process(false)
	for i in 30: lake.step(1.0 / 30.0)
	lake._player_pos = lake.get_horse_node().position + Vector3(-1.2, 0, 0)
	lake.start_rig()
	for i in 60: lake.step(1.0 / 30.0)
	s._drive_prebuild(1.0e9)
	for i in 60: lake.preview_road(s._pb_node)
	lake._player_pos = LogansLakeChamber.AUCTION_SIGN + Vector3(-1.4, 0, 1.4)       # a step before the line, on the road's width
	lake._look_yaw = Ep2LakeLandform.ROAD_YAW
	lake._look_pitch = -0.05
	lake.step(1.0 / 30.0)
	await _save("1_lake_before_line")
	lake._player_pos = LogansLakeChamber.AUCTION_SIGN + Vector3(0.2, 0, -0.2)
	lake.step(1.0 / 30.0)
	lake.step(1.0 / 30.0)
	var road: AuctionRoadChamber = s.get_active() as AuctionRoadChamber
	if road == null:
		print("AUCTION_HANDOVER_SHOT: no hand-over ", s.get_active())
		get_tree().quit(1)
		return
	road.set_physics_process(false)
	road._update_camera(0.0)
	await _save("2_road_first_frame")
	road._player_pos = road.at(40.0)
	road._update_camera(0.0)
	await _save("3_road_40m")
	road._look_yaw += PI
	road._update_camera(0.0)
	await _save("4_road_looking_back_at_the_lake")
	print("AUCTION_HANDOVER_SHOT_DONE ", _out)
	get_tree().quit()
