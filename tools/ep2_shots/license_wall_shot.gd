extends Node
## Evidence for the founder's 2026-11-03 follow-up: the four printed licenses on the wall opposite Mike Dean, seen from the counter,
## and Inferno's quad road through Dude's ranch (no tree in it). Real chamber, real renderer:
##   SHOT_OUT=/tmp/x xvfb-run -a godot --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1280x720 res://tools/ep2_shots/license_wall_shot.tscn
var chamber: GoldTownChamber
var vp: SubViewport
var out: String


func _ready() -> void:
	out = OS.get_environment("SHOT_OUT")
	if out.is_empty(): out = OS.get_user_data_dir().path_join("license_wall_shot")
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	chamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate() as GoldTownChamber
	vp.add_child(chamber)
	chamber.setup(0, [], 0)
	chamber.set_physics_process(false)
	for i in 30: chamber.step(1.0 / 60.0)
	var office := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Certificates", p)
	# from the counter: the wall opposite Mike Dean, then Mike Dean himself (the two sides of the room)
	await shot("office_license_wall", office.call(GoldTownChamber.OFFICE_SPOT + Vector3(-0.6, 0, 0)),
		office.call(GoldTownChamber.LICENSE_WALL_AT + Vector3(0, 0.1, -GoldTownChamber.LICENSE_WALL_STEP * 1.5)))
	await shot("office_license_close", office.call(Vector3(2.2, 0, -5.9)),
		office.call(GoldTownChamber.LICENSE_WALL_AT + Vector3(0, 0.1, -GoldTownChamber.LICENSE_WALL_STEP * 1.5)))
	await shot("office_mike_dean_side", office.call(GoldTownChamber.OFFICE_SPOT), office.call(GoldTownChamber.MINISTER_DESK + Vector3(-1.5, 1.2, 0)))
	# Inferno's road into the ranch, from his seat height, looking up the road past the tree spots
	await shot("ranch_quad_road", Vector3(3.0, 0, 1150.0), Vector3(8.0, 1.6, 1215.0))
	print("LICENSE_WALL_SHOT: done ", out)
	get_tree().quit(0)


func shot(label: String, ground: Vector3, focus: Vector3) -> void:
	chamber._player_pos = ground
	var eye: Vector3 = ground + Vector3(0, chamber.eye_height, 0)
	var d: Vector3 = focus - eye
	chamber._look_yaw = atan2(d.x, d.z)
	chamber._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	chamber._update_camera(0)
	chamber._sync_visuals()
	for frame in 4: await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), 0.86)
