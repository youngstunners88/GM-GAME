extends Node
## PLAYER-EYE capture (skill ep2-hideout-player-view): what Lil Blunt actually sees once he is inside the hideout,
## through the game's own follow camera and real walk input. Scripted camera boards do not count.
##   xvfb-run -a -s "-screen 0 960x540x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 960x540 res://tools/ep2_shots/player_view_shot.tscn -- out=<dir>

const SMELT := preload("res://src/episode2/chamber/smelting_facility.tscn")
var _out := ".farm/pv"
var f: Node = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	f = SMELT.instantiate()
	f.intro_film = false
	add_child(f)
	f.setup(0, [], 0)
	f.set_physics_process(false)
	await get_tree().process_frame
	_run(2.0)
	await _cap("pv0_arrival")
	f._look_yaw = 0.0
	_walk_to(-2.0)
	await _cap("pv1_forward")
	_walk_to(2.0)
	await _cap("pv2_midroom")
	# look left, right and back with the mouse, standing still
	for spec in [["pv3_look_left", 0.9], ["pv4_look_right", -0.9], ["pv5_look_back", 3.1416]]:
		f._look_yaw = spec[1]
		_run(1.0)
		await _cap(spec[0])
	f._look_yaw = 0.0
	f._look_pitch = 0.25
	_run(1.0)
	await _cap("pv6_look_up")
	get_tree().quit()


func _walk_to(z: float) -> void:
	f.set_move_input(Vector2(0.0, 1.0))
	for i in 900:
		if f.get_player_position().z >= z:
			break
		f.step(1.0 / 60.0)
	f.set_move_input(Vector2.ZERO)
	_run(0.6)


func _run(sec: float) -> void:
	for i in int(sec * 60.0):
		f.step(1.0 / 60.0)


func _cap(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name, " pos=", f.get_player_position(), " yaw=", f.get_look_yaw())
