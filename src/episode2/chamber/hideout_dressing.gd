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
const WHISKEY_TABLE_POS := Vector3(4.8, 0.0, 4.4)
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
	_gold.emission_energy_multiplier = 0.06
	_leather = _plain(Color(0.28, 0.15, 0.09), 0.7, 0.0)
	_alcove()
	_joinery_and_lanterns()
	_entry_wall()
	var poster := _poster()
	_trophies()
	var gat: Node3D = _gatling(Vector3(-4.0, 0.0, 7.2), -2.21)
	_gun_wall()
	_whiskey_table(WHISKEY_TABLE_POS)
	_rug(Vector3(0.9, 0.045, 4.4))
	_bull_skull(Vector3(0.0, 6.3, 15.4))
	_braziers()
	_gold_and_cart()
	_hanging_chains()
	_blockers.append([Vector2(WHISKEY_TABLE_POS.x, WHISKEY_TABLE_POS.z), 1.35])          # whiskey table
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

## Arrival-side rock face. Looking back previously exposed only the flat forge
## background colour. The framed old mine remains beyond the walk boundary;
## dressing adds no collision, exit or change to the film/entry beat.
func _entry_wall() -> void:
	var rock: StandardMaterial3D = _tex_mat(
		"res://src/episode2/assets/textures/tex_rock_wall.jpg", Color(0.48, 0.38, 0.31), 0.25)
	var stonework := Node3D.new()
	stonework.name = "MineEntryRockFace"
	_v.add_child(stonework)
	for side in [-1.0, 1.0]:
		_box(Vector3(8.2, 10.0, 2.0), Vector3(7.5 * side, 4.8, -12.0), rock, Vector3.ZERO, stonework)
		_box(Vector3(0.5, 5.7, 0.5), Vector3(3.15 * side, 2.7, -10.9), _timber, Vector3.ZERO, stonework)
		for k in 4:
			_glb(RunnerView.BOULDER_ROCK_MODEL, Vector3((4.2 + 1.7 * float(k)) * side, -0.2, -10.3),
				1.7 + 0.3 * float(k % 2), float(k) * 1.7, stonework)
		var lp: Node3D = _glb(LANTERN, Vector3(3.05 * side, 3.2, -10.55), 1.0, 0.0, stonework)
		if lp:
			RunnerView.self_light(lp, 0.25, Color(1.0, 0.72, 0.38))
		_fire(Vector3(2.8 * side, 3.5, -10.0), 1.8, 8.0)
	_box(Vector3(6.9, 5.2, 2.0), Vector3(0.0, 7.3, -12.0), rock, Vector3.ZERO, stonework)
	_box(Vector3(6.9, 0.5, 0.6), Vector3(0.0, 5.35, -10.9), _timber, Vector3.ZERO, stonework)
	# An iron gate closes the abandoned entrance instead of implying a playable
	# passage through the existing movement clamp.
	_box(Vector3(6.0, 5.0, 0.2), Vector3(0.0, 2.3, -15.2), _dark_wood, Vector3.ZERO, stonework)
	for x in range(-5, 6):
		_cyl(0.035, 0.035, 4.7, Vector3(float(x) * 0.5, 2.3, -11.1), _iron, Vector3.ZERO, stonework)
	for y in [0.6, 3.7]:
		_box(Vector3(5.9, 0.10, 0.12), Vector3(0.0, y, -11.0), _iron, Vector3.ZERO, stonework)


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
	# Three columns of three (9 rifles) so the wall reads as an armory from the doorway; the middle column's middle
	# rifle is the one Inferno Bull takes down.
	for z0 in [5.3, 6.8, 8.7]:
		for row in 3:
			var y: float = 2.9 - 0.45 * float(row)
			var rifle: Node3D = _glb(RIFLE, Vector3(wx + 0.08, y, z0), 1.1, 0.0)
			if rifle:
				RunnerView.self_light(rifle, 0.12, Color(1.0, 0.82, 0.6))
				if row == 1 and z0 == 6.8:
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
		# the founder's tumblers (Meshy LKhotS), unit-height GLB on the cloth
		if _glb("res://src/episode2/assets/whiskey_glass.glb", pos + Vector3(gx, 1.03, 0.12), 0.16, 0.0) == null:
			_cyl(0.075, 0.06, 0.15, pos + Vector3(gx, 1.1, 0.12), amber)
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
	var ingot_mesh: ArrayMesh = _beveled_ingot()
	var stacks := Node3D.new()
	stacks.name = "BeveledGoldStacks"
	_v.add_child(stacks)
	for stack in [Vector3(-2.3, 0.0, 4.3), Vector3(5.6, 0.0, 12.2)]:
		for row in 4:
			var cols: int = 5 - row
			for c in cols:
				var x: float = stack.x - float(cols - 1) * 0.28 + float(c) * 0.56
				_add(ingot_mesh, _gold, Vector3(x, 0.1 + 0.21 * float(row), stack.z), Vector3.ZERO, stacks)
		_blockers.append([Vector2(stack.x, stack.z), 1.0])
	var cart_pos := Vector3(-3.9, 0.0, 1.4)
	if _prop("ore_cart", cart_pos, 1.6, 0.35) == null:
		_box(Vector3(1.0, 0.7, 1.7), cart_pos + Vector3(0.0, 0.7, 0.0), _dark_wood)
	_blockers.append([Vector2(cart_pos.x, cart_pos.z), 1.1])
	_glb(INGOT_RACK, Vector3(-3.0, 0.0, 12.4), 1.4, 0.0)

## A cast bar with inset crown, bevel shoulders and eight corner faces.
## Shared by all stacks: 48 triangles per bar, no new texture or GLB payload.
func _beveled_ingot() -> ArrayMesh:
	var ring := PackedVector2Array([
		Vector2(-0.22, -0.14), Vector2(0.22, -0.14), Vector2(0.25, -0.11), Vector2(0.25, 0.11),
		Vector2(0.22, 0.14), Vector2(-0.22, 0.14), Vector2(-0.25, 0.11), Vector2(-0.25, -0.11)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		var j: int = (i + 1) % ring.size()
		var a := Vector3(ring[i].x, -0.1, ring[i].y)
		var b := Vector3(ring[j].x, -0.1, ring[j].y)
		var c := Vector3(ring[j].x, 0.055, ring[j].y)
		var d := Vector3(ring[i].x, 0.055, ring[i].y)
		var e := Vector3(ring[j].x * 0.85, 0.1, ring[j].y * 0.85)
		var f := Vector3(ring[i].x * 0.85, 0.1, ring[i].y * 0.85)
		_ingot_triangle(st, a, b, c)
		_ingot_triangle(st, a, c, d)
		_ingot_triangle(st, d, c, e)
		_ingot_triangle(st, d, e, f)
		_ingot_triangle(st, Vector3(0.0, 0.1, 0.0), f, e)
		_ingot_triangle(st, Vector3(0.0, -0.1, 0.0), b, a)
	return st.commit()

func _ingot_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	# Godot front faces wind clockwise. Explicit outward normals keep the bevel
	# visibly shaded instead of the flat box colour of the previous stacks.
	if normal.dot((a + b + c) / 3.0) < 0.0:
		normal = -normal
	else:
		var swap: Vector3 = b
		b = c
		c = swap
	for point in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(point)


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
static func add_cauldron(visuals: Node3D, pos: Vector3, molten: Material, height: float = 1.35) -> void:
	var d := HideoutDressing.new()
	d._v = visuals
	d._brass = Ep2Palette.make("brass")
	var c: Node3D = d._prop("cauldron", pos, height, 0.0)
	if c:
		for mesh in c.find_children("*", "MeshInstance3D", true, false):
			var iron := StandardMaterial3D.new()
			iron.albedo_color = Color(0.48, 0.40, 0.32)
			iron.metallic = 0.15
			iron.roughness = 0.7
			mesh.material_override = iron
	if c == null:
		var iron: StandardMaterial3D = d._dark_iron()
		d._cyl(0.95, 0.78, 1.5, pos + Vector3(0.0, 1.05, 0.0), iron)
	d._cyl(height * 0.49, height * 0.49, 0.02, pos + Vector3(0.0, height * 0.86, 0.0), molten)


## Pegged load-bearing timber, hanging lanterns and an open vault frame the existing walk route.
## All solid dressing stays at the walls, above the route or beyond the exit trigger.
func _joinery_and_lanterns() -> void:
	var root := Node3D.new()
	root.name = "HideoutTimberJoinery"
	_v.add_child(root)
	var stone := _tex_mat("res://src/episode2/assets/textures/tex_rock_wall.jpg", Color(0.56, 0.48, 0.39), 0.35)
	for z in [0.0, 3.5, 7.0, 10.5, 13.2]:
		for side in [-1.0, 1.0]:
			var x: float = (WALL_X - 0.35) * side
			_box(Vector3(0.55, 5.7, 0.55), Vector3(x, 3.0, z), _timber, Vector3.ZERO, root)
			_box(Vector3(0.85, 0.42, 0.85), Vector3(x, 0.21, z), stone, Vector3.ZERO, root)
			for y in [0.7, 3.1, 5.4]:
				_box(Vector3(0.61, 0.16, 0.61), Vector3(x, y, z), _iron, Vector3.ZERO, root)
				for dz in [-0.18, 0.18]:
					_cyl(0.035, 0.035, 0.05, Vector3(x - side * 0.32, y, z + dz), _brass, Vector3(0, 0, 90), root)
			_box(Vector3(0.3, 1.8, 0.3), Vector3(x - side * 0.55, 5.25, z), _timber, Vector3(0, 0, -side * 38), root)
		_box(Vector3(WALL_X * 2.0, 0.55, 0.6), Vector3(0.0, 5.95, z), _timber, Vector3.ZERO, root)
	for z in [1.7, 7.0, 12.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * 4.6
			for i in 9:
				var link := TorusMesh.new()
				link.inner_radius = 0.045
				link.outer_radius = 0.072
				link.rings = 8
				link.ring_segments = 6
				_add(link, _iron, Vector3(x, 5.8 - float(i) * 0.10, z), Vector3(90, float(i % 2) * 90, 0), root)
			var lp: Node3D = _glb(LANTERN, Vector3(x, 4.3, z), 0.65, 0.0, root)
			if lp:
				RunnerView.self_light(lp, 0.28, Color(1.0, 0.72, 0.38))
			_fire(Vector3(x, 4.6, z), 1.2, 5.0)
	# Dark open Fort Knox passage; the furnace is beside it, never across its mouth.
	for side in [-1.0, 1.0]:
		_box(Vector3(0.65, 4.7, 0.9), Vector3(side * 2.6, 2.25, 16.4), stone, Vector3.ZERO, root)
		var door := Node3D.new()
		door.position = Vector3(side * 2.3, 0.0, 16.1)
		door.rotation.y = side * 0.48
		root.add_child(door)
		_box(Vector3(1.45, 3.95, 0.25), Vector3(-side * 0.72, 1.98, 0), _dark_wood, Vector3.ZERO, door)
		for y in [0.5, 1.98, 3.45]:
			_box(Vector3(1.42, 0.18, 0.31), Vector3(-side * 0.72, y, -0.03), _iron, Vector3.ZERO, door)
			for dx in [0.2, 1.2]:
				_cyl(0.04, 0.04, 0.05, Vector3(-side * dx, y, -0.20), _brass, Vector3(90, 0, 0), door)
	_box(Vector3(4.3, 4.2, 0.15), Vector3(0, 2.1, 18.2), _plain(Color(0.05, 0.035, 0.025), 1.0, 0.0), Vector3.ZERO, root)
	for i in 11:
		var a: float = float(i) / 10.0 * PI
		_box(Vector3(0.65, 0.75, 0.95), Vector3(cos(a) * 2.55, 4.3 + sin(a) * 0.75, 16.4), stone, Vector3(0, 0, rad_to_deg(a) - 90), root)
	for x in [-8.0, -4.3, 4.4, 8.2]:
		for i in 3:
			var rock: Node3D = _glb(RunnerView.BOULDER_ROCK_MODEL, Vector3(x, 2.4 + float(i) * 1.7, 17.6), 1.9, x, root)
			if rock:
				for mesh in rock.find_children("*", "MeshInstance3D", true, false):
					mesh.material_override = stone
