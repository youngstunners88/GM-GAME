class_name Ep2BullRestArm
extends SkeletonModifier3D
## Keep the Tripo arms relaxed when the mismatched Meshy idle curls them into the coat.
## Founder 2026-10-10: the left hand no longer carries a whiskey glass.
## Imported local bone poses use the imported rest rotation, not an identity quaternion.
## Enabled only at standing idle; walk, seated clips and hand-over IK retain their own poses.
var resting: bool = false
## Painted Bull (motion fix 2026-11-21): his Winchester is sculpted into the LEFT fist and is now rigid to it, so any clip
## that swings the left arm (the crate Sit_and_Drink drinks with it) waves the whole rifle across his face. The left arm
## stays at its rest pose relative to the torso whenever this is set; the hip fire (Ep2BullHipFire, runs later) and a
## left IK reach (callers clear it) are the only things that move it.
var hold_left: bool = false


func _process_modification() -> void:
	if not resting and not hold_left:
		return
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var bones: Array = ["RightShoulder", "RightArm", "RightForeArm", "RightHand",
		"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand"] if resting else ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand"]
	for bn in bones:
		var bone: int = sk.find_bone(bn)
		if bone >= 0:
			sk.set_bone_pose_rotation(bone, sk.get_bone_rest(bone).basis.get_rotation_quaternion())
