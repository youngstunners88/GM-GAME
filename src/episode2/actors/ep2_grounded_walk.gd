class_name Ep2GroundedWalk
extends RefCounted
## In-place gait with linear stance travel and a raised, eased swing.
## FK/IK uses each model's own rest transforms; actor translation owns root motion.
static var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/episode2/config/grounded_walk.json"))
const SOLVE := preload("res://src/episode2/actors/ep2_ranch_pose.gd")

## Replace only locomotion clips on this instance; keep all authored work gestures.
static func install(folk: Ep2TownFolk) -> bool:
	var ap: AnimationPlayer = folk.anim_player()
	if ap == null: return false
	var skeletons: Array = folk.model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return false
	var skel: Skeleton3D = skeletons[0]
	var hips: int = SOLVE._find(skel, "Hips")
	if hips < 0: return false
	for side in ["Left", "Right"]:
		for suffix in ["UpLeg", "Leg", "Foot"]:
			if SOLVE._find(skel, side + suffix) < 0: return false
	var data: Dictionary = config
	var unit: float = skel.global_basis.get_scale().y
	var up: Vector3 = (skel.global_basis.inverse() * Vector3.UP).normalized()
	var forward: Vector3 = (skel.global_basis.inverse() * folk.global_basis.z).normalized()
	var right: Vector3 = forward.cross(up).normalized()
	var library: AnimationLibrary = Ep2TownFolk.own_default_library(ap)
	# Sample real idle/carry upper-body poses. Their local rotations preserve
	# each rest basis, avoiding the T-pose/axis errors of raw mocap replacement.
	for source in ["Idle", "Carry"]:
		if source == "Carry" and not ap.has_animation(source): continue
		ap.play(source)
		ap.seek(0.3, true)
		ap.advance(0.0)
		var upper: Dictionary = {}
		for b in skel.get_bone_count(): upper[b] = skel.get_bone_pose_rotation(b)
		var anim := Animation.new()
		anim.length = float(data.cycle_seconds)
		anim.loop_mode = Animation.LOOP_LINEAR
		var path: String = str(ap.get_node(ap.root_node).get_path_to(skel))
		var tracks: Dictionary = {}
		for b in skel.get_bone_count():
			var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(track, NodePath("%s:%s" % [path, skel.get_bone_name(b)]))
			tracks[b] = track
		var pos_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, NodePath("%s:%s" % [path, skel.get_bone_name(hips)]))
		var count: int = int(data.samples)
		for sample in count + 1:
			var phase: float = float(sample) / count if sample < count else 0.0
			var pose: Dictionary = solve(skel, hips, upper, forward, up, right, unit, phase, source == "Carry")
			var time: float = float(sample) / count * anim.length
			for b in skel.get_bone_count(): anim.rotation_track_insert_key(tracks[b], time, pose.rot[b])
			anim.position_track_insert_key(pos_track, time, pose.hips_pos)
		var name: String = "GroundedCarry" if source == "Carry" else "GroundedWalk"
		if library.has_animation(name): library.remove_animation(name)
		library.add_animation(name, anim)
	folk.procedural_bob = false
	folk.walk_clip_speed = float(data.reference_speed)
	folk.walk_clip = "GroundedWalk"
	ap.play("Idle")
	ap.advance(0.0)
	return true

## Solve one full rig pose. Stance feet move backwards at the actor's reference
## speed, cancelling root travel in world space; each leg keeps its rest length.
static func solve(skel: Skeleton3D, hips: int, upper: Dictionary, fwd: Vector3, up: Vector3, right: Vector3, unit: float, phase: float, carrying: bool) -> Dictionary:
	var data: Dictionary = config
	var rot: Dictionary = upper.duplicate()
	var hp: Vector3 = skel.get_bone_rest(hips).origin - up * ((float(data.hip_lower_m) - float(data.hip_bob_m) * cos(phase * TAU * 2.0)) / unit)
	var targets: Dictionary = {}
	var stride: float = float(data.reference_speed) * float(data.cycle_seconds) * float(data.stance_fraction) / unit
	for side in ["Left", "Right"]:
		var p: float = fposmod(phase + (0.5 if side == "Right" else 0.0), 1.0)
		var stance: float = float(data.stance_fraction)
		var along: float
		var lift: float = 0.0
		if p < stance:
			along = stride * (0.5 - p / stance)
		else:
			var k: float = (p - stance) / (1.0 - stance)
			along = stride * (smoothstep(0.0, 1.0, k) - 0.5)
			lift = float(data.clearance_m) / unit * pow(sin(k * PI), 2.0)
		var foot: int = SOLVE._find(skel, side + "Foot")
		var rest: Transform3D = skel.get_bone_global_rest(foot)
		targets[side] = rest.origin + fwd * along + up * lift
	# Rise over the planted leg at mid-stance; lower only as far as a long step
	# actually needs. A fixed deep hip offset made the entire walk a crouch.
	var lower: float = 0.0
	for side in ["Left", "Right"]:
		var thigh: int = SOLVE._find(skel, side + "UpLeg")
		var shin: int = SOLVE._find(skel, side + "Leg")
		var foot: int = SOLVE._find(skel, side + "Foot")
		var start: Vector3 = SOLVE._global(skel, thigh, rot, hp, hips).origin
		var offset: Vector3 = start - (targets[side] as Vector3)
		var horizontal: Vector3 = offset - up * offset.dot(up)
		var length: float = (skel.get_bone_rest(shin).origin.length() + skel.get_bone_rest(foot).origin.length()) * float(data.leg_extension)
		var vertical: float = sqrt(maxf(0.0001, length * length - horizontal.length_squared()))
		lower = maxf(lower, offset.dot(up) - vertical)
	hp -= up * lower
	var G: Callable = func(b: int) -> Transform3D: return SOLVE._global(skel, b, rot, hp, hips)
	for side in ["Left", "Right"]:
		var p: float = fposmod(phase + (0.5 if side == "Right" else 0.0), 1.0)
		var thigh: int = SOLVE._find(skel, side + "UpLeg")
		var shin: int = SOLVE._find(skel, side + "Leg")
		var foot: int = SOLVE._find(skel, side + "Foot")
		var rest: Transform3D = skel.get_bone_global_rest(foot)
		var target: Vector3 = targets[side]
		var start: Vector3 = (G.call(thigh) as Transform3D).origin
		var knee: Vector3 = SOLVE._two_bone(start, target, skel.get_bone_rest(shin).origin.length(), skel.get_bone_rest(foot).origin.length(), start + fwd)
		SOLVE._aim(skel, thigh, rot, G, knee - start)
		SOLVE._aim(skel, shin, rot, G, target - (G.call(shin) as Transform3D).origin)
		# Keep the sole level throughout stance instead of inheriting shin tilt.
		rot[foot] = ((G.call(skel.get_bone_parent(foot)) as Transform3D).basis.inverse() * rest.basis).orthonormalized().get_rotation_quaternion()
		var arm: int = SOLVE._find(skel, side + "Arm")
		if arm >= 0 and not carrying:
			SOLVE._rotate_global(skel, arm, rot, G, right, sin(p * TAU) * float(data.arm_swing_radians))
	return {"rot": rot, "hips_pos": hp}
