extends Node
## Dude's Chill Bud patch with the founder's plants, in the real town under the town's own light, from Lil Blunt's eye on the lake road.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/patch_town_shot.tscn


func _ready() -> void:
	var out: String = OS.get_environment("OUT")
	if out == "":
		out = "user://patch_town"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	var c: GoldTownChamber = (load("res://src/episode2/chamber/gold_town.tscn") as PackedScene).instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	var bed: Vector3 = Ep2BudPatch.POS
	for spot in [["patch-road", bed + Vector3(2.5, 0.0, 9.0)], ["patch-reach", bed + Vector3(1.0, 0.0, 3.2)], ["patch-east", bed + Vector3(13.0, 0.0, 2.0)], ["patch-far", bed + Vector3(14.0, 0.0, 34.0)]]:
		var at: Vector3 = spot[1]
		for i in 14:
			c._player_pos = at
			c._look_yaw = atan2(bed.x - at.x, bed.z - at.z)
			c._look_pitch = -0.02
			c.step(1.0 / 60.0)
			await get_tree().process_frame
		for i in 6:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/" + str(spot[0]) + ".png")
		print("PATCH_TOWN_SHOT ", spot[0], " plants ", int(c._stable_yard._patch_root.get_meta("plants_placed", 0)) if c._stable_yard != null else -1)
	print("PATCH_TOWN_DONE")
	get_tree().quit()
