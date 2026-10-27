class_name Ep2RanchPose
extends RefCounted
## Runtime ranch clips for the supplied Tripo/Mixamo townsfolk rigs.
##
## Poses are solved from each skeleton's own rest transforms. Bones are aimed
## with shortest-arc rotations, the hands use a two-bone reach, and the results
## are keyed as ordinary animations. Installing a clip never changes the model.

const RIDE: String = "RanchRide"
const BRUSH: String = "RanchBrush"
const CARRY: String = "RanchCarry"

const RIDE_LOOP: float = 2.4
const BRUSH_LOOP: float = 1.9
const CARRY_LOOP: float = 2.0

const _RIDE_BEATS: Array = [0.0, 0.6, 1.2, 1.8, 2.4]
const _BRUSH_BEATS: Array = [0.0, 0.475, 0.95, 1.425, 1.9]
const _CARRY_BEATS: Array = [0.0, 0.5, 1.0, 1.5, 2.0]
const _BODY_TRACKS: Array = [
	"Hips", "Spine",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
	"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
]
# Carry supplies the held upper-body pose without stamping a new leg gait over
# either a resting stance or the assistant's walk.
const _CARRY_TRACKS: Array = [
	"Hips", "Spine", "LeftArm", "LeftForeArm", "LeftHand",
	"RightArm", "RightForeArm", "RightHand",
]


## Install the seated, gently bobbing reins pose in `player`'s default library.
## `fwd` and `up` are character axes in skeleton space; `unit` is metres per
## skeleton unit. Returns false when the supplied rig is incomplete.
static func install_ride(player: AnimationPlayer, skel: Skeleton3D, fwd: Vector3, up: Vector3, unit: float) -> bool:
	return _install(player, skel, fwd, up, unit, RIDE)


## Install the standing horse-brushing loop, including its chest-height stroke.
## Returns false when the supplied rig is incomplete.
static func install_brush(player: AnimationPlayer, skel: Skeleton3D, fwd: Vector3, up: Vector3, unit: float) -> bool:
	return _install(player, skel, fwd, up, unit, BRUSH)


## Install the hay-carrying upper-body pose and its small load bob. Leg tracks
## are deliberately omitted so the clip does not replace the rig's rest/walk
## leg animation. Returns false when the supplied rig is incomplete.
static func install_carry(player: AnimationPlayer, skel: Skeleton3D, fwd: Vector3, up: Vector3, unit: float) -> bool:
	return _install(player, skel, fwd, up, unit, CARRY)


static func _install(player: AnimationPlayer, skel: Skeleton3D, fwd: Vector3, up: Vector3, unit: float, clip: String) -> bool:
	if player == null or skel == null:
		return false
	if clip != RIDE and clip != BRUSH and clip != CARRY:
		return false
	var need: Array = [
		"Hips", "Spine", "Head", "RightArm", "RightForeArm", "RightHand",
		"LeftArm", "LeftForeArm", "LeftHand", "LeftUpLeg", "LeftLeg", "LeftFoot",
		"RightUpLeg", "RightLeg", "RightFoot",
	]
	var idx: Dictionary = {}
	for name_value in need:
		var bone_name: String = str(name_value)
		var bone: int = _find(skel, bone_name)
		if bone < 0:
			return false
		idx[bone_name] = bone
	if fwd.length_squared() < 1e-10 or up.length_squared() < 1e-10:
		return false
	var forward: Vector3 = fwd.normalized()
	var vertical: Vector3 = up - forward * up.dot(forward)
	if vertical.length_squared() < 1e-10:
		return false
	vertical = vertical.normalized()
	var right: Vector3 = forward.cross(vertical).normalized()
	var metres: float = maxf(0.0001, unit)
	var beats: Array = _RIDE_BEATS
	var clip_length: float = RIDE_LOOP
	if clip == BRUSH:
		beats = _BRUSH_BEATS
		clip_length = BRUSH_LOOP
	elif clip == CARRY:
		beats = _CARRY_BEATS
		clip_length = CARRY_LOOP
	var poses: Array = []
	for beat_value in beats:
		var beat: float = float(beat_value)
		var phase: float = 0.0 if is_equal_approx(beat, clip_length) else beat / clip_length * TAU
		if clip == RIDE:
			poses.append(_solve_ride(skel, idx, forward, vertical, right, metres, phase))
		elif clip == BRUSH:
			poses.append(_solve_brush(skel, idx, forward, vertical, right, metres, phase))
		else:
			poses.append(_solve_carry(skel, idx, forward, vertical, right, metres, phase))
	var anim: Animation = Animation.new()
	anim.length = clip_length
	anim.loop_mode = Animation.LOOP_LINEAR
	var root: Node = player.get_node_or_null(player.root_node)
	if root == null:
		return false
	var path: String = str(root.get_path_to(skel))
	var first_pose: Dictionary = poses[0]
	var first_rotations: Dictionary = first_pose["rot"]
	var bones: Array = first_rotations.keys()
	for bone_value in bones:
		var bone: int = int(bone_value)
		var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("%s:%s" % [path, skel.get_bone_name(bone)]))
		for k in beats.size():
			var pose: Dictionary = poses[k]
			var rotations: Dictionary = pose["rot"]
			var value: Quaternion = rotations[bone]
			anim.rotation_track_insert_key(track, float(beats[k]), value)
	var hips: int = idx["Hips"]
	var position_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(position_track, NodePath("%s:%s" % [path, skel.get_bone_name(hips)]))
	for k in beats.size():
		var pose: Dictionary = poses[k]
		var hips_value: Vector3 = pose["hips_pos"]
		anim.position_track_insert_key(position_track, float(beats[k]), hips_value)
	var lib: AnimationLibrary = player.get_animation_library("") if player.has_animation_library("") else null
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	if lib.has_animation(clip):
		lib.remove_animation(clip)
	lib.add_animation(clip, anim)
	return true


static func _find(skel: Skeleton3D, n: String) -> int:
	var want: String = n.to_lower()
	for i in skel.get_bone_count():
		var have: String = skel.get_bone_name(i).to_lower()
		if have == want or have.ends_with(":" + want) or have.ends_with("_" + want):
			return i
	return -1


static func _solve_ride(skel: Skeleton3D, idx: Dictionary, fwd: Vector3, up: Vector3, right: Vector3, unit: float, phase: float) -> Dictionary:
	var local_rot: Dictionary = _rest_rotations(skel)
	var hips: int = idx["Hips"]
	var spine: int = idx["Spine"]
	var sway: float = sin(phase)
	var hips_pos: Vector3 = skel.get_bone_rest(hips).origin
	# The ride controller puts the actor root 0.72 m above the horse root. A
	# seated hip height of 0.54 m consequently places the rider on the saddle.
	hips_pos -= up * (hips_pos.dot(up) - (0.54 + 0.012 * sway) / unit)
	hips_pos -= fwd * (0.025 / unit)
	var G: Callable = func(i: int) -> Transform3D: return _global(skel, i, local_rot, hips_pos, hips)
	_tilt(skel, spine, local_rot, G, right, 0.035 + 0.015 * sway)
	_rotate_global(skel, spine, local_rot, G, fwd, 0.016 * sway)
	for side_value in ["Left", "Right"]:
		var side: String = str(side_value)
		var side_sign: float = -1.0 if side == "Left" else 1.0
		# About 28 degrees out from forward, followed by an approximately
		# 82-degree knee bend and a nearly vertical stirrup shin.
		var thigh: Vector3 = (fwd * 0.88 + right * (side_sign * 0.46) - up * 0.12).normalized()
		var shin: Vector3 = (-up + fwd * 0.03 - right * (side_sign * 0.03)).normalized()
		var foot: Vector3 = (fwd * 0.92 - up * 0.38 - right * (side_sign * 0.05)).normalized()
		_aim(skel, idx[side + "UpLeg"], local_rot, G, thigh)
		_aim(skel, idx[side + "Leg"], local_rot, G, shin)
		_aim(skel, idx[side + "Foot"], local_rot, G, foot)
		var shoulder: Vector3 = (G.call(idx[side + "Arm"]) as Transform3D).origin
		var target: Vector3 = hips_pos + up * (0.20 / unit)
		target += fwd * ((0.36 + 0.008 * sway) / unit) + right * (side_sign * 0.14 / unit)
		var pole: Vector3 = shoulder + right * (side_sign * 0.30 / unit) - up * (0.32 / unit) - fwd * (0.10 / unit)
		var hand_dir: Vector3 = (fwd * 0.65 - up * 0.35 - right * (side_sign * 0.08)).normalized()
		_reach_arm(skel, idx, local_rot, G, side, target, pole, hand_dir)
	return _result(idx, local_rot, hips_pos, _BODY_TRACKS)


static func _solve_brush(skel: Skeleton3D, idx: Dictionary, fwd: Vector3, up: Vector3, right: Vector3, unit: float, phase: float) -> Dictionary:
	var local_rot: Dictionary = _rest_rotations(skel)
	var hips: int = idx["Hips"]
	var spine: int = idx["Spine"]
	var hips_pos: Vector3 = skel.get_bone_rest(hips).origin
	var G: Callable = func(i: int) -> Transform3D: return _global(skel, i, local_rot, hips_pos, hips)
	var stroke: float = 0.5 - 0.5 * cos(phase)
	_tilt(skel, spine, local_rot, G, right, 0.045 + 0.035 * stroke)
	_rotate_global(skel, spine, local_rot, G, up, -0.025 + 0.05 * stroke)
	# The free hand remains forward on the horse while the torso follows the
	# working arm by only a few centimetres.
	var left_shoulder: Vector3 = (G.call(idx["LeftArm"]) as Transform3D).origin
	var left_target: Vector3 = left_shoulder - up * (0.20 / unit)
	left_target += fwd * ((0.32 + 0.02 * stroke) / unit) + right * (0.07 / unit)
	var left_pole: Vector3 = left_shoulder - right * (0.34 / unit) - up * (0.28 / unit) - fwd * (0.10 / unit)
	_reach_arm(skel, idx, local_rot, G, "Left", left_target, left_pole, (fwd * 0.70 - up * 0.30).normalized())
	# Cosine easing gives a 0.45 m forward/back stroke with no snap at either
	# end. Both endpoints remain inside a normal human arm's reach envelope.
	var right_shoulder: Vector3 = (G.call(idx["RightArm"]) as Transform3D).origin
	var right_target: Vector3 = right_shoulder - up * (0.13 / unit) - fwd * (0.04 / unit) - right * (0.04 / unit)
	right_target += fwd * (0.45 * stroke / unit)
	var right_pole: Vector3 = right_shoulder + right * (0.34 / unit) - up * (0.26 / unit) - fwd * (0.16 / unit)
	_reach_arm(skel, idx, local_rot, G, "Right", right_target, right_pole, (fwd * 0.85 - up * 0.30).normalized())
	# Unposed leg rotations are explicitly keyed here to plant the standing
	# stance after the assistant finishes walking to the brushing spot.
	return _result(idx, local_rot, hips_pos, _BODY_TRACKS)


static func _solve_carry(skel: Skeleton3D, idx: Dictionary, fwd: Vector3, up: Vector3, right: Vector3, unit: float, phase: float) -> Dictionary:
	var local_rot: Dictionary = _rest_rotations(skel)
	var hips: int = idx["Hips"]
	var spine: int = idx["Spine"]
	var bob: float = 0.006 * sin(phase)
	var hips_pos: Vector3 = skel.get_bone_rest(hips).origin + up * (bob / unit)
	var G: Callable = func(i: int) -> Transform3D: return _global(skel, i, local_rot, hips_pos, hips)
	_tilt(skel, spine, local_rot, G, right, 0.085 + 0.008 * sin(phase))
	for side_value in ["Left", "Right"]:
		var side: String = str(side_value)
		var side_sign: float = -1.0 if side == "Left" else 1.0
		var shoulder: Vector3 = (G.call(idx[side + "Arm"]) as Transform3D).origin
		# Wrists are exactly 0.35 m apart, at the carried bale's waist-height
		# centre. Their forward reach leaves the elbows gently bent.
		var target: Vector3 = hips_pos + up * (0.15 / unit) + fwd * (0.36 / unit)
		target += right * (side_sign * 0.175 / unit)
		var pole: Vector3 = shoulder + right * (side_sign * 0.26 / unit) - up * (0.24 / unit) - fwd * (0.12 / unit)
		var hand_dir: Vector3 = (fwd * 0.30 - up * 0.80 - right * (side_sign * 0.15)).normalized()
		_reach_arm(skel, idx, local_rot, G, side, target, pole, hand_dir)
	return _result(idx, local_rot, hips_pos, _CARRY_TRACKS)


static func _reach_arm(skel: Skeleton3D, idx: Dictionary, local_rot: Dictionary, G: Callable, side: String, target: Vector3, pole: Vector3, hand_dir: Vector3) -> void:
	var arm: int = idx[side + "Arm"]
	var forearm: int = idx[side + "ForeArm"]
	var hand: int = idx[side + "Hand"]
	var shoulder: Vector3 = (G.call(arm) as Transform3D).origin
	var upper: float = skel.get_bone_rest(forearm).origin.length()
	var lower: float = skel.get_bone_rest(hand).origin.length()
	if upper < 1e-6 or lower < 1e-6:
		return
	var elbow: Vector3 = _two_bone(shoulder, target, upper, lower, pole)
	_aim(skel, arm, local_rot, G, (elbow - shoulder).normalized())
	_aim(skel, forearm, local_rot, G, (target - elbow).normalized())
	_aim(skel, hand, local_rot, G, hand_dir)


static func _result(idx: Dictionary, local_rot: Dictionary, hips_pos: Vector3, tracks: Array) -> Dictionary:
	var rot: Dictionary = {}
	for name_value in tracks:
		var bone_name: String = str(name_value)
		var bone: int = idx[bone_name]
		rot[bone] = local_rot[bone]
	return {"rot": rot, "hips_pos": hips_pos}


static func _rest_rotations(skel: Skeleton3D) -> Dictionary:
	var local_rot: Dictionary = {}
	for i in skel.get_bone_count():
		local_rot[i] = skel.get_bone_rest(i).basis.get_rotation_quaternion()
	return local_rot


## Evaluate skeleton-space forward kinematics for the trial pose.
static func _global(skel: Skeleton3D, i: int, local_rot: Dictionary, hips_pos: Vector3, hips: int) -> Transform3D:
	var chain: Array = []
	var bone: int = i
	while bone >= 0:
		chain.push_front(bone)
		bone = skel.get_bone_parent(bone)
	var transform: Transform3D = Transform3D()
	for c in chain:
		var origin: Vector3 = hips_pos if c == hips else skel.get_bone_rest(c).origin
		transform = transform * Transform3D(Basis(local_rot[c] as Quaternion), origin)
	return transform


## Shortest-arc aim of a bone's rest child direction onto `dir`.
static func _aim(skel: Skeleton3D, i: int, local_rot: Dictionary, G: Callable, dir: Vector3) -> void:
	var child_dir: Vector3 = _child_offset(skel, i)
	if child_dir.length() < 1e-6 or dir.length() < 1e-6:
		return
	var wanted: Vector3 = dir.normalized()
	var global_transform: Transform3D = G.call(i)
	var now: Vector3 = (global_transform.basis * child_dir).normalized()
	var q: Quaternion = Quaternion(now, wanted) if now.dot(wanted) > -0.999 else Quaternion(global_transform.basis.x.normalized(), PI)
	var new_global: Basis = Basis(q) * global_transform.basis
	var parent: int = skel.get_bone_parent(i)
	var parent_global: Basis = (G.call(parent) as Transform3D).basis if parent >= 0 else Basis()
	local_rot[i] = (parent_global.inverse() * new_global).orthonormalized().get_rotation_quaternion()


## Lean a bone forward about the character's right axis.
static func _tilt(skel: Skeleton3D, i: int, local_rot: Dictionary, G: Callable, right: Vector3, angle: float) -> void:
	_rotate_global(skel, i, local_rot, G, right, -angle)


static func _rotate_global(skel: Skeleton3D, i: int, local_rot: Dictionary, G: Callable, axis: Vector3, angle: float) -> void:
	var global_transform: Transform3D = G.call(i)
	var new_global: Basis = Basis(axis.normalized(), angle) * global_transform.basis
	var parent: int = skel.get_bone_parent(i)
	var parent_global: Basis = (G.call(parent) as Transform3D).basis if parent >= 0 else Basis()
	local_rot[i] = (parent_global.inverse() * new_global).orthonormalized().get_rotation_quaternion()


static func _child_offset(skel: Skeleton3D, i: int) -> Vector3:
	for child in skel.get_bone_children(i):
		var offset: Vector3 = skel.get_bone_rest(child).origin
		if offset.length() > 1e-5:
			return offset.normalized()
	return Vector3.ZERO


## Elbow position for an upper/lower arm chain reaching from `s` to `t`.
static func _two_bone(s: Vector3, t: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var to_target: Vector3 = t - s
	var distance: float = clampf(to_target.length(), 0.001, (a + b) * 0.999)
	var direction: Vector3 = to_target.normalized()
	var cos_a: float = clampf((a * a + distance * distance - b * b) / (2.0 * a * distance), -1.0, 1.0)
	var perpendicular: Vector3 = (pole - s) - direction * (pole - s).dot(direction)
	perpendicular = perpendicular.normalized() if perpendicular.length() > 1e-5 else Vector3.UP
	return s + direction * a * cos_a + perpendicular * a * sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
