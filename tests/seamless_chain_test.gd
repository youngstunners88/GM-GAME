extends Node
## SEAMLESS CHAIN (founder 2026-10-25, PROMPT_EPISODE2_CAD_TRANSITIONS_DRAW_REWRITE): the REAL chain the founder plays -
## hideout -> open door -> the lift that was built behind it -> the woods built behind the lift - with no pause, no pre-visible
## Lil Blunt and no rewind. The older gates enter the lift WITHOUT a prebuild, which hid the bug where activating the prebuilt lift
## freed the woods being built behind it (the woods were then built at the lift's exit and started from their own entrance).
##  1.1 the hideout door: no wall in front of the open door while Inferno finishes "made it" - he says it leading on.
##  1.2 the elevator: the lift seen through the doorway has an EMPTY cage (no second Lil Blunt holding nothing).
##  1.3 elevator -> woods: the woods are still being built behind the lift after the cut, the cage tops out as the last line starts
##      (no dead wait at the top), and walking out lands in THAT woods at the mapped spot with no replayed intro.
## Run: godot --headless res://tests/seamless_chain_test.tscn

var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail if not ok else ""])
	if not ok:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	var root: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(root)
	root.set_process(false)                    # the test is the frame clock: prebuild and portal are driven below
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
	check("the hideout's lesson built the lift behind it", pl != null and root.is_prebuilt("mine_lift"))
	if pl == null:
		_done()
		return
	pl.set_physics_process(false)
	check("1.2 the built lift holds NO Lil Blunt (he is still in the hideout)", pl._player_node != null and not pl._player_node.visible)

	# ---- 1.1 the EXIT beat for real: Inferno to the bank, "lava1", the hop, "lava2", wait for the crossing, "made it"
	print("-- 1.1 hideout door")
	var said: Array = []
	hf.line_spoken.connect(func(id): said.append(id))
	hf._enter_fps()
	hf._player_pos = Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z - 2.5)
	hf._look_yaw = 0.0
	hf._look_pitch = 0.0
	hf._beat = SmeltingFacilityChamber.Beat.EXIT
	hf._on_beat_entered(SmeltingFacilityChamber.Beat.EXIT)
	for i in 60 * 40:                          # until Inferno has hopped and is on the far bank
		if hf._bull.position.z > SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF and not hf._bull.is_hopping():
			break
		hf.step(1.0 / 60.0)
		root._drive_portal()
	check("Inferno is across the lava", hf._bull.position.z > SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF)
	check("...the door is NOT open while Lil Blunt is still on the near bank", not hf._exit_open())
	for i in 60 * 12:                          # "hop over" (lava2) said; the show now waits for him to cross
		if said.has("vo_bull_lava2") and hf._hold <= 0.0:
			break
		hf.step(1.0 / 60.0)
		root._drive_portal()
	hf._player_pos = Vector3(0.0, 0.0, SmeltingFacilityChamber.CHANNEL_Z + SmeltingFacilityChamber.LAVA_HALF + 0.6)
	for i in 30:
		hf.step(1.0 / 60.0)
		root._drive_portal()
		if hf._exit_line_end > 0.0:
			break
	check("across the lava, Inferno says \"made it\"", hf._exit_line_end > hf._elapsed)
	check("...and the door opens AT ONCE, while the line is still playing (no wall in front of the open door)", hf._exit_open() and hf._exit_line_end - hf._elapsed > 3.0,
		"left %.2f s" % (hf._exit_line_end - hf._elapsed))
	hf.step(1.0 / 60.0)                        # the show's last step (the "made it" call) closes on the next frame
	hf.step(1.0 / 60.0)
	check("...Inferno is not held standing for his own line: he is already walking to the door", hf._hold <= 0.0 and not hf._show_active and hf._bull.is_walking())
	pl.line_spoken.connect(func(id): said.append("lift:" + str(id)))
	var cut: Dictionary = {"t": -1.0, "voice_left": -1.0}
	hf.set_move_input(Vector2(0.0, 1.0))
	var walk_t: float = 0.0
	var from_z: float = hf._player_pos.z
	for i in 60 * 6:
		if root.get_active() != hf:
			break
		cut["voice_left"] = hf.get_handoff().get("voice_left", -1.0)
		hf.step(1.0 / 60.0)
		root._drive_portal()
		walk_t += 1.0 / 60.0
	var walk_min: float = (SmeltingFacilityChamber.PORTAL_Z - from_z) / SmeltingFacilityChamber.WALK_SPEED
	check("he walks straight through the open doorway: the cut comes when he reaches it, not when the line ends",
		root.get_active() == pl and walk_t < walk_min + 0.6, "walked %.2f s (straight walk %.2f s)" % [walk_t, walk_min])
	check("...the lift that took over is the SAME room the doorway showed", root.get_active() == pl and pl.handoff_seamless)
	check("...and \"made it\" was still playing at the cut (nobody waited for it)", float(cut["voice_left"]) > 1.0, str(cut["voice_left"]))

	# ---- 1.3 the woods are built behind the lift AFTER the seamless cut (the regression)
	print("-- 1.3 woods built behind the lift")
	check("entering the prebuilt lift starts building the WOODS behind it", root._pb_node is WoodsQuadChamber and root._pb_id == "woods_quad")
	await get_tree().process_frame
	await get_tree().process_frame
	check("...and that build SURVIVES the cut (its off-screen viewport is not freed with the lift's)",
		root._pb_node != null and is_instance_valid(root._pb_node) and root._pb_vp != null and is_instance_valid(root._pb_vp)
		and root._pb_node.get_parent() == root._pb_vp and root._pb_vp.is_inside_tree())
	var woods: WoodsQuadChamber = root._pb_node as WoodsQuadChamber if is_instance_valid(root._pb_node) else null
	check("...so the lift WAITS for the woods instead of building them at the exit", not pl._handoff_ok())
	hf = null

	# ---- 1.2 in the lift: no body, Inferno's next line waits for "made it" to end
	print("-- 1.2 lift")
	pl.step(1.0 / 60.0)
	check("in the lift: first person, his body still hidden", not pl._player_node.visible)
	check("Inferno's lift line waits for \"made it\" to finish (no two lines at once)", not said.has("lift:vo_bull_lift1") and pl._queued_line == "vo_bull_lift1")
	for i in int((float(cut["voice_left"]) + 0.3) * 60.0):
		pl.step(1.0 / 60.0)
	check("...then he says it", said.has("lift:vo_bull_lift1"))

	# ---- 1.3 the ride: the cage tops out as Lil Blunt's reply starts; the gate opens on it
	print("-- 1.3 ride")
	var w_said: Array = []
	if woods != null:
		woods.line_spoken.connect(func(id): w_said.append(id))
	var ride: Dictionary = {"top": -1.0, "surface": -1.0, "reply": -1.0}
	var t: float = 0.0
	for i in 60 * 60:
		if pl.get_beat_name() in ["ARRIVE", "BOARD"] and not pl.is_show_active():
			pl._player_pos = Vector3(0.0, pl.get_cage_y(), 0.0)          # he steps onto the cage
		pl.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if float(ride["top"]) < 0.0 and pl.get_cage_y() >= MineLiftChamber.TOP_Y - 0.001:
			ride["top"] = t
		if float(ride["reply"]) < 0.0 and said.has("lift:vo_lb_plan_reply"):
			ride["reply"] = t
		if pl.get_beat_name() == "SURFACE":
			ride["surface"] = t
			break
	check("the cage reaches the surface", float(ride["surface"]) > 0.0, str(ride))
	check("...no dead wait at the top: the gate starts to open the moment the cage arrives", float(ride["surface"]) - float(ride["top"]) < 0.3, str(ride))
	check("...as Lil Blunt answers Inferno's plan (every plan line said, in order, none cut)",
		float(ride["reply"]) > 0.0 and absf(float(ride["surface"]) - float(ride["reply"])) < 0.5
		and said.find("lift:vo_bull_plan1") < said.find("lift:vo_bull_plan2") and said.find("lift:vo_bull_plan2") < said.find("lift:vo_bull_plan3")
		and said.find("lift:vo_bull_plan3") < said.find("lift:vo_lb_plan_reply"), str(ride) + " " + str(said))

	# ---- 1.3 walk out: the SAME woods, at the mapped spot, no intro again
	print("-- 1.3 walk out")
	root._drive_prebuild(1.0e9)
	check("the woods finished building behind the lift", woods != null and root.is_prebuilt("woods_quad"))
	pl._look_yaw = 0.0
	pl._look_pitch = -0.04
	pl.set_move_input(Vector2(0.0, 1.0))
	var mapped: Vector3 = Vector3.ZERO
	for i in 60 * 12:
		if root.get_active() != pl:
			break
		mapped = pl._player_pos - MineLiftChamber.SURFACE_OFFSET
		pl.step(1.0 / 60.0)
	var wood: WoodsQuadChamber = root.get_active() as WoodsQuadChamber
	check("walking out of the cage enters THE woods that were built behind it (one cut, no rebuild)", wood != null and wood == woods and wood.handoff_seamless)
	if wood != null:
		wood.set_physics_process(false)
		check("...where he stood, not back at the woods' own entrance (no rewind)", wood._player_pos.distance_to(mapped) < 0.2 and wood._player_pos.z > WoodsQuadChamber.SPAWN.z + 1.0,
			"%s vs mapped %s" % [wood._player_pos, mapped])
		check("...and Inferno's woods introduction is not replayed", not w_said.has("vo_bull_woods_sneak"), str(w_said))
	_done()


func _done() -> void:
	print("SEAMLESS_CHAIN: %s" % ["ALL PASS" if failures == 0 else "%d FAILURE(S)" % failures])
	get_tree().quit(failures)
