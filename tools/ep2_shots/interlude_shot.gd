extends Node
## REAL-RENDER proof of the interlude chambers (skill ep2-interlude-chain). Plays a chamber through its own step() and saves
## the player's view at the story's key moments.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 1280x720 res://tools/ep2_shots/interlude_shot.tscn -- chamber=lift out=.farm/interlude
##   chamber=lift  -> arrive, lever (director shot), rise (mid shaft), surface
##   chamber=woods -> start, trail, quad hidden, reveal, ride, spy (hip + spyglass)
const LIFT := preload("res://src/episode2/chamber/mine_lift.tscn")
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
var _out := ".farm/interlude"
var _which := "lift"
var c: Ep2Interlude = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
		elif kv.size() == 2 and kv[0] == "chamber":
			_which = kv[1]
	DirAccess.make_dir_recursive_absolute(_out)
	c = (LIFT if _which == "lift" else WOODS).instantiate()
	add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	if _which == "lift":
		await _lift()
	else:
		await _woods()
	get_tree().quit()


func _run(seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _cap(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " beat ", c.get_beat_name(), " player ", c.get_player_position())


func _lift() -> void:
	var l: MineLiftChamber = c
	_run(1.5)
	await _cap("lift_1_arrive")
	l._player_pos = Vector3(0.0, 0.0, -1.0)
	var guard := 0
	while l.get_beat_name() != "LEVER" and guard < 600:
		guard += 1
		_run(0.05)
	_run(1.8)
	await _cap("lift_2_lever")
	while l.get_beat_name() != "RISE" and guard < 4000:
		guard += 1
		_run(0.1)
	_run(8.0)
	await _cap("lift_3_rise_a")
	_run(4.0)
	await _cap("lift_4_rise_mid")
	while l.get_beat_name() != "SURFACE" and guard < 8000:
		guard += 1
		_run(0.2)
	_run(3.0)
	await _cap("lift_5_surface")


func _woods() -> void:
	var w: WoodsQuadChamber = c
	_run(2.0)
	await _cap("woods_1_start")
	w._player_pos = Vector3(0.5, 0.0, 28.0)
	w._look_yaw = 0.0
	w._bull.position = Vector3(1.0, 0.0, 33.0)
	_run(1.0)
	await _cap("woods_2_trail")
	w._advance_to(WoodsQuadChamber.Beat.REVEAL)
	_run(0.5)
	await _cap("woods_3_hidden")
	var guard := 0
	while w.is_quad_hidden() and guard < 2000:
		guard += 1
		_run(0.1)
	_run(0.5)
	await _cap("woods_4_reveal_a")
	_run(1.8)
	await _cap("woods_5_revealed")
	while w.get_beat_name() != "RIDE" and guard < 4000:
		guard += 1
		_run(0.1)
	_run(3.5)
	await _cap("woods_6_ride")
	while w.get_beat_name() != "SPY" and guard < 8000:
		guard += 1
		_run(0.2)
	_run(1.0)
	await _cap("woods_7_spy_hip")
	var eye: Vector3 = WoodsQuadChamber.SPY_EYE
	var b: Ep2Actor = w.get_camp_bears()[2]
	var to: Vector3 = (b.position + Vector3(0.0, 1.1, 0.0)) - eye
	w._look_yaw = atan2(to.x, to.z)
	w._look_pitch = atan2(to.y, Vector2(to.x, to.z).length())
	w.set_aim(true)
	_run(0.8)
	await _cap("woods_8_spyglass")
