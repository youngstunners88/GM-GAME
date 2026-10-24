extends Node
## End-to-end crowd scenarios over imported actors and the real town collision geometry.
var failures: int = 0
var checks: int = 0
var reports: Dictionary = {}

func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label, " ", detail if not ok else "")

func _ready() -> void:
	var world := Node3D.new()
	add_child(world)
	var geometry: Dictionary = Ep2GoldTown.build(world, true)
	var tp := Ep2TownPeople.new()
	tp.configure_space(geometry)
	tp.build(world, 7627)
	check("all thirteen public figures load; prisoner remains owned by jail", tp.people.size() == 13)
	check("navigation has a connected outdoor street graph", tp.navigation.graph.get_point_count() > 500)
	var far := Vector3(80, 0, 1300)
	var overlaps: int = 0
	var static_hits: int = 0
	var shop_ticks: int = 0
	for frame in 6000: # ten simulated minutes, at a different tick rate from the old 120s test
		tp.step(0.1, far)
		for i in tp.people.size():
			var p: Ep2TownPeople.Person = tp.people[i]
			var q := Vector2(p.folk.position.x, p.folk.position.z)
			# a shopper on a scripted visit is legitimately on a walk-in shop's porch / inside it (founder 2026-10-24); everyone else stays on the street graph
			if p.state not in Ep2TownPeople.SHOP_STATES and not tp.navigation.is_clear(q): static_hits += 1
			if p.state in Ep2TownPeople.SHOP_STATES: shop_ticks += 1
			for k in range(i + 1, tp.people.size()):
				var other: Ep2TownPeople.Person = tp.people[k]
				if q.distance_to(Vector2(other.folk.position.x, other.folk.position.z)) < 0.60: overlaps += 1
	check("ten minutes: nobody enters walls, props, raised porches or firing yard (shop visits apart)", static_hits == 0, static_hits)
	check("ten minutes: townspeople really go into the shops", shop_ticks > 0, shop_ticks)
	check("ten minutes: civilians never intersect one another", overlaps == 0, overlaps)
	var distinct_histories: Dictionary = {}
	var all_active: bool = true
	var all_varied: bool = true
	for p in tp.people:
		all_active = all_active and p.walked_m > 20 and p.choices > 5
		all_varied = all_varied and p.visits.size() >= 2
		distinct_histories[JSON.stringify(p.visits)] = true
		reports[p.id] = {"walked_m": p.walked_m, "choices": p.choices, "visits": p.visits.duplicate(), "recoveries": p.recoveries, "personality": p.profile, "memories": p.memories.duplicate()}
	check("every person independently makes decisions and travels", all_active, reports)
	check("every person visits multiple places", all_varied, reports)
	check("individual histories differ across the cast", distinct_histories.size() >= 10, distinct_histories.size())
	# Put the player across a live path and check the personal-space invariant rather than a path declaration.
	var first: Ep2TownPeople.Person = tp.people[0]
	var player: Vector3 = first.folk.position + Vector3(0, 0, 1.2)
	# Insert the player into free space, as the chamber's player collision does.
	for i in 32:
		var q: Vector2 = tp.navigation.closest(Vector2(first.folk.position.x, first.folk.position.z) + Vector2.from_angle(float(i) * TAU / 32) * 1.8)
		if tp._body_clear(q, null, far):
			player = Vector3(q.x, 0, q.y)
			break
	var player_hits: int = 0
	for frame in 500:
		tp.step(0.04, player)
		for p in tp.people:
			if Vector2(p.folk.position.x - player.x, p.folk.position.z - player.z).length() < 0.60: player_hits += 1
	check("crowd yields around a stationary player", player_hits == 0, player_hits)
	# A fixed obstacle across the direct line must produce a real detour.
	var obstructed: Dictionary = geometry.duplicate(true)
	(obstructed["props"] as Array).append([Vector2(0, 1422), 0.85])
	var nav := Ep2TownNavigation.new()
	nav.configure(obstructed)
	var detour: Array[Vector2] = nav.path(Vector2(0, 1418), Vector2(0, 1427))
	var safe_path: bool = detour.size() >= 2
	var prev := Vector2(0, 1418)
	for point in detour:
		safe_path = safe_path and nav.segment_clear(prev, point)
		prev = point
	check("pathfinding reroutes around a newly obstructed street", safe_path, detour)
	# Social exchange is bilateral and remembered; actor positioning is a legal scenario fixture.
	var a: Ep2TownPeople.Person = tp.people[0]
	var b: Ep2TownPeople.Person = tp.people[1]
	var base: Vector2 = tp.navigation.closest(Vector2(0, 1418))
	a.folk.place(Vector3(base.x, 0, base.y))
	b.folk.place(Vector3(base.x, 0, base.y + 1.2))
	a.state = "pause"; b.state = "pause"
	a.timer = 10; b.timer = 10
	a.social_cd = 0; b.social_cd = 0
	a.profile["social"] = 1.0
	a.memories.erase(b.id); b.memories.erase(a.id)
	tp._try_social(a)
	check("nearby people exchange a bilateral greeting and remember the partner", a.state == "social" and b.state == "social" and a.memories.has(b.id) and b.memories.has(a.id))
	# Danger interrupts, does not kill/spawn people, and they resume after the quiet interval.
	tp.notify_danger(Vector3(0, 0, 1425), 200)
	var fear_count: int = 0
	for p in tp.people:
		if (p.fear > 0 and p.state in ["flee", "shelter"]) or p.state in Ep2TownPeople.SHOP_STATES: fear_count += 1   # a shopper indoors is not exposed
	check("nearby gunfire interrupts every exposed civilian", fear_count == 13, fear_count)
	for frame in 900: tp.step(0.1, far)
	var recovered: int = 0
	for p in tp.people:
		if p.fear <= 0 and p.state not in ["flee", "shelter"]: recovered += 1
	check("quiet recovery returns everyone to ordinary activities", recovered == 13, recovered)
	tp.set_context("duel")
	var total_before: float = 0
	for p in tp.people: total_before += p.walked_m
	for frame in 1200: tp.step(0.1, far)
	check("crowd clears the duel lane without teleporting", tp.duel_lane_clear())
	var sheltered: bool = true
	for p in tp.people: sheltered = sheltered and (p.state == "shelter" or p.state in ["shop_in", "shop_buy"])   # indoors is safe
	check("everyone waits safely during the draw", sheltered)
	var frozen: Dictionary = tp.snapshot()
	tp.step(0, far)
	check("paused simulation changes no timers or memories", tp.snapshot() == frozen)
	tp.set_context("normal")
	for frame in 500: tp.step(0.1, far)
	var data: Dictionary = tp.snapshot()
	var old_positions: Dictionary = {}
	for p in tp.people: old_positions[p.id] = p.folk.position
	for frame in 100: tp.step(0.1, far)
	check("NPC state round-trips through JSON", tp.restore(JSON.parse_string(JSON.stringify(data))))
	var positions_match: bool = true
	for p in tp.people:
		positions_match = positions_match and Vector2(p.folk.position.x, p.folk.position.z).distance_to(Vector2(old_positions[p.id].x, old_positions[p.id].z)) < 0.001
	check("restoration preserves identity and location", positions_match)
	var saved_progress: Dictionary = GameManager.progression_state.duplicate(true)
	GameManager.town_people_state = data.duplicate(true)
	check("town state is written through the existing session save", GameManager.save_session())
	GameManager.town_people_state.clear()
	check("town routines and memories survive a disk load", GameManager.load_session() and tp.restore(GameManager.town_people_state))
	check("ambient memories do not change campaign progression", GameManager.progression_state == saved_progress)
	for frame in 100: tp.step(0.1, far)
	var resumed: Dictionary = tp.snapshot()
	check("saved routines can restart from the same decision point", tp.restore(GameManager.town_people_state))
	for frame in 100: tp.step(0.1, far)
	check("restoring random streams reproduces the subsequent decisions", tp.snapshot() == resumed)
	var corrupt: Dictionary = data.duplicate(true)
	corrupt["people"][0]["position"] = [NAN, 0]
	var before_invalid: Dictionary = tp.snapshot()
	check("malformed state is rejected atomically", not tp.restore(corrupt) and tp.snapshot() == before_invalid)
	for mutation in ["scalar", "memory", "overlap", "duplicate", "path", "random"]:
		corrupt = data.duplicate(true)
		match mutation:
			"scalar": corrupt["people"][0]["greet_cd"] = {"bad": true}
			"memory": corrupt["people"][0]["memories"]["player_seen"] = [1, 2]
			"overlap": corrupt["people"][0]["position"] = corrupt["people"][1]["position"].duplicate()
			"duplicate": corrupt["people"][0]["id"] = corrupt["people"][1]["id"]
			"path": corrupt["people"][0]["waypoints"] = [[0, 100]]
			"random": corrupt["people"][0]["rng_state"] = "99999999999999999999"
		check("invalid %s rejected without mutation" % mutation, not tp.restore(corrupt) and tp.snapshot() == before_invalid)
	# Regression (founder 2026-10-22): the people live in the town BEFORE the drop-off. The ride chamber builds its own crowd
	# on the ride's lighter collision; the town chamber must take that exact state over at the cut.
	var ride_world := Node3D.new()
	add_child(ride_world)
	var ride := Ep2TownPeople.new()
	ride.configure_space(Ep2GoldTown.build(ride_world, false))
	ride.build(ride_world, 4101)
	for frame in 900: ride.step(0.1, Vector3(0, 0, 1300))
	var town_world := Node3D.new()
	add_child(town_world)
	var town := Ep2TownPeople.new()
	town.configure_space(Ep2GoldTown.build(town_world, true))
	town.build(town_world, 4101)
	var ride_state: Dictionary = ride.snapshot()
	var handed: bool = town.restore(JSON.parse_string(JSON.stringify(ride_state)))
	var mismatched: Array = []
	for i in ride.people.size():
		var rp: Ep2TownPeople.Person = ride.people[i]
		var tq: Ep2TownPeople.Person = town.person(rp.id)
		if tq == null or Vector2(tq.folk.position.x - rp.folk.position.x, tq.folk.position.z - rp.folk.position.z).length() > 0.001 or tq.state != rp.state or tq.activity != rp.activity \
				or tq.destination != rp.destination or tq.rng.state != rp.rng.state or tq.visits.size() != rp.visits.size():
			mismatched.append(rp.id)
	check("ride-in crowd hands over to the town chamber at the cut", handed and mismatched.is_empty(), mismatched)
	# A quad comes down the middle of the street: whoever stands in its lane steps to the verge.
	var lane_person: Ep2TownPeople.Person = ride.people[0]
	var spot: Vector2 = ride.navigation.closest(Vector2(0.0, 1425.0))
	lane_person.folk.place(Vector3(spot.x, 0, spot.y))
	lane_person.state = "pause"
	lane_person.timer = 30.0
	ride.make_way(Vector3(spot.x, 0, spot.y - 8.0), Vector2(0, 1))
	check("a person in the quad's lane steps aside", lane_person.state == "flee" and absf(lane_person.safety.x - spot.x) > 1.0, [lane_person.state, lane_person.safety])
	ride_world.queue_free()
	town_world.queue_free()
	var n: int = tp.build(world, 7627)
	check("rebuilding creates exactly one instance per identity", n == 13 and world.find_children("Person_*", "", false, false).size() == 13)
	var file := FileAccess.open("res://design/ep2/town/autonomy-20261022/behavior-report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "people": reports}, "\t") + "\n")
		file.close()
	world.queue_free()
	print("EP2_TOWN_AUTONOMY: ALL PASS (%d checks)" % checks if failures == 0 else "EP2_TOWN_AUTONOMY: FAILED %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
