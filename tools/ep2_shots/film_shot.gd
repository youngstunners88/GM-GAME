extends Node
## Frame grabs of the cliff-jump film (skill ep2-cinematic-cutscene / see-it-yourself). Plays the REAL film on
## the Compatibility renderer at a fixed 60 Hz step and saves the viewport at chosen REAL seconds.
##   xvfb-run ... res://tools/ep2_shots/film_shot.tscn -- out=<dir> at=0.5,1.5,3,...
## Prints the timeline and the real second each story event fired.

func _ready() -> void:
	var out := ".farm/film"
	var marks := PackedFloat32Array([0.5, 1.5, 2.3, 3.2, 4.5, 6.0, 7.0, 8.0, 9.0, 10.5])
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
		elif kv.size() == 2 and kv[0] == "at":
			marks = PackedFloat32Array()
			for m in kv[1].split(",", false):
				marks.append(float(m))
	DirAccess.make_dir_recursive_absolute(out)
	var script: GDScript = load("res://src/episode2/cinematic/cliff_jump_cinematic.gd")
	if script == null or not script.can_instantiate():
		push_error("FILM SCRIPT DOES NOT LOAD (parse error) - fix it before capturing")
		get_tree().quit(2)
		return
	var film := CliffJumpCinematic.new()
	add_child(film)
	film.event.connect(func(n: String) -> void: print("EVENT %s real=%.2f act=%.2f" % [n, film.get_real_time(), film.get_action_time()]))
	await get_tree().process_frame
	print("TIMELINE launch=%.2f crash=%.2f land=%.2f rest=%.2f land_z=%.1f rock_z=%.1f" % [film.a_launch, film.a_crash, film.a_land, film.a_rest, film.land_z, film.rock_z])
	film.start()
	var i: int = 0
	var t: float = 0.0
	while i < marks.size() and not film.is_finished():
		film.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if t >= marks[i]:
			await get_tree().process_frame
			await get_tree().process_frame
			var path := "%s/f%02d_%05.2fs_%s.png" % [out, i, t, film.get_shot()]
			get_viewport().get_texture().get_image().save_png(path)
			print("SHOT ", path, " hero=", film.hero_position(), " cart=", film.cart_position())
			i += 1
		elif int(t * 60.0) % 3 == 0:
			await get_tree().process_frame
	while not film.is_finished():
		film.step(1.0 / 60.0)
		t += 1.0 / 60.0
	print("FINISHED real=%.2f" % t)
	get_tree().quit()
