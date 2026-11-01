extends Node
## Guns Buff §6 horizon order: from the woods' exit looking east (Logan's Lake glimpse) and down the road to town (Dude's ranch trees
## in front of the town from the first moment the town shows).
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/horizon_shot.tscn


func _shot(out: String, name: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("HORIZON_SHOT ", name)


func _ready() -> void:
	var out: String = OS.get_environment("OUT")
	if out == "":
		out = "user://horizon"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	var woods: WoodsQuadChamber = (load("res://src/episode2/chamber/woods_quad.tscn") as PackedScene).instantiate()
	add_child(woods)
	woods.setup(0, [], 0)
	woods.set_physics_process(false)
	woods.debug_invulnerable = true
	await get_tree().process_frame
	var lake: Vector3 = Ep2LakeGlimpse.lake_world()
	for spot in [["exit-east", Vector3(14.0, 0.0, WoodsQuadChamber.FOREST_END_Z + 15.0), lake],
			["out-east-60", Vector3(10.0, 0.0, WoodsQuadChamber.FOREST_END_Z + 60.0), lake],
			["out-east-140", Vector3(6.0, 0.0, WoodsQuadChamber.FOREST_END_Z + 140.0), lake],
			["exit-ahead", Vector3(14.0, 0.0, WoodsQuadChamber.FOREST_END_Z + 15.0), Vector3(0.0, 0.0, Ep2GoldTown.TOWN_Z)],
			["road-mid", Vector3(0.0, 0.0, Ep2GoldTown.TOWN_Z - 300.0), Vector3(0.0, 0.0, Ep2GoldTown.TOWN_Z)]]:
		var at: Vector3 = spot[1]
		var look: Vector3 = spot[2]
		woods._player_pos = at
		woods._look_yaw = atan2(look.x - at.x, look.z - at.z)
		woods._look_pitch = 0.02
		for i in 12:
			woods._player_pos = at
			woods._look_yaw = atan2(look.x - at.x, look.z - at.z)
			woods._look_pitch = 0.02
			woods.step(1.0 / 60.0)
			await get_tree().process_frame
		await _shot(out, spot[0])
	print("HORIZON_SHOTS_DONE")
	get_tree().quit()
