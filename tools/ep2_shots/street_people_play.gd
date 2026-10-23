extends Node
## Actual GoldTown chamber, its own player camera/HUD/Winchester and autonomous street roster.
## Before replaces models only inside this test fixture; source assets, access gate and game logic are untouched.
var c: GoldTownChamber
var out: String = "res://design/ep2/town/people-rebuild-20261021/gameplay/session"
var variant: String = "after"
var viewport: SubViewport

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
		if arg.begins_with("variant="): variant = arg.substr(8)
	DirAccess.make_dir_recursive_absolute(out)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	c = load("res://src/episode2/chamber/gold_town.tscn").instantiate() as GoldTownChamber
	viewport.add_child(c)
	c.setup(0, [], 0)
	c.set_physics_process(false)
	await get_tree().process_frame
	var people: Ep2TownPeople = c.get_people()
	if people == null or people.people.size() != 5:
		push_error("STREET_PLAY: real chamber did not spawn all five people")
		get_tree().quit(1)
		return
	if variant == "before":
		for person in people.people:
			var folk: Ep2TownFolk = person.folk
			var row: Dictionary = {}
			for item in Ep2TownPeople.ROSTER:
				if str(item["id"]) == str(person.id): row = item
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			var path: String = "res://design/ep2/town/people-rebuild-20261021/originals/" + str(row["file"])
			if doc.append_from_file(path, state) != OK:
				get_tree().quit(1)
				return
			folk.model.free()
			folk.model = doc.generate_scene(state)
			folk.add_child(folk.model)
			var bb: AABB = Ep2TownFolk._aabb(folk.model)
			var scale_factor: float = float(row["h"]) / bb.size.y
			folk.model.scale = Vector3.ONE * scale_factor
			folk.model.position = Vector3(-(bb.position.x + bb.size.x * .5), -bb.position.y, -(bb.position.z + bb.size.z * .5)) * scale_factor
			folk._bind_clips()
	for person in people.people:
		person.folk._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Advance the same seeded, unchanged routes for both halves of the comparison.
	c._show_active = false
	c._show_blocks_control = false
	c._player_pos = Vector3(0, 0, 1403)
	run_seconds(12.0)
	for person in people.people:
		var position: Vector3 = person.folk.position
		c._player_pos = position + Vector3(0, 0, -2.5)
		look_at_person(position + Vector3(0, 1.2, 0))
		run_seconds(.55)
		look_at_person(person.folk.position + Vector3(0, 1.2, 0))
		for frame in 3: await RenderingServer.frame_post_draw
		var path: String = out.path_join(variant + "_player_" + str(person.id) + ".png")
		if viewport.get_texture().get_image().save_png(path) != OK:
			push_error("STREET_PLAY: image write failed " + path)
			get_tree().quit(1)
			return
		print("STREET_PLAY ", person.id, " pose=", person.folk.current_clip(), " greetings=", person.greets, " height=", person.folk.height_m, " camera_fov=", c.get_camera().fov)
	print("STREET_PLAY: ALL FIVE CAPTURED ", variant)
	c.queue_free()
	for frame in 3: await get_tree().process_frame
	get_tree().quit()

func look_at_person(target: Vector3) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0, c.eye_height, 0)
	var delta: Vector3 = target - eye
	c._look_yaw = atan2(delta.x, delta.z)
	c._look_pitch = atan2(delta.y, Vector2(delta.x, delta.z).length())
	c.release_look()
	c.step(1.0 / 60.0)

func run_seconds(seconds: float) -> void:
	for frame in int(seconds * 60):
		c.step(1.0 / 60.0)
		for person in c.get_people().people: person.folk._anim.advance(1.0 / 60.0)
