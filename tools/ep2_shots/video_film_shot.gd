extends Node
## Real-render proof of the Seedance transition film (skill ep2-seedance-film): the facility is set up exactly as
## the session root does, the film plays in REAL time, and the viewport is saved at chosen real seconds, then the
## film is skipped and the target-practice view is saved.
##   xvfb-run ... res://tools/ep2_shots/video_film_shot.tscn -- out=<dir> at=0.3,3,12,22

func _ready() -> void:
	var out := ".farm/film/real"
	var marks := PackedFloat32Array([0.3, 3.0, 12.0, 22.0])
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		elif kv.size() == 2 and kv[0] == "at":
			marks = PackedFloat32Array()
			for m in kv[1].split(",", false):
				marks.append(float(m))
	DirAccess.make_dir_recursive_absolute(out)
	var f: SmeltingFacilityChamber = (load("res://src/episode2/chamber/smelting_facility.tscn") as PackedScene).instantiate()
	add_child(f)
	var t0: int = Time.get_ticks_msec()
	f.setup(0, [], 0)
	print("SETUP_RETURNED_MS ", Time.get_ticks_msec() - t0, " video=", f.get_video_film() != null)
	var i: int = 0
	while i < marks.size() and f.get_beat() == f.Beat.CINEMATIC:
		await get_tree().process_frame
		var real: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if real >= marks[i]:
			var path := "%s/v%02d_%05.2fs.png" % [out, i, real]
			get_viewport().get_texture().get_image().save_png(path)
			print("SHOT ", path, " room_built=", f._room_built, " film_t=", f.get_video_film().elapsed() if f.get_video_film() else -1.0)
			i += 1
	if f.get_video_film():
		f.get_video_film().skip()
	for _k in 12:
		await get_tree().process_frame
	var p2 := "%s/after_skip.png" % out
	get_viewport().get_texture().get_image().save_png(p2)
	print("SHOT ", p2, " beat=", f.get_beat_name(), " fps=", f.is_fps())
	get_tree().quit()
