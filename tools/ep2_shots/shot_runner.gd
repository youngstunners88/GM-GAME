extends Node
## Fast local screenshot rig (skill: ep2-reference-match-loop). Runs the REAL runner scene with the
## real view under Xvfb + Mesa software GL (Compatibility renderer — the same one the web build
## uses), lets the autopilot play, and saves the viewport at chosen track distances. ~1 minute a
## capture instead of a 15-minute web export + browser run.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" .godot-cache/Godot_v4.3-stable_linux.x86_64 \
##       --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 \
##       res://tools/ep2_shots/shot_runner.tscn -- out=.farm/shots_l leg=0 at=20,100,262,432 aim=800,300
##
## Args: out=<dir> leg=<0|1> at=<comma metres> aim=<x,y mouse px> (default centre-right).
## The mouse aim is faked by moving the viewport mouse position via Input.warp_mouse.

var _last_d: float = 0.0
const SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")

func _args() -> Dictionary:
	var d := {"out": ".farm/shots_l", "leg": "0", "at": "20,100", "aim": "800,300"}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2:
			d[kv[0]] = kv[1]
	return d

func _ready() -> void:
	var args: Dictionary = _args()
	var out: String = str(args["out"])
	if str(args.get("cam", "")) != "":
		# cam=x,y,z,lx,ly,lz ; z and lz are OFFSETS from the rider's distance
		var cv: PackedStringArray = str(args["cam"]).split(",")
		RunnerView.debug_cam = [Vector3(float(cv[0]), float(cv[1]), float(cv[2])), Vector3(float(cv[3]), float(cv[4]), float(cv[5]))]
	for f in str(args.get("off", "")).split(",", false):
		RunnerView.debug_off[f] = true
	DirAccess.make_dir_recursive_absolute(out)
	var marks: PackedFloat32Array = PackedFloat32Array()
	for m in str(args["at"]).split(",", false):
		marks.append(float(m))
	var leg: Dictionary = Episode2Tracks.LEGS[int(args["leg"])]
	if str(args.get("custom", "")) == "coins":
		# Inspection leg: coins on the outer rails ahead of a rider who never collects them.
		leg = {"chamber_z": 200.0, "zip_segments": [], "archers": [], "obstacles": [
			{"z": 9.0, "lane": 1, "type": "gold"}, {"z": 13.0, "lane": 1, "type": "gold"},
			{"z": 11.0, "lane": 2, "type": "gold"}, {"z": 15.0, "lane": 2, "type": "gold"}], "start_lane": 0}
	if str(args.get("custom", "")) == "cliff":
		# Inspection leg: a short run that ends at the cliff mouth (the real Descent is 1800 m long).
		leg = {"chamber_z": 240.0, "zip_segments": [], "archers": [], "obstacles": [], "start_lane": 1,
			"ends_at_cliff": true}
	if str(args.get("custom", "")) == "shovels":
		# Inspection leg: the shovel line ahead of a rider who never zips (he will get smacked - fine).
		leg = {"chamber_z": 200.0, "zip_segments": [{"start_z": 20.0, "end_z": 60.0}], "archers": [], "obstacles": [
			{"z": 60.0, "lane": 0, "type": "shovels"}, {"z": 60.0, "lane": 1, "type": "shovels"},
			{"z": 60.0, "lane": 2, "type": "shovels"}], "start_lane": 1}
	var live: Node3D = SCENE.instantiate()
	add_child(live)
	live.setup(float(leg["chamber_z"]), leg["obstacles"], leg["zip_segments"], leg["archers"], true,
		{"rail_events": leg.get("rail_events", []), "carts_start": leg.get("carts_start", [true, true, true]),
		"start_lane": int(leg.get("start_lane", 1)), "speed": leg.get("speed", {}), "ends_at_cliff": bool(leg.get("ends_at_cliff", false))})
	live.set_physics_process(false)
	var aim: PackedStringArray = str(args["aim"]).split(",")
	var next: int = 0
	var varied: int = 0
	var frames: int = 0
	while next < marks.size() and live.is_running() and frames < 200000:
		RunnerAutopilot.tick(live)
		live.step(1.0 / 60.0)
		frames += 1
		if RunnerView.debug_cam.size() == 2:
			var dz: float = live.get_distance() - _last_d
			RunnerView.debug_cam = [RunnerView.debug_cam[0] + Vector3(0, 0, dz), RunnerView.debug_cam[1] + Vector3(0, 0, dz)]
		_last_d = live.get_distance()
		if frames % 2 == 0:
			get_viewport().warp_mouse(Vector2(float(aim[0]), float(aim[1])))
		# vary=<per-mark overrides>, marks separated by ';', props by '|', applied 6 m BEFORE the mark so
		# per-step state (body yaw, seat) settles:  arm.head_back=0.9|aim.follow=0.2|view.hero_yaw_base=-0.3
		var vr: PackedStringArray = str(args.get("vary", "")).split(";")
		if varied == next and next < vr.size() and live.get_distance() >= marks[next] - 6.0:
			varied = next + 1
			if vr[next] != "":
				var vv: Node = live.get_node("View")
				for kv in vr[next].split("|", false):
					var p: PackedStringArray = kv.split("=")
					var tgts: Array = []
					var prop: String = p[0].get_slice(".", 1)
					if p[0].begins_with("arm."):
						tgts = [vv._arm_rest]
					elif p[0].begins_with("aim."):
						tgts = [vv._aim_mod]
					elif p[0].begins_with("node."):          # node.<Name>.<prop>: any named node under the view
						tgts = [vv.find_child(p[0].get_slice(".", 1), true, false)]
						prop = p[0].get_slice(".", 2)
					elif p[0].begins_with("mat."):           # mat.<prop>: every hero surface material
						for mi in vv._hero_body.find_children("*", "MeshInstance3D", true, false):
							for si in (mi as MeshInstance3D).get_surface_override_material_count():
								if (mi as MeshInstance3D).get_surface_override_material(si):
									tgts.append((mi as MeshInstance3D).get_surface_override_material(si))
					else:
						tgts = [vv]
					for tgt in tgts:
						var cur: Variant = tgt.get(prop)
						var val: Variant = float(p[1]) if typeof(cur) == TYPE_FLOAT else str_to_var(p[1])
						# A value that does not parse (e.g. a 3-component Color(...)) comes back null and would
						# silently zero the property - a black, "transparent" hero that looks like a lighting result.
						if val == null or typeof(val) != typeof(cur):
							push_error("VARY-BAD %s=%s does not parse as %s" % [p[0], p[1], type_string(typeof(cur))])
							get_tree().quit(3)
							return
						tgt.set(prop, val)
				print("VARY d%04d %s" % [int(marks[next]), vr[next]])
		if live.get_distance() >= marks[next]:
			var cl: PackedStringArray = str(args.get("clips", "")).split(",", false)
			if next < cl.size():
				RunnerView.debug_clip = cl[next]
				for _i in 30:
					await get_tree().process_frame
			for _i in 4:
				await get_tree().process_frame
			var img: Image = get_viewport().get_texture().get_image()
			var path: String = ("%s/d%04d.png" % [out, int(marks[next])]) if str(args.get("clips", "")) == "" else ("%s/c%02d_%s.png" % [out, next, RunnerView.debug_clip])
			img.save_png(path)
			print("SHOT ", path, " ", img.get_size())
			var vw: Node = live.get_node("View")
			if str(args.get("eyes", "")) != "" and vw._hero_body:
				await _eyes(vw, out, int(marks[next]))
			if vw._hero_body:
				var pl: AnimationPlayer = vw._rider_anim.player if vw._rider_anim else null
				print("DBG rider.rot=", vw._rider.rotation, " model.rot=", vw._rider_model.rotation, " model.scale=", vw._rider_model.scale, " hero.scale=", vw._hero_body.scale, " anim=", pl.current_animation if pl else "-", " t=", pl.current_animation_position if pl else 0.0, " mood=", vw._rider_anim.current if vw._rider_anim else "-", " rider.y=", vw._rider.position.y, " rim=", vw._cart_rim_y)
			next += 1
		elif frames % 3 == 0:
			await get_tree().process_frame
	print("DONE frames=", frames, " d=", live.get_distance())
	get_tree().quit()

## Skill see-it-yourself: the hero's screen box in the game camera (from the posed skeleton, so it
## follows the pose, plus a margin for the baked pickaxe/revolver), then six orbit views of the SAME
## frame. Game time is frozen while this runs, so every view shows the identical pose.
func _eyes(vw: Node, out: String, d: int) -> void:
	var sk: Skeleton3D = vw._hero_body.find_children("*", "Skeleton3D", true, false)[0]
	var cam: Camera3D = get_viewport().get_camera_3d()
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	var centre := Vector3.ZERO
	for b in sk.get_bone_count():
		var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(b).origin
		centre += p
		var s: Vector2 = cam.unproject_position(p)
		lo = lo.min(s)
		hi = hi.max(s)
	centre /= float(sk.get_bone_count())
	var pad: Vector2 = (hi - lo) * 0.35 + Vector2(12, 12)
	print("EYES box %d %d %d %d" % [int(lo.x - pad.x), int(lo.y - pad.y), int(hi.x + pad.x), int(hi.y + pad.y)])
	# Same frame WITHOUT the hero: the per-pixel difference is his exact screen mask (scripts/eyes-board.py
	# turns it into area / contrast-vs-background / gold-revolver-pixel numbers). His lights stay on.
	vw._hero_body.visible = false
	for _i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/d%04d_nohero.png" % [out, d])
	vw._hero_body.visible = true
	var views := {"back": Vector3(0, 0.9, -3.2), "front": Vector3(0, 0.6, 3.4), "left": Vector3(-3.4, 0.6, 0),
		"right": Vector3(3.4, 0.6, 0), "q_front": Vector3(2.4, 1.2, 2.4), "top": Vector3(0.01, 3.6, -0.6)}
	# A camera of our own: the runner re-seats its camera every frame, so moving that one does nothing.
	var eye := Camera3D.new()
	eye.fov = 40.0
	vw.add_child(eye)
	eye.make_current()
	for v in views:
		eye.global_position = centre + views[v]
		eye.look_at(centre, Vector3.UP if absf(views[v].normalized().y) < 0.95 else Vector3.BACK)
		for _i in 3:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/d%04d_%s.png" % [out, d, v])
	cam.make_current()
	eye.queue_free()
	print("EYES orbit %s/d%04d_*.png" % [out, d])
