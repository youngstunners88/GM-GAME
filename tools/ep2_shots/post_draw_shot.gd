extends Node
## The post-draw rewrite in the real town, real Compatibility renderer (founder 2026-10-25, PROMPT_EPISODE2_CAD_TRANSITIONS_DRAW_REWRITE
## section 4): the same chamber code as the game, stepped by this script, a frame grabbed at each moment - Mike Dean running out, the
## street cheering, the pairs dancing, Mike Dean praying by the stranger, Inferno's quad coming up the lane and parked at Rich's, the body
## scene, Inferno stooping through the saloon door, the two whiskeys. Each shot teleports Lil Blunt's eye; frames come from a 1600x900 SubViewport.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/post_draw_shot.tscn -- out=<dir>
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/post_draw"
var _c: GoldTownChamber = null
var _vp: SubViewport = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	# a 1600x900 SubViewport: a tiling window manager squashes a direct window grab
	_vp = SubViewport.new()
	_vp.size = Vector2i(1600, 900)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	_c = TOWN.instantiate()
	_vp.add_child(_c)
	_c.setup(0, [], 0)
	await get_tree().process_frame
	_c.set_process(false)
	_c.set_physics_process(false)                         # this script steps the chamber itself
	_c.get_hud().visible = true
	# the duel, won: the street has cleared to the verges, the stranger is down at his mark
	_c._player_pos = GoldTownChamber.DUEL_MARK
	_c._advance_to(GoldTownChamber.Beat.DRAW)
	_run(3.0)
	_c.get_opponent().fall_dead()
	_c._draw_state = "won"
	_c._advance_to(GoldTownChamber.Beat.WON)
	var duel: Vector3 = GoldTownChamber.DUEL_MARK
	var office_door: Vector3 = Ep2GoldTown.door_world("Bldg_Certificates", 1.0)
	await _shot("1_minister_runs_out", duel + Vector3(2.0, 0.0, -1.5), office_door + Vector3(0.0, 1.1, 0.0), 1.6)
	await _shot("1b_minister_runs_out", duel + Vector3(1.5, 0.0, 0.5), _c.get_minister().position + Vector3(0.0, 1.0, 0.0), 0.8)
	_run(4.5)
	await _shot("2_street_cheers", duel + Vector3(0.0, 0.0, -8.0), duel + Vector3(0.0, 1.0, 0.0), 0.0)
	await _shot("2b_street_cheers_from_the_middle", duel, duel + Vector3(-4.6, 1.2, 1.0), 0.0)
	_report_people("cheer")
	_run_until(func(): return _c.get_people() != null and _c.get_people().celebration_phase() == "dance", 20.0)
	await _shot("3_pairs_dance", duel + Vector3(7.0, 0.0, -4.5), duel + Vector3(0.0, 1.0, 0.5), 2.5)
	await _shot("3b_pairs_dance", duel + Vector3(-7.0, 0.0, 4.5), duel + Vector3(0.0, 1.0, -0.5), 1.5)
	_report_people("dance")
	_run_until(func(): return _c.minister_task() == "kneeling" and _c.get_minister().current_clip() == "kneel", 60.0)
	var body: Vector3 = _c.get_opponent().position
	await _shot("4_minister_prays", body + Vector3(3.6, 0.0, -2.6), body + Vector3(0.6, 0.5, -0.2), 0.8)
	# the Armory: the Gatling tested; Inferno comes back up the lane on his quad and parks at Rich's
	_run_until(func(): return _c.get_beat_name() == "TIP", 60.0)
	var yard: Vector3 = Ep2GoldTown.door_world("Bldg_Armory", 3.5)
	_c._player_pos = yard
	_c._advance_to(GoldTownChamber.Beat.ARMORY)
	_c.skip_armory_intro()
	_c._mount_bursts = 1
	_run_until(func(): return _c.get_beat_name() == "BULL_BACK", 10.0)
	_run_until(func(): return _c.get_quad() != null and _c.get_quad().position.distance_to(GoldTownChamber.LANE_MARK) < 9.0, 40.0)
	await _shot("5_quad_up_the_lane", GoldTownChamber.LANE_MARK + Vector3(-3.0, 0.0, 2.5), _c.get_quad().position + Vector3(0.0, 1.2, 0.0), 0.0)
	_run_until(func(): return _c.get_quad().is_parked, 30.0)
	await _shot("6_quad_parked_at_richs", _c.get_quad().position + Vector3(-4.5, 0.0, -5.0), _c.get_quad().position + Vector3(0.0, 1.1, 0.0), 0.4)
	# Lil Blunt goes over to him (Inferno speaks once he is near)
	_run_until(func():
		_c._player_pos = _c.get_bull().position + Vector3(1.6, 0.0, 1.6)
		return _c.get_beat_name() == "BODY", 40.0)
	# the body in the street: Inferno, Mike Dean praying, the man Lil Blunt shot
	_run_until(func(): return _c.bull_task() == "at_body", 60.0)
	_c._player_pos = body + Vector3(-3.4, 0.0, 4.2)
	_run(0.4)
	await _shot("7_body_in_the_street", body + Vector3(3.6, 0.0, 3.2), body + Vector3(-0.3, 0.7, 0.6), 1.0)
	await _shot("7b_inferno_greets_minister", body + Vector3(2.6, 0.0, 3.8), _c.get_bull().position + Vector3(0.0, 1.8, 0.0), 2.0)
	_run_until(func(): return _c.get_beat_name() == "DRINKS", 60.0)
	# into the saloon: Inferno stoops through the batwing door; then the bar
	var door_in: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 0.0)
	var saloon_xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Saloon"))
	_run_until(func(): return absf((saloon_xf.affine_inverse() * _c.get_bull().position).z) < 0.35, 40.0)
	await _shot("8_inferno_stoops_through_the_door", Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(3.8, 0.0, 2.4)),
		Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(0.0, 1.7, 0.1)), 0.0)
	_run_until(func(): return _c.bull_task() == "at_bar", 30.0)
	_c._player_pos = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT)
	_run_until(func(): return _c.is_second_glass_on_bar(), 10.0)
	var bar: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT)
	await _shot("9_two_whiskeys", bar + (Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(-0.6, 0.0, 0.8)) - Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3.ZERO)),
		_c.get_bull().position + Vector3(0.0, 1.6, 0.0), 1.0)
	print("POST_DRAW_SHOT done ", _out, " beat ", _c.get_beat_name(), " max_duck ", _c.max_duck())
	get_tree().quit()


## Where everyone is and what they are doing (the proof sheet's caption data; also how a framing is chosen).
func _report_people(tag: String) -> void:
	var ppl: Ep2TownPeople = _c.get_people()
	if ppl == null:
		return
	for q in ppl.people:
		print("POST_DRAW_PEOPLE %s %s state=%s clip=%s at=(%.1f, %.1f) partner=%s" % [tag, q.id, q.state, q.folk.current_clip(),
			q.folk.position.x, q.folk.position.z, q.partner])


func _run(seconds: float) -> void:
	for i in int(seconds * 60.0):
		_c.step(1.0 / 60.0)


func _run_until(cond: Callable, seconds: float) -> void:
	for i in int(seconds * 60.0):
		if cond.call():
			return
		_c.step(1.0 / 60.0)


func _shot(name: String, eye: Vector3, look_at: Vector3, advance: float) -> void:
	_run(advance)
	_c._player_pos = Vector3(eye.x, 0.0, eye.z)
	_c.eye_height = 1.55
	var d: Vector3 = look_at - (Vector3(eye.x, 0.0, eye.z) + Vector3(0, _c.eye_height, 0))
	_c._look_yaw = atan2(d.x, d.z)
	_c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_c.step(0.001)
	for i in 4:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("POST_DRAW_SHOT ", name, " beat=", _c.get_beat_name(), " minister=", _c.get_minister().current_clip(), " bull=", _c.bull_task())
