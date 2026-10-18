extends Node
## The Episode 2 town's life (founder 2026-10-18): horses at the rails, the river, the railway and the train in front of Fort Knox,
## rendered in the real Compatibility renderer.
##   godot --rendering-driver opengl3 --resolution 1280x720 --path . res://tools/ep2_shots/town_life_shot.tscn -- out=.farm/townlife
var _out := ".farm/townlife"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
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
	Ep2GoldTown.build(world, false)
	var life: Ep2TownLife = world.find_child("TownLife", true, false) as Ep2TownLife
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	world.add_child(cam)
	cam.current = true
	life._wait = 0.0
	for i in 40:
		await get_tree().process_frame
	life._train_x = 25.0
	for i in 90:
		await get_tree().process_frame
	var shots: Array = [
		["horses_street", Vector3(0.0, 1.6, 1404.0), Vector3(-1.0, 1.4, 1434.0)],
		["street_end", Vector3(0.0, 1.6, 1472.0), Vector3(2.0, 6.0, 1560.0)],
		["river_wide", Vector3(26.0, 1.7, 1488.0), Vector3(-6.0, 3.0, 1545.0)],
		["river_bank", Vector3(18.0, 1.7, 1507.0), Vector3(-8.0, 0.3, 1522.0)],
		["train_close", Vector3(18.0, 1.7, 1500.0), Vector3(2.0, 3.0, 1546.0)],
	]
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
		print("TOWN_LIFE_SHOT ", s[0], " train_x=", snappedf(life._train_x, 0.1), " visible=", life._train.visible)
	get_tree().quit()
