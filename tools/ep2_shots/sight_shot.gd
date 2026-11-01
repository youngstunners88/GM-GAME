extends Node
## The aiming sight (founder 2026-11-01): hip, aimed, aimed ON a target (red + brackets), at desktop and phone-landscape size.
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/sight_shot.tscn


func _ready() -> void:
	var out: String = OS.get_environment("OUT")
	if out == "":
		out = "user://sight"
	DirAccess.make_dir_recursive_absolute(out)
	for screen in [Vector2i(1280, 720), Vector2i(844, 390)]:
		for state in [["hip", 0.0, false], ["aimed", 1.0, false], ["locked", 1.0, true]]:
			var vp := SubViewport.new()
			vp.size = screen
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(vp)
			var bg := ColorRect.new()
			bg.color = Color(0.72, 0.58, 0.38)
			bg.size = Vector2(screen)
			vp.add_child(bg)
			var hud := Ep2FpsHud.new()
			vp.add_child(hud)
			hud.size = Vector2(screen)
			hud.show_ammo = false
			hud.ads = state[1]
			hud.on_target = state[2]
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			var cx: int = screen.x / 2
			var cy: int = screen.y / 2
			img.get_region(Rect2i(cx - 80, cy - 80, 160, 160)).save_png(out + "/sight-%dx%d-%s.png" % [screen.x, screen.y, state[0]])
			vp.queue_free()
	print("SIGHT_SHOTS_DONE")
	get_tree().quit()
