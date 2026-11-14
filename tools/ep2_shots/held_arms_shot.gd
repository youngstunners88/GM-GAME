extends Node
## What Lil Blunt's arms look like on each thing he can hold (founder 2026-11-14: the bow arm, the Sharps' left arm, the pickaxe), from his own eye in the
## real town chamber and the real Compatibility renderer: the Winchester (the reference hands), the Sharps, the pickaxe at rest and mid-swing, and the bow
## at rest and through the draw.
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/ep2_shots/held_arms_shot.tscn -- out=<dir>
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/held_arms"
var _c: GoldTownChamber = null
var _vp: SubViewport = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
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
	for id in [Ep2ArmoryState.BOW, Ep2ArmoryState.BUFF]:
		st.acquire(id)
	st.arrows = 12
	(st.firearm(Ep2ArmoryState.BOW) as Ep2Bow).rounds = 12
	_c._player_pos = Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(4.0, 0.0, 9.0))
	_c._look_yaw = PI
	_c._look_pitch = -0.04
	_c.select_weapon(Ep2ArmoryState.WIN)
	_step(0.6)
	await _grab("1_winchester_hip")
	_c.select_weapon(Ep2ArmoryState.BUFF)
	_step(0.6)
	await _grab("2_sharps_hip")
	_c.set_aim(true)
	_step(0.12)
	await _grab("3_sharps_raising")
	_c.set_aim(false)
	_step(0.6)
	_c.select_weapon(Ep2ArmoryState.PICK)
	_step(0.6)
	await _grab("4_pickaxe_hip")
	_c.shoot()
	_step(0.2)
	await _grab("5_pickaxe_swing")
	_step(0.6)
	_c.select_weapon(Ep2ArmoryState.BOW)
	_step(0.6)
	await _grab("6_bow_hip")
	_c.shoot()
	_step(0.23)
	await _grab("7_bow_draw_third")
	_step(0.23)
	await _grab("8_bow_draw_twothird")
	_step(0.2)
	await _grab("9_bow_full")
	_step(1.2)
	_c.set_aim(true)
	_step(0.6)
	await _grab("10_bow_ads")
	_c.shoot()
	_step(0.66)
	await _grab("11_bow_ads_full")
	print("HELD_ARMS_SHOT done ", _out, " equipped=", st.equipped)
	get_tree().quit()


func _step(seconds: float) -> void:
	for i in int(seconds * 60.0):
		_c.step(1.0 / 60.0)


func _grab(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("HELD_ARMS_SHOT ", name, " equipped=", _c.armory.equipped, " view=", _c.get_viewmodel().rifle.name)
