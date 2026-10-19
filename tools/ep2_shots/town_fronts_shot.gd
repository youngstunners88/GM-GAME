extends Node
## Main Street and the Armory lane at Lil Blunt's eye height (windows/doors pass, 2026-10-19). Real Compatibility renderer through a
## 1600x900 SubViewport, the town built by the game's own Ep2GoldTown.build.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/town_fronts_shot.tscn -- out=<dir>
var _out := ".farm/townfronts"


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
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	world.add_child(cam)
	cam.current = true
	var shots: Array = [
		["1_street_left_row", Vector3(6.5, 1.65, 1409.0), Vector3(-9.0, 3.2, 1432.0)],
		["2_street_right_row", Vector3(-6.5, 1.65, 1409.0), Vector3(9.0, 3.2, 1432.0)],
		["3_saloon_front", Vector3(-1.0, 1.65, 1402.0), Vector3(9.0, 2.6, 1414.0)],
		["4_treasury_front", Vector3(-3.0, 1.65, 1420.0), Vector3(9.0, 2.6, 1426.5)],
		["5_certificates", Vector3(4.0, 1.65, 1403.0), Vector3(-9.0, 2.6, 1414.0)],
		["6_up_the_street", Vector3(0.0, 1.65, 1403.0), Vector3(0.0, 3.5, 1470.0)],
		["7_armory_lane", Vector3(-9.0, 1.65, 1452.0), Vector3(-20.0, 3.0, 1468.0)],
		["8_church", Vector3(0.0, 1.65, 1452.0), Vector3(0.0, 3.0, 1478.0)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 6:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
	print("TOWN_FRONTS_DONE")
	get_tree().quit()
