class_name RunnerAimModifier
extends SkeletonModifier3D
## Points Lil Blunt's GUN ARM at the reticle, on top of whatever clip is playing
## (Godot 4.3 runs SkeletonModifier3D after the AnimationPlayer). Founder,
## 2026-09-27: "when Lil Blunt shoots it looks weird — he has his gold revolver in
## one hand and his pickaxe in the other". Before this, the body played a
## full-body Side_Shot clip and the gun floated on the hand pointing elsewhere.
##
## Method (axis-convention free, so it survives a re-rig): straighten the elbow
## to its rest bend, measure shoulder→hand in skeleton space, rotate the upper arm
## by the shortest arc onto shoulder→target, write it back as a LOCAL pose.
## `influence` (built in) blends it with the clip: the view eases it to 0 for
## the reload, the pickaxe swipe, ducking and the zipline.

@export var arm_bone: String = "RightArm"
@export var fore_bone: String = "RightForeArm"
@export var hand_bone: String = "RightHand"
## 1 = the shoulder->hand line points straight at the target (library rig). Below 1 the incoming pose's
## line is kept partly, so an arm posed OUT to the side stays visible to the chase camera.
@export var follow: float = 1.0
## Straighten the elbow to its rest bend first (library rig). Off for a hero posed by RunnerArmRest.
@export var reset_fore: bool = true
## Non-zero: the held gun's barrel axis in the HAND frame; the hand is turned so the barrel points at
## the target (otherwise the barrel points wherever the wrist happens to face - the founder saw it
## pointing at the ceiling).
@export var barrel_local: Vector3 = Vector3.ZERO
## Aim target in WORLD space; the view writes it every frame.
var target: Vector3 = Vector3.ZERO
## Recoil kick (radians), decays in the view; lifts the arm after a shot.
var kick: float = 0.0

func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	var arm: int = sk.find_bone(arm_bone)
	var fore: int = sk.find_bone(fore_bone)
	var hand: int = sk.find_bone(hand_bone)
	if arm < 0 or fore < 0 or hand < 0:
		return
	if reset_fore:
		sk.set_bone_pose_rotation(fore, sk.get_bone_rest(fore).basis.get_rotation_quaternion())
	var arm_g: Transform3D = sk.get_bone_global_pose(arm)
	var hand_p: Vector3 = sk.get_bone_global_pose(hand).origin
	var t_local: Vector3 = sk.global_transform.affine_inverse() * target
	var d0: Vector3 = hand_p - arm_g.origin
	var d1: Vector3 = t_local - arm_g.origin
	if d0.length_squared() < 1e-8 or d1.length_squared() < 1e-8:
		return
	d1 = d0.normalized().slerp(d1.normalized(), clampf(follow, 0.0, 1.0)).normalized()
	if kick > 0.0:
		# Recoil: tip the aim upward in skeleton space.
		var side: Vector3 = d1.cross(Vector3.UP)
		if side.length_squared() > 1e-6:
			d1 = d1.rotated(side.normalized(), -kick)
	var q := Quaternion(d0.normalized(), d1)
	var new_basis: Basis = Basis(q) * arm_g.basis.orthonormalized()
	var parent: int = sk.get_bone_parent(arm)
	var parent_basis: Basis = sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var local: Basis = parent_basis.inverse() * new_basis
	sk.set_bone_pose_rotation(arm, local.get_rotation_quaternion())
	if barrel_local != Vector3.ZERO:
		var hg: Transform3D = sk.get_bone_global_pose(hand)
		var hb: Basis = hg.basis.orthonormalized()
		var want: Vector3 = t_local - hg.origin
		if want.length_squared() < 1e-8:
			return
		want = want.normalized()
		if kick > 0.0:
			var kside: Vector3 = want.cross(Vector3.UP)
			if kside.length_squared() > 1e-6:
				want = want.rotated(kside.normalized(), -kick)
		var nb: Basis = Basis(Quaternion((hb * barrel_local).normalized(), want)) * hb
		var fb: Basis = sk.get_bone_global_pose(sk.get_bone_parent(hand)).basis.orthonormalized()
		sk.set_bone_pose_rotation(hand, (fb.inverse() * nb).get_rotation_quaternion())
