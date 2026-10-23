extends Node
## Actual session-root doorway cut and full reveal-to-ride capture, Compatibility renderer.
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")
var out := "work/transitions/captures"

func snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("TRANSITION_SHOT ", label)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	StateMachine.change_state(StateMachine.State.TRANSITIONING)
	StateMachine.change_state(StateMachine.State.PLAYING)
	var root: Ep2SessionRoot = ROOT.instantiate()
	add_child(root)
	root.configure([{"chamber": "smelting_facility", "chamber_z": 5.0}], false)
	root.armory = Ep2ArmoryState.post_hideout()
	root._chamber_segment = 0
	root._on_chamber_cleared({"story": true, "chamber": "smelting_facility", "gold_awarded": 0, "gold_forfeited": 0, "next_chamber": "mine_lift"})
	root.set_process(false)
	root.set_physics_process(false)
	root._drive_prebuild(1.0e9)
	var lift: MineLiftChamber = root.get_active()
	lift.set_physics_process(false)
	lift._cage_y = MineLiftChamber.TOP_Y
	lift._advance_to(MineLiftChamber.Beat.SURFACE)
	lift._gate_open = 1.0
	lift._player_pos = Vector3(0.0, MineLiftChamber.TOP_Y, MineLiftChamber.EXIT_Z)
	lift._ground_y = MineLiftChamber.TOP_Y
	lift._bull.position = Vector3(0.75, MineLiftChamber.TOP_Y, 10.0)
	lift._look_yaw = 0.0
	lift._look_pitch = -0.04
	lift._surface_light()
	lift._update_camera(0.0)
	lift._sync_visuals()
	for i in 4:
		await get_tree().process_frame
	await snap("01_lift_threshold")
	root._on_chamber_cleared({"story": true, "chamber": "mine_lift", "gold_awarded": 0, "gold_forfeited": 0, "next_chamber": "woods_quad"})
	var wood: WoodsQuadChamber = root.get_active()
	wood.set_physics_process(false)
	wood.debug_invulnerable = true
	wood._sync_visuals()
	await snap("02_woods_first_frame")
	await get_tree().process_frame
	await snap("03_woods_next_frame")
	# Whole action sampled at 10 fps with 60 Hz deterministic simulation.
	wood._player_pos = WoodsQuadChamber.QUAD_POS + Vector3(3.0, 0.0, -5.0)
	wood._bull.position = WoodsQuadChamber.QUAD_POS + Vector3(3.0, 0.0, -1.2)
	wood._hold = 0.0
	wood._advance_to(WoodsQuadChamber.Beat.REVEAL)
	var frame := 0
	while wood.get_beat_name() != "RIDE" and frame < 300:
		for i in 10:
			wood.step(1.0 / 60.0)
		if frame % 4 == 0 or wood.get_beat_name() == "RIDE":
			await snap("quad_%03d" % frame)
		frame += 1
	print("TRANSITION_SHOT complete: ", wood.get_beat_name(), " frames=", frame)
	get_tree().quit()
