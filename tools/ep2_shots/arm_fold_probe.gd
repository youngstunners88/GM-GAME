extends Node
## ARM-FOLD PROBE (2026-11-25, PROMPT ..._STOCKPILE_CAD_WHEELBARROW_RIG_STOREFRONT_STATS section 5/8): runs the real town (or the
## auction hall) rendered - Ep2ArmIK only runs with a renderer - and, every frame, measures each MPFB figure's arms:
##   ff   = min distance between the two forearm segments (elbow -> 70% to the wrist) less two radii (< 0 = arm through arm)
##   hh   = hand-to-hand distance (< ~0.1 m with the hands in front of the chest = crossed/folded)
##   cross= a hand past the body's midline onto the other side by > 6 cm (body frame)
##   ft   = min distance from either forearm to the torso segment (hips->neck) less radii (< 0 = forearm inside the chest)
## Prints per figure: min ff, min hh, worst cross, min ft, and the clip that was playing at the worst frame; writes a JSON summary.
##   godot --rendering-driver opengl3 --path . res://tools/ep2_shots/arm_fold_probe.tscn -- out=<dir> [room=town|auction] [secs=20]
const FORE_R := 0.045
const TORSO_R := 0.13
var out := ".farm/arm_fold"
var room := "town"
var secs := 20.0
var figs: Array = []          # [label, Ep2TownFolk]
var stats: Dictionary = {}
var post_ik: Dictionary = {}  # figures measured from their last modifier's modification_processed
var shoot: Array = []         # figure names to photograph close (front, left, right) at the end
var vp: SubViewport
var cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		elif a.begins_with("room="): room = a.substr(5)
		elif a.begins_with("secs="): secs = float(a.substr(5))
		elif a.begins_with("shots="): shoot = Array(a.substr(6).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(640, 360)
	vp = SubViewport.new()                         # a fixed 1280x720 view (a tiling WM resizes the window)
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root: Node
	var stepper: Callable
	if room == "auction":
		var road: AuctionRoadChamber = (load("res://src/episode2/chamber/auction_road.tscn") as PackedScene).instantiate()
		road.handoff = {"road_mounted": true}
		vp.add_child(road)
		road.set_physics_process(false)
		road.bind_armory(Ep2ArmoryState.post_hideout())
		road.setup(0, [], 0)
		road._claim_done = true
		road._spooked = true
		road._player_pos = road.from_house(Vector3(0.4, 0, 9.0))
		for i in 30:
			road.step(1.0 / 30.0)
		root = road
		var swell := [0.0]
		stepper = func(d: float) -> void:
			road._player_pos = road.from_house(Vector3(0.4, 0, 9.0))
			road.step(d)
			swell[0] += d
			if swell[0] > 6.0 and road.house() != null:      # a swell every 6 s: the crowd claps
				road.house()._swell = 1.0
				swell[0] = 0.0
	else:
		var town: GoldTownChamber = (load("res://src/episode2/chamber/gold_town.tscn") as PackedScene).instantiate()
		vp.add_child(town)
		town.set_physics_process(false)
		town.setup(0, [], 0)
		town.set("_player_pos", Vector3(0.0, 0.0, 1405.0))
		root = town
		stepper = func(d: float) -> void: town.step(d)
	await get_tree().process_frame
	await get_tree().process_frame
	for f in root.find_children("*", "Ep2TownFolk", true, false):
		var folk: Ep2TownFolk = f
		var sk: Skeleton3D = _sk(folk)
		if sk == null or _b(sk, "LeftForeArm") < 0 or _b(sk, "RightForeArm") < 0:
			continue
		figs.append([String(folk.name), folk])
		stats[String(folk.name)] = {"ff": INF, "hh": INF, "cross": 0.0, "ft": INF, "worst_clip": "", "frames": 0, "fold_frames": 0}
		# a figure with arm IK (Ep2ArmIK) is measured AFTER its modifiers ran: the bone poses read later in the frame are the clip's again
		var mods: Array = sk.find_children("*", "SkeletonModifier3D", false, false)
		if not mods.is_empty():
			var lbl: String = String(folk.name)
			(mods[mods.size() - 1] as SkeletonModifier3D).modification_processed.connect(func() -> void: _measure(lbl, folk))
			post_ik[lbl] = true
	print("ARM_PROBE figures: ", figs.map(func(r): return r[0]))
	var t := 0.0
	while t < secs:
		stepper.call(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		t += get_process_delta_time()
		for r in figs:
			if not post_ik.has(r[0]):
				_measure(r[0], r[1])
	var lines: Array = []
	for k in stats:
		var s: Dictionary = stats[k]
		var line := "ARM_PROBE %-28s ff %.3f  hh %.3f  cross %.3f  ft %.3f  fold %d/%d  clip@worst %s" % [k, s["ff"], s["hh"], s["cross"], s["ft"],
			s["fold_frames"], s["frames"], s["worst_clip"]]
		print(line)
		lines.append(line)
	if not shoot.is_empty():
		cam = Camera3D.new()
		cam.fov = 50.0
		vp.add_child(cam)
		cam.make_current()
		for r in figs:
			if not shoot.has(r[0]):
				continue
			var f: Ep2TownFolk = r[1]
			var chest: Vector3 = f.global_position + Vector3(0, f.height_m * 0.62, 0)
			var fwd: Vector3 = f.global_transform.basis.z.normalized()
			var side: Vector3 = f.global_transform.basis.x.normalized()
			for v in [["front", fwd], ["left", side], ["right", -side], ["front_left", (fwd + side).normalized()]]:
				stepper.call(1.0 / 60.0)
				cam.global_position = chest + (v[1] as Vector3) * 2.3 + Vector3(0, 0.15, 0)
				cam.look_at(chest, Vector3.UP)
				for i in 3:
					await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_jpg(out.path_join("%s_%s_%s.jpg" % [room, r[0], v[0]]), 0.85)
	var fh := FileAccess.open(out.path_join("arm_probe_%s.json" % room), FileAccess.WRITE)
	fh.store_string(JSON.stringify(stats, "  "))
	print("ARM_PROBE_DONE")
	get_tree().quit()


static func _sk(f: Ep2TownFolk) -> Skeleton3D:
	var sks: Array = f.model.find_children("*", "Skeleton3D", true, false) if f.model != null else []
	return sks[0] as Skeleton3D if not sks.is_empty() else null


static func _b(sk: Skeleton3D, part: String) -> int:
	for i in sk.get_bone_count():
		var n: String = sk.get_bone_name(i)
		if n.ends_with(part) and n.length() - part.length() <= 11:
			return i
	return -1


static func _p(sk: Skeleton3D, i: int) -> Vector3:
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin


static func _seg(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3) -> float:
	var p: PackedVector3Array = Geometry3D.get_closest_points_between_segments(a0, a1, b0, b1)
	return p[0].distance_to(p[1])


func _measure(label: String, f: Ep2TownFolk) -> void:
	if not is_instance_valid(f) or not f.is_visible_in_tree():
		return
	var sk: Skeleton3D = _sk(f)
	var s: Dictionary = stats[label]
	var fl := _p(sk, _b(sk, "LeftForeArm"))
	var hl := _p(sk, _b(sk, "LeftHand"))
	var fr := _p(sk, _b(sk, "RightForeArm"))
	var hr := _p(sk, _b(sk, "RightHand"))
	var sl := _p(sk, _b(sk, "LeftArm"))
	var sr := _p(sk, _b(sk, "RightArm"))
	var hips_i: int = -1
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i).to_lower()
		if n.ends_with("hips") or n.ends_with("pelvis"):
			hips_i = i
			break
	var neck_i: int = _b(sk, "Neck")
	var hips: Vector3 = _p(sk, hips_i) if hips_i >= 0 else f.global_position + Vector3(0, 1.0, 0)
	var neck: Vector3 = _p(sk, neck_i) if neck_i >= 0 else (sl + sr) * 0.5
	var ff: float = _seg(fl, fl.lerp(hl, 0.7), fr, fr.lerp(hr, 0.7)) - FORE_R * 2.0     # elbow -> 70%: palms meeting in a clap is not a fold
	var hh: float = hl.distance_to(hr)
	var ft: float = minf(_seg(fl, hl, hips, neck), _seg(fr, hr, hips, neck)) - FORE_R - TORSO_R
	# midline crossing in the body's own frame: across = the shoulder line, a hand past the middle onto the other side
	var across: Vector3 = (sl - sr)
	across.y = 0.0
	across = across.normalized()
	var mid: Vector3 = (sl + sr) * 0.5
	var cross: float = maxf(-(hl - mid).dot(across), (hr - mid).dot(across))
	s["frames"] += 1
	var fold: bool = ff < 0.0 or cross > 0.06 or (hh < 0.1 and ft < 0.05)
	if fold:
		s["fold_frames"] += 1
	if ff < s["ff"] or cross > s["cross"]:
		s["worst_clip"] = f.current_clip()
	s["ff"] = minf(s["ff"], ff)
	s["hh"] = minf(s["hh"], hh)
	s["cross"] = maxf(s["cross"], cross)
	s["ft"] = minf(s["ft"], ft)
