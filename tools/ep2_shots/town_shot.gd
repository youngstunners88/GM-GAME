extends Node
## The GoldMine town on its own (skill ep2-gold-rush-town): street views graded against the founder's town target.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 \
##       --path . res://tools/ep2_shots/town_shot.tscn -- out=.farm/town/street
var _out := ".farm/town/street"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	world.add_child(env)
	var sun := DirectionalLight3D.new()
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
	world.add_child(cam)
	cam.current = true
	var shots: Array = [["street", Vector3(0.5, 1.55, 1398.0), Vector3(1.0, 4.0, 1440.0)],
		["cert_front", Vector3(-1.0, 1.55, 1404.0), Vector3(-9.0, 3.5, 1412.0)],
		["saloon_front", Vector3(1.0, 1.55, 1405.0), Vector3(9.0, 3.5, 1414.0)],
		["cert_inside", Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.5, 1.55, -1.2)), Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 1.2, -6.0))],
		["saloon_inside", Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.0, 1.55, -1.0)), Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(-1.0, 1.4, -9.0))],
		["approach", Vector3(1.0, 2.8, 1250.0), Vector3(5.0, 8.0, 1450.0)]]
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, s[0]])
		print("shot ", s[0])
	get_tree().quit()
