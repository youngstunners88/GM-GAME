extends Node
## Every bear motion the woods use, side by side on the founder's Tripo bear rig, so each clip is LOOKED AT before it ships:
## idle, walk + run (Meshy library clips on the same 24-bone skeleton), sit/read, sleep, archery aim + shot, leap, stomp, fallen.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1600x900 \
##       --path . res://tools/ep2_shots/bear_poses_shot.tscn -- out=.farm/bears/poses
var _out := ".farm/bears/poses"
var _bears: Array = []
var _states: Array = ["idle", "walk", "run", "sit_read", "sleep", "aim", "shot", "leap", "stomp", "dead"]
var _sequence: bool = false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out":
			_out = kv[1]
		if kv.size() == 2 and kv[0] == "states":
			_states = Array(kv[1].split(","))
		if kv.size() == 2 and kv[0] == "sequence":
			_sequence = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.68)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0.0)
	add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 20)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.3, 0.22)
	floor.material_override = fm
	add_child(floor)
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(0.0, 2.2, 11.5)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	cam.current = true
	if _sequence and _states.size() == 1:
		cam.position = Vector3(3.5, 1.6, 3.5)
		cam.look_at(Vector3(0, 0.9, 0))
		cam.fov = 30.0
	var world := Node3D.new()
	add_child(world)
	var states: Array = _states
	var x0: float = -1.5 * float(states.size() - 1)
	for i in states.size():
		var b := Ep2BearKit.make_bear(world, Vector3(x0 + float(i) * 3.0, 0.0, 0.0))
		b.facing = 0.35
		b.rotation.y = 0.35
		if str(states[i]) in ["aim", "shot"]:
			Ep2BearKit.add_bow(b)
		Ep2BearKit.pose(b, str(states[i]))
		if str(states[i]) in ["walk", "run"]:
			b.walk_to(b.position + Vector3(0, 0, 100), 1.5 if str(states[i]) == "walk" else 3.0)
		if b.has_meta("contacts"):
			b.skeleton.skeleton_updated.connect(func() -> void:
				var contact: Ep2HandContacts = b.get_meta("contacts")
				var measurements: Dictionary = {}
				for side in contact.targets:
					var bone: int = b.skeleton.find_bone(str(side) + "Hand")
					var palm: Vector3 = b.skeleton.global_transform * (b.skeleton.get_bone_global_pose(bone) * (contact.local_palm(str(side)) / b.skeleton.global_transform.basis.get_scale().x))
					measurements[side] = palm.distance_to(contact.targets[side].global_position)
				b.set_meta("contact_errors", measurements))
		var lb := Label3D.new()
		lb.text = str(states[i])
		lb.font_size = 64
		lb.position = Vector3(x0 + float(i) * 3.0, 3.2, 0.0)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lb)
		_bears.append(b)
	for f in (480 if _sequence else 50):
		for b in _bears:
			(b as Ep2Actor).step(1.0 / 60.0)
			Ep2BearKit.tick_pose(b, 1.0 / 60.0)
		await get_tree().process_frame
		if _sequence and f % 30 == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out + "_%03d.png" % (f / 30))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "_front.png")
	for b in _bears:
		var a := b as Ep2Actor
		var sk := a.skeleton
		var foot: float = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftToeBase"))).origin.y
		var hips: float = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin.y
		var stump: Node3D = a.get_meta("prop_stump") if a.has_meta("prop_stump") else null
		if stump:
			print("   stump top=", snappedf(stump.global_position.y + 0.36 * a.height_m / 4.4, 0.01), " hips_xz_local=", (a.to_local((sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin)).snapped(Vector3.ONE * 0.01))
		print(Ep2BearKit.pose_name(a), " foot_y=", snappedf(foot, 0.01), " hips_y=", snappedf(hips, 0.01), " h=", a.height_m)
		print(" contact errors=", a.get_meta("contact_errors", {}))
	cam.fov = 30.0
	var fx: float = x0 + 3.0 * float(maxi(states.find("sit_read"), 0))
	cam.position = Vector3(fx + 3.5, 1.6, 3.5)
	cam.look_at(Vector3(fx, 0.9, 0.0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + "_side.png")
	get_tree().quit()
