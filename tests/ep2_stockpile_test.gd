extends Node
## Founder prompt STOCKPILE_RESERVE_PROMPT 2026-11-21: the town Stockpile (open depot, workers, wheelbarrows) in the east back lot and
## the Reserve under Fort Knox's hill. Checks, in the real town chamber, what a player would see and bump into: both are drawn off
## Main Street, clear of every building, door and the back-lot miners (who are all still there); the depot's open front is seen from
## the street; every worker stands clear of walls and props; the wheelbarrow loop never touches a wall, a prop or a worker; the barrows
## roll (wheel turning, hands on the grips), load at the ore pile and tip in the yard, stop for Lil Blunt, and gunfire stops everyone;
## the Reserve is its own place, reachable on foot from the drop point, its door reads one line, and it blocks nothing on the way to
## the river, the railway and Fort Knox's hill.
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const SITE := preload("res://src/episode2/extras/stockpile/stockpile_site.gd")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _ready() -> void:
	print("-- EP2 STOCKPILE + RESERVE")
	var town: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	check("the Stockpile is drawn in the town", SITE.stockpile_drawn and town.find_child("Stockpile", true, false) != null)
	check("the Reserve is drawn in the town", SITE.reserve_drawn and town.find_child("Reserve", true, false) != null)
	var sp: Node = town._stockpile
	check("the Stockpile's workers are built", sp != null and sp.workers.size() == 6, "%d" % (sp.workers.size() if sp else 0))
	check("the back-lot miners are all still there", town._miners != null and town._miners.miners.size() == Ep2BackLotMiners.MINERS.size())
	if sp == null or sp.workers.is_empty():
		_done(town)
		return
	sp.set_process(false)                                   # the test steps it, at a fixed 30 fps
	_test_placement(town)
	_test_clearances(town, sp)
	await _test_barrows(town, sp)
	await _test_danger(sp)
	_test_reserve(town, sp)
	_done(town)


func _done(town: Node) -> void:
	town.free()
	print("STOCKPILE: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)


func _corners(xf: Transform3D, x0: float, x1: float, z0: float, z1: float) -> Array:
	return [xf * Vector3(x0, 0, z0), xf * Vector3(x1, 0, z0), xf * Vector3(x1, 0, z1), xf * Vector3(x0, 0, z1)]


func _overlaps_building(pts: Array, pad: float) -> String:
	for e in Ep2GoldTown.LAYOUT:
		var piece: String = str(e[0])
		if not Ep2GoldTown.FOOTPRINT.has(piece): continue
		var fp: Array = Ep2GoldTown.FOOTPRINT[piece]
		var inv: Transform3D = Ep2GoldTown.building_xform(e).affine_inverse()
		for p in pts:
			var l: Vector3 = inv * (p as Vector3)
			if absf(l.x) < float(fp[0]) * 0.5 + pad and l.z > -float(fp[1]) - pad and l.z < Ep2GoldTown.PORCH_DEPTH + pad:
				return piece
	return ""


func _test_placement(town: GoldTownChamber) -> void:
	var lot: Array = _corners(SITE.xform(), -8.3, 6.9, -SITE.DEPTH, 6.8)
	var res: Array = _corners(SITE.reserve_xform(), -SITE.RESERVE_HALF.x, SITE.RESERVE_HALF.x, -SITE.RESERVE_HALF.y, 0.4)
	var min_x: float = INF
	for p in lot: min_x = minf(min_x, absf((p as Vector3).x))
	check("the Stockpile's lot is off Main Street (behind the fronts)", min_x > Ep2GoldTown.STREET_HALF + 9.0, "nearest |x| %.1f" % min_x)
	check("the Stockpile's lot overlaps no building", _overlaps_building(lot, 1.5) == "", _overlaps_building(lot, 1.5))
	check("the Reserve overlaps no building", _overlaps_building(res, 1.5) == "", _overlaps_building(res, 1.5))
	var near_door: float = INF
	for e in Ep2GoldTown.LAYOUT:
		var d: Vector3 = Ep2GoldTown.door_world(str(e[0]), 1.0)
		for p in lot + res:
			near_door = minf(near_door, Vector2(d.x - p.x, d.z - p.z).length())
	check("neither stands in front of a door", near_door > 6.0, "nearest door %.1f m" % near_door)
	var near_miner: float = INF
	for m in town._miners.miners:
		var q := Vector2(m.folk.position.x, m.folk.position.z)
		for p in lot:
			near_miner = minf(near_miner, q.distance_to(Vector2(p.x, p.z)))
	check("the miners keep their lot (Stockpile 8+ m away)", near_miner > 8.0, "%.1f m" % near_miner)
	var sc: Vector3 = SITE.xform().origin
	var rc: Vector3 = SITE.reserve_xform().origin
	check("the Reserve is its own place, not attached to the Stockpile", Vector2(sc.x - rc.x, sc.z - rc.z).length() > 25.0,
		"%.1f m apart" % Vector2(sc.x - rc.x, sc.z - rc.z).length())
	# THE SIGHTLINE: from the street in the gap past Bldg_F, at eye height, the open front's middle is in plain view (no wall between)
	var eye := Vector2(6.0, 1458.0)
	var front: Vector3 = SITE.xform() * Vector3(0.0, 0.0, 0.5)
	var hit: int = 0
	var own: int = 0
	for s in town._town_col["walls"]:
		if _seg_hit(eye, Vector2(front.x, front.z), s[0], s[1]):
			if (s[0] as Vector2).x > 20.0 and (s[1] as Vector2).x > 20.0:
				own += 1                                    # the depot's own yard props are in front of its open front
			else:
				hit += 1
	check("the depot's open front is seen from the street gap past Bldg_F", hit == 0, "%d town walls across the line" % hit)
	# the Reserve sits short of the river (and so of the railway and Fort Knox's hill): it blocks nothing beyond the town
	var far_z: float = -INF
	for p in res: far_z = maxf(far_z, (p as Vector3).z)
	check("the Reserve stands short of the river", far_z < Ep2GoldTown.RIVER_Z - Ep2GoldTown.RIVER_W * 0.5 - 8.0, "front z %.1f" % far_z)
	var hill: Vector3 = Ep2GoldTown.FORT_POS + Vector3(0.0, 0.0, -6.0)
	var hill_d: float = INF
	for p in res: hill_d = minf(hill_d, Vector2(p.x - hill.x, p.z - hill.z).length())
	check("the Reserve stands short of Fort Knox's hill", hill_d > 46.0 + 20.0, "%.1f m from the hill's centre" % hill_d)


func _seg_hit(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	return Geometry2D.segment_intersects_segment(a, b, c, d) != null


func _clear_of(p: Vector2, r: float, town: GoldTownChamber, skip: Array) -> float:
	var worst: float = INF
	for s in town._town_col["walls"]:
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		worst = minf(worst, p.distance_to(c) - r)
	for pr in town._town_col["props"]:
		if pr in skip or (pr as Array).is_empty(): continue
		worst = minf(worst, p.distance_to(pr[0]) - float(pr[1]) - r)
	return worst


func _test_clearances(town: GoldTownChamber, sp: Node) -> void:
	var moving: Array = []
	for w in sp.workers:
		moving.append(w.circle)
		if not w.barrow_circle.is_empty(): moving.append(w.barrow_circle)
	for w in sp.workers:
		if w.barrow != null: continue
		var p := Vector2(w.folk.position.x, w.folk.position.z)
		check("%s stands clear of walls and props" % w.id, _clear_of(p, 0.38, town, moving + [w.circle]) > -0.02,
			"%.2f m" % _clear_of(p, 0.38, town, moving + [w.circle]))
	# the loop: the pusher (0.42) and his barrow (0.5, 1.8 m ahead) - every 25 cm of it
	var pts: PackedVector3Array = sp.loop_points()
	var worst: float = INF
	var at: Vector2 = Vector2.ZERO
	var stations: Array = []
	for w in sp.workers:
		if w.barrow == null: stations.append(w.circle)
	var static_moving: Array = []
	for m in moving:
		if not (m in stations): static_moving.append(m)
	var n: int = int(sp._loop_len / 0.25)
	for i in n:
		var q: Vector3 = sp._at(float(i) * 0.25)
		var c: float = _clear_of(Vector2(q.x, q.z), 0.5, town, static_moving)
		if c < worst:
			worst = c
			at = Vector2(q.x, q.z)
	check("the wheelbarrow loop touches no wall, prop or worker", worst > 0.0, "tightest %.2f m at (%.1f, %.1f)" % [worst, at.x, at.y])


func _test_barrows(town: GoldTownChamber, sp: Node) -> void:
	town._player_pos = Vector3(0.0, 0.0, 1405.0)
	var w = null
	for o in sp.workers:
		if o.barrow != null:
			w = o
			break
	check("a wheelbarrow is pushed", w != null)
	if w == null: return
	var start: Vector3 = w.barrow.position
	var spin0: float = w.spin
	var rolled: float = 0.0
	var last: Vector3 = start
	var saw_loaded: bool = false
	var saw_empty: bool = false
	var grip_gap: float = 0.0
	var sk: Skeleton3D = w.skel
	var gaps: Array = []
	var probe := func() -> void:
		if w.hold <= 0.0 and w.alert_t <= 0.0 and (w.ik["Right"] as Ep2ArmIK).influence > 0.95:
			var r: Vector3 = (sk.global_transform * sk.get_bone_global_pose(w.hand_r)).origin
			gaps.append(r.distance_to((w.grips[1] as Node3D).global_position))
			if gaps.size() == 20:
				var sh: Vector3 = (sk.global_transform * sk.get_bone_global_pose(FOLK_RA(w))).origin
				print("    DBG feet %s hand %s shoulder %s grip %s axle %s skel_scale %s" % [w.folk.global_position, r, sh, (w.grips[1] as Node3D).global_position, w.barrow.global_position, sk.global_transform.basis.get_scale()])
	(w.ik["Right"] as Ep2ArmIK).modification_processed.connect(probe)
	for i in 1200:
		sp._process(1.0 / 30.0)
		await get_tree().process_frame
		rolled += w.barrow.position.distance_to(last)
		last = w.barrow.position
		saw_loaded = saw_loaded or w.load_node.visible
		saw_empty = saw_empty or not w.load_node.visible
	(w.ik["Right"] as Ep2ArmIK).modification_processed.disconnect(probe)
	gaps.sort()
	grip_gap = gaps[gaps.size() / 2] if not gaps.is_empty() else 9.0
	check("it rolls along its loop", rolled > 16.0, "%.1f m in 40 s" % rolled)
	check("the wheel turns with the distance", absf(w.spin - spin0) > 20.0, "%.1f rad" % absf(w.spin - spin0))
	check("it is loaded at the ore pile and tipped in the yard", saw_loaded and saw_empty)
	check("his right hand is on the grip", grip_gap < 0.12, "%.2f m (IK shortfall %.2f)" % [grip_gap, (w.ik["Right"] as Ep2ArmIK).shortfall])
	# Lil Blunt steps in front of the wheel: the barrow stops
	var s_before: float = w.s
	w.hold = 0.0
	town._player_pos = sp._at(w.s + 2.7)
	for i in 30:
		sp._process(1.0 / 30.0)
	check("a barrow stops for Lil Blunt in its way", absf(w.s - s_before) < 0.05, "moved %.2f m" % absf(w.s - s_before))
	town._player_pos = Vector3(0.0, 0.0, 1405.0)


func FOLK_RA(w) -> int:
	return load("res://src/episode2/extras/folk_mpfb/mpfb_folk.gd").bone(w.folk, "RightArm")


func _test_danger(sp: Node) -> void:
	var shot: Vector3 = SITE.xform() * Vector3(0.0, 0.0, 12.0)
	sp.notify_danger(shot)
	for i in 30:
		sp._process(1.0 / 30.0)
		await get_tree().process_frame
	var all_stopped: bool = true
	var facing: float = 1.0
	for w in sp.workers:
		all_stopped = all_stopped and w.alert_t > 0.0
		var to_shot: Vector3 = Vector3(shot.x - w.folk.position.x, 0.0, shot.z - w.folk.position.z).normalized()
		facing = minf(facing, Vector3(sin(w.folk.rotation.y), 0.0, cos(w.folk.rotation.y)).dot(to_shot))
		if w.barrow != null:
			for side in w.ik:
				check("%s lets go of the barrow on a shot" % w.id, (w.ik[side] as Ep2ArmIK).influence < 0.1)
	check("a shot stops every worker", all_stopped)
	check("they all turn toward the gunfire", facing > 0.7, "worst dot %.2f" % facing)


func _test_reserve(town: GoldTownChamber, sp: Node) -> void:
	# walk from the drop point to the Reserve's door the way Lil Blunt would (the town's own collision), past the church
	var spot: Vector3 = SITE.reserve_xform() * SITE.RESERVE_INSPECT
	var p: Vector3 = Ep2GoldTown.DROP_POINT
	var route: Array = [Vector3(2.0, 0, 1446.0), Vector3(2.0, 0, 1458.0), Vector3(6.0, 0, 1462.0), Vector3(7.0, 0, 1476.0), Vector3(14.0, 0, 1482.0), Vector3(30.0, 0, 1486.0), Vector3(31.5, 0, 1491.5), spot]
	for target in route:
		for i in 400:
			var d: Vector3 = (target as Vector3) - p
			d.y = 0.0
			if d.length() < 0.3: break
			p += d.normalized() * minf(0.15, d.length())
			p = town._collide(p)
		print("    walk leg to %s ended at %s" % [target, p])
	check("the Reserve's door is reached on foot from the drop point", Vector2(p.x - spot.x, p.z - spot.z).length() < 0.6,
		"ended %.1f m short" % Vector2(p.x - spot.x, p.z - spot.z).length())
	town._player_pos = spot
	sp._step_reserve()
	var prompt: String = town._hud._search.text if town._hud != null and town._hud._search != null else "?"
	check("at its door the placard can be read", prompt.begins_with("Read the placard"), prompt)
	var before: int = sp.inspected
	sp.inspect()
	check("reading it gives its one line", sp.inspected == before + 1 and not sp.RESERVE_LINE.contains("%") and not sp.RESERVE_LINE.contains("$"))
	town._player_pos = Vector3(0.0, 0.0, 1405.0)
	sp._step_reserve()
	check("the prompt goes when he walks away", town._hud == null or town._hud._search.text == "")
