class_name Ep2BearHeadDown
extends SkeletonModifier3D
## A reading bear sits UP and looks DOWN into the magazine in his paws: straightens the spine (the library chair-sit clip
## slumps forward on the bear's hunched body) and tilts the neck and head forward. Skeleton space, so it holds for every
## yaw. `influence` blends it in (Ep2BearKit turns it on only in the sit_read pose).
## Angles are radians about the skeleton's lateral axis (+X): positive tips forward / down, negative tips back.

@export var spine_pitch: float = -0.32
@export var neck_pitch: float = 0.10
@export var head_pitch: float = 0.30


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	_pitch(sk, "Spine02", spine_pitch)
	_pitch(sk, "neck", neck_pitch)
	_pitch(sk, "Head", head_pitch)


## Rotate `bone` about the skeleton's lateral axis (+X), applied in its parent's frame.
func _pitch(sk: Skeleton3D, bone: String, ang: float) -> void:
	var b: int = sk.find_bone(bone)
	if b < 0 or absf(ang) < 1e-4:
		return
	var gb: Transform3D = sk.get_bone_global_pose(b)
	var new_basis: Basis = Basis(Vector3.RIGHT, ang) * gb.basis.orthonormalized()
	var p: int = sk.get_bone_parent(b)
	var pb: Basis = sk.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
	sk.set_bone_pose_rotation(b, (pb.inverse() * new_basis).get_rotation_quaternion())
