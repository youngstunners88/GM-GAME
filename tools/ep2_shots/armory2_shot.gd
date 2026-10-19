extends Node
## Rich & Utah's two-storey Armory in the real Compatibility renderer, from Lil Blunt's eye height (skill ep2-armory-two-story).
## The town is built by Ep2GoldTown.build (same code as the game), Rich and Utah run their Ep2ArmoryBrain for a while first, then
## each camera renders through a 1600x900 SubViewport (a tiled window would squash a direct viewport grab).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/armory2_shot.tscn -- out=docs/episode2-quality/armory-two-story-2026-10-19
var _out := ".farm/armory2"


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
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	ground.mesh = pm
	ground.material_override = Ep2GoldTown.desert_ground_mat()
	ground.position = Vector3(0, 0, 1450)
	world.add_child(ground)
	Ep2GoldTown.build(world, true)
	var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory"))
	var rich := Ep2TownFolk.new()
	world.add_child(rich)
	rich.setup(Ep2Extras.RICH, 1.80)
	var utah := Ep2TownFolk.new()
	world.add_child(utah)
	utah.setup(Ep2Extras.UTAH, 1.85)
	var rb := Ep2ArmoryBrain.new()
	rb.walk_speed = 0.76
	rb.setup("rich", rich, xf, Ep2GoldTown.armory_spots, "counter_rich", 7101)
	var ub := Ep2ArmoryBrain.new()
	ub.walk_speed = 0.86
	ub.setup("utah", utah, xf, Ep2GoldTown.armory_spots, "bench", 7202)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	world.add_child(cam)
	cam.current = true
	var L := func(p: Vector3) -> Vector3: return xf * p
	var outside: Vector3 = L.call(Vector3(0, 0, 10))
	# let them work a while (as if he had just walked up the lane)
	for i in 900:
		rb.step(1.0 / 60.0, outside)
		ub.step(1.0 / 60.0, outside)
	var shots: Array = [
		["1_lane_approach", L.call(Vector3(6.5, 1.65, 17.0)), L.call(Vector3(0.0, 4.4, 0.0))],
		["2_porch_door", L.call(Vector3(1.2, 1.65, 6.0)), L.call(Vector3(0.0, 1.9, -3.0))],
		["3_counter_rich", L.call(Vector3(0.3, 1.65, -2.4)), rich.position + Vector3(0, 1.3, 0)],
		["4_gallery_utah", L.call(Vector3(-1.0, 1.65, -2.6)), utah.position + Vector3(0, 1.2, 0)],
		["5_racks_gatling", L.call(Vector3(2.0, 1.65, -3.6)), L.call(Vector3(-0.8, 3.6, -11.0))],
	]
	for s in shots:
		# the step that walked in also triggers the greeting for the inside shots
		if str(s[0]).begins_with("3"):
			for i in 70:
				rb.step(1.0 / 60.0, L.call(Vector3(0.3, 0, -2.4)))
				ub.step(1.0 / 60.0, L.call(Vector3(0.3, 0, -2.4)))
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 6:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
		print("ARMORY2_SHOT ", s[0], " rich=", rich.current_clip(), "@", rb.spot, " utah=", utah.current_clip(), "@", ub.spot)
	get_tree().quit()
