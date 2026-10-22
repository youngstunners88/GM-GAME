extends Node3D
## The actual woods rig/materials/controller in a clear diagnostic camera.
func _ready() -> void:
	var out: String = ".farm/actor-motion/bull"
	DirAccess.make_dir_recursive_absolute(out)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.4, 0.46, 0.42)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(3.5, 2.0, 4.5)
	camera.look_at(Vector3(0, 1.4, 0))
	camera.fov = 35.0
	camera.current = true
	var bull := Ep2Actor.new()
	add_child(bull)
	bull.setup(SmeltingFacilityChamber.BULL_RIG_MODEL, 2.4, 2.9, {"walk": SmeltingFacilityChamber.BULL_WALK_CLIP}, [SmeltingFacilityChamber.BULL_IDLE])
	bull.idle_clip = SmeltingFacilityChamber.BULL_IDLE
	bull.play(bull.idle_clip, 1.0, 0.0)
	Ep2Interlude._fix_bull_materials(bull.model)
	var hero := Ep2BullHero.dress(bull)
	for frame in 180:
		if frame >= 60 and frame < 120:
			hero.aim_at(Vector3(0, 1.4, 10))
		if frame == 90:
			hero.fire_at(Vector3(0, 1.4, 10))
		bull.step(1.0 / 60.0)
		await get_tree().process_frame
		if frame in [30, 80, 92, 160]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/frame_%03d.png" % [out, frame])
	get_tree().quit()
