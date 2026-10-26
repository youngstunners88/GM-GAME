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
## The furnace: its Blender stonework and the CAD front share this mount (the mouth's centre on the face, at floor level); the bellows
## stand left of the mouth beyond the walk clamp (x -6.3), the fire tools lean on the face right of the right jamb.
const FURNACE_MOUNT := Vector3(-6.3, 0.0, 16.05)
const BELLOWS_AT := Vector3(-7.6, 0.0, 14.4)
const FIRE_TOOLS_AT := Vector3(-4.2, 0.0, 15.62)
const RIFLE := "res://src/episode2/assets/winchester_1886.glb"
## The Armory Gatling's barrels run along its local +x (Ep2GoldTown.GATLING_POST): turn it so they point the way the old prop did.
const GATLING_YAW_FIX := -PI * 0.5
const POSTER_TEX := "res://src/episode2/assets/textures/tex_pinup_poster.jpg"
const HIDE_TEX := "res://src/episode2/assets/textures/tex_cowhide.png"
const TIMBER_TEX := "res://src/episode2/assets/textures/tex_timber.jpg"
const LANTERN := "res://src/episode2/assets/lantern.glb"
const WHISKEY_TABLE_POS := Vector3(4.8, 0.0, 4.4)
const INGOT_RACK := "res://src/episode2/assets/ingot_rack.glb"
## The CAD kit's crates and kegs keep the hideout's own timber (the measured mean of tex_timber x its tints: the old crates' colour), not the
## kit's greyer weathered planks - the founder's room palette stays as approved, the props only gain their joinery.
const CRATE_TONE := {"Planks": ["planks_weathered", 1.4, 0.0, 1.0, Color(0.22, 0.10, 0.03)], "Trim": ["planks_raw", 1.1, 0.0, 1.0, Color(0.105, 0.031, 0.008)]}
const KEG_TONE := {"Trim": ["planks_raw", 0.9, 0.0, 1.0, Color(0.26, 0.13, 0.05)], "Planks": ["planks_weathered", 0.9, 0.0, 1.0, Color(0.20, 0.10, 0.04)]}

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


## `slice` = spread the build over several frames (one `await process_frame` between groups) so it can run
## BEHIND the founder's film without freezing the video (skill ep2-seamless-transition). Callers `await` it.
static func build(visuals: Node3D, slice: bool = false) -> Dictionary:
	var d := HideoutDressing.new()
	d._slice = slice
	return await d._build(visuals)


var _slice: bool = false


func _breathe() -> void:
	if _slice and _v and _v.is_inside_tree():
		await _v.get_tree().process_frame


func _build(visuals: Node3D) -> Dictionary:
	_v = visuals
	_timber = _tex_mat(TIMBER_TEX, Color(0.66, 0.42, 0.24), 0.5)
	_dark_wood = _tex_mat(TIMBER_TEX, Color(0.36, 0.21, 0.11), 0.5)
	_iron = _plain(Color(0.18, 0.17, 0.16), 0.45, 0.35)
	_brass = Ep2Palette.make("brass")
	# Gold stays albedo-bright with a small emission: in the Compatibility backend a
	# high-metallic bar has no reflection source and renders near black (the palette's
	# own iron/rail note). Metallic held at 0.4; the warm fills in _fill_lights do the
	# glinting, not the metal.
	_gold = _plain(Color(1.0, 0.80, 0.33), 0.26, 0.40)
	_gold.emission_enabled = true
	_gold.emission = Color(1.0, 0.72, 0.24)
	_gold.emission_energy_multiplier = 0.035
	_gold.metallic_specular = 0.7
	_leather = _plain(Color(0.28, 0.15, 0.09), 0.7, 0.0)
	_dress_palette()
	_alcove()
	await _breathe()
	_authored_architecture()
	_finish_forge()
	await _breathe()
	_joinery_and_lanterns()
	await _breathe()
	_entry_wall()
	await _breathe()
	var poster := _poster()
	_trophies()
	await _breathe()
	var gat: Node3D = _gatling(Vector3(-4.0, 0.0, 7.2), -2.21)
	_gun_wall()
	await _breathe()
	_whiskey_table(WHISKEY_TABLE_POS)
	await _breathe()
	_rug(Vector3(0.9, 0.045, 4.4))
	_braziers()
	await _breathe()
	_gold_and_cart()
	await _breathe()
	_hanging_chains()
	await _breathe()
	_crates_and_ammo()
	await _breathe()
	_wall_props()
	await _breathe()
	_smithy()
	await _breathe()
	_bottle_shelf()
	await _breathe()
	_fill_lights()
	await _breathe()
	_atmosphere()
	_blockers.append([Vector2(WHISKEY_TABLE_POS.x, WHISKEY_TABLE_POS.z), 1.35])          # whiskey table
	return {"flames": _flames, "gatling": gat, "poster": poster, "blockers": _blockers, "rack_rifle": _rack_rifle}


## The founder's quality pass (2026-10-25: "hyperreal props ... tools, surfaces - not grey primitives"): the flat iron, brass and leather
## every code-built prop shares (chains, straps, hoops, tool heads, the ammo boxes' fittings, the saddle-leather) become the photo-scanned
## sets, keeping their colours (Ep2Pbr). The timber already has its grain texture. Streamed: without the extras the old flats stay.
func _dress_palette() -> void:
	var iron: StandardMaterial3D = Ep2Pbr.replace(_iron, "iron_painted", 0.5, 0.3)
	if iron != null:
		_iron = iron
	var brass: StandardMaterial3D = Ep2Pbr.replace(_brass, "brass_worn", 0.35, 0.55)
	if brass != null:
		_brass = brass
	var leather: StandardMaterial3D = Ep2Pbr.replace(_leather, "leather_brown", 0.4)
	if leather != null:
		_leather = leather


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
		if path == TIMBER_TEX:
			m.normal_enabled = true
			m.normal_texture = load(PROP_DIR + "finish_oak_normal.png")
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
	finish_materials(n)
	(parent if parent else _v).add_child(n)
	return n


## Keep authored PBR relief, with measured albedo values for the warm Web renderer.
## Source materials use linear Blender colours; these palette values are Godot sRGB.
static func finish_materials(root: Node3D) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			if not src is StandardMaterial3D or not src.resource_name.begins_with("Finish_"):
				continue
			var mat: StandardMaterial3D = src.duplicate()
			match src.resource_name:
				"Finish_HammeredIron": mat.albedo_color = Color(0.13, 0.12, 0.10)
				"Finish_RubbedIron": mat.albedo_color = Color(0.24, 0.21, 0.17)
				"Finish_OldBrass": mat.albedo_color = Color(0.34, 0.24, 0.08)
				"Finish_CastGold": mat.albedo_color = Color(0.65, 0.43, 0.12)
				"Finish_WornOak": mat.albedo_color = Color(0.65, 0.47, 0.30)
				"Finish_SootStone": mat.albedo_color = Color(0.48, 0.45, 0.39)
			mat.emission_enabled = false
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mi.set_surface_override_material(i, mat)


## A lantern that reads as a LIT lantern, not a flat white disc. The committed
## lantern.glb bakes its glass globe at full-white emission; in the Compatibility
## backend that clips to a pure-white octagon that, from across the room, reads as
## a pale plastic plate floating on the wall (see docs/episode2-quality/hideout-env).
## We keep the brass cage and recolour only the blown-out glass to a warm amber that
## crosses the glow threshold without losing its hue, then self-light it.
func _lantern(pos: Vector3, scale: float, parent: Node3D = null) -> Node3D:
	var lp: Node3D = _glb(LANTERN, pos, scale, 0.0, parent)
	if lp == null:
		return null
	finish_lantern(lp)
	return lp


## Fix individual cage and globe surfaces, preserving their imported geometry.
## Warm local lights illuminate the brass; self-emission belongs only to the globe.
static func finish_lantern(root: Node3D) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		for i in mi.mesh.get_surface_count():
			var source: Material = mi.mesh.surface_get_material(i)
			if not source is StandardMaterial3D:
				continue
			var mat: StandardMaterial3D = source.duplicate()
			mat.metallic = 0.25
			mat.roughness = 0.48
			if source.resource_name.contains("Glow"):
				mat.albedo_color = Color(0.72, 0.31, 0.05)
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.42, 0.06)
				mat.emission_energy_multiplier = 0.75
			else:
				mat.albedo_color = Color(0.25, 0.17, 0.07)
				mat.emission_enabled = false
			mi.set_surface_override_material(i, mat)


var _glass_mat: StandardMaterial3D = null

func _lantern_glass() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.albedo_color = Color(1.0, 0.74, 0.40)
		_glass_mat.roughness = 0.3
		_glass_mat.emission_enabled = true
		_glass_mat.emission = Color(1.0, 0.60, 0.24)
		_glass_mat.emission_energy_multiplier = 1.7
	return _glass_mat


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
	# Individual bevelled floorboards are supplied by the Blender architecture kit.
	# a low ceiling run of beams so the alcove has a roof line
	var bz: float = ALCOVE_Z0 + 0.5
	while bz < ALCOVE_Z1:
		_box(Vector3(WALL_X * 2.0, 0.34, 0.34), Vector3(0.0, 6.35, bz), _timber)
		bz += 2.6
	# lanterns along both walls
	for lz in [1.0, 6.0, 11.0]:
		for sx in [-1.0, 1.0]:
			var lamp := Ep2Palette.make_lantern_light()
			lamp.light_energy = 1.65
			lamp.omni_range = 8.0
			lamp.position = Vector3((WALL_X - 0.6) * sx, 3.9, lz)
			_v.add_child(lamp)
			_lantern(Vector3((WALL_X - 0.45) * sx, 3.5, lz), 1.1)

## Blender-authored boards, dressed-stone vault and fitted rifle cabinet.
## Five merged meshes keep hundreds of bevelled pieces inexpensive to submit.
func _authored_architecture() -> void:
	var kit := preload("res://src/episode2/assets/hideout/armory_architecture.glb").instantiate()
	kit.name = "ArmoryArchitecture"
	_v.add_child(kit)
	# Local lamp pools expose the stone bevels against the dark passage.
	for side in [-1.0, 1.0]:
		var pos := Vector3(side * 3.5, 3.65, 15.25)
		_lantern(pos, 0.75)
		_fire(pos + Vector3(-side * 0.3, 0.3, -0.3), 2.0, 5.5)
	for child in kit.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		for i in mi.mesh.get_surface_count():
			var src: StandardMaterial3D = mi.mesh.surface_get_material(i)
			var mat: StandardMaterial3D = src.duplicate()
			if src.resource_name.begins_with("ArmoryOak"):
				mat.albedo_color = Color(0.44, 0.27, 0.15) if src.resource_name == "ArmoryOak" else Color(0.36, 0.20, 0.10)
				mat.albedo_texture = load(TIMBER_TEX)
				mat.normal_enabled = true
				mat.normal_texture = load(PROP_DIR + "finish_oak_normal.png")
				mat.uv1_triplanar = true
				mat.uv1_scale = Vector3(0.65, 0.65, 0.65)
			elif src.resource_name.begins_with("ArmoryStone"):
				mat.albedo_color = Color(0.68, 0.62, 0.53)
				mat.albedo_texture = load("res://src/episode2/assets/textures/tex_rock_wall.jpg")
				mat.uv1_triplanar = true
				mat.uv1_scale = Vector3.ONE * 0.4
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			mi.set_surface_override_material(i, mat)
	# the oak and the stone above already carry their finish textures; the cabinet brass was still flat colour
	Ep2Pbr.dress(kit, {}, ["ArmoryOak", "ArmoryOakDark", "ArmoryStone", "ArmoryStoneLight"])


## Blender finish kit: deep masonry frames the existing furnace light plane.
## Geometry stays outside the walk route; progression and the opening are unchanged.
func _finish_forge() -> void:
	var forge := _glb(PROP_DIR + "furnace_stonework.glb", FURNACE_MOUNT, 1.0, 0.0)
	if forge:
		forge.name = "BlenderFurnaceStonework"
	# THE CAD FURNACE FRONT (founder 2026-10-25: "Inferno hideout smelting facility - hyperreal props, furnace, kegs, tools ... not grey
	# primitives"; tools/ep2_cad/smelter_kit_cad.py): cast-iron doors hung on the stone jambs and swung open into the room, a riveted
	# sheet-iron hood with its flue climbing into the rock roof, the great bellows feeding the left jamb, the fire tools against the face.
	# The doors and hood are built in the stonework's own frame at hideout size; the bellows and tools are real size. Streamed: until the
	# kit is mounted the furnace is as it was (nothing stands in), then Ep2KitProps.upgrade_pending() fills them in.
	var mount := Transform3D(Basis.IDENTITY, FURNACE_MOUNT)
	Ep2KitProps.place(_v, "Kit_FurnaceDoors", mount)
	Ep2KitProps.place(_v, "Kit_FurnaceHood", mount)
	var real := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * Ep2KitProps.SCALE_HIDEOUT), Vector3.ZERO)
	Ep2KitProps.place(_v, "Kit_Bellows", Transform3D(Basis(Vector3.UP, -PI * 0.5), BELLOWS_AT), real)     # nozzle (+x) into the jamb
	Ep2KitProps.place(_v, "Kit_FireTools", Transform3D(Basis.IDENTITY, FIRE_TOOLS_AT), real)              # leaning back onto the face
	_blockers.append([Vector2(-4.95, 15.05), 0.6])     # the right-hand door, swung into the room (the left one is past the walk clamp)
	_blockers.append([Vector2(FIRE_TOOLS_AT.x, FIRE_TOOLS_AT.z), 0.35])


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
			var rubble := _glb(RunnerView.BOULDER_ROCK_MODEL, Vector3((4.2 + 1.7 * float(k)) * side, -0.2, -10.3),
				1.7 + 0.3 * float(k % 2), float(k) * 1.7, stonework)
			if rubble:
				for mi in rubble.find_children("*", "MeshInstance3D", true, false):
					mi.material_override = rock
		_lantern(Vector3(3.05 * side, 3.2, -10.55), 1.0, stonework)
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
	# Colt Single Action revolvers on pegs, two rows of three, below the rifles: the CAD Colt (fluted cylinder, ejector housing, case-hardened
	# frame, walnut grip; Ep2KitProps) at Inferno's scale, the old code-built one standing in until the streamed kit is mounted.
	for r in 2:
		for i in 3:
			var rp := Vector3(wx + 0.1, 1.55 - 0.45 * float(r), 4.9 + float(i) * 1.5 + 0.2 * float(r))
			Ep2KitProps.place(_v, "Kit_Revolver", Transform3D(Basis.IDENTITY, rp), Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * Ep2KitProps.SCALE_HIDEOUT),
				Vector3.ZERO), _revolver)
	for i in 6:
		_cyl(0.03, 0.03, 0.12, Vector3(wx + 0.1, 1.0, 4.9 + 0.09 * float(i)), _brass, Vector3(0, 0, 0))
	# The miner's helmet hangs on its own peg at the end of the rack (Inferno Bull takes it down for Lil Blunt).
	_box(Vector3(0.1, 0.9, 0.9), Vector3(wx - 0.02, 2.15, 10.2), _timber)
	_cyl(0.03, 0.03, 0.3, Vector3(wx + 0.12, 2.2, 10.2), _iron, Vector3(0, 0, 90))


## The old code-built revolver (barrel, cylinder, frame, grip) in `root`'s frame: the stand-in until the CAD Colt is mounted.
func _revolver(root: Node3D) -> void:
	_cyl(0.025, 0.025, 0.42, Vector3(0.0, 0.0, 0.2), _iron, Vector3(90, 0, 0), root)            # barrel
	_cyl(0.055, 0.055, 0.1, Vector3(0.0, 0.0, -0.04), _iron, Vector3(90, 0, 0), root)            # cylinder
	_box(Vector3(0.05, 0.12, 0.16), Vector3(0.0, -0.05, -0.16), _iron, Vector3(0, 0, 0), root)    # frame
	_box(Vector3(0.05, 0.2, 0.09), Vector3(0.0, -0.13, -0.24), _plain(Color(0.45, 0.22, 0.10), 0.5, 0.0), Vector3(18, 0, 0), root)  # grip


## The Colt Gatling (Meshy): brass breech, six barrels, wooden tripod. Its muzzle is model -X; `yaw` turns it.
func _gatling(pos: Vector3, yaw: float) -> Node3D:
	# The Armory's Colt Gatling (founder 2026-10-24: Inferno's items "look crass and trash" - the old Meshy gun stood on a stick
	# tripod): the same detailed post-mounted gun Rich keeps (streamed, extras/armory/gatling_post.glb), without its NOT FOR SALE sign.
	if Ep2Extras.has(Ep2Extras.GATLING):
		var src: Node = (load(Ep2Extras.GATLING) as PackedScene).instantiate()
		var post: Node3D = src.find_child("Gatling_Post", true, false) as Node3D
		if post != null:
			var gun: Node3D = post.duplicate() as Node3D
			gun.transform = Transform3D(Basis(Vector3.UP, yaw + GATLING_YAW_FIX), pos)
			gun.name = "ColtGatling"
			_v.add_child(gun)
			Ep2Pbr.dress(gun, Ep2GatlingPost.DRESS_INDOORS, [], true)     # the kit's intended dark iron / stone in the fire-lit room
			src.free()
			_blockers.append([Vector2(pos.x, pos.z), 1.1])
			return gun
		src.free()
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
	var cast_scene: PackedScene = load(PROP_DIR + "cast_ingot.glb") as PackedScene
	var stacks := Node3D.new()
	stacks.name = "BeveledGoldStacks"
	_v.add_child(stacks)
	for stack in [Vector3(-2.3, 0.0, 4.3), Vector3(5.6, 0.0, 12.2)]:
		for row in 4:
			var cols: int = 5 - row
			for c in cols:
				var x: float = stack.x - float(cols - 1) * 0.28 + float(c) * 0.56
				if cast_scene:
					var bar: Node3D = cast_scene.instantiate()
					finish_materials(bar)
					bar.scale = Vector3(1.0, 1.35, 1.4)
					bar.position = Vector3(x, 0.176 * float(row), stack.z)
					bar.rotation_degrees.y = float((row + c) % 3 - 1) * 1.8
					stacks.add_child(bar)
				else:
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
	# Real oval links on a hook (the CAD kit, one MultiMesh per chain); the old rod + ring stands in until the kit is mounted.
	var dark: StandardMaterial3D = _dark_iron()
	for cx in [-5.2, -2.6, 4.6, 6.2]:
		for cz in [2.0, 8.0]:
			var length: float = 2.4 + fmod(absf(cx * cz), 1.6)
			Ep2KitProps.chain(_v, Vector3(cx, 6.2, cz), length, 3.4, func(h: Node3D) -> void:
				_cyl(0.05, 0.05, length, Vector3(0.0, -length * 0.5, 0.0), dark, Vector3.ZERO, h)
				_cyl(0.09, 0.09, 0.08, Vector3(0.0, -length, 0.0), _iron, Vector3(90, 0, 0), h))


# --- crates, ammo boxes, brass cartridges (foreground + wall clusters) ----------------------------
## The reference foreground is crates and open ammo boxes spilling brass. These sit along the walls and
## in the arrival corners so the room reads full the instant Lil Blunt walks in, without crowding the
## central walk lane (player runs x within +/-6.3, z -8..15; Bull works at x~1.6 z~8). Every solid stack
## gets a blocker.
func _crates_and_ammo() -> void:
	var root := Node3D.new()
	root.name = "HideoutCrates"
	_v.add_child(root)
	# [centre xz, box size, has an open ammo box on top]
	var clusters := [
		[Vector3(5.7, 0.0, -3.0), Vector3(1.3, 1.1, 1.3), false],   # arrival corner, screen-left
		[Vector3(5.5, 0.0, -1.2), Vector3(0.9, 0.8, 0.9), true],
		[Vector3(-5.7, 0.0, -3.2), Vector3(1.3, 1.2, 1.3), false],  # arrival corner, screen-right
		[Vector3(-5.9, 0.0, 3.4), Vector3(1.1, 1.0, 1.1), true],    # below the gun wall
		[Vector3(-6.0, 0.0, 11.8), Vector3(1.2, 1.3, 1.2), false],
		[Vector3(3.2, 0.0, 6.1), Vector3(0.95, 0.8, 0.95), true],   # by the Bull's bench
		[Vector3(6.1, 0.0, 9.6), Vector3(1.1, 1.0, 1.1), false],
	]
	for cl in clusters:
		var p: Vector3 = cl[0]
		var sz: Vector3 = cl[1]
		_crate(p + Vector3(0.0, sz.y * 0.5, 0.0), sz, root)
		# a smaller crate perched off-centre on the big one for a layered pile
		if not cl[2]:
			var sz2: Vector3 = sz * 0.62
			_crate(p + Vector3(sz.x * 0.18, sz.y + sz2.y * 0.5, -sz.z * 0.12), sz2, root)
		else:
			_ammo_box(p + Vector3(0.0, sz.y + 0.02, 0.0), root)
		_blockers.append([Vector2(p.x, p.z), maxf(sz.x, sz.z) * 0.62 + 0.25])
	# a few brass cartridges and a spilled pile on the plank floor by the gun wall
	_spilled_brass(Vector3(-5.1, 0.03, 4.6), root, 9)
	_spilled_brass(Vector3(4.2, 0.03, 5.4), root, 6)


## A crate of `size` centred on `centre`: the CAD kit's planked crate (battens, braces, iron corner plates, bolt heads) in the hideout's own
## warm timber (CRATE_TONE), the old banded box standing in until the streamed kit is mounted.
func _crate(centre: Vector3, size: Vector3, parent: Node3D) -> void:
	Ep2KitProps.place(parent, "Kit_Crate", Transform3D(Basis.IDENTITY, centre), Transform3D(Basis.IDENTITY.scaled(size), Vector3(0.0, -size.y * 0.5, 0.0)),
		func(h: Node3D) -> void: _crate_box(Vector3.ZERO, size, h), false, CRATE_TONE)


## The old banded timber crate: plank body, darker plank grooves, brass corner straps and bolt heads.
func _crate_box(centre: Vector3, size: Vector3, parent: Node3D) -> void:
	_box(size, centre, _timber, Vector3.ZERO, parent)
	# plank grooves on the four sides
	for gz in [-0.3, 0.0, 0.3]:
		_box(Vector3(size.x * 1.002, size.y * 0.9, 0.025), centre + Vector3(0.0, 0.0, size.z * gz), _dark_wood, Vector3.ZERO, parent)
		_box(Vector3(0.025, size.y * 0.9, size.z * 1.002), centre + Vector3(size.x * gz, 0.0, 0.0), _dark_wood, Vector3.ZERO, parent)
	# diagonal brace on the front face (screen side, toward -Z arrival)
	_box(Vector3(size.x * 1.3, 0.09, 0.03), centre + Vector3(0.0, 0.0, -size.z * 0.505), _dark_wood, Vector3(0, 0, 32), parent)
	# brass edge straps top and bottom + corner bolts
	for sy in [-0.42, 0.42]:
		_box(Vector3(size.x * 1.01, 0.07, size.z * 1.01), centre + Vector3(0.0, size.y * sy, 0.0), _brass, Vector3.ZERO, parent)
	for bx in [-0.46, 0.46]:
		for bz in [-0.46, 0.46]:
			_box(Vector3(0.06, size.y * 0.96, 0.06), centre + Vector3(size.x * bx, 0.0, size.z * bz), _brass, Vector3.ZERO, parent)


## An open box of ammunition on a crate: the CAD kit's planked box with 25 standing .45-70 rounds and two spilled on the lid, in the
## hideout's timber; the old box stands in until the streamed kit is mounted.
func _ammo_box(centre: Vector3, parent: Node3D) -> void:
	Ep2KitProps.place(parent, "Kit_AmmoBox", Transform3D(Basis.IDENTITY, centre), Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3.ONE * 2.07),
		Vector3(0.0, -0.13, 0.0)), func(h: Node3D) -> void: _ammo_box_open(Vector3.ZERO, h), false, CRATE_TONE)


## The old open crate of ammunition: four low walls, a floor, packed rows of standing brass cartridges, a
## couple knocked over on the rim.
func _ammo_box_open(centre: Vector3, parent: Node3D) -> void:
	var w := 0.62
	var h := 0.26
	var wall := 0.05
	_box(Vector3(w, 0.05, w), centre + Vector3(0.0, -h * 0.4, 0.0), _dark_wood, Vector3.ZERO, parent)
	for s in [-1.0, 1.0]:
		_box(Vector3(w, h, wall), centre + Vector3(0.0, 0.0, (w * 0.5) * s), _dark_wood, Vector3.ZERO, parent)
		_box(Vector3(wall, h, w), centre + Vector3((w * 0.5) * s, 0.0, 0.0), _dark_wood, Vector3.ZERO, parent)
	# packed cartridges standing up (brass case + copper tip)
	var copper := _plain(Color(0.72, 0.38, 0.16), 0.3, 0.6)
	for ix in range(-2, 3):
		for iz in range(-2, 3):
			var cp: Vector3 = centre + Vector3(float(ix) * 0.1, 0.07, float(iz) * 0.1)
			_cyl(0.035, 0.038, 0.13, cp, _brass, Vector3.ZERO, parent)
			_cyl(0.015, 0.032, 0.05, cp + Vector3(0.0, 0.09, 0.0), copper, Vector3.ZERO, parent)
	# two spilled over the near rim
	for k in [-0.12, 0.14]:
		var sp: Vector3 = centre + Vector3(k, h * 0.5 + 0.02, -w * 0.5 - 0.09)
		_cyl(0.036, 0.036, 0.16, sp, _brass, Vector3(90, 18.0 * signf(k), 0), parent)


## A little scatter of loose brass rounds on the floor.
func _spilled_brass(centre: Vector3, parent: Node3D, n: int) -> void:
	var copper := _plain(Color(0.72, 0.38, 0.16), 0.3, 0.6)
	for i in n:
		var a: float = float(i) * 2.4
		var off := Vector3(cos(a) * 0.28 * float(i % 3 + 1) * 0.3, 0.035, sin(a * 1.7) * 0.26 * float(i % 2 + 1) * 0.3)
		var rp: Vector3 = centre + off
		# the CAD .45-70 lying the same way the old round did, centred on its spot, its side on the planks
		var turn := Basis.from_euler(Vector3(PI * 0.5, a, 0.0))
		var local := Transform3D(turn.scaled(Vector3.ONE * 3.0), Vector3(0.0, -0.012, 0.0) + turn * Vector3(0.0, -0.1155, 0.0))
		Ep2KitProps.place(parent, "Kit_Cartridge", Transform3D(Basis.IDENTITY, rp), local, func(h: Node3D) -> void:
			_cyl(0.034, 0.034, 0.15, Vector3.ZERO, _brass, Vector3(90, rad_to_deg(a), 0), h)
			_cyl(0.014, 0.03, 0.045, Vector3(cos(a) * 0.08, 0.0, sin(a) * 0.08), copper, Vector3(90, rad_to_deg(a), 0), h))


# --- wall props: bandoliers, tools, horseshoes, tally marks, wanted posters -----------------------
func _wall_props() -> void:
	var root := Node3D.new()
	root.name = "HideoutWallProps"
	_v.add_child(root)
	var copper := _plain(Color(0.72, 0.38, 0.16), 0.3, 0.6)
	# Bandoliers slung on both timber walls (leather strap + a run of brass rounds). Kept off the gun-wall
	# rack rows (z 5.3..8.7 on -X) and off the trophy heads.
	for spec in [[1.0, 2.7, 1.9], [1.0, 2.9, 12.6], [-1.0, 1.6, 9.9], [-1.0, 2.8, 2.3]]:
		var sx: float = spec[0]
		var wx: float = (WALL_X - 0.14) * sx
		var y: float = spec[1]
		var z0: float = spec[2]
		_box(Vector3(0.05, 0.16, 2.0), Vector3(wx, y, z0), _leather, Vector3(22.0 * sx, 0, 0), root)
		for i in 10:
			var rz: float = z0 - 0.85 + float(i) * 0.19
			var ry: float = y + 0.34 - float(i) * 0.068
			_cyl(0.028, 0.03, 0.12, Vector3(wx - 0.06 * sx, ry, rz), _brass, Vector3(90, 0, 0), root)
			_cyl(0.012, 0.025, 0.04, Vector3(wx - 0.12 * sx, ry, rz), copper, Vector3(90, 0, 0), root)
	# Horseshoes nailed to the timber (good-luck, both walls).
	var shoe := TorusMesh.new()
	shoe.inner_radius = 0.1
	shoe.outer_radius = 0.17
	shoe.rings = 10
	shoe.ring_segments = 7
	for spec2 in [[1.0, 4.6, 2.0], [1.0, 4.4, 9.4], [-1.0, 4.7, 3.1]]:
		var wx2: float = (WALL_X - 0.12) * spec2[0]
		_add(shoe, _iron, Vector3(wx2, spec2[1], spec2[2]), Vector3(0, 90.0 * spec2[0], 8), root)
	# Shovel + sledgehammer leaning in the screen-left back corner (near the ore cart / gold).
	_lean_tool(Vector3(6.3, 0.0, 12.9), 2.0, root, true)     # shovel
	_lean_tool(Vector3(6.55, 0.0, 12.4), 1.9, root, false)   # sledge
	# Tally-mark scratches on a plank by the whiskey table (how many days in the Mine).
	var chalk := _plain(Color(0.86, 0.82, 0.7), 0.95, 0.0)
	chalk.emission_enabled = true
	chalk.emission = Color(0.6, 0.55, 0.42)
	chalk.emission_energy_multiplier = 0.3
	for g in 4:
		var gx0: float = (WALL_X - 0.1)
		var bz0: float = 5.6 + float(g) * 0.32
		for m in 4:
			_box(Vector3(0.015, 0.22, 0.02), Vector3(gx0, 1.75, bz0 + float(m) * 0.055), chalk, Vector3(0, 0, 0), root)
		_box(Vector3(0.015, 0.26, 0.02), Vector3(gx0, 1.75, bz0 + 0.11), chalk, Vector3(0, 0, 40), root)  # the slash
	# Framed wanted posters on the timber (parchment, hand-bill bars for text, a dark frame).
	_wanted_poster(Vector3(-(WALL_X - 0.1), 3.8, 7.2), -1.0, root)
	_wanted_poster(Vector3((WALL_X - 0.1), 4.3, 6.4), 1.0, root)


# --- the smelter's working floor: kegs, the anvil, ingot moulds, a pick ------------------------------------------------------------------
## Founder 2026-10-25 ("furnace, kegs, tools ... not grey primitives"): new CAD pieces from the kit (Ep2KitProps) - two oak kegs with a small
## one on top by the trophy wall, a keg lying on its chocks below the gun wall, the anvil on its banded stump with the tongs on its face and
## two ingot moulds before the furnace, a pick leaning on the trophy wall. They are new, so without the streamed kit they simply arrive with
## it (no primitive stand-ins). Spots keep clear of the walk lane, Inferno's route to the door, the cauldrons and every existing prop.
func _smithy() -> void:
	var root := Node3D.new()
	root.name = "HideoutSmithy"
	_v.add_child(root)
	var s: float = 1.5                                            # kegs at Inferno's scale (~0.93 m tall)
	_kit_at(root, "Kit_Keg", Vector3(6.3, 0.0, 5.6), 0.4, s, KEG_TONE)
	_kit_at(root, "Kit_Keg", Vector3(6.2, 0.0, 6.42), 1.9, s, KEG_TONE)
	_kit_at(root, "Kit_KegSmall", Vector3(6.3, (0.62 - 0.028) * s, 5.6), 0.9, s, KEG_TONE)       # resting on the first keg's head
	_blockers.append([Vector2(6.25, 6.0), 0.95])
	# the lying keg: its axis across toward the gun wall, on two chocks whose cradle (r 0.245 at y 0.30) is the keg's bilge
	for cx in [-0.27, 0.27]:
		_kit_at(root, "Kit_Chock", Vector3(-6.2 + cx * s, 0.0, -0.5), 0.0, s, KEG_TONE)
	Ep2KitProps.place(root, "Kit_Keg", Transform3D(Basis.IDENTITY, Vector3(-6.2, 0.0, -0.5)),
		Transform3D(Basis(Vector3.BACK, -PI * 0.5).scaled(Vector3.ONE * s), Vector3(-0.31 * s, 0.30 * s, 0.0)), Callable(), false, KEG_TONE)
	_blockers.append([Vector2(-6.2, -0.5), 0.75])
	# the anvil on its stump (face top 0.749 m real), the tongs lying across its face, two ingot moulds on the floor beside it
	var a: float = 1.6
	_kit_at(root, "Kit_Anvil", Vector3(-5.9, 0.0, 14.2), 0.25, a)
	_kit_at(root, "Kit_Tongs", Vector3(-5.9, (0.749 + 0.017) * a, 14.2), 0.25 + PI * 0.5 + 0.2, a)
	_blockers.append([Vector2(-5.9, 14.2), 0.75])
	_kit_at(root, "Kit_Mould", Vector3(-7.1, 0.0, 14.0), 0.1, a)
	_kit_at(root, "Kit_Mould", Vector3(-7.1, 0.07 * a, 14.0), 0.35, a)
	_blockers.append([Vector2(-7.1, 14.0), 0.5])
	# a pick, head up, leaning on the trophy wall beside the sledge (its top touches the timber at x 7.1)
	Ep2KitProps.place(root, "Kit_Pick", Transform3D(Basis.IDENTITY, Vector3(6.55, 0.0, 11.6)),
		Transform3D((Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(-74.0))).scaled(Vector3.ONE * 2.1), Vector3.ZERO), Callable(), true)


## A kit prop standing at `pos` turned `yaw`, at `s` x real size (no stand-in: a new piece waits for the streamed kit).
func _kit_at(parent: Node3D, prop: String, pos: Vector3, yaw: float, s: float, tone: Dictionary = {}) -> Node3D:
	return Ep2KitProps.place(parent, prop, Transform3D(Basis(Vector3.UP, yaw), pos), Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO),
		Callable(), false, tone)


## A tool leaning on the wall, tilted like the old one: the CAD kit's coal shovel (D-grip, blade down) or octagonal sledge (head up); the
## old handle-and-box stands in until the streamed kit is mounted. Kit tools lie along -z from their working end (real 1.27 m / 0.95 m).
func _lean_tool(base: Vector3, length: float, parent: Node3D, shovel: bool) -> void:
	var turn := Basis(Vector3.RIGHT, deg_to_rad(106.0 if shovel else -74.0))
	var s: float = length / (1.27 if shovel else 0.95)
	Ep2KitProps.place(parent, "Kit_Shovel" if shovel else "Kit_Sledge", Transform3D(Basis.IDENTITY, base), Transform3D(turn.scaled(Vector3.ONE * s),
		Vector3.ZERO), func(h: Node3D) -> void: _lean_tool_old(Vector3.ZERO, length, h, shovel), true)


## The old leaning tool: handle + head.
func _lean_tool_old(base: Vector3, length: float, parent: Node3D, shovel: bool) -> void:
	var handle := _plain(Color(0.5, 0.33, 0.18), 0.75, 0.0)
	var tilt := 16.0
	_cyl(0.035, 0.04, length, base + Vector3(0.0, length * 0.5, 0.0), handle, Vector3(tilt, 0, 0), parent)
	var head_y: float = length * 0.02
	if shovel:
		_box(Vector3(0.34, 0.42, 0.04), base + Vector3(0.0, head_y + 0.2, length * 0.14), _iron, Vector3(tilt, 0, 0), parent)
	else:
		_box(Vector3(0.5, 0.18, 0.18), base + Vector3(0.0, length * 0.96, length * 0.1), _dark_iron(), Vector3(tilt, 0, 90), parent)


func _wanted_poster(pos: Vector3, sx: float, parent: Node3D) -> void:
	_box(Vector3(0.06, 1.15, 0.9), pos, _dark_wood, Vector3.ZERO, parent)
	# The real hand-bills (founder 2026-10-24: the posters looked like blank boards): the same engraved posters the town hangs
	# (Ep2TownPosters, streamed). Jack Hammer on the left wall, the masked stage robbers on the right. Bars below are the fallback.
	var bill: String = Ep2TownPosters.DIR + ("poster_jack_hammer.jpg" if sx < 0.0 else "poster_masked_riders.jpg")
	if Ep2Extras.has(bill):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(bill)
		m.roughness = 0.95
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var q := QuadMesh.new()
		q.size = Vector2(0.74, 0.74 * Ep2TownPosters.ASPECT_PAINTED)
		_add(q, m, pos + Vector3(-0.04 * sx, 0.0, 0.0), Vector3(0.0, -sx * 90.0, sx * 1.5), parent)
		return
	var paper := _plain(Color(0.82, 0.73, 0.55), 0.95, 0.0)
	paper.emission_enabled = true
	paper.emission = Color(0.65, 0.52, 0.34)
	paper.emission_energy_multiplier = 0.4
	_box(Vector3(0.015, 1.0, 0.76), pos + Vector3(-0.05 * sx, 0.0, 0.0), paper, Vector3.ZERO, parent)
	var ink := _plain(Color(0.12, 0.08, 0.05), 1.0, 0.0)
	# "WANTED" banner + a portrait block + reward bars
	_box(Vector3(0.016, 0.14, 0.62), pos + Vector3(-0.058 * sx, 0.36, 0.0), ink, Vector3.ZERO, parent)
	_box(Vector3(0.016, 0.34, 0.34), pos + Vector3(-0.058 * sx, 0.02, 0.0), ink, Vector3.ZERO, parent)
	for by in [-0.28, -0.38]:
		_box(Vector3(0.016, 0.05, 0.5), pos + Vector3(-0.058 * sx, by, 0.0), ink, Vector3.ZERO, parent)


# --- a saloon bottle shelf on the wall behind the whiskey table -----------------------------------
func _bottle_shelf() -> void:
	var root := Node3D.new()
	root.name = "HideoutBottleShelf"
	_v.add_child(root)
	var wx: float = WALL_X - 0.18
	for sy in [2.3, 3.0]:
		_box(Vector3(0.4, 0.06, 2.4), Vector3(wx, sy, 3.6), _dark_wood, Vector3.ZERO, root)
		# brackets
		for bz in [2.6, 4.6]:
			_box(Vector3(0.36, 0.06, 0.06), Vector3(wx, sy - 0.12, bz), _iron, Vector3(0, 0, 32), root)
		var cols := [Color(0.18, 0.4, 0.2, 0.85), Color(0.42, 0.22, 0.08, 0.9), Color(0.5, 0.3, 0.05, 0.85),
			Color(0.1, 0.22, 0.3, 0.85), Color(0.45, 0.14, 0.1, 0.9), Color(0.5, 0.42, 0.12, 0.85)]
		for i in 6:
			var gm := _plain(cols[i], 0.15, 0.0)
			gm.emission_enabled = true
			gm.emission = Color(cols[i].r, cols[i].g, cols[i].b)
			gm.emission_energy_multiplier = 0.3
			var bz: float = 2.6 + float(i) * 0.36
			_cyl(0.07, 0.08, 0.34, Vector3(wx, sy + 0.2, bz), gm, Vector3.ZERO, root)
			_cyl(0.028, 0.05, 0.14, Vector3(wx, sy + 0.44, bz), gm, Vector3.ZERO, root)


# --- warm fill / rim lighting so the dressing reads against the dark timber -----------------------
## The forge environment is deliberately dark (Ep2Palette.make_environment); the furnace is on +X
## (screen-left) and the room falls off to near-black between its lanterns. These steady warm fills
## lift the gold, the gun wall, the trophies and the arrival floor so every prop reads, and push the
## molten-gold spill the reference leads with. They carry no flicker (not appended to `_flames`).
func _fill_lights() -> void:
	# [pos, energy, range, color]
	var fills := [
		# molten-gold spill off the furnace channel (world +X), the reference's warm key
		[Vector3(5.6, 1.3, 10.5), 3.0, 11.0, Color(1.0, 0.5, 0.14)],
		[Vector3(3.4, 1.0, 12.8), 2.0, 9.0, Color(1.0, 0.46, 0.12)],
		# the gold stacks + ore cart glint
		[Vector3(-2.3, 1.4, 4.3), 1.8, 5.5, Color(1.0, 0.74, 0.34)],
		[Vector3(5.6, 1.4, 12.2), 1.6, 5.5, Color(1.0, 0.74, 0.34)],
		[Vector3(-3.9, 1.3, 1.4), 1.5, 5.0, Color(1.0, 0.72, 0.32)],
		# the armory wall (world -X)
		[Vector3(-5.6, 2.6, 6.8), 1.6, 5.5, Color(1.0, 0.72, 0.42)],
		# the full taxidermy bears so they read warm-brown not grey
		[Vector3(5.4, 2.0, 8.0), 1.4, 4.5, Color(1.0, 0.7, 0.4)],
		[Vector3(-5.9, 2.0, 12.4), 1.3, 4.5, Color(1.0, 0.7, 0.4)],
		# the Fort Knox back wall + skull so the deep hideout reads from a forward view
		[Vector3(0.0, 3.6, 14.4), 1.6, 7.0, Color(1.0, 0.64, 0.3)],
		# the arrival/approach floor from the CAMERA side (never top-down over the range
		# firing bench at z=-2.55, which would read as a black silhouette box)
		[Vector3(0.0, 2.3, -5.4), 1.0, 7.5, Color(1.0, 0.66, 0.34)],
		[Vector3(0.0, 3.0, 2.0), 1.0, 7.5, Color(1.0, 0.68, 0.36)],
	]
	for f in fills:
		var l := OmniLight3D.new()
		l.position = f[0]
		l.light_energy = f[1]
		l.omni_range = f[2]
		l.light_color = f[3]
		l.light_specular = 0.6
		_v.add_child(l)


# --- atmosphere: drifting ember motes + faint haze so the air catches the firelight ---------------
func _atmosphere() -> void:
	var root := Node3D.new()
	root.name = "HideoutAtmosphere"
	_v.add_child(root)
	# slow-rising embers over the furnace / brazier side
	for p in [Vector3(4.6, 1.2, 10.5), Vector3(-2.2, 1.1, 8.4), Vector3(3.6, 1.1, 8.6)]:
		_embers(p, root)
	# a couple of broad, very faint warm haze billboards up in the beams to read the volume of smoke/heat
	for h in [Vector3(2.5, 4.6, 7.0), Vector3(-3.0, 4.8, 4.0), Vector3(4.5, 4.4, 12.0)]:
		_haze(h, root)


func _embers(pos: Vector3, parent: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 20
	p.lifetime = 3.2
	p.position = pos
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_blob()
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.4, 0.0))
	g.add_point(0.25, Color(1.0, 0.65, 0.25, 0.9))
	g.set_color(g.get_point_count() - 1, Color(0.8, 0.3, 0.05, 0.0))
	p.color_ramp = g
	p.direction = Vector3.UP
	p.spread = 24.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.0, 0.35, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.3, 0.9)
	p.preprocess = 2.0
	parent.add_child(p)


func _haze(pos: Vector3, parent: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 7.0
	p.position = pos
	var q := QuadMesh.new()
	q.size = Vector2(3.4, 3.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_blob()
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.6, 0.3, 0.0))
	g.add_point(0.5, Color(1.0, 0.55, 0.25, 0.14))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.45, 0.2, 0.0))
	p.color_ramp = g
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0.05, 0.08, 0.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.6, 0.4, 1.6)
	p.preprocess = 4.0
	parent.add_child(p)


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
	var c: Node3D = d._glb(PROP_DIR + "forge_crucible.glb", pos, height / 1.70, 0.0)
	if c == null:
		c = d._prop("cauldron", pos, height, 0.0)
		if c:
			for mesh in c.find_children("*", "MeshInstance3D", true, false):
				var iron := StandardMaterial3D.new()
				iron.albedo_color = Color(0.22, 0.18, 0.14)
				iron.metallic = 0.25
				iron.roughness = 0.65
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
			_lantern(Vector3(x, 4.3, z), 0.65, root)
			_fire(Vector3(x, 4.6, z), 1.2, 5.0)
	# THE ELEVATOR DOOR, OPEN (founder 2026-10-24: "improve the design of the door that leads to the elevator ... the door should be open and
	# we should be able to see the elevator from within the smelting facility"). Two heavy plank leaves swung right back toward the room on
	# strap hinges, so the arch is clear and the doorway shows the mine lift beyond it (SmeltingFacilityChamber.portal_attach; the session
	# root draws the built lift room in it). Each leaf: six boards with gaps and a little warp, three riveted iron straps, a clinched-nail
	# brace, a ring pull. The leaves swing into the ROOM - into the passage they would stand behind the doorway image and vanish.
	var plank_tones: Array = [0.92, 1.0, 0.86, 0.97, 0.9, 1.04]
	for side in [-1.0, 1.0]:
		var door := Node3D.new()
		door.name = "ElevatorDoorLeaf"
		door.position = Vector3(side * 2.3, 0.0, 16.1)
		door.rotation.y = -side * 1.5                    # open flat toward the room, either side of the arch
		root.add_child(door)
		for i in 6:
			var w := StandardMaterial3D.new()
			w.albedo_color = _dark_wood.albedo_color * float(plank_tones[i])
			w.albedo_texture = _dark_wood.albedo_texture
			w.uv1_triplanar = _dark_wood.uv1_triplanar
			w.uv1_scale = _dark_wood.uv1_scale
			w.roughness = 0.9
			var x: float = -side * (0.13 + float(i) * 0.24)
			_box(Vector3(0.22, 3.95 - 0.03 * float(i % 3), 0.11), Vector3(x, 1.98, 0.0), w, Vector3(0, 0, 0.4 * float(i % 2) - 0.2), door)
		for y in [0.45, 1.98, 3.5]:
			_box(Vector3(1.48, 0.13, 0.04), Vector3(-side * 0.74, y, -0.075), _iron, Vector3.ZERO, door)       # strap across the boards
			_box(Vector3(0.62, 0.15, 0.05), Vector3(side * 0.18, y, -0.07), _iron, Vector3.ZERO, door)          # the strap hinge round the pin
			for k in 6:
				_cyl(0.022, 0.022, 0.03, Vector3(-side * (0.12 + float(k) * 0.26), y, -0.1), _brass, Vector3(90, 0, 0), door)
		_box(Vector3(0.12, 2.0, 0.06), Vector3(-side * 0.74, 1.2, -0.065), _iron, Vector3(0, 0, side * 33.0), door)  # diagonal brace
		var ring := TorusMesh.new()
		ring.inner_radius = 0.07
		ring.outer_radius = 0.1
		_add(ring, _iron, Vector3(-side * 1.3, 1.25, -0.14), Vector3(0, 0, 0), door)
		_cyl(0.05, 0.05, 0.05, Vector3(-side * 1.3, 1.35, -0.1), _brass, Vector3(90, 0, 0), door)                 # its boss
		_cyl(0.045, 0.045, 4.1, Vector3(side * 0.02, 2.0, 0.0), _iron, Vector3.ZERO, door)                        # the hinge pin
	# The passage beyond the door: dark, until the doorway shows the lift room (then this plate is hidden, see portal_attach).
	var plate := _box(Vector3(4.3, 4.2, 0.15), Vector3(0, 2.1, 18.2), _plain(Color(0.05, 0.035, 0.025), 1.0, 0.0), Vector3.ZERO, root)
	plate.name = "PassagePlate"
	for x in [-8.0, -4.3, 4.4, 8.2]:
		for i in 3:
			var rock: Node3D = _glb(RunnerView.BOULDER_ROCK_MODEL, Vector3(x, 2.4 + float(i) * 1.7, 17.6), 1.9, x, root)
			if rock:
				for mesh in rock.find_children("*", "MeshInstance3D", true, false):
					mesh.material_override = stone

