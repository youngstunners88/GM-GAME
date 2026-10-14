class_name Ep2RemingtonView
extends RefCounted
## Dedicated FPS prop, built against the founder's Stage 3 golden revolver reference.
## Local +Z is the muzzle, matching the Winchester viewmodel frame. No asset service is required.
static func make() -> Node3D:
	var root := Node3D.new()
	root.name = "GoldenRemington1875"
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.83, 0.48, 0.10)
	gold.metallic = 0.8
	gold.roughness = 0.26
	var dark := Ep2ViewHands._mat(Color(0.10, 0.055, 0.022), 0.65, 0.0)
	var steel := Ep2ViewHands._mat(Color(0.08, 0.065, 0.045), 0.35, 0.0)
	# Long barrel, Remington under-barrel web/ejector, solid top strap and six chambers.
	_cyl(root, "Barrel", 0.026, 0.30, Vector3(0, 0.038, 0.19), gold)
	_cyl(root, "Bore", 0.017, 0.004, Vector3(0, 0.038, 0.343), steel)
	_cyl(root, "EjectorRod", 0.010, 0.25, Vector3(0.025, 0.002, 0.18), gold)
	_box(root, "BarrelWeb", Vector3(0.016, 0.034, 0.25), Vector3(0, 0.005, 0.18), gold)
	_cyl(root, "Cylinder", 0.049, 0.085, Vector3(0, 0.024, 0.0), gold)
	for i in 6:
		var a: float = float(i) * TAU / 6.0
		_cyl(root, "Chamber%d" % i, 0.013, 0.003, Vector3(sin(a) * 0.032, 0.024 + cos(a) * 0.032, 0.044), steel)
		_cyl(root, "Flute%d" % i, 0.008, 0.060, Vector3(sin(a) * 0.047, 0.024 + cos(a) * 0.047, 0), dark)
	_box(root, "TopStrap", Vector3(0.041, 0.018, 0.12), Vector3(0, 0.066, 0), gold)
	_box(root, "Frame", Vector3(0.044, 0.026, 0.13), Vector3(0, -0.030, -0.008), gold)
	_box(root, "Backstrap", Vector3(0.040, 0.15, 0.028), Vector3(0, -0.066, -0.077), gold)
	var grip := _box(root, "WalnutGrip", Vector3(0.049, 0.118, 0.065), Vector3(0, -0.087, -0.083), dark)
	grip.rotation.x = -0.20
	_box(root, "Hammer", Vector3(0.016, 0.032, 0.026), Vector3(0, 0.066, -0.079), gold)
	_box(root, "FrontSight", Vector3(0.008, 0.014, 0.024), Vector3(0, 0.073, 0.29), gold)
	# Rear notch leaves the centre of the sight picture open.
	for x in [-0.011, 0.011]:
		_box(root, "RearSight", Vector3(0.006, 0.010, 0.014), Vector3(x, 0.080, -0.045), steel)
	var guard := TorusMesh.new()
	guard.inner_radius = 0.034
	guard.outer_radius = 0.042
	var ring := _mesh(root, "TriggerGuard", guard, Vector3(0, -0.067, -0.017), gold)
	ring.rotation.z = PI * 0.5
	ring.scale = Vector3(1, 1, 0.8)
	_box(root, "Trigger", Vector3(0.009, 0.030, 0.010), Vector3(0, -0.055, -0.026), gold)
	# Small gold medallions on the wood, matching the founder's brass accents.
	for side in [-1.0, 1.0]:
		var badge := _cyl(root, "GripMedallion", 0.013, 0.003, Vector3(side * 0.026, -0.082, -0.086), gold)
		badge.rotation.y = PI * 0.5
	Ep2ViewHands._arm(root, "Right", Vector3(0.035, -0.094, -0.089), Vector3(-0.55, -0.28, -0.72),
		Ep2ViewHands._mat(Color(0.21, 0.49, 0.10), 0.8, 0.0), Ep2ViewHands._mat(Color(0.10, 0.29, 0.04), 0.8, 0.0),
		Ep2ViewHands._mat(Color(0.23, 0.12, 0.045), 0.7, 0.0), gold, false)
	root.set_meta("arm_pivot", Vector3(-0.18, -0.22, -0.37))
	root.set_meta("ads_cam", Vector3(0, 0.066, -0.37))
	return root


static func _mesh(root: Node3D, label: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	root.add_child(node)
	return node


static func _box(root: Node3D, label: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(root, label, mesh, pos, mat)


static func _cyl(root: Node3D, label: String, radius: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 32
	var node := _mesh(root, label, mesh, pos, mat)
	node.rotation.x = PI * 0.5
	return node
