extends Node
## The Sharps 1874 and the Colt Gatling in the real chamber, real Compatibility renderer (skill ep2-armory-guns). Plays the introduction in the real
## Armory (same code as the game), steps the simulation in bulk, and grabs Lil Blunt's own eye view plus a few hero framings. Each shot teleports the eye.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/armory_guns_shot.tscn -- out=docs/episode2-quality/armory-guns-2026-10-20
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var _out := ".farm/armory_guns"
var _c: GoldTownChamber = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1600, 900)
	_c = TOWN.instantiate()
	add_child(_c)
	_c.setup(0, [], 0)
	await get_tree().process_frame
	_c.set_process(false)
	_c.set_physics_process(false)                         # this script steps the chamber itself
	var L := func(p: Vector3) -> Vector3: return Ep2GoldTown.local_to_world("Bldg_Armory", p)
	var counter: Vector3 = L.call(GoldTownChamber.ARMORY_SPOT)
	_c._player_pos = counter
	_c._advance_to(GoldTownChamber.Beat.ARMORY)
	var intro: Ep2ArmoryIntro = _c.get_intro()
	_c.get_hud().visible = true
	# 1. the lit case, as he finds it
	await _shot("1_case_before", counter, L.call(Vector3(2.6, 1.2, -5.2)), 0.0)
	# 2. Rich lifts the Sharps (clip Reach), then holds it up (InspectRifle)
	_until(func(): return intro.stage == Ep2ArmoryIntro.Stage.SHARPS_TALK, 40.0)
	await _shot("2_rich_sharps_a", counter + Vector3(0.0, 0.0, 0.3), _c.get_rich().position + Vector3(0, 1.2, 0), 0.4)
	await _shot("2_rich_sharps_b", L.call(Vector3(1.2, 0.0, -3.4)), _c.get_rich().position + Vector3(0, 1.3, 0), 1.2)
	await _shot("2_rich_sharps_c", L.call(Vector3(1.6, 0.0, -4.0)), _c.get_rich().position + Vector3(0.0, 1.25, 0), 2.0)
	# the clips he plays while he talks: a series from the customer's side of the counter
	for k in 8:
		await _shot("2_series_%d" % k, L.call(Vector3(1.3, 0.0, -3.6)), _c.get_rich().position + Vector3(0.0, 1.2, 0.0), 1.4)
	_until(func(): return intro.stage == Ep2ArmoryIntro.Stage.GATLING_WAIT, 120.0)
	var post: Ep2GatlingPost = _c.get_gatling()
	var stand: Vector3 = post.stand_position()
	# 3. the yard from the lane: the post, the sign, Utah, the plates
	await _shot("3_yard_from_lane", L.call(Vector3(3.0, 0.0, 9.0)), post.position + Vector3(2.5, 1.2, 0.0), 0.2)
	await _shot("3_post_closeup", post.position + Vector3(-3.6, 0.0, -2.2), post.position + Vector3(0.0, 1.45, 0.0), 0.1)
	await _shot("3_sign", post.position + Vector3(-4.5, 0.0, 3.0), post.position + Vector3(-2.4, 1.0, 0.0), 0.1)
	_c._player_pos = stand + Vector3(2.2, 0.0, 2.0)
	_until(func(): return post.shots_fired > 2, 60.0)
	# 4. the demonstration, from where he watches
	await _shot("4_demo_utah", stand + Vector3(1.0, 0.0, 3.6), stand + Vector3(0.0, 1.3, 0.0), 0.15)
	await _shot("4_demo_burst", stand + Vector3(3.0, 0.0, 2.4), post.position + Vector3(-9.0, 1.2, 0.0), 0.15)
	for k in 3:
		await _shot("4_crank_%d" % k, stand + Vector3(-0.8, 0.0, 2.6), stand + Vector3(0.9, 1.1, 0.0), 0.5)
	_until(func(): return intro.stage == Ep2ArmoryIntro.Stage.GATLING_OFFER, 60.0)
	# 5. he takes the crank
	_c._player_pos = stand
	_c.start_rig("eth")
	await _shot("5_mounted_idle", stand, post.position, 0.1)
	_c.shoot()
	_c.step(0.7)
	await _shot("5_mounted_firing", stand, post.position, 0.0)
	_c.step(0.25)
	await _shot("5_mounted_firing_b", stand, post.position, 0.0)
	print("ARMORY_GUNS_SHOT done ", _out, " plates ", post.plates_rung, " shots ", post.shots_fired)
	get_tree().quit()


func _until(cond: Callable, seconds: float) -> void:
	for i in int(seconds * 60.0):
		if cond.call():
			return
		_c.step(1.0 / 60.0)


func _shot(name: String, eye: Vector3, look_at: Vector3, advance: float) -> void:
	for i in int(advance * 60.0):
		_c.step(1.0 / 60.0)
	if not _c.is_mounted():
		_c._player_pos = Vector3(eye.x, 0.0, eye.z)
		_c.eye_height = maxf(eye.y, 1.55) if eye.y > 0.1 else 1.55
		var d: Vector3 = look_at - (Vector3(eye.x, 0.0, eye.z) + Vector3(0, _c.eye_height, 0))
		_c._look_yaw = atan2(d.x, d.z)
		_c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	_c.step(0.001)
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("ARMORY_GUNS_SHOT ", name, " rich=", _c.get_rich().current_clip(), " utah=", _c.get_utah().current_clip(), " stage=", _c.get_intro().stage)
