extends Node
## Real-render proof of the boss 3 -> Episode 2 hand-off (skill ep2-seamless-transition): pre-warm for a few seconds
## (stand-in for the death tween + film), then go(); saves the screen at the card, mid-load and after the reveal, and
## prints the time from go() to finished and the worst frame.
##   xvfb-run ... res://tools/ep2_shots/transition_shot.tscn -- out=<dir> warm=4

func _ready() -> void:
	var out := ".farm/film/transition"
	var warm := 4.0
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		elif kv.size() == 2 and kv[0] == "warm":
			warm = float(kv[1])
	DirAccess.make_dir_recursive_absolute(out)
	var root: Node = get_tree().root
	reparent.call_deferred(root)
	await get_tree().process_frame
	var dummy := ColorRect.new()
	dummy.color = Color(0.25, 0.4, 0.8)      # a BLUE stand-in for "the level" so a blue flash would show
	dummy.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.add_child(dummy)
	root.add_child(cl)
	get_tree().current_scene = cl
	var td: Node = root.get_node("TransitionDirector")
	td.prewarm("res://src/episode2/ep2_entry.tscn")
	var t_end: int = Time.get_ticks_msec() + int(warm * 1000.0)
	var worst := 0.0
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		var n: int = Time.get_ticks_usec()
		worst = maxf(worst, float(n - last) / 1000.0)
		last = n
	print("WARM_PHASE state=", td.state, " frac=%.2f worst_frame_ms=%.0f" % [td.warm_fraction(), worst])
	var t0: int = Time.get_ticks_msec()
	td.go("res://src/episode2/ep2_entry.tscn")
	var shots := [0.15, 0.7, 1.6]
	var i := 0
	var worst2 := 0.0
	last = Time.get_ticks_usec()
	while not (td.state == td.S.IDLE and not td._going):
		await get_tree().process_frame
		var n2: int = Time.get_ticks_usec()
		worst2 = maxf(worst2, float(n2 - last) / 1000.0)
		last = n2
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if i < shots.size() and el >= shots[i]:
			get_viewport().get_texture().get_image().save_png("%s/t%d_%s_%.2fs.png" % [out, i, td.S.keys()[td.state], el])
			i += 1
	print("HANDOFF go->finished ms=", Time.get_ticks_msec() - t0, " worst_frame_ms=%.0f" % worst2)
	for k in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/after.png" % out)
	print("SCENE ", get_tree().current_scene.name if get_tree().current_scene else "none")
	get_tree().quit()
