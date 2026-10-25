class_name Ep2TownQuad
extends Node3D
## INFERNO'S FLAME QUAD COMING BACK INTO TOWN (founder 2026-10-25, PROMPT_EPISODE2_CAD_TRANSITIONS_DRAW_REWRITE section 4.3: "After testing
## the Gatling, Inferno returns on his bike and parks outside Rich's"). The same model the woods ride uses (WoodsQuadChamber.QUAD_MODEL),
## driven along a path: a cruise that eases off into the park, the wheels turning with the road, the engine loop heard on the approach
## (3D, fading with distance) and cut when he parks. The chamber seats Inferno with `seat_position()` every frame while it rolls.
## Pure logic + light visuals: `step(delta)` is called by the chamber, so a test can drive it headless.
signal parked

const CRUISE := 8.5                    # m/s up the street (the woods ride's quad does 11 flat out)
const ACCEL := 6.0                     # m/s^2 either way
const BRAKE_DIST := 10.0               # starts easing off this far from the park
const MIN_V := 0.7
const ENGINE := "res://src/assets/sounds/ep2_quad_loop.mp3"
const START := "res://src/assets/sounds/ep2_quad_start.mp3"

var path: Array = []
var yaw: float = 0.0
var is_parked: bool = false
var speed: float = 0.0
var _s: float = 0.0
var _len: float = 0.0
var _wheels: Array = []
var _modelled: bool = false
var _engine: AudioStreamPlayer3D = null


## Load the quad (the woods ride's model; a plain stand-in body only guards a stripped build) and its engine.
func build() -> void:
	if ResourceLoader.exists(WoodsQuadChamber.QUAD_MODEL):
		var m: Node3D = (load(WoodsQuadChamber.QUAD_MODEL) as PackedScene).instantiate() as Node3D
		m.name = "QuadModel"
		add_child(m)
		_modelled = true
		for wn in m.find_children("Wheel_*", "Node3D", true, false):
			if String(wn.name).count("_") == 1:                     # Wheel_FL ... Wheel_RR, not their rims / nuts
				_wheels.append(wn)
	else:
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.7, 0.8, 3.4)
		body.mesh = bm
		body.position.y = 0.8
		add_child(body)
	if ResourceLoader.exists(ENGINE):
		var st: AudioStream = load(ENGINE) as AudioStream
		if st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate() as AudioStreamMP3
			(st as AudioStreamMP3).loop = true
		_engine = AudioStreamPlayer3D.new()
		_engine.name = "Engine"
		_engine.stream = st
		_engine.unit_size = 14.0
		_engine.max_distance = 220.0
		_engine.volume_db = -3.0
		_engine.position = Vector3(0.0, 0.9, 0.3)
		add_child(_engine)


## Roll along `points` (world, y ignored) from the first to the last, parking there.
func drive(points: Array) -> void:
	path = []
	for p in points:
		path.append(Vector3((p as Vector3).x, 0.0, (p as Vector3).z))
	_len = 0.0
	for i in path.size() - 1:
		_len += (path[i] as Vector3).distance_to(path[i + 1])
	_s = 0.0
	speed = CRUISE * 0.8
	is_parked = path.size() < 2
	visible = true
	if path.size() >= 2:
		position = path[0]
		yaw = atan2((path[1] as Vector3).x - (path[0] as Vector3).x, (path[1] as Vector3).z - (path[0] as Vector3).z)
		rotation = Vector3(0.0, yaw, 0.0)
	if _engine != null and _engine.is_inside_tree():
		_engine.play()


func step(delta: float) -> void:
	if is_parked or path.size() < 2 or delta <= 0.0:
		return
	var left: float = _len - _s
	var want: float = CRUISE if left > BRAKE_DIST else maxf(MIN_V, CRUISE * left / BRAKE_DIST)
	speed = move_toward(speed, want, ACCEL * delta)
	_s = minf(_len, _s + speed * delta)
	var acc: float = 0.0
	var i: int = 0
	while i < path.size() - 2 and acc + (path[i] as Vector3).distance_to(path[i + 1]) < _s:
		acc += (path[i] as Vector3).distance_to(path[i + 1])
		i += 1
	var a: Vector3 = path[i]
	var b: Vector3 = path[i + 1]
	var t: float = clampf((_s - acc) / maxf(a.distance_to(b), 0.01), 0.0, 1.0)
	position = a.lerp(b, t)
	yaw = lerp_angle(yaw, atan2(b.x - a.x, b.z - a.z), clampf(4.0 * delta, 0.0, 1.0))
	rotation = Vector3(0.0, yaw, 0.0)
	for w in _wheels:
		(w as Node3D).rotation.x += speed * delta / WoodsQuadChamber.QUAD_WHEEL_R
	if _engine != null:
		_engine.pitch_scale = 0.85 + 0.35 * clampf(speed / CRUISE, 0.0, 1.0)
	if _s >= _len - 0.01:
		is_parked = true
		speed = 0.0
		if _engine != null:
			_engine.stop()
		parked.emit()


## Inferno's actor origin on the saddle for the quad's current pose (the woods ride's seat: WoodsQuadChamber._bull_seat_position).
func seat_position() -> Vector3:
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	if not _modelled:
		return position + f * 0.55 + Vector3(0.0, 0.62, 0.0)
	var hips_at: Vector3 = position + f * WoodsQuadChamber.BULL_SEAT_F + Vector3(0.0, WoodsQuadChamber.SEAT_TOP_DRIVER + 0.10, 0.0)
	return hips_at - Basis(Vector3.UP, yaw) * WoodsQuadChamber.BULL_HIPS


## Where Inferno stands when he swings off: beside the saddle on his left, a little behind it.
func dismount_spot() -> Vector3:
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	var r := Vector3(-f.z, 0.0, f.x)
	return position - r * 1.6 - f * 0.5


func travelled() -> float:
	return _s


func length() -> float:
	return _len
