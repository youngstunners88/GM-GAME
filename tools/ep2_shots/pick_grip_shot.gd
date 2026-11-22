extends Node
## Lil Blunt's war pick from his own eye (founder 2026-11-22: "thumb over the handle, fingers under it; a swing that can actually hurt"):
## the resting hold, then the swing frame by frame, in the real town chamber and the real Compatibility renderer.
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/ep2_shots/pick_grip_shot.tscn -- out=<dir>
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/pick_grip"
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
	_c._player_pos = Ep2GoldTown.local_to_world("Bldg_Armory", Vector3(4.0, 0.0, 9.0))
	_c._look_yaw = PI
	_c._look_pitch = -0.04
	_c.select_weapon(Ep2ArmoryState.PICK)
	_step(0.8)
	await _grab("00_hold")
	_c.shoot()
	var t: float = 0.0
	for i in 12:
		_step(0.05)
		t += 0.05
		await _grab("%02d_swing_%03dms" % [i + 1, int(t * 1000.0)])
	_step(0.8)
	await _grab("20_back_to_hold")
	print("PICK_GRIP_SHOT done ", _out)
	get_tree().quit()


func _step(seconds: float) -> void:
	for i in int(seconds * 60.0):
		_c.step(1.0 / 60.0)


func _grab(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
