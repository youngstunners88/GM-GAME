class_name Ep2ArmIK
extends SkeletonModifier3D
## Analytic two-bone arm IK for the Meshy humanoid rig (Arm -> ForeArm -> Hand), plus an optional forward lean of
## the spine so a short-armed character can still reach. Used by Ep2Actor so Inferno Bull really reaches for the
## rifle on the wall, the helmet on the crate and Lil Blunt's hands (founder 2026-10-02: "he needs to walk and
## grab the Winchester off the wall and hand it to him" - the old open-hands pose made items float).
##
## `influence` (SkeletonModifier3D) is the blend 0..1 between the playing clip's arm and the solved arm, so the
## reach eases in and out. Everything is solved in skeleton space; targets are given in WORLD space.

## Anatomical side of the arm this modifier drives: "Left" or "Right".
@export var side: String = "Right"
## World-space point the hand should reach (valid while `reaching`).
var target_world: Vector3 = Vector3.ZERO
var reaching: bool = false
## World-space direction the elbow bends toward (default: down and out), re-derived each frame from the body.
var pole_down: float = 0.8
var pole_out: float = 0.6
## Forward lean (radians) of Spine + Spine01 toward `lean_toward` (world point), for reaching farther.
var spine_lean: float = 0.0
var lean_toward: Vector3 = Vector3.ZERO
## Last solve: how far (metres) the hand fell short of the target (0 = reached).
var shortfall: float = 0.0


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null or not reaching or influence <= 0.001:
		return
	var a: int = sk.find_bone(side + "Arm")
	var f: int = sk.find_bone(side + "ForeArm")
	var h: int = sk.find_bone(side + "Hand")
	if a < 0 or f < 0 or h < 0:
		return
	var inv_xf: Transform3D = sk.global_transform.affine_inverse()
	if absf(spine_lean) > 0.001:
		_lean(sk, inv_xf)
	var up: Vector3 = (inv_xf.basis * Vector3.UP).normalized()
	var s: Vector3 = sk.get_bone_global_pose(a).origin
	var e0: Vector3 = sk.get_bone_global_pose(f).origin
	var h0: Vector3 = sk.get_bone_global_pose(h).origin
	var l1: float = s.distance_to(e0)
	var l2: float = e0.distance_to(h0)
	var t: Vector3 = inv_xf * target_world
	var d_full: float = s.distance_to(t)
	var d: float = clampf(d_full, absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	shortfall = maxf(0.0, d_full - (l1 + l2)) * sk.global_transform.basis.get_scale().x     # metres
	var dir_st: Vector3 = (t - s).normalized()
	var x: float = (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	var hgt: float = sqrt(maxf(l1 * l1 - x * x, 0.0))
	var hips: int = sk.find_bone("Hips")
	var out_v: Vector3 = (s - sk.get_bone_global_pose(hips).origin) if hips >= 0 else Vector3.RIGHT
	out_v = (out_v - up * out_v.dot(up)).normalized()
	var pole: Vector3 = (out_v * pole_out - up * pole_down).normalized()
	pole = (pole - dir_st * pole.dot(dir_st))
	pole = pole.normalized() if pole.length_squared() > 1e-8 else up
	var e: Vector3 = s + dir_st * x + pole * hgt
	aim_bone(sk, a, f, ((e0 - s).normalized()).slerp((e - s).normalized(), influence))
	var e1: Vector3 = sk.get_bone_global_pose(f).origin
	var cur_f: Vector3 = (sk.get_bone_global_pose(h).origin - e1).normalized()
	var want_f: Vector3 = (s + dir_st * d - e1).normalized() if d_full > l1 + l2 else (t - e1).normalized()
	aim_bone(sk, f, h, cur_f.slerp(want_f, influence))


## Rotate `bone` so that bone -> child points along `dir` (skeleton space).
static func aim_bone(sk: Skeleton3D, bone: int, child: int, dir: Vector3) -> void:
	var g: Transform3D = sk.get_bone_global_pose(bone)
	var d0: Vector3 = sk.get_bone_global_pose(child).origin - g.origin
	if d0.length_squared() < 1e-10 or dir.length_squared() < 1e-10:
		return
	var nb: Basis = Basis(Quaternion(d0.normalized(), dir.normalized())) * g.basis.orthonormalized()
	var parent: int = sk.get_bone_parent(bone)
	var pb: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (pb.inverse() * nb).get_rotation_quaternion())


func _lean(sk: Skeleton3D, inv_xf: Transform3D) -> void:
	var hips: int = sk.find_bone("Hips")
	if hips < 0:
		return
	var up: Vector3 = (inv_xf.basis * Vector3.UP).normalized()
	var to: Vector3 = (inv_xf * lean_toward) - sk.get_bone_global_pose(hips).origin
	to = to - up * to.dot(up)
	if to.length_squared() < 1e-6:
		return
	var axis: Vector3 = to.normalized().cross(up).normalized()      # tilting about this leans "up" toward `to` when the angle is negative
	for bn in ["Spine", "Spine01"]:
		var b: int = sk.find_bone(bn)
		if b < 0:
			continue
		var gb: Basis = sk.get_bone_global_pose(b).basis.orthonormalized()
		var nb: Basis = Basis(axis, -spine_lean * 0.5 * influence) * gb
		var parent: int = sk.get_bone_parent(b)
		var pb: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
		sk.set_bone_pose_rotation(b, (pb.inverse() * nb).get_rotation_quaternion())
