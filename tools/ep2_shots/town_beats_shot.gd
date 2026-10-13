extends Node
## REAL-RENDER proof of the GoldMine town chamber (founder lock 2026-10-14) from Lil Blunt's own eye, rifle in hand: the street where
## Bull dropped him, Sheriff Jake behind the certificate counter, the saloon bar and the barman, the stranger, the draw in the street,
## and Bull walking up afterwards.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 1280x720 --path . res://tools/ep2_shots/town_beats_shot.tscn -- out=.farm/town_beats
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/town_beats"
var c: GoldTownChamber = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	c = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	_run(0.5)
	_look_at(Vector3(0.0, 3.0, 1440.0))
	await _cap("1_street_dropoff")
	_look_at(Ep2GoldTown.door_world("Bldg_Certificates", 0.0) + Vector3(0.0, 2.6, 0.0))
	await _cap("2_certificates_front")
	# the office: the sheriff behind the counter
	c._player_pos = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 0.0, -2.2))
	c._advance_to(GoldTownChamber.Beat.OFFICE)
	_run(2.0)
	_look_at(c.get_jake().position + Vector3(0.0, 1.45, 0.0))
	await _cap("3_sheriff_jake")
	var keep: Vector3 = c._player_pos
	c._player_pos = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.6, 0.0, -4.0))
	c._camera.fov = 40.0
	_look_at(c.get_jake().position + Vector3(0.0, 1.5, 0.0))
	await _cap("3b_jake_close")
	c._player_pos = keep
	# the saloon
	while c.get_beat_name() != "TO_BAR":
		_run(0.5)
	c._player_pos = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT)
	c._advance_to(GoldTownChamber.Beat.BAR)
	_run(1.5)
	_look_at(c.get_bartender().position + Vector3(0.0, 1.5, 0.0))
	await _cap("4_saloon_barman")
	_run(9.0)
	_look_at(c.get_opponent().position + Vector3(0.0, 1.6, 0.0))
	await _cap("5_the_stranger")
	_look_at(Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.0, 1.2, -3.0)))
	await _cap("6_saloon_room")
	# the draw in the street
	c._show_active = false
	c._show_blocks_control = false
	c._advance_to(GoldTownChamber.Beat.SQUARE_UP)
	c._opp_path = []
	c._jake_path = []
	c._player_pos = GoldTownChamber.DUEL_MARK
	c._advance_to(GoldTownChamber.Beat.DRAW)
	_run(1.0)
	_look_at(GoldTownChamber.OPP_MARK + Vector3(0.0, 1.5, 0.0))
	await _cap("7_the_draw_wait")
	while c.get_draw_state() != "go":
		_run(0.1)
	_run(0.5)
	_look_at(GoldTownChamber.OPP_MARK + Vector3(0.0, 1.3, 0.0))
	await _cap("8_draw")
	c._on_player_shot()
	_run(4.0)
	while c.get_beat_name() == "DRAW":
		_run(0.2)
	_run(2.5)
	_look_at(c.get_bull().position + Vector3(0.0, 2.0, 0.0))
	await _cap("9_bull_arrives")
	get_tree().quit()


func _look_at(p: Vector3) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0.0, c.eye_height, 0.0)
	var d: Vector3 = p - eye
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	c.release_look()
	c.step(1.0 / 60.0)


func _run(seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _cap(shot_name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " beat ", c.get_beat_name())
