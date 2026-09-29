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
	var live: Node3D = SCENE.instantiate()
	add_child(live)
	live.setup(float(leg["chamber_z"]), leg["obstacles"], leg["zip_segments"], leg["archers"], true,
		{"rail_events": leg.get("rail_events", []), "carts_start": leg.get("carts_start", [true, true, true]),
		"start_lane": int(leg.get("start_lane", 1)), "speed": leg.get("speed", {})})
	live.set_physics_process(false)
	var aim: PackedStringArray = str(args["aim"]).split(",")
	var next: int = 0
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
			if vw._hero_body:
				var pl: AnimationPlayer = vw._rider_anim.player if vw._rider_anim else null
				print("DBG rider.rot=", vw._rider.rotation, " model.rot=", vw._rider_model.rotation, " model.scale=", vw._rider_model.scale, " hero.scale=", vw._hero_body.scale, " anim=", pl.current_animation if pl else "-", " t=", pl.current_animation_position if pl else 0.0, " mood=", vw._rider_anim.current if vw._rider_anim else "-", " rider.y=", vw._rider.position.y, " rim=", vw._cart_rim_y)
			next += 1
		elif frames % 3 == 0:
			await get_tree().process_frame
	print("DONE frames=", frames, " d=", live.get_distance())
	get_tree().quit()
