extends Node
## REAL-RENDER proof of the target-practice lesson and the first-person Winchester (skills ep2-range-lesson and
## ep2-fps-shooter-feel). Plays the lesson through the facility's own step() and saves the player's view at every
## stage: low-ready while Inferno leads, the demonstration, loading, hip, ADS, the shot with muzzle flash, a hit.
##   xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 960x540 res://tools/ep2_shots/range_lesson_shot.tscn -- out=.farm/range

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _out := ".farm/range"
var f: SmeltingFacilityChamber = null
var _vm: PackedStringArray = PackedStringArray()
var _quick: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
		elif kv.size() == 2 and kv[0] == "vm":      # placement sim: hipx,hipy,hipz,scale,zshift,drop,adsdepth[,yaw]
			_vm = kv[1].split(",")
		elif kv.size() == 2 and kv[0] == "quick":
			_quick = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(_out)
	f = SMELT.instantiate()
	f.intro_film = false
	add_child(f)
	if _vm.size() >= 7:      # candidate viewmodel placement from tools/ep2_sim/vm_placement_sim.mjs
		f.VM_HIP_POS = Vector3(float(_vm[0]), float(_vm[1]), float(_vm[2]))
		f.VM_SCALE = float(_vm[3])
		Ep2ViewHands.founder_z_shift = float(_vm[4])
		Ep2ViewHands.founder_drop = float(_vm[5])
		Ep2ViewHands.founder_ads_depth = float(_vm[6])
		f.VM_ADS_DEPTH = float(_vm[6])
		if _vm.size() >= 10:
			Ep2ViewHands.founder_ads_cam = Vector3(0.0, float(_vm[8]), float(_vm[9]))
		if _vm.size() >= 8:
			f.VM_HIP_ROT = Vector3(f.VM_HIP_ROT.x, PI + float(_vm[7]), f.VM_HIP_ROT.z)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	f.spread_scale = 0.0
	await get_tree().process_frame
	f._on_video_film_finished()
	_run(0.6)
	if _quick:
		f.debug_skip_lesson()
		f._player_pos = Vector3(RangeDressing.LINE.x + 0.6, 0.0, RangeDressing.LINE.z + 1.8)
		f._look_yaw = PI
		f._look_pitch = 0.02
		_run(1.2)
		await _cap("q_hip")
		_metric_rifle("hip")
		_metric_vm("hip")
		f.set_aim(true)
		_run(0.6)
		await _cap("q_ads")
		_metric_rifle("ads")
		_metric_vm("ads")
		get_tree().quit()
		return
	await _cap("r01_lead_low_ready")
	_until(func(): return f._lead_done, 25.0)
	await _cap("r02_bull_at_range")
	f._player_pos = Vector3(RangeDressing.LINE.x + 0.6, 0.0, RangeDressing.LINE.z + 1.8)     # where a player really stops (inside the arrive radius)
	f._look_yaw = PI      # face the target wall (-Z)
	f._look_pitch = -0.05
	_run(0.3)
	await _cap("r03_demo_start")
	# a wide, level look straight at the wall so all five targets (incl. the bear) are in frame
	f.debug_skip_lesson()
	f._look_yaw = PI
	f._look_pitch = 0.02
	_run(0.3)
	await _cap("r03b_wall_wide")
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


## Per-VERTEX placement numbers for the viewmodel (the founder's COD references: gun tight to the lower-right at the hip,
## and when shouldered the target stays visible - the body sits BELOW the sight line). Projects every vertex of the
## visible rifle meshes to the screen. Fractions are of the frame; "central" is the TARGET WINDOW: +-10 % wide, from 14 % above to 2 % below the crosshair.
func _metric_vm(tag: String) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var n_on: int = 0
	var n_all: int = 0
	var n_central: int = 0
	var n_upper: int = 0
	var n_lr: int = 0
	var n_near: int = 0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var fz: float = -INF            # front sight = the highest vertex of the muzzle-most 6 cm (model local frame)
	var front := Vector3.ZERO
	var front_ok: bool = false
	for mi in f._rifle_node.find_children("*", "MeshInstance3D", true, false):
		var m0 := mi as MeshInstance3D
		if m0.mesh == null or m0 == f._muzzle_flash or not m0.is_visible_in_tree():
			continue
		for si0 in m0.mesh.get_surface_count():
			for v0 in (m0.mesh.surface_get_arrays(si0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var rl: Vector3 = f._rifle_node.global_transform.affine_inverse() * (m0.global_transform * v0)
				fz = maxf(fz, rl.z)
	for mi in f._rifle_node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m == f._muzzle_flash or not m.is_visible_in_tree():
			continue
		for si in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				n_all += 1
				var rl2: Vector3 = f._rifle_node.global_transform.affine_inverse() * (m.global_transform * v)
				if rl2.z > fz - 0.06 and (not front_ok or rl2.y > front.y):
					front = m.global_transform * v
					front_ok = true
				var wp: Vector3 = m.global_transform * v
				if cam.global_position.distance_to(wp) < 0.06 and not cam.is_position_behind(wp):
					n_near += 1      # geometry swallowing the lens: the camera is INSIDE the gun
				if cam.is_position_behind(wp):
					continue
				var sp: Vector2 = cam.unproject_position(wp)
				if sp.x < 0.0 or sp.y < 0.0 or sp.x > vp.x or sp.y > vp.y:
					continue
				n_on += 1
				lo = lo.min(sp)
				hi = hi.max(sp)
				var d: Vector2 = (sp - vp * 0.5) / vp
				if absf(d.x) < 0.10 and d.y > -0.14 and d.y < 0.02:      # the target window: at and just above the crosshair
					n_central += 1
				if d.y < 0.0:
					n_upper += 1
				if d.x > 0.0 and d.y > 0.0:
					n_lr += 1
	var on: float = float(maxi(n_on, 1))
	var fs := Vector2(9.0, 9.0)
	if front_ok and not cam.is_position_behind(front):
		fs = (cam.unproject_position(front) - vp * 0.5) / vp
	print("VMF %s front_dx=%.3f front_dy=%.3f near=%.4f" % [tag, fs.x, fs.y, float(n_near) / float(maxi(n_all, 1))])
	print("VM %s on_screen=%.3f central=%.4f upper=%.4f lower_right=%.3f bbox=%.3f,%.3f,%.3f,%.3f area=%.3f" % [tag,
		float(n_on) / float(maxi(n_all, 1)), float(n_central) / on, float(n_upper) / on, float(n_lr) / on,
		lo.x / vp.x, lo.y / vp.y, hi.x / vp.x, hi.y / vp.y, (hi.x - lo.x) * (hi.y - lo.y) / (vp.x * vp.y)])
