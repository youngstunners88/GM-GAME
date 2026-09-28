extends Node
## Render the real room with the web-compatible renderer, including UI.
## SHOT_OUT supplies an output directory. Run this scene with opengl3.

func _ready() -> void:
	var out := OS.get_environment("SHOT_OUT")
	if out.is_empty():
		out = "user://portal-captures"
	DirAccess.make_dir_recursive_absolute(out)
	var failures: int = 0
	for protocol in ["smoke", "diamonds", "gold"]:
		var room: Node2D = load("res://src/protocol_portals/StudyRoom.tscn").instantiate()
		room.protocol = protocol
		add_child(room)
		await get_tree().create_timer(1.1).timeout
		var player: Node2D = room.get_node("Player")
		player.set_physics_process(false)
		player.position = Vector2(1900, 470)
		var camera: Camera2D = room.call("_find_camera", player)
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
		for i in range(5):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = out.path_join(protocol + ".png")
		var err := img.save_png(path)
		print("PORTAL CAPTURE: %s (%s)" % [path, err])
		# Sample the rendered image, not just node properties: the broken rooms
		# passed structural checks while 89% of the screen was nearly black.
		var visible_samples: int = 0
		var sample_count: int = 0
		for y in range(0, img.get_height(), 8):
			for x in range(0, img.get_width(), 8):
				var pixel := img.get_pixel(x, y)
				sample_count += 1
				if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 32.0 / 255.0:
					visible_samples += 1
		var coverage: float = float(visible_samples) / float(sample_count)
		print("PORTAL VISIBILITY: %s %.3f" % [protocol, coverage])
		if err != OK or coverage < 0.4:
			push_error("%s: room is blank/dark or capture failed" % protocol)
			failures += 1
		room.queue_free()
		await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
