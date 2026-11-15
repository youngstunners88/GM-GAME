extends Node
## Evidence for the founder's River Assets (2026-11-15): Hammer's varied raft crews, Logan's cabin row with the neighbour wing and
## its mine4gold.app / Uniswap / LP surfaces, and the improved vulture in its flight, perch and carcass poses. Real renderer:
##   SHOT_OUT=/tmp/x SHOT_MODE=river|lake|vulture godot --rendering-method gl_compatibility --resolution 1280x720 \
##     res://tools/ep2_shots/river_assets_shot.tscn
var vp: SubViewport
var out: String

func _ready() -> void:
	out = OS.get_environment("SHOT_OUT")
	if out.is_empty(): out = OS.get_user_data_dir().path_join("river_assets_shot")
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	match OS.get_environment("SHOT_MODE"):
		"lake": await lake()
		"vulture": await vulture()
		_: await river()
	get_tree().quit()

func save(label: String) -> void:
	for frame in 4: await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), 0.86)
	print("RIVER_ASSETS_SHOT ", label)

func river() -> void:
	var st := Ep2ArmoryState.post_hideout()
	st.purchase_river_gear("btc")
	st.purchase_sniper("btc")
	var c: RiverCoverChamber = load("res://src/episode2/chamber/river_cover.tscn").instantiate() as RiverCoverChamber
	vp.add_child(c)
	c.set_physics_process(false)
	c.debug_no_ranged = true
	c.bind_armory(st)
	c.setup(0, [], 0)
	c._spawn_raft(0, 0, 60.0)
	c._spawn_raft(1, 0, 110.0)
	c._spawn_raft(1, 1, 110.0)
	c._step_rafts(0.0)
	c._sync_visuals()
	c._hud_layer.hide() if "_hud_layer" in c else null
	var cam := Camera3D.new()
	c.add_child(cam)
	cam.current = true
	var n: int = 0
	for r in c.get_rafts():
		var men: Array = r["men"]
		if n == 1:
			((men[0] as Dictionary)["folk"] as Ep2TownFolk).set_pose("draw")
		var at: Vector3 = (r["node"] as Node3D).global_position
		var s: float = float(r["s"])
		cam.global_position = at + c.river_right(s) * -6.5 * signf(float(r["lateral"])) + c.river_dir(s) * 2.0 + Vector3(0, 2.2, 0)
		cam.look_at(at + Vector3(0, 1.0, 0))
		await save("raft_%d_crew%d" % [n, men.size()])
		n += 1

func lake() -> void:
	var c: LogansLakeChamber = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	vp.add_child(c)
	c.setup()
	c.set_physics_process(false)
	c.get_viewmodel().set_shown(false)
	c._hud_layer.hide()
	for v in [["approach_trail", Vector3(-8, 0, 2), Vector3(-21, 2.5, 16)], ["trail_passing", Vector3(-9, 0, 19.6), Vector3(-20, 2.6, 19.6)], ["courtyard", Vector3(-13.5, 1, 15.5), Vector3(-21.5, 2.2, 19.6)],
			["sign_closeup", Vector3(-16.2, 1, 19.0), Vector3(-19.8, 3.3, 19.6)], ["uniswap_crate", Vector3(-16.4, 1, 20.4), Vector3(-18.9, 1.4, 21.3)]]:
		var feet: Vector3 = v[1]
		c._player_pos = feet
		var d: Vector3 = (v[2] as Vector3) - feet - Vector3(0, c.eye_height, 0)
		c._look_yaw = atan2(d.x, d.z)
		c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
		for i in 30: c.step(1.0 / 60.0)
		c.get_viewmodel().set_shown(false)
		await save("lake_" + str(v[0]))

func vulture() -> void:
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.62, .70, .80)
	env.environment.ambient_light_color = Color(.8, .78, .72)
	env.environment.ambient_light_energy = .7
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-.9, .6, 0)
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(.55, .45, .32)
	ground.material_override = dirt
	world.add_child(ground)
	var soar := Ep2VultureMesh.build(1.25)
	world.add_child(soar)
	soar.position = Vector3(0, 2.6, 0)
	Ep2VultureMesh.flap(soar, 0.0, 0.0)
	var perch := Ep2VultureMesh.build(1.25)
	world.add_child(perch)
	perch.position = Vector3(-2.2, Ep2VultureMesh.PERCH_HEIGHT * 1.25, 1.0)
	perch.rotation = Vector3(Ep2VultureMesh.PERCH_PITCH, .8, 0)
	Ep2VultureMesh.fold(perch)
	var dead := Ep2VultureMesh.build(1.25)
	world.add_child(dead)
	dead.position = Vector3(2.2, Ep2VultureMesh.LYING_HEIGHT * 1.25, 1.2)
	dead.rotation.y = -.6
	Ep2VultureMesh.slump(dead)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 2.4, 7.5)
	cam.look_at(Vector3(0, 1.1, 0.5))
	cam.current = true
	await save("vulture_soar_perch_carcass")
	cam.position = Vector3(0, .6, 6.0)
	cam.look_at(Vector3(0, 2.6, 0))
	await save("vulture_overhead")
