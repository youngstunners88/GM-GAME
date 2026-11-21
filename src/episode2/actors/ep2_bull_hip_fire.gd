class_name Ep2BullHipFire
extends SkeletonModifier3D
## Inferno Bull's ONE-HANDED hip fire with the rifle sculpted into his painted left fist (motion fix T1, 2026-11-21).
##
## Why one hand: his right fist is sculpted INTO the flask pouch (moving it tears the pouch), so the honest hold is the
## left fist alone. Why this pose: the fist's grip axis runs across the palm, perpendicular to the forearm, so to
## point the barrel forward the forearm must point forward-DOWN with the elbow bent and the upper arm out from his
## wide hip (measured in Blender on inferno_bull_rigged.glb, renders `motionfix/T1`: no tear at elbow or shoulder,
## the stock clears the hip). The barrel then comes level at the target; recoil kicks the muzzle up about the wrist
## and the forearm follows, then recovers.
##
## Runs AFTER Ep2BullRestArm and Ep2MotionLayer (added last), so it starts from the rest/clip pose and is the final
## word on the left arm while `weight` > 0. It needs the rifle to be rigid to LeftHand (tools/ep2_forge/
## bull_rifle_rigid.py); before that fix the sculpted barrel and stock were skinned to the head and thigh and
## stretched like taffy whenever the arm moved.

## Body-frame directions (x = his LEFT, y = UP, z = his FRONT), from the Blender skin test (pose "v2").
const UPPER_ARM := Vector3(0.42, -0.90, -0.12)
const FOREARM := Vector3(0.30, -0.55, 0.75)
## Aim limits around his front, radians: he turns his body for anything wider.
const MAX_YAW := 0.6
const MAX_UP := 0.30
const MAX_DOWN := 0.25

var actor: Ep2Actor = null
## 0 = arm untouched (carry / rest), 1 = full hip-fire hold.
var weight: float = 0.0
## 0..1 recoil envelope (1 at the shot, decays to 0).
var recoil: float = 0.0
## World point to aim at while `has_target`.
var aim_target: Vector3 = Vector3.ZERO
var has_target: bool = false
## 0..1: turn the left fist so the rifle stands upright (his carry) while that hand does something else (the lift lever, motion fix T6) -
## otherwise the rifle follows the forearm and sticks out through whatever he is working at. Applied after any IK reach.
var rifle_up: float = 0.0


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or actor == null:
		return
	if rifle_up > 0.001 and weight <= 0.001:
		var h: int = sk.find_bone("LeftHand")
		if h >= 0:
			var cur: Vector3 = Ep2BullHero.rifle_axis_skeleton(sk, h)
			var up: Vector3 = (sk.global_transform.basis.inverse() * Vector3.UP).normalized()
			_turn_hand(sk, h, cur, cur.slerp(up, clampf(rifle_up, 0.0, 1.0)).normalized())
		return
	if weight <= 0.001 and recoil <= 0.001:
		return
	var arm: int = sk.find_bone("LeftArm")
	var fore: int = sk.find_bone("LeftForeArm")
	var hand: int = sk.find_bone("LeftHand")
	if arm < 0 or fore < 0 or hand < 0:
		return
	var q0: Array[Quaternion] = [sk.get_bone_pose_rotation(arm), sk.get_bone_pose_rotation(fore), sk.get_bone_pose_rotation(hand)]
	var inv: Basis = sk.global_transform.basis.inverse()
	var front: Vector3 = Basis(Vector3.UP, actor.facing) * Vector3.BACK
	var muzzle_w: Vector3 = front + Vector3.UP * 0.03
	var yaw: float = 0.0
	if has_target:
		var fist: Vector3 = sk.global_transform * sk.get_bone_global_pose(hand).origin
		var to: Vector3 = aim_target - fist
		var flat: Vector3 = Vector3(to.x, 0.0, to.z)
		if flat.length_squared() > 1e-6:
			yaw = clampf(front.signed_angle_to(flat.normalized(), Vector3.UP), -MAX_YAW, MAX_YAW)
			var pitch: float = clampf(atan2(to.y, flat.length()), -MAX_DOWN, MAX_UP)
			muzzle_w = (Basis(Vector3.UP, yaw) * front) * cos(pitch) + Vector3.UP * sin(pitch)
	var body: Basis = Basis(Vector3.UP, actor.facing + yaw)
	var left: Vector3 = body * Vector3.RIGHT      # facing 0 looks down +Z, so his left is +X
	var fwd: Vector3 = body * Vector3.BACK
	var up_w: Vector3 = left * UPPER_ARM.x + Vector3.UP * UPPER_ARM.y + fwd * UPPER_ARM.z
	var fo_w: Vector3 = left * FOREARM.x + Vector3.UP * FOREARM.y + fwd * FOREARM.z
	Ep2ArmIK.aim_bone(sk, arm, fore, (inv * up_w).normalized())
	Ep2ArmIK.aim_bone(sk, fore, hand, (inv * fo_w).normalized())
	_turn_hand(sk, hand, Ep2BullHero.rifle_axis_skeleton(sk, hand), (inv * muzzle_w).normalized())
	var q1: Array[Quaternion] = [sk.get_bone_pose_rotation(arm), sk.get_bone_pose_rotation(fore), sk.get_bone_pose_rotation(hand)]
	var w: float = clampf(weight, 0.0, 1.0)
	sk.set_bone_pose_rotation(arm, q0[0].slerp(q1[0], w))
	sk.set_bone_pose_rotation(fore, q0[1].slerp(q1[1], w))
	sk.set_bone_pose_rotation(hand, q0[2].slerp(q1[2], w))
	if recoil > 0.001:
		# Muzzle climbs about the wrist and the forearm kicks with it (a rotation about his LEFT axis lifts the front).
		var axis: Vector3 = (inv * left).normalized()
		_rotate_global(sk, fore, axis, -recoil * 0.10)
		_rotate_global(sk, hand, axis, -recoil * 0.30)


## Swing the hand so the rifle axis (skeleton space) turns onto `want`.
static func _turn_hand(sk: Skeleton3D, hand: int, cur: Vector3, want: Vector3) -> void:
	if cur.length_squared() < 1e-8 or want.length_squared() < 1e-8:
		return
	var g: Basis = sk.get_bone_global_pose(hand).basis.orthonormalized()
	var nb: Basis = Basis(Quaternion(cur.normalized(), want.normalized())) * g
	var parent: int = sk.get_bone_parent(hand)
	var pb: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(hand, (pb.inverse() * nb).get_rotation_quaternion())


static func _rotate_global(sk: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	var g: Basis = sk.get_bone_global_pose(bone).basis.orthonormalized()
	var nb: Basis = Basis(axis, angle) * g
	var parent: int = sk.get_bone_parent(bone)
	var pb: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (pb.inverse() * nb).get_rotation_quaternion())
