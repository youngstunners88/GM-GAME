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
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
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
	# One full cycle of every runtime activity on every imported rig, in the chamber.
	# Clip selection here is a fixture, separate from the autonomous behavior sequence below.
	for p in crowd.people:
		watch(p)
		for clip in ["Idle", "Walk", "Greet", "Observe", "Rest", "Talk", "Inspect", "Alert"]:
			p.folk.play_clip(clip)
			var player: AnimationPlayer = p.folk.anim_player()
			var duration: float = player.current_animation_length
			for sample in 7:
				player.seek(duration * float(sample) / 6.0, true)
				await capture("%s_%s_%02d" % [p.id, clip, sample])
	# Autonomous timelines: no state assignment, destinations and clips selected by the live controller.
	for phase in ["ordinary", "danger", "recovery", "duel"]:
		if phase == "danger": crowd.notify_danger(Vector3(0, 0, 1425), 200)
		if phase == "duel": crowd.set_context("duel")
		for sample in 12:
			# Advance the crowd clock directly only in this scenario; chamber context would restore the story beat.
			for tick in 120:
				crowd.step(.05, Vector3(0, 0, 1404))
				for p in crowd.people: p.folk.anim_player().advance(.05)
			watch(crowd.people[sample % 13])
			await capture("%s_%02d" % [phase, sample])
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
	chamber._player_pos = Vector3(eye_ground.x, 0, eye_ground.y)
	var eye: Vector3 = chamber._player_pos + Vector3(0, chamber.eye_height, 0)
	var delta: Vector3 = point + Vector3(0, p.folk.height_m * .58, 0) - eye
	chamber._look_yaw = atan2(delta.x, delta.z)
	chamber._look_pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
	chamber._sync_visuals()

func capture(label: String) -> void:
	for frame in 2: await RenderingServer.frame_post_draw
	var error: int = vp.get_texture().get_image().save_jpg(out.path_join(label + ".jpg"), .86)
	if error != OK:
		push_error("TOWN_AUTONOMY_PLAY: cannot write " + label)
		get_tree().quit(1)
	var states: Array = []
	for p in chamber.get_people().people: states.append({"id": p.id, "state": p.state, "activity": p.activity, "clip": p.folk.current_clip(), "position": str(p.folk.position)})
	records.append({"frame": label, "elapsed": chamber.get_people().elapsed, "people": states})
