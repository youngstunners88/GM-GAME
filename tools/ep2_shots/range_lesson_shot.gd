extends Node
## REAL-RENDER proof of the target-practice lesson and the first-person Winchester (skills ep2-range-lesson and
## ep2-fps-shooter-feel). Plays the lesson through the facility's own step() and saves the player's view at every
## stage: low-ready while Inferno leads, the demonstration, loading, hip, ADS, the shot with muzzle flash, a hit.
##   xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 960x540 res://tools/ep2_shots/range_lesson_shot.tscn -- out=.farm/range

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _out := ".farm/range"
var f: SmeltingFacilityChamber = null


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
	await get_tree().process_frame
	f._on_video_film_finished()
	_run(0.6)
	await _cap("r01_lead_low_ready")
	_until(func(): return f._lead_done, 25.0)
	await _cap("r02_bull_at_range")
	f._player_pos = Vector3(RangeDressing.LINE.x, 0.0, RangeDressing.LINE.z + 0.4)
	f._look_yaw = 0.0
	_run(1.0)
	await _cap("r03_demo_start")
	_run(9.3 + 3.0)
	await _cap("r04_demo_raise_load")
	_run(7.65 + 0.35 - 3.0 + 3.0)
	await _cap("r05_demo_aim")
	_until(func(): return f.winchester_shots_played >= 1, 40.0)
	_run(0.05)
	await _cap("r06_demo_shot")
	_run(0.5)
	await _cap("r07_demo_plate_down")
	_until(func(): return f.get_lesson_name() == "LOAD", 40.0)
	await _cap("r08_load_prompt")
	f.reload()
	_run(0.75)
	await _cap("r09_reloading")
	_until(func(): return f.get_lesson_name() == "AIM", 6.0)
	_run(0.2)
	await _cap("r10_hip_loaded")
	_metric_rifle("hip")
	f.set_aim(true)
	_run(0.5)
	await _cap("r11_ads")
	_metric_rifle("ads")
	_until(func(): return f.get_lesson_name() == "FIRE", 3.0)
	f.aim_at(f.get_mold_position(1))
	_run(0.4)
	await _cap("r12_ads_on_plate")
	f.shoot()
	_run(0.03)
	await _cap("r13_fire_flash")
	_run(0.5)
	await _cap("r14_after_kick")
	f.set_aim(false)
	_run(0.5)
	f.aim_at(f.get_mold_position(2))
	_run(0.4)
	await _cap("r15_hip_on_far_plate")
	get_tree().quit()


func _run(sec: float) -> void:
	for i in int(sec * 60.0):
		f.step(1.0 / 60.0)


func _until(pred: Callable, limit: float) -> void:
	for i in int(limit * 60.0):
		if pred.call():
			return
		f.step(1.0 / 60.0)


func _cap(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	if f._hud_ctl:
		print("  hud size=", f._hud_ctl.size, " visible=", f._hud_ctl.is_visible_in_tree(), " obj='", f._hud_ctl.objective, "'")
	print("SHOT ", name, " lesson=", f.get_lesson_name(), " ads=%.2f fov=%.1f rounds=%d" % [f.get_gun().ads, f._camera.fov, f.get_gun().rounds])


## Numbers the gauntlet feeds to Jev: where the rifle sits on screen and how far the sight is from the crosshair.
func _metric_rifle(tag: String) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var rifle: Node3D = f._rifle_node
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var top_world := Vector3.ZERO
	var top_y := -INF
	for mi in rifle.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m == f._muzzle_flash:
			continue
		var bb: AABB = m.get_aabb()
		for k in 8:
			var wp: Vector3 = m.global_transform * bb.get_endpoint(k)
			if cam.is_position_behind(wp):
				continue
			var sp: Vector2 = cam.unproject_position(wp)
			lo = lo.min(sp)
			hi = hi.max(sp)
			if wp.y > top_y:
				top_y = wp.y
				top_world = wp
	var centre: Vector2 = vp * 0.5
	var sight: Vector2 = cam.unproject_position(top_world)
	var rc: Vector2 = cam.unproject_position(rifle.global_position)
	print("METRIC %s_rifle_centre_x=%.3f y=%.3f (fraction of the frame; hip must sit low and right)" % [tag, rc.x / vp.x, rc.y / vp.y])
	print("METRIC %s_sight_offset_px=%.1f (of a %dx%d frame)" % [tag, sight.distance_to(centre), int(vp.x), int(vp.y)])
