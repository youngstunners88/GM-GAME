extends Node
## P1-12 (founder 2026-11-22: "they actually need to flap their wings"): one founder vulture, close, through a full wingbeat (8 frames).
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/vulture_flap_shot.tscn -- out=<dir>
var _out := ".farm/vulture_flap"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.68, 0.82)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var bird: Node3D = Ep2VultureMesh.build(1.0)
	add_child(bird)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0.0, 0.6, 4.2)                # in front of and a little above: both wings in frame
	cam.look_at(Vector3(0.0, 0.1, 0.0), Vector3.UP)
	bird.rotation.y = PI                                          # nose (-Z) toward the camera
	for k in 8:
		Ep2VultureMesh.flap(bird, TAU * float(k) / 8.0, 1.0)
		for j in 3:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/flap_%d.png" % [_out, k])
	print("VULTURE_FLAP_DONE ", _out)
	get_tree().quit()
