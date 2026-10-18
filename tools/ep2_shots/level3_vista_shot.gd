extends Node
## Real Compatibility renders of Level 3 (Gold Rush) at several points on the ride into town, so "do I see the train,
## the lake and the horses?" is answered by a picture, not by code. Run with opengl3:
##   godot --rendering-driver opengl3 --resolution 1280x720 --path . res://tools/ep2_shots/level3_vista_shot.tscn -- out=.farm/l3
var out := ".farm/l3"
var stops: Array = [300.0, 1200.0, 2100.0, 2900.0, 3050.0, 3300.0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
		if arg.begins_with("stops="):
			stops = []
			for s in arg.trim_prefix("stops=").split(","):
				stops.append(float(s))
	DirAccess.make_dir_recursive_absolute(out)
	var level: Node = load("res://src/level/level_03_gold_rush.tscn").instantiate()
	add_child(level)
	for i in 20:
		await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("no player in level 3")
		get_tree().quit(1)
		return
	player.set_physics_process(false)
	for x in stops:
		player.global_position = Vector2(x, 560.0)
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam == null:
			cam = player.find_child("*", true, false) as Camera2D
		if cam:
			cam.position_smoothing_enabled = false
			cam.reset_smoothing()
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := out.path_join("l3_x%04d.png" % int(x))
		get_viewport().get_texture().get_image().save_png(path)
		print("L3_CAPTURE: ", path)
	get_tree().quit(0)
