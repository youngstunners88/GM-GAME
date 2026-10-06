extends Node
## Close views of Inferno Bull's head/hat from where the player stands (see-through check, skill ep2-bull-solid).
##   ... bull_close_shot.tscn -- out=.farm/bull [cull=0|1] [dist=2.6]
const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
func _ready() -> void:
	var out := ".farm/bull"; var dist := 2.6; var old_cull := false
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out": out = kv[1]
		if kv.size() == 2 and kv[0] == "dist": dist = float(kv[1])
		if kv.size() == 2 and kv[0] == "old": old_cull = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(out)
	var f: SmeltingFacilityChamber = SMELT.instantiate()
	f.intro_film = false
	add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	await get_tree().process_frame
	f._on_video_film_finished()
	f.debug_skip_lesson()
	if old_cull:       # BEFORE picture: put back-face culling back on every Bull surface
		for mi in f.get_bull().find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			for i in mm.mesh.get_surface_count():
				var om: Material = mm.get_surface_override_material(i)
				if om is BaseMaterial3D and not String(mm.get_path()).contains("whiskey"):
					(om as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
	var bp: Vector3 = f.get_bull().global_position
	f._player_pos = Vector3(bp.x + 0.2, 0.0, bp.z + dist)
	f._look_yaw = PI
	f._look_pitch = 0.12
	for i in 40: f.step(1.0 / 60.0)
	for i in 4: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/bull_front.png")
	f._player_pos = Vector3(bp.x + 1.6, 0.0, bp.z + dist * 0.7)
	f._look_yaw = PI + 0.5
	for i in 40: f.step(1.0 / 60.0)
	for i in 4: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/bull_side.png")
	# from BEHIND (he turns to the targets in the demo): the back of the head / hat
	f.get_bull().facing = 0.0          # turned away, like the demo (he faces the targets): we see his back and the inside of the head
	f.get_bull().face_yaw(0.0)
	f.get_bull().rotation.y = 0.0
	for i in 120: f.step(1.0 / 60.0)
	f._player_pos = Vector3(bp.x + 0.3, 0.0, bp.z + dist * 0.8)
	f._look_yaw = PI
	f._look_pitch = 0.2
	for i in 40: f.step(1.0 / 60.0)
	for i in 4: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out + "/bull_back.png")
	# materials audit: numbers for Jev
	var n_alpha := 0; var n_cull := 0; var n_surf := 0
	for mi in f.get_bull().find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			n_surf += 1
			var mat: Material = m.get_surface_override_material(i)
			if mat == null: mat = m.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				if (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					n_alpha += 1
					print("BULLALPHA path=", f.get_bull().get_path_to(m), " mesh=", m.name, " surf=", i, " mode=", (mat as BaseMaterial3D).transparency, " alpha_scissor=", (mat as BaseMaterial3D).alpha_scissor_threshold, " tex=", (mat as BaseMaterial3D).albedo_texture)
				if (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_BACK: n_cull += 1
	print("BULLMAT surfaces=%d alpha=%d cull_back=%d" % [n_surf, n_alpha, n_cull])
	get_tree().quit()
