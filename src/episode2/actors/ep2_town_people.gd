class_name Ep2TownPeople
extends RefCounted
## Independent deterministic ambient brains. All thirteen supplied public figures; the jail prisoner is story-controlled.
## No wall-clock timers, external AI, quest dialogue, combat targets or unbounded wandering.
const GREET_R := 3.6
const GREET_COOLDOWN := 24.0
const BODY_R := 0.31
const LOOPING_CLIPS := ["Idle", "Walk", "Observe", "Rest", "Talk", "Inspect", "Alert"]
const ROSTER: Array = [
	{"id": "clerk", "file": "townsman_clerk.glb", "h": 1.76, "route": [Vector2(-2.6, 1408.5), Vector2(-2.6, 1423.0), Vector2(-2.6, 1437.0)], "speed": 0.95, "pause": [3.0, 8.0]},
	{"id": "oldtimer", "file": "townsman_oldtimer.glb", "h": 1.69, "route": [Vector2(2.6, 1424.0), Vector2(2.6, 1437.0), Vector2(1.2, 1444.0)], "speed": 0.78, "pause": [5.0, 12.0]},
	{"id": "rancher", "file": "townsman_rancher.glb", "h": 1.84, "route": [Vector2(2.9, 1431.0), Vector2(0.4, 1421.0), Vector2(2.9, 1431.0), Vector2(-0.8, 1436.0)], "speed": 1.05, "pause": [6.0, 14.0]},
	{"id": "dressmaker", "file": "townswoman_dressmaker.glb", "h": 1.66, "route": [Vector2(1.0, 1409.5), Vector2(1.0, 1427.0), Vector2(1.0, 1445.0)], "speed": 0.88, "pause": [2.5, 6.0]},
	{"id": "lady", "file": "townswoman_lady.glb", "h": 1.72, "route": [Vector2(-0.6, 1444.0), Vector2(-0.6, 1428.0), Vector2(-0.6, 1411.0)], "speed": 0.82, "pause": [4.0, 9.0]},
	{"id": "bald_worker", "file": "townsman_bald_worker.glb", "h": 1.8, "speed": 0.99, "route": [Vector2(-2.0, 1410), Vector2(2.0, 1412)], "pause": [4.0, 10.0]},
	{"id": "grandma", "file": "townswoman_grandma.glb", "h": 1.57, "speed": 0.68, "route": [Vector2(-2.0, 1413), Vector2(2.0, 1415)], "pause": [4.0, 10.0]},
	{"id": "grandfather", "file": "townsman_grandfather.glb", "h": 1.73, "speed": 0.73, "route": [Vector2(-2.0, 1416), Vector2(2.0, 1418)], "pause": [4.0, 10.0]},
	{"id": "grandmother", "file": "townswoman_grandmother.glb", "h": 1.59, "speed": 0.7, "route": [Vector2(-2.0, 1419), Vector2(2.0, 1421)], "pause": [4.0, 10.0]},
	{"id": "youth", "file": "townsman_youth.glb", "h": 1.67, "speed": 1.12, "route": [Vector2(-2.0, 1422), Vector2(2.0, 1424)], "pause": [4.0, 10.0]},
	{"id": "boy", "file": "townsboy.glb", "h": 1.36, "speed": 1.16, "route": [Vector2(-2.0, 1425), Vector2(2.0, 1427)], "pause": [4.0, 10.0]},
	{"id": "braided_girl", "file": "townsgirl_braided.glb", "h": 1.34, "speed": 1.02, "route": [Vector2(-2.0, 1428), Vector2(2.0, 1430)], "pause": [4.0, 10.0]},
	{"id": "bob_girl", "file": "townsgirl_bob.glb", "h": 1.28, "speed": 0.98, "route": [Vector2(-2.0, 1431), Vector2(2.0, 1433)], "pause": [4.0, 10.0]},
]

const PROFILES := {
	"clerk": {"social": 0.72, "rest": 0.45, "interests": ["saloon", "office", "notice"], "label": "Pianist", "temperament": "observant"},
	"oldtimer": {"social": 0.38, "rest": 0.90, "interests": ["rest_south", "horses", "notice"], "label": "Old-timer", "temperament": "reserved"},
	"rancher": {"social": 0.54, "rest": 0.30, "interests": ["horses", "water", "yard"], "label": "Rancher", "temperament": "practical"},
	"dressmaker": {"social": 0.67, "rest": 0.32, "interests": ["shop", "market", "office"], "label": "Dressmaker", "temperament": "busy"},
	"lady": {"social": 0.78, "rest": 0.40, "interests": ["market", "notice", "saloon"], "label": "Market visitor", "temperament": "outgoing"},
	"bald_worker": {"social": 0.42, "rest": 0.30, "interests": ["yard", "water", "office"], "label": "Worker", "temperament": "industrious"},
	"grandma": {"social": 0.80, "rest": 0.85, "interests": ["rest_south", "market", "notice"], "label": "Grandmother", "temperament": "welcoming"},
	"grandfather": {"social": 0.48, "rest": 0.82, "interests": ["rest_north", "horses", "saloon"], "label": "Grandfather", "temperament": "unhurried"},
	"grandmother": {"social": 0.64, "rest": 0.87, "interests": ["rest_north", "shop", "market"], "label": "Elder companion", "temperament": "companionable"},
	"youth": {"social": 0.61, "rest": 0.18, "interests": ["yard", "notice", "market"], "label": "Young townsman", "temperament": "curious"},
	"boy": {"social": 0.74, "rest": 0.24, "interests": ["water", "market", "rest_south"], "label": "Boy", "temperament": "energetic"},
	"braided_girl": {"social": 0.58, "rest": 0.30, "interests": ["shop", "market", "rest_north"], "label": "Braided girl", "temperament": "inquisitive"},
	"bob_girl": {"social": 0.45, "rest": 0.38, "interests": ["rest_south", "shop", "water"], "label": "Bob-haired girl", "temperament": "watchful"},
}
## Ground-level destinations beside the town's actual institutions. No invented enterable shops or raised-porch walking.
const PLACES := {
	"office": Vector2(-3.2, 1409), "saloon": Vector2(-3.2, 1424),
	"shop": Vector2(3.0, 1412), "market": Vector2(3.0, 1436),
	"notice": Vector2(-3.0, 1437), "horses": Vector2(2.6, 1428),
	"water": Vector2(-2.8, 1444), "yard": Vector2(-13.0, 1457),
	"rest_south": Vector2(-2.6, 1401), "rest_north": Vector2(3.0, 1450),
}
const SHELTERS := [Vector2(-3.2, 1401), Vector2(3.2, 1401), Vector2(-3.2, 1450), Vector2(3.2, 1450), Vector2(-15, 1456)]
const ACTIVITIES := ["work", "errand", "rest", "observe", "social"]

class Person:
	var id: String = ""
	var folk: Ep2TownFolk
	var route: Array = [] # historical route fixtures, no longer the decision policy
	var speed: float = 1.0
	var pause_range := Vector2(3, 8)
	var state: String = "pause"
	var timer: float = 1.0
	var greet_cd: float = 0.0
	var greets: int = 0
	var walked_m: float = 0.0
	var rng := RandomNumberGenerator.new()
	var profile: Dictionary = {}
	var activity: String = "observe"
	var destination: String = ""
	var waypoints: Array[Vector2] = []
	var recent: Array[String] = []
	var visits: Dictionary = {}
	var memories: Dictionary = {}
	var choices: int = 0
	var blocked: float = 0.0
	var recoveries: int = 0
	var social_cd: float = 0.0
	var partner: String = ""
	var fear: float = 0.0
	var threat := Vector2.ZERO
	var activity_time: float = 0.0
	var safety := Vector2.ZERO

var people: Array = []
var navigation := Ep2TownNavigation.new()
var reservations: Dictionary = {}
var elapsed: float = 0.0
var _seed: int = 4101
var _configured: bool = false
var _mode: String = "normal" # normal | quiet | duel
var _story_was_duel: bool = false

func configure_space(info: Dictionary) -> void:
	navigation.configure(info)
	_configured = true

func build(parent: Node3D, seed_value: int = 4101) -> int:
	# Safe repeated build: retire only this controller's instances.
	for p in people:
		if is_instance_valid(p.folk):
			p.folk.get_parent().remove_child(p.folk)
			p.folk.queue_free()
	people.clear()
	reservations.clear()
	elapsed = 0.0
	_seed = seed_value
	if not _configured:
		# Compatibility fixtures pass no info; derive the same town collision using a temporary holder.
		var geometry := Node3D.new()
		parent.add_child(geometry)
		configure_space(Ep2GoldTown.build(geometry, true))
		parent.remove_child(geometry)
		geometry.queue_free()
	for row in ROSTER:
		var path: String = Ep2Extras.PEOPLE_DIR + str(row["file"])
		if not Ep2Extras.has(path): continue
		var p := Person.new()
		p.id = str(row["id"])
		p.rng.seed = seed_value + int(p.id.hash())
		p.profile = PROFILES[p.id].duplicate(true)
		p.folk = Ep2TownFolk.new()
		p.folk.name = "Person_" + p.id
		p.folk.clip_blend = 0.18
		p.folk.looping_clips.assign(LOOPING_CLIPS)
		p.folk.arrival_radius = 0.003
		parent.add_child(p.folk)
		if not p.folk.setup(path, float(row["h"])):
			p.folk.queue_free()
			continue
		p.route = row["route"]
		p.speed = float(row["speed"])
		p.pause_range = Vector2(float(row["pause"][0]), float(row["pause"][1]))
		# Spread people across their first interest and avoid overlapping starts.
		var origin: Vector2 = PLACES[p.profile["interests"][people.size() % 3]]
		var pos: Vector2 = navigation.closest(origin + Vector2(p.rng.randf_range(-1.3, 1.3), p.rng.randf_range(-1.8, 1.8)))
		for attempt in 40:
			if _body_clear(pos, p, Vector3(100, 0, 1300)): break
			pos = navigation.closest(origin + Vector2(p.rng.randf_range(-2.2, 2.2), p.rng.randf_range(-4, 4)))
		p.folk.place(Vector3(pos.x, 0, pos.y))
		p.folk.face_yaw(p.rng.randf() * TAU)
		p.timer = p.rng.randf_range(0.5, 8.0)
		p.social_cd = p.rng.randf_range(5, 20)
		people.append(p)
	return people.size()

func set_context(mode: String) -> void:
	if mode not in ["normal", "quiet", "duel"]: mode = "normal"
	if _mode == mode: return
	_mode = mode
	if mode == "duel":
		_story_was_duel = true
		for p in people:
			_release(p)
			p.folk.stop()
			p.partner = ""
			_seek_safety(p, Vector2(0, 1425), true)
	elif _story_was_duel:
		_story_was_duel = false
		for p in people:
			p.fear = maxf(p.fear, 3.0)
			p.timer = p.rng.randf_range(2, 5)

func notify_danger(where: Vector3, radius: float = 24.0) -> void:
	for p in people:
		if _pos(p).distance_to(Vector2(where.x, where.z)) > radius: continue
		p.threat = Vector2(where.x, where.z)
		p.fear = p.rng.randf_range(12, 20)
		p.memories["last_danger"] = elapsed
		if p.state != "shelter" and _mode != "duel": _seek_safety(p, p.threat, false)

func step(delta: float, player_world: Vector3) -> void:
	if delta <= 0.0 or not is_finite(delta): return
	# Bounded substeps prevent collision tunnelling after a browser hitch.
	var remaining: float = minf(delta, 0.5)
	while remaining > 0.00001:
		var dt: float = minf(remaining, 0.05)
		elapsed += dt
		for p in people: _step_one(p, dt, player_world)
		remaining -= dt

func _step_one(p: Person, dt: float, player: Vector3) -> void:
	p.greet_cd = maxf(0, p.greet_cd - dt)
	p.social_cd = maxf(0, p.social_cd - dt)
	p.fear = maxf(0, p.fear - dt)
	p.timer = maxf(-1, p.timer - dt)
	p.activity_time += dt
	var before: Vector2 = _pos(p)
	if p.state == "flee" and p.fear <= 0 and _mode != "duel":
		p.folk.stop()
		p.state = "pause"
		p.timer = p.rng.randf_range(1, 3)
	if p.state in ["walk", "flee"]:
		_move(p, dt, player)
		if p.state == "walk" and _mode == "normal" and p.fear <= 0 and _near_player(p, player): _greet(p, player)
	elif p.state == "shelter":
		p.folk.face_point(Vector3(p.threat.x, 0, p.threat.y))
		if _mode != "duel" and p.fear <= 0 and p.timer <= 0:
			p.state = "pause"
			p.timer = p.rng.randf_range(1, 4)
			p.folk.hold_clip("Observe")
	elif p.state == "greet":
		p.folk.face_point(player)
		if p.timer <= 0:
			p.state = "pause"
			p.timer = p.rng.randf_range(1, 3)
			p.folk.hold_clip("Observe")
	elif p.state == "social":
		var other: Person = person(p.partner)
		if other != null: p.folk.face_point(other.folk.position)
		if p.timer <= 0 or other == null or other.state != "social":
			p.partner = ""
			p.state = "pause"
			p.timer = p.rng.randf_range(2, 5)
			p.folk.hold_clip("Idle")
	else:
		if _mode == "normal" and p.fear <= 0 and _near_player(p, player):
			_greet(p, player)
		elif p.timer <= 0 and _mode != "duel":
			_choose(p)
		elif _mode == "normal" and p.social_cd <= 0 and p.fear <= 0:
			_try_social(p)
	if before.distance_to(_pos(p)) < 0.000001: p.folk.step(dt)

func _pos(p: Person) -> Vector2:
	return Vector2(p.folk.position.x, p.folk.position.z)

func person(id: String) -> Person:
	for p in people:
		if p.id == id: return p
	return null

func _near_player(p: Person, player: Vector3) -> bool:
	return p.greet_cd <= 0 and absf(player.y) < 3.0 and _pos(p).distance_to(Vector2(player.x, player.z)) < GREET_R

func _greet(p: Person, player: Vector3) -> void:
	p.folk.stop()
	p.folk.hold_clip("Greet" if float(p.profile["social"]) >= 0.5 else "Observe")
	p.folk.face_point(player)
	p.state = "greet"
	p.timer = 2.4 if float(p.profile["social"]) >= 0.5 else 1.5
	p.greet_cd = GREET_COOLDOWN + (1.0 - float(p.profile["social"])) * 20.0
	p.greets += 1
	p.memories["player_seen"] = elapsed
	# The destination is retained; the next decision can resume the interrupted errand.

func _release(p: Person) -> void:
	if reservations.get(p.destination, "") == p.id: reservations.erase(p.destination)
	p.destination = ""

func _choose(p: Person) -> void:
	_release(p)
	var best_score: float = -INF
	var chosen: String = "observe"
	var place: String = ""
	for activity in ACTIVITIES:
		var score: float = p.rng.randf_range(0, 0.65)
		if activity == "work": score += 0.65 if p.id in ["bald_worker", "rancher", "dressmaker", "clerk", "youth"] else 0.12
		if activity == "rest": score += float(p.profile["rest"]) * minf(1.0, p.walked_m / 18.0)
		if activity == "social": score += float(p.profile["social"]) * 0.6
		if activity in p.recent: score -= 0.7
		if activity == "social" and (_mode != "normal" or p.social_cd > 0): score -= 2.0
		if score > best_score:
			best_score = score
			chosen = activity
	var interests: Array = p.profile["interests"]
	var candidates: Array = interests.duplicate()
	if chosen == "rest": candidates = ["rest_south", "rest_north"]
	elif chosen in ["errand", "observe"]: candidates.append("notice")
	var available_interest: bool = false
	for candidate in candidates:
		if not reservations.has(candidate) and _pos(p).distance_to(navigation.closest(PLACES[candidate])) >= 2.0:
			available_interest = true
	# A popular market/notice spot can stay reserved for minutes. Take a useful
	# secondary errand instead of repeatedly "arriving" at the place already occupied.
	if not available_interest:
		for candidate in PLACES:
			if candidate not in candidates: candidates.append(candidate)
	var best_place: float = -INF
	for candidate in candidates:
		var owner: String = str(reservations.get(candidate, ""))
		if not owner.is_empty() and owner != p.id: continue
		var point: Vector2 = navigation.closest(PLACES[candidate])
		if _pos(p).distance_to(point) < 2.0: continue
		var score: float = p.rng.randf_range(0, 1) - float(p.visits.get(candidate, 0)) * .18
		if candidate in interests: score += 0.65
		if score > best_place:
			best_place = score
			place = candidate
	p.activity = chosen
	p.choices += 1
	p.activity_time = 0.0
	p.recent.append(chosen)
	if p.recent.size() > 3: p.recent.pop_front()
	if place.is_empty():
		p.state = "pause"
		p.timer = p.rng.randf_range(2, 4)
		p.folk.hold_clip("Observe")
		return
	p.destination = place
	reservations[place] = p.id
	var target: Vector2 = navigation.closest(PLACES[place])
	p.waypoints = navigation.path(_pos(p), target)
	p.state = "walk"
	p.blocked = 0.0
	if p.waypoints.is_empty(): _arrive(p)

func _arrive(p: Person) -> void:
	p.folk.stop()
	p.visits[p.destination] = int(p.visits.get(p.destination, 0)) + 1
	p.state = "pause"
	p.timer = p.rng.randf_range(5, 12)
	var clip: String = "Observe"
	if p.activity == "rest":
		clip = "Rest"
		p.timer *= 1.0 + float(p.profile["rest"])
	elif p.activity == "work": clip = "Inspect"
	p.folk.hold_clip(clip)
	if not p.destination.is_empty():
		var target: Vector2 = PLACES[p.destination]
		# Face the institution/horse, rather than staring into the last path segment.
		p.folk.face_point(Vector3(target.x + (-4.0 if target.x < 0 else 4.0), 0, target.y))

func _body_clear(point: Vector2, owner: Person, player: Vector3) -> bool:
	if not navigation.is_clear(point): return false
	if absf(player.y) < 2.2 and point.distance_to(Vector2(player.x, player.z)) < 0.68: return false
	for other in people:
		if other == owner: continue
		if point.distance_to(_pos(other)) < BODY_R * 2.0: return false
	return true

func _move(p: Person, dt: float, player: Vector3) -> void:
	var here: Vector2 = _pos(p)
	# Consume reached nodes in the same tick so the walk clip never flickers to idle at corners.
	while not p.waypoints.is_empty() and here.distance_to(p.waypoints[0]) < 0.16:
		p.waypoints.pop_front()
	if p.waypoints.is_empty():
		if p.state == "flee":
			p.state = "shelter"
			p.timer = p.rng.randf_range(3, 6)
			p.folk.hold_clip("Alert")
		else: _arrive(p)
		return
	var target: Vector2 = p.waypoints[0]
	var direction: Vector2 = (target - here).normalized()
	var speed: float = p.speed * (1.45 if p.state == "flee" else 1.0)
	var distance: float = minf(speed * dt, here.distance_to(target))
	var candidate: Vector2 = here + direction * distance
	var moved: bool = _body_clear(candidate, p, player) and navigation.segment_clear(here, candidate)
	if not moved:
		# Stable individual passing side, then alternate: no accumulated force can push through a body or wall.
		var side: float = 1.0 if int(p.id.hash()) % 2 == 0 else -1.0
		for sign_value in [side, -side]:
			var tangent: Vector2 = Vector2(-direction.y, direction.x) * float(sign_value)
			candidate = here + (direction * 0.25 + tangent).normalized() * distance
			if _body_clear(candidate, p, player) and navigation.segment_clear(here, candidate):
				moved = true
				break
	if moved:
		p.folk.walk_to(Vector3(candidate.x, 0, candidate.y), speed)
		p.folk.step(dt)
		p.folk.stop()
		p.walked_m += here.distance_to(_pos(p))
		var progress: float = here.distance_to(target) - _pos(p).distance_to(target)
		p.blocked = p.blocked + dt if progress < distance * 0.15 else maxf(0, p.blocked - dt)
	else:
		p.folk.stop()
		p.blocked += dt
	if p.blocked > 2.5:
		p.recoveries += 1
		p.blocked = 0.0
		if p.state == "flee": _seek_safety(p, p.threat, _mode == "duel")
		else:
			_release(p)
			p.state = "pause"
			p.timer = p.rng.randf_range(0.8, 2.0)

func _try_social(p: Person) -> void:
	p.social_cd = p.rng.randf_range(8, 16)
	if p.rng.randf() > float(p.profile["social"]): return
	for other in people:
		if other == p or other.state != "pause" or other.fear > 0 or other.social_cd > 0: continue
		var distance: float = _pos(p).distance_to(_pos(other))
		if distance < 0.8 or distance > 2.7: continue
		if elapsed - float(p.memories.get(other.id, -100.0)) < 60.0: continue
		if not navigation.segment_clear(_pos(p), _pos(other)): continue
		var duration: float = p.rng.randf_range(3.5, 6.5)
		for pair in [[p, other], [other, p]]:
			var a: Person = pair[0]
			var b: Person = pair[1]
			a.state = "social"
			a.partner = b.id
			a.timer = duration
			a.social_cd = 35.0 + (1.0 - float(a.profile["social"])) * 35.0
			a.memories[b.id] = elapsed
			a.folk.stop()
			a.folk.hold_clip("Talk")
		return

func _seek_safety(p: Person, danger: Vector2, duel: bool) -> void:
	_release(p)
	p.partner = ""
	p.threat = danger
	var options: Array = []
	var shelters: Array = SHELTERS.duplicate()
	if duel:
		# Clear sideways to the street verge; do not funnel thirteen people to two distant end points.
		for z in [-2.4, -1.2, 0.0, 1.2, 2.4]:
			for x in [-4.2, 4.2]: shelters.append(Vector2(x, _pos(p).y + z))
	for shelter in shelters:
		var safe: Vector2 = navigation.closest(shelter)
		var score: float = -_pos(p).distance_to(safe) if duel else safe.distance_to(danger) - _pos(p).distance_to(safe) * 0.28 + p.rng.randf_range(0, 2)
		if duel and absf(safe.x) < 3.8 and safe.y > 1412 and safe.y < 1442: continue
		if not _body_clear(safe, p, Vector3(100, 0, 1300)): continue
		var reserved: bool = false
		for other in people:
			if other != p and other.state in ["flee", "shelter"] and other.safety.distance_to(safe) < 1.0: reserved = true
		if reserved: continue
		options.append([score, safe])
	options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for option in options:
		var safe: Vector2 = option[1]
		var path: Array[Vector2] = navigation.path(_pos(p), safe)
		if path.is_empty(): continue
		p.safety = safe
		p.waypoints = path
		p.state = "flee"
		p.folk.hold_clip("Alert")
		return
	p.state = "shelter"
	p.safety = _pos(p)
	p.timer = 2.0
	p.folk.stop()
	p.folk.hold_clip("Alert")

func duel_lane_clear() -> bool:
	for p in people:
		var q: Vector2 = _pos(p)
		if absf(q.x) < 3.5 and q.y > 1413 and q.y < 1441: return false
	return true

func snapshot() -> Dictionary:
	var rows: Array = []
	for p in people:
		var path: Array = []
		for point in p.waypoints: path.append([point.x, point.y])
		rows.append({"id": p.id, "position": [_pos(p).x, _pos(p).y], "activity": p.activity, "destination": p.destination,
			"recent": p.recent.duplicate(), "visits": p.visits.duplicate(), "memories": p.memories.duplicate(),
			"greet_cd": p.greet_cd, "greets": p.greets, "walked_m": p.walked_m, "choices": p.choices,
			"rng_state": str(p.rng.state), "fear": p.fear, "social_cd": p.social_cd,
			"state": p.state, "timer": p.timer, "waypoints": path, "partner": p.partner,
			"threat": [p.threat.x, p.threat.y], "safety": [p.safety.x, p.safety.y],
			"blocked": p.blocked, "recoveries": p.recoveries, "activity_time": p.activity_time,
			"clip": p.folk._base_clip})
	return {"version": 1, "elapsed": elapsed, "people": rows, "mode": _mode}

func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -10000, 10000) and _number(value[1], -10000, 10000)

func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func restore(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("people") is Array: return false
	var rows: Array = data["people"]
	if rows.size() != people.size() or not _number(data.get("elapsed"), 0, 10000000): return false
	if data.get("mode") not in ["normal", "quiet", "duel"]: return false
	# Validate everything before touching actors, random streams or reservations.
	var seen: Dictionary = {}
	var destinations: Dictionary = {}
	var positions: Array[Vector2] = []
	for row in rows:
		if not row is Dictionary or not row.get("id") is String: return false
		var id: String = row["id"]
		if person(id) == null or seen.has(id): return false
		seen[id] = row
		if not _point(row.get("position")): return false
		var point: Vector2 = _vector(row["position"])
		if not navigation.is_clear(point): return false
		for previous in positions:
			if previous.distance_to(point) < 0.60: return false
		positions.append(point)
		if row.get("activity") not in ACTIVITIES: return false
		if row.get("state") not in ["pause", "walk", "flee", "shelter", "greet", "social"]: return false
		if row.get("clip") not in ["Idle", "Observe", "Rest", "Talk", "Inspect", "Alert", "Greet"]: return false
		var destination: Variant = row.get("destination")
		if not destination is String or (destination != "" and not PLACES.has(destination)): return false
		if destination != "":
			if destinations.has(destination): return false
			destinations[destination] = id
		if not row.get("partner") is String or (row["partner"] != "" and person(row["partner"]) == null): return false
		if not _point(row.get("threat")) or not _point(row.get("safety")): return false
		if not row.get("recent") is Array or row["recent"].size() > 3: return false
		for activity in row["recent"]:
			if activity not in ACTIVITIES: return false
		for key in ["visits", "memories"]:
			if not row.get(key) is Dictionary or row[key].size() > 32: return false
			for entry in row[key]:
				if not entry is String: return false
				if key == "visits" and not PLACES.has(entry): return false
				if key == "memories" and entry not in ["player_seen", "last_danger"] and person(entry) == null: return false
				if not _number(row[key][entry], 0, 10000000): return false
				if key == "memories" and float(row[key][entry]) > float(data["elapsed"]): return false
		for key in ["greet_cd", "social_cd", "fear", "timer", "blocked", "activity_time", "walked_m", "greets", "choices", "recoveries"]:
			if not _number(row.get(key), -1 if key == "timer" else 0, 10000000): return false
		for key in ["greet_cd", "social_cd", "fear", "timer", "blocked"]:
			if float(row[key]) > 120: return false
		var random_state: Variant = row.get("rng_state")
		if not random_state is String or random_state.length() > 20 or not random_state.is_valid_int(): return false
		if str(int(random_state)) != random_state: return false
		if not row.get("waypoints") is Array or row["waypoints"].size() > 128: return false
		var previous: Vector2 = point
		for waypoint in row["waypoints"]:
			if not _point(waypoint): return false
			var next: Vector2 = _vector(waypoint)
			if not navigation.segment_clear(previous, next): return false
			previous = next
	for row in rows:
		if row["state"] == "social":
			var partner: Dictionary = seen.get(row["partner"], {})
			if partner.get("state") != "social" or partner.get("partner") != row["id"]: return false
	reservations = destinations
	elapsed = float(data["elapsed"])
	_mode = data["mode"]
	_story_was_duel = _mode == "duel"
	for row in rows:
		var p: Person = person(row["id"])
		var point: Vector2 = _vector(row["position"])
		p.folk.place(Vector3(point.x, 0, point.y))
		p.activity = row["activity"]
		p.recent.assign(row["recent"])
		p.visits = row["visits"].duplicate()
		p.memories = row["memories"].duplicate()
		p.greet_cd = float(row["greet_cd"])
		p.social_cd = float(row["social_cd"])
		p.greets = int(row["greets"])
		p.choices = int(row["choices"])
		p.walked_m = float(row["walked_m"])
		p.rng.state = int(row["rng_state"])
		p.fear = float(row["fear"])
		p.state = row["state"]
		p.timer = float(row["timer"])
		p.destination = row["destination"]
		p.partner = row["partner"]
		p.threat = _vector(row["threat"])
		p.safety = _vector(row["safety"])
		p.blocked = float(row["blocked"])
		p.recoveries = int(row["recoveries"])
		p.activity_time = float(row["activity_time"])
		p.waypoints.clear()
		for waypoint in row["waypoints"]: p.waypoints.append(_vector(waypoint))
		p.folk.hold_clip(row["clip"])
	return true
