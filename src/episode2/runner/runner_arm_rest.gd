class_name RunnerArmRest
extends SkeletonModifier3D
## Rests the hero's PICKAXE arm. Founder, 2026-09-29: "I don't like that his left hand just
## remains up." The Meshy hero is a posed zipline figure (arm and pick overhead). The rigged clips
## put a standing skeleton at seat height and hunched him over the cart, so the skeleton stays in
## the founder's bind pose and only this arm is posed: upper arm out and down, forearm up, so the
## pickaxe stands upright beside him, as in the founder's target image.
##
## Axis-free (survives a re-rig / mirror): "up" comes from the world, "outward" from hips -> shoulder.
## `influence` blends between the raised bind pose (0) and the rest pose (1); the view eases it toward
## 0 for the chop and the zipline (hang from the pick).

@export var arm_bone: String = "RightArm"
@export var fore_bone: String = "RightForeArm"
@export var hand_bone: String = "RightHand"
@export var hips_bone: String = "Hips"
## Weights of the two rest directions (out, up) for the upper arm and the forearm.
@export var upper_out: float = 0.65
@export var upper_up: float = -0.75
@export var fore_out: float = 0.12
@export var fore_up: float = 1.0

func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var arm: int = sk.find_bone(arm_bone)
	var fore: int = sk.find_bone(fore_bone)
	var hand: int = sk.find_bone(hand_bone)
	var hips: int = sk.find_bone(hips_bone)
	if arm < 0 or fore < 0 or hand < 0 or hips < 0:
		return
	var up: Vector3 = (sk.global_transform.basis.inverse() * Vector3.UP).normalized()
	var arm_g: Transform3D = sk.get_bone_global_pose(arm)
	var hips_p: Vector3 = sk.get_bone_global_pose(hips).origin
	var out: Vector3 = arm_g.origin - hips_p
	out = (out - up * out.dot(up))
	if out.length_squared() < 1e-10:
		return
	out = out.normalized()
	# Upper arm: shoulder -> elbow onto (out, down).
	var elbow: Vector3 = sk.get_bone_global_pose(fore).origin
	var d0: Vector3 = elbow - arm_g.origin
	var d1: Vector3 = (out * upper_out + up * upper_up).normalized()
	if d0.length_squared() < 1e-10:
		return
	_rotate_bone(sk, arm, Quaternion(d0.normalized(), d1))
	# Forearm: elbow -> hand onto (up, a little out), measured AFTER the upper arm moved.
	var fore_g: Transform3D = sk.get_bone_global_pose(fore)
	var hand_p: Vector3 = sk.get_bone_global_pose(hand).origin
	var f0: Vector3 = hand_p - fore_g.origin
	var f1: Vector3 = (out * fore_out + up * fore_up).normalized()
	if f0.length_squared() < 1e-10:
		return
	_rotate_bone(sk, fore, Quaternion(f0.normalized(), f1))

## Rotate `bone` by the global-space arc `q` (blended in by `influence` via the modifier system).
func _rotate_bone(sk: Skeleton3D, bone: int, q: Quaternion) -> void:
	var g: Transform3D = sk.get_bone_global_pose(bone)
	var new_basis: Basis = Basis(q) * g.basis.orthonormalized()
	var parent: int = sk.get_bone_parent(bone)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var local: Basis = parent_basis.inverse() * new_basis
	sk.set_bone_pose_rotation(bone, local.get_rotation_quaternion())
