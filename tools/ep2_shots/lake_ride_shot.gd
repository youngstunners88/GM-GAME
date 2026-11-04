extends Node
## The ride to Logan's Lake as a before/after strip (founder 2026-11-04: "why is there desert sand here"): the real trail with the real
## lake preview on its horizon, every 40 m over the last stretch, looking ahead and to both sides, then the shore itself.
##   godot --rendering-method gl_compatibility --rendering-driver opengl3 --path . res://tools/ep2_shots/lake_ride_shot.tscn -- out=<dir>
var out := ".farm/lake-ride"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var session = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	vp.add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail)
	session._active = trail
	session._wire_chamber(trail)
	trail.setup()
	trail.set_physics_process(false)
	session._drive_prebuild(1e9)
	var lake = session._pb_node
	for i in 200:
		trail.preview_lake(lake)
	print("ROUTE total ", trail._route_total)
	for distance in [520.0, 400.0, 300.0, 220.0, 160.0, 110.0, 70.0, 30.0, 4.0]:
		trail._place_at_distance(trail._route_total - distance)
		trail._blend_lake_light()
		for side in [["ahead", 0.0], ["left", 0.9], ["right", -0.9]]:
			trail._look_yaw = trail._travel_yaw + float(side[1])
			trail._look_pitch = -0.04
			trail._update_camera(0)
			trail._sync_visuals()
			for f in 4:
				await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_jpg("%s/ride_%03d_%s.jpg" % [out, int(distance), str(side[0])], 0.85)
	print("LAKE_RIDE_SHOT_DONE")
	get_tree().quit()
