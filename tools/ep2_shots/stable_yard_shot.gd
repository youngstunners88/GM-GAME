extends Node
## Actual first-person chamber camera, plus full source-clip phase evidence for both founder rigs.
var c: GoldTownChamber
var vp: SubViewport
var out := ".farm/stable-yard"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	c = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	vp.add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	var yard: Ep2StableYard = c._stable_yard
	_look(Vector3(-1, 0, 1222), Vector3(-13, 1.3, 1222))
	await _shot("yard_from_gate")
	for index in yard.actors.size():
		var f: Ep2TownFolk = yard.actors[index]
		for key in Ep2StableYard.CLIPS:
			f.play_clip(key)
			f.anim_player().advance(0.25)
			var animation: Animation = f.anim_player().get_animation(f.anim_player().current_animation)
			for phase in [0.15, 0.5, 0.85]:
				f.anim_player().seek(animation.length * phase, true)
				_look(f.position + Vector3(4.1, 0, 0.6), f.position + Vector3(0, 1.25 if key == "jump" else 0.95, 0))
				await _shot("%s_%s_%02d" % [f.name, key, int(phase * 100)])
		f.hold_clip("idle")
		f.anim_player().advance(0.25)
	for i in 1800: yard.step(1.0 / 60.0, Vector3(0, 0, 1222))
	_look(Vector3(-3.8, 0, 1237.5), Vector3(-11, 1.0, 1224))
	await _shot("yard_after_thirty_seconds")
	print("STABLE_YARD_SHOT: TWO RIGS FIVE CLIPS AND HERD CAPTURED")
	get_tree().quit()

func _look(ground: Vector3, focus: Vector3) -> void:
	c._player_pos = ground
	var d: Vector3 = focus - (ground + Vector3(0, c.eye_height, 0))
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	c._update_camera(0)
	c._sync_visuals()

func _shot(label: String) -> void:
	for i in 4: await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), 0.9)
