extends Node
## Measures the REAL cost of each stage of entering Episode 2 (skill ep2-seamless-transition / jev simulation):
## warm load, instantiate(), add_child (_ready), frames until the runner exists, and the worst frame after.
## Output is JSON-ish lines for tools/ep2_sim/simulate.mjs. Software GL, so ABSOLUTE numbers are pessimistic; the
## RATIOS between strategies are what the simulation uses.
func _ready() -> void:
	var root: Node = get_tree().root
	reparent.call_deferred(root)
	await get_tree().process_frame
	GameManager.ep2_story_unlocked = true
	var td: Node = root.get_node("TransitionDirector")
	var path := "res://src/episode2/ep2_entry.tscn"
	var draw_warm := true
	for a in OS.get_cmdline_user_args():
		if a == "drawwarm=0":
			draw_warm = false
	var t0 := Time.get_ticks_usec()
	td.prewarm(path)
	td.set_process(true)
	td.set_process(true)
	var guard := 0
	while (not td._queue.is_empty() or not td._late.is_empty()) and guard < 5000:
		# film phase first (light items), then the covered phase (scripts/scenes) - exactly what go() does
		td.state = td.S.COVERING if td._queue.is_empty() else td.S.WARMING
		td._pump_warm(1.0e9)
		guard += 1
		await get_tree().process_frame
	td.state = td.S.READY
	print("PROBE warm_total_ms=%.0f" % (float(Time.get_ticks_usec() - t0) / 1000.0))
	print("PROBE render_queue_at_start=", td._render_queue.size())
	if draw_warm:
		# the real flow has the 15 s film: let the one-model-at-a-time GPU warm-up run to completion
		var wf := 0
		while not td._render_queue.is_empty() and wf < 1200:
			td._render_cooldown = 0.0 if wf % 18 == 0 else td._render_cooldown
			await get_tree().process_frame
			wf += 1
		await get_tree().create_timer(0.5).timeout
		print("PROBE drawn_models=", td.rendered_count, " processing=", td.is_processing(), " state=", td.state, " q=", td._render_queue.size(), " wf=", wf)
	else:
		td._render_queue.clear()
	var ps: PackedScene = load(path)
	var t1 := Time.get_ticks_usec()
	var inst: Node = ps.instantiate()
	print("PROBE instantiate_ms=%.0f" % (float(Time.get_ticks_usec() - t1) / 1000.0))
	var t2 := Time.get_ticks_usec()
	root.add_child(inst)
	print("PROBE add_child_ready_ms=%.0f" % (float(Time.get_ticks_usec() - t2) / 1000.0))
	var worst := 0.0
	var last := Time.get_ticks_usec()
	var frames := 0
	var runner_frame := -1
	while frames < 90:
		await get_tree().process_frame
		var n := Time.get_ticks_usec()
		worst = maxf(worst, float(n - last) / 1000.0)
		last = n
		frames += 1
		if runner_frame < 0 and inst.get("_root") != null:
			runner_frame = frames
	print("PROBE worst_frame_after_ms=%.0f runner_exists_at_frame=%d" % [worst, runner_frame])
	get_tree().quit()
