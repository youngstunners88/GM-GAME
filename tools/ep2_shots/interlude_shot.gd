extends Node
## REAL-RENDER proof of the interlude chambers (skill ep2-interlude-chain). Plays a chamber through its own step() and saves
## the player's view at the story's key moments.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility \
##       --resolution 1280x720 res://tools/ep2_shots/interlude_shot.tscn -- chamber=lift out=.farm/interlude
##   chamber=lift  -> arrive (first person, rifle in hands), ADS, lever (director shot: body + held rifle), rise, surface
##   chamber=woods -> start, trail, FIRE (muzzle flash), quad hidden, reveal, ride (back seat), spy (hip + spyglass)
const LIFT := preload("res://src/episode2/chamber/mine_lift.tscn")
const WOODS := preload("res://src/episode2/chamber/woods_quad.tscn")
var _out := ".farm/interlude"
var _which := "lift"
var _quick := false                                  # quick=1: only the framings graded against the founder's target (woods)
var c: Ep2Interlude = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
		elif kv.size() == 2 and kv[0] == "chamber":
			_which = kv[1]
		elif kv.size() == 2 and kv[0] == "quick":
			_quick = kv[1] == "1"
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
	var p0: Vector3 = l._player_pos
	l._player_pos = Vector3(0.0, 0.0, -8.0)             # the founder-target framing: just out of the hideout tunnel, the bridge and cage ahead
	_run(0.3)
	await _cap("lift_0_entry")
	l._player_pos = p0
	c.set_aim(true)
	_run(0.6)
	await _cap("lift_1b_ads")
	c.set_aim(false)
	_run(0.6)
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
	var g2 := 0
	while l.is_show_active() and g2 < 200:              # Inferno walks out first; frame the walkway once he is on his way
		g2 += 1
		_run(0.1)
	l._look_yaw = 0.0                                   # turn to the daylight: the walkway out of the shaft (target view top_exit)
	l._look_pitch = -0.05
	_run(1.5)
	await _cap("lift_6_exit_walkway")


func _woods() -> void:
	var w: WoodsQuadChamber = c
	_run(2.0)
	await _cap("woods_1_start")
	w._player_pos = Vector3(0.5, 0.0, 28.0)
	w._look_yaw = 0.0
	w._bull.position = Vector3(1.0, 0.0, 33.0)
	_run(1.0)
	await _cap("woods_2_trail")
	# the founder's target framing (woods_exterior_target.jpg): standing in the old growth, Inferno ahead, the view tipped up into the canopy
	var keep_pitch: float = w._look_pitch
	w._look_pitch = 0.22
	_run(0.2)
	await _cap("woods_0_target")
	w._look_pitch = keep_pitch
	_run(0.2)
	if _quick:
		return
	w.shoot()
	_run(0.03)
	await _cap("woods_2b_fire")
	_run(1.0)
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
	# the quad as the player sees it: two vantage points the plan puts him at (the trail side, then right beside it)
	for spec in [["woods_5b_quad_trail", Vector3(3.5, 0.0, -7.0)], ["woods_5c_quad_near", Vector3(2.4, 0.0, -3.4)], ["woods_5d_quad_front", Vector3(0.6, 0.0, 6.5)]]:
		var at: Vector3 = WoodsQuadChamber.QUAD_POS
		w._player_pos = at + (spec[1] as Vector3)
		var d: Vector3 = (at + Vector3(0.0, 0.9, 0.0)) - (w._player_pos + Vector3(0.0, 1.55, 0.0))
		w._look_yaw = atan2(d.x, d.z)
		w._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
		_run(0.1)
		await _cap(str(spec[0]))
	while w.get_beat_name() != "RIDE" and guard < 4000:
		guard += 1
		_run(0.1)
	_run(3.5)
	await _cap("woods_6_ride")
	# the same moment from outside (the player never sees this): proves Inferno sits on the seat with both hands on the grips
	var cam: Camera3D = w.get_camera()
	var cam_xf: Transform3D = cam.global_transform
	w.get_viewmodel().set_shown(false)
	w.get_hud().visible = false
	var qn: Node3D = w.get_quad_node()
	for spec2 in [["woods_6b_ride_side", Vector3(3.6, 1.3, 0.6)], ["woods_6c_ride_rear", Vector3(-1.2, 2.2, -4.4)]]:
		cam.global_position = qn.global_position + Basis(Vector3.UP, w._quad_yaw) * (spec2[1] as Vector3)
		cam.look_at(qn.global_position + Basis(Vector3.UP, w._quad_yaw) * Vector3(0.0, 1.5, 0.3), Vector3.UP)
		await _cap(str(spec2[0]))
	cam.global_transform = cam_xf
	w.get_viewmodel().set_shown(true)
	w.get_hud().visible = true
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
