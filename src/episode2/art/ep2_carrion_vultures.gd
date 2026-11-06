class_name Ep2CarrionVultures
extends Node3D
## VULTURES AT THE CARCASSES (founder 2026-11-02): on the road to Logan's Lake what Lil Blunt leaves dead draws the birds, and not at once. A while
## after a death, and only while he is well away from the body, one or two turkey vultures spiral down, land beside it and hop and peck. They lift
## off if he rides close or fires near them, and come back later once he has gone. A bird can also be shot out of the air or off the carcass:
## one hit leaves it labouring, the second folds it and drops it on the ground.
##
## The room reports the deaths (add_body), shots that pass near (notify_shot) and the actual shot ray (shoot); this node owns the birds.
## Seeded, so tests can drive it.

signal bird_hit(at: Vector3, killed: bool)
signal bird_down(at: Vector3)

const DELAY_MIN := 20.0                   # seconds from a death to the first bird
const DELAY_MAX := 40.0
const BODY_CLEAR := 25.0                  # no bird comes down while he is closer than this
const SCARE_RIDE := 12.0                  # he rides this close: they lift off
const SCARE_SHOT := 10.0                  # a shot passing this close to a bird lifts it off
const MAX_FEEDERS := 4                    # birds coming down or on the ground, over the whole trail
const MAX_AT_BODY := 2
const DESCEND_S := 9.0
const FLEE_S := 7.0
const DESCEND_FROM := 28.0                # height the spiral starts at (the flock's own thermal)
const BIRD_SCALE := 1.25
const HP := 2                             # a wing hit is survivable; a second brings it down
const HIT_RADIUS := 0.62
const DOWN_SECONDS := 14.0
const CRY := "res://src/episode2/extras/audio/trail/vulture_cry.ogg"
const CRY_FALLBACK := "res://src/assets/sounds/ep2_bird_call_1.mp3"

var bodies: Array = []                    # [{pos, radius, wait, birds}]
var birds: Array = []                     # [{node, model, neck, body, health, state, t, phase, spot, centre, from, wounded, down_t}]
var _rng := RandomNumberGenerator.new()
var _cry: AudioStreamPlayer3D = null


func _init() -> void:
	_rng.seed = 1893


## Something died at `at`. `radius` is how far from its centre a bird stands (a bison is wide).
func add_body(at: Vector3, radius: float = 0.8) -> void:
	bodies.append({"pos": at, "radius": radius, "wait": _rng.randf_range(DELAY_MIN, DELAY_MAX), "birds": 0})


## A failed attempt restages the trail: the dead get up, the birds go.
func clear() -> void:
	for b in birds:
		(b["node"] as Node3D).queue_free()
	birds.clear()
	bodies.clear()


## How many birds are on their way down or on the ground (the perf cap counts these).
func feeders() -> int:
	var n: int = 0
	for b in birds:
		if str(b["state"]) in ["descend", "feed"]:
			n += 1
	return n


## How many are down and eating.
func feeding() -> int:
	var n: int = 0
	for b in birds:
		if str(b["state"]) == "feed":
			n += 1
	return n


func alive_count() -> int:
	var n: int = 0
	for b in birds:
		if str(b["state"]) != "down":
			n += 1
	return n


## He fired along this ray: any bird it passes close to lifts off, with the others at its body. This is the near-miss scare;
## `shoot()` is the ray that actually wounds or kills one.
func notify_shot(eye: Vector3, dir: Vector3) -> void:
	var d: Vector3 = dir.normalized()
	for b in birds:
		if str(b["state"]) in ["flee", "down"]:
			continue
		var p: Vector3 = (b["node"] as Node3D).global_position
		var along: float = maxf((p - eye).dot(d), 0.0)
		if (eye + d * along).distance_to(p) < SCARE_SHOT:
			_scare(int(b["body"]))


## Distance along the ray to the nearest bird that can still be hit, or -1. Hits nothing.
func ray_distance(eye: Vector3, dir: Vector3) -> float:
	return _nearest(eye, dir.normalized())[1]


## The actual shot ray. `damage` is the round's weight (a buffalo gun kills outright). Returns the hit distance, or -1. A wounded bird
## labours away; a killed bird drops where it was hit, and the others at that body lift off.
func shoot(eye: Vector3, dir: Vector3, damage: int = 1) -> float:
	var near: Array = _nearest(eye, dir.normalized())
	var best: int = near[0]
	if best < 0:
		return -1.0
	var b: Dictionary = birds[best]
	var at: Vector3 = (b["node"] as Node3D).global_position
	var health: Ep2CreatureHealth = b["health"]
	Ep2VultureMesh.feather_puff(self, at + Vector3(0.0, 0.3, 0.0), 22 if health.hp <= damage else 12)
	if health.take_hit(damage, at):
		b["state"] = "down"
		b["down_t"] = 0.0
		Ep2VultureMesh.fold(b["model"])
		bodies[int(b["body"])]["birds"] = maxi(0, int(bodies[int(b["body"])]["birds"]) - 1)
		_scare(int(b["body"]))
		bird_hit.emit(at, true)
		bird_down.emit(at)
	else:
		b["wounded"] = true
		_scare(int(b["body"]))
		_call_from(at)
		bird_hit.emit(at, false)
	return near[1]


## True when a bird is under the ray (the HUD sight turns red).
func under_sight(eye: Vector3, dir: Vector3) -> bool:
	return ray_distance(eye, dir) >= 0.0


## [index, distance] of the nearest bird on the ray that is not already down.
func _nearest(eye: Vector3, d: Vector3) -> Array:
	var best: int = -1
	var best_t: float = -1.0
	for i in birds.size():
		if str(birds[i]["state"]) == "down":
			continue
		var at: Vector3 = (birds[i]["node"] as Node3D).global_position + Vector3(0.0, 0.30, 0.0)
		var t: float = _ray_sphere(eye, d, at, HIT_RADIUS)
		if t >= 0.0 and (best < 0 or t < best_t):
			best_t = t
			best = i
	return [best, best_t]


func _call_from(at: Vector3) -> void:
	if _cry == null:
		_cry = AudioStreamPlayer3D.new()
		_cry.name = "VultureCry"
		_cry.bus = "SFX"
		_cry.unit_size = 22.0
		_cry.max_distance = 150.0
		_cry.volume_db = -14.0
		add_child(_cry)
		var path: String = CRY if ResourceLoader.exists(CRY) else CRY_FALLBACK
		_cry.stream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if _cry.stream != null:
		_cry.global_position = at
		_cry.play()


func step(delta: float, player: Vector3) -> void:
	for i in bodies.size():
		var body: Dictionary = bodies[i]
		var flat: Vector3 = (body["pos"] as Vector3) - player
		flat.y = 0.0
		var gap: float = flat.length()
		if int(body["birds"]) > 0 and gap < SCARE_RIDE:
			_scare(i)
		body["wait"] = maxf(0.0, float(body["wait"]) - delta)
		if float(body["wait"]) <= 0.0 and int(body["birds"]) == 0 and gap >= BODY_CLEAR:
			var want: int = mini(_rng.randi_range(1, MAX_AT_BODY), MAX_FEEDERS - feeders())
			for k in want:
				_send_bird(i)
	for j in range(birds.size() - 1, -1, -1):
		var b: Dictionary = birds[j]
		if str(b["state"]) != "down":
			b["t"] = float(b["t"]) + delta
		match str(b["state"]):
			"descend":
				_fly_down(b)
			"feed":
				_eat(b)
			"flee":
				if _fly_off(b):
					(b["node"] as Node3D).queue_free()
					birds.remove_at(j)
			"down":
				if _fall_dead(b, delta):
					(b["node"] as Node3D).queue_free()
					birds.remove_at(j)


func _scare(index: int) -> void:
	var body: Dictionary = bodies[index]
	for b in birds:
		if int(b["body"]) == index and str(b["state"]) not in ["flee", "down"]:
			b["state"] = "flee"
			b["t"] = 0.0
			b["from"] = (b["node"] as Node3D).position
			_set_wings(b, true)
	body["birds"] = 0
	body["wait"] = _rng.randf_range(DELAY_MIN, DELAY_MAX)      # they come back later, if he has gone


func _send_bird(index: int) -> void:
	var body: Dictionary = bodies[index]
	var a: float = _rng.randf_range(0.0, TAU)
	var spot: Vector3 = (body["pos"] as Vector3) + Vector3(cos(a), 0.0, sin(a)) * float(body["radius"])
	var node: Node3D = _make_bird()
	add_child(node)
	var b: Dictionary = {"node": node, "model": node.get_node("Model"), "neck": node.get_node("Model/Neck"), "body": index,
		"health": Ep2CreatureHealth.attach(node, HP), "state": "descend", "t": 0.0, "phase": _rng.randf_range(0.0, TAU), "spot": spot,
		"centre": body["pos"], "from": spot, "wounded": false, "down_t": 0.0}
	birds.append(b)
	body["birds"] = int(body["birds"]) + 1
	_set_wings(b, true)
	_fly_down(b)


## The spiral: wide and high to tight and low, ending exactly on its spot.
func _fly_down(b: Dictionary) -> void:
	var k: float = clampf(float(b["t"]) / DESCEND_S, 0.0, 1.0)
	var ease_k: float = 1.0 - (1.0 - k) * (1.0 - k)
	var r: float = lerpf(15.0, 0.0, ease_k)
	var a: float = float(b["phase"]) + ease_k * TAU * 2.0
	var node: Node3D = b["node"]
	var spot: Vector3 = b["spot"]
	node.position = spot + Vector3(cos(a) * r, lerpf(DESCEND_FROM, 0.0, ease_k), sin(a) * r)
	node.rotation = Vector3(0.0, -a, 0.25 * (1.0 - k))        # along the turn, banked into it
	_flap(b, 0.6)
	if k >= 1.0:
		b["state"] = "feed"
		b["t"] = 0.0
		_set_wings(b, false)
		var to: Vector3 = (b["centre"] as Vector3) - spot
		node.rotation = Vector3(0.0, atan2(-to.x, -to.z), 0.0)


## On the ground: a head down in pecks and a small hop now and then.
func _eat(b: Dictionary) -> void:
	var t: float = float(b["t"]) + float(b["phase"])
	var node: Node3D = b["node"]
	(b["neck"] as Node3D).rotation.x = -0.25 - 0.75 * maxf(0.0, sin(t * 5.0)) * (0.5 + 0.5 * sin(t * 0.9))
	var hop: float = fposmod(t, 3.1)
	node.position = (b["spot"] as Vector3) + Vector3(0.0, 0.16 * sin(minf(hop / 0.3, 1.0) * PI), 0.0)


## Up and out in a widening climb. True when it has gone. A wounded bird climbs lower and slower.
func _fly_off(b: Dictionary) -> bool:
	var wounded: bool = bool(b.get("wounded", false))
	var k: float = clampf(float(b["t"]) / (FLEE_S * (1.65 if wounded else 1.0)), 0.0, 1.0)
	var a: float = float(b["phase"]) + k * TAU * 1.2
	var node: Node3D = b["node"]
	var climb: float = k * k * DESCEND_FROM * (0.55 if wounded else 1.4)
	node.position = (b["from"] as Vector3) + Vector3(cos(a) * k * 22.0, climb, sin(a) * k * 22.0)
	node.rotation = Vector3(-0.3 * (1.0 - k), -a, 0.2 + (0.18 * sin(float(b["t"]) * 4.0) if wounded else 0.0))
	_flap(b, 1.0 if not wounded else 0.55)
	return k >= 1.0


## A killed bird: wings folded, gravity takes it to the ground beside the body it came for, then it lies there for DOWN_SECONDS.
func _fall_dead(b: Dictionary, delta: float) -> bool:
	var node: Node3D = b["node"]
	var dt: float = float(b["down_t"]) + delta
	b["down_t"] = dt
	if not bool(b.get("settled", false)):
		var ground: float = (b["spot"] as Vector3).y
		var vy: float = float(b.get("vy", 0.0)) - 9.4 * delta
		b["vy"] = vy
		node.position.y = maxf(ground, node.position.y + vy * delta)
		node.rotation.x += delta * 2.2
		node.rotation.z += delta * 1.5
		if node.position.y <= ground:
			b["settled"] = true
			node.rotation = Vector3(-0.08, node.rotation.y, 0.26)
			var model: Node3D = b["model"]
			model.rotation.x = 0.0
			model.position.y = Ep2VultureMesh.LYING_HEIGHT * BIRD_SCALE
			Ep2VultureMesh.slump(model)
			b["down_t"] = 0.0
	return bool(b.get("settled", false)) and dt >= DOWN_SECONDS


func _ray_sphere(eye: Vector3, dir: Vector3, centre: Vector3, radius: float) -> float:
	var oc: Vector3 = eye - centre
	var b: float = oc.dot(dir)
	var c: float = oc.length_squared() - radius * radius
	var disc: float = b * b - c
	if disc < 0.0:
		return -1.0
	var root: float = sqrt(disc)
	var t: float = -b - root
	if t < 0.02:
		t = -b + root
	return t if t >= 0.02 else -1.0


func _flap(b: Dictionary, amount: float) -> void:
	Ep2VultureMesh.flap(b["model"], float(b["t"]) * 7.0 + float(b["phase"]), amount * 0.62)


## Spread and level for the air; on the ground it stands chest up with its wings folded back along the body.
func _set_wings(b: Dictionary, open: bool) -> void:
	var model: Node3D = b["model"]
	model.rotation.x = 0.0 if open else Ep2VultureMesh.PERCH_PITCH
	if open:
		Ep2VultureMesh.spread(model)
	else:
		Ep2VultureMesh.fold(model)


## The trail's one vulture (`Ep2VultureMesh`), carried on the root so `position` is the ground under its feet.
func _make_bird() -> Node3D:
	var root := Node3D.new()
	root.name = "Vulture"
	var model := Ep2VultureMesh.build(BIRD_SCALE)
	model.name = "Model"
	model.position.y = Ep2VultureMesh.PERCH_HEIGHT * BIRD_SCALE
	root.add_child(model)
	return root
