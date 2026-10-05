class_name RangeDressing
extends RefCounted
## Inferno Bull's TARGET PRACTICE range inside the hideout (founder 2026-10-04, two rounds). Skill ep2-range-lesson.
##
## ROUND 2 (founder): "make the target practice area more practical. There is a lot of room in the back so lets
## have it against the empty wall. And let's have the targets be the logos of the protocols in an interesting way
## [glowing-ring plaques, ref 'Minotaur Mentors Leafy Sharpshooter'] ... One of the targets must also be a bear."
## So the range now faces the EMPTY -Z wall (the entry hall, the open end of the room): a timber target wall holds
## four protocol-logo plaques in glowing green rings, plus a standing bear, and the player shoots down a clear lane
## from a firing bench. The furnace and Bull are off to the side, as in the reference.
##
## This file is the VISUAL owner of the range; `SmeltingFacilityChamber` owns the GAMEPLAY and talks to it only
## through this contract, so the range can be restyled without touching the lesson logic:
##   * `LINE`            where Lil Blunt stands to shoot (the firing line), facing -Z.
##   * `BULL_LINE`       where Inferno stands for his demonstration, beside the line.
##   * `LANE_X`          the lane's centre x (the player's firing column).
##   * `TARGET_Z`        the wall the plaques mount on.
##   * `TARGET_SPOTS`    the hit CENTRE of each target (same order as `TARGET_KINDS`); near..far by angle.
##   * `TARGET_KINDS`    what each target is ("titanx" | "gold_mine" | "diamonds" | "blaze_diamonds" | "bear").
##   * `PLATE_RADIUS`    the hittable radius used by the gameplay's ray test.
##   * `build(parent, timber)` -> {"targets": Array[Node3D] (one per TARGET_SPOTS, origin AT the hit centre),
##                                 "blockers": Array of [Vector2, radius], "line": Vector3}
##   * `set_target_state(target, broken)` the hit/standing look; the gameplay calls it every time it syncs.

const LANE_X := 0.0
## The firing line faces -Z (into the open entry hall), the "lots of room in the back" the founder asked for.
const LINE := Vector3(0.0, 0.0, -2.0)
const BULL_LINE := Vector3(1.9, 0.0, -3.3)   # side by side with the player, a step ahead on the RIGHT (founder round 3: 'Bull being side by side with Lil Blunt'); clear of every line of fire
const TARGET_Z := -9.3
const WALL_GLB := "res://src/episode2/assets/hideout/range_wall.glb"
const PLAQUE_GLB := "res://src/episode2/assets/hideout/range_plaque.glb"
const PLATE_RADIUS := 0.42
## Hit radius per target (same order): the logo plaques use PLATE_RADIUS; the taxidermy bear is big.
const TARGET_RADII := [0.42, 0.42, 0.42, 0.42, 0.9]
const BEAR_PROP := "res://src/episode2/assets/hideout/bear_standing.glb"
const BEAR_HEIGHT := 3.6

## Hit centres. The four logos are wall plaques; the bear stands on the floor in front of the wall.
const TARGET_SPOTS := [
	Vector3(-1.5, 2.65, -9.3),     # TitanX
	Vector3(0.1, 2.95, -9.3),      # Gold Mine (the hero medallion)
	Vector3(1.7, 2.65, -9.3),      # Diamonds
	Vector3(-0.6, 1.45, -9.3),     # Blaze Diamonds
	Vector3(-3.4, 1.9, -6.6),      # the BEAR: a LARGE taxidermy grizzly, close and to the left (chest = hit centre)
]
const TARGET_KINDS := ["titanx", "gold_mine", "diamonds", "blaze_diamonds", "bear"]
const LOGO_DIR := "res://src/episode2/assets/textures/logos/"
const RING_COLOR := Color(0.25, 1.0, 0.35)       # the glowing green ring from the reference


## Builds the range under `parent` (the facility's visuals node). Returns the contract dictionary.
static func build(parent: Node3D, timber: Material) -> Dictionary:
	var targets: Array = []
	var blockers: Array = []
	_build_wall_and_bench(parent, timber)
	for i in TARGET_SPOTS.size():
		var kind: String = str(TARGET_KINDS[i])
		var spot: Vector3 = TARGET_SPOTS[i]
		var node: Node3D = _build_taxidermy_bear(parent, spot) if kind == "bear" else _build_logo_plaque(parent, spot, kind)
		node.name = "Target_%d_%s" % [i, kind]
		targets.append(node)
	_build_damage(parent)
	return {"targets": targets, "blockers": blockers, "line": LINE}


## The timber backing wall behind the plaques, a firing bench with cartridge boxes at the line, lane markings,
## a sign and two lamps that light the wall so the logos read.
static func _build_wall_and_bench(parent: Node3D, timber: Material) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.8
	wood.emission_enabled = true
	wood.emission = Color(0.5, 0.33, 0.18)
	wood.emission_energy_multiplier = 0.10      # a touch of warmth so it never reads as a dead grey slab
	# Blender-built plank wall (tools/blender/build_range_props.py); the box + seams below are the fallback.
	var wall_scene: PackedScene = load(WALL_GLB) as PackedScene if ResourceLoader.exists(WALL_GLB) else null
	if wall_scene:
		var wall_model: Node3D = wall_scene.instantiate() as Node3D
		wall_model.name = "PlankWall"
		wall_model.position = Vector3(0.0, 0.0, TARGET_Z - 0.4)     # planks' front face = where the holes sit
		parent.add_child(wall_model)
	else:
		# backing wall panel
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(11.0, 6.4, 0.4)
		wall.mesh = wm
		wall.material_override = wood
		wall.position = Vector3(0.0, 3.0, TARGET_Z - 0.6)      # front face at TARGET_Z-0.4 (holes sit on it)
		parent.add_child(wall)
		# vertical plank seams
		var plank := StandardMaterial3D.new()
		plank.albedo_color = Color(0.21, 0.13, 0.08)
		plank.roughness = 0.9
		for px in range(-5, 6):
			var seam := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.08, 6.2, 0.06)
			seam.mesh = sm
			seam.material_override = plank
			seam.position = Vector3(float(px) * 1.0, 3.0, TARGET_Z - 0.14)
			parent.add_child(seam)
	# two wall lamps so the plaques are lit
	for lx in [-3.6, 3.6]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.86, 0.6)
		lamp.light_energy = 2.6
		lamp.omni_range = 7.0
		lamp.position = Vector3(lx, 3.9, TARGET_Z + 1.4)
		parent.add_child(lamp)
	# firing bench at the line
	var bench := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, 0.14, 0.7)          # a table TOP, not a solid slab
	bench.mesh = bm
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.5, 0.34, 0.2)
	top_mat.roughness = 0.75
	top_mat.emission_enabled = true
	top_mat.emission = Color(0.55, 0.37, 0.2)
	top_mat.emission_energy_multiplier = 0.12
	bench.material_override = top_mat
	bench.position = Vector3(LANE_X, 0.78, LINE.z - 0.7)
	parent.add_child(bench)
	for lx in [-0.85, 0.85]:
		for lz in [-0.3, 0.3]:
			var leg := MeshInstance3D.new()
			var lgm := BoxMesh.new()
			lgm.size = Vector3(0.12, 0.78, 0.12)
			leg.mesh = lgm
			leg.material_override = wood
			leg.position = Vector3(LANE_X + lx, 0.39, LINE.z - 0.7 + lz)
			parent.add_child(leg)
	# a small warm lamp over the bench so the viewmodel and the bench read
	var blamp := OmniLight3D.new()
	blamp.light_color = Color(1.0, 0.82, 0.55)
	blamp.light_energy = 2.0
	blamp.omni_range = 4.5
	blamp.position = Vector3(LANE_X, 2.2, LINE.z - 0.2)
	parent.add_child(blamp)
	# two cartridge boxes on the bench
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.52, 0.18)
	brass.metallic = 0.8
	brass.roughness = 0.35
	brass.emission_enabled = true
	brass.emission = Color(0.8, 0.55, 0.2)
	brass.emission_energy_multiplier = 0.12
	for bx in [-0.7, 0.7]:
		var box := MeshInstance3D.new()
		var bxm := BoxMesh.new()
		bxm.size = Vector3(0.44, 0.2, 0.3)
		box.mesh = bxm
		box.material_override = wood
		box.position = Vector3(LANE_X + bx, 0.95, LINE.z - 0.85)
		parent.add_child(box)
		# a few cartridges standing in the box
		for cx in [-0.1, 0.0, 0.1]:
			var shell := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.025
			cm.bottom_radius = 0.025
			cm.height = 0.18
			shell.mesh = cm
			shell.material_override = brass
			shell.position = Vector3(LANE_X + bx + cx, 1.1, LINE.z - 0.85)
			parent.add_child(shell)
	# lane floor markings down to the wall
	var lane_mat := StandardMaterial3D.new()
	lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lane_mat.albedo_color = Color(1.0, 0.62, 0.15, 1.0)
	var lane := MeshInstance3D.new()
	var lnm := BoxMesh.new()
	lnm.size = Vector3(0.12, 0.02, abs(LINE.z - TARGET_Z))
	lane.mesh = lnm
	lane.material_override = lane_mat
	lane.position = Vector3(LANE_X, 0.015, (LINE.z + TARGET_Z) * 0.5)
	parent.add_child(lane)
	var sign := Label3D.new()
	sign.text = "TARGET PRACTICE"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.modulate = Color(1.0, 0.75, 0.3)
	sign.outline_size = 14
	sign.position = Vector3(LANE_X, 5.1, TARGET_Z + 0.2)
	parent.add_child(sign)


## A protocol-logo plaque: a wooden board, the logo (unshaded so it always reads), a glowing green ring, and an
## empty holder the gameplay fills with bullet holes on a hit. Origin is at the hit centre (the logo).
static func _build_logo_plaque(parent: Node3D, centre: Vector3, kind: String) -> Node3D:
	var root := Node3D.new()
	root.position = centre
	parent.add_child(root)
	var r: float = PLATE_RADIUS
	# board + riveted iron rim: the Blender mount (tools/blender/build_range_props.py), else a plain box
	var mount_scene: PackedScene = load(PLAQUE_GLB) as PackedScene if ResourceLoader.exists(PLAQUE_GLB) else null
	if mount_scene:
		var mount: Node3D = mount_scene.instantiate() as Node3D
		mount.name = "Mount"
		mount.position = Vector3(0.0, 0.0, -0.01)
		root.add_child(mount)
	else:
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 2.5, r * 2.5, 0.08)
		board.mesh = bm
		var board_mat := StandardMaterial3D.new()
		board_mat.albedo_color = Color(0.26, 0.17, 0.10)
		board_mat.roughness = 0.85
		board.material_override = board_mat
		board.position = Vector3(0.0, 0.0, -0.06)
		root.add_child(board)
	# the logo quad, facing +Z (toward the player at the firing line)
	var logo := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(r * 1.9, r * 1.9)
	logo.mesh = qm
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tex_path: String = LOGO_DIR + "logo_%s.png" % kind
	if ResourceLoader.exists(tex_path):
		lm.albedo_texture = load(tex_path)
	else:
		lm.albedo_color = Color(0.9, 0.9, 0.9)
	logo.mesh.material = lm
	logo.position = Vector3(0.0, 0.0, 0.01)
	logo.name = "Logo"
	root.add_child(logo)
	# the glowing green ring
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 1.02
	tm.outer_radius = r * 1.14
	tm.rings = 32
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = RING_COLOR
	rm.emission_enabled = true
	rm.emission = RING_COLOR
	rm.emission_energy_multiplier = 1.6
	ring.material_override = rm
	ring.name = "Ring"
	ring.rotation.x = PI * 0.5      # TorusMesh lies flat by default; stand it up to face the player (+Z)
	ring.position = Vector3(0.0, 0.0, 0.02)
	root.add_child(ring)
	var holes := Node3D.new()
	holes.name = "Holes"
	root.add_child(holes)
	root.set_meta("kind", "logo")
	return root


## Standing targets glow; a hit logo dims its ring, tilts, and sprouts a bullet hole. A hit bear topples back.
static func set_target_state(target: Node3D, broken: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	var ring: MeshInstance3D = target.get_node_or_null("Ring") as MeshInstance3D
	if ring:
		var m: StandardMaterial3D = ring.material_override as StandardMaterial3D
		if m:
			m.emission_energy_multiplier = 0.0 if broken else 1.6
			m.albedo_color = Color(0.3, 0.3, 0.3) if broken else RING_COLOR
	# tilt the plaque and add one bullet hole
	target.rotation = Vector3(0.35 if broken else 0.0, 0.0, 0.0)
	var holes: Node3D = target.get_node_or_null("Holes")
	if broken and holes and holes.get_child_count() == 0:
		var hole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.05
		cm.height = 0.02
		hole.mesh = cm
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.albedo_color = Color(0.02, 0.02, 0.02)
		hole.material_override = hm
		hole.rotation.x = PI * 0.5
		hole.position = Vector3(0.08, 0.05, 0.03)
		holes.add_child(hole)


## A LARGE taxidermy grizzly (the same Meshy taxidermist bear as the hideout), reared up on a plinth in front of the
## wall (founder round 3: "The bear target must be a large actual bear from the taxidermist"). Origin = chest.
static func _build_taxidermy_bear(parent: Node3D, centre: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = centre
	parent.add_child(root)
	# plinth
	var plinth := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.9
	pm.bottom_radius = 1.0
	pm.height = 0.3
	plinth.mesh = pm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.22, 0.12)
	wood.roughness = 0.8
	plinth.material_override = wood
	plinth.position = Vector3(0.0, 0.15 - centre.y, 0.0)
	root.add_child(plinth)
	var packed: PackedScene = load(BEAR_PROP) as PackedScene if ResourceLoader.exists(BEAR_PROP) else null
	if packed:
		var bear: Node3D = packed.instantiate()
		bear.name = "Bear"
		var sc: float = BEAR_HEIGHT / 1.0                 # the Meshy GLB is a unit box (height 1.0, lowest y -0.5)
		bear.scale = Vector3.ONE * sc
		bear.rotation.y = 0.0                              # the GLB's front already faces +Z (the firing line)
		bear.position = Vector3(0.0, 0.3 + 0.5 * sc - centre.y, 0.0)
		root.add_child(bear)
	else:
		var box := MeshInstance3D.new()
		var bxm := BoxMesh.new()
		bxm.size = Vector3(1.4, 2.6, 1.0)
		box.mesh = bxm
		box.material_override = wood
		box.name = "Bear"
		root.add_child(box)
	# a green target ring on the bear's chest so it reads as a TARGET like the plaques
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.64
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = RING_COLOR
	rm.emission_enabled = true
	rm.emission = RING_COLOR
	rm.emission_energy_multiplier = 1.6
	ring.material_override = rm
	ring.name = "Ring"
	ring.rotation.x = PI * 0.5
	ring.position = Vector3(0.0, 0.0, 0.62)
	root.add_child(ring)
	root.set_meta("kind", "bear")
	return root


## The wall is already SHOT UP when you arrive (founder round 3: "It's too fresh. Look at how my reference is
## damaged with holes"): ~90 bullet holes with a pale splinter rim, clustered around the plaques and scattered over
## the planks, deterministic so every run looks the same. One MultiMesh draw call.
static func _build_damage(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261004
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.015, 0.01, 1.0), Color(0.02, 0.015, 0.01, 0.95), Color(0.85, 0.7, 0.45, 0.55), Color(0.85, 0.7, 0.45, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.34, 0.5, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	var spots: Array = []
	# clusters around every plaque (like the reference), then a loose scatter over the planks
	for sp in TARGET_SPOTS:
		for k in 9:
			var a: float = rng.randf() * TAU
			var r: float = rng.randf_range(0.2, 0.95)
			if sp.z > TARGET_Z + 0.5:
				continue      # the standing bear is not on the wall
			spots.append(Vector3(sp.x + cos(a) * r, sp.y + sin(a) * r, TARGET_Z - 0.4))
	for k in 70:
		spots.append(Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(0.6, 4.8), TARGET_Z - 0.4))
	mm.instance_count = spots.size()
	for i in spots.size():
		var sz: float = rng.randf_range(0.14, 0.34)
		var t := Transform3D(Basis.from_euler(Vector3(0.0, 0.0, rng.randf() * TAU)).scaled(Vector3(sz, sz, 1.0)), spots[i])
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WallDamage"
	mmi.multimesh = mm
	parent.add_child(mmi)
