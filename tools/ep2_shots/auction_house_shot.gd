extends Node
## Auction House captures from the REAL road room (brief PROMPT_AUCTION_HOUSE_RENEGADE_JACK_HAMMER_2026-11-08): the lake end of the road,
## the dusk approach, the porch, the hall from the floor, Jack by the claim board, Jack running for the side door.
##   godot --path . --rendering-method gl_compatibility res://tools/ep2_shots/auction_house_shot.tscn -- out=<dir>
var _out := ".farm/auction_house"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var vp := SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var road: AuctionRoadChamber = (load("res://src/episode2/chamber/auction_road.tscn") as PackedScene).instantiate()
	road.handoff = {"road_mounted": true}
	vp.add_child(road)
	road.set_physics_process(false)
	road.bind_armory(Ep2ArmoryState.post_hideout())
	road.setup(0, [], 0)
	road._claim_done = true
	road._spooked = true
	var shots := [
		["01_lake_end", road.at(2.0), road.ROAD_YAW, 0.0, 0.2],
		["02_dusk_approach", road.at(road.ARRIVE_S - 25.0), road.ROAD_YAW, 0.05, 0.2],
		["03_grounds_porch", road.from_house(Vector3(1.5, 0, -14.0)), road.ROAD_YAW - 0.08, 0.12, 1.5],
		["04_hall_floor", road.from_house(Vector3(0.4, 0, 9.0)), road.ROAD_YAW, 0.06, 0.5],
		["05_jack_board", road.from_house(Vector3(-3.0, 0, 15.5)), road.ROAD_YAW - 0.95, 0.02, 9.0],
		["06_flee", road.from_house(Vector3(-3.0, 0, 15.5)), road.ROAD_YAW - 1.2, 0.02, 14.4],
	]
	if OS.get_cmdline_user_args().has("probe"):
		shots = [["11_left_seats", road.from_house(Vector3(-2.0, 0, 12.6)), road.ROAD_YAW - 1.45, -0.1, 0.4],
			["12_right_seats", road.from_house(Vector3(2.0, 0, 12.6)), road.ROAD_YAW + 1.45, -0.1, 0.4],
			["13_renegade_close", road.from_house(Vector3(0.4, 0, 21.0)), road.ROAD_YAW, 0.2, 0.4]]
	if OS.get_cmdline_user_args().has("close"):
		shots = [["07_renegade", road.from_house(Vector3(0.6, 0, 20.5)), road.ROAD_YAW, 0.12, 0.4],
			["08_jack", road.from_house(Vector3(-5.6, 0, 17.6)), road.ROAD_YAW - 0.68, 0.0, 0.4],
			["09_floor", road.from_house(Vector3(1.0, 0, 13.4)), road.ROAD_YAW + 0.55, -0.05, 3.0],
			["10_side_windows", road.from_house(Vector3(0.0, 0, 6.0)), road.ROAD_YAW + 1.3, 0.1, 0.3]]
	if OS.get_cmdline_user_args().has("cast"):      # 2026-11-16 cast brief: the band pocket, the porch checker + desk, the tied horses, Renegade's arms
		shots = [["14_band_left", road.from_house(Vector3(-3.4, 0, 18.2)), road.ROAD_YAW - 0.9, -0.02, 0.4],
			["14b_band_close", road.from_house(Vector3(-5.2, 0, 19.0)), road.ROAD_YAW - 0.75, -0.02, 0.4],
			["15_porch_checker", road.from_house(Vector3(2.9, 0, -1.6)), road.ROAD_YAW - 0.1, -0.04, 0.4],
			["16_horses_outside", road.from_house(Vector3(1.5, 0, -15.0)), road.ROAD_YAW - PI * 0.5, 0.0, 0.4],
			["17_renegade_arms", road.from_house(Vector3(0.45, 0, 22.9)), road.ROAD_YAW, 0.06, 0.4],
			["18_wall_trim", road.from_house(Vector3(4.0, 0, 21.0)), road.ROAD_YAW + 1.2, 0.05, 0.4],
			["19_stage_front", road.from_house(Vector3(-3.0, 0, 20.5)), road.ROAD_YAW + 0.5, -0.1, 0.4]]
	if OS.get_cmdline_user_args().has("clerk"):     # the claim wagon's checker, face on from 2.4 m and from the saddle's approach
		var cp: Vector3 = road.at(road.CLAIM_S - 2.6, -2.2)
		var eye: Vector3 = road.at(road.CLAIM_S - 5.0, -2.2)
		shots = [["20_claim_clerk", eye, atan2(cp.x - eye.x, cp.z - eye.z), -0.22, 0.4],
			["21_claim_clerk_talk", road.at(road.CLAIM_S - 6.2, -1.6), atan2(cp.x - road.at(road.CLAIM_S - 6.2, -1.6).x, cp.z - road.at(road.CLAIM_S - 6.2, -1.6).z), -0.16, 0.4]]
	for s in shots:
		road._player_pos = s[1]
		var t: float = s[4]
		while t > 0.0:
			road.step(1.0 / 30.0)
			t -= 1.0 / 30.0
		road._look_yaw = s[2]
		road._look_pitch = s[3]
		for i in 6:
			road.step(1.0 / 60.0)
			await get_tree().process_frame
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
		print("SHOT ", s[0], " beat=", road.get_beat_name(), " phase=", road.house().phase if road.house() != null else "-")
	get_tree().quit()
