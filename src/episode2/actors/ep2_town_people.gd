class_name Ep2TownPeople
extends RefCounted
## THE TOWN'S TOWNSMEN AND TOWNSWOMEN (founder 2026-10-19: "we're lacking townsmen and townswomen"; skill ep2-town-people).
##
## Five rigged people (tools/ep2_blender/build_townfolk.py, streamed with the Episode 2 extras: Ep2Extras.PEOPLE_DIR) live on Main
## Street: a clerk, an old-timer, a rancher, a dressmaker and a lady. Each walks its own route along the open middle of the street
## (never through a hitching rail, horse, trough, wagon, lamp or wall: the routes are tested against the town's own props and walls),
## stops to idle at its ends and at random points, and when Lil Blunt comes within GREET_R turns to him, plays Greet once, and goes
## on with its day. Pure logic over Ep2TownFolk (clips Idle / Walk / Greet / Point / Carry); a fixed seed replays exactly.
## Missing GLBs (the extras not mounted yet) simply mean nobody is out: the town stays as it was.

const GREET_R := 3.6              # m: how close he must come to be noticed
const GREET_COOLDOWN := 18.0      # s: a person greets the same passer-by once in a while, not every step
## id, file, height, [route points (x, z)], walk speed m/s, pause range s, idle clip while pausing
const ROSTER: Array = [
	{"id": "clerk", "file": "townsman_clerk.glb", "h": 1.76, "route": [Vector2(-2.6, 1408.5), Vector2(-2.6, 1423.0), Vector2(-2.6, 1437.0)], "speed": 0.95, "pause": [3.0, 8.0]},
	{"id": "oldtimer", "file": "townsman_oldtimer.glb", "h": 1.69, "route": [Vector2(2.6, 1424.0), Vector2(2.6, 1437.0), Vector2(1.2, 1444.0)], "speed": 0.78, "pause": [5.0, 12.0]},
	{"id": "rancher", "file": "townsman_rancher.glb", "h": 1.84, "route": [Vector2(2.9, 1431.0), Vector2(0.4, 1421.0), Vector2(2.9, 1431.0), Vector2(-0.8, 1436.0)], "speed": 1.05, "pause": [6.0, 14.0]},
	{"id": "dressmaker", "file": "townswoman_dressmaker.glb", "h": 1.66, "route": [Vector2(1.0, 1409.5), Vector2(1.0, 1427.0), Vector2(1.0, 1445.0)], "speed": 0.88, "pause": [2.5, 6.0]},
	{"id": "lady", "file": "townswoman_lady.glb", "h": 1.72, "route": [Vector2(-0.6, 1444.0), Vector2(-0.6, 1428.0), Vector2(-0.6, 1411.0)], "speed": 0.82, "pause": [4.0, 9.0]},
]

class Person:
	var id: String = ""
	var folk: Ep2TownFolk = null
	var route: Array = []
	var idx: int = 0
	var dir: int = 1
	var speed: float = 1.0
	var pause_range: Vector2 = Vector2(3.0, 8.0)
	var state: String = "pause"          # pause | walk | greet
	var timer: float = 1.0
	var greet_cd: float = 0.0
	var greets: int = 0
	var walked_m: float = 0.0

var people: Array = []
var rng := RandomNumberGenerator.new()


## Build whoever is available into `parent` (a Node3D in world space). Returns the number of people placed.
func build(parent: Node3D, seed_value: int = 4101) -> int:
	rng.seed = seed_value
	for r in ROSTER:
		var path: String = Ep2Extras.PEOPLE_DIR + str(r["file"])
		if not Ep2Extras.has(path):
			continue
		var p := Person.new()
		p.id = str(r["id"])
		p.folk = Ep2TownFolk.new()
		p.folk.name = "Person_" + p.id
		parent.add_child(p.folk)
		if not p.folk.setup(path, float(r["h"]), Color(0.4, 0.3, 0.2)):
			p.folk.queue_free()
			continue
		p.route = r["route"]
		p.speed = float(r["speed"])
		p.pause_range = Vector2(float((r["pause"] as Array)[0]), float((r["pause"] as Array)[1]))
		p.idx = rng.randi() % p.route.size()
		var start: Vector2 = p.route[p.idx]
		p.folk.place(Vector3(start.x, 0.0, start.y))
		p.folk.face_yaw(rng.randf() * TAU)
		p.timer = rng.randf_range(0.5, p.pause_range.y)          # they do not all stand up and set off together
		people.append(p)
	return people.size()


func step(delta: float, player_world: Vector3) -> void:
	for p in people:
		var pp := p as Person
		var before: Vector3 = pp.folk.position
		_step_one(pp, delta, player_world)
		pp.folk.step(delta)
		pp.walked_m += Vector2(pp.folk.position.x - before.x, pp.folk.position.z - before.z).length()


func _step_one(p: Person, delta: float, player_world: Vector3) -> void:
	p.greet_cd = maxf(0.0, p.greet_cd - delta)
	var here: Vector3 = p.folk.position
	var near: bool = Vector2(here.x - player_world.x, here.z - player_world.z).length() < GREET_R and absf(player_world.y - here.y) < 3.0
	match p.state:
		"greet":
			p.timer -= delta
			p.folk.face_point(player_world)
			if p.timer <= 0.0:
				p.state = "pause"
				p.timer = rng.randf_range(1.0, 3.0)
				p.folk.hold_clip("Idle")
		"pause":
			p.timer -= delta
			if near and p.greet_cd <= 0.0:
				p.folk.stop()
				p.folk.face_point(player_world)
				p.folk.hold_clip("Greet")
				p.greets += 1
				p.greet_cd = GREET_COOLDOWN
				p.state = "greet"
				p.timer = 2.4
			elif p.timer <= 0.0:
				_next_leg(p)
		"walk":
			if not p.folk.is_walking():
				p.state = "pause"
				p.timer = rng.randf_range(p.pause_range.x, p.pause_range.y)
				p.folk.hold_clip("Idle")
			elif near and p.greet_cd <= 0.0:
				p.folk.stop()
				p.folk.face_point(player_world)
				p.folk.hold_clip("Greet")
				p.greets += 1
				p.greet_cd = GREET_COOLDOWN
				p.state = "greet"
				p.timer = 2.4


func _next_leg(p: Person) -> void:
	# ping-pong along the route; now and then turn round early so no two people keep the same rhythm
	if p.idx + p.dir >= p.route.size() or p.idx + p.dir < 0 or rng.randf() < 0.15:
		p.dir = -p.dir
	p.idx = clampi(p.idx + p.dir, 0, p.route.size() - 1)
	var to: Vector2 = p.route[p.idx]
	p.folk.walk_to(Vector3(to.x, 0.0, to.y), p.speed)
	p.state = "walk"
