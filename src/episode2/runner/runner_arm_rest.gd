class_name RunnerArmRest
extends SkeletonModifier3D
## Seats the founder's posed hero like the TARGET LOOK (references/founder_2026-09-29/REF_target-look.jpg):
## seen from behind, sitting deep in the cart, hat on top of the leaf head, gun arm out on his right with
## the gold revolver pointing down the track, pickaxe leaning up at his left side.
## The Meshy hero is an airborne zipline figure (legs splayed, pickaxe hooked overhead, revolver out) and
## every library clip hunched or floated him, so the skeleton keeps the bind pose and THIS modifier poses
## him by direction. Axis-free: "up"/"forward" come from the WORLD (rider forward = +Z), "outward" from
## hips -> limb root, so it survives a re-rig, the mirror and the body yaw. `influence` blends to the bind
## pose (the zipline hang); `pick_raise` (0..1) swings the pickaxe overhead for the chop.
##
## Founder history this guards: 09-29 "creature from a failed lab" (clips), 09-30 "foot out of the cart,
## arm spastic behind his back", 09-30 "still trash" -> seen with the orbit rig (skill see-it-yourself):
## revolver pointing at the ceiling, pickaxe held up like a club, crouching with the belt over the rim,
## back-of-head leaves sticking up through the hat brim.

@export var pick_side: String = "Right"      # anatomical side holding the pickaxe (gun arm is the other)
@export var pick_raise: float = 0.0
## Limb directions as (forward, up, outward) weights in the world frame.
@export var gun_upper := Vector3(0.15, -0.55, 0.80)
@export var gun_fore := Vector3(0.55, 0.05, 0.85)
@export var gun_barrel := Vector3(0.97, 0.12, 0.08)
@export var pick_upper := Vector3(0.30, -0.90, 0.30)
@export var pick_fore := Vector3(0.85, 0.25, 0.45)
@export var pick_handle := Vector3(0.05, 0.80, 0.60)
## Barrel / handle axes in the HAND bone's local frame, measured from lil_blunt_hero.glb skin weights
## (PCA of the LeftHand-weighted revolver verts; centroid of the RightHand-weighted pick head).
@export var barrel_local := Vector3(0.265, 0.90, -0.33)
@export var handle_local := Vector3(0.0, 1.0, 0.0)
## Head tipped back (radians): the back-of-head leaves drop under the brim and the hat crown faces the
## chase camera, so from behind he reads as a HAT on a leaf collar (target), not a bush with a brim through it.
@export var head_back: float = 0.9
@export var spine_back: float = 0.12

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
	var lat: Vector3 = fwd.cross(up).normalized()               # rotating +angle about this tips "up" backward
	var hips_p: Vector3 = sk.get_bone_global_pose(hips).origin
	# Sit up straight, head back.
	_tilt(sk, "Spine01", lat, spine_back)
	_tilt(sk, "neck", lat, head_back * 0.5)
	_tilt(sk, "Head", lat, head_back * 0.5)
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
		var h: Vector3 = pick_handle if is_pick else gun_barrel
		var ud: Vector3 = (fwd * u.x + up * u.y + aout * u.z).normalized()
		var fd: Vector3 = (fwd * f.x + up * f.y + aout * f.z).normalized()
		var hd: Vector3 = (fwd * h.x + up * h.y + aout * h.z).normalized()
		if is_pick and pick_raise > 0.0:
			# Chop: arm straight up overhead, the pick head coming forward over him.
			ud = ud.slerp((up * 0.95 + aout * 0.3).normalized(), pick_raise)
			fd = fd.slerp((up * 1.0 + fwd * 0.2).normalized(), pick_raise)
			hd = hd.slerp((up * 0.6 + fwd * 0.8).normalized(), pick_raise)
		_chain(sk, side + "Arm", side + "ForeArm", ud)
		_chain(sk, side + "ForeArm", side + "Hand", fd)
		_aim_hand(sk, side + "Hand", handle_local if is_pick else barrel_local, hd)

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
	_set_global_basis(sk, bone, Basis(Quaternion(d0.normalized(), dir)) * g.basis.orthonormalized())

## Turn the hand so its held item (axis `local_axis` in the hand frame) points along `dir`.
func _aim_hand(sk: Skeleton3D, bone_name: String, local_axis: Vector3, dir: Vector3) -> void:
	var bone: int = sk.find_bone(bone_name)
	if bone < 0:
		return
	var gb: Basis = sk.get_bone_global_pose(bone).basis.orthonormalized()
	var cur: Vector3 = (gb * local_axis).normalized()
	_set_global_basis(sk, bone, Basis(Quaternion(cur, dir)) * gb)

## Rotate `bone` by `angle` about the skeleton-space `axis`.
func _tilt(sk: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var bone: int = sk.find_bone(bone_name)
	if bone < 0 or absf(angle) < 1e-4:
		return
	var gb: Basis = sk.get_bone_global_pose(bone).basis.orthonormalized()
	_set_global_basis(sk, bone, Basis(axis, angle) * gb)

func _set_global_basis(sk: Skeleton3D, bone: int, new_basis: Basis) -> void:
	var parent: int = sk.get_bone_parent(bone)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
