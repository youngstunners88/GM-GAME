extends Node
## See-it-yourself captures of the town Stockpile, its workers and the Reserve (STOCKPILE_RESERVE_PROMPT 2026-11-21) in the real
## town chamber, Compatibility renderer. The "street_gap" and "miners_right" views are also taken on master (before) for the
## no-unrequested-change comparison.
## xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/ep2_shots/stockpile_shot.tscn -- <out_dir> [seconds_of_work]
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const VIEWS: Array = [
	["street_gap", Vector3(6.0, 1.6, 1458.0), Vector3(29.0, 1.6, 1458.0)],
	["street_south", Vector3(2.0, 1.6, 1440.0), Vector3(25.0, 1.5, 1456.0)],
	["depot", Vector3(17.5, 2.4, 1458.0), Vector3(30.0, 1.0, 1458.0)],
	["yard_shovels", Vector3(20.5, 1.7, 1466.5), Vector3(23.0, 0.8, 1461.6)],
	["barrow", Vector3(19.6, 1.5, 1441.0), Vector3(23.2, 0.8, 1444.0)],
	["miners_right", Vector3(19.8, 1.6, 1436.0), Vector3(23.4, 0.9, 1430.0)],
	["reserve", Vector3(33.0, 1.7, 1494.4), Vector3(38.0, 2.0, 1488.0)],
	["reserve_door", Vector3(36.4, 1.6, 1493.6), Vector3(37.0, 1.8, 1489.0)],
	["church_east", Vector3(0.0, 1.6, 1462.0), Vector3(30.0, 2.0, 1486.0)],
]


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "user://"
	var work_s: float = float(args[1]) if args.size() > 1 else 6.0
	get_window().size = Vector2i(1280, 720)
	var town: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	town.set("_player_pos", Vector3(0.0, 0.0, 1405.0))
	# a fixed 1280x720 offscreen view of the same world (a tiling window manager resizes the window; the HUD stays out of the proof)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 62.0
	vp.add_child(cam)
	cam.make_current()
	var t: float = 0.0
	while t < work_s:
		await get_tree().process_frame
		t += get_process_delta_time()
	for v in VIEWS:
		cam.global_position = v[1]
		cam.look_at(v[2])
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
		print("SHOT ", v[0])
	get_tree().quit(0)
