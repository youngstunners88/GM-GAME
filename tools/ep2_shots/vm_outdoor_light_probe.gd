extends Node
## The held rifle's brightness by view direction outdoors (the sun alone vs its own key light), to calibrate Ep2Viewmodel.set_own_light:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 \
##       --path . res://tools/ep2_shots/vm_outdoor_light_probe.tscn -- key=4.7      (key=sun: the sun alone)
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
var w: WoodsQuadChamber


func _ready() -> void:
	w = WOODS.instantiate()
	add_child(w)
	w.setup(0, [], 0)
	w.set_physics_process(false)
	w.debug_invulnerable = true
	await get_tree().process_frame
	for i in 30:
		w.step(1.0 / 60.0)
	var mode: String = "sun"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			mode = a.substr(4)
	if mode != "sun":
		w.get_viewmodel().set_own_light(float(mode), w._sun)
	w._player_pos = Vector3(-10.4, 0.0, 105.4)
	var out: Array = []
	for yaw_deg in [90, 0, -60, -139, 180]:
		w._look_yaw = deg_to_rad(float(yaw_deg))
		w._look_pitch = -0.05
		for i in 6:
			w.step(1.0 / 60.0)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(".farm/vm_key_%s_%d.png" % [mode, yaw_deg])
		var acc := Color(0, 0, 0)
		var n: int = 0
		for y in range(560, 640, 3):
			for x in range(880, 1000, 3):
				acc += img.get_pixel(x, y)
				n += 1
		out.append("%d:%.3f" % [yaw_deg, (acc.r + acc.g + acc.b) / (3.0 * float(n))])
	print("MODE ", mode, " ", " ".join(out))
	get_tree().quit()
