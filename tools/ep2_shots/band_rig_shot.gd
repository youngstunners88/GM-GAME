extends Node3D
## The hall band on a bare floor, face on and from the side, at three moments: are both hands on each instrument, and does it move?
##   godot --path . --rendering-method gl_compatibility res://tools/ep2_shots/band_rig_shot.tscn -- out=<dir>
var _out := ".farm/band_rig"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	get_viewport().size = Vector2i(1280, 640)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.3, 0.28)
	env.environment.ambient_light_color = Color(0.7, 0.68, 0.64)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	add_child(sun)
	var house := Ep2AuctionHouse.new()
	add_child(house)
	house._kit = (load(Ep2AuctionHouse.KIT) as PackedScene).instantiate() as Node3D
	var x: float = -3.0
	for row in Ep2AuctionHouse.BAND:
		var f: Ep2TownFolk = house._person(str(row[0]), Vector3(x, 0, 0), 1.66 if x < -2.5 else 1.78)
		f.looping_clips.assign(["Idle", "Play"])
		f.face_point(Vector3(x, 0, 10))
		f.hold_clip("Idle")
		var kind: String = str(Ep2AuctionHouse.BAND_KIND.get(str(row[3]), "lead"))
		var play: Node = load(Ep2AuctionHouse.BAND_PLAY).new()
		f.add_child(play)
		play.setup(f, kind, house._kit_copy(str(row[3])) if str(row[3]) != "" else null, house._kit_copy("Auc_FiddleBow") if kind == "fiddle" else null)
		house._folk.append(f)
		x += 1.5
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40
	var views := [["front", Vector3(0, 1.35, 7.2), Vector3(0, 1.2, 0)], ["side", Vector3(6.5, 1.5, 3.0), Vector3(0, 1.2, 0)]]
	for moment in 3:
		for i in 20:
			for f in house._folk: (f as Ep2TownFolk).step(1.0 / 60.0)
			await get_tree().process_frame
		for v in views:
			cam.look_at_from_position(v[1], v[2], Vector3.UP)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, v[0], moment])
	print("BAND_RIG_DONE")
	get_tree().quit()
