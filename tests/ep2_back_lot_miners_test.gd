extends Node
## Founder prompt PROMPT_BACK_MINERS_2026-11-08: ambient local gold miners at the BACK of town. Checks what a player would see and bump into,
## in the real town chamber: they are there, behind the fronts (not on Main Street, not in a building, not in front of a door, not on a
## horse), solid to Lil Blunt, holding their tools in their hands, the seated one on a crate at his own hip height, and gunfire stops their
## work and turns them toward it before they go back to it.
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
var failures: int = 0


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _ready() -> void:
	print("-- EP2 BACK-LOT MINERS")
	var town: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	var miners: Ep2BackLotMiners = town._miners
	check("the miners are built with the town", miners != null and miners.miners.size() == Ep2BackLotMiners.MINERS.size(),
		"%d of %d" % [miners.miners.size() if miners else 0, Ep2BackLotMiners.MINERS.size()])
	if miners == null or miners.miners.is_empty():
		_done(town)
		return
	_test_placement(town, miners)
	await _test_hands_and_seat(miners)
	await _test_danger(miners)
	_done(town)


func _done(town: Node) -> void:
	town.free()
	print("BACK_LOT_MINERS: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)


func _test_placement(town: GoldTownChamber, miners: Ep2BackLotMiners) -> void:
	var props: Array = town._town_col.get("props", [])
	for m in miners.miners:
		var p: Vector3 = m.folk.position
		var at := Vector2(p.x, p.z)
		check("%s is behind the fronts, off Main Street" % m.id, absf(p.x) > Ep2GoldTown.STREET_HALF + 8.0, "x=%.1f" % p.x)
		# not inside any building (or its porch)
		var inside: String = ""
		for e in Ep2GoldTown.LAYOUT:
			var piece: String = str(e[0])
			if not Ep2GoldTown.FOOTPRINT.has(piece): continue
			var fp: Array = Ep2GoldTown.FOOTPRINT[piece]
			var l: Vector3 = Ep2GoldTown.building_xform(e).affine_inverse() * p
			if absf(l.x) < float(fp[0]) * 0.5 + 0.6 and l.z > -float(fp[1]) - 0.6 and l.z < Ep2GoldTown.PORCH_DEPTH + 0.6:
				inside = piece
		check("%s stands in the open, not inside a building" % m.id, inside == "", inside)
		# well clear of every door anyone uses
		var near_door: float = INF
		for e in Ep2GoldTown.LAYOUT:
			var piece: String = str(e[0])
			if Ep2GoldTown.FOOTPRINT.has(piece) and float(Ep2GoldTown.FOOTPRINT[piece][2]) > 0.0:
				var d: Vector3 = Ep2GoldTown.door_world(piece, 1.0)
				near_door = minf(near_door, Vector2(d.x - p.x, d.z - p.z).length())
		check("%s is nowhere near a door" % m.id, near_door > 4.0, "%.1f m" % near_door)
		var horse: float = INF
		for h in Ep2TownLife.HORSES:
			horse = minf(horse, Vector2(float(h[0]) - p.x, float(h[1]) - p.z).length())
		check("%s is clear of the horses" % m.id, horse > 3.0, "%.1f m" % horse)
		# solid: the town's collision pushes Lil Blunt out of him
		var pushed: Vector2 = Ep2GoldTown.collide(at, 0.3, town._town_col.get("walls", []), props)
		check("%s is solid to Lil Blunt" % m.id, pushed.distance_to(at) > 0.4, "pushed %.2f m" % pushed.distance_to(at))
	# clusters of 2-4 (the founder's "clusters of 2-4, small radius")
	var lots: Dictionary = {}
	for m in miners.miners:
		var side: String = "L" if m.folk.position.x < 0.0 else "R"
		lots[side] = int(lots.get(side, 0)) + 1
	for side in lots:
		check("lot %s holds a cluster of 2-4" % side, int(lots[side]) >= 2 and int(lots[side]) <= 4, str(lots[side]))


func _test_hands_and_seat(miners: Ep2BackLotMiners) -> void:
	for i in 30:
		await get_tree().process_frame
	for m in miners.miners:
		if m.tool != null:
			var grip: Vector3 = (m.skel.global_transform * m.skel.get_bone_global_pose(m.hand)).origin
			var top: Vector3 = m.tool.global_transform * Vector3.ZERO
			var axis: Vector3 = m.tool.global_transform.basis.y.normalized()
			# the hand lies on the handle's line (within a hand's width)
			var off: Vector3 = (grip - top) - axis * (grip - top).dot(axis)
			check("%s's hand is on his %s" % [m.id, m.tool_kind], off.length() < 0.06, "%.3f m off the handle" % off.length())
			check("%s's %s rests on the ground or in the mound, not in the air" % [m.id, m.tool_kind], top.y < 0.3, "end at y=%.2f" % top.y)
	for row in Ep2BackLotMiners.MINERS:
		if not bool(row.get("seat", false)): continue
		var id: String = str(row["id"])
		var m = null
		for x in miners.miners:
			if x.id == id: m = x
		if m == null: continue
		var hips: int = Ep2BackLotMiners._bone(m.skel, ["hips", "pelvis"])
		var hy: float = (m.skel.global_transform * m.skel.get_bone_global_pose(hips)).origin.y
		var seat: float = float(miners.get_meta("seat_top_" + id, -1.0))
		check("%s sits on his crate, not on the air" % id, seat > 0.25 and hy > seat - 0.02 and hy - seat < 0.2, "hips %.2f, crate top %.2f" % [hy, seat])


func _test_danger(miners: Ep2BackLotMiners) -> void:
	var m = miners.miners[0]
	var shot := Vector3(0.0, 0.0, 1420.0)
	miners.notify_danger(shot)
	await get_tree().create_timer(1.5).timeout
	check("a shot stops the work: he turns to look", m.folk.current_clip() in ["alert", "observe"], m.folk.current_clip())
	var to_shot: Vector3 = Vector3(shot.x - m.folk.position.x, 0.0, shot.z - m.folk.position.z).normalized()
	var fwd: Vector3 = m.folk.global_transform.basis.z.normalized()
	check("he faces the gunfire", fwd.dot(to_shot) > 0.8, "dot %.2f" % fwd.dot(to_shot))
	for x in miners.miners: x.alert_t = 0.01
	for i in 5:
		await get_tree().process_frame
	check("then he goes back to work", m.folk.current_clip() == str(Ep2BackLotMiners.MINERS[0]["clip"]).to_lower(), m.folk.current_clip())
