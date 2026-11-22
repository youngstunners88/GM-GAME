extends Node
## P1-8 (founder 2026-11-22, image2): the Reserve turned to face the church, RESERVE as a gold header above the door.
## Frames: the founder's camera (south-west of the old door, looking north-east), the new front straight on, and the view out of the door.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/reserve_shot.tscn -- out=<dir>
const SITE := preload("res://src/episode2/extras/stockpile/stockpile_site.gd")
var _out := ".farm/reserve"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var town: GoldTownChamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate()
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	town.set_process(false)
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	var xf: Transform3D = SITE.reserve_xform()
	var door: Vector3 = xf.origin
	var out_dir: Vector3 = xf.basis * Vector3(0.0, 0.0, 1.0)
	var church: Vector3 = Ep2GoldTown.local_to_world("Church", Vector3.ZERO)
	for v in [["founder", Vector3(30.5, 1.6, 1499.5), Vector3(39.0, 1.9, 1486.0)],
			["front", door + out_dir * 9.0 + Vector3(0.0, 1.6, 0.0), door + Vector3(0.0, 3.0, 0.0)],
			["door_out", xf * SITE.RESERVE_INSPECT + Vector3(0.0, 1.6, 0.0), church + Vector3(0.0, 4.0, 0.0)]]:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for j in 6:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, v[0]])
	print("RESERVE_SHOT_DONE ", _out)
	get_tree().quit()
