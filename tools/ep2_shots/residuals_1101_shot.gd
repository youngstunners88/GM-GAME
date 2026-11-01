extends Node
## Founder residuals 2026-11-01: real-renderer captures of the changed views (run windowed, Compatibility renderer, like the web build):
##   approach-<m>.png   the lake approach from the trail (grassland, signpost, Logan's camp smoke) at <m> metres before the shore
##   rider.png          the chasing rider seated on his horse (camera looking back down the trail)
##   vm-<gun>.png       the coach gun / MP18 / golden Thompson in Lil Blunt's hands
##   showcase.png       the Armory panel with the MP18 turning in the display case
##   patch.png          Dude's Chill Bud patch
## OUT=<dir> godot --path . --rendering-driver opengl3 tools/ep2_shots/residuals_1101_shot.tscn

var out: String = ""


func _shot(name: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("RESIDUAL_SHOT ", name)


func _ready() -> void:
	out = OS.get_environment("OUT")
	if out == "":
		out = "user://residuals_1101"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 720)
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail)
	session._active = trail
	session._wire_chamber(trail)
	trail.setup()
	trail.set_physics_process(false)
	trail.debug_invulnerable = true
	session._drive_prebuild(1e9)
	var lake: Node = session._pb_node
	for i in 220:
		trail.preview_lake(lake)
	for distance in [260.0, 175.0, 110.0, 40.0]:
		trail._place_at_distance(trail._route_total - distance)
		trail._look_yaw = trail._travel_yaw
		trail._look_pitch = -0.02
		trail._blend_lake_light()
		trail._update_camera(0)
		trail._sync_visuals()
		await _shot("approach-%d" % int(distance))
	# the chasing rider, seen over the shoulder
	trail._place_at_distance(LakeTrailChamber.RIDER_START_S + 6.0)
	for i in 90:
		trail.step(1.0 / 60.0)
	var rider: Dictionary = trail._bandits[trail._bandits.size() - 1]
	var at: Vector3 = trail._bandit_world_position(rider)
	var eye: Vector3 = trail.get_camera().global_position
	trail._look_yaw = atan2(at.x - eye.x, at.z - eye.z)
	trail._look_pitch = atan2(at.y + 1.6 - eye.y, Vector2(at.x - eye.x, at.z - eye.z).length())
	trail._update_camera(0)
	await _shot("rider")
	# the new guns in his hands
	for id in Ep2ArmoryState.SHOP_GUNS:
		trail.armory.purchase_firearm(id, "btc")
		trail.armory.select(id)
		trail._place_at_distance(40.0)
		trail._look_yaw = trail._travel_yaw
		trail._look_pitch = 0.0
		for i in 20:
			trail.step(1.0 / 60.0)
		trail._update_camera(0)
		await _shot("vm-" + id)
	# the showcase at the screens it must work on (an off-screen viewport of exactly that size)
	for screen in [Vector2i(1600, 900), Vector2i(844, 390), Vector2i(390, 844)]:
		for pick in [Ep2ArmoryState.MP18, Ep2ArmoryState.TOMMY]:
			var vp := SubViewport.new()
			vp.size = screen
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			add_child(vp)
			var backdrop := ColorRect.new()
			backdrop.color = Color(0.32, 0.24, 0.16)
			backdrop.size = Vector2(screen)
			vp.add_child(backdrop)
			var shop := Ep2ArmoryShop.new()
			vp.add_child(shop)
			shop.open_shop(trail.armory, 9)
			for i in Ep2ArmoryState.SHOP.size():
				if str(Ep2ArmoryState.SHOP[i]["id"]) == pick:
					shop.index = i
			for i in 50:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(out + "/showcase-%dx%d-%s.png" % [screen.x, screen.y, pick])
			print("RESIDUAL_SHOT showcase ", screen, " ", pick)
			vp.queue_free()
	# the patch, in its own small lit set
	session.queue_free()
	await get_tree().process_frame
	var set_root := Node3D.new()
	add_child(set_root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.82)
	env.environment.ambient_light_color = Color(0.8, 0.78, 0.7)
	env.environment.ambient_light_energy = 0.6
	set_root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	set_root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color(0.62, 0.5, 0.34)
	ground.material_override = dirt
	ground.position = Ep2BudPatch.POS
	set_root.add_child(ground)
	Ep2BudPatch.build(set_root)
	var cam := Camera3D.new()
	set_root.add_child(cam)
	cam.position = Ep2BudPatch.POS + Vector3(3.2, 1.7, 2.6)
	cam.look_at(Ep2BudPatch.POS + Vector3(0, 0.35, 0))
	cam.current = true
	await _shot("patch")
	print("RESIDUAL_SHOTS_DONE")
	get_tree().quit()
