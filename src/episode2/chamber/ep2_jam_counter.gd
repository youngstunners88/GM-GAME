extends Node3D
## THE GENERAL STORE'S JAM (founder 2026-11-25, PROMPT_EPISODE2_STOCKPILE_CAD_WHEELBARROW_RIG_STOREFRONT_STATS_2026-11-25 section 7): the
## storefront woman behind Bldg_A's counter sells one good, jars of jam. A little stepped pine rack on the counter's free end (between
## the wrapping-paper roll and the candy jars of the kit's Gen_Counter, tools/ep2_blender/build_town_kit.py) holds labelled jars:
## blackberry and peach preserves, gingham cloth tied over each lid, a paper label round each, and a painted card "HOMEMADE JAM".
## Built from primitives here (shared meshes and materials, no pack bytes). Untyped (no class_name): gold_town.gd preloads it.
const PIECE := "Bldg_A"
const COUNTER := Vector3(1.2, 0.0, -4.0)          # Gen_Counter's spot in the shop (Ep2GoldTown.WALKIN_SHOPS / ROOM_DETAIL)
const TOP_Y := 1.04                                # the counter's trim top (build_town_kit.py: box 1.01 + 0.03)
const RACK_AT := Vector3(-1.02, 0.0, 0.02)         # counter local: its free end, clear of the paper roll (x < -1.34) and the jars (x > -0.69)
const JAR_R := 0.045
const JAR_H := 0.11
const FLAVOURS := [["BLACKBERRY", Color(0.30, 0.05, 0.14)], ["PEACH", Color(0.93, 0.52, 0.18)]]

var jars: int = 0                                  # evidence for tests


## The rack and its jars on Bldg_A's counter (null when the shop is not in the layout). `parent` sits at the town's origin.
static func build(parent: Node3D) -> Node3D:
	var e: Array = Ep2GoldTown.entry(PIECE)
	if e.is_empty():
		return null
	var n = (load("res://src/episode2/chamber/ep2_jam_counter.gd") as GDScript).new()
	n.name = "JamCounter"
	n.transform = Ep2GoldTown.building_xform(e) * Transform3D(Basis(), COUNTER + Vector3(RACK_AT.x, TOP_Y, RACK_AT.z))
	parent.add_child(n)
	n._dress()
	return n


func _mat(c: Color, rough: float = 0.8, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _box(size: Vector3, at: Vector3, mat: Material, label: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = label
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	add_child(mi)


func _dress() -> void:
	var pine := _mat(Color(0.56, 0.40, 0.25), 0.9)
	# the stepped rack: a low front step and a raised back step (0.5 m wide, 0.30 deep)
	_box(Vector3(0.52, 0.03, 0.30), Vector3(0.0, 0.015, 0.0), pine, "RackBase")
	_box(Vector3(0.52, 0.10, 0.14), Vector3(0.0, 0.08, -0.08), pine, "RackStep")
	_box(Vector3(0.03, 0.16, 0.30), Vector3(-0.245, 0.08, 0.0), pine, "RackSideL")
	_box(Vector3(0.03, 0.16, 0.30), Vector3(0.245, 0.08, 0.0), pine, "RackSideR")
	# shared jar parts
	var glass := CylinderMesh.new()
	glass.top_radius = JAR_R
	glass.bottom_radius = JAR_R
	glass.height = JAR_H
	glass.radial_segments = 12
	glass.rings = 1
	var fill := CylinderMesh.new()
	fill.top_radius = JAR_R - 0.006
	fill.bottom_radius = JAR_R - 0.006
	fill.height = JAR_H - 0.02
	fill.radial_segments = 10
	fill.rings = 1
	var cloth := CylinderMesh.new()                 # gingham over the lid, a little proud of the rim
	cloth.top_radius = JAR_R + 0.004
	cloth.bottom_radius = JAR_R + 0.012
	cloth.height = 0.025
	cloth.radial_segments = 12
	cloth.rings = 1
	var band := CylinderMesh.new()                  # the paper label round the jar's middle
	band.top_radius = JAR_R + 0.002
	band.bottom_radius = JAR_R + 0.002
	band.height = 0.045
	band.radial_segments = 12
	band.rings = 1
	var glass_m := _mat(Color(0.85, 0.90, 0.88), 0.12, 0.35)
	var paper_m := _mat(Color(0.93, 0.88, 0.74), 0.9)
	var cloth_m := [_mat(Color(0.72, 0.12, 0.12), 0.95), _mat(Color(0.86, 0.80, 0.70), 0.95)]
	var fill_m := [_mat(FLAVOURS[0][1], 0.35), _mat(FLAVOURS[1][1], 0.35)]
	# back step: four jars, front step: four, alternating blackberry / peach
	var rows := [[-0.04 - 0.08, 0.13], [0.07, 0.03]]   # [z, base y]
	var k: int = 0
	for row in rows:
		for i in 4:
			var x: float = -0.18 + i * 0.12
			var f: int = (i + k) % 2
			var root := Node3D.new()
			root.name = "Jar_%s_%d" % [FLAVOURS[f][0], jars]
			root.position = Vector3(x, float(row[1]) + JAR_H * 0.5, float(row[0]))
			add_child(root)
			for part in [[glass, glass_m, 0.0, "Glass"], [fill, fill_m[f], -0.005, "Jam"], [band, paper_m, -0.008, "Label"],
					[cloth, cloth_m[f], JAR_H * 0.5 + 0.01, "Cloth"]]:
				var mi := MeshInstance3D.new()
				mi.name = str(part[3])
				mi.mesh = part[0]
				mi.material_override = part[1]
				mi.position.y = float(part[2])
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mi)
			jars += 1
		k += 1
	# two more on the counter in front of the rack, for whoever is at the counter
	for i in 2:
		var root := Node3D.new()
		root.name = "Jar_%s_%d" % [FLAVOURS[i][0], jars]
		root.position = Vector3(0.36 + i * 0.11, JAR_H * 0.5, 0.18)
		add_child(root)
		for part in [[glass, glass_m, 0.0, "Glass"], [fill, fill_m[i], -0.005, "Jam"], [band, paper_m, -0.008, "Label"],
				[cloth, cloth_m[i], JAR_H * 0.5 + 0.01, "Cloth"]]:
			var mi := MeshInstance3D.new()
			mi.name = str(part[3])
			mi.mesh = part[0]
			mi.material_override = part[1]
			mi.position.y = float(part[2])
			root.add_child(mi)
		jars += 1
	# the card behind the back row on a pine stand, its words (on the face toward the customer, +z) above the jar tops
	_box(Vector3(0.50, 0.22, 0.02), Vector3(0.0, 0.11, -0.175), pine, "CardStand")
	Ep2Signpost.board(self, Vector3(0.50, 0.26, 0.012), Vector3(0.0, 0.35, -0.175), paper_m, "HOMEMADE JAM", Color(0.42, 0.06, 0.12), false)
