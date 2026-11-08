extends Node
## See-it-yourself capture of the back-lot miners (PROMPT_BACK_MINERS_2026-11-08) in the real town chamber, Compatibility renderer.
## xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/ep2_shots/back_lot_miners_shot.tscn -- <out_dir>
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const VIEWS: Array = [
	["left_lot", Vector3(-17.2, 1.6, 1422.0), Vector3(-21.4, 1.0, 1426.0)],
	["left_close", Vector3(-19.4, 1.5, 1424.4), Vector3(-21.6, 1.0, 1425.6)],
	["right_lot", Vector3(19.6, 1.6, 1442.0), Vector3(23.4, 0.9, 1434.5)],
	["right_close", Vector3(21.0, 1.4, 1428.6), Vector3(24.2, 0.8, 1426.8)],
	["from_street_gap", Vector3(0.0, 1.6, 1404.0), Vector3(-21.0, 1.0, 1426.0)],
]


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else "user://"
	get_window().size = Vector2i(1280, 720)
	var town: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	var cam := Camera3D.new()
	cam.fov = 62.0
	add_child(cam)
	cam.make_current()
	for i in 40:
		await get_tree().process_frame
	for v in VIEWS:
		cam.global_position = v[1]
		cam.look_at(v[2])
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
		print("SHOT ", v[0])
	get_tree().quit(0)
