class_name RunnerArmRest
extends SkeletonModifier3D
## Seats the founder's posed hero like a NORMAL PERSON in the cart (class name kept for the scene wiring).
## Founder, 2026-09-29/30: "his foot is out of the cart ... his arm is looking spastic behind his back.
## BOTH ARMS MUST BE IN FRONT LIKE A NORMAL PERSON." The Meshy hero is an airborne zipline figure
## (legs splayed, one arm overhead, one arm out) and library clips hunch/float him, so the skeleton
## keeps his bind pose and THIS modifier poses the limbs by direction:
##   legs   thighs forward, shins straight down, feet forward  -> knees together, boots INSIDE the cart
##   arms   upper arms forward-down, forearms forward         -> both hands out in front of him
##   pick   fist forward at chest height, the pickaxe upright in front of his left shoulder
## Axis-free: "up" and "forward" come from the WORLD (rider forward = +Z), "outward" from hips -> limb root,
## so it survives a re-rig, the mirror and the aim yaw. `influence` blends to the bind pose (the zipline
## hang from the pick); `pick_raise` (0..1) swings the pickaxe arm back overhead for the chop.

@export var pick_side: String = "Right"      # anatomical side holding the pickaxe (gun arm is the other)
@export var pick_raise: float = 0.0
## Where the gun arm rests when the aim modifier is not driving it (world-ish weights: fwd, up, out).
@export var gun_upper := Vector3(0.75, -0.45, 0.25)
@export var gun_fore := Vector3(0.95, 0.10, 0.10)
@export var pick_upper := Vector3(0.65, -0.55, 0.30)
@export var pick_fore := Vector3(0.45, 0.85, 0.05)

func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var hips: int = sk.find_bone("Hips")
	if hips < 0:
		return
	var inv: Basis = sk.global_transform.basis.inverse()
	var up: Vector3 = (inv * Vector3.UP).normalized()
	var fwd: Vector3 = (inv * Vector3.BACK).normalized()       # world +Z = down the track
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var hips_p: Vector3 = sk.get_bone_global_pose(hips).origin
	for side in ["Left", "Right"]:
		var root_p: Vector3 = sk.get_bone_global_pose(sk.find_bone(side + "UpLeg")).origin
		var out: Vector3 = _outward(root_p - hips_p, up, fwd)
		# Legs: thigh forward (a touch outward), shin straight down, foot forward.
		_chain(sk, side + "UpLeg", side + "Leg", (fwd * 0.95 - up * 0.30 + out * 0.10).normalized())
		_chain(sk, side + "Leg", side + "Foot", (-up * 1.0 - fwd * 0.10).normalized())
		if sk.find_bone(side + "ToeBase") >= 0:
			_chain(sk, side + "Foot", side + "ToeBase", (fwd * 0.9 - up * 0.15).normalized())
		# Arms.
		var sh_p: Vector3 = sk.get_bone_global_pose(sk.find_bone(side + "Arm")).origin
		var aout: Vector3 = _outward(sh_p - hips_p, up, fwd)
		var is_pick: bool = side == pick_side
		var u: Vector3 = pick_upper if is_pick else gun_upper
		var f: Vector3 = pick_fore if is_pick else gun_fore
		var ud: Vector3 = (fwd * u.x + up * u.y + aout * u.z).normalized()
		var fd: Vector3 = (fwd * f.x + up * f.y + aout * f.z).normalized()
		if is_pick and pick_raise > 0.0:
			# Chop: arm straight up overhead (the bind-pose swing), blended by pick_raise.
			ud = ud.slerp((up * 0.95 + aout * 0.3).normalized(), pick_raise)
			fd = fd.slerp((up * 1.0 + fwd * 0.2).normalized(), pick_raise)
		_chain(sk, side + "Arm", side + "ForeArm", ud)
		_chain(sk, side + "ForeArm", side + "Hand", fd)

func _outward(v: Vector3, up: Vector3, fwd: Vector3) -> Vector3:
	var o: Vector3 = v - up * v.dot(up) - fwd * v.dot(fwd)
	return o.normalized() if o.length_squared() > 1e-10 else Vector3.RIGHT

## Rotate `bone` so that bone -> child points along `dir` (skeleton space).
func _chain(sk: Skeleton3D, bone_name: String, child_name: String, dir: Vector3) -> void:
	var bone: int = sk.find_bone(bone_name)
	var child: int = sk.find_bone(child_name)
	if bone < 0 or child < 0:
		return
	var g: Transform3D = sk.get_bone_global_pose(bone)
	var d0: Vector3 = sk.get_bone_global_pose(child).origin - g.origin
	if d0.length_squared() < 1e-10:
		return
	var q := Quaternion(d0.normalized(), dir)
	var new_basis: Basis = Basis(q) * g.basis.orthonormalized()
	var parent: int = sk.get_bone_parent(bone)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
