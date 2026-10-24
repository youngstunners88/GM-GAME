extends Node
## Actual root handoff with a continuously held W; no input re-press across the doorway.
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")
var out := "work/transition2/before"

func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("TRANSITION2_SHOT ", label)

func _ready() -> void:
	if OS.get_environment("SHOT_OUT") != "": out = OS.get_environment("SHOT_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	if "rideonly=1" in OS.get_cmdline_user_args():
		var scene: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
		add_child(scene)
		scene.setup()
		scene.set_physics_process(false)
		await capture_ride(scene)
		get_tree().quit()
		return
	var root: Ep2SessionRoot = ROOT.instantiate()
	add_child(root)
	root.configure([{"chamber": "smelting_facility", "chamber_z": 5.0}], false)
	root.armory = Ep2ArmoryState.post_hideout()
	root._chamber_segment = 0
	root._on_chamber_cleared({"story": true, "next_chamber": "mine_lift"})
	root.set_process(false)
	root.set_physics_process(false)
	var lift: MineLiftChamber = root.get_active()
	lift.set_physics_process(false)
	# Render each warm view, rather than completing all views without drawing.
	while not root.is_prebuilt("woods_quad"):
		root._drive_prebuild(7.0)
		await get_tree().process_frame
	for i in 3: await get_tree().process_frame
	lift._cage_y = MineLiftChamber.TOP_Y
	lift._advance_to(MineLiftChamber.Beat.SURFACE)
	lift._gate_open = 1.0
	lift._player_pos = Vector3(0.0, MineLiftChamber.TOP_Y, 0.8)
	lift._ground_y = MineLiftChamber.TOP_Y
	lift._bull.position = Vector3(0.75, MineLiftChamber.TOP_Y, 4.5)
	lift._look_yaw = 0.0
	lift._look_pitch = -0.04
	lift._surface_light()
	lift._tick(0.0)
	lift._update_camera(0.0)
	lift._sync_visuals()
	await snap("01_inside_open_gate")
	Input.action_press("move_up")
	root._poll_free_roam()
	var switched := false
	var samples: Array = []
	for frame in 210:
		var c: Ep2Interlude = root.get_active()
		c.set_physics_process(false)
		root._poll_free_roam()
		var t: int = Time.get_ticks_usec()
		c.step(1.0 / 60.0)
		var cpu: float = (Time.get_ticks_usec() - t) / 1000.0
		var active: Ep2Interlude = root.get_active()
		samples.append({"frame": frame, "chamber": active._chamber_id(), "z": active._player_pos.z, "input": active._move_input.y, "moving": active._moving, "phase": active._walk_phase, "bull_z": active._bull.position.z, "cpu_ms": cpu})
		if not switched and active != lift:
			switched = true
			print("TRANSITION2_HANDOFF ", samples[-1])
			await snap("03_first_woods")
		elif frame == 60: await snap("02_exit_beam")
		elif frame == 205: await snap("04_after_walk")
		if frame % 30 == 0: await get_tree().process_frame
	Input.action_release("move_up")
	var file := FileAccess.open(out.path_join("walk.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "\t"))
	var wood: WoodsQuadChamber = root.get_active()
	wood.set_physics_process(false)
	await capture_ride(wood)
	get_tree().quit()


func capture_ride(wood: WoodsQuadChamber) -> void:
	wood.debug_invulnerable = true
	wood._show_active = false
	wood.armory.active_gun().rounds = 6
	wood.armory.active_gun().reserve = 18
	wood._reveal_quad()
	wood._begin_ride()
	wood._tick_viewmodel(0.0)
	wood._ride_s = 120.0
	var road: Array = wood._ride_sample(wood._ride_s)
	wood._quad.position = road[0]
	wood._quad_yaw = road[1]
	wood._quad.rotation.y = wood._quad_yaw
	wood._seat_riders()
	wood._look_yaw = wood._quad_yaw
	wood._look_pitch = -0.04
	wood.release_look()
	wood._update_camera(0.0)
	wood._sync_visuals()
	for i in 2: await get_tree().process_frame
	# Reconstruct only the former eye setting on identical unchanged driver/pack geometry.
	wood.eye_height = 1.40
	wood._update_camera(0.0)
	await snap("05_rider_old_eye")
	wood._bull.visible = false
	await snap("05_old_eye_no_driver")
	wood._bull.visible = true
	wood.eye_height = WoodsQuadChamber.BACK_EYE
	wood._update_camera(0.0)
	await snap("05_rider_forward")
	wood._bull.visible = false
	await snap("05_new_eye_no_driver")
	wood._bull.visible = true
	wood.set_aim(true)
	wood._vm.gun.ads = 1.0
	wood._vm.step(1.0, false, false, 0.0)
	wood._update_camera(0.0)
	await snap("06_rider_ads")
	for angle in [-PI * 0.5, PI * 0.5, PI]:
		wood._look_yaw = wood._quad_yaw + angle
		wood._update_camera(0.0)
		await snap("side_%d" % int(rad_to_deg(angle)))
	var bear: Ep2BearBrain = wood.get_bears("road")[0]
	bear.actor.position = (wood._ride_sample(wood._ride_s + 22.0)[0] as Vector3)
	bear.actor.visible = true
	Ep2BearKit.pose(bear.actor, "idle")
	var eye: Vector3 = wood._player_pos + Vector3.UP * wood.eye_height
	var aim: Vector3 = bear.actor.position + Vector3.UP * 1.5
	var d: Vector3 = (aim - eye).normalized()
	wood._look_yaw = atan2(d.x, d.z)
	wood._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	wood._update_camera(0.0)
	await snap("07_aim_road_bear")
	var hp: int = bear.hp
	print("TRANSITION2_SHOT bear ray=", wood._bear_on_ray(eye, d) == bear, " fired=", wood.shoot(), " hp=", hp, "->", bear.hp)
	wood._tick_viewmodel(0.0)
	await snap("08_hit_road_bear")
