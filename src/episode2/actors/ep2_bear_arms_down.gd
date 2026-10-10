class_name Ep2BearArmsDown
extends SkeletonModifier3D
## The founder's Tripo bear (2026-10-10: "those bears are from Meshy! I want my Tripo bears ... hyper realism") rides the old
## Meshy bear skeleton and its clips. Those clips were made for an ARCHER holding a bow: in Idle the arms stay out sideways,
## and on the bow-less Tripo body that reads as a T-pose. This modifier, applied after the clip, swings each arm down and a
## little forward - the menacing claws-out stance of the founder's reference still (bear standing in the pines, arms low).
## Axis-free: "down"/"forward" come from the bear's own frame (skeleton space: +Y up, +Z forward), "outward" from hips ->
## shoulder, so it holds for every bear yaw. `influence` (SkeletonModifier3D) blends it in or out.

## Upper arm and forearm directions as (forward, up, outward) weights in the bear's frame.
@export var upper_dir := Vector3(0.12, -0.93, 0.34)
@export var fore_dir := Vector3(0.30, -0.90, 0.22)


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var hips: int = sk.find_bone("Hips")
	if hips < 0:
		return
	var hips_p: Vector3 = sk.get_bone_global_pose(hips).origin
	for side in ["Left", "Right"]:
		var arm: int = sk.find_bone(side + "Arm")
		if arm < 0:
			continue
		var out: Vector3 = sk.get_bone_global_pose(arm).origin - hips_p
		out.y = 0.0
		out.z = 0.0
		out = out.normalized() if out.length() > 1e-4 else Vector3(1.0 if side == "Left" else -1.0, 0.0, 0.0)
		_aim(sk, side + "Arm", side + "ForeArm", _dir(upper_dir, out))
		_aim(sk, side + "ForeArm", side + "Hand", _dir(fore_dir, out))


func _dir(w: Vector3, out: Vector3) -> Vector3:
	return (Vector3.BACK * w.x + Vector3.UP * w.y + out * w.z).normalized()


## Rotate `bone` (in skeleton space) so the direction to `child` points along `want`.
func _aim(sk: Skeleton3D, bone: String, child: String, want: Vector3) -> void:
	var b: int = sk.find_bone(bone)
	var c: int = sk.find_bone(child)
	if b < 0 or c < 0:
		return
	var gb: Transform3D = sk.get_bone_global_pose(b)
	var have: Vector3 = sk.get_bone_global_pose(c).origin - gb.origin
	if have.length() < 1e-5:
		return
	var q := Quaternion(have.normalized(), want)
	var new_basis: Basis = Basis(q) * gb.basis.orthonormalized()
	var p: int = sk.get_bone_parent(b)
	var pb: Basis = sk.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis()
	sk.set_bone_pose_rotation(b, (pb.inverse() * new_basis).get_rotation_quaternion())
