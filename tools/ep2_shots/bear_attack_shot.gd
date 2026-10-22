extends Node
## Real engine renders of the bear's brawler attacks and gait on the shipping rig, at the moments that matter, so the
## motion is LOOKED AT in Godot (not only in Blender): swipe + bite at 7 times each, and walk / run mid-stride.
##   godot --rendering-driver opengl3 --resolution 960x540 --path . res://tools/ep2_shots/bear_attack_shot.tscn -- out=.farm/bearshots
var out := ".farm/bearshots"
const TIMES := [0.0, 0.2, 0.3, 0.45, 0.55, 0.8, 1.1]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.58, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.72)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0.0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.3, 0.22)
	ground.material_override = fm
	add_child(ground)
	var cam := Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true
	var world := Node3D.new()
	add_child(world)
	for state in ["swipe", "bite"]:
		var b := Ep2BearKit.make_bear(world, Vector3.ZERO)
		b.facing = 0.0
		b.rotation.y = 0.0
		Ep2BearKit.pose(b, state)
		b.step(1.0 / 60.0)
		var t: float = 0.0
		for i in TIMES.size():
			while t < float(TIMES[i]):
				b.step(1.0 / 60.0)
				Ep2BearKit.tick_pose(b, 1.0 / 60.0)
				t += 1.0 / 60.0
			cam.position = Vector3(3.6, 1.7, 3.4)
			cam.look_at(Vector3(0, 1.1, 0.0))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d_side.png" % [state, i]))
			cam.position = Vector3(0.0, 1.7, 5.2)
			cam.look_at(Vector3(0, 1.1, 0.0))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d_front.png" % [state, i]))
		print("BEAR_ATTACK_SHOT: ", state, " clip=", b.current_clip(), " clip_len=", Ep2BearKit.clip_len(b, Ep2BearKit.SWIPE if state == "swipe" else Ep2BearKit.BITE))
		b.queue_free()
	for state in ["walk", "run"]:
		var b := Ep2BearKit.make_bear(world, Vector3.ZERO)
		Ep2BearKit.pose(b, state)
		b.walk_to(Vector3(0, 0, 60), 1.4 if state == "walk" else 3.6)
		for i in 4:
			for f in 15:
				b.step(1.0 / 60.0)
				Ep2BearKit.tick_pose(b, 1.0 / 60.0)
			cam.position = Vector3(b.position.x + 3.8, 1.5, b.position.z + 0.2)
			cam.look_at(Vector3(b.position.x, 1.0, b.position.z))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d.png" % [state, i]))
		print("BEAR_GAIT_SHOT: ", state, " clip=", b.current_clip(), " moved_z=", snappedf(b.position.z, 0.01))
		b.queue_free()
	get_tree().quit()
