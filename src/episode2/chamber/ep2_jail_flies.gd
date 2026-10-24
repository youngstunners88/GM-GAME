class_name Ep2JailFlies
extends Node3D
## THE FLIES OVER THE JAIL PRIVY (founder 2026-10-24: "the toilet with flies in the jail house"; skill ep2-jail-privy).
##
## A small swarm round the privy in cell A (tools/ep2_blender/build_jailhouse.py, Jail_Nav Spot_privy): most circle and dart over the
## seat, a few land on the seat board and crawl, then lift off again. One MultiMesh for the bodies, one for the wing blur - two draw
## calls whatever the count. The buzz is a seamless 2 s loop (tools/ep2_forge/make_fly_buzz.py) on a short-range 3D player, quiet
## enough that the Sheriff's and the accomplice's lines stay on top. Nothing updates when the camera is more than FAR m away.
## Deterministic: every fly's path is a function of its index and the elapsed time, no random state.

const BUZZ := "res://src/episode2/extras/jail/fly_buzz.wav"
const COUNT := 18
const LANDERS := 6                       # the first LANDERS flies take turns sitting on the seat
const FAR := 16.0

var _bodies: MultiMeshInstance3D
var _wings: MultiMeshInstance3D
var _t: float = 0.0
## The seat in this node's local frame (the node sits at Spot_privy, seat height): flies land within this disc.
var _seat_r: float = 0.24


func _ready() -> void:
	_bodies = _multi(_body_mesh(), _body_mat())
	_wings = _multi(_wing_mesh(), _wing_mat())
	_wings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bodies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if Ep2Extras.has(BUZZ):
		var s := load(BUZZ) as AudioStreamWAV
		if s != null:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2               # 16-bit mono: frames = bytes / 2
			var p := AudioStreamPlayer3D.new()
			p.name = "Buzz"
			p.stream = s
			p.volume_db = -13.0
			p.unit_size = 1.6
			p.max_distance = 9.0
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
			p.autoplay = true
			p.position = Vector3(0.0, 0.15, 0.0)
			add_child(p)
	_step(0.0)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near: bool = cam == null or cam.global_position.distance_to(global_position) < FAR
	_bodies.visible = near
	_wings.visible = near
	if near:
		_step(delta)


## Where fly `i` is at time `t` (local frame) and whether it is sitting on the seat.
func fly_pos(i: int, t: float) -> Array:
	var fi := float(i)
	var a1: float = 1.3 + fmod(fi * 0.37, 1.1)
	var a2: float = 2.1 + fmod(fi * 0.53, 1.7)
	var r: float = 0.10 + fmod(fi * 0.071, 0.24)
	var p1: float = fi * 2.399
	var air := Vector3(sin(t * a1 + p1) * r, 0.18 + 0.16 * (0.5 + 0.5 * sin(t * a2 + p1 * 0.7)) + fmod(fi * 0.05, 0.25), cos(t * a1 * 0.83 + p1) * r * 1.2)
	air += Vector3(sin(t * 17.0 + fi), sin(t * 23.0 + fi * 1.3), sin(t * 19.0 + fi * 0.7)) * 0.012    # the dart
	if i >= LANDERS:
		return [air, false]
	# a lander: sits for the first 35% of its own cycle, flies the rest; eases on and off the board over 0.3 s
	var cyc: float = 7.0 + fmod(fi * 1.7, 5.0)
	var u: float = fmod(t + fi * 2.3, cyc)
	var sit_t: float = cyc * 0.35
	var ang: float = fi * 1.9 + floor((t + fi * 2.3) / cyc) * 2.2
	var spot := Vector3(cos(ang) * _seat_r * 0.75, 0.005, sin(ang) * _seat_r * 0.9)
	spot += Vector3(sin(u * 0.9 + fi), 0.0, cos(u * 0.7 + fi)) * 0.02                                   # crawling
	var k: float = 0.0
	if u < sit_t:
		k = 1.0
	elif u < sit_t + 0.3:
		k = 1.0 - (u - sit_t) / 0.3
	elif u > cyc - 0.3:
		k = (u - (cyc - 0.3)) / 0.3
	return [air.lerp(spot, k), k > 0.99]


func _step(delta: float) -> void:
	_t += delta
	var bm := _bodies.multimesh
	var wm := _wings.multimesh
	for i in COUNT:
		var r: Array = fly_pos(i, _t)
		var p: Vector3 = r[0]
		var sitting: bool = r[1]
		var ahead: Array = fly_pos(i, _t + 0.05)
		var dir: Vector3 = (ahead[0] as Vector3) - p
		var yaw: float = atan2(dir.x, dir.z) if dir.length() > 1e-4 else float(i)
		var b := Basis(Vector3.UP, yaw)
		bm.set_instance_transform(i, Transform3D(b, p))
		# wings: a flat blur while flying, folded small on the seat
		var flap: float = 0.25 if sitting else 1.0 + 0.15 * sin(_t * 70.0 + float(i))
		wm.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(flap, 1.0, flap)), p + Vector3(0, 0.004, 0)))


func _multi(mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = COUNT
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)
	return mi


## A house fly is ~7 mm; at the visitor's 2.5 m that is a pixel. These are drawn a little larger (1.4 cm) so they read as flies, not noise.
func _body_mesh() -> Mesh:
	var s := SphereMesh.new()
	s.radius = 0.0045
	s.height = 0.014
	s.radial_segments = 6
	s.rings = 3
	return s


func _wing_mesh() -> Mesh:
	var q := PlaneMesh.new()
	q.size = Vector2(0.020, 0.010)
	return q


func _body_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.04)
	m.metallic = 0.3
	m.roughness = 0.35                        # the blue-black sheen of a fly's back
	return m


func _wing_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.58, 0.60, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
