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
		"show_active": host.get("_show_active"), "show_blocks": host.get("_show_blocks_control"), "hold": host.get("_hold")}
	active = true
	folk.stop()
	if id == "rich":
		var case_rifle: Node3D = host.get("_sharps_case")
		if case_rifle != null:
			saved.case_visible = case_rifle.visible
			case_rifle.visible = false
		weapon = folk.held_prop("Sharps")
		owned_weapon = weapon == null
		if weapon == null: weapon = POSE.attach_rifle(folk)
		if weapon == null:
			reset()
			return false
		folk.hold_clip("InspectRifle")
	else:
		owned_weapon = true
		if not _draw_remington():
			reset()
			return false
	active = true
	elapsed = 0.0
	fired = false
	folk.face_point(host.get("_player_pos"))
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
	folk.position = saved.position
	folk.rotation = saved.rotation
	folk.facing = saved.facing
	folk._goal = saved.goal
	folk._path = saved.path
	folk._walking = saved.walking
	folk._base_clip = saved.base
	folk.anim_player().callback_mode_process = saved.clock
	folk.play_clip(saved.clip)
	folk.anim_player().seek(float(saved.animation_time), true)
	host.set("_show_active", saved.show_active)
	host.set("_show_blocks_control", saved.show_blocks)
	host.set("_hold", saved.hold)
	host.set("eye_height", saved.eye)
	var case_rifle: Node3D = host.get("_sharps_case")
	if case_rifle != null: case_rifle.visible = saved.case_visible
	active = false
	fired = false
	elapsed = 0.0


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
	var gun_frame := Transform3D(Basis.IDENTITY, Vector3(-0.20, folk.height_m * 0.72, 0.52))
	var G: Callable = func(b: int) -> Transform3D: return SOLVE._global(sk, b, rot, hp, idx.Hips)
	SOLVE._reach_arm(sk, idx, rot, G, "Right", local * (gun_frame.origin - Vector3(0, -0.04, 0.03)),
		local * Vector3(-0.43, folk.height_m * 0.61, 0.24), (local.basis * Vector3(0, -0.5, 0.7)).normalized())
	var hand: Transform3D = sk.global_transform * (G.call(idx.RightHand) as Transform3D)
	var hold: Transform3D = hand.affine_inverse() * folk.global_transform * gun_frame
	var anim := Animation.new()
	anim.length = DRAW_SECONDS
	var path: String = str(ap.get_node(ap.root_node).get_path_to(sk))
	for name in ["RightArm", "RightForeArm", "RightHand"]:
		var b: int = idx[name]
		var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("%s:%s" % [path, sk.get_bone_name(b)]))
		anim.rotation_track_insert_key(track, 0.0, start[b])
		anim.rotation_track_insert_key(track, 0.50, rot[b])
		anim.rotation_track_insert_key(track, DRAW_SECONDS, rot[b])
	ap.stop()
	ap.clear_caches()
	var lib: AnimationLibrary = Ep2TownFolk.own_default_library(ap)
	if lib.has_animation("ProtectedDraw"): lib.remove_animation("ProtectedDraw")
	lib.add_animation("ProtectedDraw", anim)
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
	return true


func step(delta: float) -> void:
	if not active or not is_instance_valid(folk): return
	elapsed += delta
	folk.face_point(host.get("_player_pos"))
	folk.step(delta)
	folk.anim_player().advance(delta)
	if not fired and elapsed >= DRAW_SECONDS:
		fired = true
		shots += 1
		shot_origin = muzzle.global_position
		var eye: Vector3 = host.get("_player_pos") + Vector3(0, float(host.get("eye_height")), 0)
		shot_direction = (eye - shot_origin).normalized()
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
