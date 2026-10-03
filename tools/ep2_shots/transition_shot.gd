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
	# The cover is the REAL last frame of the boss 3 film (seamless mode), exactly as the bosses do it.
	var cover := Control.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://.farm/ep2intro/last.png"))
	if img != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cover.add_child(tr)
	GameManager.ep2_story_unlocked = true
	td.go("res://src/episode2/ep2_entry.tscn", "", "", cover)
	var shots := [0.2, 1.0, 2.0, 3.0]
	var min_lum := 1.0
	var black_frames := 0
	var i := 0
	var worst2 := 0.0
	last = Time.get_ticks_usec()
	while not (td.state == td.S.IDLE and not td._going):
		await get_tree().process_frame
		var n2: int = Time.get_ticks_usec()
		worst2 = maxf(worst2, float(n2 - last) / 1000.0)
		last = n2
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		var lum: float = _mean_lum()
		min_lum = minf(min_lum, lum)
		if lum < 0.04:
			black_frames += 1
		if i < shots.size() and el >= shots[i]:
			get_viewport().get_texture().get_image().save_png("%s/t%d_%s_%.2fs.png" % [out, i, td.S.keys()[td.state], el])
			i += 1
	print("HANDOFF go->finished ms=", Time.get_ticks_msec() - t0, " worst_frame_ms=%.0f" % worst2, " min_screen_luminance=%.3f black_frames=%d" % [min_lum, black_frames])
	for k in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/after.png" % out)
	print("SCENE ", get_tree().current_scene.name if get_tree().current_scene else "none")
	get_tree().quit()


## Mean luminance (0..1) of the current frame, sampled on a coarse grid.
func _mean_lum() -> float:
	var im: Image = get_viewport().get_texture().get_image()
	if im == null or im.is_empty():
		return 1.0
	var w: int = im.get_width()
	var h: int = im.get_height()
	var acc: float = 0.0
	var n: int = 0
	for yy in range(4, h, maxi(h / 8, 1)):
		for xx in range(4, w, maxi(w / 8, 1)):
			var c: Color = im.get_pixel(xx, yy)
			acc += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			n += 1
	return acc / float(maxi(n, 1))
