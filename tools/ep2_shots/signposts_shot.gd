extends Node
## P1-11 (founder 2026-11-22: "The signposts on the ridge and at logans lake are horrid ... The words are floating in mid air."):
## Logan's Lake arrival sign, the auction sign and the overlook sign from the path at eye height, then the river's ridge sign.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/signposts_shot.tscn -- out=<dir>
var _out := ".farm/signposts"


func _shoot(cam: Camera3D, name: String, eye: Vector3, at: Vector3) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	for j in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var lake: LogansLakeChamber = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	add_child(lake)
	lake.set_physics_process(false)
	lake.setup(0, [], 0)
	lake.set_process(false)
	lake._auction_sign.visible = true
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.current = true
	var sign: Vector3 = LogansLakeChamber.ARRIVAL_SIGN
	await _shoot(cam, "lake_arrival", sign + Vector3(1.5, 1.6, -5.5), sign + Vector3(0, 1.4, 0))
	var auction: Vector3 = lake._auction_sign.position
	await _shoot(cam, "lake_auction", auction + Vector3(-1.0, 1.6, 4.5), auction + Vector3(0, 1.6, 0))
	await _shoot(cam, "lake_overlook", Vector3(-2.0, LogansLakeChamber.path_height(28) + 1.6, 28.0), Vector3(-4, LogansLakeChamber.path_height(34) + 1.4, 34))
	lake.free()
	var river: RiverCoverChamber = load("res://src/episode2/chamber/river_cover.tscn").instantiate()
	add_child(river)
	river.set_physics_process(false)
	river.debug_no_ranged = true
	var st := Ep2ArmoryState.post_hideout()
	st.river_gear = true
	river.bind_armory(st)
	river.setup(0, [], 0)
	river.set_process(false)
	cam.current = true
	var rp: Vector3 = RiverCoverChamber.RIDGE_POINTS[1]
	await _shoot(cam, "ridge_sign", rp + Vector3(-1.5, 1.6, -5.0), rp + Vector3(-3.2, 1.6, 0))
	print("SIGNPOSTS_SHOT_DONE ", _out)
	get_tree().quit()
