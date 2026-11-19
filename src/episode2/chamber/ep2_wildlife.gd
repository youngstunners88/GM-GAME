class_name Ep2Wildlife
extends Node3D
## LIFE IN THE WOOD (founder 2026-10-10: "work towards birds flying randomly and trees moving with the wind ... the necessary soundscape
## from ElevenLabs"; skill ep2-set-piece-forge). Drop one into any outdoor chamber:
##   * BIRDS: a few dark songbirds wander on random waypoints above the canopy and, now and then, one swoops down between the trunks;
##     every so often a small flock flushes from a tree with the flutter sound. Each bird is two flapping wing quads on a tiny body:
##     cheap, and at 20-60 m that is all a bird is. Deterministic from `seed` so captures repeat.
##   * SOUNDSCAPE (ElevenLabs sound-generation, assets/audio-manifest.json): a seamless 19 s forest-ambience loop under everything,
##     a wind gust through the canopy every 14-30 s, and bird calls / a raven / a woodpecker placed in 3D round the listener.
## The host calls `setup(listener, centre, half_extent, canopy_y)` once, then `step(delta)` from its own tick (so a chamber's
## deterministic step() drives the birds in tests and captures too).

const AMBIENCE := "res://src/assets/sounds/ep2_woods_ambience_loop.ogg"
const GUST := "res://src/assets/sounds/ep2_woods_wind_gust.mp3"
const CALLS := ["res://src/assets/sounds/ep2_bird_call_1.mp3", "res://src/assets/sounds/ep2_bird_call_2.mp3", "res://src/assets/sounds/ep2_bird_call_3.mp3"]
const FLUTTER := "res://src/assets/sounds/ep2_birds_flutter.mp3"
const BIRD_COUNT := 7

var seed: int = 1886
var ambience_db: float = -14.0
var _rng := RandomNumberGenerator.new()
var _listener: Node3D = null
var _centre := Vector3.ZERO
var _half := Vector2(60.0, 60.0)
var _canopy_y: float = 32.0
var _birds: Array = []                 # [node, wing_l, wing_r, velocity, target, flap_phase, speed]
var _ambience: AudioStreamPlayer = null
var _gust: AudioStreamPlayer = null
var _calls: Array = []                 # AudioStreamPlayer3D pool
var _t_gust: float = 8.0
var _t_call: float = 3.0
var _t_flock: float = 20.0
var calls_played: int = 0
var gusts_played: int = 0
var flocks_flushed: int = 0
var birds_shot: int = 0
## A shot songbird drops out of the air and lies on the forest floor (founder 2026-11-05: bullets must not pass through animals).
const HIT_RADIUS := 0.32                  # the body is 24 cm: a little generous, like every small target in the game
var _fallen: Array = []                  # [node, wing_l, wing_r, velocity] - falling, then lying still


func setup(listener: Node3D, centre: Vector3, half_extent: Vector2, canopy_y: float, play_ambience: bool = true) -> void:
	_rng.seed = seed
	_listener = listener
	_centre = centre
	_half = half_extent
	_canopy_y = canopy_y
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.09, 0.08, 0.07)
	body_mat.roughness = 0.9
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in BIRD_COUNT:
		_birds.append(_make_bird(body_mat, _random_air_point(i % 3 == 0)))
	_ambience = _player(AMBIENCE, ambience_db, true)
	_gust = _player(GUST, ambience_db + 2.0, false)
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 18.0
		p.max_distance = 140.0
		p.volume_db = -4.0
		add_child(p)
		_calls.append(p)
	if play_ambience:
		start_ambience()


func start_ambience() -> void:
	if _ambience != null and _ambience.stream != null and not _ambience.playing:
		_ambience.play()


func _player(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.volume_db = db
	if ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		if loop and st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		elif loop and st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		p.stream = st
	add_child(p)
	return p


func _make_bird(mat: Material, at: Vector3) -> Array:
	var n := Node3D.new()
	n.position = at
	add_child(n)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.05
	bm.height = 0.24
	bm.radial_segments = 6
	bm.rings = 2
	body.mesh = bm
	body.material_override = mat
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	n.add_child(body)
	var wings: Array = []
	for sx in [-1.0, 1.0]:
		var pivot := Node3D.new()
		n.add_child(pivot)
		var w := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.26, 0.11)
		w.mesh = qm
		w.material_override = mat
		w.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		w.position = Vector3(0.13 * sx, 0.0, 0.0)
		pivot.add_child(w)
		wings.append(pivot)
	var spd: float = _rng.randf_range(7.0, 11.0)
	return [n, wings[0], wings[1], Vector3(0, 0, spd), _random_air_point(false), _rng.randf() * TAU, spd]


func _random_air_point(low: bool) -> Vector3:
	var x: float = _centre.x + _rng.randf_range(-_half.x, _half.x)
	var z: float = _centre.z + _rng.randf_range(-_half.y, _half.y)
	var y: float = _rng.randf_range(4.0, 9.0) if low else _canopy_y + _rng.randf_range(-4.0, 10.0)
	return Vector3(x, y, z)


## Metres along the ray to the nearest flying bird, or -1.0. Nothing is hurt here.
func ray_distance(eye: Vector3, dir: Vector3) -> float:
	var best: float = -1.0
	for b in _birds:
		var t: float = _ray_sphere(eye, dir, (b[0] as Node3D).global_position, HIT_RADIUS)
		if t >= 0.0 and (best < 0.0 or t < best):
			best = t
	return best


## The round lands on the nearest bird on the ray: it falls, the rest scatter. Returns true when a bird was hit.
func shoot(eye: Vector3, dir: Vector3) -> bool:
	var hit: int = -1
	var best: float = INF
	for i in _birds.size():
		var t: float = _ray_sphere(eye, dir, (_birds[i][0] as Node3D).global_position, HIT_RADIUS)
		if t >= 0.0 and t < best:
			best = t
			hit = i
	scare((_birds[hit][0] as Node3D).global_position if hit >= 0 else eye + dir * 20.0)
	if hit < 0:
		return false
	var b: Array = _birds[hit]
	_birds.remove_at(hit)
	_fallen.append([b[0], b[1], b[2], (b[3] as Vector3) * 0.25 + dir * 2.0])
	birds_shot += 1
	return true


## A gunshot (or a near miss): every bird still flying bursts away from it and climbs, with the wing flutter.
func scare(at: Vector3) -> void:
	for b in _birds:
		var n: Node3D = b[0]
		var away: Vector3 = n.global_position - at
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
		b[3] = away * float(b[6]) * 1.3 + Vector3(0.0, 5.0, 0.0)
		b[4] = n.position + away * 45.0 + Vector3(0.0, 12.0, 0.0)
	if ResourceLoader.exists(FLUTTER) and not _calls.is_empty():
		var p: AudioStreamPlayer3D = _calls[(calls_played + 2) % _calls.size()]
		p.stream = load(FLUTTER)
		p.global_position = at
		p.play()


func get_fallen_count() -> int:
	return _fallen.size()


static func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc: Vector3 = o - c
	var b: float = oc.dot(d)
	var disc: float = b * b - (oc.length_squared() - r * r)
	if disc < 0.0:
		return -1.0
	var t: float = -b - sqrt(disc)
	return t if t >= 0.0 else -1.0


func _step_fallen(delta: float) -> void:
	for f in _fallen:
		var n: Node3D = f[0]
		if n.position.y <= 0.06:
			continue                                  # on the forest floor: it stays there
		var v: Vector3 = f[3]
		v.y -= 9.8 * delta
		v.x = move_toward(v.x, 0.0, delta * 1.5)
		v.z = move_toward(v.z, 0.0, delta * 1.5)
		f[3] = v
		n.position += v * delta
		n.rotation.z += delta * 6.0                   # it tumbles, wings limp
		(f[1] as Node3D).rotation.z = 0.35
		(f[2] as Node3D).rotation.z = -0.35
		if n.position.y <= 0.06:
			n.position.y = 0.06
			n.rotation = Vector3(0.0, n.rotation.y, PI * 0.5)    # on its side among the needles


## Advance the birds and the soundscape by `delta` seconds.
func step(delta: float) -> void:
	_step_fallen(delta)
	if _listener != null and is_instance_valid(_listener):
		var lp: Vector3 = _listener.global_position
		_centre = Vector3(lp.x, 0.0, lp.z)            # the wood's life follows the player
	for b in _birds:
		var n: Node3D = b[0]
		var to: Vector3 = (b[4] as Vector3) - n.position
		if to.length() < 4.0 or n.position.distance_to(_centre) > maxf(_half.x, _half.y) * 1.6:
			b[4] = _random_air_point(_rng.randf() < 0.25)    # one in four legs swoops down between the trunks
			to = (b[4] as Vector3) - n.position
		var want: Vector3 = to.normalized() * float(b[6])
		var v: Vector3 = (b[3] as Vector3).lerp(want, clampf(delta * 0.9, 0.0, 1.0))
		b[3] = v
		n.position += v * delta
		if v.length() > 0.1:
			n.look_at(n.position + v, Vector3.UP)
		# flap while climbing or slow, glide on the way down
		var flap_rate: float = 14.0 if v.y > -0.6 else 3.0
		b[5] = float(b[5]) + delta * flap_rate
		var ang: float = sin(float(b[5])) * (0.9 if v.y > -0.6 else 0.15)
		(b[1] as Node3D).rotation.z = ang
		(b[2] as Node3D).rotation.z = -ang
	_t_gust -= delta
	if _t_gust <= 0.0:
		_t_gust = _rng.randf_range(14.0, 30.0)
		if _gust.stream != null:
			_gust.play()
			gusts_played += 1
	_t_call -= delta
	if _t_call <= 0.0:
		_t_call = _rng.randf_range(3.5, 9.0)
		_play_call()
	_t_flock -= delta
	if _t_flock <= 0.0:
		_t_flock = _rng.randf_range(35.0, 70.0)
		_flush_flock()


func _play_call() -> void:
	var path: String = CALLS[_rng.randi() % CALLS.size()]
	if not ResourceLoader.exists(path):
		return
	var p: AudioStreamPlayer3D = _calls[calls_played % _calls.size()]
	p.stream = load(path)
	var a: float = _rng.randf() * TAU
	var d: float = _rng.randf_range(12.0, 45.0)
	p.global_position = _centre + Vector3(cos(a) * d, _rng.randf_range(6.0, 22.0), sin(a) * d)
	p.pitch_scale = _rng.randf_range(0.93, 1.08)
	p.play()
	calls_played += 1


## A few birds burst out of a tree ahead of the player, climbing away, with the wing flutter.
func _flush_flock() -> void:
	if _birds.is_empty():
		return
	var a: float = _rng.randf() * TAU
	var origin: Vector3 = _centre + Vector3(cos(a) * 22.0, 9.0, sin(a) * 22.0)
	for i in mini(3, _birds.size()):
		var b: Array = _birds[i]
		(b[0] as Node3D).position = origin + Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.5, 1.5))
		b[3] = Vector3(_rng.randf_range(-3, 3), 4.0, _rng.randf_range(-3, 3))
		b[4] = origin + Vector3(cos(a + 1.0) * 40.0, _canopy_y + 6.0, sin(a + 1.0) * 40.0)
	if ResourceLoader.exists(FLUTTER) and not _calls.is_empty():
		var p: AudioStreamPlayer3D = _calls[(calls_played + 1) % _calls.size()]
		p.stream = load(FLUTTER)
		p.global_position = origin
		p.play()
	flocks_flushed += 1


func get_bird_count() -> int:
	return _birds.size()


func is_ambience_playing() -> bool:
	return _ambience != null and _ambience.playing
