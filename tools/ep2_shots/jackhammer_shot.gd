extends Node
## Actual town art and lighting at walk-up eye height. Mounted firing proof is in ep2_gatling_hits_test -- capture=...
func _ready() -> void:
	var out: String = "/tmp/jackhammer-shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out)
	var c: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	var cam: Camera3D = c.get_camera()
	cam.current = true
	var board: Vector3 = Ep2TownPosters.BOARD_POS
	var axf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	var sxf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Saloon"))
	var shots: Array = [
		["board", board + Vector3(1.8, 1.65, 0), board + Vector3(0, 1.75, 0)],
		["saloon_porch", sxf * Vector3(0.4, 1.65, 3.4), sxf * Vector3(0, 1.9, 0)],
		["saloon_jack_close", sxf * Vector3(2.35, 1.65, 1.2), sxf * Vector3(2.35, 1.95, 0)],
		["armory_front", axf * Vector3(-0.8, 1.65, 4.5), axf * Vector3(-1.0, 1.65, 0)],
		["armory_left", axf * Vector3(-4.6, 1.65, 1.2), axf * Vector3(-4.6, 1.5, 0)],
		["armory_right", axf * Vector3(1.8, 1.65, 1.2), axf * Vector3(1.8, 1.45, 0)],
		["gatling_from_porch", axf * Vector3(2.5, 1.65, 2.8), axf * Vector3(30, 2.0, 1.6)],
	]
	for shot in shots:
		cam.global_position = shot[1]
		cam.look_at(shot[2], Vector3.UP)
		for frame in 6: await RenderingServer.frame_post_draw
		cam.get_viewport().get_texture().get_image().save_png(out.path_join(shot[0] + ".png"))
	print("JACKHAMMER_SHOTS: COMPLETE")
	c.queue_free()
	await get_tree().process_frame
	get_tree().quit()
