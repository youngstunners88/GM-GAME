extends Node
## Behavioral regression for the founder's 2026-10-23 transition document.
var failures := 0

func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1

func advance(c: Node, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)

func _ready() -> void:
	await get_tree().process_frame
	# Exercise all three boss cards past the old delayed voice start.
	var boss_voice_started := [false]
	NftIssuer._voice_player.finished.connect(func(): boss_voice_started[0] = true)
	for id in ["boss_auditor", "boss_distributor", "boss_claimjumper"]:
		NftIssuer._voice_player.stop()
		NftIssuer._voice_player.stream = null
		NftIssuer._play_congrats(NftIssuer.definition(id))
		await get_tree().create_timer(1.85).timeout
		check(id + " keeps the jingle without scheduling/loading speech", NftIssuer._jingle_player.stream != null and NftIssuer._voice_player.stream == null and not NftIssuer._voice_player.playing and not boss_voice_started[0])
	NftIssuer._play_congrats(NftIssuer.definition("test_smoke"))
	check("protocol-test congratulations retain their voice", NftIssuer._voice_player.stream != null)
	NftIssuer._voice_player.stop()

	var td: Node = get_node("/root/TransitionDirector")
	var queue: Array = td._build_queue(GameManager.EPISODE2_SCENE)
	var later_assets := false
	for path in queue:
		if "/hideout/" in str(path) or "ep2_cliff_to_hideout.ogv" in str(path):
			later_assets = true
	check("Episode 2 entry never waits for the later hideout/film assets", not later_assets)
	check("opening runner models are still warmed", queue.has("res://src/episode2/assets/leaf_cart.glb") and queue.has("res://src/episode2/assets/lil_blunt_hero.glb"))
	check("final-frame dissolve is at most 0.2 seconds", td.DISSOLVE_SECONDS <= 0.2)

	var lift: MineLiftChamber = load("res://src/episode2/chamber/mine_lift.tscn").instantiate()
	add_child(lift)
	lift.setup()
	var said: Array = []
	lift.line_spoken.connect(func(id): said.append(id))
	lift._player_pos = Vector3(0.0, 0.0, -1.0)
	advance(lift, 15.0)
	check("lift actually reaches the rising phase", lift.get_beat_name() == "RISE")
	check("Inferno never announces the handle", not said.has("vo_bull_lift_lever"))
	check("the silent handle is still physically pulled", lift._lever_t >= 1.0)
	lift._cage_y = MineLiftChamber.TOP_Y
	lift._advance_to(MineLiftChamber.Beat.SURFACE)
	lift._surface_light()
	lift._player_pos = Vector3(0.4, MineLiftChamber.TOP_Y, MineLiftChamber.EXIT_Z + 0.2)
	lift._look_yaw = 1.2
	lift._look_pitch = 0.18
	lift._bull.position = Vector3(0.75, MineLiftChamber.TOP_Y, 10.0)
	check("surface exit becomes ready while Bull is still walking", lift._show_active and lift._wants_handoff())
	var handoff: Dictionary = lift.get_handoff()
	var wood: WoodsQuadChamber = load("res://src/episode2/chamber/woods_quad.tscn").instantiate()
	add_child(wood)
	wood.handoff = handoff
	wood.setup()
	wood.debug_invulnerable = true
	check("player position is continuous through the doorway", wood.get_player_position().is_equal_approx(lift._player_pos - MineLiftChamber.SURFACE_OFFSET))
	check("first rendered eye is already at the mapped position", wood.get_camera().position.distance_to(wood.get_player_position() + Vector3(0.0, wood.eye_height, 0.0)) < 0.02)
	check("Bull does not respawn at a different place", wood._bull.position.is_equal_approx(lift._bull.position - MineLiftChamber.SURFACE_OFFSET))
	check("sideways gaze survives the handoff exactly", is_equal_approx(wood._look_yaw, 1.2) and is_equal_approx(wood._look_pitch, 0.18))
	check("same daylight is established before the cut", lift._env_node.environment.tonemap_exposure == wood._env_node.environment.tonemap_exposure and lift._surface_sun.rotation.is_equal_approx(wood._sun.rotation))
	var vista: Node3D = lift._visuals.get_node("SurfaceWoods")
	for part in ["ForestTrunks_0", "ForestCrowns_0", "ForestFerns_0", "ForestTrunks_1", "ForestTrunks_2"]:
		var a: MultiMeshInstance3D = vista.get_node(NodePath(part))
		var b: MultiMeshInstance3D = wood._visuals.get_node(NodePath(part))
		var same: bool = a.multimesh.instance_count == b.multimesh.instance_count and a.multimesh.mesh == b.multimesh.mesh
		for i in a.multimesh.instance_count:
			if a.multimesh.get_instance_transform(i) != b.multimesh.get_instance_transform(i):
				same = false
		check(part + " has identical meshes and every placement on both sides", same)
	lift.queue_free()

	# Start the actual reveal with the player several metres away; track motion through ride.
	wood._player_pos = WoodsQuadChamber.QUAD_POS + Vector3(3.0, 0.0, -5.0)
	wood._bull.position = WoodsQuadChamber.QUAD_POS + Vector3(3.0, 0.0, -1.2)
	wood._hold = 0.0
	wood._advance_to(WoodsQuadChamber.Beat.REVEAL)
	var clock := [0.0]
	var speech: Array = []
	wood.line_spoken.connect(func(id):
		if id in ["vo_bull_quad_reveal", "vo_lb_quad_ok", "vo_bull_quad_mount"]:
			speech.append([id, clock[0], wood._vo_len(id)]))
	var before: Vector3 = wood._player_pos
	var max_jump := 0.0
	var frames := 0
	while wood.get_beat_name() != "RIDE" and frames < 2400:
		clock[0] += 1.0 / 60.0
		wood.step(1.0 / 60.0)
		max_jump = maxf(max_jump, wood._player_pos.distance_to(before))
		before = wood._player_pos
		frames += 1
	var complete_lines: bool = speech.size() == 3
	for i in range(1, speech.size()):
		if float(speech[i][1]) - float(speech[i - 1][1]) < float(speech[i - 1][2]) - 0.03:
			complete_lines = false
	check("reveal, reply and mount lines finish without self-interruption", complete_lines)
	check("reveal, approach and mounting reach the ride", wood.get_beat_name() == "RIDE")
	check("whole reveal-to-ride camera has no teleport", max_jump < 0.35)
	check("quad is visible by the time the ride begins", not wood.is_quad_hidden())
	check("mounting finishes before the quad moves", not wood.is_gliding() and wood._bull_swing.is_empty())
	print("TRANSITION_FEEDBACK: %s (reveal-to-ride %.2fs; max camera step %.3fm)" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures, frames / 60.0, max_jump])
	get_tree().quit(failures)
