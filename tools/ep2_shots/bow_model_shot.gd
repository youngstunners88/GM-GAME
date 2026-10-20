extends Node
## The founder bow on its own (skill ep2-founder-bow): behind / right / top at rest, half draw and full draw, so the model, string, arrow and hands are judged before any
## viewmodel placement.   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/bow_model_shot.tscn -- out=<dir>
var _out := ".farm/bow_model"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1000, 800)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.72)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var bow: Node3D = Ep2BowView.make_founder()
	vp.add_child(bow)
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	cam.current = true
	var views: Array = [["behind", Vector3(-0.1, 0.1, -2.6), Vector3(0, 0.1, 0)], ["right", Vector3(-2.6, 0.1, -0.2), Vector3(0, 0.1, -0.1)],
		["left", Vector3(2.6, 0.1, -0.2), Vector3(0, 0.1, -0.1)], ["top", Vector3(0.0, 2.8, -0.2), Vector3(0, 0, -0.1)], ["front", Vector3(0.4, 0.1, 2.6), Vector3(0, 0.1, 0)]]
	for state in [["rest", 0.0], ["full", 1.0]]:
		Ep2BowView.update(bow, float(state[1]), true)
		for v in views:
			cam.position = v[1]
			cam.look_at(v[2], Vector3.UP)
			for i in 4:
				await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, state[0], v[0]])
	# the emblem close up, both sides (the GM logo must read like the rifle's): camera 0.30 m off the riser
	Ep2BowView.update(bow, 0.0, true)
	for side in [1.0, -1.0]:
		cam.fov = 30.0
		cam.position = Vector3(0.0 + side * 0.30, 0.15, -0.076)
		cam.look_at(Vector3(0.0, 0.133, -0.076), Vector3.UP)
		for i in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/emblem_%s.png" % [_out, "plus_x" if side > 0 else "minus_x"])
	var arrow: Node3D = bow.get_node("NockedArrow")
	print("BOW_MODEL_SHOT nock=", bow.get_node("Nock").position, " arrow=", arrow.position, " visible=", arrow.visible, " hand=", bow.get_node("RightHand").position, " limbs=", bow.get_meta("limbs").size())
	get_tree().quit()
