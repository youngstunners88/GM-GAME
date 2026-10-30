extends Node
var checks := 0
var failed := 0
func check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failed += 1
	print("[PASS] " + label if ok else "[FAIL] " + label)

func _ready() -> void:
	var session := Ep2SessionRoot.new()
	add_child(session)
	session.set_process(false)
	var facility: SmeltingFacilityChamber = preload("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	session.add_child(facility)
	session._active = facility
	session._wire_chamber(facility)
	facility.setup()
	facility.set_physics_process(false)
	var video: Ep2VideoFilm = facility.get_video_film()
	check("the real founder film is prepared", video != null)
	for i in 250:
		facility.step(1.0 / 60.0)
		if i % 4 == 0: await get_tree().process_frame
	for i in 100:
		if facility._room_ready: break
		await get_tree().process_frame
	check("film remains active after hideout build", not video.is_done() and facility._room_ready)
	check("film does not build a separate elevator viewport", session._pb_node == null and session._pb_vp == null)
	check("film still disables the main 3D pass", get_viewport().disable_3d)
	check("hidden room simulation is frozen behind the film", facility._visuals.process_mode == Node.PROCESS_MODE_DISABLED and not facility._bull.can_process())
	video.skip()
	for i in 10:
		facility.step(1.0 / 60.0)
		await get_tree().process_frame
	check("lesson restores 3D and starts early elevator prebuild", not get_viewport().disable_3d and session._pb_id == "mine_lift")
	check("film exit resumes the room's character processing", facility._visuals.process_mode == Node.PROCESS_MODE_INHERIT and facility._bull.can_process())
	session._drive_prebuild(1.0e9)
	var prepared: MineLiftChamber = session._pb_node
	check("elevator is built before doorway travel", session.is_prebuilt("mine_lift"))
	facility._beat = facility.Beat.EXIT
	facility._show_active = false
	facility._show_blocks_control = false
	facility._hold = 0.0
	facility._player_pos = Vector3(1.1, .6, facility.PORTAL_Z + 0.02)
	facility._vel_y = 2.3
	facility._air_jumps = 1
	facility._look_yaw = 1.2
	facility._look_pitch = 0.7
	facility._move_input = Vector2(0.6, 0.8)
	facility._run_input = true
	facility._moving = true
	facility._walk_phase = 1.7
	facility._bull.position = Vector3(0.7, 0, facility.PORTAL_Z + 2.0)
	facility._bull.rotation.y = 0.3
	facility._bull.anim.play(facility._bull.walk_clip)
	facility._bull.anim.seek(0.4, true)
	facility._update_camera(0.0)
	var camera_before: Transform3D = facility._camera.global_transform
	session._drive_portal()
	check("door image stays beyond the near clip at the physical threshold", facility._portal_quad.position.z-facility._camera.position.z > facility._camera.near*2.0)
	check("portal excludes duplicate first-person weapon and HUD", not prepared._vm._shown and not prepared._hud.visible)
	check("portal mirrors Inferno's actual moving pose", prepared._bull.anim.current_animation == facility._bull.walk_clip and absf(prepared._bull.anim.current_animation_position-0.4)<0.001 and absf(prepared._bull.rotation.y-0.3)<0.001)
	session._chain_id = "mine_lift"
	session._enter_chamber_chained(0)
	var lift: MineLiftChamber = session._active
	lift.set_physics_process(false)
	check("same prebuilt elevator becomes active", lift == prepared)
	check("Inferno's walk owner retains the carried clip", lift._bull._clip == lift._bull.walk_clip)
	check("oblique yaw and steep pitch do not snap", absf(lift._look_yaw-1.2)<0.0001 and absf(lift._look_pitch-0.7)<0.0001)
	check("first camera position maps exactly across doorway", lift._camera.global_position.distance_to(camera_before.origin + facility.LIFT_OFFSET) < 0.001)
	check("first camera orientation remains continuous", lift._camera.global_basis.is_equal_approx(camera_before.basis))
	check("held movement, sprint and airborne velocity survive", lift._move_input == Vector2(0.6,0.8) and lift._run_input and lift._moving and is_equal_approx(lift._vel_y,2.3) and lift._air_jumps==1)
	check("stride phase remains continuous", absf(lift._walk_phase-1.7)<0.0001)
	check("active elevator restores the single weapon and HUD", lift._vm._shown and lift._hud.visible)
	check("parked facility loses stale forward-chain callbacks", not facility.chamber_cleared.is_connected(session._on_chamber_cleared))
	session.queue_free()
	await get_tree().process_frame
	print("EP2_FIX_CONTINUITY: %d checks, %d failed" % [checks, failed])
	get_tree().quit(failed)
