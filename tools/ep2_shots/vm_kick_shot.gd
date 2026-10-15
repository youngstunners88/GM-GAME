extends Node
## VIEWMODEL KICK PROOF (skill ep2-rifle-always-visible): the real woods chamber, first person, the rifle at the hip, then a shot.
## Saves the hip frame and the recoil frames (the kick peaks ~0.03-0.08 s after the shot) and prints, per frame, the screen share of
## the ArmSleeve (rendered magenta in a second pass so it can be counted) and the mean luminance of the rifle region.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 \
##       --path . res://tools/ep2_shots/vm_kick_shot.tscn -- out=.farm/kick/now
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
var _out := ".farm/kick/now"
var c: Ep2Interlude = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	c = WOODS.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	_run(1.5)
	c._look_pitch = -0.04
	_run(0.2)
	await _cap("hip")
	c.shoot()
	var ms := 0
	for t in [0.017, 0.05, 0.1, 0.15, 0.2]:
		_run(t)
		ms += int(round(t * 1000.0))
		await _cap("kick_%03dms" % ms)
	get_tree().quit()


func _run(seconds: float) -> void:
	for i in int(maxf(1.0, round(seconds * 60.0))):
		c.step(1.0 / 60.0)


func _cap(tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s_%s.png" % [_out, tag])
	# second pass: the sleeve alone in flat magenta, everything else as is -> count its pixels
	var sleeve: MeshInstance3D = c.find_child("ArmSleeve", true, false) as MeshInstance3D
	var share := -1.0
	if sleeve != null:
		var keep: Material = sleeve.material_override
		var mag := StandardMaterial3D.new()
		mag.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mag.albedo_color = Color(1, 0, 1)
		sleeve.material_override = mag
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var m: Image = get_viewport().get_texture().get_image()
		m.save_png("%s_%s_sleeve.png" % [_out, tag])
		var n := 0
		for y in range(0, m.get_height(), 4):
			for x in range(0, m.get_width(), 4):
				var p: Color = m.get_pixel(x, y)
				if p.r > 0.85 and p.b > 0.85 and p.g < 0.2:
					n += 1
		share = float(n) / float((m.get_width() / 4) * (m.get_height() / 4))
		sleeve.material_override = keep
	# the rifle region: lower-right quarter of the frame
	var lum := 0.0
	var cnt := 0
	for y in range(img.get_height() / 2, img.get_height(), 3):
		for x in range(img.get_width() / 2, img.get_width(), 3):
			var q: Color = img.get_pixel(x, y)
			lum += (q.r + q.g + q.b) / 3.0
			cnt += 1
	print("KICK %s sleeve_on_screen=%.4f lower_right_luminance=%.3f" % [tag, share, lum / maxf(1.0, float(cnt))])
