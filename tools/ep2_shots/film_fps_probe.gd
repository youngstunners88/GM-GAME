extends Node
## How well does the founder's film play while the hideout is built/rendered behind it? Real-render (software GL = a weak-GPU
## stand-in). Reports the picture's progress against the wall clock and the worst gap between decoded frames.
##   ... film_fps_probe.tscn -- force3d=1   (3D pass ON behind the film, the old behaviour)   |  (default: OFF, the fix)
const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
func _ready() -> void:
	var force3d := false
	for a in OS.get_cmdline_user_args():
		if a == "force3d=1": force3d = true
	var f: SmeltingFacilityChamber = SMELT.instantiate()
	f.intro_film = true
	add_child(f)
	f.setup(0, [], 0)
	if force3d:
		get_viewport().disable_3d = false
	var vf = f.get_video_film()
	var t0 := Time.get_ticks_msec()
	var last_pos := 0.0
	var last_change := t0
	var worst_gap := 0
	var frames := 0
	var changes := 0
	while Time.get_ticks_msec() - t0 < 16000:
		await get_tree().process_frame
		frames += 1
		var pos: float = vf._video.stream_position
		if pos != last_pos:
			changes += 1
			worst_gap = maxi(worst_gap, Time.get_ticks_msec() - last_change)
			last_change = Time.get_ticks_msec()
			last_pos = pos
	var real: float = float(Time.get_ticks_msec() - t0) / 1000.0
	print("FILMFPS force3d=%s real=%.1fs picture=%.1fs ratio=%.2f render_fps=%.1f picture_updates=%d worst_gap_ms=%d room_ready=%s" % [str(force3d), real, last_pos, last_pos / real, float(frames) / real, changes, worst_gap, str(f._room_ready)])
	get_tree().quit()
