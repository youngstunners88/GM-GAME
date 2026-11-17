extends Node3D
## The Gold Rush Auction as a GRAND EVENT (founder 2026-11-17: "I want the auction to really be dazzling and for the GM logo to at
## least be present on the stage or one or 2 of the walls ... This needs to be a grand marvel event. We need to show flames.").
## Streamed with the Episode 2 extras and loaded by path from Ep2AuctionHouse (no class_name). Local space = the hall's.
##   - The GM logo: a 3.2 m disc over the block on the back wall, a 2.2 m disc on each side wall, each in its own warm wash.
##   - Fire: two iron braziers burning on the stage's front corners; four flame jets along the stage lip that erupt on every
##     call (`burst`); a flame in every wall lantern.
##   - Gold: dust drifting down through the stage light all night; a shower of gold leaf when the lot is called (`shower`).
## Web build: CPU particles and unshaded additive quads only (the export is the Compatibility renderer); three lights in all.

const LOGO := "res://src/episode2/extras/auction/gm_logo_disc.png"
const BRAZIER_SOUND := "res://src/episode2/extras/audio/town/hall_braziers.ogg"
const JET_SOUND := "res://src/episode2/extras/audio/town/hall_fire_jet.ogg"
## [position, diameter, yaw] of each logo disc (hall: back wall z = 32, side walls x = +-11).
const LOGOS := [[Vector3(0.0, 4.35, 31.78), 3.2, PI], [Vector3(-10.78, 4.1, 15.5), 2.2, PI * 0.5], [Vector3(10.78, 4.1, 15.5), 2.2, -PI * 0.5]]
const BRAZIERS := [Vector3(-5.7, 1.1, 24.55), Vector3(5.7, 1.1, 24.55)]
const JETS := [-4.4, -1.6, 1.6, 4.4]                # x along the stage lip
const JET_Z := 24.3
const JET_Y := 1.12
const JET_SECONDS := 1.15

var jets_fired: int = 0                             # the gate reads these
var showers: int = 0
var _jets: Array[CPUParticles3D] = []
var _jet_light: OmniLight3D
var _jet_t: float = 0.0
var _jet_sound: AudioStreamPlayer3D
var _brazier_lights: Array[OmniLight3D] = []
var _gold_rain: CPUParticles3D
var _shower: CPUParticles3D
var _t: float = 0.0


## Build it all into the hall. `sconces` are the hall's wall-lantern rows [side, z]; `half_w` its half width.
func build(sconces: Array, half_w: float) -> void:
	name = "GrandEvent"
	_logos()
	var fire := _fire_material(Color(1.0, 0.55, 0.16))
	for p in BRAZIERS:
		_brazier(p, fire)
	for x in JETS:
		var jet := _flames(Vector3(x, JET_Y, JET_Z), fire, 56, 0.9, 0.34, Vector3(0, 9.5, 0), 0.06)
		jet.emitting = false
		jet.one_shot = true
		jet.explosiveness = 0.15
		jet.scale_amount_min = 0.7
		jet.scale_amount_max = 1.25
		_jets.append(jet)
		_iron(Vector3(0.16, 0.08, 0.16), Vector3(x, JET_Y - 0.02, JET_Z))      # the nozzle
	_jet_light = _omni(Vector3(0, 2.4, 23.6), 0.0, 13.0, Color(1.0, 0.6, 0.25))
	_jet_sound = _sound(JET_SOUND, Vector3(0, 1.6, JET_Z), false, 9.0, -2.0)
	var small := _fire_material(Color(1.0, 0.62, 0.22))
	for row in sconces:
		var x: float = float(row[0]) * (half_w - 0.42)
		_flames(Vector3(x, 3.42, float(row[1])), small, 10, 0.5, 0.07, Vector3(0, 0.55, 0), 0.02).scale_amount_max = 0.55
	_gold()
	_sound(BRAZIER_SOUND, Vector3(0, 1.6, 24.4), true, 6.0, -9.0)


## Every jet erupts (a call, a cheer, the sale). Throttled: a jet cannot fire again while it is still burning.
func burst() -> void:
	if _jet_t > 0.0:
		return
	_jet_t = JET_SECONDS
	jets_fired += 1
	for j in _jets:
		j.restart()
		j.emitting = true
	if _jet_sound != null and _jet_sound.stream != null:
		_jet_sound.pitch_scale = randf_range(0.95, 1.05)
		_jet_sound.play()


## Gold leaf showers over the block (the lot is called).
func shower() -> void:
	showers += 1
	if _shower != null:
		_shower.restart()
		_shower.emitting = true
	burst()


func _process(delta: float) -> void:
	_t += delta
	_jet_t = maxf(0.0, _jet_t - delta)
	if _jet_light != null:
		var on: float = clampf(_jet_t / JET_SECONDS * 1.4, 0.0, 1.0)
		_jet_light.light_energy = on * (5.5 + sin(_t * 47.0) * 0.8)
	for i in _brazier_lights.size():
		var l: OmniLight3D = _brazier_lights[i]
		l.light_energy = 2.2 + sin(_t * 13.0 + i * 2.1) * 0.25 + sin(_t * 29.0 + i) * 0.18 + sin(_t * 5.3 + i * 0.7) * 0.2


# --- pieces -----------------------------------------------------------------------------------------------------------------

func _logos() -> void:
	if not ResourceLoader.exists(LOGO):
		return
	var tex: Texture2D = load(LOGO)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission_energy_multiplier = 0.55               # gold catches the room's fire; the green rim reads in shadow
	mat.metallic = 0.35
	mat.roughness = 0.45
	for li in LOGOS.size():
		var row: Array = LOGOS[li]
		var d: float = float(row[1])
		var q := QuadMesh.new()
		q.size = Vector2(d, d)
		var disc := MeshInstance3D.new()
		disc.name = "GMLogo%d" % li
		disc.mesh = q
		disc.material_override = mat
		disc.position = row[0]
		disc.rotation.y = float(row[2])
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc)
		# a brass ring behind it, standing proud of the planks
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = d * 0.5 - 0.02
		tor.outer_radius = d * 0.5 + 0.09
		ring.mesh = tor
		var brass := StandardMaterial3D.new()
		brass.albedo_color = Color(0.78, 0.58, 0.22)
		brass.metallic = 0.85
		brass.roughness = 0.32
		ring.material_override = brass
		ring.rotation = Vector3(PI * 0.5, float(row[2]), 0.0)
		ring.position = (row[0] as Vector3) + Basis(Vector3.UP, float(row[2])) * Vector3(0, 0, -0.03)
		add_child(ring)
	# the back-wall disc gets its own wash from the truss; the side discs ride the brazier and chandelier light
	var wash := SpotLight3D.new()
	wash.position = Vector3(0, 6.6, 26.0)
	wash.light_color = Color(1.0, 0.82, 0.55)
	wash.light_energy = 3.0
	wash.spot_range = 9.0
	wash.spot_angle = 22.0
	add_child(wash)
	wash.look_at_from_position(wash.position, LOGOS[0][0], Vector3.UP)


func _brazier(p: Vector3, fire: Material) -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09, 0.08, 0.075)
	iron.metallic = 0.7
	iron.roughness = 0.55
	var bowl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.2
	cm.height = 0.34
	bowl.mesh = cm
	bowl.material_override = iron
	bowl.position = p + Vector3(0, 1.0, 0)
	add_child(bowl)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.06
	sm.bottom_radius = 0.16
	sm.height = 0.86
	stem.mesh = sm
	stem.material_override = iron
	stem.position = p + Vector3(0, 0.43, 0)
	add_child(stem)
	var coals := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.38
	cc.bottom_radius = 0.38
	cc.height = 0.02
	coals.mesh = cc
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.25, 0.05, 0.0)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.32, 0.05)
	glow.emission_energy_multiplier = 2.5
	coals.material_override = glow
	coals.position = p + Vector3(0, 1.16, 0)
	add_child(coals)
	_flames(p + Vector3(0, 1.18, 0), fire, 48, 0.85, 0.28, Vector3(0, 2.2, 0), 0.05)
	var embers := _flames(p + Vector3(0, 1.3, 0), _fire_material(Color(1.0, 0.7, 0.3)), 14, 2.6, 0.2, Vector3(0, 1.2, 0), 0.008)
	embers.scale_amount_min = 0.06
	embers.scale_amount_max = 0.12
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.6
	_brazier_lights.append(_omni(p + Vector3(0, 1.9, -0.3), 2.2, 8.5, Color(1.0, 0.56, 0.22)))


## A column of flame: additive billboards rising, shrinking and cooling from white-yellow to deep red.
func _flames(at: Vector3, mat: Material, amount: int, life: float, radius: float, gravity: Vector3, size: float) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.position = at
	f.amount = amount
	f.lifetime = life
	f.local_coords = false
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = radius
	f.direction = Vector3.UP
	f.spread = 12.0
	f.gravity = gravity
	f.initial_velocity_min = 0.2
	f.initial_velocity_max = 0.7
	f.damping_min = 0.4
	f.damping_max = 1.2
	f.angle_min = -180.0
	f.angle_max = 180.0
	f.scale_amount_min = 0.55
	f.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.55))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	f.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.set_color(1, Color(0.6, 0.05, 0.0, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.12, 0.9))
	f.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.7) * (size / 0.05)
	q.material = mat
	f.mesh = q
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(f)
	return f


static func _fire_material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	m.albedo_texture = _soft_dot()
	m.no_depth_test = false
	m.disable_receive_shadows = true
	return m


static var _dot: Texture2D
## A soft round flame tongue (no texture file: a radial gradient, taller than wide).
static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.62)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot


func _gold() -> void:
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(1.0, 0.8, 0.3)
	leaf.metallic = 1.0
	leaf.roughness = 0.25
	leaf.emission_enabled = true
	leaf.emission = Color(1.0, 0.74, 0.25)
	leaf.emission_energy_multiplier = 0.9
	leaf.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	leaf.vertex_color_use_as_albedo = true
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.05)
	q.material = leaf
	_gold_rain = CPUParticles3D.new()
	_gold_rain.name = "GoldDust"
	_gold_rain.position = Vector3(0, 6.6, 26.5)
	_gold_rain.amount = 90
	_gold_rain.lifetime = 7.0
	_gold_rain.preprocess = 7.0
	_gold_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_gold_rain.emission_box_extents = Vector3(6.0, 0.2, 3.5)
	_gold_rain.gravity = Vector3(0, -0.75, 0)
	_gold_rain.initial_velocity_min = 0.0
	_gold_rain.initial_velocity_max = 0.15
	_gold_rain.angular_velocity_min = -220.0
	_gold_rain.angular_velocity_max = 220.0
	_gold_rain.angle_max = 360.0
	_gold_rain.mesh = q
	add_child(_gold_rain)
	var big := q.duplicate() as QuadMesh
	big.size = Vector2(0.07, 0.1)
	_shower = CPUParticles3D.new()
	_shower.name = "GoldShower"
	_shower.position = Vector3(0, 6.8, 21.0)
	_shower.amount = 420
	_shower.lifetime = 5.5
	_shower.one_shot = true
	_shower.explosiveness = 0.7
	_shower.emitting = false
	_shower.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_shower.emission_box_extents = Vector3(7.0, 0.3, 6.0)
	_shower.direction = Vector3.UP
	_shower.spread = 70.0
	_shower.initial_velocity_min = 1.0
	_shower.initial_velocity_max = 3.0
	_shower.gravity = Vector3(0, -1.6, 0)
	_shower.damping_min = 0.6
	_shower.damping_max = 1.4
	_shower.angular_velocity_min = -400.0
	_shower.angular_velocity_max = 400.0
	_shower.angle_max = 360.0
	var hue := Gradient.new()
	hue.set_color(0, Color(1.0, 0.86, 0.4))
	hue.set_color(1, Color(0.85, 0.6, 0.2))
	_shower.color_initial_ramp = hue
	_shower.mesh = big
	add_child(_shower)


func _iron(size: Vector3, at: Vector3) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	b.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.09, 0.08)
	m.metallic = 0.7
	b.material_override = m
	b.position = at
	add_child(b)


func _omni(at: Vector3, energy: float, rng: float, color: Color) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = at
	o.light_energy = energy
	o.omni_range = rng
	o.light_color = color
	add_child(o)
	return o


func _sound(path: String, at: Vector3, loop: bool, unit: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.position = at
	p.bus = "SFX"
	p.unit_size = unit
	p.max_distance = 60.0
	p.volume_db = db
	if ResourceLoader.exists(path):
		var s: AudioStream = (load(path) as AudioStream).duplicate()
		if loop and s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		p.stream = s
	add_child(p)
	if loop and p.stream != null:
		p.autoplay = true
		p.play()
	return p
