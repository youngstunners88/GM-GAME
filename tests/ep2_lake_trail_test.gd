extends Node
## Headless gate for the locked town -> lake trail -> Logan's Lake order, mounted movement, bandit telegraphs,
## damage, UNHORSE, checkpoint retry, and the prebuilt one-frame lake hand-off.
## Run: godot --headless res://tests/ep2_lake_trail_test.tscn

const TRAIL := preload("res://src/episode2/chamber/lake_trail.tscn")
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")

var _failures: int = 0
var _prebuild: Array = []
var _lake_ready: bool = true


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s %s" % [label, detail])


func _step(c: LakeTrailChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


func _make_trail() -> LakeTrailChamber:
	_prebuild = []
	var c: LakeTrailChamber = TRAIL.instantiate() as LakeTrailChamber
	add_child(c)
	c.set_physics_process(false)
	c.prebuild_requested.connect(func(id: String) -> void: _prebuild.append(id))
	c.setup(0, [], 0)
	return c


func _aim_at(c: LakeTrailChamber, point: Vector3) -> void:
	var eye: Vector3 = c.get_camera().global_position
	var d: Vector3 = point - eye
	c._look_yaw = atan2(d.x, d.z)
	c._look_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	c._update_camera(0.0)


func _test_town_hook() -> void:
	print("-- TOWN HOOK")
	var town: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(town)
	town.set_physics_process(false)
	var requests: Array = []
	var results: Array = []
	town.prebuild_requested.connect(func(id: String) -> void: requests.append(id))
	town.chamber_cleared.connect(func(result: Dictionary) -> void: results.append(result))
	town.setup(0, [], 0)
	town._advance_to(town.Beat.GEARED)
	_check("GEARED prebuilds the lake trail, not the lake itself", requests.count("lake_trail") == 1 and not requests.has("logans_lake"), str(requests))
	town._advance_to(town.Beat.DONE)
	_check("DONE hands over to the trail with Dude's horse", results.size() == 1 and str(results[0].get("next_chamber", "")) == "lake_trail"
		and bool(results[0].get("horse", false)), str(results))
	_check("DONE keeps the existing story fields", results.size() == 1 and results[0].has("got_map") and results[0].has("draw_losses")
		and results[0].has("armory_visited") and results[0].has("sniper") and results[0].has("river_gear") and results[0].has("investigation"), str(results))
	_check("the session registers the new room", Ep2SessionRoot.CHAMBER_SCENES.has("lake_trail"))
	town.free()


func _test_riding() -> void:
	print("-- RIDING")
	var c: LakeTrailChamber = _make_trail()
	_check("the trail is 450-600 m and starts mounted with the horse beneath the camera",
		c.get_route_length() >= 450.0 and c.get_route_length() <= 600.0 and c.is_mounted()
		and Vector2(c.get_horse_node().position.x - c.get_player_position().x, c.get_horse_node().position.z - c.get_player_position().z).length() < 0.05
		and c.get_camera().position.y - c.get_horse_node().position.y > 1.5, "%.1f m" % c.get_route_length())
	var start: float = c.get_route_distance()
	c.set_move_input(Vector2(0.0, 1.0))
	_step(c, 2.0)
	var measured: float = (c.get_route_distance() - start) / 2.0
	_check("W pushes the horse toward 7 m/s and travel stays inside 4-7 m/s", measured >= 4.0 and measured <= 7.0 and c.get_route_speed() > 6.9,
		"average %.2f, now %.2f" % [measured, c.get_route_speed()])
	c.set_move_input(Vector2(0.0, -1.0))
	_step(c, 2.0)
	_check("S eases to 4 m/s without stopping the ride", absf(c.get_route_speed() - 4.0) < 0.02 and c.is_riding(), "%.2f" % c.get_route_speed())
	c.set_move_input(Vector2(1.0, 0.0))
	_step(c, 1.2)
	_check("D steers to the right lane edge but never beyond it", absf(c.get_lane_offset() - 2.2) < 0.02, "%.2f" % c.get_lane_offset())
	c.set_move_input(Vector2(-1.0, 0.0))
	_step(c, 2.0)
	_check("A steers back to the opposite edge, still lane-bound", absf(c.get_lane_offset() + 2.2) < 0.02 and absf(c.get_lane_offset()) <= 2.2,
		"%.2f" % c.get_lane_offset())
	c.set_move_input(Vector2.ZERO)
	c.look(Vector2(100000.0, 0.0))
	_check("mouse look is free within a +/-110 degree cone from travel", absf(angle_difference(c._travel_yaw, c.get_look_yaw())) <= 1.91995)
	_check("the armory remains usable from the saddle", c.get_viewmodel() != null and c.shoot())
	_check("the walk clip is speed-matched rather than an invented gallop", c.get_horse_clip() == "horse_walk"
		and (c._horse_anim == null or c._horse_anim.speed_scale > 1.0))
	c.free()


func _test_bandits_and_damage() -> void:
	print("-- BANDIT TELLS, SHOOTING AND HEARTS")
	var c: LakeTrailChamber = _make_trail()
	c.debug_invulnerable = true
	c._place_at_distance(96.0)
	c.set_aim(true)
	var previous_shots: Array = []
	previous_shots.resize(c.get_bandit_count())
	previous_shots.fill(0)
	var tell_seen: bool = false
	var shot_seen: bool = false
	var visual_ok: bool = true
	var timing_ok: bool = true
	var dropped: bool = false
	var shot_a_telegraph: bool = false
	for frame in 60 * 14:
		c.step(1.0 / 60.0)
		for i in c.get_bandit_count():
			if c.is_bandit_telegraphing(i):
				tell_seen = true
				if c.get_bandit_state(i) != "telegraph" or not (c._bandits[i]["glint"] as MeshInstance3D).visible \
						or (c._bandits[i]["folk"] as Ep2TownFolk).pose_name != "draw":
					visual_ok = false
				if not dropped:
					_aim_at(c, c.get_bandit_aim_position(i))
					if c.shoot():
						shot_a_telegraph = true
						dropped = c.get_bandit_state(i) == "dead" and c.get_bandits_down() == 1
			var shots: int = c.get_bandit_shots(i)
			if shots > int(previous_shots[i]):
				shot_seen = true
				if c.get_bandit_last_tell(i) < 0.6:
					timing_ok = false
				previous_shots[i] = shots
	_check("bandits rise, Draw and show a visible gun glint before firing", tell_seen and visual_ok)
	_check("every recorded shot has at least 0.6 s of visible tell (authored tells are 0.85-1.2 s)", shot_seen and timing_ok)
	_check("shooting a telegraphing bandit drops him with fall_dead", shot_a_telegraph and dropped and c.get_bandits_down() == 1)
	_check("a full-health room never heals above three hearts", c.get_health() == 3 and not c._heal_one() and c.get_health() == 3)
	c.debug_invulnerable = false
	c._invuln = 0.0
	c._hurt_player()
	_check("one bandit hit costs exactly one heart", c.get_health() == 2, "%d" % c.get_health())
	c._invuln = 0.0
	c._hurt_player()
	_check("a second separate hit costs one more, never more than the three-heart cap", c.get_health() == 1)
	c.free()


func _test_unhorse_to_shore() -> void:
	print("-- UNHORSE AND ARRIVAL ON FOOT")
	var c: LakeTrailChamber = _make_trail()
	var results: Array = []
	c.chamber_cleared.connect(func(result: Dictionary) -> void: results.append(result))
	for i in 3:
		c._invuln = 0.0
		c._hurt_horse()
	_check("three horse wounds trigger exactly one UNHORSE event, not a game over", c.get_horse_hp() == 0 and not c.is_mounted()
		and c.is_unhorsing() and c.get_unhorse_count() == 1 and not c.is_failing() and not c.is_resolved())
	var lowest_eye: float = 99.0
	for i in 100:
		c.step(1.0 / 60.0)
		lowest_eye = minf(lowest_eye, c.eye_height)
	_check("the stumble drops and rolls the camera without a blackout, then returns to walking eye height",
		lowest_eye < 1.0 and not c.is_unhorsing() and absf(c.eye_height - Ep2Interlude.FPS_EYE_HEIGHT) < 0.02, "lowest %.2f" % lowest_eye)
	c.debug_invulnerable = true
	c.set_move_input(Vector2(0.0, 1.0))
	var seconds: float = 0.0
	while results.is_empty() and seconds < 260.0:
		c.step(1.0 / 30.0)
		seconds += 1.0 / 30.0
	_check("he continues on foot at walking speed and still reaches Logan's Lake", results.size() == 1
		and str(results[0].get("next_chamber", "")) == "logans_lake" and not bool(results[0].get("arrived_mounted", true)), str(results))
	c.free()


func _test_retry() -> void:
	print("-- OUT OF HEARTS: FRESH TRAIL ATTEMPT")
	var c: LakeTrailChamber = _make_trail()
	c._place_at_distance(30.0)
	c._invuln = 0.0
	c._hurt_horse()
	for i in 3:
		c._invuln = 0.0
		c._hurt_player()
	_check("zero hearts ends the attempt like the woods", c.is_failing() and c.get_health() == 0)
	_step(c, 1.1)
	_check("retry starts at the trail start with three hearts and a fresh horse", not c.is_failing() and c.get_attempt() == 1
		and c.get_route_distance() < 0.01 and c.get_health() == 3 and c.get_horse_hp() == 3 and c.is_mounted())
	var living: int = 0
	for i in c.get_bandit_count():
		if c.get_bandit_state(i) != "dead":
			living += 1
	_check("the ambush and the kill count are restored together", living == c.get_bandit_count() and c.get_bandits_down() == 0)
	c.free()


func _test_mounted_arrival_and_prebuild() -> void:
	print("-- MOUNTED ARRIVAL AND PREBUILT LAKE")
	var c: LakeTrailChamber = _make_trail()
	c.debug_invulnerable = true
	var results: Array = []
	c.chamber_cleared.connect(func(result: Dictionary) -> void: results.append(result))
	_lake_ready = false
	c.handoff_ready = func() -> bool: return _lake_ready
	_check("the lake is requested at the start of the ride", _prebuild.size() == 1 and str(_prebuild[0]) == "logans_lake", str(_prebuild))
	c.set_move_input(Vector2(0.0, 1.0))
	var seconds: float = 0.0
	while not c._ending and seconds < 140.0:
		c.step(1.0 / 30.0)
		seconds += 1.0 / 30.0
	_step(c, 3.2)
	_check("the shore waits for the already-requested lake instead of building at the cut", c._ending and results.is_empty()
		and c.is_waiting_for_handoff() and _prebuild.size() == 1)
	_check("a living horse lowers its head to drink (horse_graze)", c.get_horse_clip() == "horse_graze" and c.get_horse_hp() == 3)
	_lake_ready = true
	_step(c, 0.2)
	_check("arrival resolves to logans_lake mounted, with time and bandit count", results.size() == 1
		and str(results[0].get("next_chamber", "")) == "logans_lake" and bool(results[0].get("arrived_mounted", false))
		and typeof(results[0].get("trail_seconds")) == TYPE_FLOAT and float(results[0].get("trail_seconds")) > 1.0
		and typeof(results[0].get("bandits_down")) == TYPE_INT, str(results))
	_check("resolution makes no second prebuild request", _prebuild.size() == 1, str(_prebuild))
	c.free()


func _ready() -> void:
	print("-- EP2 LAKE TRAIL")
	_test_town_hook()
	_test_riding()
	_test_bandits_and_damage()
	_test_unhorse_to_shore()
	_test_retry()
	_test_mounted_arrival_and_prebuild()
	if _failures == 0:
		print("EP2_LAKE_TRAIL: ALL PASS")
	else:
		print("EP2_LAKE_TRAIL: %d FAILURE(S)" % _failures)
	get_tree().quit(_failures)
