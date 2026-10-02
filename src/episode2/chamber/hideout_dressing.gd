class_name HideoutDressing
extends RefCounted
## Inferno Bull's HANGOUT, as the founder's target image shows it (design/ep2/inferno_bull_hideout_target.jpg,
## design/ep2/INFERNO_BULL_HIDEOUT_design.md): a timber-panelled alcove off the smelter, 1800s Western
## dressing, heat and flame everywhere. All of it is code-built from primitives + the committed GLBs so it
## costs almost nothing in package size and every prop has a visible primitive fallback.
##
## Built into the facility's `Visuals` node by `build()`. Returns the handles the facility animates:
##   flames   - OmniLight3D list (the facility flickers them)
##   gatling  - the Colt Gatling (its barrels spin lazily)
##   poster   - the pin-up poster mesh
## Dressing is pure set decoration: nothing here is collidable or part of the beat sheet.

## Meshy image-to-3d props (2026-10-01, concepts from tools/ep2_forge/hideout_concepts.py, provenance in
## assets/hideout/sources.json). Meshy normalises each to a unit box centred on the origin; NATIVE holds the
## measured [height, lowest y] so a prop can be sized and stood on the floor without a runtime AABB.
const PROP_DIR := "res://src/episode2/assets/hideout/"
const NATIVE := {
	"gatling": [0.670, -0.338], "bear_standing": [1.0, -0.5], "bear_head": [1.0, -0.5],
	"ore_cart": [0.879, -0.440], "cauldron": [0.655, -0.327],
}
const RIFLE := "res://src/episode2/assets/winchester_1886.glb"
const POSTER_TEX := "res://src/episode2/assets/textures/tex_pinup_poster.jpg"
const HIDE_TEX := "res://src/episode2/assets/textures/tex_cowhide.png"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const LANTERN := "res://src/episode2/assets/lantern.glb"
const INGOT_RACK := "res://src/episode2/assets/ingot_rack.glb"

## Inside faces of the alcove walls. The Bull stands at x=1.6, so the room is ~14 m wide and the walls hold
## the gun wall (right) and the trophies (left).
const WALL_X := 7.1
const ALCOVE_Z0 := -1.0
const ALCOVE_Z1 := 13.5

var _v: Node3D
var _timber: StandardMaterial3D
var _dark_wood: StandardMaterial3D
var _iron: StandardMaterial3D
var _brass: StandardMaterial3D
var _gold: StandardMaterial3D
var _leather: StandardMaterial3D
var _flames: Array = []
var _blockers: Array = []
var _rack_rifle: Node3D = null


static func build(visuals: Node3D) -> Dictionary:
	var d := HideoutDressing.new()
	return d._build(visuals)


func _build(visuals: Node3D) -> Dictionary:
	_v = visuals
	_timber = _tex_mat(TIMBER_TEX, Color(0.66, 0.42, 0.24), 0.5)
	_dark_wood = _tex_mat(TIMBER_TEX, Color(0.36, 0.21, 0.11), 0.5)
	_iron = _plain(Color(0.18, 0.17, 0.16), 0.45, 0.35)
	_brass = Ep2Palette.make("brass")
	_gold = _plain(Color(1.0, 0.76, 0.28), 0.28, 0.45)
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.7, 0.2)
	_gold.emission_energy_multiplier = 0.18
	_leather = _plain(Color(0.28, 0.15, 0.09), 0.7, 0.0)
	_alcove()
	var poster := _poster()
	_trophies()
	var gat: Node3D = _gatling(Vector3(-4.0, 0.0, 7.2), -2.21)
	_gun_wall()
	_whiskey_table(Vector3(3.6, 0.0, 5.4))
	_rug(Vector3(0.9, 0.045, 4.4))
	_bull_skull(Vector3(0.0, 6.3, 15.4))
	_braziers()
	_gold_and_cart()
	_hanging_chains()
	_blockers.append([Vector2(3.6, 5.4), 1.35])          # whiskey table
	return {"flames": _flames, "gatling": gat, "poster": poster, "blockers": _blockers, "rack_rifle": _rack_rifle}


## Instance a Meshy prop, scaled so its HEIGHT is `height` m, standing on `base` (y = floor), turned `yaw` rad.
func _prop(name: String, base: Vector3, height: float, yaw: float) -> Node3D:
	var path: String = PROP_DIR + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	var nat: Array = NATIVE[name]
	var sc: float = height / float(nat[0])
	n.scale = Vector3.ONE * sc
	n.rotation.y = yaw
	n.position = base + Vector3(0.0, -float(nat[1]) * sc, 0.0)
	_v.add_child(n)
	RunnerView.self_light(n, 0.06, Color(1.0, 0.8, 0.6))
	return n


# --- small builders ------------------------------------------------------------------------------

func _plain(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _tex_mat(path: String, tint: Color, uv: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.85
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	(parent if parent else _v).add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(b, mat, pos, rot_deg, parent)


func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 14
	return _add(c, mat, pos, rot_deg, parent)


func _glb(path: String, pos: Vector3, scale: float, yaw_deg: float, parent: Node3D = null) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * scale
	n.rotation_degrees.y = yaw_deg
	(parent if parent else _v).add_child(n)
	return n


func _fire(pos: Vector3, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.52, 0.16)
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	_v.add_child(l)
	_flames.append(l)
	return l


func _flame_particles(pos: Vector3, scale: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 34
	p.lifetime = 0.9
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34) * scale
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.7, 0.25, 0.9)
	m.albedo_texture = _soft_blob()
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.92, 0.55, 1.0))
	g.add_point(0.45, Color(1.0, 0.45, 0.1, 0.8))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.05, 0.0, 0.0))
	p.color_ramp = g
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.7 * scale
	p.initial_velocity_max = 1.5 * scale
	p.gravity = Vector3(0.0, 0.6, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.16 * scale
	p.preprocess = 1.0
	p.position = pos
	_v.add_child(p)
	return p


# --- the alcove ----------------------------------------------------------------------------------

## Timber-panelled side walls with a rock backing, so the vast cavern reads as a lived-in room.
func _alcove() -> void:
	var len_z: float = ALCOVE_Z1 - ALCOVE_Z0
	var mid_z: float = (ALCOVE_Z0 + ALCOVE_Z1) * 0.5
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.5, 6.4, len_z), Vector3((WALL_X + 0.25) * sx, 3.2, mid_z), _dark_wood)
		# vertical planks and a dado rail break up the flat wall
		var z: float = ALCOVE_Z0 + 0.4
		while z < ALCOVE_Z1:
			_box(Vector3(0.12, 6.0, 0.14), Vector3((WALL_X - 0.02) * sx, 3.2, z), _timber)
			z += 1.2
		_box(Vector3(0.2, 0.2, len_z), Vector3((WALL_X - 0.05) * sx, 1.35, mid_z), _timber)
		_box(Vector3(0.24, 0.3, len_z), Vector3((WALL_X - 0.05) * sx, 6.15, mid_z), _timber)
	# warm plank floor across the hangout (the cave gravel stays outside it)
	_box(Vector3(WALL_X * 2.0, 0.06, len_z), Vector3(0.0, 0.0, mid_z), _tex_mat(TIMBER_TEX, Color(0.44, 0.27, 0.15), 0.9))
	# a low ceiling run of beams so the alcove has a roof line
	var bz: float = ALCOVE_Z0 + 0.5
	while bz < ALCOVE_Z1:
		_box(Vector3(WALL_X * 2.0, 0.34, 0.34), Vector3(0.0, 6.35, bz), _timber)
		bz += 2.6
	# lanterns along both walls
	for lz in [1.0, 6.0, 11.0]:
		for sx in [-1.0, 1.0]:
			var lamp := Ep2Palette.make_lantern_light()
			lamp.position = Vector3((WALL_X - 0.6) * sx, 3.9, lz)
			_v.add_child(lamp)
			var lp: Node3D = _glb(LANTERN, Vector3((WALL_X - 0.45) * sx, 3.5, lz), 1.1, 0.0)
			if lp:
				RunnerView.self_light(lp, 0.25, Color(1.0, 0.72, 0.38))


# --- the poster ----------------------------------------------------------------------------------

func _poster() -> MeshInstance3D:
	# A framed 1890s revue poster on the back wall, left of the Fort Knox door, lit by its own warm lamp.
	var pos := Vector3(6.2, 3.9, 16.0)
	_box(Vector3(2.7, 3.8, 0.12), pos, _dark_wood)
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 3.5)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.82)
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.45)
	m.emission_energy_multiplier = 0.55
	if ResourceLoader.exists(POSTER_TEX):
		m.albedo_texture = load(POSTER_TEX)
		m.emission_texture = load(POSTER_TEX)
	var mi := _add(q, m, pos + Vector3(0.0, 0.0, -0.08), Vector3(0.0, 180.0, 0.0))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 1.4
	lamp.omni_range = 5.5
	lamp.position = pos + Vector3(0.0, 0.4, -1.8)
	_v.add_child(lamp)
	return mi


# --- trophies: mounted heads on both walls + the taxidermist's full bears (Meshy) -------------------------------

func _trophies() -> void:
	# Wall mounts on their own shield plaques, roaring into the room. Model faces +Z, plaque back at -Z.
	for spec in [[1.0, 3.5, 3.4, 1.5], [1.0, 3.8, 10.4, 1.3], [-1.0, 5.2, 4.4, 1.3], [-1.0, 3.6, 11.8, 1.2]]:
		var sx: float = spec[0]
		var size: float = spec[3]
		var base := Vector3((WALL_X - 0.42 * size) * sx, float(spec[1]) - size * 0.5, float(spec[2]))
		var head: Node3D = _prop("bear_head", base, size, -PI * 0.5 * sx)
		if head == null:
			_cyl(0.4, 0.5, 0.7, base + Vector3(-0.4 * sx, size * 0.5, 0.0), _leather, Vector3(0, 0, 90))
	# The full taxidermy grizzlies, reared up on their plinths: the big one front-left, one back-right.
	for spec2 in [[Vector3(5.4, 0.0, 8.0), 3.0, -2.5], [Vector3(-5.9, 0.0, 12.4), 2.5, 2.6]]:
		var b: Node3D = _prop("bear_standing", spec2[0], spec2[1], spec2[2])
		if b == null:
			_box(Vector3(1.2, 2.6, 1.0), spec2[0] + Vector3(0.0, 1.3, 0.0), _leather)
		_blockers.append([Vector2(spec2[0].x, spec2[0].z), 1.2])


# --- the armory: 1800s rifles + revolvers on the right wall ----------------------------------------

func _gun_wall() -> void:
	var wx: float = -(WALL_X - 0.12)
	_box(Vector3(0.14, 3.0, 7.4), Vector3(wx - 0.05, 2.5, 7.4), _dark_wood)
	# Winchester 1886 rack: the committed GLB lying along the wall at a REACHABLE height (Inferno Bull takes the
	# middle one down: rows y = 2.9 / 2.45 / 2.0). Real size for a 2.9 m Bull: ~1.3 m.
	var z0: float = 6.8
	for row in 3:
		var y: float = 2.9 - 0.45 * float(row)
		var rifle: Node3D = _glb(RIFLE, Vector3(wx + 0.08, y, z0), 1.1, 0.0)
		if rifle:
			RunnerView.self_light(rifle, 0.05, Color(1.0, 0.82, 0.6))
			if row == 1:
				_rack_rifle = rifle
		else:
			_box(Vector3(0.08, 0.08, 1.3), Vector3(wx + 0.08, y, z0), _leather)
		for pz in [-0.5, 0.5]:
			_box(Vector3(0.12, 0.12, 0.12), Vector3(wx + 0.02, y - 0.1, z0 + pz * 1.0), _iron)
	# Colt Single Action revolvers on pegs (barrel, cylinder, frame, walnut grip), two rows of three, below the rifles.
	for r in 2:
		for i in 3:
			var rp := Vector3(wx + 0.1, 1.55 - 0.45 * float(r), 4.9 + float(i) * 1.5 + 0.2 * float(r))
			_revolver(rp)
	for i in 6:
		_cyl(0.03, 0.03, 0.12, Vector3(wx + 0.1, 1.0, 4.9 + 0.09 * float(i)), _brass, Vector3(0, 0, 0))
	# The miner's helmet hangs on its own peg at the end of the rack (Inferno Bull takes it down for Lil Blunt).
	_box(Vector3(0.1, 0.9, 0.9), Vector3(wx - 0.02, 2.15, 10.2), _timber)
	_cyl(0.03, 0.03, 0.3, Vector3(wx + 0.12, 2.2, 10.2), _iron, Vector3(0, 0, 90))


func _revolver(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	_v.add_child(root)
	_cyl(0.025, 0.025, 0.42, Vector3(0.0, 0.0, 0.2), _iron, Vector3(90, 0, 0), root)            # barrel
	_cyl(0.055, 0.055, 0.1, Vector3(0.0, 0.0, -0.04), _iron, Vector3(90, 0, 0), root)            # cylinder
	_box(Vector3(0.05, 0.12, 0.16), Vector3(0.0, -0.05, -0.16), _iron, Vector3(0, 0, 0), root)    # frame
	_box(Vector3(0.05, 0.2, 0.09), Vector3(0.0, -0.13, -0.24), _plain(Color(0.45, 0.22, 0.10), 0.5, 0.0), Vector3(18, 0, 0), root)  # grip


## The Colt Gatling (Meshy): brass breech, six barrels, wooden tripod. Its muzzle is model -X; `yaw` turns it.
func _gatling(pos: Vector3, yaw: float) -> Node3D:
	var g: Node3D = _prop("gatling", pos, 1.8, yaw)
	if g == null:
		g = Node3D.new()
		g.position = pos
		_v.add_child(g)
		_box(Vector3(0.3, 0.3, 1.4), Vector3(0.0, 1.2, 0.0), _brass, Vector3.ZERO, g)
	g.name = "ColtGatling"
	_blockers.append([Vector2(pos.x, pos.z), 1.1])
	return g


func _whiskey_table(pos: Vector3) -> void:
	# A plank table with a checked cloth, a cut-glass decanter, two tumblers, an ashtray, the pickaxe leaning.
	_box(Vector3(2.2, 0.12, 1.1), pos + Vector3(0.0, 0.95, 0.0), _timber)
	for lx in [-0.95, 0.95]:
		for lz in [-0.4, 0.4]:
			_box(Vector3(0.12, 0.95, 0.12), pos + Vector3(lx, 0.47, lz), _dark_wood)
	_box(Vector3(1.7, 0.02, 0.9), pos + Vector3(0.1, 1.02, 0.0), _plain(Color(0.34, 0.07, 0.05), 0.95, 0.0))
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(0.80, 0.40, 0.08, 0.78)
	amber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amber.roughness = 0.08
	amber.emission_enabled = true
	amber.emission = Color(0.9, 0.4, 0.06)
	amber.emission_energy_multiplier = 0.5
	_cyl(0.16, 0.2, 0.34, pos + Vector3(-0.5, 1.2, -0.05), amber)                         # decanter body
	_cyl(0.05, 0.1, 0.22, pos + Vector3(-0.5, 1.48, -0.05), amber)                        # neck
	_cyl(0.07, 0.07, 0.07, pos + Vector3(-0.5, 1.63, -0.05), amber)                       # stopper
	for gx in [0.1, 0.42]:
		_cyl(0.075, 0.06, 0.15, pos + Vector3(gx, 1.1, 0.12), amber)                      # tumblers
	_cyl(0.12, 0.12, 0.04, pos + Vector3(0.72, 1.04, -0.12), _iron)                       # ashtray
	_fire(pos + Vector3(0.0, 1.5, 0.0), 0.9, 3.5)
	# the pickaxe leaning on the table
	_cyl(0.025, 0.025, 1.4, pos + Vector3(1.25, 0.72, 0.2), _timber, Vector3(0, 0, 14))
	_box(Vector3(0.55, 0.07, 0.07), pos + Vector3(1.0, 1.4, 0.2), _iron, Vector3(0, 0, 14))


func _rug(pos: Vector3) -> void:
	# A real hide shape (alpha-cut texture), not a rectangle.
	var q := QuadMesh.new()
	q.size = Vector2(3.6, 4.3)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.88, 0.8)
	m.roughness = 1.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	if ResourceLoader.exists(HIDE_TEX):
		m.albedo_texture = load(HIDE_TEX)
	_add(q, m, pos, Vector3(-90, 18, 0))


## A bleached longhorn skull with horns over the Fort Knox door.
func _bull_skull(pos: Vector3) -> void:
	var bone := _plain(Color(0.92, 0.86, 0.74), 0.8, 0.0)
	bone.emission_enabled = true
	bone.emission = Color(0.5, 0.4, 0.28)
	bone.emission_energy_multiplier = 0.45
	var hollow := _plain(Color(0.05, 0.03, 0.02), 1.0, 0.0)
	var s := Node3D.new()
	s.position = pos
	s.scale = Vector3.ONE * 1.5
	_v.add_child(s)
	var cranium := SphereMesh.new()
	cranium.radius = 0.3
	cranium.height = 0.6
	_add(cranium, bone, Vector3.ZERO, Vector3.ZERO, s)
	var snout := CapsuleMesh.new()
	snout.radius = 0.15
	snout.height = 0.7
	_add(snout, bone, Vector3(0.0, -0.4, 0.04), Vector3.ZERO, s)
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.085
		eye.height = 0.17
		_add(eye, hollow, Vector3(0.13 * side, -0.02, -0.25), Vector3.ZERO, s)
		var prev := Vector3(0.22 * side, 0.1, 0.0)
		for i in 7:
			var t: float = float(i + 1) / 7.0
			var nxt := Vector3((0.22 + 1.5 * t) * side, 0.1 + 0.5 * sin(t * 1.5), 0.0)
			var mid: Vector3 = (prev + nxt) * 0.5
			var dir: Vector3 = nxt - prev
			var c := _cyl(0.05 * (1.0 - 0.75 * t), 0.075 * (1.0 - 0.6 * t), dir.length() + 0.03, mid, bone, Vector3.ZERO, s)
			c.rotation.z = atan2(dir.y, dir.x) - PI * 0.5
			prev = nxt


## Braziers either side of the Bull's seat: heat and flame in the frame, as the brief asks.
func _braziers() -> void:
	for p in [Vector3(3.6, 0.0, 8.6), Vector3(-2.2, 0.0, 8.4), Vector3(-5.6, 0.0, 1.8)]:
		_cyl(0.42, 0.28, 0.5, p + Vector3(0.0, 0.85, 0.0), _dark_iron())
		for a in [0.0, 120.0, 240.0]:
			_cyl(0.03, 0.03, 0.9, p + Vector3(sin(deg_to_rad(a)) * 0.28, 0.42, cos(deg_to_rad(a)) * 0.28), _dark_iron())
		_flame_particles(p + Vector3(0.0, 1.15, 0.0), 1.2)
		_fire(p + Vector3(0.0, 1.5, 0.0), 2.4, 7.0)


func _gold_and_cart() -> void:
	# Gold bars stacked in the right foreground and at the back, plus the Meshy ore cart heaped with gold.
	for stack in [Vector3(-2.3, 0.0, 4.3), Vector3(5.6, 0.0, 12.2)]:
		for row in 4:
			var cols: int = 5 - row
			for c in cols:
				var x: float = stack.x - float(cols - 1) * 0.28 + float(c) * 0.56
				_box(Vector3(0.5, 0.2, 0.28), Vector3(x, 0.1 + 0.21 * float(row), stack.z), _gold)
		_blockers.append([Vector2(stack.x, stack.z), 1.0])
	var cart_pos := Vector3(-3.9, 0.0, 1.4)
	if _prop("ore_cart", cart_pos, 1.6, 0.35) == null:
		_box(Vector3(1.0, 0.7, 1.7), cart_pos + Vector3(0.0, 0.7, 0.0), _dark_wood)
	_blockers.append([Vector2(cart_pos.x, cart_pos.z), 1.1])
	_glb(INGOT_RACK, Vector3(-3.0, 0.0, 12.4), 1.4, 0.0)


func _dark_iron() -> StandardMaterial3D:
	return _plain(Color(0.16, 0.15, 0.15), 0.5, 0.3)


func _hanging_chains() -> void:
	# Iron chains with hooks from the ceiling beams, heavier on the Bull's side.
	for cx in [-5.2, -2.6, 4.6, 6.2]:
		for cz in [2.0, 8.0]:
			var length: float = 2.4 + fmod(absf(cx * cz), 1.6)
			_cyl(0.05, 0.05, length, Vector3(cx, 6.2 - length * 0.5, cz), _dark_iron())
			_cyl(0.09, 0.09, 0.08, Vector3(cx, 6.2 - length, cz), _iron, Vector3(90, 0, 0))


var _blob: GradientTexture2D = null

func _soft_blob() -> GradientTexture2D:
	if _blob == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_blob = GradientTexture2D.new()
		_blob.gradient = g
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 64
		_blob.height = 64
	return _blob


## The Meshy cast-iron cauldron brimming with molten gold, on its stone base (2 m across). `molten` adds a
## flowing-gold surface on top so the pour reads as live. Returns the node for the facility's blockers.
static func add_cauldron(visuals: Node3D, pos: Vector3, molten: Material) -> void:
	var d := HideoutDressing.new()
	d._v = visuals
	d._brass = Ep2Palette.make("brass")
	var c: Node3D = d._prop("cauldron", pos, 1.35, 0.0)
	if c == null:
		var iron: StandardMaterial3D = d._dark_iron()
		d._cyl(0.95, 0.78, 1.5, pos + Vector3(0.0, 1.05, 0.0), iron)
	d._cyl(0.66, 0.66, 0.02, pos + Vector3(0.0, 1.16, 0.0), molten)
