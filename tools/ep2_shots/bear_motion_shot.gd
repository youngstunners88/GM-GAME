extends Node3D
## Motion fix T2 proof: the bear kit's brawler blows (swipe / bite / slam) and the archer's draw-release, each sampled across its whole
## clip from the side, 1280x720 SubViewport, plain studio light. Prints the paw height over time (strike frames) and, for the archer, the
## nock-to-right-paw contact and the moment the brain would loose.
##   godot --rendering-method gl_compatibility --path . res://tools/ep2_shots/bear_motion_shot.tscn -- out=<dir>
var _out := ".farm/bear_motion"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(_out)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.57, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0.0)
	vp.add_child(sun)
	var world := Node3D.new()
	vp.add_child(world)
	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	for state in ["swipe", "bite", "slam", "aim"]:
		var b: Ep2Actor = Ep2BearKit.make_bear(world, Vector3.ZERO, 2.2)
		b.facing = 0.0
		if state == "aim":
			Ep2BearKit.add_bow(b)
		Ep2BearKit.pose(b, "idle")
		for i in 20:
			b.step(1.0 / 60.0); Ep2BearKit.tick_pose(b, 1.0 / 60.0)
		Ep2BearKit.pose(b, state)
		var total: float = 1.9 if state == "aim" else (Ep2BearKit.clip_len(b, b.current_clip()) / maxf(b.anim.speed_scale, 0.01) if b.anim else 1.2)
		cam.global_position = Vector3(4.2, 1.4, 1.2)
		cam.look_at(Vector3(0, 1.15, 0.3), Vector3.UP)
		var t: float = 0.0
		for k in 8:
			var until: float = total * float(k) / 7.0
			while t < until:
				if state == "aim" and t < 1.15 and t + 1.0 / 60.0 >= 1.15:
					Ep2BearKit.pose(b, "shot")
				b.step(1.0 / 60.0); Ep2BearKit.tick_pose(b, 1.0 / 60.0)
				t += 1.0 / 60.0
			for j in 2:
				await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/%s_%d.png" % [_out, state, k])
			var sk: Skeleton3D = b.skeleton
			var rh: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
			var lh: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftHand")).origin
			var hl: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftUpLeg")).origin
			var hr: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightUpLeg")).origin
			var fwd: Vector3 = (hl - hr).cross(Vector3.UP).normalized()      # the way his hips face (actor facing 0 = +Z)
			var d := {"state": state, "k": k, "t": snappedf(t, 0.01), "clip": b.current_clip(), "paw_y": [snappedf(lh.y, 0.01), snappedf(rh.y, 0.01)],
				"hips_face_deg": snappedf(rad_to_deg(atan2(fwd.x, fwd.z)), 1.0)}
			print("@@", JSON.stringify(d))
		b.queue_free()
	get_tree().quit()
