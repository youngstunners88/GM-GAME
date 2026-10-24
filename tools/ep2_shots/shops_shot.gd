extends Node
## THE WALK-IN SHOPS + A SHOPPER (founder 2026-10-24; skills ep2-walkin-shops, ep2-town-shopping) in the real town chamber, its camera,
## HUD and people controller: each shop from its doorway, then one townsperson sent on a real shop visit (walk the street to the steps,
## up onto the porch, in to the counter, buy, out with the parcel) captured at each leg.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/shops_shot.tscn -- out=<dir>
var chamber: GoldTownChamber
var vp: SubViewport
var out := ".farm/shops"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	chamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate() as GoldTownChamber
	vp.add_child(chamber)
	chamber.setup(0, [], 0)
	chamber.set_physics_process(false)
	await get_tree().process_frame
	print("KIT_V2 ", Ep2GoldTown.kit_v2)
	for piece in ["Bldg_A", "Bldg_B", "Bldg_C"]:
		var L := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world(piece, p)
		_look(L.call(Vector3(0.0, 0.0, 6.5)), L.call(Vector3(0.0, 1.8, 0.0)))
		await _shot("%s_front" % piece)
		_look(L.call(Vector3(0.2, 0.0, 0.4)), L.call(Vector3(0.3, 1.1, -5.0)))
		await _shot("%s_from_door" % piece)
		_look(L.call(Vector3(-2.2, 0.0, -1.0)), L.call(Vector3(1.6, 1.0, -6.5)))
		await _shot("%s_inside_corner" % piece)
	# a real shopper: the dressmaker goes to the general store
	var crowd: Ep2TownPeople = chamber.get_people()
	if crowd == null:
		print("SHOPS_SHOT_DONE (no people)")
		get_tree().quit()
		return
	var p: Ep2TownPeople.Person = crowd.person("dressmaker")
	for other in crowd.people:
		other.folk.anim_player().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var started := false
	for attempt in 40:                          # the errand's own dice: retry until it picks the general store
		p.state = "pause"
		p.timer = 0.0
		crowd.reservations.clear()
		if crowd._start_shopping(p) and p.shop == "Bldg_A":
			started = true
			break
		if p.shop != "":
			crowd._leave_shop_done(p)
	print("SHOPPER_STARTED ", started, " shop=", p.shop)
	var spots: Dictionary = Ep2GoldTown.shop_spots("Bldg_A")
	var legs := {"shop_in": false, "shop_buy": false, "shop_out": false}
	for t in 60 * 120:
		chamber.step(1.0 / 60.0)
		for other in crowd.people: other.folk.anim_player().advance(1.0 / 60.0)
		if p.state == "shop_in" and not legs["shop_in"] and p.folk.position.y > 0.3:
			legs["shop_in"] = true
			_look(spots["out"] + Vector3(-2.4, 0.0, 1.5), p.folk.position + Vector3(0, 1.0, 0))
			await _shot("shopper_1_up_the_steps")
		if p.state == "shop_buy" and not legs["shop_buy"]:
			legs["shop_buy"] = true
			_look(Ep2GoldTown.local_to_world("Bldg_A", Vector3(-1.4, 0.0, -1.0)), p.folk.position + Vector3(0, 1.1, 0))
			await _shot("shopper_2_at_the_counter")
		if p.state == "shop_out" and not legs["shop_out"] and p.folk.position.distance_to(spots["porch"]) < 0.6:
			legs["shop_out"] = true
			_look(spots["out"] + Vector3(2.0, 0.0, 2.5), p.folk.position + Vector3(0, 1.0, 0))
			await _shot("shopper_3_out_with_parcel")
		if legs["shop_out"]:
			break
	print("SHOPPER_LEGS ", legs, " parcel=", p.folk.held_prop("Parcel") != null)
	print("SHOPS_SHOT_DONE")
	get_tree().quit()


func _look(ground: Vector3, focus: Vector3) -> void:
	chamber._player_pos = Vector3(ground.x, 0.0, ground.z)
	var eye: Vector3 = chamber._player_pos + Vector3(0, chamber.eye_height, 0)
	var d: Vector3 = focus - eye
	chamber._look_yaw = atan2(d.x, d.z)
	chamber._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	chamber._update_camera(0)
	chamber._sync_visuals()


func _shot(label: String) -> void:
	for f in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg("%s/%s.jpg" % [out, label], 0.88)
