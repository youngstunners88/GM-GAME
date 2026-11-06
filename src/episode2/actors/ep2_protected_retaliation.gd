extends RefCounted
## Explicit hit-only exception. Ordinary civilians remain in Ep2TownLaw.
## Loadouts are intentionally explicit: never manufacture a missing assignment.
const POSE := preload("res://src/episode2/actors/ep2_armory_pose.gd")
const SOLVE := preload("res://src/episode2/actors/ep2_ranch_pose.gd")
const DRAW_SECONDS := 0.65
const DOWN_SECONDS := 0.85
const ENABLED := ["dude", "minister", "bartender", "sheriff", "rich", "utah", "store_clerk", "stable_assistant"]
var active: bool = false
var fired: bool = false
var elapsed: float = 0.0
var shots: int = 0
var folk: Ep2TownFolk
var host: Node
var weapon: Node3D
var muzzle: Node3D
var flash: MeshInstance3D
var shot_origin := Vector3.ZERO
var shot_direction := Vector3.ZERO
var shot_barrel_direction := Vector3.ZERO
var saved: Dictionary = {}
var owned_weapon: bool = false

func begin(chamber: Node, id: String, target: Ep2TownFolk) -> bool:
	if id not in ENABLED: return false
	if active: return true
	if target == null or target.dead or target.anim_player() == null: return false
	host = chamber
	folk = target
	saved = {"position": folk.position, "rotation": folk.rotation, "facing": folk.facing,
		"goal": folk._goal, "path": folk._path.duplicate(), "walking": folk._walking,
		"base": folk._base_clip, "clip": folk.current_clip(), "clock": folk.anim_player().callback_mode_process,
		"eye": host.get("eye_height"), "case_visible": true,
		"animation_time": folk.anim_player().current_animation_position,
		"actual_animation": folk.anim_player().assigned_animation, "playing": folk.anim_player().is_playing(),
		"speed_scale": folk.anim_player().speed_scale, "playing_speed": folk.anim_player().get_playing_speed(),
		"show_active": host.get("_show_active"), "show_blocks": host.get("_show_blocks_control"), "hold": host.get("_hold"), "case_rifle": null, "chore_props": []}
	for prop_name in ["HorseBrush", "CarriedHay"]:
		var prop: Node3D = folk.find_child(prop_name, true, false) as Node3D
		if prop != null:
			saved.chore_props.append([prop, prop.visible])
			prop.visible = false
	active = true
	folk.stop()
	if id == "rich":
		var case_rifle: Node3D = host.get("_sharps_case")
		saved.case_rifle = case_rifle
		if case_rifle != null:
			saved.case_visible = case_rifle.visible
			case_rifle.visible = false
		if not _prepare_rifle_draw():
			reset()
			return false
		weapon = folk.held_prop("Sharps")
		owned_weapon = weapon == null
		if weapon == null: weapon = POSE.attach_rifle(folk)
		if weapon == null:
			reset()
			return false
		weapon.transform = folk.get_meta("sharps_hand_transform")
		folk.hold_clip("ProtectedRifleDraw")
		folk.play_clip("ProtectedRifleDraw")
		folk.anim_player().seek(0.0, true)
		folk.anim_player().advance(0.0)
	else:
		owned_weapon = true
		if not _draw_remington():
			reset()
			return false
	active = true
	elapsed = 0.0
	fired = false
	folk.face_point(host.get("_player_pos"))
	if weapon.name == "Sharps": folk.facing -= POSE.RIFLE_YAW
	folk.anim_player().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	host.set("_show_blocks_control", true)
	host.set("_show_active", false)
	host.set("_hold", 0.0)
	host.set("_move_input", Vector2.ZERO)
	host.call("set_aim", false)
	muzzle = weapon.get_node("Muzzle")
	flash = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 0.76, 0.24)
	sphere.material = mat
	flash.mesh = sphere
	muzzle.add_child(flash)
	flash.visible = false
	return true


func reset() -> void:
	if not active: return
	if is_instance_valid(flash): flash.queue_free()
	if owned_weapon and is_instance_valid(weapon): folk.drop_prop(str(weapon.name))
	if is_instance_valid(weapon) and weapon.name == "Sharps":
		POSE.install_rifle(folk)
		if not owned_weapon: weapon.transform = folk.get_meta("sharps_hand_transform")
	folk.position = saved.position
	folk.rotation = saved.rotation
	folk.facing = saved.facing
	folk._goal = saved.goal
	folk._path = saved.path
	folk._walking = saved.walking
	folk._base_clip = saved.base
	folk.anim_player().callback_mode_process = saved.clock
	folk.play_clip(saved.clip)
	var ap: AnimationPlayer = folk.anim_player()
	if str(saved.actual_animation) != "" and ap.has_animation(saved.actual_animation):
		ap.speed_scale = float(saved.speed_scale)
		var custom_speed: float = float(saved.playing_speed) / ap.speed_scale if absf(ap.speed_scale) > 0.0001 else 0.0
		ap.play(saved.actual_animation, 0.0, custom_speed, custom_speed < 0.0)
		ap.seek(float(saved.animation_time), true)
		if not bool(saved.playing): ap.pause()
	host.set("_show_active", saved.show_active)
	host.set("_show_blocks_control", saved.show_blocks)
	host.set("_hold", saved.hold)
	for row in saved.chore_props:
		if is_instance_valid(row[0]): row[0].visible = row[1]
	host.set("eye_height", saved.eye)
	var case_rifle: Node3D = saved.case_rifle
	if is_instance_valid(case_rifle): case_rifle.visible = saved.case_visible
	active = false
	fired = false
	elapsed = 0.0


func _prepare_rifle_draw() -> bool:
	var ap: AnimationPlayer = folk.anim_player()
	var rigs: Array = folk.model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty(): return false
	var sk: Skeleton3D = rigs[0]
	var hips: int = SOLVE._find(sk, "Hips")
	var start: Dictionary = {}
	for b in sk.get_bone_count(): start[b] = sk.get_bone_pose_rotation(b)
	var hp: Vector3 = sk.get_bone_pose_position(hips)
	if not POSE.install_rifle(folk, host.get("_player_pos") + Vector3(0, float(host.get("eye_height")), 0)): return false
	var end: Animation = ap.get_animation("InspectRifle")
	var anim := Animation.new()
	anim.length = DRAW_SECONDS
	var path: String = str(ap.get_node(ap.root_node).get_path_to(sk))
	for b in sk.get_bone_count():
		var bp := NodePath("%s:%s" % [path, sk.get_bone_name(b)])
		var source: int = end.find_track(bp, Animation.TYPE_ROTATION_3D)
		var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, bp)
		var goal: Quaternion = end.rotation_track_interpolate(source, 0.0)
		anim.rotation_track_insert_key(track, 0, start[b])
		anim.rotation_track_insert_key(track, 0.50, goal)
		anim.rotation_track_insert_key(track, DRAW_SECONDS, goal)
	var hp_path := NodePath("%s:%s" % [path, sk.get_bone_name(hips)])
	var source: int = end.find_track(hp_path, Animation.TYPE_POSITION_3D)
	var track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, hp_path)
	var goal: Vector3 = end.position_track_interpolate(source, 0.0)
	anim.position_track_insert_key(track, 0, hp)
	anim.position_track_insert_key(track, 0.50, goal)
	anim.position_track_insert_key(track, DRAW_SECONDS, goal)
	ap.stop()
	ap.clear_caches()
	var lib: AnimationLibrary = Ep2TownFolk.own_default_library(ap)
	if lib.has_animation("ProtectedRifleDraw"): lib.remove_animation("ProtectedRifleDraw")
	lib.add_animation("ProtectedRifleDraw", anim)
	return true


func _draw_remington() -> bool:
	var ap: AnimationPlayer = folk.anim_player()
	var rigs: Array = folk.model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty(): return false
	var sk: Skeleton3D = rigs[0]
	var idx: Dictionary = {}
	for name in ["Hips", "RightArm", "RightForeArm", "RightHand"]:
		idx[name] = SOLVE._find(sk, name)
		if idx[name] < 0: return false
	var rot: Dictionary = {}
	for b in sk.get_bone_count(): rot[b] = sk.get_bone_pose_rotation(b)
	var hp: Vector3 = sk.get_bone_pose_position(idx.Hips)
	var start: Dictionary = rot.duplicate()
	var local: Transform3D = sk.global_transform.affine_inverse() * folk.global_transform
	sk.force_update_all_bone_transforms()
	var shoulder: Vector3 = folk.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(idx.RightArm).origin)
	var gun_frame := Transform3D(Basis.IDENTITY, Vector3(-0.20, shoulder.y - 0.10, 0.52))
	var target: Vector3 = host.get("_player_pos") + Vector3(0, float(host.get("eye_height")), 0)
	var heading: float = atan2(target.x - folk.global_position.x, target.z - folk.global_position.z)
	var aim: Vector3 = Basis(Vector3.UP, heading).inverse() * (target - folk.global_position) - gun_frame.origin
	gun_frame.basis = Basis.looking_at(aim.normalized(), Vector3.UP, true)

	var G: Callable = func(b: int) -> Transform3D: return SOLVE._global(sk, b, rot, hp, idx.Hips)
	SOLVE._reach_arm(sk, idx, rot, G, "Right", local * (gun_frame * Vector3(0, -0.055, -0.19)),
		local * Vector3(-0.43, shoulder.y - 0.30, 0.24), (local.basis * Vector3(0, -0.5, 0.7)).normalized())
	var hand: Transform3D = sk.global_transform * (G.call(idx.RightHand) as Transform3D)
	var hold: Transform3D = hand.affine_inverse() * folk.global_transform * gun_frame
	var anim := Animation.new()
	anim.length = DRAW_SECONDS
	var path: String = str(ap.get_node(ap.root_node).get_path_to(sk))
	# Key the full sampled body: a partial arm clip would reset the minister
	# chest/shoulder rest basis underneath the solved grip during blending.
	for b in sk.get_bone_count():
		var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("%s:%s" % [path, sk.get_bone_name(b)]))
		anim.rotation_track_insert_key(track, 0.0, start[b])
		anim.rotation_track_insert_key(track, 0.50, rot[b])
		anim.rotation_track_insert_key(track, DRAW_SECONDS, rot[b])
	var hip_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hip_track, NodePath("%s:%s" % [path, sk.get_bone_name(idx.Hips)]))
	anim.position_track_insert_key(hip_track, 0, hp)
	anim.position_track_insert_key(hip_track, DRAW_SECONDS, hp)
	ap.stop()
	ap.clear_caches()
	var lib: AnimationLibrary = Ep2TownFolk.own_default_library(ap)
	if lib.has_animation("ProtectedDraw"): lib.remove_animation("ProtectedDraw")
	lib.add_animation("ProtectedDraw", anim)
	# Bind from the evaluated imported rig, including its scale/translation tracks.
	ap.play("ProtectedDraw", 0.0)
	ap.seek(0.50, true)
	ap.advance(0.0)
	sk.force_update_all_bone_transforms()
	hand = sk.global_transform * sk.get_bone_global_pose(idx.RightHand)
	hold = hand.affine_inverse() * folk.global_transform * gun_frame
	weapon = Ep2RemingtonView.make_held()
	weapon.name = "GoldenRemington"
	if not folk.attach_prop(weapon, sk.get_bone_name(idx.RightHand)):
		weapon.free()
		return false
	weapon.transform = hold
	var mark := Marker3D.new()
	mark.name = "Muzzle"
	mark.position = Vector3(0, 0.055, 0.33)
	weapon.add_child(mark)
	folk.hold_clip("ProtectedDraw")
	ap.seek(0.0, true)
	ap.advance(0.0)
	return true


func step(delta: float) -> void:
	if not active or not is_instance_valid(folk): return
	elapsed += delta
	folk.face_point(host.get("_player_pos"))
	if weapon.name == "Sharps": folk.facing -= POSE.RIFLE_YAW
	var root_height: float = folk.position.y
	folk.step(delta)
	# Mounted actors keep their seat height while the reaction owns their motion.
	folk.position.y = root_height
	folk.anim_player().advance(delta)
	# Manual simulation must update bone attachments before reading the muzzle.
	for skeleton in folk.model.find_children("*", "Skeleton3D", true, false):
		(skeleton as Skeleton3D).force_update_all_bone_transforms()
	# Track the live eye through the final wrist aim (including a falling player).
	# Rotate the actual wrist, keeping the hand and attached revolver together.
	if elapsed >= 0.50:
		var attachment: BoneAttachment3D = weapon.get_parent() as BoneAttachment3D
		var skeleton: Skeleton3D = attachment.get_parent() as Skeleton3D
		var bone: int = skeleton.find_bone(attachment.bone_name)
		var target: Vector3 = host.get("_player_pos") + Vector3(0, float(host.get("eye_height")), 0)
		for iteration in 2:
			var wrist: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
			var barrel: Transform3D = wrist * weapon.transform * muzzle.transform
			var direction: Vector3 = (target - barrel.origin).normalized()
			var correction := Quaternion(barrel.basis.z.normalized(), direction)
			var parent: int = skeleton.get_bone_parent(bone)
			var parent_frame: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(parent)
			var local_basis: Basis = parent_frame.basis.inverse() * Basis(correction) * wrist.basis
			skeleton.set_bone_pose_rotation(bone, local_basis.orthonormalized().get_rotation_quaternion())
			skeleton.force_update_all_bone_transforms()
	if weapon.name == "Sharps": POSE.track_support(folk, weapon)
	if not fired and elapsed >= DRAW_SECONDS:
		fired = true
		shots += 1
		var attachment: BoneAttachment3D = weapon.get_parent() as BoneAttachment3D
		var skeleton: Skeleton3D = attachment.get_parent() as Skeleton3D
		var bone: int = skeleton.find_bone(attachment.bone_name)
		var muzzle_frame: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone) * weapon.transform * muzzle.transform
		shot_origin = muzzle_frame.origin
		var eye: Vector3 = host.get("_player_pos") + Vector3(0, float(host.get("eye_height")), 0)
		shot_direction = (eye - shot_origin).normalized()
		shot_barrel_direction = muzzle_frame.basis.z.normalized()
		flash.visible = true
		folk.kick()
		host.call("_sfx", "ep2_revolver_blast_1" if weapon.name == "GoldenRemington" else "ep2_winchester_shot_1")
		var hud: Node = host.get("_hud")
		if hud != null:
			hud.call("hurt")
			hud.call("fade_to", 1.0, DOWN_SECONDS)
	if fired:
		flash.visible = elapsed < DRAW_SECONDS + 0.08
		host.set("eye_height", move_toward(float(host.get("eye_height")), 0.35, delta * 2.2))
	if elapsed >= DRAW_SECONDS + DOWN_SECONDS and not bool(host.get("_resolved")):
		host.set_meta("protected_npc_defeat", true)
		host.set("_resolved", true)
		host.set("_running", false)
		host.emit_signal("chamber_failed")
