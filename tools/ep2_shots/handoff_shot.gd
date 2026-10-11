extends Node
## REAL-RENDER proof that the chamber hand-over is ONE cut (skill ep2-interlude-chain, "no blackouts"): the real session root loads the
## lift, builds the wood behind it frame by frame, then hands over. Saves the last lift frame and the first wood frames and prints
## their mean luminance (a black frame would read ~0) and the frame times around the cut.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 1280x720 res://tools/ep2_shots/handoff_shot.tscn -- out=.farm/handoff
const ROOT := preload("res://src/episode2/session/ep2_session_root.tscn")
var _out := ".farm/handoff"


func _lum(img: Image) -> float:
	var small: Image = img.duplicate()
	small.resize(32, 18)
	var sum := 0.0
	for y in 18:
		for x in 32:
			var c: Color = small.get_pixel(x, y)
			sum += (c.r + c.g + c.b) / 3.0
	return sum / 576.0


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("HANDOFF ", name, " luminance=%.3f" % _lum(img))


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	var root: Ep2SessionRoot = ROOT.instantiate()
	add_child(root)
	root.configure([{"chamber": "smelting_facility", "chamber_z": 5.0}], false)
	root._chamber_segment = 0
	root._on_chamber_cleared({"story": true, "chamber": "smelting_facility", "gold_awarded": 0, "gold_forfeited": 0, "next_chamber": "mine_lift"})
	var lift: Ep2Interlude = root.get_active()
	var frames := 0
	var worst := 0
	while not root.is_prebuilt("woods_quad") and frames < 2000:
		var t0 := Time.get_ticks_msec()
		await get_tree().process_frame
		worst = maxi(worst, Time.get_ticks_msec() - t0)
		frames += 1
	print("HANDOFF wood built behind the lift after ", frames, " frames, worst frame ", worst, " ms")
	await get_tree().process_frame
	await _snap("1_lift_before_cut")
	lift._look_yaw = 0.35
	var t1 := Time.get_ticks_msec()
	root._on_chamber_cleared({"story": true, "chamber": "mine_lift", "gold_awarded": 0, "gold_forfeited": 0, "next_chamber": "woods_quad"})
	print("HANDOFF cut call ms=", Time.get_ticks_msec() - t1)
	for i in 3:
		var t2 := Time.get_ticks_msec()
		await _snap("2_wood_frame_%d" % i)
		print("HANDOFF wood frame ", i, " took ms=", Time.get_ticks_msec() - t2)
	print("HANDOFF active=", root.get_active().name, " camera_current=", (root.get_active() as Ep2Interlude).get_camera().current, " yaw=%.2f" % (root.get_active() as Ep2Interlude).get_look_yaw())
	get_tree().quit()
