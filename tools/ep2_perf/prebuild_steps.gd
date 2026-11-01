extends Node
## PREBUILD FRAME BUDGET PROBE (skill ep2-prebuild-frame-budget). Per-step CPU cost of a chamber's background prebuild (one step runs per frame at minimum, so a long step = a frame hitch).
func _ready() -> void:
	await get_tree().process_frame
	# GM_PREBUILD_IDS="gold_town,mine_lift" picks the rooms (each built twice when GM_PREBUILD_WARM=1: the second row is the warm cost)
	var ids: Array = Array(OS.get_environment("GM_PREBUILD_IDS").split(",", false))
	if ids.is_empty():
		ids = ["mine_lift", "woods_quad", "gold_town", "lake_trail", "logans_lake"]
	if OS.get_environment("GM_PREBUILD_WARM") == "1":
		var twice: Array = []
		for id in ids:
			twice.append_array([id, id])
		ids = twice
	for id in ids:
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = Vector2i(320, 180)
		add_child(vp)
		var n: Node = Ep2SessionRoot.CHAMBER_SCENES[id].instantiate()
		if n.has_method("bind_armory"): n.bind_armory(Ep2ArmoryState.post_hideout())
		var t0 := Time.get_ticks_usec()
		vp.add_child(n)
		var add_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		n.call("prebuild_begin")
		var steps: Array = n._pb_steps
		var times: Array = []
		var i := 0
		while n._pb_i < steps.size():
			var s := Time.get_ticks_usec()
			(steps[n._pb_i] as Callable).call()
			n._pb_i += 1
			times.append([(Time.get_ticks_usec() - s) / 1000.0, i, str((steps[i] as Callable).get_method())])
			i += 1
		times.sort_custom(func(a, b): return a[0] > b[0])
		var total := 0.0
		for t in times: total += t[0]
		print("PREBUILD ", id, " add_child=%.1fms steps=%d total=%.0fms top:" % [add_ms, times.size(), total])
		for k in mini(8, times.size()):
			print("   %.1f ms  step %d %s" % times[k])
		vp.queue_free()
		await get_tree().process_frame
	get_tree().quit()
