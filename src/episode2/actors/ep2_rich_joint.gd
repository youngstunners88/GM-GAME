class_name Ep2RichJoint
extends Node3D
## Rich's joint, lit (founder 2026-11-22: "why isn't his joint lit with smoke twirling"). The joint is modelled into the founder's Rich
## (rich_armory2.glb, between his lips, tip forward on his left); this puts a glowing ember on its tip and a thin curl of smoke rising from
## it, both riding his Head bone, so they stay on the joint through every clip. Chill and positive: a slow ember breath, a lazy curl that
## fades, a bigger draw while he is on his CigarPuff break. No new cutscene: the brain's CigarPuff task is the draw.

## The joint's tip in the model's mesh space (glTF axes, metres), measured on rich_armory2.glb (the single forward protrusion at mouth
## height, 0.21 m ahead of the Head bone; tools-side render with a marker on it: docs/episode2-quality/rich-joint-20261123).
const TIP_MESH := Vector3(0.181, 1.524, -0.065)
const EMBER_R := 0.0075
const EMBER := Color(1.0, 0.42, 0.12)
const SMOKE := Color(0.88, 0.88, 0.88, 0.45)

var folk: Ep2TownFolk = null
var ember: MeshInstance3D = null
var glow: OmniLight3D = null
var smoke: CPUParticles3D = null
var _mat: StandardMaterial3D = null
var _t: float = 0.0


## Light the joint on `f` (no-op, returns null, when the rig has no Head bone or no skin to measure from).
static func light(f: Ep2TownFolk) -> Ep2RichJoint:
	if f == null or f.model == null:
		return null
	var sks: Array = f.model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return null
	var sk: Skeleton3D = sks[0]
	var head: int = -1
	for i in sk.get_bone_count():
		if Ep2TownFolk._bone_key(sk.get_bone_name(i)).ends_with("head") and not Ep2TownFolk._bone_key(sk.get_bone_name(i)).ends_with("headtop_end"):
			head = i
			break
	if head < 0:
		return null
	# the tip in the Head bone's own frame: the skin's bind pose maps mesh space into that bone's frame (skeleton units)
	var local := Vector3.INF
	for mi in f.model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.skin == null:
			continue
		for bi in m.skin.get_bind_count():
			var b: int = m.skin.get_bind_bone(bi)
			if b < 0:
				b = sk.find_bone(m.skin.get_bind_name(bi))
			if b == head:
				local = m.skin.get_bind_pose(bi) * TIP_MESH
				break
		if local.is_finite():
			break
	if not local.is_finite():
		return null
	var j := Ep2RichJoint.new()
	j.name = "RichJoint"
	j.folk = f
	if not f.attach_prop(j, sk.get_bone_name(head), local):
		j.free()
		return null
	j._build()
	return j


func _build() -> void:
	# children in metres whatever the rig's units (attach_prop already undoes the model's own scale; this undoes the skeleton's)
	var s: float = global_transform.basis.get_scale().x if is_inside_tree() else 1.0
	if s > 1e-5 and absf(s - 1.0) > 1e-3:
		scale /= s
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = EMBER
	_mat.emission_enabled = true
	_mat.emission = EMBER
	_mat.emission_energy_multiplier = 2.4
	ember = MeshInstance3D.new()
	ember.name = "Ember"
	var sm := SphereMesh.new()
	sm.radius = EMBER_R
	sm.height = EMBER_R * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	ember.mesh = sm
	ember.material_override = _mat
	ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ember)
	glow = OmniLight3D.new()
	glow.name = "EmberGlow"
	glow.light_color = EMBER
	glow.light_energy = 0.35
	glow.omni_range = 0.35
	glow.shadow_enabled = false
	add_child(glow)
	smoke = CPUParticles3D.new()
	smoke.name = "JointSmoke"
	smoke.amount = 34
	smoke.lifetime = 3.2
	smoke.preprocess = 2.0
	smoke.local_coords = false                       # the curl stays in the air when he turns his head
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.004
	smoke.direction = Vector3.UP
	smoke.spread = 8.0
	smoke.gravity = Vector3(0.0, 0.05, 0.0)
	smoke.initial_velocity_min = 0.04
	smoke.initial_velocity_max = 0.09
	smoke.tangential_accel_min = 0.05                # the twirl: a slow sideways pull round the rising column
	smoke.tangential_accel_max = 0.16
	smoke.angular_velocity_min = -40.0
	smoke.angular_velocity_max = 40.0
	smoke.damping_min = 0.02
	smoke.damping_max = 0.06
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.0))
	fade.set_color(1, Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.0))
	fade.add_point(0.12, SMOKE)
	fade.add_point(0.55, Color(SMOKE.r, SMOKE.g, SMOKE.b, SMOKE.a * 0.6))
	smoke.color_ramp = fade
	var puff := QuadMesh.new()
	puff.size = Vector2(0.05, 0.05)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_texture = _soft_dot()
	puff.material = pm
	smoke.mesh = puff
	add_child(smoke)


## A round soft-edged puff (no file: 32 px radial falloff).
static func _soft_dot() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d: float = Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.6))
	return ImageTexture.create_from_image(img)


## The ember breathes (0.8 - 1.2 s), and draws bright with a thicker plume on his CigarPuff break.
func _process(delta: float) -> void:
	_t += delta
	var drawing: bool = folk != null and folk.current_clip() == "CigarPuff"
	var breath: float = 0.75 + 0.25 * sin(_t * TAU / 1.0)
	var k: float = (1.6 if drawing else 1.0) * breath
	if _mat:
		_mat.emission_energy_multiplier = 2.4 * k
	if glow:
		glow.light_energy = 0.35 * k
	if smoke:
		smoke.initial_velocity_max = 0.14 if drawing else 0.09
		smoke.scale_amount_max = 1.4 if drawing else 1.0
