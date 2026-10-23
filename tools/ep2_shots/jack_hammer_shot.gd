extends Node
## Jack Hammer in the real Compatibility renderer in the town's desert light (skill ep2-jack-hammer-character): full body, three-quarter and the face
## close-up (the eye patch must read at the distance the player meets him), plus the Greet/Walk clips.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/jack_hammer_shot.tscn -- out=<dir>
var _out := ".farm/jack_hammer"


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
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = Ep2GoldTown.desert_ground_mat()
	world.add_child(ground)
	var jh := Ep2TownFolk.new()
	world.add_child(jh)
	jh.setup(Ep2Extras.JACK_HAMMER, 1.92)
	jh.position = Vector3.ZERO
	jh.face_point(Vector3(0.0, 0.0, 10.0))
	for i in 30:
		jh.step(1.0 / 60.0)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 200.0
	world.add_child(cam)
	cam.current = true
	var shots: Array = [
		["1_full_front", Vector3(0.0, 1.3, 4.6), Vector3(0.0, 0.95, 0.0)],
		["2_three_quarter", Vector3(2.6, 1.5, 3.4), Vector3(0.0, 1.0, 0.0)],
		["3_face_meeting", Vector3(0.0, 1.75, 2.2), Vector3(0.0, 1.72, 0.0)],
		["4_face_close", Vector3(0.0, 1.76, 1.0), Vector3(0.0, 1.72, 0.0)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in 6:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, s[0]])
	print("JACK_HAMMER_SHOT_DONE")
	get_tree().quit()
