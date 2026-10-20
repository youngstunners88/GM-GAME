extends Node
## The jailhouse and its accomplice in the real Compatibility renderer from Lil Blunt's eye height (skill ep2-jailhouse). The town is built
## by the game's own Ep2GoldTown.build (so the stone, the sign, the hole-cut windows and the yard are what the game draws).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/jail_shot.tscn -- out=<dir>
var _out := ".farm/jail"


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
	var acc := Ep2TownFolk.new()
	world.add_child(acc)
	acc.setup(Ep2Extras.PRISONER, 1.74)
	acc.position = Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots["accomplice"])
	acc.face_point(Ep2GoldTown.local_to_world("Bldg_Jail", Ep2GoldTown.jail_spots["visit"]))
	for i in 30:
		acc.step(1.0 / 60.0)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 900.0
	world.add_child(cam)
	cam.current = true
	var L := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Jail", p)
	var shots: Array = [
		["1_from_the_drop", Vector3(0.0, 1.65, 1403.0), L.call(Vector3(0.0, 2.2, 0.0))],
		["2_road_approach", Vector3(-12.0, 1.65, 1403.5), L.call(Vector3(0.0, 2.4, -1.0))],
		["3_door", L.call(Vector3(0.8, 1.65, 6.0)), L.call(Vector3(0.0, 2.2, -1.0))],
		["4_side_with_town", Vector3(-20.0, 1.65, 1409.0), L.call(Vector3(-3.0, 2.4, -3.0))],
		["5_inside_office", L.call(Vector3(-0.2, 1.65, -0.9)), L.call(Vector3(-1.0, 1.5, -6.0))],
		["6_the_cell", L.call(Vector3(-1.85, 1.65, -3.5)), acc.position + Vector3(0.0, 1.35, 0.0)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 6:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
	print("JAIL_SHOT_DONE")
	get_tree().quit()
