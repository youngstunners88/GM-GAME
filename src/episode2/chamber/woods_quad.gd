class_name WoodsQuadChamber
extends Ep2Interlude
## Interlude 2 - THE BEAR WOODS (founder 2026-10-09): they step out of the mine lift into the wood. Inferno Bull is a master
## of disguise: nothing he owns can be found, least of all his FLAME-DESIGNER QUAD, which sits under a hand-built pile of
## leaves and branches in a thicket. They sneak there (walk, never run: the bears hear), he throws the leaves off, they ride
## it down the trail to a ridge, and spy on the bear camp to plan the hunt. Next: Lil Blunt shoots the bears from the quad
## while Inferno drives (not built yet - this chamber is the groundwork and ends the playable slice with TO BE CONTINUED).
## The "Deep Mining 3" song starts the moment they mount the quad.
##
## Beats: SNEAK -> REVEAL (leaves off) -> MOUNT -> RIDE (on rails, 10 s) -> SPY (hold RMB: spyglass, spot 6 bears) -> DONE.
## Skill: ep2-interlude-chain.

enum Beat { SNEAK, REVEAL, MOUNT, RIDE, SPY, DONE }

const MUSIC := "res://src/assets/music/ep2_deep_mining3_quad.ogg"
const QUAD_LOOP := "res://src/assets/sounds/ep2_quad_loop.mp3"

# --- layout (metres; flat ground, +z is "deeper into the wood") ---
const SPAWN := Vector3(0.0, 0.0, 2.0)
## The trail Inferno leads along while they sneak.
const SNEAK_TRAIL: Array = [Vector2(0.0, 4.0), Vector2(1.0, 17.0), Vector2(-2.5, 30.0), Vector2(-1.5, 43.0), Vector2(-3.8, 51.0)]
const QUAD_POS := Vector3(-7.4, 0.0, 53.5)         # hidden in the thicket beside the end of the trail
const QUAD_YAW := 0.0                              # nose toward +z
## The ride (x, z): from the thicket back out onto the wood road and down to the ridge.
const RIDE_TRAIL: Array = [Vector2(-7.4, 53.5), Vector2(-2.0, 62.0), Vector2(5.0, 78.0), Vector2(6.0, 98.0), Vector2(0.0, 116.0),
	Vector2(-3.0, 125.0), Vector2(0.0, 133.0)]
const RIDE_SPEED := 9.5
const SPY_EYE := Vector3(2.6, 1.55, 147.0)         # prone behind the ferns on the ridge
const CAMP_CENTRE := Vector3(0.0, 0.0, 188.0)
const BEAR_SPOTS: Array = [Vector2(-5.5, 183.0), Vector2(-2.0, 192.0), Vector2(4.0, 181.0), Vector2(6.5, 190.0), Vector2(-8.5, 191.0), Vector2(1.5, 197.0)]
const PATROL_BEARS: Array = [Vector2(-15.0, 24.0), Vector2(14.0, 37.0), Vector2(-14.0, 47.0)]
const HEARING := 19.0                              # a bear hears a running Lil Blunt inside this radius
const SPY_ZOOM_FOV := 16.0
const SPY_SPOT_ANGLE := 0.075                      # radians (~4.3 deg): how close to a bear the spyglass must be
const SPY_TIMEOUT := 70.0

var _ground_mat: StandardMaterial3D = null
var _leaf_mats: Array = []
var _trees: Array = []                              # [Vector2 position, radius] for trunk collision
var _quad: Node3D = null
var _quad_wheels: Array = []
var _quad_light: SpotLight3D = null
var _cover: Node3D = null
var _cover_bits: Array = []                         # [Node3D, Vector3 outward velocity, float spin]
var _reveal_t: float = -1.0
var _riding: bool = false
var _ride_pts: PackedVector3Array = PackedVector3Array()
var _ride_len: PackedFloat32Array = PackedFloat32Array()
var _ride_s: float = 0.0
var _ride_total: float = 0.0
var _ride_speed: float = 0.0
var _ride_done: bool = false
var _quad_yaw: float = 0.0
var _engine: AudioStreamPlayer = null
var _sneak_i: int = 0
var _bull_waiting: bool = false
var _warn_cd: float = 0.0
var _stay_cd: float = 0.0
var _noise_hits: int = 0
var _patrols: Array = []                            # [Ep2Actor, Vector2 a, Vector2 b, bool going_b]
var _camp_bears: Array = []                         # Ep2Actor
var _marked: Array = []                             # bool per camp bear
var _marks: Array = []                              # marker node per camp bear
var _zoom: float = 0.0
var _aim_on: bool = false
var _spy_t: float = 0.0
var _spy_done: bool = false
var _hud_layer: CanvasLayer = null
var _hud: Ep2FpsHud = null
var _bear_clips: Dictionary = {}


func _init() -> void:
	title_card = "THE BEAR WOODS"
	music_path = ""                                  # the lift's song carries on until the quad starts (Deep Mining 3 begins at MOUNT)
	walk_speed = 2.3                                 # a sneak: walking IS the stealth
	camera_min = Vector3(-80.0, 0.4, -30.0)
	camera_max = Vector3(80.0, 30.0, 240.0)


func _chamber_id() -> String:
	return "woods_quad"


func _beat_label(b: int) -> String:
	return Beat.keys()[clampi(b, 0, Beat.size() - 1)]


# --- the set ----------------------------------------------------------------------------------------------------------

func _build_room() -> void:
	_apply_light()
	_leaf_mats = [_plain(Color(0.13, 0.31, 0.12), 0.95), _plain(Color(0.19, 0.39, 0.14), 0.95), _plain(Color(0.10, 0.25, 0.10), 0.95),
		_plain(Color(0.27, 0.42, 0.12), 0.95)]
	_ground_mat = _tex(GRAVEL_TEX, Color(0.38, 0.42, 0.25), 0.35)
	_box(Vector3(260.0, 0.5, 330.0), Vector3(0.0, -0.25, 105.0), _ground_mat)
	_build_trails()
	_build_forest()
	_build_mine_hut()
	_build_quad()
	_build_cover()
	_build_camp()
	_build_ridge()
	_build_patrols()


func _apply_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.20, 0.34, 0.52)
	psm.sky_horizon_color = Color(0.92, 0.62, 0.38)
	psm.ground_horizon_color = Color(0.45, 0.36, 0.28)
	psm.ground_bottom_color = Color(0.14, 0.16, 0.12)
	psm.sun_angle_max = 25.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.52, 0.56)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.58, 0.55, 0.50)
	env.fog_density = 0.011
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	_env_node.environment = env
	_sun.rotation_degrees = Vector3(-22.0, -35.0, 0.0)
	_sun.light_color = Color(1.0, 0.78, 0.55)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true


func _build_trails() -> void:
	var dirt: StandardMaterial3D = _tex(GRAVEL_TEX, Color(0.50, 0.38, 0.26), 0.5)
	var all_trails: Array = [SNEAK_TRAIL, RIDE_TRAIL]
	for tr in all_trails:
		var w: float = 2.2 if tr == SNEAK_TRAIL else 4.4
		for i in range(tr.size() - 1):
			var a: Vector2 = tr[i]
			var b: Vector2 = tr[i + 1]
			var mid: Vector2 = (a + b) * 0.5
			var seg := _box(Vector3(w, 0.04, a.distance_to(b) + 0.6), Vector3(mid.x, 0.02, mid.y), dirt)
			seg.rotation.y = atan2(b.x - a.x, b.y - a.y)
	# from the ridge the ride continues as a track to the camp road: a faded ribbon
	var spawn_pad := _box(Vector3(6.0, 0.04, 6.0), Vector3(0.0, 0.02, 2.0), dirt)
	spawn_pad.name = "LiftPad"


func _distance_to_trails(p: Vector2) -> float:
	var best: float = 1e9
	for tr in [SNEAK_TRAIL, RIDE_TRAIL]:
		for i in range(tr.size() - 1):
			var a: Vector2 = tr[i]
			var b: Vector2 = tr[i + 1]
			var ab: Vector2 = b - a
			var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


## A thousand-tree wood in three MultiMeshes (trunks, lower cones, upper cones): one draw call each.
func _build_forest() -> void:
	var bark: StandardMaterial3D = _plain(Color(0.26, 0.18, 0.12), 0.95)
	var xf_trunk: Array = []
	var xf_low: Array = []
	var xf_up: Array = []
	var xf_bush: Array = []
	var gx: float = -70.0
	var idx: int = 0
	while gx <= 70.0:
		var gz: float = -14.0
		while gz <= 236.0:
			var hs: float = sin(gx * 12.9898 + gz * 78.233) * 43758.5453
			var r1: float = hs - floor(hs)
			var hs2: float = sin(gx * 39.346 + gz * 11.135) * 24634.634
			var r2: float = hs2 - floor(hs2)
			var px: float = gx + (r1 - 0.5) * 6.0
			var pz: float = gz + (r2 - 0.5) * 6.0
			var p := Vector2(px, pz)
			idx += 1
			if _distance_to_trails(p) < 4.2 or (absf(px) < 13.0 and pz > 140.0 and pz < 175.0) or p.distance_to(Vector2(CAMP_CENTRE.x, CAMP_CENTRE.z)) < 24.0 or p.distance_to(Vector2(QUAD_POS.x, QUAD_POS.z)) < 6.0 \
					or (absf(px) < 7.0 and pz < 8.0 and pz > -14.0):
				gz += 7.5
				continue
			var h: float = 8.0 + 6.0 * r1
			var rad: float = 0.34 + 0.2 * r2
			xf_trunk.append(Transform3D(Basis.from_scale(Vector3(rad, h, rad)), Vector3(px, h * 0.5, pz)))
			var cr: float = 2.6 + 1.4 * r2
			xf_low.append(Transform3D(Basis.from_scale(Vector3(cr, 4.6, cr)), Vector3(px, h * 0.62 + 1.2, pz)))
			xf_up.append(Transform3D(Basis.from_scale(Vector3(cr * 0.72, 4.0, cr * 0.72)), Vector3(px, h * 0.62 + 3.6, pz)))
			_trees.append([p, rad + 0.25])
			if idx % 2 == 0:
				var bsz: float = 0.8 + 0.7 * r1
				xf_bush.append(Transform3D(Basis.from_scale(Vector3(bsz * 1.3, bsz * 0.8, bsz * 1.3)), Vector3(px + 1.6 * (r2 - 0.5) * 3.0, bsz * 0.45, pz + 1.4)))
			gz += 7.5
		gx += 7.5
	_multi(_cyl_mesh(1.0, 1.0, 1.0, 6), xf_trunk, bark)
	_multi(_cyl_mesh(0.0, 1.0, 1.0, 8), xf_low, _leaf_mats[0])
	_multi(_cyl_mesh(0.0, 1.0, 1.0, 8), xf_up, _leaf_mats[1])
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 4
	_multi(sm, xf_bush, _leaf_mats[2])


func _cyl_mesh(rt: float, rb: float, h: float, sides: int) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = sides
	return cm


func _multi(mesh: Mesh, xforms: Array, mat: Material) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	_visuals.add_child(mmi)


## The mine's surface mouth behind the spawn: a rocky mound with a plank door - the lift they just came up.
func _build_mine_hut() -> void:
	var rock: StandardMaterial3D = _tex(ROCK_TEX, Color(0.46, 0.40, 0.34), 0.22)
	var timber: StandardMaterial3D = _tex(TIMBER_TEX, Color(0.62, 0.45, 0.30), 0.6)
	_box(Vector3(14.0, 7.0, 6.0), Vector3(0.0, 3.5, -9.0), rock)
	_box(Vector3(3.4, 3.6, 0.5), Vector3(0.0, 1.8, -5.9), timber)
	_box(Vector3(0.5, 3.6, 0.5), Vector3(-1.9, 1.8, -5.8), timber)
	_box(Vector3(0.5, 3.6, 0.5), Vector3(1.9, 1.8, -5.8), timber)
	_box(Vector3(4.4, 0.5, 0.6), Vector3(0.0, 3.8, -5.8), timber)
	_lantern(Vector3(-2.6, 3.0, -5.3), 2.6, 9.0)


# --- Inferno's quad, and the leaves that hide it ---------------------------------------------------------------------------

func _build_quad() -> void:
	_quad = Node3D.new()
	_quad.name = "FlameQuad"
	_quad.position = QUAD_POS
	_quad.rotation.y = QUAD_YAW
	_visuals.add_child(_quad)
	var paint: StandardMaterial3D = _plain(Color(0.45, 0.04, 0.03), 0.25, 0.35)       # deep candy red
	var black: StandardMaterial3D = _plain(Color(0.05, 0.05, 0.06), 0.6, 0.2)
	var chrome: StandardMaterial3D = _plain(Color(0.72, 0.70, 0.66), 0.3, 0.6)
	var rubber: StandardMaterial3D = _plain(Color(0.05, 0.05, 0.055), 0.9)
	var flame_a: StandardMaterial3D = _glow(Color(1.0, 0.42, 0.04), 1.0)
	var flame_b: StandardMaterial3D = _glow(Color(1.0, 0.78, 0.12), 1.2)
	var flame_c: StandardMaterial3D = _glow(Color(1.0, 0.95, 0.55), 1.4)
	var s: float = 1.7                                # big enough to carry a 2.9 m bull
	_box(Vector3(1.0, 0.45, 2.0) * s, Vector3(0.0, 0.85 * s, 0.0), paint, _quad)                    # body
	_box(Vector3(0.9, 0.3, 0.9) * s, Vector3(0.0, 1.12 * s, 0.55 * s), paint, _quad)                 # tank / nose cover
	_box(Vector3(0.8, 0.14, 1.0) * s, Vector3(0.0, 1.17 * s, -0.5 * s), black, _quad)                # seat
	_box(Vector3(0.7, 0.1, 0.55) * s, Vector3(0.0, 1.14 * s, -1.0 * s), black, _quad)                # rear seat / rack
	_box(Vector3(1.7, 0.07, 0.07) * s, Vector3(0.0, 1.5 * s, 0.35 * s), chrome, _quad)               # handlebars
	_cyl(0.04 * s, 0.04 * s, 0.5 * s, Vector3(0.0, 1.27 * s, 0.35 * s), chrome, _quad, 8)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := _cyl(0.4 * s, 0.4 * s, 0.34 * s, Vector3(0.74 * s * sx, 0.4 * s, 0.72 * s * sz), rubber, _quad, 14)
			w.rotation = Vector3(0.0, 0.0, PI * 0.5)
			_quad_wheels.append(w)
			_cyl(0.2 * s, 0.2 * s, 0.36 * s, Vector3(0.74 * s * sx, 0.4 * s, 0.72 * s * sz), chrome, _quad, 10).rotation = Vector3(0.0, 0.0, PI * 0.5)   # rims
			_box(Vector3(0.42, 0.06, 0.95) * s, Vector3(0.74 * s * sx, 0.78 * s, 0.72 * s * sz), paint, _quad)   # fenders
		# THE FLAME DESIGN: layered tongues licking back from the nose along both flanks and over the front fenders
		for k in 7:
			var fl: float = 0.78 - 0.085 * float(k)                          # tongue length, long at the nose
			var tongue := _box(Vector3(0.05, 0.1 + 0.02 * float(k % 3), fl) * s, Vector3(0.515 * s * sx, (0.74 + 0.065 * float(k % 4)) * s, (0.78 - 0.33 * float(k)) * s), [flame_a, flame_b, flame_c][k % 3], _quad)
			tongue.rotation.x = -0.06 * float(k)
		_box(Vector3(0.04, 0.16, 0.8) * s, Vector3(0.45 * s * sx, 1.05 * s, 0.7 * s), flame_a, _quad)                # tank flame
		_box(Vector3(0.05, 0.08, 0.5) * s, Vector3(0.46 * s * sx, 1.12 * s, 0.75 * s), flame_c, _quad)
	var hl := _sphere(0.13 * s, Vector3(0.0, 1.02 * s, 1.02 * s), _glow(Color(1.0, 0.95, 0.75), 3.0), _quad, 0.8)
	hl.name = "Headlight"
	_quad_light = SpotLight3D.new()
	_quad_light.light_color = Color(1.0, 0.92, 0.75)
	_quad_light.light_energy = 0.0
	_quad_light.spot_range = 28.0
	_quad_light.spot_angle = 30.0
	_quad_light.position = Vector3(0.0, 1.1 * s, 1.1 * s)
	_quad_light.rotation = Vector3(0.0, PI, 0.0)
	_quad.add_child(_quad_light)


## The disguise: ~90 clumps of leaves, branches and a draped net of ferns, bigger than the quad, plus a ring of the same bushes
## around it, so from the trail it is simply the biggest bush in a thicket.
func _build_cover() -> void:
	_cover = Node3D.new()
	_cover.name = "LeafCover"
	_visuals.add_child(_cover)
	_cover.position = QUAD_POS
	var branch_mat: StandardMaterial3D = _plain(Color(0.30, 0.20, 0.12), 0.95)
	for i in 150:
		var a: float = float(i) * 2.399963                        # golden-angle scatter
		var rr: float = 0.25 + 1.75 * sqrt(fposmod(float(i) * 0.6180339, 1.0))
		var x: float = cos(a) * rr * 1.05
		var z: float = sin(a) * rr * 1.9 - 0.2
		var y: float = 0.4 + 2.2 * (1.0 - clampf(rr / 2.0, 0.0, 1.0)) + 0.25 * sin(float(i) * 1.7)
		var sz: float = 0.7 + 0.45 * absf(sin(float(i) * 2.3))
		var clump := _sphere(sz, Vector3(x, y, z), _leaf_mats[i % _leaf_mats.size()], _cover, 0.72)
		clump.rotation = Vector3(0.3 * sin(float(i)), float(i), 0.2 * cos(float(i)))
		_cover_bits.append([clump, Vector3(x, 0.4, z).normalized() * (2.0 + 1.5 * absf(sin(float(i) * 3.1))) + Vector3(0.0, 3.0, 0.0), 2.5 * sin(float(i) * 1.3)])
	for i in 16:
		var a2: float = float(i) * 0.7854
		var br := _cyl(0.035, 0.05, 2.0 + 0.5 * sin(float(i)), Vector3(cos(a2) * 0.9, 1.5, sin(a2) * 1.6), branch_mat, _cover, 5)
		br.rotation = Vector3(0.6 * sin(a2 * 2.0), a2, 0.5 * cos(a2))
		_cover_bits.append([br, Vector3(cos(a2), 1.0, sin(a2)) * 3.0, 3.0])
	# the surrounding thicket (stays): the same leaf materials, so the pile belongs
	for i in 22:
		var a3: float = float(i) * 0.2856
		if absf(angle_difference(a3, -0.75)) < 0.75:
			continue                                               # the trail side stays open (where Inferno and the camera come in)
		var d: float = 3.0 + 1.0 * absf(sin(float(i) * 2.0))
		_sphere(1.5 + 0.7 * absf(sin(float(i))), QUAD_POS + Vector3(cos(a3) * d * 1.1, 0.7, sin(a3) * d * 1.7), _leaf_mats[i % _leaf_mats.size()], null, 0.8)


func get_quad_node() -> Node3D:
	return _quad


func get_cover_node() -> Node3D:
	return _cover


func get_cover_bit_count() -> int:
	return _cover_bits.size()


func is_quad_hidden() -> bool:
	return _cover != null and is_instance_valid(_cover) and _cover.visible and _reveal_t < 0.0


# --- the bear camp + the ridge ----------------------------------------------------------------------------------------------

func _build_camp() -> void:
	var canvas: StandardMaterial3D = _plain(Color(0.55, 0.48, 0.34), 0.95)
	var wood: StandardMaterial3D = _tex(TIMBER_TEX, Color(0.55, 0.40, 0.27), 0.6)
	var cx: float = CAMP_CENTRE.x
	var cz: float = CAMP_CENTRE.z
	_box(Vector3(46.0, 0.06, 38.0), Vector3(cx, 0.03, cz), _tex(GRAVEL_TEX, Color(0.40, 0.31, 0.22), 0.5))
	# tents: prisms
	for tp in [Vector3(-12.0, 0.0, 186.0), Vector3(11.0, 0.0, 184.0), Vector3(-9.0, 0.0, 199.0), Vector3(9.0, 0.0, 198.0)]:
		var pm := PrismMesh.new()
		pm.size = Vector3(4.6, 3.0, 5.0)
		var tent := MeshInstance3D.new()
		tent.mesh = pm
		tent.material_override = canvas
		tent.position = tp + Vector3(0.0, 1.5, 0.0)
		tent.rotation.y = tp.x * 0.1
		_visuals.add_child(tent)
	# logs round the fire
	for i in 6:
		var a: float = float(i) * 1.0472
		var lg := _cyl(0.28, 0.28, 2.4, Vector3(cx + cos(a) * 3.6, 0.3, cz + sin(a) * 3.6), wood, null, 8)
		lg.rotation = Vector3(PI * 0.5, 0.0, a + PI * 0.5)
	# the campfire: a hot glow + smoke
	var fire := _cyl(0.0, 0.7, 1.2, Vector3(cx, 0.6, cz), _glow(Color(1.0, 0.5, 0.1), 2.6), null, 7)
	fire.name = "Campfire"
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.6, 0.25)
	fl.light_energy = 3.2
	fl.omni_range = 26.0
	fl.position = Vector3(cx, 1.5, cz)
	_visuals.add_child(fl)
	var smoke := _particles(18, 4.0, Color(0.5, 0.5, 0.5, 0.45), 1.8)
	smoke.position = Vector3(cx, 1.4, cz)
	smoke.direction = Vector3(0.0, 1.0, 0.0)
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.4
	_visuals.add_child(smoke)
	# a watchtower with a lookout bear
	for tx in [-1.0, 1.0]:
		for tz in [-1.0, 1.0]:
			_box(Vector3(0.35, 7.0, 0.35), Vector3(-17.0 + 1.6 * tx, 3.5, 176.0 + 1.6 * tz), wood)
	_box(Vector3(4.2, 0.3, 4.2), Vector3(-17.0, 7.0, 176.0), wood)
	_box(Vector3(4.2, 0.9, 0.2), Vector3(-17.0, 7.6, 174.0), wood)
	# the bears (a rigged bear on each spot, idle, facing the fire)
	for i in BEAR_SPOTS.size():
		var sp: Vector2 = BEAR_SPOTS[i]
		var b: Ep2Actor = _make_bear(Vector3(sp.x, 0.0, sp.y))
		b.face_point(Vector3(cx, 0.0, cz))
		b.facing = atan2(cx - sp.x, cz - sp.y)
		b.rotation.y = b.facing
		_camp_bears.append(b)
		_marked.append(false)
		_marks.append(null)


func _build_ridge() -> void:
	# the ridge: a fern bank and a fallen log across the spy spot, a rise the ride tops before the camp opens up beyond it
	var fern: StandardMaterial3D = _plain(Color(0.20, 0.42, 0.16), 0.95)
	var wood: StandardMaterial3D = _tex(TIMBER_TEX, Color(0.45, 0.33, 0.22), 0.6)
	for i in 26:
		var x: float = -10.0 + float(i) * 0.9
		var z: float = 150.0 + 1.0 * sin(float(i) * 1.9)
		var f := _sphere(0.6 + 0.25 * absf(sin(float(i) * 2.7)), Vector3(x, 0.3, z), fern, null, 0.7)
		f.rotation.y = float(i)
	var log := _cyl(0.45, 0.45, 9.0, Vector3(1.0, 0.45, 148.6), wood, null, 8)
	log.rotation = Vector3(0.0, 0.0, PI * 0.5)
	log.rotation.y = 0.08


func _build_patrols() -> void:
	for pp in PATROL_BEARS:
		var p: Vector2 = pp
		var b: Ep2Actor = _make_bear(Vector3(p.x, 0.0, p.y - 5.0))
		_patrols.append([b, Vector2(p.x, p.y - 5.0), Vector2(p.x, p.y + 5.0), true])
		b.walk_to(Vector3(p.x, 0.0, p.y + 5.0), 0.9)


## A rigged bear (the runner's bear rig, 1.9 m) with an idle clip looping. Bears are enemies of the story - no weed theming.
func _make_bear(pos: Vector3) -> Ep2Actor:
	var b := Ep2Actor.new()
	b.name = "Bear"
	b.position = pos
	_visuals.add_child(b)
	var ok: bool = b.setup(RunnerMotion.BEAR_RIG, 1.9, 2.2, {}, [])
	if not ok or b.anim == null:
		return b
	var names: PackedStringArray = b.anim.get_animation_list()
	var idle: String = ""
	var walk: String = ""
	for n in names:
		var ln: String = str(n).to_lower()
		if idle == "" and (ln.find("idle") >= 0 or ln.find("stand") >= 0 or ln.find("breath") >= 0):
			idle = str(n)
		if walk == "" and ln.find("walk") >= 0:
			walk = str(n)
	if idle == "" and not names.is_empty():
		idle = str(names[0])
	if walk != "":
		b.walk_clip = walk
	b.idle_clip = idle
	if idle != "":
		b.anim.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
		b.play(idle, 1.0, 0.0)
	_bear_clips[b.get_instance_id()] = [idle, walk]
	return b


# --- the story --------------------------------------------------------------------------------------------------------

func _on_setup() -> void:
	_beat = Beat.SNEAK
	_player_pos = SPAWN
	_ground_y = 0.0
	_look_yaw = 0.0
	_look_pitch = -0.2
	_player_yaw = 0.0
	if _bull == null:
		_bull = _build_bull(Vector3(1.6, 0.0, 4.0), 0.0)
	_engine = _loop_player(QUAD_LOOP, -7.0)
	_build_hud()
	if _camera:
		_camera.position = SPAWN + Vector3(0.0, 2.6, -3.4)
	_on_beat_entered(Beat.SNEAK)


func _build_hud() -> void:
	if _hud_layer != null:
		return
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 12
	add_child(_hud_layer)
	_hud = Ep2FpsHud.new()
	_hud.show_ammo = false
	_hud.show_crosshair = false
	_hud_layer.add_child(_hud)


func _on_beat_entered(b: int) -> void:
	match b:
		Beat.SNEAK:
			_sneak_i = 0
			if _hud:
				_hud.objective = "Stay close to Inferno. Walk soft - bears hear a runner."
			_begin_carry_line("vo_bull_woods_sneak")
		Beat.REVEAL:
			_bull.stop()
			if _hud:
				_hud.objective = ""
			var bull_at := Vector3(QUAD_POS.x + 3.0, 0.0, QUAD_POS.z - 1.2)
			_start_show([
				{"do": "walk", "to": bull_at, "speed": 2.2},
				{"do": "face", "at": QUAD_POS},
				FacilityShow._say("vo_bull_quad_reveal", 0.2),
				{"do": "reach", "at": QUAD_POS + Vector3(0.0, 1.5, 0.0), "ramp": 0.5, "hold": 0.2, "lean": 0.35},
				{"do": "call", "fn": _reveal_quad},
				{"do": "wait", "t": 1.2},
				{"do": "release", "ramp": 0.5, "t": 0.4},
				FacilityShow._say("vo_lb_quad_ok", 0.2),
				{"do": "wait", "t": 0.5}], true)
			set_camera_shot(QUAD_POS + Vector3(6.0, 3.6, -9.5), QUAD_POS + Vector3(0.0, 1.3, 0.0), 56.0)
		Beat.MOUNT:
			_start_show([
				FacilityShow._say("vo_bull_quad_mount", 0.15),
				{"do": "call", "fn": _mount}], true)
		Beat.RIDE:
			_begin_ride()
		Beat.SPY:
			_begin_spy()


func _show_finished() -> void:
	match _beat:
		Beat.REVEAL:
			_advance_to(Beat.MOUNT)
		Beat.MOUNT:
			_advance_to(Beat.RIDE)
		Beat.SPY:
			if _spy_done:
				_advance_to(Beat.DONE)
				_resolve({"end_session": true, "to_be_continued": true, "next_mode": "quad_hunt"})


func _reveal_quad() -> void:
	_reveal_t = 0.0
	_sfx("ep2_leaves_pull")


func _mount() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_room_music"):
		am.play_room_music(MUSIC, 2.0)
	_sfx("ep2_quad_start")
	if _quad_light:
		_quad_light.light_energy = 6.0


func _begin_ride() -> void:
	release_camera()
	_riding = true
	_ride_done = false
	cam_distance = 7.5
	cam_height = 2.4
	_look_pitch = -0.18
	_bull.stop()
	_build_ride_path()
	_ride_s = 0.0
	_ride_speed = 0.0
	if _engine:
		_engine.play()
	_seat_riders()
	if _hud:
		_hud.objective = ""


## Catmull-Rom through RIDE_TRAIL, resampled every ~1.5 m: the quad follows this by arc length.
func _build_ride_path() -> void:
	_ride_pts = PackedVector3Array()
	_ride_len = PackedFloat32Array()
	var pts: Array = RIDE_TRAIL
	var n: int = pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		var steps: int = maxi(4, int(p1.distance_to(p2) / 1.5))
		for k in steps:
			var t: float = float(k) / float(steps)
			var t2: float = t * t
			var t3: float = t2 * t
			var q: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			_ride_pts.append(Vector3(q.x, 0.0, q.y))
	_ride_pts.append(Vector3(pts[n - 1].x, 0.0, pts[n - 1].y))
	var acc: float = 0.0
	_ride_len.append(0.0)
	for i in range(1, _ride_pts.size()):
		acc += _ride_pts[i].distance_to(_ride_pts[i - 1])
		_ride_len.append(acc)
	_ride_total = acc


func _ride_sample(s: float) -> Array:
	s = clampf(s, 0.0, _ride_total)
	var i: int = 1
	while i < _ride_len.size() - 1 and _ride_len[i] < s:
		i += 1
	var a: Vector3 = _ride_pts[i - 1]
	var b: Vector3 = _ride_pts[i]
	var seg: float = maxf(_ride_len[i] - _ride_len[i - 1], 0.001)
	var t: float = clampf((s - _ride_len[i - 1]) / seg, 0.0, 1.0)
	return [a.lerp(b, t), atan2(b.x - a.x, b.z - a.z)]


func _seat_riders() -> void:
	var f := Vector3(sin(_quad_yaw), 0.0, cos(_quad_yaw))
	var r := Vector3(-f.z, 0.0, f.x)
	var base: Vector3 = _quad.position
	_bull.position = base + f * 0.55 + Vector3(0.0, 0.62, 0.0)
	_bull.facing = _quad_yaw
	_bull.rotation.y = _quad_yaw
	_player_pos = base - f * 2.1 + Vector3(0.0, 1.1, 0.0)
	_player_yaw = _quad_yaw
	_ground_y = _player_pos.y
	_vel_y = 0.0
	if r.length() < 0.0:
		pass


func _begin_spy() -> void:
	_riding = false
	cam_distance = 3.9
	cam_height = 1.45
	_ground_y = 0.0
	_player_pos = Vector3(SPY_EYE.x, 0.0, SPY_EYE.z)
	_player_yaw = 0.0
	_look_yaw = 0.0
	_look_pitch = 0.0
	_spy_t = 0.0
	_spy_done = false
	_bull.position = Vector3(SPY_EYE.x - 2.4, 0.0, SPY_EYE.z - 1.0)
	_bull.facing = 0.0
	_bull.rotation.y = 0.0
	_bull.play(BULL_IDLE, 1.0, 0.3)
	if _engine:
		_engine.stop()
	if _quad_light:
		_quad_light.light_energy = 0.0
	if _hud:
		_hud.show_crosshair = true
		_hud.objective = "Hold RIGHT MOUSE for the spyglass. Spot the bears: 0 / %d" % BEAR_SPOTS.size()
	_start_show([FacilityShow._say("vo_bull_spy1", 0.3)])


func _finish_spy() -> void:
	_spy_done = true
	_start_show([
		FacilityShow._say("vo_bull_spy2", 0.3),
		FacilityShow._say("vo_lb_spy_reply", 0.4)])


# --- per-frame --------------------------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_warn_cd = maxf(0.0, _warn_cd - delta)
	_stay_cd = maxf(0.0, _stay_cd - delta)
	_tick_patrols(delta)
	_tick_cover(delta)
	match _beat:
		Beat.SNEAK:
			_tick_sneak(delta)
		Beat.RIDE:
			_tick_ride(delta)
		Beat.SPY:
			_tick_spy(delta)
	if _hud:
		_hud.ads = _zoom


func _tick_sneak(_delta: float) -> void:
	var trail: Array = SNEAK_TRAIL
	var target2: Vector2 = trail[_sneak_i]
	var bt := Vector3(target2.x, 0.0, target2.y)
	var dist_player: float = Vector2(_bull.position.x - _player_pos.x, _bull.position.z - _player_pos.z).length()
	if _show_active:
		pass
	elif dist_player > 6.5:
		# too far behind: Inferno stops and waits (never abandons him)
		if _bull.is_walking():
			_bull.stop()
		_bull_waiting = true
		_bull.face_point(_player_pos)
		if _stay_cd <= 0.0 and _hold <= 0.0:
			_stay_cd = 9.0
			_begin_carry_line("vo_bull_woods_sneak")
	elif dist_player < 4.5 or not _bull_waiting:
		_bull_waiting = false
		if not _bull.is_walking():
			_bull.walk_to(bt, 1.9)
	if Vector2(_bull.position.x, _bull.position.z).distance_to(target2) < 0.35:
		_sneak_i += 1
		if _sneak_i >= trail.size():
			_sneak_i = trail.size() - 1
			if dist_player < 6.0:
				_advance_to(Beat.REVEAL)
			return
	# noise: a runner near a bear is heard
	if _moving and _run_input and _warn_cd <= 0.0:
		for pb in _patrols:
			var bear: Ep2Actor = pb[0]
			if Vector2(bear.position.x - _player_pos.x, bear.position.z - _player_pos.z).length() < HEARING:
				_noise_hits += 1
				_warn_cd = 7.0
				bear.face_point(_player_pos)
				if _hud:
					_hud.toast("SHH! WALK SOFT", 2.0)
				if _hold <= 0.0:
					_begin_carry_line("vo_bull_woods_quiet")
				break


func _tick_patrols(_delta: float) -> void:
	for pb in _patrols:
		var b: Ep2Actor = pb[0]
		if not b.is_walking():
			var going_b: bool = not bool(pb[3])
			pb[3] = going_b
			var t: Vector2 = pb[2] if going_b else pb[1]
			b.walk_to(Vector3(t.x, 0.0, t.y), 0.9)


func _tick_cover(delta: float) -> void:
	if _reveal_t < 0.0 or _cover == null or not is_instance_valid(_cover):
		return
	_reveal_t += delta
	var k: float = clampf(_reveal_t / 1.5, 0.0, 1.0)
	for bit in _cover_bits:
		var n: Node3D = bit[0]
		var vel: Vector3 = bit[1]
		n.position += vel * delta * (1.0 - k * 0.6)
		n.rotation.y += float(bit[2]) * delta
		n.scale = Vector3.ONE * maxf(0.0, 1.0 - k * k)
	if k >= 1.0:
		_cover.visible = false
		_reveal_t = 1.5


func _tick_ride(delta: float) -> void:
	if _ride_done:
		return
	var remaining: float = _ride_total - _ride_s
	var target_speed: float = RIDE_SPEED if remaining > 14.0 else maxf(2.0, RIDE_SPEED * remaining / 14.0)
	_ride_speed = move_toward(_ride_speed, target_speed, 4.5 * delta)
	_ride_s = minf(_ride_s + _ride_speed * delta, _ride_total)
	var smp: Array = _ride_sample(_ride_s)
	var pos: Vector3 = smp[0]
	_quad_yaw = lerp_angle(_quad_yaw, float(smp[1]), clampf(8.0 * delta, 0.0, 1.0))
	var bob: float = 0.05 * sin(_anim_t * 17.0) * clampf(_ride_speed / RIDE_SPEED, 0.0, 1.0)
	_quad.position = pos + Vector3(0.0, bob, 0.0)
	_quad.rotation = Vector3(0.02 * sin(_anim_t * 9.0), _quad_yaw, 0.03 * sin(_anim_t * 7.0))
	for w in _quad_wheels:
		(w as Node3D).rotation.x += _ride_speed * delta / 0.68
	_seat_riders()
	_look_yaw = lerp_angle(_look_yaw, _quad_yaw, clampf(1.6 * delta, 0.0, 1.0))
	if _engine:
		_engine.pitch_scale = 0.85 + 0.35 * clampf(_ride_speed / RIDE_SPEED, 0.0, 1.0)
	if _ride_s >= _ride_total - 0.01:
		_ride_done = true
		_advance_to(Beat.SPY)


func set_aim(on: bool) -> void:
	_aim_on = on and _beat == Beat.SPY


func _tick_spy(delta: float) -> void:
	_spy_t += delta
	_zoom = move_toward(_zoom, 1.0 if _aim_on else 0.0, delta / 0.25)
	var eye: Vector3 = SPY_EYE
	var cp: float = cos(_look_pitch)
	var dir := Vector3(sin(_look_yaw) * cp, sin(_look_pitch), cos(_look_yaw) * cp)
	set_camera_shot(eye, eye + dir * 10.0, lerpf(62.0, SPY_ZOOM_FOV, _zoom), true)
	# marking: the spyglass up and a bear in the middle of it
	if _zoom > 0.6:
		for i in _camp_bears.size():
			if _marked[i]:
				continue
			var b: Ep2Actor = _camp_bears[i]
			var to: Vector3 = (b.position + Vector3(0.0, 1.1, 0.0)) - eye
			if to.length() < 1.0:
				continue
			if dir.angle_to(to.normalized()) < SPY_SPOT_ANGLE:
				_mark_bear(i)
	if _spy_done:
		return
	if _spy_t > SPY_TIMEOUT:
		for i in _camp_bears.size():
			if not _marked[i]:
				_mark_bear(i, true)
	if _count_marked() >= _camp_bears.size() and not _show_active:
		_finish_spy()


func _count_marked() -> int:
	var n: int = 0
	for m in _marked:
		if bool(m):
			n += 1
	return n


func _mark_bear(i: int, silent: bool = false) -> void:
	_marked[i] = true
	var b: Ep2Actor = _camp_bears[i]
	var mk := _sphere(0.22, b.position + Vector3(0.0, 3.0, 0.0), _glow(Color(1.0, 0.8, 0.2), 3.0), null, 1.4)
	mk.name = "BearMark"
	_marks[i] = mk
	var n: int = _count_marked()
	if _hud:
		_hud.objective = "Hold RIGHT MOUSE for the spyglass. Spot the bears: %d / %d" % [n, _camp_bears.size()]
		if not silent:
			_hud.toast("BEAR SPOTTED  %d / %d" % [n, _camp_bears.size()], 1.4)


func get_marked_count() -> int:
	return _count_marked()


func get_bear_total() -> int:
	return _camp_bears.size()


func get_noise_hits() -> int:
	return _noise_hits


func is_riding() -> bool:
	return _riding


func get_ride_progress() -> float:
	return _ride_s / maxf(_ride_total, 0.001)


func get_camp_bears() -> Array:
	return _camp_bears


## While riding the player does not steer: the quad is on rails and the mouse only looks around.
func _move_player(delta: float) -> void:
	if _riding:
		_moving = false
		return
	super._move_player(delta)


func _update_vertical(delta: float) -> void:
	if _riding:
		return
	super._update_vertical(delta)


func _can_jump() -> bool:
	return not _riding and _beat != Beat.SPY


func has_player_control() -> bool:
	return _running and not _resolved and not _show_blocks_control and _beat != Beat.DONE


func is_fps() -> bool:
	return _beat == Beat.SPY


func get_episode_mode() -> int:
	return Episode2Mode.Mode.FPS if _beat == Beat.SPY else Episode2Mode.Mode.HIDEOUT


## Trunks are solid; the ridge fern bank is the limit of the world until the spy beat.
func _collide(p: Vector3) -> Vector3:
	var q := p
	q.x = clampf(q.x, -55.0, 55.0)
	q.z = clampf(q.z, -5.0, 149.0)
	if _beat == Beat.SPY:
		q.x = clampf(q.x, SPY_EYE.x - 1.5, SPY_EYE.x + 1.5)
		q.z = clampf(q.z, SPY_EYE.z - 0.8, SPY_EYE.z + 0.8)
		return q
	for t in _trees:
		var tp: Vector2 = t[0]
		if absf(tp.x - q.x) > 3.0 or absf(tp.y - q.z) > 3.0:
			continue
		var d := Vector2(q.x - tp.x, q.z - tp.y)
		var r: float = float(t[1])
		if d.length() < r:
			var out: Vector2 = (d.normalized() if d.length_squared() > 1e-6 else Vector2(1.0, 0.0)) * r
			q.x = tp.x + out.x
			q.z = tp.y + out.y
	return q
