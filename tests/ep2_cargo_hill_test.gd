extends Node
## CARGO CHECK -> HILL -> RIDGE IN ONE MOTION (founder 2026-11-07: "no pause climbing the hill from the cargo check"). The real session
## plays Logan's Lake: he meets Logan, hears him out, checks the staged cargo with [E], then only HOLDS FORWARD (steering like a player,
## never faster than a thumb turns). Every frame of the walk logs its cost, whether he is in control, whether he moved, and how far the
## camera jumped (lake frames are put in the ridge's axes with LAKE_OFFSET, so the swap to the ridge is measured as one world). A line
## every 2 m. Fails on any frame he is held while pushing forward, any camera jump or turn he did not make, or a frame that builds the
## ridge while he walks.
## Run: godot --headless res://tests/ep2_cargo_hill_test.tscn
const DT := 1.0 / 60.0
const MAX_STALL := 2                 # frames in a row with forward held and no progress (a 2-frame wobble at a clamp is not a stop)
const MAX_CAM_STEP := 0.1            # m per frame: walking is 0.057 m, a step up the ridge a little more
const MAX_CAM_TURN := 0.02           # rad per frame of camera rotation the player did not ask for
const MAX_FRAME_MS := 60.0           # one headless frame of the walk: a ridge build step costs 100-600 ms
const STEER_RATE := 0.03             # rad per frame the test's thumb turns
var failures := 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _gaze(yaw: float, pitch: float) -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## One frame as the session root runs it: the room, then the background build (ep2_session_root.gd `_process`).
func _frame(root: Ep2SessionRoot, c: Ep2Interlude) -> float:
	var t0 := Time.get_ticks_usec()
	c.step(DT)
	var a: Node = root.get_active()
	var waiting: bool = a.has_method("is_waiting_for_handoff") and bool(a.call("is_waiting_for_handoff"))
	if root._pb_settle > 0.0 and not waiting:
		root._pb_settle -= DT
	else:
		root._drive_prebuild(Ep2SessionRoot.PREBUILD_MS_WAITING if waiting else Ep2SessionRoot.PREBUILD_MS)
	return float(Time.get_ticks_usec() - t0) / 1000.0


func _ready() -> void:
	await get_tree().process_frame
	var root: Ep2SessionRoot = load("res://src/episode2/session/ep2_session_root.tscn").instantiate()
	add_child(root)
	root.set_process(false)                         # the test is the frame clock (as seamless_chain_test)
	var st := Ep2ArmoryState.post_hideout()
	st.river_gear = true
	st.sniper_owned = true
	st.sniper_rounds = 40
	root.armory = st
	var lake: LogansLakeChamber = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	root.add_child(lake)
	root._active = lake
	root._mode = Ep2SessionRoot.Mode.CHAMBER
	root._chain_id = "logans_lake"
	root._chamber_segment = 0
	root._wire_chamber(lake)
	lake.setup(0, [], 0)
	lake.set_physics_process(false)
	lake.chamber_cleared.connect(root._on_chamber_cleared, CONNECT_ONE_SHOT)
	for i in 30:
		_frame(root, lake)
	# Logan, his lines, the cargo: the real beats (the ridge is asked for when he starts talking)
	lake._player_pos = LogansLakeChamber.LOGAN_MARK + Vector3(-1.5, 0, 0)
	check("he meets Logan", lake.start_rig() and lake.get_beat() == LogansLakeChamber.Beat.INVESTIGATE)
	var talk_worst := 0.0
	for i in 60 * 40:
		talk_worst = maxf(talk_worst, _frame(root, lake))
		if lake.get_beat() == LogansLakeChamber.Beat.STAGE:
			break
	print("  while Logan talks: worst frame %.1f ms (the ridge's background build), built=%s" % [talk_worst, root.is_prebuilt("river_cover")])
	check("the ridge is built behind the lake before the cargo is checked", root.is_prebuilt("river_cover"))
	lake._player_pos = LogansLakeChamber.STAGING_MARK + Vector3(-1.5, 0, 0)
	_frame(root, lake)
	check("[E] at the staged cargo checks it", lake.start_rig() and lake.staging_complete())
	var ridge: RiverCoverChamber = null
	var last_cam := Transform3D()
	var have_cam := false
	var last_gaze := Vector3.ZERO
	var stall := 0
	var worst_stall := 0
	var worst_step := 0.0
	var worst_step_f := -1
	var worst_turn := 0.0
	var worst_ms := 0.0
	var lost_control := 0
	var swap_frame := -1
	var walked := 0.0
	var next_log := 0.0
	for f in 60 * 60:
		var ch: Ep2Interlude = root.get_active() as Ep2Interlude
		if ch is RiverCoverChamber and ridge == null:
			ridge = ch
			ridge.set_physics_process(false)
		var p: Vector3 = ch.get_player_position()
		var at: Vector3 = p if ridge != null else p + RiverCoverChamber.LAKE_OFFSET
		# steer like a thumb: up the lake's shore path hugging its right bank (the widest he can stray from the ridge line), then along
		# the ridge path ahead
		var goal: Vector3 = Vector3(-4.0, 0, 70) if ridge == null else (ridge.ridge_nearest(p)[0] as Vector3) + Vector3(0, 0, 6)
		var want: float = atan2(goal.x - p.x, goal.z - p.z)
		ch._look_yaw = ch._look_yaw + clampf(wrapf(want - ch._look_yaw, -PI, PI), -STEER_RATE, STEER_RATE)
		ch.set_move_input(Vector2(0, 1))
		var asked: Vector3 = _gaze(ch._look_yaw, ch._look_pitch)
		var in_control: bool = ch.has_player_control()
		var ms: float = _frame(root, ch)
		var now: Ep2Interlude = root.get_active() as Ep2Interlude
		if now != ch:
			swap_frame = f
		var xf: Transform3D = now.get_camera().global_transform
		if not (now is RiverCoverChamber):
			xf.origin += RiverCoverChamber.LAKE_OFFSET
		var p2: Vector3 = now.get_player_position()
		var at2: Vector3 = p2 if now is RiverCoverChamber else p2 + RiverCoverChamber.LAKE_OFFSET
		var moved: float = Vector2(at2.x - at.x, at2.z - at.z).length()
		walked += moved
		if not in_control:
			lost_control += 1
		stall = stall + 1 if moved < 0.005 else 0
		worst_stall = maxi(worst_stall, stall)
		worst_ms = maxf(worst_ms, ms)
		var gaze: Vector3 = _gaze(now._look_yaw, now._look_pitch)
		if have_cam:
			var step_m: float = xf.origin.distance_to(last_cam.origin)
			# the turn nobody asked for: the room's gaze against the one the thumb set, plus the camera's turn beyond the gaze's turn
			var forced: float = asked.angle_to(gaze)
			var cam_turn: float = (-last_cam.basis.z).angle_to(-xf.basis.z)
			var turn: float = maxf(forced, cam_turn - last_gaze.angle_to(gaze))
			if step_m > worst_step:
				worst_step = step_m
				worst_step_f = f
			worst_turn = maxf(worst_turn, turn)
			if step_m > MAX_CAM_STEP or turn > MAX_CAM_TURN or ms > MAX_FRAME_MS or stall == MAX_STALL + 1:
				print("    JUMP f=%d %s step=%.3f m turn=%.3f rad frame=%.1f ms stall=%d" % [f, now.name, step_m, turn, ms, stall])
		last_cam = xf
		last_gaze = gaze
		have_cam = true
		if walked >= next_log:
			print("    walk %5.1f m  f=%4d %-11s frame=%6.2f ms control=%s eye=(%.2f, %.2f, %.2f)" % [walked, f, now.name, ms, in_control,
				xf.origin.x, xf.origin.y, xf.origin.z])
			next_log += 2.0
		if ridge != null and ridge.ridge_s(p2) > ridge.ridge_s(RiverCoverChamber.SPAWN) + 30.0:
			break
	print("  swap at frame %d, walked %.1f m. worst: stall %d frames, camera step %.3f m (frame %d), unasked turn %.3f rad, frame %.1f ms, %d frames without control" % [
		swap_frame, walked, worst_stall, worst_step, worst_step_f, worst_turn, worst_ms, lost_control])
	check("the lake hands on to the ridge while he walks (no stop at the top of the shore path)", ridge != null)
	check("he never stops while holding forward (longest stall %d frames)" % worst_stall, worst_stall <= MAX_STALL)
	check("he never loses control from the cargo to the ridge", lost_control == 0, "%d frames" % lost_control)
	check("no camera jump at the hill or the swap (worst %.3f m)" % worst_step, worst_step <= MAX_CAM_STEP)
	check("no turn he did not make (worst %.3f rad)" % worst_turn, worst_turn <= MAX_CAM_TURN)
	check("no frame of the walk builds anything (worst %.1f ms)" % worst_ms, worst_ms <= MAX_FRAME_MS)
	check("he walks on up the ridge 30 m past its foot", ridge != null and ridge.ridge_s(ridge.get_player_position()) > ridge.ridge_s(RiverCoverChamber.SPAWN) + 30.0)
	print("CARGO_HILL: %s (%d failures)" % ["ALL PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)
