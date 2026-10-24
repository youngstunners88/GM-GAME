extends Node
## THE SALOON'S DRINKERS (founder 2026-10-24: "sitting and drinking in the saloon as well as the balcony above"; skill ep2-saloon-drinkers)
## in the real town chamber: the balcony regulars from the street, a seated drinker at a table and one at the bar, each at the start of a
## sip and with the glass at the lips (the Ep2DrinkPose clips, built from each person's own rig).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/saloon_shot.tscn -- out=<dir>
var chamber: GoldTownChamber
var vp: SubViewport
var out := ".farm/saloon"


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
	var crowd: Ep2TownPeople = chamber.get_people()
	var seats: Array = Ep2GoldTown.saloon_seats()
	var spots: Dictionary = Ep2GoldTown.shop_spots("Bldg_Saloon")
	# seat two visitors directly: the lady at the first table, the clerk at the bar
	var visits := {"lady": 0, "clerk": 3}
	for id in visits:
		var p: Ep2TownPeople.Person = crowd.person(id)
		p.shop = "Bldg_Saloon"
		p.seat = int(visits[id])
		p.destination = "shop:Bldg_Saloon#%d" % p.seat
		p.folk.use_height = true
		var at: Vector3 = seats[p.seat]["pos"]
		p.folk.place(Vector3(at.x, 0.06, at.z))
		p.state = "shop_buy"
		crowd._start_drinking(p, spots)
	for p in crowd.people:
		p.folk.anim_player().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var S := func(v: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Saloon", v)
	var balcony_mid: Vector3 = S.call(Vector3(-1.7, Ep2GoldTown.BALCONY_Y + 1.0, 0.9))
	for beat in [["rest", 1.0], ["sip", 3.3]]:
		for p in crowd.people:
			var player: AnimationPlayer = p.folk.anim_player()
			if player.current_animation.to_lower().contains("drink"):
				player.advance(p.folk.clip_blend + 0.05)        # finish the cross-fade from the previous clip first
				player.seek(float(beat[1]), true)
		chamber.step(1.0 / 60.0)
		_look(S.call(Vector3(-1.0, 0.0, 9.5)), balcony_mid)
		await _shot("balcony_from_street_%s" % beat[0])
		var lady: Vector3 = crowd.person("lady").folk.position
		_look(S.call(Vector3(0.6, 0.0, -1.4)), lady + Vector3(0, 0.9, 0))
		await _shot("table_%s" % beat[0])
		var clerk: Vector3 = crowd.person("clerk").folk.position
		_look(S.call(Vector3(-0.2, 0.0, -5.2)), clerk + Vector3(0, 1.2, 0))
		await _shot("bar_%s" % beat[0])
	print("REGULARS ", crowd.person("grandfather").state, " ", crowd.person("grandfather").folk.position, " clip=", crowd.person("grandfather").folk.current_clip())
	print("SALOON_SHOT_DONE")
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
