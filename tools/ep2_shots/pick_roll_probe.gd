extends "res://tools/ep2_shots/pick_grip_shot.gd"
## One frame per grip roll (radians about the handle) so the thumb-over-handle roll can be picked by eye.
func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 540)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	_c = TOWN.instantiate()
	_vp.add_child(_c)
	_c.setup(0, [], 0)
	await get_tree().process_frame
	_c.set_process(false)
	_c.set_physics_process(false)
	_c.skip_armory_intro()
	_c._player_pos = Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(4.0, 0.0, 9.0))
	_c._look_yaw = PI
	_c.select_weapon(Ep2ArmoryState.PICK)
	_step(0.5)
	var vm = _c.get_viewmodel()
	for deg in [0.0, 180.0, 202.5, 225.0, 247.5, 270.0]:
		vm.pick_grip_roll = deg_to_rad(deg)
		var view: Node3D = vm._weapon_views[Ep2ArmoryState.PICK]
		view.remove_meta("held")
		vm._ensure_held_pick()
		_step(0.3)
		await _grab("roll_%d" % int(deg * 10))
	get_tree().quit()
