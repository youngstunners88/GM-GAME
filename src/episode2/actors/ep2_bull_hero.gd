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
## Rest-pose fist centre in skeleton space (rig cm): measured on the bind pose, a little in front of / below the wrist.
const GRIP_REST := Vector3(56.0, 129.0, 19.0)
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
var _rel: Transform3D = Transform3D.IDENTITY    # rifle frame relative to the LeftHand bone (skeleton space)
var _scale: float = 1.5


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
const GRADE_ALBEDO := Color(0.60, 0.66, 1.04)
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
	_add_lamp(sk)
	_hand = sk.find_bone("LeftHand")
	if not with_rifle or _hand < 0 or not ResourceLoader.exists(RIFLE_MODEL):
		return
	_scale = RIFLE_SCALE_PER_M * bull.height_m
	# Desired rest frame in skeleton space: muzzle up with a slight forward/outward tip, the rifle's TOP (lift, +Y)
	# facing out to his left so the side plate - lever, receiver, stock - reads in profile from the front (sheet).
	var muzzle := Vector3(0.06, 1.0, 0.10).normalized()
	var lift := Vector3(1.0, 0.0, 0.0)
	var side := lift.cross(muzzle).normalized()           # right-handed: side x lift = muzzle
	lift = muzzle.cross(side).normalized()
	var want := Transform3D(Basis(side, lift, muzzle), GRIP_REST)
	_rel = sk.get_bone_global_rest(_hand).affine_inverse() * want
	rifle = (load(RIFLE_MODEL) as PackedScene).instantiate() as Node3D
	rifle.name = "BullHeroRifle"
	add_child(rifle)
	rifle.top_level = true
	_solid(rifle)
	sk.skeleton_updated.connect(_sync)


func _add_lamp(sk: Skeleton3D) -> void:
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


func _process(_dt: float) -> void:
	if bull == null or rest_arm == null:
		return
	var clip: String = bull.current_clip()
	var seated: bool = clip.contains("Sit") or clip.contains("sit")
	var reaching: bool = bull.reach_weight("Right") > 0.01 or bull.reach_weight("Left") > 0.01
	rest_arm.resting = not seated and not reaching
	if rifle:
		rifle.visible = not seated and bull.is_visible_in_tree()


func _sync() -> void:
	if rifle == null or not rifle.visible or _hand < 0:
		return
	var sk: Skeleton3D = bull.skeleton
	var t: Transform3D = sk.global_transform * sk.get_bone_global_pose(_hand) * _rel
	var b := t.basis.orthonormalized()
	var muzzle: Vector3 = b.z
	var origin: Vector3 = t.origin + muzzle * (GRIP_ALONG * _scale)
	rifle.global_transform = Transform3D(b.scaled(Vector3.ONE * _scale), origin)


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
