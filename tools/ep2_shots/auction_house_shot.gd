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
	if OS.get_cmdline_user_args().has("bandwide"):      # 2026-11-21 captured band clips: each player's own motion, fiddle at the chin, wrapped hands
		var look := func(eye_l: Vector3, at_l: Vector3) -> float:
			var e: Vector3 = road.from_house(eye_l)
			var t: Vector3 = road.from_house(at_l)
			return atan2(t.x - e.x, t.z - e.z)
		shots = [["27_band_wide", road.from_house(Vector3(-4.6, 0, 17.4)), look.call(Vector3(-4.6, 0, 17.4), Vector3(-7.6, 0, 21.6)), -0.08, 0.4],
			["27b_band_wide_later", road.from_house(Vector3(-4.6, 0, 17.4)), look.call(Vector3(-4.6, 0, 17.4), Vector3(-7.6, 0, 21.6)), -0.08, 0.4, "wait"],
			["28_fiddle_banjo", road.from_house(Vector3(-7.0, 0, 18.9)), look.call(Vector3(-7.0, 0, 18.9), Vector3(-8.9, 0, 21.5)), -0.02, 0.4],
			["29_bass_harmonica", road.from_house(Vector3(-4.2, 0, 19.0)), look.call(Vector3(-4.2, 0, 19.0), Vector3(-5.8, 0, 21.8)), -0.02, 0.4]]
	if OS.get_cmdline_user_args().has("grand"):     # 2026-11-17 grand event: GM logos, braziers, flame jets, gold, the band really playing
		var band_eye: Vector3 = road.from_house(Vector3(-4.6, 0, 17.4))
		var band_at: Vector3 = road.from_house(Vector3(-7.6, 0, 21.6))
		var band_yaw: float = atan2(band_at.x - band_eye.x, band_at.z - band_eye.z)
		shots = [["22_stage_wide", road.from_house(Vector3(0.0, 0, 8.0)), road.ROAD_YAW, 0.08, 0.4],
			["23_flame_jets", road.from_house(Vector3(0.0, 0, 13.0)), road.ROAD_YAW, 0.12, 0.2, "burst"],
			["24_band_playing", band_eye, band_yaw, -0.08, 0.4],
			["24b_band_playing_later", band_eye, band_yaw, -0.08, 0.4, "wait"],
			["25_left_wall_logo", road.from_house(Vector3(-3.0, 0, 15.5)), road.ROAD_YAW - PI * 0.5, 0.12, 0.4],
			["26_gold_shower", road.from_house(Vector3(0.0, 0, 15.0)), road.ROAD_YAW, 0.15, 0.2, "shower"],
			["27_bass_harmonica", road.from_house(Vector3(-4.0, 0, 20.4)), road.ROAD_YAW - 1.25, -0.12, 0.4],
			["28_fiddle_banjo", road.from_house(Vector3(-7.0, 0, 18.4)), road.ROAD_YAW - 0.35, -0.1, 0.4]]
	if OS.get_cmdline_user_args().has("band"):      # each player face on from 2.3 m: are both hands on the instrument?
		shots = []
		for row in Ep2AuctionHouse.BAND:
			var at := Vector3(float(row[1]), 0, float(row[2]))
			var eye_l: Vector3 = at + (Ep2AuctionHouse.BAND_FACE - at).normalized() * 2.3
			var eye: Vector3 = road.from_house(eye_l)
			var tgt: Vector3 = road.from_house(at)
			shots.append(["29_%s" % str(row[3]).to_lower(), eye, atan2(tgt.x - eye.x, tgt.z - eye.z), -0.12, 0.4])
	if OS.get_cmdline_user_args().has("visitors"):  # 2026-11-20 visitor carriages: arrival read, each rig side-on for hooves + wheels
		shots = []
		for row in [["30_gate_arrival", Vector3(0.0, 0, -46.0), Vector3(4.0, 0, -10.0), 0.08],
				["31_palace", Vector3(5.0, 0, -18.0), Vector3(17.0, 0, -11.0), 0.25],
				["32_palace_side", Vector3(6.5, 0, -11.0), Vector3(17.0, 0, -11.0), 0.0],
				["33_coach_side", Vector3(3.0, 0, -25.0), Vector3(9.0, 0, -24.5), -0.12],
				["34_pair_side", Vector3(3.0, 0, -35.0), Vector3(9.2, 0, -35.0), -0.12],
				["35_single_left", Vector3(-4.0, 0, -8.5), Vector3(-10.5, 0, -8.0), -0.12],
				["36_single_gate", Vector3(-4.0, 0, -36.0), Vector3(-10.4, 0, -35.5), -0.12],
				["37_porch_back", Vector3(0.0, 0, -2.0), Vector3(2.0, 0, -30.0), 0.0]]:
			var eye_v: Vector3 = road.from_house(row[1])
			var tgt_v: Vector3 = road.from_house(row[2])
			shots.append([row[0], eye_v, atan2(tgt_v.x - eye_v.x, tgt_v.z - eye_v.z), row[3], 0.4])
	for s in shots:
		if s.size() > 5 and road.house() != null and road.house().grand != null:
			var g: Node = road.house().grand
			if s[5] == "burst":
				g._jet_t = 0.0
				g.burst()
			elif s[5] == "shower":
				g._jet_t = 0.0
				g.shower()
			for i in (40 if s[5] != "wait" else 25):
				await get_tree().process_frame
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
