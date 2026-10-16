class_name Ep2BullHero
extends Node
## Inferno Bull as the founder's character sheet (2026-10-11, skill ep2-bull-repose-hero "Game GLB"):
## upright, arms relaxed (right fist on his flask pouch, left fist closed round a rifle held VERTICALLY at his side).
##
## The GLB's Idle_02 is now the Tripo bind pose (tools/ep2_forge/bull_hero_fix.py), which already IS that stance. This
## node keeps it while he walks: the Meshy walk clip swings the arms, and the Tripo right fist is sculpted INTO the
## flask pouch, so an arm swing tears the fist/pouch surface ("the melted arm"). Arms stay at rest (Ep2BullRestArm)
## unless he is sitting (quad / crate clips) or an IK reach is running; legs, hips and spine still walk.
## His rifle is a separate rigid prop placed from the LeftHand bone every skeleton update (never skinned: "liquid arm").
## Hidden while seated (both hands on the quad / on his knees).

const RIFLE_MODEL := "res://src/episode2/assets/winchester_1886.glb"
## Rifle GLB: 1.2 m, muzzle +Z, centred (skill ep2-handoff-props). The fist holds it just below the receiver.
const GRIP_ALONG := 0.10
const RIFLE_SCALE_PER_M := 1.42 / 2.5    # a touch over the hideout BULL_RIFLE_SCALE (1.3 @ 2.5 m): the sheet rifle is chunky
## His helmet lamp is LIT on the sheet. Lens centre on the bind pose (skeleton space, rig cm), found from the bright
## lens texels of the atlas (bull_hero_fix.py era measurement: x -0.01, y 2.24-2.35, z 0.39 m).
const LAMP_REST := Vector3(-0.7, 222.0, 37.0)

var bull: Ep2Actor = null
var rifle: Node3D = null
var rest_arm: Ep2BullRestArm = null
var _hand: int = -1
var _scale: float = 1.5
var motion: Ep2MotionLayer = null
var aim_target: Vector3 = Vector3.ZERO
var aim_until: float = -1.0
var shot_time: float = -99.0
var _muzzle_dir: Vector3 = Vector3.UP
## Source skin surface landmarks: left vertex 61101, right vertex 28464 (native 2.4 m).
const LEFT_PALM_M := Vector3(0.088063, -0.086519, -0.038417)
const RIGHT_PALM_M := Vector3(0.020910, 0.045520, -0.045412)
var _palm_m := Vector3.ZERO


## Dress `b` once: rest-arm lock + the vertical rifle in his left fist. Safe on a fallback (no skeleton) actor.
static func dress(b: Ep2Actor, with_rifle: bool = true) -> Ep2BullHero:
	if b == null or b.skeleton == null:
		return null
	var h := Ep2BullHero.new()
	h.name = "BullHero"
	h.bull = b
	b.add_child(h)
	h._setup(with_rifle)
	return h


## Sheet grade (founder: "muddy"): black fur, dark denim, brown leather, brass. The restored PBR is an orange-tinted
## self-glow over a copper-leaning atlas, so in golden woods light he read as a bronze statue. Cool and darken the
## albedo a touch, take the glow down to a neutral lift and keep the metal low: measured in _measure / the report.
## True when inferno_bull_rigged.glb is the painted Hunyuan3D Bull (own UVs and textures, its own lamp, cigar and
## rifle modelled in; v3 head grafted on the v2 body). The old Bull's grade, lamp prop and rifle prop do not apply:
## the painted albedo is already dark, and the props would sit mid-face or double the rifle in his fist.
const PAINTED_GLB := true
const GRADE_ALBEDO := Color(1.0, 1.0, 1.0) if PAINTED_GLB else Color(0.60, 0.66, 1.04)
const GRADE_EMISSION := Color(0.85, 0.85, 0.9)
const GRADE_EMISSION_ENERGY := 0.0
const GRADE_METALLIC := 0.35


static func grade(model: Node) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var d := m.get_surface_override_material(i) as StandardMaterial3D
			if d == null:
				continue
			d.albedo_color = GRADE_ALBEDO
			d.emission = GRADE_EMISSION
			d.emission_energy_multiplier = GRADE_EMISSION_ENERGY
			d.metallic = minf(d.metallic, GRADE_METALLIC)
			d.rim_tint = 0.2


func _setup(with_rifle: bool) -> void:
	var sk: Skeleton3D = bull.skeleton
	if bull.model:
		grade(bull.model)
	rest_arm = Ep2BullRestArm.new()
	rest_arm.name = "BullHeroRestArm"
	sk.add_child(rest_arm)
	motion = Ep2MotionLayer.new()
	motion.actor = bull
	motion.bull_carry = true
	sk.add_child(motion)
	bull.pose_stepped.connect(_step)
	sk.skeleton_updated.connect(_sync_rifle)
	_add_lamp(sk)
	_hand = sk.find_bone("LeftHand")
	_palm_m = LEFT_PALM_M * bull.height_m / 2.4
	if not with_rifle or _hand < 0 or not ResourceLoader.exists(RIFLE_MODEL):
		return
	_scale = RIFLE_SCALE_PER_M * bull.height_m
	# Desired rest frame in skeleton space: muzzle up with a slight forward/outward tip, the rifle's TOP (lift, +Y)
	# facing out to his left so the side plate - lever, receiver, stock - reads in profile from the front (sheet).
	var muzzle := Vector3(0.06, 1.0, 0.10).normalized()
	var lift := Vector3(1.0, 0.0, 0.0)
	var side := lift.cross(muzzle).normalized()           # right-handed: side x lift = muzzle
	lift = muzzle.cross(side).normalized()
	# GRIP = the hand bone itself (a little past the wrist toward the knuckles), not a measured rest point: the old
	# GRIP_REST sat ~0.2 m off the drawn fist and the rifle hovered beside him (founder 2026-10-11 "WHY THE SEPARATION").
	var rest: Transform3D = sk.get_bone_global_rest(_hand)
	var sk_scale: float = maxf(sk.global_transform.basis.get_scale().x, 0.0001)
	var grip: Vector3 = rest.origin + rest.basis * (_palm_m / sk_scale)
	grip += muzzle * (GRIP_ALONG * _scale / sk_scale)
	rifle = (load(RIFLE_MODEL) as PackedScene).instantiate() as Node3D
	rifle.name = "BullHeroRifle"
	_solid(rifle)
	# Child of the LeftHand BoneAttachment3D: it follows the FINAL drawn hand (after every modifier), so the rifle can
	# never part from his fist - no per-frame sync to drift.
	var hold: Node3D = bull.holder("LeftHand")
	if hold == null:
		return
	hold.add_child(rifle)
	# Painted model: its own rifle is already in his left fist. This prop stays as the invisible grip/aim reference
	# (recoil, muzzle point and the CI grip test measure it), so the rifle is never drawn twice.
	rifle.visible = not PAINTED_GLB
	# The holder is the hand bone's frame in METRES (Ep2Actor.holder undoes the rig's cm scale).
	var rb: Basis = rest.basis.orthonormalized()
	rifle.transform = Transform3D(rb.inverse() * Basis(side, lift, muzzle) * Basis.from_scale(Vector3.ONE * _scale),
		rb.inverse() * (grip - rest.origin) * sk_scale)


func _add_lamp(sk: Skeleton3D) -> void:
	if PAINTED_GLB:
		return    # the painted model has its own lamp on the hat; the old rest-pose lamp prop would float on his face
	var head: int = sk.find_bone("Head")
	var hold: Node3D = bull.holder("Head")
	if head < 0 or hold == null:
		return
	var sc: float = maxf(sk.global_transform.basis.get_scale().x, 0.0001)
	var local: Vector3 = (sk.get_bone_global_rest(head).affine_inverse() * LAMP_REST) * sc
	var lens := MeshInstance3D.new()
	lens.name = "BullHelmetLamp"
	var sm := SphereMesh.new()
	sm.radius = 0.042 * bull.height_m / 2.4
	sm.height = sm.radius * 1.2
	lens.mesh = sm
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(1.0, 0.86, 0.5)
	lens.material_override = lm
	lens.position = local
	hold.add_child(lens)
	var glow := OmniLight3D.new()
	glow.name = "BullHelmetLampLight"
	glow.light_color = Color(1.0, 0.82, 0.55)
	glow.light_energy = 0.5
	glow.omni_range = 2.2
	glow.shadow_enabled = false
	glow.position = local * 1.15
	hold.add_child(glow)


func _step(dt: float) -> void:
	if bull == null or rest_arm == null:
		return
	var clip: String = bull.current_clip()
	var seated: bool = clip.contains("Sit") or clip.contains("sit")
	var reaching: bool = bull.reach_weight("Right") > 0.01 or bull.reach_weight("Left") > 0.01
	# The quad ride's seated clip (Chair_Sit_Idle) swings the sculpted arms into a torn, half-invisible elbow (founder 2026-10-11): only the
	# drinking clip is allowed to move the arms; every other pose keeps them at the imported rest pose.
	rest_arm.resting = (not seated or clip.contains("Chair")) and not reaching
	if rifle:
		# Painted Bull: his own rifle is baked into the mesh; this prop is only the invisible grip/aim reference.
		rifle.visible = not PAINTED_GLB and not seated and bull.is_visible_in_tree()
	var aiming: bool = bull.motion_time < aim_until and not seated
	var local_carry: Vector3 = bull.global_transform.basis * Vector3(0.06, 1.0, 0.10).normalized()
	var wanted: Vector3 = (aim_target - bull.global_position - Vector3.UP * bull.height_m * 0.57).normalized() if aiming else local_carry
	_muzzle_dir = _muzzle_dir.slerp(wanted, clampf(dt * 9.0, 0.0, 1.0)).normalized()
	motion.aim_weight = move_toward(motion.aim_weight, 1.0 if aiming else 0.0, dt * 4.0)
	motion.recoil = exp(-maxf(0.0, bull.motion_time - shot_time) * 14.0) if bull.motion_time - shot_time < 0.5 else 0.0


func aim_at(target_world: Vector3) -> void:
	aim_target = target_world
	aim_until = bull.motion_time + 0.7


func fire_at(target_world: Vector3) -> Vector3:
	aim_at(target_world)
	shot_time = bull.motion_time
	# At the emission event use the actual barrel frame, with its contact pivot retained.
	_muzzle_dir = (target_world - rifle.global_position).normalized() if rifle else Vector3.BACK
	_sync_rifle()
	return rifle.to_global(Vector3(0, 0, 0.60)) if rifle else bull.global_position + Vector3.UP * 1.5


func _sync_rifle() -> void:
	if rifle == null or _hand < 0:
		return
	var sk: Skeleton3D = bull.skeleton
	var hand_world: Transform3D = sk.global_transform * sk.get_bone_global_pose(_hand)
	var palm: Vector3 = hand_world.origin + hand_world.basis * (_palm_m / sk.global_transform.basis.get_scale().x)
	var muzzle: Vector3 = _muzzle_dir.normalized()
	# Recoil rotates around the fist; translation along the barrel would break the grip.
	var recoil: float = motion.recoil * 0.055 if motion else 0.0
	var lift: Vector3 = bull.global_transform.basis.x if absf(muzzle.dot(Vector3.UP)) > 0.85 else Vector3.UP
	var side: Vector3 = lift.cross(muzzle).normalized()
	muzzle = Basis(side, -recoil) * muzzle
	lift = muzzle.cross(side).normalized()
	rifle.global_transform = Transform3D(Basis(side, lift, muzzle).scaled(Vector3.ONE * _scale), palm + muzzle * (GRIP_ALONG * _scale))


## Double-sided, opaque (skill ep2-solid-models): the rifle GLB is an open Tripo shell.
static func _solid(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				var d: BaseMaterial3D = (src as BaseMaterial3D).duplicate()
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				d.emission_energy_multiplier = minf(d.emission_energy_multiplier, 0.1)
				d.metallic = 0.35           # metallic 1.0 everywhere mirrored the warm sky: an orange stick at range
				d.roughness_texture = null  # a glossy ORM (G ~0.3) put a sun-orange sheen on the whole stock
				d.roughness = 0.62
				# The sheet's rifle is dark walnut and blued steel; this GLB's orange stock read as a toy at range.
				d.albedo_color = d.albedo_color * Color(0.42, 0.40, 0.50)
				m.set_surface_override_material(i, d)


