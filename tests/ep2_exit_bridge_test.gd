extends Node
## EP2 EXIT BRIDGE (founder 2026-10-27: "now Inferno Bull walks through the side beam that leads the walkway into the forest. The
## beam must prevent anyone from walking through it."). The real chain: the lift tops out, Inferno leads out, Lil Blunt walks out
## of the cage into the prebuilt woods, and both go down the plank bridge (rails at x +-1.12, z 4..16). Inferno's centre stays in
## his lane while he is on the boards (his bulk clears the rails), Lil Blunt cannot walk through a rail from either side, and a
## retry (Inferno standing at the bridge) is the same.
## Run: godot --headless res://tests/ep2_exit_bridge_test.tscn
var failures := 0

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


## Step the woods `seconds` with Lil Blunt walking `move`; return Inferno's widest |x| while his feet are on the boards.
func _walk(root: Ep2SessionRoot, wood: WoodsQuadChamber, seconds: float) -> float:
	var widest: float = 0.0
	for i in int(seconds * 60.0):
		root._poll_free_roam()
		wood.step(1.0 / 60.0)
		var b: Vector3 = wood._bull.position
		if b.z >= WoodsQuadChamber.EXIT_BRIDGE_Z0 and b.z <= WoodsQuadChamber.EXIT_BRIDGE_END_Z:
			widest = maxf(widest, absf(b.x))
	return widest


func _ready() -> void:
	await get_tree().process_frame
	print("EP2 EXIT BRIDGE:")
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
	# the cage at the top, Inferno where the ride leaves him (by the lever on the cage's left wall), then his own exit walk (the
	# SURFACE beat's show). Along the stretch that becomes the woods bridge (lift z 6..18 = woods z 4..16) he must be in the lane.
	lift._cage_y = MineLiftChamber.TOP_Y
	lift._player_pos = Vector3(0.0, MineLiftChamber.TOP_Y, 0.0)
	lift._ground_y = MineLiftChamber.TOP_Y
	lift._look_yaw = 0.0
	lift._bull.position = Vector3(MineLiftChamber.LEVER_POS.x + 0.65, MineLiftChamber.TOP_Y, MineLiftChamber.LEVER_POS.z)
	lift._advance_to(MineLiftChamber.Beat.SURFACE)
	var lift_widest: float = 0.0
	var off: float = MineLiftChamber.SURFACE_OFFSET.z
	for i in 60 * 7:
		lift.step(1.0 / 60.0)
		var bz: float = lift._bull.position.z - off
		if bz >= WoodsQuadChamber.EXIT_BRIDGE_Z0 and bz <= WoodsQuadChamber.EXIT_BRIDGE_END_Z:
			lift_widest = maxf(lift_widest, absf(lift._bull.position.x))
		if not lift._bull.is_walking() and lift._bull.position.z - off > WoodsQuadChamber.EXIT_BRIDGE_Z0:
			break
	check("in the lift Inferno leads out inside the woods bridge's lane (not along this walkway's edge)",
		lift_widest > 0.0 and lift_widest <= WoodsQuadChamber.BULL_BRIDGE_LANE + 0.02, "widest |x| %.2f, at %s" % [lift_widest, str(lift._bull.position)])
	# Lil Blunt walks out of the cage: the real router, held W, the cut into the prebuilt woods
	lift._player_pos = Vector3(0.0, MineLiftChamber.TOP_Y, MineLiftChamber.EXIT_Z - 0.025)
	Input.action_press("move_up")
	root._poll_free_roam()
	lift.step(1.0 / 60.0)
	var wood: WoodsQuadChamber = root.get_active()
	check("the walk out of the cage enters the woods", wood is WoodsQuadChamber)
	if not (wood is WoodsQuadChamber):
		Input.action_release("move_up")
		print("EP2_EXIT_BRIDGE: %d FAILURE(S)" % (failures + 1))
		get_tree().quit(failures + 1)
		return
	wood.set_physics_process(false)
	wood.debug_invulnerable = true
	var widest: float = _walk(root, wood, 9.0)
	Input.action_release("move_up")
	root._poll_free_roam()
	check("down the bridge Inferno's centre stays in his lane (his shoulders clear the rails at x 1.12)",
		widest <= WoodsQuadChamber.BULL_BRIDGE_LANE + 0.03, "widest |x| %.2f" % widest)
	check("...and he does walk off the end of the boards onto the trail", wood._bull.position.z > WoodsQuadChamber.EXIT_BRIDGE_END_Z,
		"z %.1f" % wood._bull.position.z)

	# Lil Blunt cannot pass through a rail from the boards (pushing diagonally into each one) ...
	for sx in [-1.0, 1.0]:
		wood._player_pos = Vector3(0.0, 0.0, 6.0)
		var crossed: bool = false
		for i in 160:
			wood._player_pos = wood._collide(wood._player_pos + Vector3(sx * 0.05, 0.0, 0.03))
			if wood._player_pos.z <= WoodsQuadChamber.EXIT_BRIDGE_END_Z and absf(wood._player_pos.x) > WoodsQuadChamber.EXIT_BRIDGE_RAIL_X - 0.3:
				crossed = true
		check("from the boards Lil Blunt cannot walk through the %s rail" % ("right" if sx > 0.0 else "left"), not crossed,
			"x %.2f" % wood._player_pos.x)
	# ... nor from the floor beside the bridge into it
	wood._player_pos = Vector3(2.2, 0.0, 9.0)
	for i in 120:
		wood._player_pos = wood._collide(wood._player_pos + Vector3(-0.05, 0.0, 0.0))
	check("from beside the bridge he cannot step through the rail onto the boards", wood._player_pos.x >= WoodsQuadChamber.EXIT_BRIDGE_RAIL_X + 0.3,
		"x %.2f" % wood._player_pos.x)
	# past the end of the boards the floor is open again
	wood._player_pos = Vector3(0.0, 0.0, WoodsQuadChamber.EXIT_BRIDGE_END_Z + 0.8)
	for i in 60:
		wood._player_pos = wood._collide(wood._player_pos + Vector3(0.05, 0.0, 0.0))
	check("past the end of the bridge he walks off sideways freely", wood._player_pos.x > 2.5, "x %.2f" % wood._player_pos.x)
	# the rails are walls for walking only: they are not trunks, so they never hide him from a bear (the sight test ignores height)
	var rail_trunks: int = 0
	for t in wood._trees:
		var tp: Vector2 = t[0]
		if tp.y >= WoodsQuadChamber.EXIT_BRIDGE_Z0 and tp.y <= WoodsQuadChamber.EXIT_BRIDGE_END_Z \
				and absf(absf(tp.x) - WoodsQuadChamber.EXIT_BRIDGE_RAIL_X) < 0.05:
			rail_trunks += 1
	check("the rails are not in the trunk grid the bears' sight test reads", rail_trunks == 0, "%d" % rail_trunks)

	# a retry: Inferno stands at the bridge (BULL_START) and leads off again
	wood._bull.stop()
	wood._bull.position = WoodsQuadChamber.BULL_START
	wood._bull_swing = {}
	wood._advance_to(WoodsQuadChamber.Beat.SNEAK)
	wood._player_pos = WoodsQuadChamber.SPAWN
	Input.action_press("move_up")
	root._poll_free_roam()
	widest = _walk(root, wood, 9.0)
	Input.action_release("move_up")
	check("after a retry Inferno starts on the boards and keeps his lane too",
		absf(WoodsQuadChamber.BULL_START.x) <= WoodsQuadChamber.BULL_BRIDGE_LANE and widest <= WoodsQuadChamber.BULL_BRIDGE_LANE + 0.03,
		"widest |x| %.2f" % widest)
	print("EP2_EXIT_BRIDGE: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
