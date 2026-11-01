class_name Ep2LakeGlimpse
extends RefCounted
## LOGAN'S LAKE ON THE HORIZON from the woods (founder 2026-11-01 evening, "Guns Buff" §6B: "the same needs to occur regarding Logan's
## Lake if the player looks to the side while exiting the forest. In the far distance we should have some semblance of the Lake being
## there"). The real lake is its own chamber at the end of the lake road; the woods draw a far stand-in at the SAME world spot (the
## end of Ep2LakeRoad, in the shared town/woods survey): a green basin, still water catching the sky, a dark ring of pines and Logan's
## camp smoke - tall enough to rise over the forest edge, so "someone lives out there" reads from the forest exit. Placement only, no
## fog: nothing here hides a mistake, it fills the empty spot where the lake really is.

## The lake road's last surveyed point in world space (Ep2LakeRoad.ORIGIN + its last POINT): the lake opens just past it.
static func lake_world() -> Vector3:
	var last: Vector2 = Ep2LakeRoad.POINTS[Ep2LakeRoad.POINTS.size() - 1]
	return Ep2LakeRoad.ORIGIN + Vector3(last.x, 0.0, last.y)


static func build(parent: Node3D, trunk: Mesh = null, crown: Mesh = null, bark: Material = null, leaves: Material = null) -> Node3D:
	var root := Node3D.new()
	root.name = "LogansLakeGlimpse"
	parent.add_child(root)
	root.position = lake_world() + Vector3(-6.0, 0.0, -24.0)
	# the green basin the lake sits in (the desert stops here: the road's last stretch is grassland)
	var basin := MeshInstance3D.new()
	basin.name = "GlimpseBasin"
	var disc := CylinderMesh.new()
	disc.top_radius = 125.0
	disc.bottom_radius = 125.0
	disc.height = 0.04
	disc.radial_segments = 48
	basin.mesh = disc
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.34, 0.42, 0.2)
	grass.roughness = 1.0
	basin.material_override = grass
	basin.position = Vector3(0.0, -0.035, 0.0)
	basin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(basin)
	# still water: dark, glossy, catching the sky (the lake chamber's basin is ~54 x 45 m)
	var water := MeshInstance3D.new()
	water.name = "GlimpseWater"
	var wd := CylinderMesh.new()
	wd.top_radius = 1.0
	wd.bottom_radius = 1.0
	wd.height = 0.02
	wd.radial_segments = 48
	water.mesh = wd
	water.scale = Vector3(54.0, 1.0, 45.0)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.12, 0.27, 0.32)
	wm.metallic = 0.55
	wm.roughness = 0.06
	wm.metallic_specular = 0.9
	water.material_override = wm
	water.position = Vector3(0.0, 0.03, 0.0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	# the dark ring of pines round the basin (the woods' own trunk + crown when given, else simple dark cones)
	var rng := RandomNumberGenerator.new()
	rng.seed = 856
	var xforms: Array = []
	for i in 64:
		var a: float = TAU * float(i) / 64.0 + rng.randf_range(-0.04, 0.04)
		var r: float = rng.randf_range(66.0, 112.0)
		# leave the road's mouth (toward the town, -x/+z side) open so the water shows through the gap
		if absf(wrapf(a - 2.3, -PI, PI)) < 0.45:
			continue
		var s: float = rng.randf_range(0.8, 1.25)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * s), Vector3(cos(a) * r, 0.0, sin(a) * r * 0.9)))
	if trunk != null and crown != null:
		_multi(root, trunk, xforms, bark, "GlimpseTrunks")
		_multi(root, crown, xforms, leaves, "GlimpseCrowns")
	else:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 3.2
		cone.height = 16.0
		var pine := StandardMaterial3D.new()
		pine.albedo_color = Color(0.11, 0.2, 0.12)
		var lifted: Array = []
		for x in xforms:
			lifted.append((x as Transform3D).translated_local(Vector3(0.0, 8.0, 0.0)))
		_multi(root, cone, lifted, pine, "GlimpsePines")
	# Logan's camp smoke: the same drifting column the lake draws, scaled to read over the forest edge from ~330 m
	var smoke := MeshInstance3D.new()
	smoke.name = "GlimpseCampSmoke"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	smoke.mesh = quad
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/episode2/art/camp_smoke.gdshader")
	sm.set_shader_parameter("tint", Color(0.36, 0.37, 0.4, 0.82))      # wood smoke, darker than the pale desert sky it rises into
	smoke.material_override = sm
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.scale = Vector3(18.0, 64.0, 1.0)
	smoke.position = Vector3(-34.0, 32.0, 18.0)
	root.add_child(smoke)
	return root


static func _multi(parent: Node3D, mesh: Mesh, xforms: Array, mat: Material, label: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = label
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
