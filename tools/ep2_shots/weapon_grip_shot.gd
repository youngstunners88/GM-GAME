extends Node
## Fixed-resolution actual mine-lift gameplay camera; fixture ownership is dev-only.
var room: Ep2Interlude
var viewport: SubViewport
var out: String = "/tmp/lil-blunt-weapon-proof"
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=")
	DirAccess.make_dir_recursive_absolute(out)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	room = load("res://src/episode2/chamber/mine_lift.tscn").instantiate()
	viewport.add_child(room)
	var state := Ep2ArmoryState.post_hideout()
	state.acquire(Ep2ArmoryState.REM)
	room.bind_armory(state)
	room.setup()
	room.set_physics_process(false)
	room._show_blocks_control = false
	await advance(0.5)
	room.select_weapon(Ep2ArmoryState.REM)
	await advance(0.3)
	await capture("01_remington_hip")
	room.set_aim(true)
	await advance(0.5)
	await capture("02_remington_ads")
	room.set_aim(false)
	await advance(0.5)
	room.shoot()
	await advance(0.0167)
	await capture("03a_trigger_start")
	await advance(0.0333)
	await capture("03_remington_recoil")
	await advance(0.15)
	await capture("03b_trigger_recovery")
	await advance(0.50)
	state.record_corpse("fixture:archer", 6, true)
	state.claim_corpse("fixture:archer")
	room.select_weapon(Ep2ArmoryState.BOW)
	await advance(0.3)
	await capture("04_bow_nocked")
	room.shoot()
	await advance(0.35)
	await capture("05_bow_half_draw")
	await advance(0.32)
	await capture("06_bow_full_draw")
	await advance(0.06)
	await capture("07_bow_release")
	await advance(0.5)
	room.toggle_armory()
	await capture("08_armory")
	room.toggle_armory()
	room.queue_free()
	await get_tree().process_frame
	# Separate diagnostic view of the same shipping bear rig and shared bow.
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.26, 0.29, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	environment.environment = env
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, -0.5, 0.0)
	viewport.add_child(sun)
	var cam := Camera3D.new()
	viewport.add_child(cam)
	cam.position = Vector3(3.5, 1.6, 3.5)
	cam.look_at(Vector3(0, 1.2, 0))
	cam.fov = 35
	cam.current = true
	var world := Node3D.new()
	viewport.add_child(world)
	var bear := Ep2BearKit.make_bear(world, Vector3.ZERO)
	Ep2BearKit.add_bow(bear)
	Ep2BearKit.pose(bear, "aim")
	for i in 42:
		bear.step(1.0 / 60.0)
		Ep2BearKit.tick_pose(bear, 1.0 / 60.0)
		await get_tree().process_frame
	await capture("09_bear_full_draw")
	Ep2BearKit.pose(bear, "shot")
	for i in 6:
		bear.step(1.0 / 60.0)
		Ep2BearKit.tick_pose(bear, 1.0 / 60.0)
		await get_tree().process_frame
	await capture("10_bear_release")
	viewport.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func advance(seconds: float) -> void:
	for i in maxi(1, int(round(seconds * 60.0))):
		room.step(1.0 / 60.0)
		await get_tree().process_frame

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("WEAPON_CAPTURE: ", label)
