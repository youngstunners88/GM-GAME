class_name Ep2BullRestArm
extends SkeletonModifier3D
## Keep the Tripo right arm relaxed when the mismatched Meshy idle curls it into the coat.
## Imported local bone poses use the imported rest rotation, not an identity quaternion.
var resting: bool = false


func _process_modification() -> void:
	if not resting:
		return
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	for bn in ["RightShoulder", "RightArm", "RightForeArm", "RightHand"]:
		var bone: int = sk.find_bone(bn)
		if bone >= 0:
			sk.set_bone_pose_rotation(bone, sk.get_bone_rest(bone).basis.get_rotation_quaternion())
