extends Node
## Does the forearm extension (ArmSleeve, drawn flat magenta here) ever show on screen? The real viewmodel (Ep2Viewmodel: hip pose,
## breathing, recoil kick, lever roll, look-lag, walk bob) is RENDERED every 1/60 s through a shot and a look sweep, and the
## magenta pixels are counted (occlusion by the hand/rifle is real, unlike a projection). Run per screen shape:
##   xvfb-run -a -s "-screen 0 1725x993x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1725x993 \
##       --path . res://tools/ep2_shots/vm_sleeve_probe.tscn -- hip=0.17,-0.16,-0.5 [hip=...] [save=.farm/sleeve/x]
var _hips: Array = []
var _save := ""
var _tag_hip := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "hip":
			var p: PackedStringArray = kv[1].split(",")
			_hips.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
		elif kv.size() == 2 and kv[0] == "save":
			_save = kv[1]
	if _hips.is_empty():
		_hips.append(Ep2Viewmodel.VM_HIP_POS)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.45, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.4, 0.0)
	add_child(sun)
	for hp in _hips:
		_tag_hip = "%.2f_%.2f_%.2f" % [hp.x, hp.y, hp.z]
		var r: Array = await _worst(hp)
		print("PROBE hip=%s size=%s worst_sleeve_pixels=%.5f at=%s" % [str(hp), str(get_viewport().get_visible_rect().size), r[0], r[1]])
	get_tree().quit()


func _worst(hp: Vector3) -> Array:
	var cam := Camera3D.new()
	cam.fov = 78.0
	add_child(cam)
	cam.current = true
	var vm := Ep2Viewmodel.new()
	vm.hip_pos = hp
	add_child(vm)
	vm.attach(cam)
	var sleeve: MeshInstance3D = vm.rifle.find_child("ArmSleeve", true, false) as MeshInstance3D
	var mag := StandardMaterial3D.new()
	mag.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mag.albedo_color = Color(1, 0, 1)
	if sleeve != null:
		sleeve.material_override = mag
	var worst := 0.0
	var at := "-"
	for i in 20:
		vm.step(1.0 / 60.0, false, false, 0.0)
	var r: float = await _count("idle", vm)
	if r > worst:
		worst = r
		at = "idle"
	vm.fire()
	for i in 48:
		vm.step(1.0 / 60.0, false, false, 0.0)
		if i % 2 == 0:
			r = await _count("shot_%02d" % i, vm)
			if r > worst:
				worst = r
				at = "shot+%dms" % int((i + 1) * 1000.0 / 60.0)
	for lag in [Vector2(-1200, 0), Vector2(1200, 0), Vector2(0, 1200), Vector2(0, -1200)]:
		for i in 6:
			vm.add_look(lag / 6.0)
			vm.step(1.0 / 60.0, true, false, float(i) * 0.5 + 0.8)
		r = await _count("lag_%d_%d" % [int(lag.x), int(lag.y)], vm)
		if r > worst:
			worst = r
			at = "look-lag %s" % str(lag)
	vm.queue_free()
	cam.queue_free()
	return [worst, at]


func _count(tag: String, _vm: Node) -> float:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var n := 0
	var tot := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var p: Color = img.get_pixel(x, y)
			tot += 1
			if p.r > 0.8 and p.b > 0.8 and p.g < 0.25:
				n += 1
	if _save != "" and (n > 0 or tag == "idle"):
		img.save_png("%s_%s_%s.png" % [_save, _tag_hip, tag])
	return float(n) / float(tot)
