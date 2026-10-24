extends Node
## Frozen, repeatable comparisons in the game's town/desert environment. No runtime or access-gate changes.
## Same roster height, Ep2TownFolk scaling, 1.55m player eye, 78 degree gameplay lens for both GLBs.
## -- out=<absolute directory> only=rancher variant=before|after full=1
var out: String = "res://design/ep2/town/people-rebuild-20261021/gameplay"
var only: String = ""
var variant: String = "after"
var full: bool = false
var hands_only: bool = false
var cam: Camera3D
var vp: SubViewport
var world: Node3D
var records: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
		if arg.begins_with("only="): only = arg.substr(5)
		if arg.begins_with("variant="): variant = arg.substr(8)
		if arg == "full=1": full = true
		if arg == "hands_only=1": hands_only = true
	DirAccess.make_dir_recursive_absolute(out)
	vp = SubViewport.new()
	vp.size = Vector2i(960, 960)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	Ep2GoldTown.apply_desert_grade(env.environment, sun, 1.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	ground.mesh = plane
	ground.material_override = Ep2GoldTown.desert_ground_mat()
	ground.position = Vector3(0, 0, 1450)
	world.add_child(ground)
	Ep2GoldTown.build(world, true)
	cam = Camera3D.new()
	cam.fov = Ep2Interlude.FPS_FOV
	cam.far = 900.0
	world.add_child(cam)
	cam.current = true
	for row in Ep2TownPeople.ROSTER:
		if only != "" and not str(row["id"]) in only.split(","): continue
		await review(row)
	var f := FileAccess.open(out.path_join("%s_%s%s_receipt.json" % [variant, only if only != "" else "all", "_hands" if hands_only else ""]), FileAccess.WRITE)
	f.store_string(JSON.stringify(records, "\t"))
	f.close()
	print("STREET_PEOPLE_REVIEW: DONE ", records.size(), " captures ", variant)
	get_tree().quit()

func review(row: Dictionary) -> void:
	var id: String = str(row["id"])
	var file: String = str(row["file"])
	var path: String = "res://design/ep2/town/people-rebuild-20261021/originals/" + file if variant == "before" else Ep2Extras.PEOPLE_DIR + file
	# Read exact GLB bytes, including embedded maps. No stale editor-import cache in either half of the comparison.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var error: int = doc.append_from_file(path, state)
	if error != OK:
		push_error("STREET_REVIEW cannot parse " + path)
		get_tree().quit(1)
		return
	var scene: Node3D = doc.generate_scene(state)
	var folk := Ep2TownFolk.new()
	world.add_child(folk)
	folk.add_child(scene)
	folk.model = scene
	folk.height_m = float(row["h"])
	var bb: AABB = Ep2TownFolk._aabb(scene)
	var scale_factor: float = folk.height_m / maxf(bb.size.y, .01)
	scene.scale = Vector3.ONE * scale_factor
	scene.position = Vector3(-(bb.position.x + bb.size.x * .5) * scale_factor, -bb.position.y * scale_factor, -(bb.position.z + bb.size.z * .5) * scale_factor)
	folk._bind_clips()
	folk.place(Vector3(0, 0, 1418))
	folk.rotation.y = PI
	folk._anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	folk.play_clip("Idle")
	folk._anim.seek(.3, true)
	var views: Array = [["front", Vector3(0, 1.55, 1414.8), Vector3(0, .97, 1418)], ["three_quarter", Vector3(2.3, 1.55, 1415.4), Vector3(0, .97, 1418)], ["side", Vector3(3.2, 1.55, 1418), Vector3(0, .97, 1418)], ["back", Vector3(0, 1.55, 1421.2), Vector3(0, .97, 1418)]]
	for view in ([] if hands_only else views):
		cam.position = view[1]
		cam.look_at(view[2], Vector3.UP)
		await shot(id + "_Idle_" + str(view[0]))
	cam.position = Vector3(0, 1.55, 1416.95)
	cam.look_at(Vector3(0, 1.55, 1418), Vector3.UP)
	if not hands_only: await shot(id + "_face")
	if full:
		for clip in ["Idle", "Walk", "Greet", "Point", "Carry", "Observe", "Rest", "Talk", "Inspect", "Alert"]:
			folk.play_clip(clip)
			var duration: float = folk._anim.current_animation_length
			for frame in (0 if hands_only else 9):
				folk._anim.seek(duration * float(frame) / 8.0, true)
				for angle in 2:
					cam.position = Vector3(float(angle) * 2.3, 1.55, 1414.8 + float(angle) * .6)
					cam.look_at(Vector3(0, .97, 1418), Vector3.UP)
					await shot("%s_%s_%02d_%d" % [id, clip, frame, angle])
			folk._anim.seek(duration * .5, true)
			var skeleton: Skeleton3D = folk.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			skeleton.force_update_all_bone_transforms()
			for side in ["l", "r"]:
				for bone in skeleton.get_bone_count():
					var key: String = skeleton.get_bone_name(bone).to_lower().replace(".", "").replace("_", "")
					if key != "hand" + side: continue
					var hand: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(bone).origin)
					cam.position = Vector3(hand.x + (.35 if side == "r" else -.35), 1.55, hand.z - .35)
					cam.look_at(hand, Vector3.UP)
					await shot("%s_%s_hand_%s" % [id, clip, side])
			cam.position = Vector3(0, 1.55, 1416.95)
			cam.look_at(Vector3(0, 1.55, 1418), Vector3.UP)
			if not hands_only: await shot("%s_%s_face" % [id, clip])
	folk.queue_free()
	await get_tree().process_frame

func shot(label: String) -> void:
	for frame in 3: await RenderingServer.frame_post_draw
	var path: String = out.path_join(variant + "_" + label + ".png")
	var error: int = vp.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("STREET_CAPTURE write failed: " + path + " error=" + str(error))
		get_tree().quit(1)
		return
	records.append({"image": path, "camera": str(cam.position), "fov": cam.fov, "lighting": "Ep2GoldTown.apply_desert_grade strength=1.0"})
	print("STREET_CAPTURE ", label)
