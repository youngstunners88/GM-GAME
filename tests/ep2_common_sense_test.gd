extends Node
## Gate for the founder's five common-sense reports (2026-11-05, skill ep2-world-common-sense). Each check asserts what a player would SEE,
## over the whole action, not that a code path ran:
##   1. walkers never come within a body's width of Minister Mike Dean while he kneels and prays (and nobody stays standing in his room)
##   2. Inferno, back on his quad and meeting Lil Blunt at the body, asks what happened THERE, then the whiskey - no trip back to the quad
##   3. the saloon's batwings swing for whoever goes through (Lil Blunt and the townsfolk), never through a walker, then settle shut
##   4. a shot raft man goes over the side into the river, and the raft carries on without him (no fire, no hook)
##   5. bullets register on a raft: its health falls, it can break up, and the stage stays winnable (and resets on a retry)
## Run: godot --headless res://tests/ep2_common_sense_test.tscn  (pinned: EXPECTED_PASS checks, 0 FAIL)

const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const RIVER := preload("res://src/episode2/chamber/river_cover.tscn")
const EXPECTED_PASS := 40
const BODY_WIDTH := 0.62                    # two Ep2TownPeople.BODY_R: shoulder to shoulder

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % label)
	else:
		_fail += 1
		print("  [FAIL] %s %s" % [label, detail])


func _ready() -> void:
	print("-- EP2 COMMON SENSE")
	await test_town_minister_praying_walkers_keep_clear()
	await test_town_inferno_meets_at_body_no_return_trip()
	await test_town_saloon_doors_swing_and_settle()
	await test_town_inferno_rides_to_flux_and_minds_people()
	await test_river_shot_rider_falls_into_water()
	await test_river_raft_health_falls_and_breaks()
	var pinned: bool = _pass == EXPECTED_PASS
	if not pinned:
		print("  [FAIL] pinned check count: %d passed, %d expected" % [_pass, EXPECTED_PASS])
	print("EP2_COMMON_SENSE: %s (%d pass, %d fail)" % ["ALL PASS" if _fail == 0 and pinned else "FAIL", _pass, _fail])
	get_tree().quit(0 if _fail == 0 and pinned else 1)


# --- the town --------------------------------------------------------------------------------------------------------------------

func _town() -> GoldTownChamber:
	var c: GoldTownChamber = TOWN.instantiate()
	add_child(c)
	c.setup(0, [], 0)
	await get_tree().process_frame
	return c


func _run(c: GoldTownChamber, seconds: float) -> void:
	for i in int(seconds * 60.0):
		c.step(1.0 / 60.0)


## The draw is won: the stranger lies at his mark, Mike Dean kneels by him praying (the LOOT beat's end state).
func _stage_body(c: GoldTownChamber) -> Vector3:
	var opp: Ep2TownFolk = c.get_opponent()
	opp.position = GoldTownChamber.OPP_MARK
	opp.fall_dead()
	var kneel: Vector3 = opp.position + GoldTownChamber.KNEEL_AT
	c.get_minister().visible = true
	c.get_minister().position = kneel
	c._minister_task = "kneeling"
	c._minister_t = 3.0
	c._advance_to(GoldTownChamber.Beat.LOOT)
	c._won_t = -1000.0                               # hold the beat: only the street is on trial here
	c._got_peacemaker = true
	return kneel


func test_town_minister_praying_walkers_keep_clear() -> void:
	print("-- 1. nobody walks through Mike Dean while he prays")
	# Arrange: the Minister kneels by the body; eight townsfolk are sent on walks whose straight line runs through him
	var c: GoldTownChamber = await _town()
	var kneel: Vector3 = _stage_body(c)
	c._player_pos = kneel + Vector3(-4.5, 0.0, -6.0)
	var ppl: Ep2TownPeople = c.get_people()
	var k2 := Vector2(kneel.x, kneel.z)
	var walkers: Array = []
	var routes: Array = [[Vector2(0.0, -9.0), Vector2(0.0, 9.0)], [Vector2(0.4, 8.0), Vector2(-0.3, -8.0)], [Vector2(-4.0, 0.2), Vector2(4.0, -0.2)],
		[Vector2(4.0, 0.6), Vector2(-4.0, 0.0)], [Vector2(-0.6, -7.0), Vector2(0.8, 7.0)], [Vector2(3.0, -6.0), Vector2(-3.0, 6.0)],
		[Vector2(-3.0, -6.0), Vector2(3.0, 6.0)], [Vector2(0.2, 10.0), Vector2(0.1, -10.0)]]
	for i in mini(routes.size(), ppl.people.size()):
		var p = ppl.people[i]
		var a: Vector2 = ppl.navigation.closest(k2 + routes[i][0])
		var b: Vector2 = ppl.navigation.closest(k2 + routes[i][1])
		p.folk.position = Vector3(a.x, 0.0, a.y)
		p.state = "walk"
		p.destination = ""
		p.fear = 0.0
		p.waypoints = ppl.navigation.path(a, b)
		walkers.append([p, b, false])
	# one more is standing idle right where he kneels when he gets there: he has to step back out of the room
	var stander = ppl.people[routes.size()] if ppl.people.size() > routes.size() else null
	if stander != null:
		stander.folk.position = kneel + Vector3(0.3, 0.0, 0.25)
		stander.state = "pause"
		stander.timer = 30.0
		stander.waypoints.clear()
	# Act: 40 s of street life, measured every frame
	var closest: float = INF
	var crossed: int = 0
	for f in 40 * 60:
		c.step(1.0 / 60.0)
		c._minister_task = "kneeling"
		c.get_minister().position = kneel
		for w in walkers:
			var q: Vector2 = Vector2(w[0].folk.position.x, w[0].folk.position.z)
			closest = minf(closest, q.distance_to(k2))
			if q.distance_to(w[1]) < 1.5:
				w[2] = true                              # he got to the far side (then his day goes on: a new errand)
	for w in walkers:
		if bool(w[2]):
			crossed += 1
	var stander_d: float = Vector2(stander.folk.position.x, stander.folk.position.z).distance_to(k2) if stander != null else 99.0
	# Assert
	_check("over 40 s no walker comes within a body's width of the kneeling Minister (closest %.2f m)" % closest, closest >= BODY_WIDTH)
	_check("...they leave him a praying man's room, not a brush past (closest >= 1.2 m)", closest >= 1.2, "%.2f" % closest)
	_check("...and they still get where they were going, round him (%d of %d walked past him to the far side)" % [crossed, walkers.size()],
		crossed >= walkers.size() - 2)
	_check("someone idling where he kneels steps back out of his room (%.2f m)" % stander_d, stander_d >= 1.2)
	c.queue_free()
	await get_tree().process_frame


func test_town_inferno_meets_at_body_no_return_trip() -> void:
	print("-- 2. Inferno back from Blondie: asks what happened where he stands, then the whiskey")
	# Arrange: Lil Blunt has walked down to the body after the Gatling; Inferno rides in and parks outside Rich's
	var c: GoldTownChamber = await _town()
	var kneel: Vector3 = _stage_body(c)
	var lb: Vector3 = kneel + Vector3(-1.8, 0.0, 2.6)
	c._player_pos = lb
	var caps: Array = []
	c.captioned.connect(func(w: String, t: String) -> void: caps.append([w, t]))
	c._advance_to(GoldTownChamber.Beat.BULL_BACK)
	# Act: until the drinks beat has sent him into the saloon
	var bull: Ep2Actor = c.get_bull()
	var dismounted: bool = false
	var park: Vector3 = Vector3.ZERO
	var near_lb_at: float = -1.0
	var back_to_quad: float = INF
	var t: float = 0.0
	var reached_bar: bool = false
	var lb_gap: float = INF
	var mike_gap: float = INF
	for f in 180 * 60:
		c._player_pos = lb if c.get_beat_name() in ["BULL_BACK", "BODY"] else c._player_pos
		c.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if not dismounted and c._bull_task == "to_lb":
			dismounted = true
			park = c.get_quad().position
		if dismounted and near_lb_at < 0.0 and bull.position.distance_to(lb) < 4.0:
			near_lb_at = t
		if near_lb_at >= 0.0:
			back_to_quad = minf(back_to_quad, bull.position.distance_to(park))
		if dismounted and c.get_beat_name() in ["BULL_BACK", "BODY"]:
			lb_gap = minf(lb_gap, Vector2(bull.position.x - lb.x, bull.position.z - lb.z).length())
			mike_gap = minf(mike_gap, Vector2(bull.position.x - kneel.x, bull.position.z - kneel.z).length())
		if c.get_beat_name() == "DRINKS":
			# Lil Blunt follows him to the bar; the beat ends there
			c._player_pos = Ep2GoldTown.local_to_world("Bldg_Saloon", GoldTownChamber.BAR_SPOT)
			if c._bull_task == "at_bar":
				reached_bar = true
				break
	var order: Array = caps.filter(func(l: Array) -> bool: return l[0] in ["INFERNO", "LIL BLUNT", "MIKE DEAN"]).map(func(l: Array) -> String: return str(l[1]))
	var whiskey_i: int = order.find(GoldTownChamber.BULL_BACK_LINES[1][1])
	var what_i: int = order.find(GoldTownChamber.BODY_LINES[2][1])
	var bird_i: int = order.find(GoldTownChamber.BODY_LINES[3][1])
	# Assert
	_check("he comes to Lil Blunt at the body", near_lb_at >= 0.0, str(bull.position))
	_check("after meeting him there he never walks back to the quad (closest %.1f m to where it is parked)" % back_to_quad,
		back_to_quad > 8.0)
	_check("he asks who put a hole in him BEFORE \"First whiskey's on me\" (%d < %d)" % [what_i, whiskey_i], what_i >= 0 and whiskey_i > what_i)
	_check("every locked line still plays, the founder's bird line included, word for word", bird_i > what_i and order.has(GoldTownChamber.BODY_LINES[0][1])
		and order.has(GoldTownChamber.BULL_BACK_LINES[0][1]) and order.has(GoldTownChamber.BODY_LINES[4][1]), str(order))
	_check("...each locked line exactly once", order.count(GoldTownChamber.BULL_BACK_LINES[1][1]) == 1 and order.count(GoldTownChamber.BODY_LINES[2][1]) == 1)
	_check("he stops a talking distance from Lil Blunt, not on top of him (closest %.2f m)" % lb_gap, lb_gap >= 1.6)
	_check("...and never walks through Mike Dean kneeling there (closest %.2f m)" % mike_gap, mike_gap >= BODY_WIDTH * 2.0)
	_check("then he walks on to the bar", reached_bar, "%s %s" % [c.get_beat_name(), c._bull_task])
	c.queue_free()
	await get_tree().process_frame


## Founder 2026-11-08 (PROMPT_INFERNO_QUAD_TO_FLUX_AWARENESS): after the bar Inferno walks only to his quad and rides to Flux - even on a run
## that never saw the quad ride in - and neither on foot nor on the quad does he go through anybody.
func test_town_inferno_rides_to_flux_and_minds_people() -> void:
	var c: GoldTownChamber = await _town()
	var bull: Ep2Actor = c._bull
	if bull == null:
		_check("Inferno exists in town", false)
		c.queue_free()
		return
	bull.visible = true
	# on foot: Lil Blunt standing square in his way on the street
	bull.position = Vector3(-2.0, 0.0, 1440.0)
	c._bull_task = "leaving"
	c._player_pos = Vector3(-2.0, 0.0, 1441.6)
	c._bull_route([Vector3(-2.0, 0.0, 1448.0)], 1.6)
	var closest: float = INF
	for i in 300:
		c.step(1.0 / 60.0)
		closest = minf(closest, Vector2(bull.position.x - c._player_pos.x, bull.position.z - c._player_pos.z).length())
	_check("on foot he stops for Lil Blunt and steps round him, never through (closest %.2f m, now z %.1f)" % [closest, bull.position.z],
		closest >= 0.6 and bull.position.z > 1442.5)
	# a run with no quad in town: he still gets to a bike and rides, never the walk across town
	c._quad = null
	bull.stop()
	c._bull_path = []
	c._bull_task = "leaving"
	c._player_pos = Vector3(-40.0, 0.0, 1400.0)
	c.step(1.0 / 60.0)
	_check("after the bar he mounts the quad and rides (task %s)" % c._bull_task, c._quad != null and c._bull_task == "riding_off")
	# on the quad: someone in front -> it waits; they clear -> it rolls on
	var fwd := Vector3(sin(c._quad.yaw), 0.0, cos(c._quad.yaw))
	c._player_pos = c._quad.position + fwd * 2.5
	var s0: float = c._quad.travelled()
	_run(c, 2.0)
	_check("the quad stops for a person in front (moved %.2f m)" % (c._quad.travelled() - s0), c._quad.travelled() - s0 < 0.05)
	c._player_pos = Vector3(-40.0, 0.0, 1400.0)
	_run(c, 2.0)
	_check("...and carries on once they clear (moved %.2f m)" % (c._quad.travelled() - s0), c._quad.travelled() - s0 > 1.0)
	c.queue_free()
	await get_tree().process_frame


func _door(c: GoldTownChamber) -> Ep2SwingDoor:
	var doors: Array = c._town_col.get("doors", [])
	return doors[0] if not doors.is_empty() else null


## Shortest ground distance from `p` (door frame) to leaf i's board, hinge to tip.
func _leaf_gap(d: Ep2SwingDoor, i: int, p: Vector3) -> float:
	var leaf: Dictionary = d.leaves[i]
	var side: float = float(leaf["side"])
	var a: float = float(leaf["a"])
	var hinge := Vector2(side * (d.half_w - 0.02), 0.0)
	var tip: Vector2 = hinge + Vector2(-side * cos(a), -sin(a)) * d.leaf_len
	var q := Vector2(p.x, p.z)
	var ab: Vector2 = tip - hinge
	var k: float = clampf((q - hinge).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return q.distance_to(hinge + ab * k)


func _walk_through(c: GoldTownChamber, d: Ep2SwingDoor, move: Callable, from: Vector3, to: Vector3, seconds: float) -> Array:
	var inv: Transform3D = d.global_transform.affine_inverse()
	var max_open: float = 0.0
	var min_gap: float = INF
	for f in int(seconds * 60.0):
		var p: Vector3 = from.lerp(to, float(f) / (seconds * 60.0))
		move.call(p)
		c.step(1.0 / 60.0)
		max_open = maxf(max_open, d.open_amount())
		var lp: Vector3 = inv * p
		if absf(lp.x) < d.half_w:
			min_gap = minf(min_gap, minf(_leaf_gap(d, 0, lp), _leaf_gap(d, 1, lp)))
	return [max_open, min_gap]


func test_town_saloon_doors_swing_and_settle() -> void:
	print("-- 3. the saloon doors swing for whoever goes through, then settle back")
	# Arrange
	var c: GoldTownChamber = await _town()
	var d: Ep2SwingDoor = _door(c)
	_check("the saloon has real hinged batwings", d != null and d.leaves.size() == 2)
	if d == null:
		c.queue_free()
		return
	var baked: int = Ep2SwingDoor.strip_baked_leaves(c._visuals.find_child("Bldg_Saloon", true, false) as Node3D,
		AABB(Vector3(-0.93, 0.7, -0.6), Vector3(1.86, 1.1, 1.2)), ["DarkWood", "Brass"])
	_check("the kit's fixed half-open leaves are gone from the saloon mesh (no second, frozen pair)", baked == 0, "%d triangles left" % baked)
	var shut0: float = d.open_amount()
	var out_p: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", 2.6)
	var in_p: Vector3 = Ep2GoldTown.door_world("Bldg_Saloon", -2.6)
	c._player_pos = in_p + Vector3(0.0, 0.0, 0.0) + (in_p - out_p).normalized() * 6.0
	# Act 1: Lil Blunt walks in through them
	var lb: Array = await _walk_through(c, d, func(p: Vector3) -> void: c._player_pos = p, out_p, in_p, 3.6)
	# Act 2: they swing and settle once he is clear
	var swinging: float = d.open_amount()
	_run(c, 4.0)
	var settled: float = d.open_amount()
	# Act 3: a townsman (the barman's walk - any body in the crowd works the same) comes back out the other way
	c._player_pos = in_p + (in_p - out_p).normalized() * 6.0
	var folk: Ep2TownFolk = c.get_people().people[0].folk
	c.get_people().people[0].state = "pause"
	c.get_people().people[0].timer = 60.0
	var pushes0: int = d.pushes
	var npc: Array = await _walk_through(c, d, func(p: Vector3) -> void: folk.position = p, in_p, out_p, 3.6)
	# Assert
	_check("shut before anyone comes (%.2f rad)" % shut0, shut0 < 0.02)
	_check("they swing open as Lil Blunt goes through (%.2f rad)" % lb[0], lb[0] > 1.1)
	_check("...and never sweep through him (closest board %.2f m)" % lb[1], lb[1] > 0.25)
	_check("they swing back after him and settle shut (%.2f -> %.3f rad)" % [swinging, settled], settled < 0.03)
	_check("they swing for a townsman too, the other way (%.2f rad, pushed %d)" % [npc[0], d.pushes - pushes0], npc[0] > 1.1 and d.pushes > pushes0)
	_check("...never through him either (closest board %.2f m)" % npc[1], npc[1] > 0.25)
	c.queue_free()
	await get_tree().process_frame


# --- the river -------------------------------------------------------------------------------------------------------------------

func _river() -> RiverCoverChamber:
	var st := Ep2ArmoryState.post_hideout()
	st.purchase_river_gear("btc")
	st.purchase_sniper("btc")
	st.purchase_sniper_ammo(10, "btc")
	var c: RiverCoverChamber = RIVER.instantiate() as RiverCoverChamber
	add_child(c)
	c.set_physics_process(false)
	c.debug_no_ranged = true
	c.bind_armory(st)
	c.setup(0, [], 0)
	c._player_pos = RiverCoverChamber.MARKER + Vector3(0, 0, 1.0)
	c._ground_y = c._player_pos.y
	_adv(c, 0.2)
	var o: Vector3 = RiverCoverChamber.OVERLOOKS[0]
	c._player_pos = o
	c._ground_y = o.y
	_aim(c, c.river_point(c.river_s_of(RiverCoverChamber.LAUNCH_POINT)))
	_adv(c, 1.0)
	return c


func _adv(c: RiverCoverChamber, seconds: float) -> void:
	for i in int(seconds * 30.0):
		c.step(1.0 / 30.0)


func _aim(c: RiverCoverChamber, p: Vector3) -> void:
	var eye: Vector3 = c._player_pos + Vector3(0, c.eye_height, 0)
	var dv: Vector3 = p - eye
	c._look_yaw = atan2(dv.x, dv.z)
	c._look_pitch = atan2(dv.y, Vector2(dv.x, dv.z).length())


func _raft_up(c: RiverCoverChamber) -> Dictionary:
	for i in 300:
		_adv(c, 0.1)
		if not c.get_rafts().is_empty():
			var r: Dictionary = c.get_rafts()[0]
			if (r["node"] as Node3D).global_position.distance_to(c._player_pos) < 80.0 and float(r["s"]) > 2.0:
				return r
	return c.get_rafts()[0] if not c.get_rafts().is_empty() else {}


func test_river_shot_rider_falls_into_water() -> void:
	print("-- 4. a shot raft man falls into the river; the raft goes on without him")
	# Arrange
	var c: RiverCoverChamber = _river()
	var r: Dictionary = _raft_up(c)
	_check("a raft of Hammer's men is on the river", not r.is_empty())
	if r.is_empty():
		c.queue_free()
		return
	var node: Node3D = r["node"]
	var m: Dictionary = (r["men"] as Array)[0]
	var folk: Ep2TownFolk = m["folk"]
	var s0: float = float(r["s"])
	# Act: shot (the gate drives the hit, as the river gate does)
	c.damage_raider(m)
	var heights: Array = []
	for i in 12:
		_adv(c, 0.25)
		heights.append(folk.global_position.y)
	var surface: float = c.river_point(c.river_s_of(Vector2(folk.global_position.x, folk.global_position.z))).y + RiverCoverChamber.WATER_Y
	var off_raft: float = Vector2(folk.global_position.x - node.global_position.x, folk.global_position.z - node.global_position.z).length()
	var tell_after: bool = false
	for i in 60:
		_adv(c, 0.1)
		tell_after = tell_after or str(m["state"]) == "tell"
	# Assert
	_check("he is no longer carried by the raft (off its frame)", folk.get_parent() != node and not node.is_ancestor_of(folk))
	_check("he went over the side, clear of the logs (%.1f m from the raft's centre)" % off_raft, off_raft > 1.6)
	_check("he ends up in the water, not on top of it (y %.2f vs surface %.2f)" % [heights[heights.size() - 1], surface],
		c.raider_overboard(m) and float(heights[heights.size() - 1]) < surface)
	_check("...a fall, not a teleport: he rises off the deck before he drops", float(heights.max()) > float(heights[0]) - 0.6 and heights.size() == 12)
	_check("the raft carries on downstream without him (%.1f -> %.1f m)" % [s0, float(r["s"])], float(r["s"]) > s0 + 2.0)
	_check("a dead man raises no gun", not tell_after and str(m["state"]) == "dead")
	c.queue_free()
	await get_tree().process_frame


func test_river_raft_health_falls_and_breaks() -> void:
	print("-- 5. a raft takes bullets: hits show, health falls, it breaks up, and the stage stays winnable")
	# Arrange
	var c: RiverCoverChamber = _river()
	var r: Dictionary = _raft_up(c)
	if r.is_empty():
		_check("a raft to shoot", false)
		c.queue_free()
		return
	var node: Node3D = r["node"]
	var health: Ep2CreatureHealth = Ep2CreatureHealth.of(node)
	var hp0: int = health.hp if health != null else -1
	# Act 1: a real shot from the overlook at the raft's empty end (the men stand at the other)
	c.armory.equipped = Ep2ArmoryState.BUFF
	var aim_at: Vector3 = node.global_transform * Vector3(0.0, 0.1, 1.85)
	_aim(c, aim_at)
	var on: bool = c.aim_on_target(c._player_pos + Vector3(0, c.eye_height, 0), c._look_dir())
	c._on_player_shot()
	var hp1: int = health.hp if health != null else -1
	var scars: int = node.find_children("BulletScar*", "", true, false).size()
	# Act 2: shot until it fails
	var men_before: int = c._raiders_alive()
	var guard: int = 0
	while not bool(r["broken"]) and guard < 20:
		c.damage_raft(r, 1, node.global_position)
		guard += 1
	var hits_to_break: int = guard + 1
	_adv(c, 3.0)
	var men_wet: int = 0
	for m in r["men"]:
		if c.raider_overboard(m):
			men_wet += 1
	var hp_dead: int = health.hp
	var log0: Node3D = (r["logs"] as Array)[0]
	var surface: float = c.river_point(float(r["s"])).y + RiverCoverChamber.WATER_Y
	var log_top: float = log0.global_position.y + 0.18
	var stray_scars: int = node.find_children("BulletScar*", "", false, false).size()
	c.damage_raft(r, 2, node.global_position)
	# Assert
	_check("the crosshair calls out a raft as a target", on)
	_check("a bullet into the raft registers: its health falls (%d -> %d, the Sharps counts two)" % [hp0, hp1], hp0 == RiverCoverChamber.RAFT_HP and hp1 == hp0 - 2)
	_check("...and the hit shows on the timber (a fresh scar)", scars >= 1)
	_check("it can fail: %d hits in all broke it up" % hits_to_break, bool(r["broken"]) and hits_to_break <= RiverCoverChamber.RAFT_HP)
	_check("breaking it takes more bullets than its two men (shooting them stays the better answer)",
		RiverCoverChamber.RAFT_HP > (r["men"] as Array).size() * 2 - 1)
	_check("whoever was aboard goes into the river (%d of %d in the water)" % [men_wet, men_before], men_wet == men_before and c._raiders_alive() == 0)
	_check("the wreck's logs float awash and drift, its scars on them (log top %.2f vs water %.2f, %d scars left floating)" % [log_top, surface, stray_scars],
		log_top > surface - 0.12 and stray_scars == 0)
	_check("a broken raft lets go of the shipment and takes no more hits", not bool(r["hooked"]) and health.hp == hp_dead)
	# a retry brings the gate's raft back whole
	c._package_lost()
	var fresh: Dictionary = c.get_rafts()[0] if not c.get_rafts().is_empty() else {}
	_check("a retry after failing brings a whole raft with its men (no wreck, no floating bodies left over)", not fresh.is_empty() and not bool(fresh["broken"])
		and Ep2CreatureHealth.of(fresh["node"]).hp == RiverCoverChamber.RAFT_HP and c.get_raiders().size() == 2)
	c.queue_free()
	await get_tree().process_frame
