extends Node
## Does the founder's film actually DECODE and ADVANCE? (headless-safe: no pixels, just clock + texture)
##   godot --headless res://tools/ep2_shots/video_probe.tscn -- path=res://src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv
func _ready() -> void:
	var path := "res://src/assets/video/cutscenes/ep2_cliff_to_hideout.ogv"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("path="): path = a.substr(5)
	print("PROBE exists=", ResourceLoader.exists(path))
	var st := ResourceLoader.load(path)
	print("PROBE loaded=", st, " class=", st.get_class() if st else "null")
	var vp := VideoStreamPlayer.new()
	vp.stream = st
	vp.size = Vector2(640, 360)
	add_child(vp)
	vp.play()
	for i in 240:
		await get_tree().process_frame
		if i % 60 == 0:
			var tex := vp.get_video_texture()
			print("PROBE f=%d playing=%s pos=%.2f tex=%s" % [i, vp.is_playing(), vp.stream_position, (str(tex.get_size()) if tex else "null")])
	get_tree().quit()
