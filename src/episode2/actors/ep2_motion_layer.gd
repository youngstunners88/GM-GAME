class_name Ep2MotionLayer
extends SkeletonModifier3D
## Small additive acting over the real clips: breath, scanning and restrained carry swing.
## It does not scale a body or advance an independent frame clock.
var actor: Ep2Actor = null
var bull_carry: bool = false
var phase_offset: float = 0.0
var aim_weight: float = 0.0
var recoil: float = 0.0
var _sample_time: float = -1.0
var _base: Dictionary = {}


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or actor == null:
		return
	if _sample_time != actor.motion_time:
		_sample_time = actor.motion_time
		_base.clear()
	var state: String = str(actor.get_meta("pose", "idle"))
	if state in ["dead", "hit", "leap", "swipe", "bite"]:
		return
	var t: float = actor.motion_time + phase_offset
	var breath: float = sin(t * (1.6 if state == "sleep" else 1.9)) * 0.012
	_rotate(sk, "Spine02", Vector3.RIGHT, breath)
	if state == "aim":
		_rotate(sk, "Spine", Vector3.RIGHT, -0.025 * clampf(float(actor.get_meta("pose_t", 0.0)) / 0.7, 0, 1))
	elif state == "shot":
		_rotate(sk, "Spine", Vector3.RIGHT, -0.025 + 0.008 * exp(-float(actor.get_meta("pose_t", 0.0)) * 12.0))
	if bull_carry:
		_rotate(sk, "Spine", Vector3.RIGHT, -recoil * 0.025)
		_rotate(sk, "LeftArm", Vector3.RIGHT, aim_weight * 0.10 - recoil * 0.035)
		_rotate(sk, "LeftForeArm", Vector3.RIGHT, aim_weight * 0.08)
	if state not in ["sleep", "sit_read", "aim"]:
		_rotate(sk, "Head", Vector3.UP, sin(t * 0.85) * (0.07 if actor.is_walking() else 0.045))
		_rotate(sk, "neck", Vector3.RIGHT, sin(t * 1.1) * 0.015)
	if bull_carry and actor.is_walking() and actor.reach_weight("Left") < 0.01:
		# The left fist is free; the fused right fist/pouch must not be dragged by a library swing.
		var stride: float = sin(t * 4.2) * minf(actor.motion_speed, 2.0) * 0.025
		_rotate(sk, "LeftArm", Vector3.RIGHT, stride)
		_rotate(sk, "LeftForeArm", Vector3.RIGHT, -stride * 0.6)
	elif not bull_carry and actor.is_walking():
		var stride: float = sin(t * 4.2) * minf(actor.motion_speed, 3.0) * 0.06
		_rotate(sk, "LeftArm", Vector3.RIGHT, stride)
		_rotate(sk, "RightArm", Vector3.RIGHT, -stride)


func _rotate(sk: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var b: int = sk.find_bone(name)
	if b >= 0:
		if not _base.has(name):
			_base[name] = sk.get_bone_pose_rotation(b)
		sk.set_bone_pose_rotation(b, (_base[name] * Quaternion(axis, angle)).normalized())
