extends Node
## Founder 2026-11-04 (screenshot 2): "the way the sheriff stands on the actual platform ... The same goes for everyone else in the town. I've
## seen some women sitting in mid air. Make the characters in the world fit coherently." The verification pass over the whole town: runs the real
## crowd for minutes of game time and checks every person, every half second, against what is really under their boots or their seat.
const TOWN := preload("res://src/episode2/chamber/gold_town.tscn")
const SIM_SECONDS := 240.0
const STEP := 1.0 / 20.0
const FOOT_TOLERANCE := 0.14                  # a planted boot's sole bone against the floor under it (a stride lifts one foot, the lower one counts)
const SEAT_REACH := 0.75                      # a seated clip needs a chair this close
var failures: int = 0
var _dump: Dictionary = {}


func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


func _foot_y(folk: Ep2TownFolk) -> float:
	var skels: Array = folk.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return INF
	var sk: Skeleton3D = skels[0]
	var low: float = INF
	for i in sk.get_bone_count():
		var n: String = sk.get_bone_name(i).to_lower()
		if n.ends_with("foot") or n.ends_with("toebase") or n.ends_with("toe_base"):
			low = minf(low, (sk.global_transform * sk.get_bone_global_pose(i)).origin.y)
	return low


func _hip_y(folk: Ep2TownFolk) -> float:
	var skels: Array = folk.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return INF
	var sk: Skeleton3D = skels[0]
	for i in sk.get_bone_count():
		var n: String = sk.get_bone_name(i).to_lower()
		if n.ends_with("hips") or n.ends_with("pelvis"):
			return (sk.global_transform * sk.get_bone_global_pose(i)).origin.y
	return INF


func _chairs(town: Node) -> Array:
	var out: Array = []
	for n in town.find_children("*", "Node3D", true, false):
		var low: String = str(n.name).to_lower()
		if "chair" in low or "bench" in low:
			out.append((n as Node3D).global_position)
	return out


func _near_chair(p: Vector3, chairs: Array) -> bool:
	for c in chairs:
		if Vector2(p.x - (c as Vector3).x, p.z - (c as Vector3).z).length() <= SEAT_REACH and absf(p.y - (c as Vector3).y) < 0.8:
			return true
	return false


func _ready() -> void:
	print("-- EP2 TOWN GROUNDING")
	_test_floor_function()
	var town: GoldTownChamber = TOWN.instantiate() as GoldTownChamber
	add_child(town)
	town.set_physics_process(false)
	town.setup(0, [], 0)
	_test_sheriff_on_the_boards(town)
	_test_seats(town)
	await _sweep(town)
	await _test_rest_stances(town)
	town.free()
	print("TOWN_GROUNDING: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)


func _test_floor_function() -> void:
	var porch: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.0, 0.0, 1.3))
	check("ground_y: the certificate office's porch boards", is_equal_approx(Ep2GoldTown.ground_y(porch), Ep2GoldTown.PORCH_Y))
	var side: Vector3 = Ep2GoldTown.local_to_world("Bldg_Saloon", Vector3(4.0, 0.0, 1.0))
	check("ground_y: the saloon's porch, away from its steps", is_equal_approx(Ep2GoldTown.ground_y(side), Ep2GoldTown.PORCH_Y))
	var step: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.0, 0.0, Ep2GoldTown.PORCH_DEPTH + 0.4))
	check("ground_y: halfway down the steps", absf(Ep2GoldTown.ground_y(step) - Ep2GoldTown.PORCH_Y * 0.5) < 0.02)
	check("ground_y: the middle of the street is the street", Ep2GoldTown.ground_y(Vector3(0.0, 0.0, 1420.0)) == 0.0)
	var room: Vector3 = Ep2GoldTown.local_to_world("Bldg_Certificates", Vector3(0.0, 0.0, -3.0))
	check("ground_y: the office's plank floor", is_equal_approx(Ep2GoldTown.ground_y(room), 0.06))


func _test_sheriff_on_the_boards(town: GoldTownChamber) -> void:
	var s: Ep2TownFolk = town.get_sheriff()
	var keep: Vector3 = s.position
	s.position = Ep2GoldTown.local_to_world("Bldg_B", Vector3(1.8, 0.0, 1.2))
	for i in 30:
		s.step(1.0 / 30.0)
	check("the Sheriff on a porch stands ON the boards, not through them", absf(s.position.y - Ep2GoldTown.PORCH_Y) < 0.02, "y %.3f" % s.position.y)
	s.position = Vector3(0.0, 0.0, 1420.0)
	for i in 30:
		s.step(1.0 / 30.0)
	check("...and off it he is back on the street", absf(s.position.y) < 0.02, "y %.3f" % s.position.y)
	s.position = keep
	s.place(keep)


func _test_seats(town: GoldTownChamber) -> void:
	var chairs: Array = _chairs(town)
	var missing: Array = []
	for seat in Ep2GoldTown.saloon_seats():
		if str(seat["kind"]) == "table":
			var p: Vector3 = seat["pos"]
			if not _near_chair(Vector3(p.x, float(seat["y"]), p.z), chairs):
				missing.append(str(p))
	check("every saloon table seat has a chair under it", missing.is_empty(), str(missing))


## Whose Rest clip is a seat is measured from the rig, so a re-rigged cast cannot quietly sit someone on the air again.
func _test_rest_stances(town: GoldTownChamber) -> void:
	var seated: Array = []
	for p in town._people.people:
		var f: Ep2TownFolk = p.folk
		if not is_instance_valid(f) or not f.has_clips():
			continue
		p.state = "pause"
		p.timer = 9999.0
		f.use_height = false
		f.clip_blend = 0.0
		f.hold_clip("Rest")
		var ap: AnimationPlayer = f.anim_player()
		var low: float = INF
		for i in 16:                                 # the lowest the hips get over the clip
			ap.advance(0.25)
			low = minf(low, _hip_y(f) - f.position.y)
		if low != INF and low < f.height_m * 0.42:
			seated.append(str(p.id))
		f.hold_clip("Idle")
		ap.advance(0.1)
	seated.sort()
	var want: Array = Ep2TownPeople.REST_SITTERS.duplicate()
	want.sort()
	check("the people whose Rest clip is a seated pose are exactly REST_SITTERS", seated == want, "%s vs %s" % [seated, want])
	for i in 2:
		var seat: Vector2 = Ep2GoldTown.REST_BENCHES[i]
		check("bench %d: its seat stands on the crowd's street graph" % i, town._people.navigation.closest(seat).distance_to(seat) < 0.15, str(town._people.navigation.closest(seat)))


func _sweep(town: GoldTownChamber) -> void:
	var chairs: Array = _chairs(town)
	var bad_floor: Dictionary = {}
	var bad_foot: Dictionary = {}
	var bad_seat: Dictionary = {}
	var samples: int = 0
	var seated_seen: int = 0
	var t: float = 0.0
	var next_sample: float = 2.0
	while t < SIM_SECONDS:
		town._tick_people(STEP)
		t += STEP
		if t >= next_sample:
			next_sample += 0.5
			for p in town._people.people:
				var f: Ep2TownFolk = p.folk
				if not is_instance_valid(f) or not f.is_visible_in_tree():
					continue
				samples += 1
				var clip: String = f.current_clip().to_lower()
				var sitting: bool = "sit" in clip
				if OS.get_cmdline_user_args().has("dump"):
					var key: String = "%s/%s" % [str(p.id), clip]
					var row: Array = _dump.get(key, [INF, -INF, INF, -INF, 0, f.position, f.height_m])
					var fy: float = _foot_y(f) - f.position.y
					var hy: float = _hip_y(f) - f.position.y
					row = [minf(row[0], fy), maxf(row[1], fy), minf(row[2], hy), maxf(row[3], hy), int(row[4]) + 1, f.position, f.height_m]
					_dump[key] = row
				var floor_y: float = Ep2GoldTown.ground_y(f.position)
				if not f.use_height and not sitting and absf(f.position.y - floor_y) > 0.08 and not f.is_walking():
					bad_floor[str(p.id)] = "%s y %.2f floor %.2f" % [f.position, f.position.y, floor_y]
				if clip == "rest" and not f.is_walking() and str(p.id) in Ep2TownPeople.REST_SITTERS and not _near_chair(f.position, chairs):
					bad_seat[str(p.id)] = "seated Rest on the air at %s" % f.position
				if sitting:
					seated_seen += 1
					if not _near_chair(f.position, chairs):
						bad_seat[str(p.id)] = "%s at %s state %s activity %s seat %d" % [clip, f.position, str(p.state), str(p.activity), int(p.seat)]
				elif not f.is_walking() and not f.use_height and not "walk" in clip and not "play" in clip:   # the children's play hops
					var foot: float = _foot_y(f)
					if foot != INF and absf(foot - floor_y) > FOOT_TOLERANCE:
						bad_foot[str(p.id)] = "%s foot %.2f floor %.2f at %s" % [clip, foot, floor_y, f.position]
			await get_tree().process_frame
	print("  sweep: %d samples, %d seated" % [samples, seated_seen])
	for k in _dump:
		var r: Array = _dump[k]
		print("DUMP %-34s foot %.2f..%.2f hip %.2f..%.2f h %.2f n %d at %s" % [k, r[0], r[1], r[2], r[3], r[6], r[4], r[5]])
	check("nobody hovers or sinks: everyone stands on the floor under them", bad_floor.is_empty(), str(bad_floor))
	check("nobody sits on the air: a seated clip always has a chair or bench", bad_seat.is_empty(), str(bad_seat))
	check("standing boots are on the floor (measured at the foot bones)", bad_foot.is_empty(), str(bad_foot))
	check("the sweep really saw people sitting", seated_seen > 0, str(seated_seen))
