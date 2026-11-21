extends Node
## Motion fix proof (T4 Rich + Sharps, T5 Utah + Gatling): the real Armory intro, stepped by this script, captured through a 1280x720
## SubViewport from fixed side cameras across the WHOLE beat (reach, lift, chest, put-back; crank demo). Prints per frame the hand
## contact numbers measured after the IK (Rich's IK shortfall per arm; Utah's palm to the crank handle).
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/armory_motion_shot.tscn -- out=<dir> [part=sharps|gatling|all]

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/armory_motion"
var _part := "all"
var _c: GoldTownChamber = null
var _vp: SubViewport = null
var _cam: Camera3D = null
var _case: Ep2SharpsCase = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		elif a.begins_with("part="): _part = a.substr(5)
	DirAccess.make_dir_recursive_absolute(_out)
	_c = TOWN.instantiate()
	add_child(_c)
	_c.setup(0, [], 0)
	await get_tree().process_frame
	_c.set_process(false)
	_c.set_physics_process(false)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	_vp.add_child(_cam)
	var L := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Armory", p)
	_c._player_pos = L.call(GoldTownChamber.ARMORY_SPOT)
	_c._advance_to(GoldTownChamber.Beat.ARMORY)
	var intro: Ep2ArmoryIntro = _c.get_intro()
	for n in _c.find_children("*", "Node3D", true, false):
		if n is Ep2SharpsCase: _case = n
	var S := Ep2ArmoryIntro.Stage
	if _part in ["sharps", "all"]:
		_until(func(): return intro.stage == S.SHARPS_SETDOWN, 40.0)
		await _frame("s0_setdown", intro, L.call(Vector3(1.0, 1.45, -3.9)), L.call(Vector3(2.3, 1.05, -5.3)))
		_until(func(): return intro.stage == S.SHARPS_REACH, 10.0)
		for t in [0.3, 0.8, 1.3, 1.8, 2.3, 2.8, 3.25]:
			_until(func(): return intro.stage_time() >= t or intro.stage != S.SHARPS_REACH, 5.0)
			await _frame("s1_reach_%.2f" % t, intro, L.call(Vector3(1.0, 1.45, -3.9)), L.call(Vector3(2.3, 1.05, -5.3)))
		_until(func(): return intro.stage == S.SHARPS_TALK, 10.0)
		_run(1.0)
		await _frame("s2_talk", intro, L.call(Vector3(1.0, 1.45, -3.9)), L.call(Vector3(2.1, 1.25, -5.2)))
		_until(func(): return intro.stage == S.SHARPS_BACK, 60.0)
		for t in [0.4, 1.0, 1.6, 2.2, 2.8, 3.5]:
			_until(func(): return intro.stage_time() >= t or intro.stage != S.SHARPS_BACK, 5.0)
			await _frame("s3_back_%.2f" % t, intro, L.call(Vector3(1.0, 1.45, -3.9)), L.call(Vector3(2.3, 1.05, -5.3)))
	if _part in ["gatling", "all"]:
		if _part == "gatling":
			intro._begin_gatling()                       # straight to the yard (the Sharps beat is part=sharps)
		var post0: Ep2GatlingPost = _c.get_gatling()
		_until(func():
			if post0 != null: _c._player_pos = post0.stand_position() + Vector3(-2.5, 0.0, 2.5)    # Lil Blunt follows him out
			return intro.stage == S.GATLING_DEMO, 120.0)
		var post: Node3D = _c.get_gatling()
		for k in 8:
			_run(0.35)
			var stand: Vector3 = post.stand_position() if post else Vector3.ZERO
			await _frame("g_demo_%d" % k, intro, stand + Vector3(-1.2, 1.5, 2.4), stand + Vector3(0.6, 1.1, 0.0))
	get_tree().quit()


func _run(sec: float) -> void:
	for i in int(sec * 60.0):
		_c.step(1.0 / 60.0)


func _until(cond: Callable, seconds: float) -> void:
	for i in int(seconds * 60.0):
		if cond.call():
			return
		_c.step(1.0 / 60.0)


func _frame(name: String, intro: Ep2ArmoryIntro, eye: Vector3, at: Vector3) -> void:
	_c.step(0.001)
	_cam.global_position = eye
	_cam.look_at(at, Vector3.UP)
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	var d := {"shot": name, "stage": intro.stage, "t": snappedf(intro.stage_time(), 0.01), "rich_clip": _c.get_rich().current_clip()}
	if _case != null:
		for side in _case._ik:
			var ik: Ep2ArmIK = _case._ik[side]
			d["ik_" + side] = [snappedf(ik.influence, 0.01), snappedf(ik.shortfall, 0.003)]
	var post: Ep2GatlingPost = _c.get_gatling()
	if post != null and intro.stage == Ep2ArmoryIntro.Stage.GATLING_DEMO:
		d["crank_ik_shortfall_m"] = snappedf(intro.crank_hand_error(), 0.003)
		var sks: Array = _c.get_utah().model.find_children("*", "Skeleton3D", true, false)
		var sk: Skeleton3D = sks[0]
		for side in ["Right", "Left"]:
			var hb: int = sk.find_bone("mixamorig:%sHand" % side)
			var goal: Vector3 = post.crank_handle_position() if side == "Right" else post.brace_position()
			d[side + "_wrist_to_target_m"] = snappedf((sk.global_transform * sk.get_bone_global_pose(hb).origin).distance_to(goal), 0.003)
	print("@@", JSON.stringify(d))
