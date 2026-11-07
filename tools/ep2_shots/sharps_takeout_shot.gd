extends Node
## Rich takes the Sharps out of the lit case and puts it back (founder 2026-11-07: "improve the way Rich takes it out the glass so that it's not tacky").
## Real Compatibility renderer, the real town chamber, the introduction's own code: a frame every 0.15 s from the customer's side of the counter, through
## the reach, the lift and the put-back. Renders in a 1280x720 SubViewport (the window manager overrides the window size).
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/sharps_takeout_shot.tscn -- out=docs/episode2-quality/weapon-tabs-2026-11-07/takeout
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const FRAME_S := 0.15
var _out := ".farm/sharps_takeout"
var _c: GoldTownChamber = null
var _vp: SubViewport = null
var _eye := Vector3.ZERO
var _look := Vector3.ZERO


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
	var L := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Armory", p)
	_c._player_pos = L.call(GoldTownChamber.ARMORY_SPOT)
	_c._advance_to(GoldTownChamber.Beat.ARMORY)
	var intro: Ep2ArmoryIntro = _c.get_intro()
	_eye = L.call(Vector3(1.0, 0.0, -3.7))
	_look = L.call(Vector3(2.45, 1.15, -5.6))
	_until(func(): return intro.stage == Ep2ArmoryIntro.Stage.SHARPS_REACH, 40.0)
	for k in 22:                                   # the reach, the lid, the lift into his hands
		await _grab("a_%02d" % k, intro)
		_step(FRAME_S)
	_until(func(): return intro.stage == Ep2ArmoryIntro.Stage.SHARPS_BACK, 90.0)
	for k in 22:                                   # back into the case, the lid shut
		await _grab("b_%02d" % k, intro)
		_step(FRAME_S)
	print("SHARPS_TAKEOUT_SHOT done ", _out)
	get_tree().quit()


func _until(cond: Callable, seconds: float) -> void:
	for i in int(seconds * 60.0):
		if cond.call():
			return
		_c.step(1.0 / 60.0)


func _step(seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		_c.step(1.0 / 60.0)


func _grab(name: String, intro: Ep2ArmoryIntro) -> void:
	_c._player_pos = Vector3(_eye.x, 0.0, _eye.z)
	var d: Vector3 = _look - (_c._player_pos + Vector3(0, _c.eye_height, 0))
	_c._look_yaw = atan2(d.x, d.z)
	_c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_c.step(0.001)
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var held: Node3D = _c.get_rich().held_prop("Sharps")
	var inv: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Armory")).affine_inverse()
	var sk: Skeleton3D = _c.get_rich().model.find_children("*", "Skeleton3D", true, false)[0]
	var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(preload("res://src/episode2/actors/ep2_ranch_pose.gd")._find(sk, "RightHand")).origin
	print("  PROBE rich_local=", (inv * _c.get_rich().global_position).snapped(Vector3.ONE * 0.01), " hand_local=", (inv * hand).snapped(Vector3.ONE * 0.01))
	print("SHARPS_TAKEOUT_SHOT ", name, " stage=", intro.stage, " clip=", _c.get_rich().current_clip(), " in_hand=", held != null)
