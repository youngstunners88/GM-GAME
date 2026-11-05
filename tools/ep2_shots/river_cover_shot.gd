extends Node
## Evidence for the day-88 river cover stage (founder lock 2026-11-04): the marker, the launch-pool look, the crate under attack, the
## bend, Utah at the dock, and the Tabs tile. Real chamber, real renderer:
##   SHOT_OUT=/tmp/x xvfb-run -a godot --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy \
##     --resolution 1280x720 res://tools/ep2_shots/river_cover_shot.tscn
var c: RiverCoverChamber
var vp: SubViewport
var out: String


func _ready() -> void:
	out = OS.get_environment("SHOT_OUT")
	if out.is_empty(): out = OS.get_user_data_dir().path_join("river_cover_shot")
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var st := Ep2ArmoryState.post_hideout()
	st.purchase_river_gear("btc")
	st.purchase_sniper("btc")
	st.purchase_sniper_ammo(10, "btc")
	c = load("res://src/episode2/chamber/river_cover.tscn").instantiate() as RiverCoverChamber
	vp.add_child(c)
	c.set_physics_process(false)
	c.bind_armory(st)
	c.setup(0, [], 0)
	run(0.3)
	await shot("01_marker", c.ridge_nearest(RiverCoverChamber.MARKER + Vector3(0, 0, -9))[0], RiverCoverChamber.MARKER + Vector3(-2.2, 1.8, 0))
	var pool: Vector3 = c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT))
	await shot("02_overlook_launch_pool", RiverCoverChamber.OVERLOOKS[0], pool)
	c._player_pos = RiverCoverChamber.OVERLOOKS[0]
	aim(pool)
	run(1.2)
	run(9.0)
	await shot("03_crate_live_bears_coming", RiverCoverChamber.OVERLOOKS[0], c.get_crate().position + Vector3(0, 0, 6))
	c.set_aim(true)
	run(0.6)
	await shot("04_sharps_scope_on_the_river", RiverCoverChamber.OVERLOOKS[0], c.get_crate().position + Vector3(0, 0.6, 4))
	c.set_aim(false)
	for b in c.get_bears(): c.damage_bear(b, 99)
	run(60.0)
	await shot("05_eddy_wait_from_ledge_path", c.ridge_nearest(RiverCoverChamber.OVERLOOKS[1] + Vector3(0, 0, -16))[0], c.get_crate().position)
	for b in c.get_bears(): c.damage_bear(b, 99)          # the ledge bear on the way down
	c._player_pos = RiverCoverChamber.OVERLOOKS[1]
	run(14.0)
	await shot("06_the_bend_rapids", RiverCoverChamber.OVERLOOKS[1], c.river_point(c.river_s_of(RiverCoverChamber.BEND_POINT)))
	for b in c.get_bears(): c.damage_bear(b, 99)
	run(70.0)
	for b in c.get_bears(): c.damage_bear(b, 99)
	c._player_pos = RiverCoverChamber.OVERLOOKS[2]
	run(14.0)
	for b in c.get_bears(): c.damage_bear(b, 99)
	run(36.0)
	for b in c.get_bears(): c.damage_bear(b, 99)
	run(4.0)
	await shot("07_utah_at_the_dock", RiverCoverChamber.OVERLOOKS[2], RiverCoverChamber.DOCK_DECK + Vector3(0, 1.0, 0))
	await shot("08_utah_takes_it_bank_view", RiverCoverChamber.DOCK_DECK + Vector3(14, -1.2, 10), RiverCoverChamber.DOCK_DECK + Vector3(-1, 0.6, 0))
	print("RIVER_COVER_SHOT: done ", out, " beat ", c.get_beat_name(), " utah ", c.utah_visible())
	get_tree().quit(0)


func run(seconds: float) -> void:
	for i in int(seconds * 30): c.step(1.0 / 30.0)


func aim(focus: Vector3) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0, c.eye_height, 0)
	var d: Vector3 = focus - eye
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())


func shot(label: String, ground: Vector3, focus: Vector3) -> void:
	c._player_pos = ground
	c._ground_y = ground.y
	aim(focus)
	c._update_camera(0)
	c._sync_visuals()
	for frame in 4: await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), 0.86)
