class_name Ep2LakeLandscape
extends RefCounted
## Lake-only authored forest, shore and reflection data. Existing world assets
## outside this chamber and the founder Logan model are never changed here.
const KIT := "res://src/episode2/extras/lake/landscape/shore_kit.glb"
const FLOOR := "res://src/episode2/assets/woods/tex_woods_floor.jpg"
const BARK := "res://src/episode2/assets/woods/tex_woods_bark.jpg"
const BARK_N := "res://src/episode2/assets/woods/tex_woods_bark_n.png"
const BRANCH := "res://src/episode2/assets/woods/tex_woods_branch.png"
var root: Node3D
var flora: Node3D
var upgraded: bool = false
var water_material: ShaderMaterial
var trees: Array[Vector4] = []
var tree_instances: int = 0
var _plants_seeded: bool = false
var _dock: Node3D
var _dock_dressed: bool = false
var _rocks_dressed: bool = false

func build_ground(parent: Node3D) -> void:
	root = parent
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in 150:
		for iz in 155:
			var x: float = -130.0 + ix * 2.0
			var z: float = -100.0 + iz * 2.0
			for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var px: float = x + uv.x * 2.0
				var pz: float = z + uv.y * 2.0
				st.set_uv(Vector2(px, pz) * 0.20)
				st.add_vertex(Vector3(px, Ep2LakeLandform.terrain_height(px, pz) - 0.012, pz))
	st.index()
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "ShoreAndMountain"
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://src/episode2/art/lake_ground.gdshader")
	m.set_shader_parameter("forest_floor", load(FLOOR))
	m.set_shader_parameter("gravel_tex", load("res://src/episode2/assets/town/tex_desert.jpg"))
	m.set_shader_parameter("gravel_normal", load(BARK_N))
	mi.material_override = m
	root.add_child(mi)

func build_water(sun: DirectionalLight3D) -> void:
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://src/episode2/art/lake_water.gdshader")
	water_material.set_shader_parameter("branch_tex", load(BRANCH))
	water_material.set_shader_parameter("sun_direction", sun.global_transform.basis.z.normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 160:
		var a: float = float(i) / 160.0 * TAU
		var b: float = float(i + 1) / 160.0 * TAU
		for p in [Vector2.ZERO, Vector2(cos(a), sin(a)) * Ep2LakeLandform.rim_radius(a) * 1.11, Vector2(cos(b), sin(b)) * Ep2LakeLandform.rim_radius(b) * 1.11]:
			st.set_normal(Vector3.UP)
			st.set_uv(p * 0.5 + Vector2(0.5, 0.5))
			st.add_vertex(Vector3(24 + p.x * 27, -0.18, 20 + p.y * 33))
	var lake := MeshInstance3D.new()
	lake.name = "StillWater"
	lake.mesh = st.commit()
	lake.material_override = water_material
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lake)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 51:
		for uv in [Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 0), Vector2(1, 1), Vector2(-1, 1)]:
			var z: float = 44.0 + (float(i) + uv.y) * 2.0
			var x: float = Ep2LakeLandform.flow_center(z) + uv.x * (Ep2LakeLandform.flow_width(z) + 2.5)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2((uv.x + 1.0) * 0.5, z / 100.0))
			st.add_vertex(Vector3(x, -0.175, z))
	var river := MeshInstance3D.new()
	river.name = "Day88Outflow"
	river.mesh = st.commit()
	river.material_override = water_material
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(river)

func _foliage(texture_path: String, height: float, sway: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/episode2/art/lake_foliage.gdshader")
	m.set_shader_parameter("albedo_tex", load(texture_path))
	m.set_shader_parameter("bend_height", height)
	m.set_shader_parameter("sway", sway)
	return m

func _bark() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(BARK)
	m.albedo_color = Color(0.78, 0.74, 0.65)
	m.normal_enabled = true
	m.normal_texture = load(BARK_N)
	m.normal_scale = 0.7
	m.roughness = 0.94
	return m

func _instances(parent: Node3D, mesh: Mesh, transforms: Array, material: Material, name: String, tones: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, tones[i] if i < tones.size() else Color.WHITE)
	var mi := MultiMeshInstance3D.new()
	mi.name = name
	mi.multimesh = mm
	mi.material_override = material
	parent.add_child(mi)
	return mi

func build_vegetation(parent: Node3D) -> void:
	root = parent
	if flora != null:
		flora.free()
	flora = Node3D.new()
	flora.name = "LakeWoodland"
	root.add_child(flora)
	upgraded = Ep2Extras.has(KIT)
	var kit: Node3D = (load(KIT if upgraded else "res://src/episode2/assets/woods/forest_kit.glb") as PackedScene).instantiate() as Node3D
	var rng := RandomNumberGenerator.new()
	rng.seed = 882727
	var layouts: Array = [[], [], []]
	var tones: Array = [[], [], []]
	trees.clear()
	# Unequal groves with an open, readable water/dock view; keep the whole
	# walked corridor and the narrow outflow free of trunks.
	for i in 175:
		var a: float = rng.randf_range(-PI, PI)
		var radius: float = rng.randf_range(1.17, 1.58) if i < 125 else rng.randf_range(1.60, 2.65)
		var x: float = 24.0 + cos(a) * 29.0 * radius
		var z: float = 20.0 + sin(a) * 36.0 * radius
		if i < 6:
			x = -17.0 - float(i % 2) * 3.0
			z = -8.0 + float(i) * 13.0
		if (x > -16.0 and x < -1.5) or (z > 45.0 and absf(x - Ep2LakeLandform.flow_center(z)) < 11.0): continue
		if radius < 1.45 and sin(a * 5.0 + 0.6) > 0.6 and i % 3 != 0: continue
		var kind: int = i % 3
		var h: float = rng.randf_range(9.0, 19.0) if kind != 2 else rng.randf_range(4.5, 8.5)
		var y: float = Ep2LakeLandform.terrain_height(x, z)
		var authored_h: float = [12.0, 14.0, 7.0][kind]
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * h / authored_h), Vector3(x, y - 0.04, z))
		layouts[kind].append(xf)
		var shade: float = rng.randf_range(0.82, 1.08)
		tones[kind].append(Color(shade, shade, shade * 0.96))
		if radius < 1.50 and trees.size() < 16: trees.append(Vector4(x, z, y + h, h * 0.23))
	tree_instances = 0
	for kind in 3:
		var prefix: String = ["FirA", "FirB", "YoungFir"][kind]
		if upgraded:
			for piece in ["Wood", "Needles"]:
				var template := kit.find_child(prefix + "_" + piece, true, false) as MeshInstance3D
				_instances(flora, template.mesh, layouts[kind], _bark() if piece == "Wood" else _foliage(BRANCH, [12.0, 14.0, 7.0][kind], 0.10), prefix + "_" + piece, tones[kind])
		else:
			# Existing art remains as a complete download fallback.
			for piece in ["Trunk", "Crown"]:
				var template := kit.find_child(piece, true, false) as MeshInstance3D
				var fallback: Array = []
				for tr in layouts[kind]:
					var xf: Transform3D = tr
					xf.basis = xf.basis.scaled(Vector3(0.3, [12.0, 14.0, 7.0][kind], 0.3) if piece == "Trunk" else Vector3.ONE * [12.0, 14.0, 7.0][kind] / 40.0)
					fallback.append(xf)
				_instances(flora, template.mesh, fallback, _bark() if piece == "Trunk" else _foliage(BRANCH, 40.0, 0.16), prefix + "_" + piece, tones[kind])
		tree_instances += layouts[kind].size()
	if water_material != null:
		var reflections := PackedVector4Array()
		for tr in trees: reflections.append(tr)
		while reflections.size() < 16: reflections.append(Vector4.ZERO)
		water_material.set_shader_parameter("trees", reflections)
		water_material.set_shader_parameter("tree_count", trees.size())
	if upgraded: _understory(kit, rng)
	kit.free()
	if not _plants_seeded:
		_shore_rocks_and_logs(rng)
		_plants_seeded = true
		if Ep2Pbr.available(): _dress_rocks()

func refresh_streamed() -> void:
	if not upgraded and Ep2Extras.has(KIT): build_vegetation(root)
	if Ep2Pbr.available():
		if _dock != null and not _dock_dressed: _dress_dock()
		if not _rocks_dressed: _dress_rocks()

func register_dock(dock: Node3D) -> void:
	_dock = dock
	if Ep2Pbr.available(): _dress_dock()

func _dress_dock() -> void:
	for node in _dock.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if base != null and base.resource_name.begins_with("Aged cedar"):
				mi.set_surface_override_material(i, Ep2Pbr.make("planks_weathered", Color(.48, .35, .23).srgb_to_linear(), .90))
	_dock_dressed = true

func _dress_rocks() -> void:
	if root == null: return
	for node in root.find_children("BankGranite_*", "Node3D", true, false):
		for child in node.find_children("*", "MeshInstance3D", true, false):
			var stone := StandardMaterial3D.new()
			stone.albedo_texture = load("res://src/episode2/extras/pbr/stone_rustic/albedo.jpg")
			stone.albedo_color = Color(.50, .53, .48)
			stone.normal_enabled = true
			stone.normal_texture = load("res://src/episode2/extras/pbr/stone_rustic/normal.jpg")
			stone.normal_scale = .4
			stone.roughness = .94
			child.material_override = stone
	_rocks_dressed = true

func _understory(kit: Node3D, rng: RandomNumberGenerator) -> void:
	for variant in 2:
		var transforms: Array = []
		for i in 38:
			var a: float = rng.randf_range(-PI, PI)
			var r: float = rng.randf_range(0.99, 1.075) * Ep2LakeLandform.rim_radius(a)
			var x: float = 24 + cos(a) * 27 * r
			var z: float = 20 + sin(a) * 33 * r
			if x < -2.5 or (z > 45 and absf(x - Ep2LakeLandform.flow_center(z)) < 8) or (x > -5 and x < 6 and z > 7 and z < 17): continue
			var s: float = rng.randf_range(.65, 1.2)
			transforms.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * s), Vector3(x, Ep2LakeLandform.terrain_height(x, z) - 0.03, z)))
		for part in ["Blade", "Seed"]:
			var template := kit.find_child("Rush" + str(variant) + "_" + part, true, false) as MeshInstance3D
			_instances(flora, template.mesh, transforms, null, "BankRush" + str(variant) + part)
	var fern_kit: Node3D = (load("res://src/episode2/assets/woods/forest_kit.glb") as PackedScene).instantiate() as Node3D
	var fern := fern_kit.find_child("Fern", true, false) as MeshInstance3D
	var transforms: Array = []
	for i in 360:
		var x: float = rng.randf_range(-29.0, 63.0) if i > 110 else rng.randf_range(-21.0, -14.2)
		var z: float = rng.randf_range(-22.0, 73.0)
		if i >= 280:
			x = rng.randf_range(-6.0, -3.0)
			if absf(z - 8.0) < 3 or absf(z - 17.0) < 3: continue
		elif Ep2LakeLandform.lake_radius(x, z) < 1.11 or (x > -14 and x < -2.5): continue
		var s: float = rng.randf_range(.55, 1.25)
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * s), Vector3(x, Ep2LakeLandform.terrain_height(x, z), z)))
	_instances(flora, fern.mesh, transforms, _foliage("res://src/episode2/assets/woods/tex_woods_fern.png", 1.0, .045), "ShoreFerns")
	fern_kit.free()

func _shore_rocks_and_logs(rng: RandomNumberGenerator) -> void:
	var packed := load("res://src/episode2/assets/woods/woods_rock.glb") as PackedScene
	for i in 55:
		var a: float = rng.randf_range(-PI, PI)
		var r: float = rng.randf_range(1.01, 1.17) * Ep2LakeLandform.rim_radius(a)
		var x: float = 24 + cos(a) * 27 * r
		var z: float = 20 + sin(a) * 33 * r
		if x < -2.5 or (z > 44 and absf(x - Ep2LakeLandform.flow_center(z)) < 10) or (x > -5 and x < 6 and z > 7 and z < 17): continue
		var rock := packed.instantiate() as Node3D
		rock.name = "BankGranite_" + str(i)
		rock.position = Vector3(x, Ep2LakeLandform.terrain_height(x, z) - .22, z)
		rock.rotation.y = rng.randf_range(-PI, PI)
		var s: float = rng.randf_range(.22, 1.25)
		rock.scale = Vector3(s, s * rng.randf_range(.6, 1.0), s)
		root.add_child(rock)
		for node in rock.find_children("*", "MeshInstance3D", true, false):
			var stone := StandardMaterial3D.new()
			stone.albedo_texture = load(FLOOR)
			stone.albedo_color = Color(0.45, 0.47, 0.40)
			stone.roughness = 0.93
			node.material_override = stone
	if Ep2Extras.has(KIT):
		var kit: Node3D = (load(KIT) as PackedScene).instantiate() as Node3D
		var template := kit.find_child("Driftwood", true, false) as MeshInstance3D
		for pos in [Vector2(-1.0, -2.0), Vector2(7.0, -11.0), Vector2(51.0, 31.0), Vector2(44.0, 49.0)]:
			var log_piece := MeshInstance3D.new()
			log_piece.name = "WeatheredShoreLog"
			log_piece.mesh = template.mesh
			log_piece.material_override = _bark()
			log_piece.position = Vector3(pos.x, Ep2LakeLandform.terrain_height(pos.x, pos.y), pos.y)
			log_piece.rotation.y = rng.randf_range(-PI, PI)
			root.add_child(log_piece)
		kit.free()
