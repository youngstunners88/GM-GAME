extends Node
## P1-7 (founder 2026-11-22, image4: "at least 2 steps before getting onto the platform so that there isn't the random black gap"):
## the walkway bridge meets the shaft landing in front of the cage. Real MineLift chamber, eye height on the bridge looking at the cage
## like the founder's frame, plus a low side view of the seam and a top-down of the seam.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/lift_gap_shot.tscn -- out=<dir>
var _out := ".farm/lift_gap"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var lift: MineLiftChamber = load("res://src/episode2/chamber/mine_lift.tscn").instantiate()
	add_child(lift)
	lift.setup()
	await get_tree().process_frame
	lift.set_process(false)
	lift.set_physics_process(false)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.world_3d = get_viewport().world_3d
	var cam := Camera3D.new()
	cam.fov = 70.0
	vp.add_child(cam)
	cam.current = true
	# [name, eye, look-at]: the founder's frame is on the bridge, a step or two before its end, eye 1.6 m, looking down at the cage door
	for v in [["founder", Vector3(0.35, 1.6, -7.6), Vector3(-0.2, 0.0, -2.6)],
			["seam_side", Vector3(1.3, 0.9, -6.6), Vector3(-0.4, -0.2, -4.6)],
			["seam_top", Vector3(0.0, 4.0, -5.0), Vector3(0.0, 0.0, -4.95)]]:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP if v[0] != "seam_top" else Vector3.FORWARD)
		for j in 4:
			await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [_out, v[0]])
	print("LIFT_GAP_DONE ", _out)
	get_tree().quit()
