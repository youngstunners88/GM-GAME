extends RefCounted
## Instance-local armory mannerisms. Preserve the founder skins and leg tracks.
const SOLVE := preload("res://src/episode2/actors/ep2_ranch_pose.gd")

static func install(folk: Ep2TownFolk) -> bool:
	var ap: AnimationPlayer = folk.anim_player()
	if ap == null: return false
	var rigs: Array = folk.model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty(): return false
	var sk: Skeleton3D = rigs[0]
	var idx: Dictionary = {}
	for n in ["Hips", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		idx[n] = SOLVE._find(sk, n)
		if idx[n] < 0: return false
	var up: Vector3 = (sk.global_basis.inverse() * Vector3.UP).normalized()
	var fwd: Vector3 = (sk.global_basis.inverse() * folk.global_basis.z).normalized()
	var right: Vector3 = fwd.cross(up).normalized()
	var unit: float = sk.global_basis.get_scale().y
	var lib: AnimationLibrary = Ep2TownFolk.own_default_library(ap)
	ap.stop()
	for clip in ["Idle", "Counter", "Greet", "Talk", "Walk", "StairsUp", "Carry"]:
		if not lib.has_animation(clip): continue
		var old: Animation = lib.get_animation(clip)
		var anim: Animation = old.duplicate(true)
		var path: String = str(ap.get_node(ap.root_node).get_path_to(sk))
		var tracks: Dictionary = {}
		for n in idx:
			if n == "Hips": continue
			var b: int = idx[n]
			var bp := NodePath("%s:%s" % [path, sk.get_bone_name(b)])
			var t: int = anim.find_track(bp, Animation.TYPE_ROTATION_3D)
			if t >= 0: anim.remove_track(t)
		for n in idx:
			if n == "Hips": continue
			var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [path, sk.get_bone_name(idx[n])]))
			tracks[n] = t
		for frame in 49:
			var phase: float = float(frame) / 48.0 * TAU
			var rot: Dictionary = SOLVE._rest_rotations(sk)
			var hp: Vector3 = sk.get_bone_rest(idx.Hips).origin
			var G: Callable = func(b: int) -> Transform3D: return SOLVE._global(sk, b, rot, hp, idx.Hips)
			for side in ["Left", "Right"]:
				var shoulder: Vector3 = (G.call(idx[side + "Arm"]) as Transform3D).origin
				var sign_side: float = -1.0 if side == "Left" else 1.0
				var arm_length: float = sk.get_bone_rest(idx[side + "ForeArm"]).origin.length() + sk.get_bone_rest(idx[side + "Hand"]).origin.length()
				var swing: float = sin(phase) * (0.045 if clip in ["Walk", "StairsUp"] else 0.008) * sign_side
				var target: Vector3 = shoulder - up * arm_length * 0.92 + right * sign_side * 0.07 / unit + fwd * (0.035 + swing) / unit
				if clip == "Greet" and side == "Right":
					var gesture: float = pow(sin(phase * 0.5), 2.0)
					target += (up * 0.25 + fwd * 0.15) * gesture / unit
				if clip == "Carry": target = hp + up * 0.12 / unit + fwd * 0.32 / unit + right * sign_side * 0.22 / unit
				var pole: Vector3 = shoulder + right * sign_side * 0.35 / unit - up * 0.24 / unit
				SOLVE._reach_arm(sk, idx, rot, G, side, target, pole, -up + fwd * 0.12)
			SOLVE._rotate_global(sk, idx.Head, rot, G, up, 0.035 * sin(phase))
			for n in tracks: anim.rotation_track_insert_key(tracks[n], float(frame) / 48.0 * anim.length, rot[idx[n]])
		lib.remove_animation(clip)
		lib.add_animation(clip, anim)
	folk.procedural_bob = false
	return true


const SHARPS := "res://src/episode2/extras/armory/showcase/sharps.glb"
## Measured on the current scoped showcase mesh after its 45-degree heading correction.
## Its normalization is 0.8511 of the canonical 1.21 m founder rifle.
const GUN_GRIP := Vector3(0.0035, 0.1416, -0.2140)
const GUN_SUPPORT := Vector3(0.0035, 0.1671, -0.0012)
const GUN_MUZZLE := Vector3(0.0035, 0.2054, 0.5181)
const GUN_SCALE := 1.175
const RIFLE_YAW := 0.70

static func rifle_frame(folk: Ep2TownFolk) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, RIFLE_YAW) * Basis(Vector3.RIGHT, -0.05), Vector3(-0.20, folk.height_m * 0.70, 0.08))


static func install_rifle(folk: Ep2TownFolk, target: Vector3 = Vector3.INF) -> bool:
	var ap: AnimationPlayer = folk.anim_player()
	if ap == null: return false
	var sk: Skeleton3D = folk.model.find_children("*", "Skeleton3D", true, false)[0]
	var idx: Dictionary = {}
	for n in ["Hips", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand"]:
		idx[n] = SOLVE._find(sk, n)
		if idx[n] < 0: return false
	ap.play("Idle", 0.0)
	ap.seek(0.0, true)
	ap.advance(0.0)
	var rot: Dictionary = {}
	for b in sk.get_bone_count(): rot[b] = sk.get_bone_pose_rotation(b)
	var hp: Vector3 = sk.get_bone_pose_position(idx.Hips)
	var G: Callable = func(b: int) -> Transform3D: return SOLVE._global(sk, b, rot, hp, idx.Hips)
	var local: Transform3D = sk.global_transform.affine_inverse() * folk.global_transform
	var gun: Transform3D = rifle_frame(folk)
	if target.is_finite():
		var heading: float = atan2(target.x - folk.global_position.x, target.z - folk.global_position.z) - RIFLE_YAW
		var direction: Vector3 = Basis(Vector3.UP, heading).inverse() * (target - folk.global_position) - gun.origin
		gun.basis = Basis.looking_at(direction.normalized(), Vector3.UP, true)
	var support: Vector3 = gun * ((GUN_SUPPORT - GUN_GRIP) * GUN_SCALE)
	for side in ["Left", "Right"]:
		var palm: Vector3 = support if side == "Left" else gun.origin
		# A palm is distal to the wrist, not the wrist bone origin itself.
		var wrist: Vector3 = palm + gun.basis * (Vector3(0, -0.065, -0.03) if side == "Left" else Vector3(0, -0.015, -0.055))
		var pole: Vector3 = Vector3(0.39 if side == "Left" else -0.43, folk.height_m * 0.56, 0.12)
		SOLVE._reach_arm(sk, idx, rot, G, side, local * wrist, local * pole, (local.basis * gun.basis * Vector3(0, 0.3, 0.95)).normalized())
	var anim := Animation.new()
	anim.length = 3.9
	anim.loop_mode = Animation.LOOP_LINEAR
	var path: String = str(ap.get_node(ap.root_node).get_path_to(sk))
	for b in sk.get_bone_count():
		var t: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [path, sk.get_bone_name(b)]))
		anim.rotation_track_insert_key(t, 0, rot[b])
		anim.rotation_track_insert_key(t, anim.length, rot[b])
	var t: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, NodePath("%s:%s" % [path, sk.get_bone_name(idx.Hips)]))
	anim.position_track_insert_key(t, 0, hp)
	anim.position_track_insert_key(t, anim.length, hp)
	ap.stop()
	ap.clear_caches()
	var lib: AnimationLibrary = Ep2TownFolk.own_default_library(ap)
	if lib.has_animation("InspectRifle"): lib.remove_animation("InspectRifle")
	lib.add_animation("InspectRifle", anim)
	# Keep the solved grip during dialogue and locomotion, retaining each clip's legs.
	var clip_map: Dictionary = {}
	for source in ["Idle", "Counter", "Greet", "Talk", "Reach", "PutDown", "Walk", "GroundedWalk", "GroundedCarry"]:
		if not lib.has_animation(source): continue
		var held: Animation = lib.get_animation(source).duplicate(true)
		for b in sk.get_bone_count():
			var lower: bool = false
			var ancestor: int = b
			while ancestor >= 0:
				if ancestor in [SOLVE._find(sk, "LeftUpLeg"), SOLVE._find(sk, "RightUpLeg"), idx.Hips]:
					lower = ancestor != idx.Hips
					break
				ancestor = sk.get_bone_parent(ancestor)
			if lower or b == idx.Hips: continue
			var bp := NodePath("%s:%s" % [path, sk.get_bone_name(b)])
			var old_track: int = held.find_track(bp, Animation.TYPE_ROTATION_3D)
			if old_track >= 0: held.remove_track(old_track)
			var track: int = held.add_track(Animation.TYPE_ROTATION_3D)
			held.track_set_path(track, bp)
			held.rotation_track_insert_key(track, 0, rot[b])
			held.rotation_track_insert_key(track, held.length, rot[b])
		var held_name: String = "Sharps" + source
		if lib.has_animation(held_name): lib.remove_animation(held_name)
		lib.add_animation(held_name, held)
		clip_map[source.to_lower()] = held_name
	folk.set_meta("sharps_clip_map", clip_map)
	# Store the grip relative to the actual solved hand, including rig scale.
	var hand: Transform3D = sk.global_transform * (G.call(idx.RightHand) as Transform3D)
	folk.set_meta("sharps_hand_transform", hand.affine_inverse() * folk.global_transform * gun)
	return true


## The scoped Sharps in its grip frame (origin = the trigger hand's palm, muzzle +z, sight up, real size): the one rifle that lies in the lit case and
## sits in Rich's hand, so it can pass from one to the other without a swap (null when the streamed model is missing).
static func make_rifle() -> Node3D:
	if not ResourceLoader.exists(SHARPS): return null
	var holder := Node3D.new()
	holder.name = "Sharps"
	var model: Node3D = (load(SHARPS) as PackedScene).instantiate()
	holder.add_child(model)
	model.transform = Transform3D(Basis(Vector3.UP, PI * 0.25).scaled(Vector3.ONE * GUN_SCALE), -GUN_GRIP * GUN_SCALE)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = (GUN_MUZZLE - GUN_GRIP) * GUN_SCALE
	holder.add_child(muzzle)
	return holder


## Where each wrist goes on the rifle (its grip frame): the palm is distal to the wrist, so these are behind and under the contact points.
static func wrist_on_rifle(side: String) -> Vector3:
	return (GUN_SUPPORT - GUN_GRIP) * GUN_SCALE + Vector3(0, -0.065, -0.03) if side == "Left" else Vector3(0, -0.015, -0.055)


static func attach_rifle(folk: Ep2TownFolk) -> Node3D:
	if not folk.has_meta("sharps_hand_transform"): return null
	var holder: Node3D = make_rifle()
	if holder == null: return null
	if not folk.attach_prop(holder, "hand_r"):
		holder.free()
		return null
	holder.transform = folk.get_meta("sharps_hand_transform")
	return holder


## Keep the independent fore-end contact after the firing wrist tracks a moving eye.
static func track_support(folk: Ep2TownFolk, weapon: Node3D) -> void:
	var sk: Skeleton3D = folk.model.find_children("*", "Skeleton3D", true, false)[0]
	var idx: Dictionary = {}
	for name in ["Hips", "LeftArm", "LeftForeArm", "LeftHand"]:
		idx[name] = SOLVE._find(sk, name)
		if idx[name] < 0: return
	var attachment: BoneAttachment3D = weapon.get_parent() as BoneAttachment3D
	var hand: int = sk.find_bone(attachment.bone_name)
	var gun: Transform3D = sk.global_transform * sk.get_bone_global_pose(hand) * weapon.transform
	var target: Vector3 = gun * ((GUN_SUPPORT - GUN_GRIP) * GUN_SCALE + Vector3(0, -0.065, -0.03))
	var pole: Vector3 = folk.global_transform * Vector3(0.39, folk.height_m * 0.56, 0.12)
	var inverse: Transform3D = sk.global_transform.affine_inverse()
	var rot: Dictionary = {}
	for b in sk.get_bone_count(): rot[b] = sk.get_bone_pose_rotation(b)
	var hp: Vector3 = sk.get_bone_pose_position(idx.Hips)
	var G: Callable = func(b: int) -> Transform3D: return SOLVE._global(sk, b, rot, hp, idx.Hips)
	SOLVE._reach_arm(sk, idx, rot, G, "Left", inverse * target, inverse * pole,
		(inverse.basis * gun.basis * Vector3(0, 0.3, 0.95)).normalized())
	for name in ["LeftArm", "LeftForeArm", "LeftHand"]: sk.set_bone_pose_rotation(idx[name], rot[idx[name]])
	sk.force_update_all_bone_transforms()
