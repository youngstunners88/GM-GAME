extends Node
## Founder 2026-11-01: "the transition of the music when going to mount the horse ... is not smooth and there is a glitch".
## Times the town -> lake trail hand-over frame piece by piece (prebuilt trail, as in play): park, activate, adopt.
## godot --path . --rendering-driver opengl3 tools/ep2_perf/mount_handoff_probe.tscn


func _ms(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0


func _ready() -> void:
	var session: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var town: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	session.add_child(town)
	session._active = town
	session._wire_chamber(town)
	town.setup()
	town.set_physics_process(false)
	for i in 30:
		await get_tree().process_frame
	# the trail is built behind the town exactly as in play (its own hidden viewport, a few ms per frame)
	session._on_prebuild_requested("lake_trail")
	var frames: int = 0
	while session._pb_node != null and not bool(session._pb_node.call("is_prebuilt")) and frames < 2000:
		session._drive_prebuild(40.0)
		await get_tree().process_frame
		frames += 1
	for i in 20:
		await get_tree().process_frame
	var sounds: int = 0
	for s in town.find_children("*", "AudioStreamPlayer3D", true, false):
		if (s as AudioStreamPlayer3D).playing:
			sounds += 1
	print("PROBE prebuilt in %d frames; town 3D sounds playing before the swap: %d" % [frames, sounds])
	for s in town.find_children("*", "AudioStreamPlayer3D", true, false):
		if (s as AudioStreamPlayer3D).playing:
			print("PROBE   sound ", town.get_path_to(s), " ", (s as AudioStreamPlayer3D).stream.resource_path.get_file() if (s as AudioStreamPlayer3D).stream else "")
	session._chain_id = "lake_trail"
	var t0: int = Time.get_ticks_usec()
	session._enter_chamber_chained(session._segment)
	print("PROBE swap call %.1f ms" % _ms(t0))
	var trail: Node = session._active
	var still: int = 0
	for s in trail.find_children("*", "AudioStreamPlayer3D", true, false):
		if (s as AudioStreamPlayer3D).playing:
			still += 1
	print("PROBE town 3D sounds still playing after: %d" % still)
	for i in 6:
		t0 = Time.get_ticks_usec()
		await get_tree().process_frame
		print("PROBE frame %d after the swap %.1f ms (process %.1f ms, physics %.1f ms)" % [i + 1, _ms(t0), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	get_tree().quit()
