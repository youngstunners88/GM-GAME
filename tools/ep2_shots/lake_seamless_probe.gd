extends Node
## FRAME LOG of the ride from the desert into Logan's Lake (founder 2026-11-07: "the desert stays on screen, the stage pauses, and then
## the scene jumps so the lake is clear"). Rides the REAL session root path: the trail asks for the lake, the root builds it behind at
## its per-frame budget, the trail previews it, the trail hands over, the lake room carries on - one frame per 1/60 s of game time.
## Logs, every 2 m of the way: distance to Logan, frame time, which room is drawn, whether he can move. Flags any frame where he holds
## "forward" and does not move (a pause), any frame over 1/30 s (a gap), and any frame where the view's mean colour or the 64x36 image
## changes by more than a small step (a jump).
##   headless (logic + timings):  godot --headless res://tools/ep2_shots/lake_seamless_probe.tscn -- start=260
##   real render (colour steps):  godot res://tools/ep2_shots/lake_seamless_probe.tscn -- start=260 render=1 out=.farm/lake-seam
const STEP_COLOUR := 0.06          # mean |delta| of the 64x36 image per frame (0..1) above this is a "jump"
var session: Node
var start_back: float = 260.0
var render: bool = false
var out_dir: String = ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() != 2: continue
		match kv[0]:
			"start": start_back = float(kv[1])
			"render": render = kv[1] == "1"
			"out": out_dir = kv[1]
	if out_dir != "": DirAccess.make_dir_recursive_absolute(out_dir)
	get_viewport().size = Vector2i(640, 360) if render else get_viewport().size
	session = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(session)
	session.set_process(false)
	session.armory = Ep2ArmoryState.post_hideout()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	session.add_child(trail)
	session._active = trail
	session._chain_id = "lake_trail"
	session._wire_chamber(trail)
	trail.chamber_cleared.connect(session._on_chamber_cleared, CONNECT_ONE_SHOT)
	trail.setup()
	trail.set_physics_process(false)
	session._mode = session.Mode.CHAMBER
	session._chamber_segment = 0                    # a story segment owns the ride, so its clear chains on to the lake
	trail.debug_invulnerable = true
	trail._place_at_distance(trail._route_total - start_back)
	var lake_xf: Transform3D = trail.lake_transform()
	var logan_world: Vector3 = lake_xf * LogansLakeChamber.LOGAN_MARK
	var prev_world := Vector3.INF
	var prev_small: Image = null
	var prev_full: Image = null
	var swapped_at: int = -1
	var prev_mean := Color.BLACK
	var next_mark: float = INF
	var frames: int = 0
	var stalls: int = 0
	var gaps: int = 0
	var jumps: int = 0
	var swaps: int = 0
	var max_dt: float = 0.0
	var max_step: float = 0.0
	var max_mean: float = 0.0
	var max_move: float = 0.0
	var room_id: String = "lake_trail"
	var lake_seen_logan: int = -1
	print("LAKE_SEAM start=%.0f m before the shore, route %.0f m, render=%s" % [start_back, trail._route_total, render])
	while frames < 60 * 90:
		var c: Node = session._active
		var horse_before: Vector3 = _horse_world(c, lake_xf)
		var horse_yaw_before: float = _horse_yaw(c, lake_xf)
		var t0: int = Time.get_ticks_usec()
		var waiting: bool = c.has_method("is_waiting_for_handoff") and bool(c.call("is_waiting_for_handoff"))
		session._drive_prebuild(session.PREBUILD_MS_WAITING if waiting else session.PREBUILD_MS)
		if c is LakeTrailChamber and session._pb_id == "logans_lake" and session.is_prebuilt("logans_lake"):
			c.preview_lake(session._pb_node)
		var here: Vector3 = _world_pos(c, lake_xf)
		var to_logan: Vector3 = logan_world - here
		if c is LakeTrailChamber:
			c._look_yaw = float(c._route_sample(c.get_route_distance() + 6.0)[1])
		else:
			var local: Vector3 = LogansLakeChamber.LOGAN_MARK - c.get_player_position()
			c._look_yaw = atan2(local.x, local.z)
		c._look_pitch = -0.03
		c.set_move_input(Vector2(0.0, 1.0))
		var ts: int = Time.get_ticks_usec()
		c.step(1.0 / 60.0)
		var step_ms: float = float(Time.get_ticks_usec() - ts) / 1000.0
		var id: String = Ep2WorldRoutes.new().id_of(session._active)
		if id != room_id:
			swaps += 1
			var horse_after: Vector3 = _horse_world(session._active, lake_xf)
			print("  SWAP frame %d: %s -> %s at %.1f m from Logan (hand-over CPU %.1f ms); horse moved %.2f m turned %.1f deg, visible %s" % [frames, room_id, id,
				Vector2(to_logan.x, to_logan.z).length(), step_ms, horse_before.distance_to(horse_after), rad_to_deg(absf(angle_difference(horse_yaw_before, _horse_yaw(session._active, lake_xf)))), session._active.get_horse_node().is_visible_in_tree()])
			room_id = id
			swapped_at = frames
			session._active.set_physics_process(false)    # this log steps the room itself, once per frame
		var dt: float = float(Time.get_ticks_usec() - t0) / 1e6
		var small: Image = null
		var mean := Color.BLACK
		if render:
			await RenderingServer.frame_post_draw
			dt = float(Time.get_ticks_usec() - t0) / 1e6
			var img: Image = get_viewport().get_texture().get_image()
			if swapped_at == frames and out_dir != "" and prev_full != null:
				prev_full.save_png(out_dir + "/swap_a.png")      # the last frame the trail drew
				img.save_png(out_dir + "/swap_b.png")            # the first frame the lake room drew
			if swapped_at >= 0 and frames == swapped_at + 10 and out_dir != "":
				img.save_png(out_dir + "/swap_c.png")            # ten frames on
			prev_full = img
			small = img.duplicate()
			small.resize(64, 36, Image.INTERPOLATE_BILINEAR)
			mean = _mean(small)
		else:
			await get_tree().process_frame
		var now: Vector3 = _world_pos(session._active, lake_xf)
		var moved: float = 0.0 if prev_world == Vector3.INF else Vector2(now.x - prev_world.x, now.z - prev_world.z).length()
		var d_logan: float = Vector2(logan_world.x - now.x, logan_world.z - now.z).length()
		var control: bool = session._active.has_player_control()
		var step_px: float = 0.0
		var step_mean: float = 0.0
		if small != null and prev_small != null:
			step_px = _diff(small, prev_small)
			step_mean = (absf(mean.r - prev_mean.r) + absf(mean.g - prev_mean.g) + absf(mean.b - prev_mean.b)) / 3.0
		var flag: String = ""
		if frames > 30 and moved < 0.01 and d_logan > 3.5:
			stalls += 1
			flag += " STALL"
		if frames > 30 and dt > 1.0 / 30.0:
			gaps += 1
			flag += " GAP"
		if step_px > STEP_COLOUR:
			jumps += 1
			flag += " JUMP"
		if frames > 2:
			max_dt = maxf(max_dt, dt)
			max_step = maxf(max_step, step_px)
			max_mean = maxf(max_mean, step_mean)
			max_move = maxf(max_move, moved)
		if lake_seen_logan < 0 and _logan_visible(session._active):
			lake_seen_logan = int(d_logan)
		if next_mark == INF: next_mark = floorf(d_logan / 2.0) * 2.0
		if d_logan <= next_mark or flag != "":
			print("  %6.1f m  f%04d %-10s dt %5.1f ms  move %.3f  ctl %s  pv %d  clar %.2f  step %.3f mean %.3f%s" % [d_logan, frames, id, dt * 1000.0,
				moved, control, _preview_count(session._active), _clarity(session._active), step_px, step_mean, flag])
			if render and out_dir != "" and (d_logan <= next_mark):
				get_viewport().get_texture().get_image().save_png("%s/d%03d.png" % [out_dir, int(d_logan)])
			while next_mark >= d_logan: next_mark -= 2.0
		prev_world = now
		prev_small = small
		prev_mean = mean
		frames += 1
		if d_logan < 3.0: break
	print("LAKE_SEAM frames=%d swaps=%d stalls=%d gaps=%d jumps=%d max_dt=%.1fms max_px_step=%.3f max_mean_step=%.3f max_move=%.3f logan_visible_from=%d m" %
		[frames, swaps, stalls, gaps, jumps, max_dt * 1000.0, max_step, max_mean, max_move, lake_seen_logan])
	get_tree().quit()


func _world_pos(c: Node, lake_xf: Transform3D) -> Vector3:
	var p: Vector3 = c.get_player_position()
	return lake_xf * p if c is LogansLakeChamber else p


func _horse_world(c: Node, lake_xf: Transform3D) -> Vector3:
	var h: Node3D = c.get_horse_node() if c.has_method("get_horse_node") else null
	if h == null: return Vector3.ZERO
	return lake_xf * h.global_position if c is LogansLakeChamber else h.global_position


func _horse_yaw(c: Node, lake_xf: Transform3D) -> float:
	var h: Node3D = c.get_horse_node() if c.has_method("get_horse_node") else null
	if h == null: return 0.0
	return h.global_rotation.y + (lake_xf.basis.get_euler().y if c is LogansLakeChamber else 0.0)


func _preview_count(c: Node) -> int:
	return c._lake_preview.get_child_count() if c is LakeTrailChamber and c._lake_preview != null else -1


func _clarity(c: Node) -> float:
	if c.has_method("water_clarity"): return float(c.call("water_clarity"))
	return -1.0


func _logan_visible(c: Node) -> bool:
	if c is LakeTrailChamber:
		return c._lake_preview != null and c._lake_preview.has_node("Logan") and c._lake_preview.get_node("Logan").is_visible_in_tree()
	return c is LogansLakeChamber and c._logan != null and c._logan.is_visible_in_tree()


func _mean(img: Image) -> Color:
	var s := Color(0, 0, 0, 0)
	for y in img.get_height():
		for x in img.get_width():
			s += img.get_pixel(x, y)
	var n: float = float(img.get_width() * img.get_height())
	return Color(s.r / n, s.g / n, s.b / n)


func _diff(a: Image, b: Image) -> float:
	var s: float = 0.0
	for y in a.get_height():
		for x in a.get_width():
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			s += (absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)) / 3.0
	return s / float(a.get_width() * a.get_height())
