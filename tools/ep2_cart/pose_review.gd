extends Node3D
var cart: Ep2RoadCart
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.40, 0.48)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.90, 1.0)
	e.ambient_light_energy = 0.65
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -25, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.50, 0.32, 0.16)
	ground.material_override = sand
	add_child(ground)
	cart = Ep2RoadCart.new()
	add_child(cart)
	cart.build("", 1.0)
	var cam := Camera3D.new()
	cam.position = Vector3(4.8, 2.5, 5.7)
	cam.fov = 38.0
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	cam.current = true
	DirAccess.make_dir_recursive_absolute("/workspace/work/cart-rebuild/review")
	for t in [0.0, 0.10, 0.22, 0.35, 0.48]:
		cart.reset_motion()
		cart.advance_motion(float(t), float(t) * 2.4)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/workspace/work/cart-rebuild/review/walk_%.2f.png" % t)
	cart.greet()
	for t in [0.0, 0.6, 0.6, 0.6, 0.6, 0.6]:
		cart.advance_motion(float(t), float(t) * 2.4)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/workspace/work/cart-rebuild/review/greet_%.2f.png" % cart.greeting_time)
	print("CART_POSE_REVIEW: captured")
	get_tree().quit()
