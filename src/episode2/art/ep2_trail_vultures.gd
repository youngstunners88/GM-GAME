class_name Ep2TrailVultures
extends Node3D
## The five turkey vultures over the lake approach. They ride a thermal in one loose, banked circle, flapping in short bursts and
## gliding between them. The old flock was scenery with no body: a cross of flat triangles that could not be hit. These birds share
## `Ep2VultureMesh`, carry `Ep2CreatureHealth`, and answer the room's shot ray.
##
## A hit makes the bird slide out of the thermal - lower, slower, one wing working harder. A second hit puts it down: the wings
## fold, it falls with gravity, rolls onto the ground and lies there for a few seconds before the body is retired. Shooting does not
## remove the rest of the flock, and a trail retry calls `reset_flock()` and puts all five back in the air.
##
## The room sets `listener` each tick so the faint wind-over-feathers loop and the rare hiss only play when he is under them.

signal bird_hit(at: Vector3, killed: bool)
signal bird_down(at: Vector3)

const COUNT := 5
const AUDIO_DIR := "res://src/episode2/extras/audio/trail/"
const WINGS := AUDIO_DIR + "vulture_wings.ogg"
const CRY := AUDIO_DIR + "vulture_cry.ogg"
const WINGS_FALLBACK := "res://src/assets/sounds/ep2_birds_flutter.mp3"
const CRY_FALLBACK := "res://src/assets/sounds/ep2_bird_call_1.mp3"
const BODY_RADIUS := 0.62                 # generous enough that a bird at 30-60 m is a fair target
const CORPSE_SECONDS := 7.0
const FALL_GRAVITY := 9.4

var birds: Array[Node3D] = []
var phase: float = 0.0
var listener: Vector3 = Vector3.ZERO

var _states: Array = []
var _rng := RandomNumberGenerator.new()
var _wings: AudioStreamPlayer3D = null
var _cry: AudioStreamPlayer3D = null
var _cry_t: float = 8.0


func _init() -> void:
	_rng.seed = 1914


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for b in birds:
		if is_instance_valid(b):
			b.queue_free()
	birds.clear()
	_states.clear()
	for i in COUNT:
		var node := Ep2VultureMesh.build(1.08 + float(i) * 0.035)
		node.name = "Vulture%d" % i
		add_child(node)
		var health := Ep2CreatureHealth.new()
		health.name = "CreatureHealth"
		health.configure(2)                # one hit wounds, the second puts it down
		node.add_child(health)
		birds.append(node)
		var st: Dictionary = {
			"node": node, "health": health,
			"angle": float(i) * TAU / float(COUNT) + _rng.randf_range(-0.22, 0.22),
			"radius": 14.0 + float(i) * 1.55,
			"height": 26.0 + float(i) * 2.05,
			"speed": 0.118 + float(i) * 0.007,
			"flap_t": _rng.randf_range(0.0, 12.0),
			"t": _rng.randf_range(0.0, 30.0),
			"wounded": false, "dead": false, "dead_t": 0.0, "fall_y": 0.0, "settled": false,
		}
		_states.append(st)
		_place(st, 0.0)
	_build_audio()


func _build_audio() -> void:
	if _wings == null:
		_wings = AudioStreamPlayer3D.new()
		_wings.name = "VultureWings"
		_wings.bus = "SFX"
		_wings.unit_size = 26.0
		_wings.max_distance = 170.0
		_wings.volume_db = -22.0
		add_child(_wings)
		_wings.global_position = global_position + Vector3(0.0, 24.0, 0.0)
		var stream: AudioStream = _stream(WINGS, WINGS_FALLBACK)
		if stream != null:
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			_wings.stream = stream
			_wings.play()
	if _cry == null:
		_cry = AudioStreamPlayer3D.new()
		_cry.name = "VultureCry"
		_cry.bus = "SFX"
		_cry.unit_size = 22.0
		_cry.max_distance = 150.0
		_cry.volume_db = -14.0
		add_child(_cry)
		_cry.stream = _stream(CRY, CRY_FALLBACK)


func _stream(path: String, fallback: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if ResourceLoader.exists(fallback):
		return load(fallback) as AudioStream
	return null


func _process(delta: float) -> void:
	phase += delta * 0.13
	var alive: int = 0
	for i in birds.size():
		var st: Dictionary = _states[i]
		var node: Node3D = birds[i]
		st["t"] = float(st["t"]) + delta
		if bool(st["dead"]):
			_fall(st, delta)
			continue
		var wounded: bool = bool(st["wounded"])
		var speed: float = float(st["speed"]) * (0.62 if wounded else 1.0)
		var angle: float = float(st["angle"]) + speed * delta
		st["angle"] = angle
		_place(st, float(st["t"]))
		alive += 1
		var flap_amount: float = 0.16
		if wounded:
			# It fights the air: the wounded wing catches the downbeat every time.
			flap_amount = 0.62 + 0.22 * sin(float(st["t"]) * 5.7)
		else:
			# Soaring birds glide more than they flap. This is the slow burst/soar cycle, not a hummingbird.
			flap_amount = clampf(sin(float(st["t"]) * 0.52 + float(st["flap_t"])) * 1.8 + 0.35, 0.0, 1.0)
		st["flap_t"] = float(st["flap_t"]) + delta * (7.0 if wounded else 5.4)
		var roll: float = -0.22 + (0.16 * sin(float(st["t"]) * 3.1) if wounded else 0.03 * sin(float(st["t"]) * 0.7))
		node.rotation.z = roll
		Ep2VultureMesh.flap(node, float(st["flap_t"]), flap_amount, roll)
		if wounded:
			node.position.y = float(node.position.y) - 2.6 - 0.7 * sin(float(st["t"]) * 2.4)
	# The wind layer belongs to the flock, not to one bird.
	if _wings != null:
		var near: bool = alive > 0 and listener.distance_to(global_position) < 165.0
		if near and not _wings.playing and _wings.stream != null:
			_wings.play()
		elif not near and _wings.playing:
			_wings.stop()
		_wings.global_position = global_position + Vector3(0.0, 23.0, 0.0)
	_cry_t -= delta
	if _cry_t <= 0.0:
		_cry_t = _rng.randf_range(9.0, 19.0)
		if alive > 0 and _cry != null and _cry.stream != null and listener.distance_to(global_position) < 150.0:
			var pick: int = _rng.randi_range(0, birds.size() - 1)
			if not bool(_states[pick]["dead"]):
				_cry.global_position = birds[pick].global_position
				_cry.play()


func _place(st: Dictionary, _t: float) -> void:
	var angle: float = float(st["angle"])
	var radius: float = float(st["radius"])
	var node: Node3D = st["node"]
	node.position = Vector3(cos(angle) * radius, float(st["height"]) + sin(angle * 0.7 + float(st["flap_t"])) * 1.1, sin(angle) * radius)
	var tangent := Vector3(-sin(angle), 0.0, cos(angle))
	# The model noses along -Z, so turn -Z onto the tangent of the circle.
	node.rotation.y = atan2(-tangent.x, -tangent.z)
	node.rotation.x = 0.03 * sin(angle * 1.3)


func _fall(st: Dictionary, delta: float) -> void:
	var node: Node3D = st["node"]
	var t: float = float(st["dead_t"]) + delta
	st["dead_t"] = t
	if not bool(st["settled"]):
		var vy: float = float(st["fall_y"]) - FALL_GRAVITY * delta
		st["fall_y"] = vy
		node.position.y = maxf(0.42, float(node.position.y) + vy * delta)
		node.rotation.x += delta * 2.4
		node.rotation.z += delta * 1.7
		if float(node.position.y) <= 0.43:
			st["settled"] = true
			node.position.y = 0.42
			node.rotation.x = -0.12
			node.rotation.z = 1.35
			Ep2VultureMesh.fold(node)
	else:
		# A short skid, then still. The body stops drawing after CORPSE_SECONDS so a long ride costs nothing.
		node.position.y = maxf(0.28, float(node.position.y) - delta * 0.35)
	if t >= CORPSE_SECONDS:
		node.visible = false


## A shot along a ray. Returns the distance to the nearest living bird, or -1.
func shoot(eye: Vector3, dir: Vector3) -> float:
	var d: Vector3 = dir.normalized()
	var best: int = -1
	var best_t: float = INF
	for i in birds.size():
		var st: Dictionary = _states[i]
		if bool(st["dead"]) or not birds[i].visible:
			continue
		var t: float = _ray_sphere(eye, d, birds[i].global_position, BODY_RADIUS)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
	if best < 0:
		return -1.0
	var st: Dictionary = _states[best]
	var at: Vector3 = birds[best].global_position
	var health: Ep2CreatureHealth = st["health"]
	var killed: bool = health.take_hit(1, at)
	if killed:
		_kill(st, at)
	else:
		st["wounded"] = true
		bird_hit.emit(at, false)
	return best_t


## True when a living bird is under the ray (the HUD sight turns red).
func under_sight(eye: Vector3, dir: Vector3) -> bool:
	var d: Vector3 = dir.normalized()
	for i in birds.size():
		if bool(_states[i]["dead"]) or not birds[i].visible:
			continue
		if _ray_sphere(eye, d, birds[i].global_position, BODY_RADIUS) >= 0.0:
			return true
	return false


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
		var health: Ep2CreatureHealth = st["health"]
		health.configure(2)
		st["wounded"] = false
		st["dead"] = false
		st["settled"] = false
		st["dead_t"] = 0.0
		st["fall_y"] = 0.0
		st["angle"] = float(i) * TAU / float(COUNT) + _rng.randf_range(-0.22, 0.22)
		st["t"] = _rng.randf_range(0.0, 30.0)
		st["flap_t"] = _rng.randf_range(0.0, 12.0)
		var node: Node3D = st["node"]
		node.visible = true
		node.rotation = Vector3.ZERO
		_place(st, 0.0)
	if _wings != null and _wings.stream != null:
		_wings.play()


func _kill(st: Dictionary, at: Vector3) -> void:
	st["dead"] = true
	st["dead_t"] = 0.0
	st["fall_y"] = 0.0
	st["settled"] = false
	var node: Node3D = st["node"]
	node.rotation.z = 0.0
	Ep2VultureMesh.fold(node)
	bird_hit.emit(at, true)
	bird_down.emit(at)


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
