class_name Ep2TrailVultures
extends Node3D
## The five turkey vultures over the lake approach. They share ONE thermal: a single slow turn with each bird holding its slot in
## it, the column drifting over the desert, flapping in short bursts and gliding between them. The old flock was scenery with no
## body: a cross of flat triangles that could not be hit. These birds share `Ep2VultureMesh`, carry `Ep2CreatureHealth`, and answer
## the room's shot ray.
##
## A hit makes the bird sag out of the thermal - lower, wider, falling behind its slot, one wing working harder. A second hit (or one
## buffalo-gun round) puts it down: the wings fold, it falls on with the speed it had, hits the ground and lies there a while before
## the body is retired. Shooting does not remove the rest of the flock, and a trail retry calls `reset_flock()` and puts all five
## back in the air.
##
## The room sets `listener` each tick; the faint wind-over-feathers loop and the rare hiss only play while it does and he is under
## them, so a room still being prebuilt behind the current one stays silent.

signal bird_hit(at: Vector3, killed: bool)
signal bird_down(at: Vector3)

const COUNT := 5
const HP := 2                             # one hit wounds, the second puts it down
const AUDIO_DIR := "res://src/episode2/extras/audio/trail/"
const WINGS := AUDIO_DIR + "vulture_wings.ogg"
const CRY := AUDIO_DIR + "vulture_cry.ogg"
const WINGS_FALLBACK := "res://src/assets/sounds/ep2_birds_flutter.mp3"
const CRY_FALLBACK := "res://src/assets/sounds/ep2_bird_call_1.mp3"
const THERMAL_RATE := 0.21                # rad/s of the shared turn
const BODY_RADIUS := 0.5                  # body and each wing: a bird at 30-60 m is a fair target
const WING_REACH := 0.85
const CORPSE_SECONDS := 20.0
const GROUND_Y := 0.11                    # the trail's desert is the flat y = 0 plane, and the flock stands on the route
const FALL_GRAVITY := 9.4
const HEAR_RANGE := 165.0
const WOUND_SAG := 7.0
const WOUND_WIDEN := 8.0

var birds: Array[Node3D] = []
var phase: float = 0.0
var listener: Vector3 = Vector3.ZERO:
	set(value):
		listener = value
		_heard_t = 0.4

var _states: Array = []
var _rng := RandomNumberGenerator.new()
var _wings: AudioStreamPlayer3D = null
var _cry: AudioStreamPlayer3D = null
var _cry_t: float = 2.5
var _heard_t: float = 0.0


func _init() -> void:
	_rng.seed = 1914


func _ready() -> void:
	_build_birds()
	_build_audio()


func _build_birds() -> void:
	for i in COUNT:
		var node := Ep2VultureMesh.build(1.08 + float(i) * 0.035)
		node.name = "Vulture%d" % i
		add_child(node)
		birds.append(node)
		var st: Dictionary = {
			"node": node, "health": Ep2CreatureHealth.attach(node, HP),
			"radius": 15.0 + float(i) * 1.6,
			"height": 26.0 + float(i) * 2.05,
			"wounded": false, "dead": false, "dead_t": 0.0, "settled": false, "velocity": Vector3.ZERO,
			"sag": 0.0, "lag": 0.0,
		}
		_scatter(st, i)
		_states.append(st)
		_place(st)


## Each bird's slot in the turn and its own wing rhythm; the same seed restages the same flock.
func _scatter(st: Dictionary, index: int) -> void:
	st["slot"] = float(index) * TAU / float(COUNT) + _rng.randf_range(-0.22, 0.22)
	st["seed"] = _rng.randf_range(0.0, TAU)
	st["flap_t"] = _rng.randf_range(0.0, 12.0)
	st["t"] = _rng.randf_range(0.0, 30.0)


func _build_audio() -> void:
	_wings = _voice("VultureWings", 40.0, 190.0, WINGS_GLIDE_DB, _stream(WINGS, WINGS_FALLBACK))
	if _wings.stream is AudioStreamOggVorbis:
		(_wings.stream as AudioStreamOggVorbis).loop = true
	_cry = _voice("VultureCry", 30.0, 190.0, -5.0, _stream(CRY, CRY_FALLBACK))


func _voice(label: String, unit: float, reach: float, db: float, stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = label
	p.bus = "SFX"
	p.unit_size = unit
	p.max_distance = reach
	p.volume_db = db
	p.stream = stream
	add_child(p)
	return p


func _stream(path: String, fallback: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if ResourceLoader.exists(fallback):
		return load(fallback) as AudioStream
	return null


func _process(delta: float) -> void:
	phase += delta * THERMAL_RATE
	_heard_t = maxf(0.0, _heard_t - delta)
	var alive: int = 0
	for st in _states:
		st["t"] = float(st["t"]) + delta
		if bool(st["dead"]):
			_fall(st, delta)
			continue
		alive += 1
		_fly(st, delta)
	_tick_audio(alive, delta)


func _fly(st: Dictionary, delta: float) -> void:
	var wounded: bool = bool(st["wounded"])
	var t: float = float(st["t"])
	if wounded:
		st["sag"] = move_toward(float(st["sag"]), 1.0, delta * 0.45)
		st["lag"] = float(st["lag"]) + delta * THERMAL_RATE * 0.38     # it cannot hold its place in the turn
	_place(st)
	var node: Node3D = st["node"]
	var seed_v: float = float(st["seed"])
	var flap_amount: float = _flap_amount(st)
	st["flap_t"] = float(st["flap_t"]) + delta * (11.0 if wounded else 8.2)
	node.rotation.z = -0.24 + (0.16 * sin(t * 3.1) if wounded else 0.03 * sin(t * 0.7 + seed_v))   # the inside wing dropped into the turn
	Ep2VultureMesh.flap(node, float(st["flap_t"]), flap_amount)


## How hard it is beating now. Founder 2026-11-17: "we don't see their wings flapping" - bursts of full wingbeats most of
## the time and a working beat between them, never a frozen cut-out gliding round the thermal. Wounded, it fights the air.
func _flap_amount(st: Dictionary) -> float:
	var t: float = float(st["t"])
	if bool(st["wounded"]):
		return 0.62 + 0.22 * sin(t * 5.7)
	return clampf(sin(t * 0.55 + float(st["seed"])) * 1.6 + 0.35, 0.3, 1.0)


## Its place in the shared thermal, facing along the turn.
func _place(st: Dictionary) -> void:
	var angle: float = phase + float(st["slot"]) - float(st["lag"]) + sin(float(st["t"]) * 0.23 + float(st["seed"])) * 0.06
	var sag: float = float(st["sag"])
	var radius: float = float(st["radius"]) + sag * WOUND_WIDEN
	var column := Vector3(cos(phase * 0.17) * 7.0, 0.0, sin(phase * 0.13) * 7.0)     # the thermal itself drifts over the desert
	var y: float = float(st["height"]) + sin(float(st["t"]) * 0.4 + float(st["seed"])) * 0.9 - sag * WOUND_SAG
	y -= sin(float(st["flap_t"])) * 0.1 * _flap_amount(st)        # each downbeat lifts the body: the flap carries weight
	var node: Node3D = st["node"]
	node.position = column + Vector3(cos(angle) * radius, y, sin(angle) * radius)
	var tangent := Vector3(-sin(angle), 0.0, cos(angle))
	# The model noses along -Z, so turn -Z onto the tangent of the circle.
	node.rotation.y = atan2(-tangent.x, -tangent.z)
	node.rotation.x = 0.03 * sin(angle * 1.3)


func _fall(st: Dictionary, delta: float) -> void:
	var node: Node3D = st["node"]
	var t: float = float(st["dead_t"]) + delta
	st["dead_t"] = t
	if not bool(st["settled"]):
		var v: Vector3 = st["velocity"]
		v.y -= FALL_GRAVITY * delta
		var drag: float = clampf(1.0 - delta * 0.35, 0.0, 1.0)
		v.x *= drag
		v.z *= drag
		st["velocity"] = v
		node.position += v * delta
		node.rotation.x += delta * 2.4
		node.rotation.z += delta * 1.7
		if node.position.y <= GROUND_Y:
			st["settled"] = true
			node.position.y = GROUND_Y
			node.rotation = Vector3(-0.08, node.rotation.y, 0.26)
			Ep2VultureMesh.slump(node)
			st["dead_t"] = 0.0
	elif t >= CORPSE_SECONDS:
		node.visible = false                # the body stops drawing so a long ride costs nothing


## THE WINGBEATS ARE HEARD (founder 2026-11-22: "The vultures need sound"): the wing loop used to hum at a flat -11 dB whatever the birds
## did. It now swells on each downbeat of the bird nearest him (louder the harder it beats) and drops to a whisper in a glide, from that bird.
const WINGS_GLIDE_DB := -24.0
const WINGS_BEAT_DB := -1.0
var wing_plays: int = 0                   # how many times the wing sound started (gates read these)
var cry_plays: int = 0
var wing_peak_db: float = -80.0           # the loudest the wings got while he was in range


func _tick_audio(alive: int, delta: float) -> void:
	var near: bool = _heard_t > 0.0 and alive > 0 and listener.distance_to(global_position) < HEAR_RANGE
	if _wings != null:
		if near and not _wings.playing and _wings.stream != null:
			_wings.play()
			wing_plays += 1
		elif not near and _wings.playing:
			_wings.stop()
		var st: Dictionary = _nearest_state()
		_wings.position = (st["node"] as Node3D).position if not st.is_empty() else Vector3(0.0, 23.0, 0.0)   # from the bird closest to him
		if not st.is_empty():
			var down: float = maxf(0.0, -cos(float(st["flap_t"])))       # the downbeat half of the stroke
			var beat: float = _flap_amount(st) * (0.3 + 0.7 * down)
			_wings.volume_db = lerpf(WINGS_GLIDE_DB, WINGS_BEAT_DB, clampf(beat, 0.0, 1.0))
			if near: wing_peak_db = maxf(wing_peak_db, _wings.volume_db)
	_cry_t -= delta
	if _cry_t <= 0.0:
		_cry_t = _rng.randf_range(4.5, 9.5)
		if near and listener.distance_to(global_position) < _cry.max_distance:
			var pick: int = _rng.randi_range(0, birds.size() - 1)
			if not bool(_states[pick]["dead"]):
				_call_from(birds[pick])


func _nearest_state() -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	var here: Vector3 = to_local(listener) if is_inside_tree() else listener
	for st in _states:
		if bool(st["dead"]):
			continue
		var d: float = (st["node"] as Node3D).position.distance_to(here)
		if d < best_d:
			best_d = d
			best = st
	return best


func _nearest_bird_local() -> Vector3:
	var best := Vector3(0.0, 23.0, 0.0)
	var best_d: float = INF
	var here: Vector3 = to_local(listener) if is_inside_tree() else listener
	for st in _states:
		if bool(st["dead"]):
			continue
		var d: float = (st["node"] as Node3D).position.distance_to(here)
		if d < best_d:
			best_d = d
			best = (st["node"] as Node3D).position
	return best


func _call_from(bird: Node3D) -> void:
	if _cry != null and _cry.stream != null and is_inside_tree():
		_cry.global_position = bird.global_position
		_cry.play()
		cry_plays += 1


## Distance along the ray to the nearest living bird, or -1. Hits nothing.
func ray_distance(eye: Vector3, dir: Vector3) -> float:
	return _nearest(eye, dir.normalized())[1]


## A shot along a ray. `damage` is the round's weight (a buffalo gun kills outright). Returns the distance to the bird hit, or -1.
func shoot(eye: Vector3, dir: Vector3, damage: int = 1) -> float:
	var near: Array = _nearest(eye, dir.normalized())
	var best: int = near[0]
	if best < 0:
		return -1.0
	var st: Dictionary = _states[best]
	var at: Vector3 = birds[best].global_position
	var health: Ep2CreatureHealth = st["health"]
	Ep2VultureMesh.feather_puff(self, at, 22 if health.hp <= damage else 12)
	if health.take_hit(damage, at):
		_kill(st, at)
	else:
		st["wounded"] = true
		_call_from(birds[best])
		bird_hit.emit(at, false)
	return near[1]


## True when a living bird is under the ray (the HUD sight turns red).
func under_sight(eye: Vector3, dir: Vector3) -> bool:
	return ray_distance(eye, dir) >= 0.0


func alive_count() -> int:
	var n: int = 0
	for st in _states:
		if not bool(st["dead"]):
			n += 1
	return n


## A retry restages the trail: every bird is back in the thermal, unhurt.
func reset_flock() -> void:
	_rng.seed = 1914
	phase = 0.0
	for i in _states.size():
		var st: Dictionary = _states[i]
		(st["health"] as Ep2CreatureHealth).configure(HP)
		st["wounded"] = false
		st["dead"] = false
		st["settled"] = false
		st["dead_t"] = 0.0
		st["velocity"] = Vector3.ZERO
		st["sag"] = 0.0
		st["lag"] = 0.0
		_scatter(st, i)
		var node: Node3D = st["node"]
		node.visible = true
		node.rotation = Vector3.ZERO
		Ep2VultureMesh.spread(node)
		_place(st)


func _kill(st: Dictionary, at: Vector3) -> void:
	st["dead"] = true
	st["dead_t"] = 0.0
	st["settled"] = false
	var node: Node3D = st["node"]
	# It keeps the way it was flying: a bird does not stop in the air when it is shot.
	var along := -node.global_transform.basis.z
	along.y = 0.0
	st["velocity"] = along.normalized() * float(st["radius"]) * THERMAL_RATE
	node.rotation.z = 0.0
	Ep2VultureMesh.fold(node)
	bird_hit.emit(at, true)
	bird_down.emit(at)


## [index, distance] of the nearest living bird on the ray: a sphere for the body and one on each wing.
func _nearest(eye: Vector3, d: Vector3) -> Array:
	var best: int = -1
	var best_t: float = -1.0
	for i in birds.size():
		if bool(_states[i]["dead"]) or not birds[i].visible:
			continue
		var c: Vector3 = birds[i].global_position
		var reach: Vector3 = birds[i].global_transform.basis.x.normalized() * WING_REACH
		for centre: Vector3 in [c, c - reach, c + reach]:
			var t: float = _ray_sphere(eye, d, centre, BODY_RADIUS)
			if t >= 0.0 and (best < 0 or t < best_t):
				best_t = t
				best = i
	return [best, best_t]


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
