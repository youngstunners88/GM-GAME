extends Node
## EP2 DOOR STRIDE (founder 2026-10-27: "The transition from the smelting facility to the elevator still glitches slightly but is much
## better"). Walking through the hideout's open elevator door with W HELD - through the real input router, which forwards a held key
## only when it changes - Lil Blunt keeps walking into the lift: the held move, the run state and the stride/bob phase cross the cut,
## and the eye does not jump. The hideout used to hand over only the gaze and positions: he stood still in the doorway with W held.
## Run: godot --headless res://tests/ep2_door_stride_test.tscn
var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	print("EP2 DOOR STRIDE:")
	var root: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(root)
	root.set_process(false)                    # the test is the frame clock
	root.configure([{"chamber": "smelting_facility", "chamber_z": 5.0}], false)
	root.armory = Ep2ArmoryState.post_hideout()
	var hf: SmeltingFacilityChamber = load("res://src/episode2/chamber/smelting_facility.tscn").instantiate()
	hf.intro_film = false
	root.add_child(hf)
	root._active = hf
	root._wire_chamber(hf)
	hf.setup(0, [], 0)
	hf.set_physics_process(false)
	hf.chamber_cleared.connect(root._on_chamber_cleared, CONNECT_ONE_SHOT)
	root._chamber_segment = 0
	root._mode = Ep2SessionRoot.Mode.CHAMBER
	await get_tree().process_frame
	hf._on_video_film_finished()
	hf.prebuild_requested.emit("mine_lift")
	root._drive_prebuild(1.0e9)
	var pl: MineLiftChamber = root._pb_node as MineLiftChamber
	check("the lift is built behind the hideout", pl != null)
	if pl == null:
		_done()
		return
	pl.set_physics_process(false)
	# the EXIT beat for real until the door is open (the same sequence the seamless chain gate plays)
	var said: Array = []
	hf.line_spoken.connect(func(id): said.append(id))
	hf._enter_fps()
	hf._player_pos = Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z - 2.5)
	hf._look_yaw = 0.0
	hf._look_pitch = 0.0
	hf._beat = SmeltingFacilityChamber.Beat.EXIT
	hf._on_beat_entered(SmeltingFacilityChamber.Beat.EXIT)
	for i in 60 * 40:
		if hf._bull.position.z > SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF and not hf._bull.is_hopping():
			break
		hf.step(1.0 / 60.0)
		root._drive_portal()
	for i in 60 * 12:
		if said.has("vo_bull_lava2") and hf._hold <= 0.0:
			break
		hf.step(1.0 / 60.0)
		root._drive_portal()
	hf._player_pos = Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF + 0.6)
	for i in 60 * 3:
		hf.step(1.0 / 60.0)
		root._drive_portal()
		if hf._exit_open() and hf._hold <= 0.0 and not hf._show_active:
			break
	check("the door is open", hf._exit_open())
	# W held through the REAL router (it forwards a key once, when it changes) and walk to the doorway plane
	Input.action_press("move_up")
	root._poll_free_roam()
	var phase_before: float = 0.0
	var eye_before: Vector3 = Vector3.ZERO
	for i in 60 * 8:
		if root.get_active() != hf:
			break
		phase_before = hf._walk_phase
		eye_before = hf._camera.global_position
		root._poll_free_roam()
		hf.step(1.0 / 60.0)
		root._drive_portal()
	check("the walk reaches the doorway and the lift takes over", root.get_active() == pl)
	if root.get_active() != pl:
		Input.action_release("move_up")
		_done()
		return
	check("the held walk crosses the cut (no new key event needed)", pl._move_input == Vector2(0.0, 1.0) and pl._moving,
		"move %s moving %s" % [str(pl._move_input), str(pl._moving)])
	check("the stride/bob phase continues instead of restarting", absf(pl._walk_phase - phase_before) < 0.5,
		"%.2f -> %.2f" % [phase_before, pl._walk_phase])
	var eye_after: Vector3 = pl.get_camera().global_position - SmeltingFacilityChamber.LIFT_OFFSET
	check("the eye does not jump at the cut (same picture)", eye_after.distance_to(eye_before) < 0.12,
		"%.3f m" % eye_after.distance_to(eye_before))
	var z0: float = pl._player_pos.z
	for i in 30:
		root._poll_free_roam()
		pl.step(1.0 / 60.0)
	check("...and he keeps walking into the lift on the next ticks", pl._player_pos.z > z0 + 0.9, "advanced %.2f m" % (pl._player_pos.z - z0))
	Input.action_release("move_up")
	root._poll_free_roam()
	var z1: float = pl._player_pos.z
	pl.step(1.0 / 60.0)
	check("releasing W stops him normally after the cut", is_equal_approx(pl._player_pos.z, z1) and not pl._moving)
	_done()


func _done() -> void:
	print("EP2_DOOR_STRIDE: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
