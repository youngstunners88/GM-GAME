extends Node
## Gate: the ride from the desert into Logan's Lake is ONE continuous world (founder 2026-11-07: "the desert stays on screen, the stage
## pauses, and then the scene jumps so the lake is clear"). Rides the real session-root path frame by frame - the trail asks for the
## lake, the root has built it behind, the trail draws it on the horizon, the trail hands over, the lake room carries on - and asserts
## what the player would see: he never stops while holding forward, the hand-over is one frame with no jump in place or gaze, the water
## clears gradually by his distance to Logan, Logan stands at the water before it is clear, and the water's look is the same material
## on both sides of the hand-over.
## Run: godot --headless res://tests/ep2_lake_seamless_test.tscn
## Real-render frame log (colour steps, frame times): tools/ep2_shots/lake_seamless_probe.tscn

var _failed: int = 0
var _checks: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failed += 1
	print(("  [PASS] " if ok else "  [FAIL] ") + label + ("" if ok else " " + detail))


class Ride:
	var frames: int = 0
	var stalls: int = 0
	var swaps: int = 0
	var swap_frame: int = -1
	var swap_step: float = 0.0
	var swap_yaw_step: float = 0.0
	var max_move: float = 0.0
	var clarity: Array = []
	var clarity_at_swap: float = -1.0
	var clarity_far: float = -1.0
	var logan_clarity: float = -1.0
	var shared_water: bool = false
	var end_room: Node = null


func _ride(session: Node, trail: LakeTrailChamber, back: float, steer_off: bool) -> Ride:
	var r := Ride.new()
	var lake_xf: Transform3D = trail.lake_transform()
	var logan_world: Vector3 = lake_xf * LogansLakeChamber.LOGAN_MARK
	var prev := Vector3.INF
	var prev_yaw: float = INF
	trail._place_at_distance(trail._route_total - back)
	while r.frames < 60 * 80:
		var c: Node = session._active
		var waiting: bool = bool(c.call("is_waiting_for_handoff")) if c.has_method("is_waiting_for_handoff") else false
		session._drive_prebuild(session.PREBUILD_MS_WAITING if waiting else session.PREBUILD_MS)
		if c is LakeTrailChamber and session._pb_id == "logans_lake" and session.is_prebuilt("logans_lake"):
			c.preview_lake(session._pb_node)
		if c is LakeTrailChamber:
			c._look_yaw = float(c._route_sample(c.get_route_distance() + 6.0)[1]) + (0.6 if steer_off else 0.0)
		else:
			var to: Vector3 = LogansLakeChamber.LOGAN_MARK - c.get_player_position()
			c._look_yaw = atan2(to.x, to.z)
		c.set_move_input(Vector2(0.0, 1.0))
		var before: Node = c
		c.step(1.0 / 60.0)
		var now_room: Node = session._active
		var p: Vector3 = now_room.get_player_position()
		var world: Vector3 = lake_xf * p if now_room is LogansLakeChamber else p
		var yaw_world: float = now_room._look_yaw + (lake_xf.basis.get_euler().y if now_room is LogansLakeChamber else 0.0)
		var moved: float = 0.0 if prev == Vector3.INF else Vector2(world.x - prev.x, world.z - prev.z).length()
		var d_logan: float = Vector2(logan_world.x - world.x, logan_world.z - world.z).length()
		if now_room != before:
			r.swaps += 1
			now_room.set_physics_process(false)                # this gate steps the room itself, once per frame
			r.swap_frame = r.frames
			r.swap_step = moved
			r.swap_yaw_step = absf(angle_difference(prev_yaw, yaw_world)) if prev_yaw != INF else 0.0
			var lake: LogansLakeChamber = now_room as LogansLakeChamber
			if lake != null and before is LakeTrailChamber and before._lake_preview != null:
				var copy: MeshInstance3D = before._lake_preview.find_child("StillWater", true, false) as MeshInstance3D
				r.shared_water = copy != null and copy.material_override == lake._landscape.water_material
			r.clarity_at_swap = float(lake._landscape.water_material.get_shader_parameter("clarity")) if lake != null else -1.0
		elif r.frames > 30 and moved < 0.01 and d_logan > 4.0:
			r.stalls += 1
		if r.frames > 2 and now_room == before:
			r.max_move = maxf(r.max_move, moved)
		if now_room is LakeTrailChamber and now_room.has_method("water_clarity"):
			var k: float = float(now_room.call("water_clarity"))
			r.clarity.append(k)
			if r.clarity_far < 0.0: r.clarity_far = k
			if r.logan_clarity < 0.0 and now_room._lake_preview != null and now_room._lake_preview.has_node("Logan"):
				r.logan_clarity = k
		prev = world
		prev_yaw = yaw_world
		r.frames += 1
		await get_tree().process_frame
		if d_logan < 4.0 or (r.swaps > 0 and r.frames - r.swap_frame > 120):
			break
	r.end_room = session._active
	return r


func _make_session() -> Array:
	var session: Node = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
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
	# the lake is requested at the start of the ride; give the background build its whole ride (it is long done by the last 200 m)
	session._drive_prebuild(1.0e9)
	return [session, trail]


func _ready() -> void:
	print("-- EP2 LAKE SEAMLESS (desert -> Logan's Lake)")
	var made: Array = _make_session()
	var session: Node = made[0]
	var trail: LakeTrailChamber = made[1]
	_check("the trail can say how clear the water is (the blend runs by distance to Logan)", trail.has_method("water_clarity"))
	var r: Ride = await _ride(session, trail, 200.0, false)
	print("   frames %d, swaps %d at frame %d, stalls %d, swap step %.3f m, max step %.3f m, clarity far %.2f / at Logan %.2f / at swap %.2f" %
		[r.frames, r.swaps, r.swap_frame, r.stalls, r.swap_step, r.max_move, r.clarity_far, r.logan_clarity, r.clarity_at_swap])
	_check("holding forward from 200 m out to Logan he never stops (no shore pause, no wait on the hand-over)", r.stalls == 0, "stalled frames %d" % r.stalls)
	_check("exactly one hand-over into the lake room", r.swaps == 1 and r.end_room is LogansLakeChamber, "swaps %d" % r.swaps)
	_check("the hand-over frame moves him one ordinary stride, no jump in place (< 0.2 m)", r.swap_step > 0.005 and r.swap_step < 0.2, "%.3f m" % r.swap_step)
	_check("the hand-over keeps his gaze (< 2 degrees)", r.swap_yaw_step < deg_to_rad(2.0), "%.2f deg" % rad_to_deg(r.swap_yaw_step))
	var mono: bool = r.clarity.size() > 10
	var max_d: float = 0.0
	for i in range(1, r.clarity.size()):
		var d: float = float(r.clarity[i]) - float(r.clarity[i - 1])
		max_d = maxf(max_d, absf(d))
		if d < -1e-5: mono = false
	_check("the water clears gradually and never clouds again on the way in", mono, str(r.clarity.slice(0, 4)))
	_check("no single frame clears it by more than a small step (<= 0.01)", max_d <= 0.01, "max %.4f" % max_d)
	_check("far out the water is still dusty (clarity <= 0.35 at 200 m)", r.clarity_far >= 0.0 and r.clarity_far <= 0.35, "%.2f" % r.clarity_far)
	_check("Logan stands at the water on the horizon before it has cleared", r.logan_clarity >= 0.0 and r.logan_clarity < 0.6, "%.2f" % r.logan_clarity)
	_check("it is fully clear in the frame of the hand-over, so the lake room draws it the same", absf(r.clarity_at_swap - 1.0) < 0.001, "%.3f" % r.clarity_at_swap)
	_check("the horizon water and the lake room's water are one material (nothing swaps its look)", r.shared_water)
	var lake: LogansLakeChamber = r.end_room as LogansLakeChamber
	if lake != null:
		_check("he keeps walking straight on at the shore and the horse goes on to the water itself", lake.has_player_control() and lake.get_horse_state() in ["lead", "drink"],
			lake.get_horse_state())
		_check("on foot at the shore (the dismount happened on the move)", absf(lake.eye_height - Ep2Interlude.FPS_EYE_HEIGHT) < 0.01, "%.2f" % lake.eye_height)
	print("EP2_LAKE_SEAMLESS: %d checks, %d failed" % [_checks, _failed])
	get_tree().quit(_failed)
