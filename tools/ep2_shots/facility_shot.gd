extends Node
## Frame grabs of the Smelting Facility at chosen beats (skill see-it-yourself). No film: it jumps straight
## to each beat, steps a moment so the camera settles, and saves the viewport.
##   xvfb-run ... res://tools/ep2_shots/facility_shot.tscn -- out=<dir>

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")

func _ready() -> void:
	var out := ".farm/facility"
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			out = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	var f = SMELT.instantiate()
	f.intro_film = false
	add_child(f)
	f.setup(0, [], 0)
	await get_tree().process_frame
	for spec in [["wake", f.Beat.WAKE, false, false], ["drink", f.Beat.DRINK, false, false],
			["helmet", f.Beat.HELMET, true, true], ["teach", f.Beat.VERB_TEACH, true, true], ["wide", f.Beat.EXIT, true, true]]:
		f._beat = int(spec[1])
		f._has_winchester = bool(spec[2])
		f._has_helmet = bool(spec[3])
		if spec[0] == "wake":
			f._on_beat_entered(f.Beat.WAKE)
		else:
			f._player_pos = Vector3(0.4, 0.0, 3.4)
		if spec[0] == "wide":
			f._camera.position = Vector3(0.0, 4.2, -11.0)
		for _i in 150:
			f.step(1.0 / 60.0)
			f._hold = 99.0
			await get_tree().process_frame
		var path := "%s/%s.png" % [out, spec[0]]
		get_viewport().get_texture().get_image().save_png(path)
		print("SHOT ", path)
		if spec[0] == "helmet":
			# Close on his head: is the helmet ON it?
			# Its own camera: the facility re-seats its camera every step.
			var head: Vector3 = f._player_node.global_position + Vector3(0.0, 1.6, 0.0)
			var eye := Camera3D.new()
			add_child(eye)
			eye.global_position = head + Vector3(1.2, 0.35, 1.5)
			eye.look_at(head, Vector3.UP)
			eye.make_current()
			for _j in 3:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/helmet_close.png" % out)
			eye.global_position = head + Vector3(-0.3, 0.6, -1.6)
			eye.look_at(head, Vector3.UP)
			for _j in 3:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/helmet_back.png" % out)
			f._camera.make_current()
			eye.queue_free()
			print("SHOT helmet_close")
	get_tree().quit()
