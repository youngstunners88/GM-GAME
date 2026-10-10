class_name Ep2BullRestArm
extends SkeletonModifier3D
## Keep the Tripo arms relaxed when the mismatched Meshy idle curls them into the coat.
## Founder 2026-10-10: the left hand no longer carries a whiskey glass.
## Imported local bone poses use the imported rest rotation, not an identity quaternion.
## Enabled only at standing idle; walk, seated clips and hand-over IK retain their own poses.
var resting: bool = false


func _process_modification() -> void:
	if not resting:
		return
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	for bn in ["RightShoulder", "RightArm", "RightForeArm", "RightHand",
		"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand"]:
		var bone: int = sk.find_bone(bn)
		if bone >= 0:
			sk.set_bone_pose_rotation(bone, sk.get_bone_rest(bone).basis.get_rotation_quaternion())
