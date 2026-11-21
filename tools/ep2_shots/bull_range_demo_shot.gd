extends Node
## Motion fix T1 proof (skill ep2-bull-weapon-motion): Inferno Bull's range DEMO - raise, aim, shot, recovery - from
## the player's eye AND from a close side camera, through a 1280x720 SubViewport (Hyprland tiles the window).
## Prints per frame: barrel-to-plate angle (deg), muzzle-to-grip length (m, constant = rigid rifle) and the hip-fire
## weight, so "the rifle points at what he shoots" is a number, not a feeling.
##   godot --rendering-method gl_compatibility res://tools/ep2_shots/bull_range_demo_shot.tscn -- out=<dir>

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _out := ".farm/bull_range_demo"
var f: SmeltingFacilityChamber = null
var _vp: SubViewport = null
var _cam: Camera3D = null
var _last: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	f = SMELT.instantiate()
	f.intro_film = false
	add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	f.spread_scale = 0.0
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_vp.add_child(_cam)
	await get_tree().process_frame
	# Godot 4.3 restores modified bone poses after the modifier pass: read the FINAL pose inside it.
	f._bull_hip.modification_processed.connect(_measure)
	f._on_video_film_finished()
	_run(0.6)
	_until(func(): return f._lead_done, 25.0)
	f._player_pos = Vector3(RangeDressing.LINE.x + 0.6, 0.0, RangeDressing.LINE.z + 1.8)
	f._look_yaw = PI
	f._look_pitch = -0.05
	_run(0.3)
	await _both("d00_before_demo")
	_until(func(): return f.get_lesson_name() == "DEMO", 30.0)
	_run(0.6)
	await _both("d01_raise")
	_run(1.2)
	await _both("d02_hold")
	_until(func(): return f.winchester_shots_played >= 1, 40.0)
	_run(0.03)
	await _both("d03_shot")
	_run(0.12)
	await _both("d04_kick")
	_run(0.45)
	await _both("d05_recover")
	_run(1.6)
	await _both("d06_after")
	_until(func(): return f.get_lesson_name() != "DEMO", 20.0)
	_run(1.0)
	await _both("d07_back_to_carry")
	get_tree().quit()


func _run(sec: float) -> void:
	for i in int(sec * 60.0):
		f.step(1.0 / 60.0)
		if i % 6 == 0:
			_metric("")


func _until(pred: Callable, limit: float) -> void:
	for i in int(limit * 60.0):
		if pred.call():
			return
		f.step(1.0 / 60.0)


func _measure() -> void:
	var b: Ep2Actor = f._bull
	var grip: Vector3 = Ep2BullHero.grip_world(b)
	var muz: Vector3 = Ep2BullHero.muzzle_world(b)
	var to_plate: Vector3 = f.get_mold_position(1) - grip
	_last = {"t": snappedf(b.motion_time, 0.01), "lesson": f.get_lesson_name(),
		"hip_w": snappedf(f._bull_hip.weight, 0.01), "recoil": snappedf(f._bull_hip.recoil, 0.01),
		"barrel_to_plate_deg": snappedf(rad_to_deg((muz - grip).angle_to(to_plate)), 0.1),
		"rifle_len_m": snappedf(grip.distance_to(muz), 0.001), "muzzle_y": snappedf(muz.y, 0.01)}


func _metric(tag: String) -> void:
	if _last.is_empty() or (tag == "" and float(_last.get("hip_w", 0.0)) < 0.01 and float(_last.get("recoil", 0.0)) < 0.01):
		return
	var d: Dictionary = _last.duplicate()
	d["tag"] = tag
	print("@@", JSON.stringify(d))


func _both(name: String) -> void:
	_metric(name)
	var main_cam: Camera3D = get_viewport().get_camera_3d()
	if main_cam:
		_cam.global_transform = main_cam.global_transform
		_cam.fov = main_cam.fov
		await _save("%s_player" % name)
	var b: Ep2Actor = f._bull
	var front: Vector3 = Basis(Vector3.UP, b.facing) * Vector3.BACK
	var left: Vector3 = Basis(Vector3.UP, b.facing) * Vector3.RIGHT
	var chest: Vector3 = b.global_position + Vector3.UP * b.height_m * 0.5
	_cam.fov = 40.0
	_cam.global_position = chest + left * 3.2 + front * 1.4 + Vector3.UP * 0.2
	_cam.look_at(chest + front * 0.6, Vector3.UP)
	await _save("%s_side" % name)
	_cam.global_position = chest + front * 3.6 + left * 1.1 + Vector3.UP * 0.3
	_cam.look_at(chest, Vector3.UP)
	await _save("%s_front" % name)


func _save(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
