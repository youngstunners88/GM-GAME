class_name Ep2HandContacts
extends SkeletonModifier3D
## Independent prop markers drive a bounded two-bone solve. Bone lengths never change.
## Run after rest/reading layers; contacts are sampled again from the final drawn pose.
var targets: Dictionary = {}                 # Left/Right -> world Marker3D on the rigid prop
var palm_offset_m: float = 0.07
var palm_local_m: Dictionary = {}
var finger_directions: Dictionary = {}     # anatomical finger axis in actor/skeleton frame
var shortfall_m: float = 0.0
var prop_frame: Node3D = null
var prop_bone: int = -1
var prop_local: Transform3D = Transform3D.IDENTITY


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	shortfall_m = 0.0
	if is_instance_valid(prop_frame) and prop_bone >= 0:
		# A torso frame is independent of the hands being solved; update it before contacts,
		# not from a one-frame-old BoneAttachment transform.
		prop_frame.global_transform = sk.global_transform * sk.get_bone_global_pose(prop_bone) * prop_local
	for side in targets:
		var mark: Node3D = targets[side]
		if not is_instance_valid(mark) or not mark.is_inside_tree():
			continue
		var arm: int = sk.find_bone(str(side) + "Arm")
		var fore: int = sk.find_bone(str(side) + "ForeArm")
		var hand: int = sk.find_bone(str(side) + "Hand")
		if arm < 0 or fore < 0 or hand < 0:
			continue
		var scale_m: float = maxf(sk.global_transform.basis.get_scale().x, 0.0001)
		var target: Vector3 = sk.global_transform.affine_inverse() * mark.global_position
		# Account for the palm beyond the wrist; re-evaluate its orientation after each solve.
		for iteration in 10:
			_orient_hand(sk, hand, str(side))
			var palm: Vector3 = sk.get_bone_global_pose(hand).basis * local_palm(str(side)) / scale_m
			_solve(sk, arm, fore, hand, target - palm, scale_m)
		_orient_hand(sk, hand, str(side))


func _orient_hand(sk: Skeleton3D, hand: int, side: String) -> void:
	if not finger_directions.has(side):
		return
	var from: Vector3 = Vector3.RIGHT if side == "Left" else Vector3.LEFT
	var desired: Basis = Basis(Quaternion(from, finger_directions[side])) * sk.get_bone_global_rest(hand).basis.orthonormalized()
	var parent: Basis = sk.get_bone_global_pose(sk.get_bone_parent(hand)).basis.orthonormalized()
	sk.set_bone_pose_rotation(hand, (parent.inverse() * desired).get_rotation_quaternion())


func local_palm(side: String) -> Vector3:
	return palm_local_m.get(side, Vector3(0, palm_offset_m, 0))


func _solve(sk: Skeleton3D, arm: int, fore: int, hand: int, target: Vector3, scale_m: float) -> void:
	var s: Vector3 = sk.get_bone_global_pose(arm).origin
	var e: Vector3 = sk.get_bone_global_pose(fore).origin
	var h: Vector3 = sk.get_bone_global_pose(hand).origin
	var l1: float = s.distance_to(e)
	var l2: float = e.distance_to(h)
	if l1 < 0.001 or l2 < 0.001:
		return
	var full: float = s.distance_to(target)
	var d: float = clampf(full, absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	shortfall_m = maxf(shortfall_m, maxf(0.0, full - d) * scale_m)
	var dir: Vector3 = (target - s).normalized()
	if dir.length_squared() < 0.5:
		return
	var x: float = (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	var bend: float = sqrt(maxf(0.0, l1 * l1 - x * x))
	var pole: Vector3 = Vector3(0.35 * signf(s.x), -1.0, -0.15)
	pole -= dir * pole.dot(dir)
	if pole.length_squared() < 0.0001:
		pole = Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)
	var elbow: Vector3 = s + dir * x + pole.normalized() * bend
	Ep2ArmIK.aim_bone(sk, arm, fore, elbow - s)
	var e1: Vector3 = sk.get_bone_global_pose(fore).origin
	Ep2ArmIK.aim_bone(sk, fore, hand, s + dir * d - e1)


static func palm_world(actor: Ep2Actor, side: String, offset_m: float = 0.07) -> Vector3:
	var holder: Node3D = actor.holder(side + "Hand")
	return holder.global_transform * Vector3(0.0, offset_m, 0.0) if holder != null else actor.global_position
