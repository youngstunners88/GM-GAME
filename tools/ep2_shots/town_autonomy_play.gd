extends Node
## Real chamber, player camera, HUD and viewmodel. No production shortcuts or access changes.
## Run with a real renderer; SHOT_OUT points outside res:// to keep evidence out of the main pack.
var chamber: GoldTownChamber
var vp: SubViewport
var out: String
var records: Array = []

func _ready() -> void:
	out = OS.get_environment("SHOT_OUT")
	if out.is_empty(): out = "res://design/ep2/town/autonomy-20261022/gameplay"
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(960, 540)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)
	chamber = load("res://src/episode2/chamber/gold_town.tscn").instantiate() as GoldTownChamber
	vp.add_child(chamber)
	chamber.setup(0, [], 0)
	chamber.set_physics_process(false)
	await get_tree().process_frame
	var crowd: Ep2TownPeople = chamber.get_people()
	if crowd == null or crowd.people.size() != 13:
		push_error("TOWN_AUTONOMY_PLAY: incomplete cast")
		get_tree().quit(1)
		return
	for p in crowd.people: p.folk.anim_player().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	advance(12)
	# Portraits from the actual player's eye with the game's own framing and light.
	for p in crowd.people:
		watch(p)
		advance(.5)
		await capture(p.id + "_greeting")
	# The fourteenth supplied figure remains inside the actual jail cell, seen from the visitor's spot.
	var prisoner: Ep2TownFolk = chamber.get_accomplice()
	if prisoner == null:
		push_error("TOWN_AUTONOMY_PLAY: jail prisoner missing")
		get_tree().quit(1)
		return
	prisoner.anim_player().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	point_camera(chamber._jail_spot("visit"), prisoner.position + Vector3(0, .95, 0))
	for clip in ["Idle", "Observe", "Talk", "Alert"]:
		prisoner.play_clip(clip)
		prisoner.anim_player().advance(.22)
		var duration: float = prisoner.anim_player().current_animation_length
		for sample in 5:
			prisoner.anim_player().seek(duration * float(sample) / 4, true)
			await capture("prisoner_%s_%02d" % [clip, sample])
	print("TOWN_AUTONOMY_PLAY: JAIL PRISONER CAPTURED")
	# One full cycle of every runtime activity on every imported rig, in the chamber.
	# Clip selection here is a fixture, separate from the autonomous behavior sequence below.
	for p in crowd.people:
		watch(p)
		for clip in ["Idle", "Walk", "Greet", "Observe", "Rest", "Talk", "Inspect", "Alert"]:
			p.folk.play_clip(clip)
			var player: AnimationPlayer = p.folk.anim_player()
			# Manual seeking does not advance an active cross-fade. Settle the real
			# transition before sampling, otherwise the previous clip can mask this one.
			player.advance(p.folk.clip_blend + .02)
			var duration: float = player.current_animation_length
			for sample in 5:
				player.seek(duration * float(sample) / 4.0, true)
				await capture("%s_%s_%02d" % [p.id, clip, sample])
	# Autonomous timelines: no state assignment, destinations and clips selected by the live controller.
	for phase in ["ordinary", "danger", "recovery", "duel"]:
		if phase == "danger": crowd.notify_danger(Vector3(0, 0, 1425), 200)
		if phase == "duel": crowd.set_context("duel")
		for sample in 13:
			# Advance the crowd clock directly only in this scenario; chamber context would restore the story beat.
			for tick in 120:
				crowd.step(.05, Vector3(0, 0, 1404))
				for p in crowd.people: p.folk.anim_player().advance(.05)
			watch(crowd.people[sample % 13])
			await capture("%s_%02d" % [phase, sample])
	if records.size() != 605:
		push_error("TOWN_AUTONOMY_PLAY: incomplete frame coverage")
		get_tree().quit(1)
		return
	var receipt := FileAccess.open(out.path_join("receipt.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"captures": records, "final_state": crowd.snapshot()}, "\t"))
	receipt.close()
	print("TOWN_AUTONOMY_PLAY: ALL THIRTEEN CAPTURED (", records.size(), " frames)")
	chamber.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func advance(seconds: float) -> void:
	for tick in int(seconds * 60):
		chamber.step(1.0 / 60)
		for p in chamber.get_people().people: p.folk.anim_player().advance(1.0 / 60)

func watch(p: Ep2TownPeople.Person) -> void:
	var point: Vector3 = p.folk.position
	# Keep the camera on legal street ground. Never scale the person for a close-up.
	var eye_ground: Vector2 = chamber.get_people().navigation.closest(Vector2(point.x, point.z - 2.8))
	for attempt in 24:
		var angle: float = p.folk.rotation.y + float(attempt / 2) * .16 * (1 if attempt % 2 == 0 else -1)
		var candidate: Vector2 = chamber.get_people().navigation.closest(Vector2(point.x, point.z) + Vector2(sin(angle), cos(angle)) * 2.8)
		if chamber.get_people()._body_clear(candidate, null, Vector3(100, 0, 1300)) and chamber.get_people().navigation.segment_clear(candidate, Vector2(point.x, point.z)):
			eye_ground = candidate
			break
	point_camera(Vector3(eye_ground.x, 0, eye_ground.y), point + Vector3(0, p.folk.height_m * .58, 0))

func point_camera(ground: Vector3, focus: Vector3) -> void:
	chamber._player_pos = ground
	var eye: Vector3 = chamber._player_pos + Vector3(0, chamber.eye_height, 0)
	var delta: Vector3 = focus - eye
	chamber._look_yaw = atan2(delta.x, delta.z)
	chamber._look_pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
	chamber._update_camera(0)
	chamber._sync_visuals()
	var projected: Vector2 = chamber.get_camera().unproject_position(focus)
	if chamber.get_camera().is_position_behind(focus) or projected.distance_to(Vector2(vp.size) * .5) > 8:
		push_error("TOWN_AUTONOMY_PLAY: camera lost subject")
		get_tree().quit(1)

func capture(label: String) -> void:
	for frame in 2: await RenderingServer.frame_post_draw
	var error: int = vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), .86)
	if error != OK:
		push_error("TOWN_AUTONOMY_PLAY: cannot write " + label)
		get_tree().quit(1)
	var states: Array = []
	for p in chamber.get_people().people: states.append({"id": p.id, "state": p.state, "activity": p.activity, "clip": p.folk.current_clip(), "position": str(p.folk.position)})
	var prisoner: Ep2TownFolk = chamber.get_accomplice()
	records.append({"frame": label, "elapsed": chamber.get_people().elapsed, "people": states,
		"prisoner": {"position": str(prisoner.position), "clip": prisoner.current_clip()} if prisoner != null else {}})
	if records.size() % 50 == 0: print("TOWN_AUTONOMY_PLAY: progress ", records.size(), " frames")
