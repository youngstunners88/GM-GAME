extends Node
## Transition 2: real held-input routing, unobstructed shaft exit, forward companion and passenger combat.
var failures := 0

func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1

func _ready() -> void:
	await get_tree().process_frame
	var root: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(root)
	root.configure([{"chamber": "smelting_facility", "chamber_z": 5.0}], false)
	root.armory = Ep2ArmoryState.post_hideout()
	root._chamber_segment = 0
	root._on_chamber_cleared({"next_chamber": "mine_lift"})
	root.set_process(false)
	root._drive_prebuild(1.0e9)
	var lift: MineLiftChamber = root.get_active()
	lift.set_physics_process(false)
	check("shaft brace exists during the lift climb", lift._exit_crossbeam != null and lift._exit_crossbeam.visible)
	lift._cage_y = MineLiftChamber.TOP_Y
	lift._player_pos = Vector3(0.0, MineLiftChamber.TOP_Y, MineLiftChamber.EXIT_Z - 0.025)
	lift._ground_y = MineLiftChamber.TOP_Y
	lift._look_yaw = 0.0
	lift._look_pitch = -0.04
	lift._advance_to(MineLiftChamber.Beat.SURFACE)
	lift._gate_open = 1.0
	lift._bull.position = Vector3(0.75, MineLiftChamber.TOP_Y, 10.0)
	check("crossbeam is gone BEFORE gate clearance", not lift._exit_crossbeam.visible)
	var prepared: WoodsQuadChamber = root._pb_node
	check("wildlife is built before reaching the door", prepared._wildlife != null)
	check("prebuilt forest ambience does not leak into shaft", not prepared._wildlife._ambience.playing)
	var said: Array = []
	prepared.line_spoken.connect(func(id): said.append(id))
	# Real router caches W, and intentionally does NOT send it again after the swap.
	Input.action_press("move_up")
	root._poll_free_roam()
	lift._walk_phase = 1.0
	lift.step(1.0 / 60.0)
	var phase: float = lift._walk_phase
	var mapped: Vector3 = lift._player_pos - MineLiftChamber.SURFACE_OFFSET
	var wood: WoodsQuadChamber = root.get_active()
	wood.set_physics_process(false)
	wood.debug_invulnerable = true
	check("the actual root enters the prebuilt woods", wood == prepared)
	check("held W survives without a new key event", wood._move_input == Vector2(0.0, 1.0) and wood._moving)
	check("stride/bob phase survives first frame", is_equal_approx(wood._walk_phase, phase))
	check("first-frame position has no restart", wood._player_pos.is_equal_approx(mapped))
	check("standing intro is not replayed at the doorway", not said.has("vo_bull_woods_sneak"))
	check("forest ambience begins on activation", wood._wildlife._ambience.playing)
	var bull_before: Vector3 = wood._bull.position
	var player_before: Vector3 = wood._player_pos
	for i in 30:
		root._poll_free_roam()
		wood.step(1.0 / 60.0)
	check("held W keeps advancing on all 30 next ticks", wood._player_pos.z > player_before.z + 1.0)
	check("Inferno walks FORWARD, never back to the first waypoint", wood._bull.position.z > bull_before.z + 0.4 and wood._bull._goal.z > bull_before.z)
	Input.action_release("move_up")
	root._poll_free_roam()
	player_before = wood._player_pos
	wood.step(1.0 / 60.0)
	check("releasing W stops normally after the handoff", wood._player_pos.is_equal_approx(player_before) and not wood._moving)
	# Carry all directions/running, not only the forward example, and retain gaze.
	for v in [Vector2(-0.6, 0.8), Vector2(0.0, -1.0), Vector2(1.0, 0.0)]:
		var data: Dictionary = wood.get_handoff()
		data.merge({"surface_player": wood._player_pos, "surface_bull": wood._bull.position, "move": v, "run": true, "moving": true}, true)
		wood.handoff = data
		wood.setup()
		check("direction %s and sprint continue through setup" % v, wood._move_input == v and wood._run_input)
	wood.walk_stop()
	wood._show_active = false
	wood._reveal_quad()
	wood._begin_ride()
	wood.release_look()
	# Place an existing road bear in the clear trail ahead: same real body/hit owner,
	# deterministic sightline fixture, no extra ammunition/targets in gameplay.
	var bear: Ep2BearBrain = wood.get_bears("road")[0]
	var f := Vector3(sin(wood._quad_yaw), 0.0, cos(wood._quad_yaw))
	bear.actor.position = wood._quad.position + f * 18.0
	bear.actor.visible = true
	Ep2BearKit.pose(bear.actor, "idle")
	var eye: Vector3 = wood._player_pos + Vector3.UP * wood.eye_height
	var aim: Vector3 = bear.actor.position + Vector3.UP * 1.5
	var d: Vector3 = (aim - eye).normalized()
	wood._look_yaw = atan2(d.x, d.z)
	wood._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	wood._update_camera(0.0)
	check("raised passenger remains over supported rear rack", wood._player_pos.is_equal_approx(wood._seat_position()) and eye.y > wood._quad.position.y + 3.3)
	check("actual road bear lies on the passenger aiming ray", wood._bear_on_ray(eye, d) == bear)
	wood.armory.active_gun().rounds = 6
	wood.armory.active_gun().reserve = 18
	wood._vm.gun.ads = 1.0
	var hp: int = bear.hp
	check("ADS shot fires from elevated passenger viewpoint", wood.shoot())
	check("passenger shot damages the aimed road bear", bear.hp < hp)
	check("shot spends one loaded round with no reserve refill", wood.armory.active_gun().rounds == 5 and wood.armory.active_gun().reserve == 18)
	print("TRANSITION2: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
