class_name Ep2RoadCart
extends Node3D
## Articulated road encounter. All motion is advanced by the chamber simulation,
## so pause/retry, deterministic tests and browser playback use the same clock.
const DIR := "res://src/episode2/extras/road_cart/"
const STRIDE := 1.5
const WALK_SECONDS := 0.625
const WHEEL_RADIUS := 0.62
const SEAT := Vector3(0.0, 1.33322, -0.77)
var ready_art: bool = false
var distance_m: float = 0.0
var greeting_time: float = -1.0
var _time: float = 0.0
var _fallback: Node3D
var _donkey: Node3D
var _farmer: Node3D
var _wagon: Node3D
var _walk: AnimationPlayer
var _driver: AnimationPlayer
var _walk_clip: StringName
var _drive_clip: StringName
var _greet_clip: StringName
var _donkey_skeleton: Skeleton3D
var _farmer_skeleton: Skeleton3D
var _wheels: Array[Node3D] = []
var _reins: Array[MeshInstance3D] = []
var _rein_mat: StandardMaterial3D


func build(fallback_path: String, fallback_scale: float) -> void:
	name = "DonkeyCart"
	if ResourceLoader.exists(fallback_path):
		_fallback = (load(fallback_path) as PackedScene).instantiate() as Node3D
		_fallback.scale = Vector3.ONE * fallback_scale
		_fallback.rotation.y = -PI * 0.5
		add_child(_fallback)
	_try_upgrade()


func _try_upgrade() -> void:
	if ready_art or not (Ep2Extras.has(DIR + "donkey.glb") and Ep2Extras.has(DIR + "farmer.glb") and Ep2Extras.has(DIR + "cart.glb")):
		return
	_donkey = (load(DIR + "donkey.glb") as PackedScene).instantiate() as Node3D
	_farmer = (load(DIR + "farmer.glb") as PackedScene).instantiate() as Node3D
	_wagon = (load(DIR + "cart.glb") as PackedScene).instantiate() as Node3D
	_donkey.name = "WalkingDonkey"
	_farmer.name = "SeatedFarmer"
	_wagon.name = "ArticulatedCart"
	_donkey.position.z = 1.60
	_farmer.position = SEAT
	_wagon.position.z = -1.30
	add_child(_donkey)
	add_child(_farmer)
	add_child(_wagon)
	_walk = _animation_player(_donkey)
	_driver = _animation_player(_farmer)
	_donkey_skeleton = _donkey.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_farmer_skeleton = _farmer.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_walk_clip = _clip(_walk, "donkey_walk")
	_drive_clip = _clip(_driver, "seated_drive")
	_greet_clip = _clip(_driver, "seated_greet")
	for side in ["L", "R"]:
		var wheel := _wagon.find_child("Wheel_" + side, true, false) as Node3D
		if wheel != null:
			_wheels.append(wheel)
	Ep2Pbr.dress(_wagon, {}, [], true)
	_rein_mat = StandardMaterial3D.new()
	_rein_mat.albedo_color = Color(0.16, 0.075, 0.025)
	_rein_mat.roughness = 0.88
	for side in ["L", "R"]:
		var mi := MeshInstance3D.new()
		mi.name = "Rein_" + side
		mi.material_override = _rein_mat
		add_child(mi)
		_reins.append(mi)
	if _fallback != null:
		_fallback.queue_free()
		_fallback = null
	ready_art = true
	_pose()


func _animation_player(root: Node) -> AnimationPlayer:
	var ap := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return ap


func _clip(ap: AnimationPlayer, suffix: String) -> StringName:
	for n in ap.get_animation_list():
		if str(n).ends_with(suffix):
			return n
	push_error("Road cart missing clip: " + suffix)
	return &""


func greet() -> void:
	greeting_time = 0.0


func reset_motion() -> void:
	distance_m = 0.0
	_time = 0.0
	greeting_time = -1.0
	_pose()


func advance_motion(delta: float, travelled: float) -> void:
	_try_upgrade()
	distance_m += travelled
	_time += delta
	if greeting_time >= 0.0:
		greeting_time += delta
		if greeting_time >= 3.0 - 0.000001:
			greeting_time = -1.0
	_pose()


func _sample(ap: AnimationPlayer, clip: StringName, seconds: float) -> void:
	if ap.current_animation != clip:
		ap.play(clip)
	ap.seek(seconds, true)
	ap.advance(0.0)


func _pose() -> void:
	if not ready_art:
		return
	_sample(_walk, _walk_clip, fposmod(distance_m / STRIDE, 1.0) * WALK_SECONDS)
	_sample(_driver, _greet_clip if greeting_time >= 0.0 else _drive_clip, greeting_time if greeting_time >= 0.0 else fposmod(_time, 3.0))
	_donkey_skeleton.force_update_all_bone_transforms()
	_farmer_skeleton.force_update_all_bone_transforms()
	for wheel in _wheels:
		wheel.rotation.x = fposmod(distance_m / WHEEL_RADIUS, TAU)
	_update_reins()


func hand_position() -> Vector3:
	var bone: int = _farmer_skeleton.find_bone("LeftHand")
	# The Meshy skeleton retains centimetres under its 0.01 armature scale.
	# The curled fingers close 6 cm beyond the wrist along the hand bone.
	return _farmer_skeleton.global_transform * (_farmer_skeleton.get_bone_global_pose(bone) * Vector3(0.0, 6.0, 0.0))


func bridle_position(side: int) -> Vector3:
	var head := _donkey_skeleton.find_bone("head")
	# Rest-space attachment at each bridle cheek; follows animated head exactly.
	var rest := _donkey_skeleton.get_bone_global_rest(head)
	var cheek := Vector3(-0.13 if side == 0 else 0.13, 0.91, 1.04)
	return _donkey_skeleton.global_transform * (_donkey_skeleton.get_bone_global_pose(head) * (rest.affine_inverse() * cheek))


func _bone_world(sk: Skeleton3D, bone_name: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone_name)).origin


func hoof_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if ready_art:
		for n in ["front_L", "front_R", "hind_L", "hind_R"]:
			var b: int = _donkey_skeleton.find_bone(n + "_hoof")
			var pose := _donkey_skeleton.get_bone_global_pose(b)
			# Anatomical sole landmark (.105 m ankle to the measured ground sole).
			result.append(_donkey_skeleton.global_transform * (pose.origin + Vector3(0.0, -0.105, 0.0)))
	return result


func _update_reins() -> void:
	var hand: Vector3 = to_local(hand_position())
	for side in 2:
		var cheek: Vector3 = to_local(bridle_position(side))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Narrow leather ribbon; double sided using explicit front/back triangles.
		for i in 16:
			var a := _rein_point(hand, cheek, float(i) / 16.0)
			var b := _rein_point(hand, cheek, float(i + 1) / 16.0)
			var width := Vector3(0.009, 0.0, 0.0)
			for p in [a - width, b - width, b + width, a - width, b + width, a + width,
					a - width, b + width, b - width, a - width, a + width, b + width]:
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
		_reins[side].mesh = st.commit()


func _rein_point(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(b, t) + Vector3(0.0, -0.14 * sin(PI * t), 0.0)
