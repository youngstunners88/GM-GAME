extends Node
## Both floors of Rich & Utah's Armory, to prove the racks, cases and gallery carry the founder's real weapon GLBs (2026-11-08 brief,
## "no placeholder sticks on either floor"). Same build path as the game (Ep2GoldTown.build), Compatibility renderer, 1600x900 SubViewport.
## Prints the frame's primitives and draw calls for each shot so the cost of the real guns is measured, not guessed.
##   godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . res://tools/ep2_shots/armory_real_guns_shot.tscn -- out=<dir>
var _out := ".farm/armory_real_guns"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	Ep2GoldTown.apply_desert_grade(env.environment, sun, 1.0)
	Ep2GoldTown.build(world, true)
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	world.add_child(cam)
	cam.current = true
	var L := func(p: Vector3) -> Vector3: return xf * p
	var shots: Array = [
		["d1_back_racks", L.call(Vector3(0.6, 1.65, -3.2)), L.call(Vector3(-0.4, 1.5, -11.8))],
		["d2_counter_cases", L.call(Vector3(-0.8, 1.7, -2.0)), L.call(Vector3(-2.4, 1.0, -5.2))],
		["d3_window_case", L.call(Vector3(-1.6, 1.6, -3.6)), L.call(Vector3(-3.2, 0.8, -2.2))],
		["d4_barrels_door", L.call(Vector3(0.0, 1.65, -6.5)), L.call(Vector3(-3.6, 1.0, -0.8))],
		["d5_sharps_case", L.call(Vector3(1.4, 1.7, -3.4)), L.call(Vector3(2.6, 1.0, -5.2))],
		["u1_gallery_back", L.call(Vector3(-1.0, 5.45, -8.6)), L.call(Vector3(-0.5, 5.3, -11.8))],
		["u2_gallery_left", L.call(Vector3(-2.2, 5.45, -8.8)), L.call(Vector3(-4.8, 5.0, -4.0))],
		["u3_utah_bench", L.call(Vector3(-0.2, 5.5, -8.4)), L.call(Vector3(1.6, 4.7, -10.6))],
		["u4_fascia_from_floor", L.call(Vector3(0.4, 1.65, -1.6)), L.call(Vector3(0.0, 3.6, -8.0))],
		["u5_gatling_rail", L.call(Vector3(1.4, 5.45, -6.4)), L.call(Vector3(0.2, 4.4, -8.9))],
		["c1_gatling_close", L.call(Vector3(2.0, 5.2, -9.4)), L.call(Vector3(0.2, 4.2, -8.9))],
		["c2_case_tray_close", L.call(Vector3(-3.2, 1.75, -1.2)), L.call(Vector3(-3.2, 0.82, -2.2))],
		["c3_counter_tray_close", L.call(Vector3(-2.4, 1.85, -4.1)), L.call(Vector3(-2.4, 1.1, -5.2))],
		["c4_rack_low_close", L.call(Vector3(-0.4, 1.2, -9.6)), L.call(Vector3(-0.4, 0.9, -11.8))],
		["c5_barrel_close", L.call(Vector3(-1.4, 1.6, -1.6)), L.call(Vector3(-4.2, 1.0, -0.9))],
		["c6_pegboard_close", L.call(Vector3(-2.9, 5.6, -3.0)), L.call(Vector3(-4.8, 5.4, -3.0))],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 6:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
		var rid: RID = vp.get_viewport_rid()
		print("ARMORY_GUNS_SHOT ", s[0], " prims=", RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			" draws=", RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	get_tree().quit()
