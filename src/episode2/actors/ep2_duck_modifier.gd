class_name Ep2DuckModifier
extends SkeletonModifier3D
## A BIG MAN DUCKING THROUGH A LOW DOORWAY (founder 2026-10-25 section 4.5: Inferno - 2.9 m - takes Lil Blunt into the saloon, whose
## batwing door is 2.5 m). After the animation each frame, bend the spine forward and bow the head by `amount` (0 upright, 1 the full
## duck), spread over the spine bones, around the character's own side axis (from the actor's facing, so the rig's bone axes do not
## matter). The chamber eases `amount` in as he nears a low door and out once he is through. A child of the Skeleton3D (Godot 4.3).

const SPINE := ["Spine02", "Spine01", "Spine"]       # the Meshy rig's spine, bottom-up (Inferno's rig, the townspeople's)
const NECK := ["neck", "Head"]
const SPINE_BEND := 0.33                             # radians per spine bone at amount 1 (~1.0 in all: a 2.9 m man under a 2.5 m lintel)
const NECK_BEND := 0.20

## 0 = upright, 1 = the full duck.
var amount: float = 0.0
## The character's forward in world space (the actor's facing); set by the chamber each frame it ducks.
var forward: Vector3 = Vector3.BACK

var _spine: Array = []
var _neck: Array = []


func _process_modification() -> void:
	if amount <= 0.001:
		return
	var sk: Skeleton3D = get_skeleton()
	if sk == null:
		return
	if _spine.is_empty():
		for n in SPINE:
			var i: int = sk.find_bone(n)
			if i >= 0:
				_spine.append(i)
		for n in NECK:
			var i: int = sk.find_bone(n)
			if i >= 0:
				_neck.append(i)
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length_squared() < 1e-6:
		return
	# bend axis: up x forward (turning +up toward +forward), taken into the skeleton's own space
	var axis_world: Vector3 = Vector3.UP.cross(fwd.normalized())
	var axis: Vector3 = (sk.global_basis.inverse() * axis_world).normalized()
	for i in _spine:
		_bend(sk, i, axis, SPINE_BEND * amount)
	for i in _neck:
		_bend(sk, i, axis, NECK_BEND * amount)


## Rotate bone `i` by `angle` about the skeleton-space `axis` at its own origin (children follow).
static func _bend(sk: Skeleton3D, i: int, axis: Vector3, angle: float) -> void:
	var parent: int = sk.get_bone_parent(i)
	var gp: Quaternion = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var local: Quaternion = sk.get_bone_pose_rotation(i)
	sk.set_bone_pose_rotation(i, (gp.inverse() * Quaternion(axis, angle) * gp * local).normalized())
