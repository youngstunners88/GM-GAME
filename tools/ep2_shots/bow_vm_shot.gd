extends Node
## The founder's bow in Lil Blunt's hands, real Compatibility renderer, from his own eye: hip, drawing (1/3, 2/3, full), the loose, the shiver, the re-nock, and the
## selector card (skill ep2-founder-bow). Runs in the Armory yard chamber (same code as the game); the simulation is stepped in bulk, then a frame is grabbed.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/bow_vm_shot.tscn -- out=docs/episode2-quality/founder-bow-2026-10-21
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/bow_vm"
var _c: GoldTownChamber = null
var _vp: SubViewport = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	# a real 16:9 frame regardless of the window the compositor hands out: the chamber lives in a 1600x900 SubViewport
	_vp = SubViewport.new()
	_vp.size = Vector2i(1600, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	_c = TOWN.instantiate()
	_vp.add_child(_c)
	_c.setup(0, [], 0)
	await get_tree().process_frame
	_c.set_process(false)
	_c.set_physics_process(false)
	_c.skip_armory_intro()
	var st: Ep2ArmoryState = _c.armory
	st.acquire(Ep2ArmoryState.BOW)
	st.arrows = 12
	(st.firearm(Ep2ArmoryState.BOW) as Ep2Bow).rounds = 12
	_c._player_pos = Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(4.0, 0.0, 9.0))
	_c._look_yaw = PI
	_c._look_pitch = -0.04
	_c.select_weapon(Ep2ArmoryState.BOW)
	_step(0.1)
	# placement probes: hip_rot=x,y,z (added to PI on y)  hip_off=x,y,z  ads=x,y,z  scale=k
	var view: Node3D = _c.get_viewmodel().rifle
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() != 2:
			continue
		var v: PackedFloat64Array = kv[1].split_floats(",")
		match kv[0]:
			"hip_rot": view.set_meta("hip_rotation", Vector3(v[0], PI + v[1], v[2]))
			"hip_off": view.set_meta("hip_offset", Vector3(v[0], v[1], v[2]))
			"ads": view.set_meta("ads_cam", Vector3(v[0], v[1], v[2]))
			"ads_pos": view.set_meta("ads_pos", Vector3(v[0], v[1], v[2]))
			"ads_rot": view.set_meta("ads_rotation", Vector3(v[0], PI + v[1], v[2]))
			"scale": view.scale = Vector3.ONE * Ep2Viewmodel.VM_SCALE * v[0]
	_step(0.5)
	await _grab("1_hip")
	var bow: Ep2Bow = st.active_gun() as Ep2Bow
	_c.shoot()
	_step(0.23)
	await _grab("2_draw_third")
	_step(0.23)
	await _grab("3_draw_twothird")
	_step(0.2)
	await _grab("4_full")
	_step(0.07)
	await _grab("5_loose")
	_step(0.06)
	await _grab("6_shiver")
	_step(0.14)
	await _grab("7_snap_settle")
	_step(0.18)
	await _grab("8_renock")
	_step(0.4)
	await _grab("9_ready_again")
	_c.set_aim(true)
	_step(0.6)
	await _grab("10_ads")
	for mi in _c.get_viewmodel().rifle.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat: Material = m.get_surface_override_material(i)
			if mat == null:
				mat = m.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				var b := mat as BaseMaterial3D
				print("BOW_MAT ", m.name, " s", i, " ", b.resource_name, " albedo=", b.albedo_color, " tex=", b.albedo_texture != null, " metal=", b.metallic, " rough=", b.roughness, " emis=", b.emission_enabled)
	print("BOW_VM_SHOT done ", _out, " founder=", _c.get_viewmodel().rifle.has_meta("fb"))
	get_tree().quit()


func _step(seconds: float) -> void:
	for i in int(seconds * 60.0):
		_c.step(1.0 / 60.0)


func _grab(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var bow: Ep2Bow = _c.armory.active_gun() as Ep2Bow
	print("BOW_VM_SHOT ", name, " draw=", snappedf(bow.draw_amount(), 0.01), " ads=", snappedf(bow.ads, 0.01), " rounds=", bow.rounds)
