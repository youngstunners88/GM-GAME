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
const BULL_LINE := Vector3(2.5, 0.0, -2.2)   # beside the player at the firing line (a coach), not downrange where he hides the targets
const TARGET_Z := -9.3
const PLATE_RADIUS := 0.42

## Hit centres. The four logos are wall plaques; the bear stands on the floor in front of the wall.
const TARGET_SPOTS := [
	Vector3(-3.2, 2.5, -9.3),      # TitanX (top left)
	Vector3(-1.05, 2.85, -9.3),    # Gold Mine (top middle, the hero medallion)
	Vector3(1.05, 2.85, -9.3),     # Diamonds (top right)
	Vector3(-2.2, 1.45, -9.3),     # Blaze Diamonds (lower left)
	Vector3(2.8, 1.5, -9.3),       # the BEAR archer (wall poster, lower right)
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
		var node: Node3D = _build_logo_plaque(parent, spot, kind)
		node.name = "Target_%d_%s" % [i, kind]
		targets.append(node)
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
	# backing wall panel
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(11.0, 6.4, 0.4)
	wall.mesh = wm
	wall.material_override = wood
	wall.position = Vector3(0.0, 3.0, TARGET_Z - 0.35)
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
	bm.size = Vector3(2.6, 0.18, 0.75)          # a table TOP, not a solid slab
	bench.mesh = bm
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.5, 0.34, 0.2)
	top_mat.roughness = 0.75
	top_mat.emission_enabled = true
	top_mat.emission = Color(0.55, 0.37, 0.2)
	top_mat.emission_energy_multiplier = 0.12
	bench.material_override = top_mat
	bench.position = Vector3(LANE_X, 0.9, LINE.z - 0.55)
	parent.add_child(bench)
	for lx in [-1.15, 1.15]:
		for lz in [-0.3, 0.3]:
			var leg := MeshInstance3D.new()
			var lgm := BoxMesh.new()
			lgm.size = Vector3(0.12, 0.9, 0.12)
			leg.mesh = lgm
			leg.material_override = wood
			leg.position = Vector3(LANE_X + lx, 0.45, LINE.z - 0.55 + lz)
			parent.add_child(leg)
	# a small warm lamp over the bench so the viewmodel and the bench read
	var blamp := OmniLight3D.new()
	blamp.light_color = Color(1.0, 0.82, 0.55)
	blamp.light_energy = 2.0
	blamp.omni_range = 4.5
	blamp.position = Vector3(LANE_X, 2.2, LINE.z - 0.2)
	parent.add_child(blamp)
	# a sandbag rest + two cartridge boxes on the bench
	var sandbag := StandardMaterial3D.new()
	sandbag.albedo_color = Color(0.45, 0.39, 0.26)
	sandbag.roughness = 1.0
	var sb := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(1.4, 0.3, 0.5)
	sb.mesh = sbm
	sb.material_override = sandbag
	sb.position = Vector3(LANE_X, 1.14, LINE.z - 0.55)
	parent.add_child(sb)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.52, 0.18)
	brass.metallic = 0.8
	brass.roughness = 0.35
	brass.emission_enabled = true
	brass.emission = Color(0.8, 0.55, 0.2)
	brass.emission_energy_multiplier = 0.12
	for bx in [-1.1, 1.1]:
		var box := MeshInstance3D.new()
		var bxm := BoxMesh.new()
		bxm.size = Vector3(0.44, 0.2, 0.3)
		box.mesh = bxm
		box.material_override = wood
		box.position = Vector3(LANE_X + bx, 1.1, LINE.z - 0.7)
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
			shell.position = Vector3(LANE_X + bx + cx, 1.26, LINE.z - 0.7)
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
	# board behind the logo
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
