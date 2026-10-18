class_name Ep2BowView
extends RefCounted
## Shared authored longbow: independent limb morph, string, nock, arrow, and hand frames.
const BOW := preload("res://src/episode2/assets/weapons/armory/bear_longbow.glb")
const ARROW := preload("res://src/episode2/assets/weapons/armory/bear_arrow.glb")

static func arrow() -> Node3D:
	return ARROW.instantiate()

static func make(player: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "RecoveredBearBow" if player else "Bow"
	root.add_child(BOW.instantiate())
	root.set_meta("limbs", root.find_children("FlexibleLimbs", "MeshInstance3D", true, false))
	var overlays: Array = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if str(node.name).begins_with("Tip binding") or str(node.name).begins_with("Horn nock"):
			overlays.append([node, node.position])
	root.set_meta("overlays", overlays)
	for label in ["Grip", "Nock"]:
		var mark := Marker3D.new()
		mark.name = label
		root.add_child(mark)
	var shaft := arrow()
	shaft.name = "NockedArrow"
	root.add_child(shaft)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c3b38e")
	material.roughness = 0.95
	for i in 2:
		var line := MeshInstance3D.new()
		line.name = "String%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0018
		mesh.bottom_radius = 0.0018
		mesh.radial_segments = 8
		line.mesh = mesh
		line.material_override = material
		root.add_child(line)
	if player:
		# Both authored hand meshes keep positive transforms; left glove is baked mirrored in Blender.
		for side in ["Left", "Right"]:
			var hand: Node3D = load("res://src/episode2/assets/weapons/armory/bow_%s_hand.glb" % side.to_lower()).instantiate()
			hand.name = side + "Hand"
			root.add_child(hand)
		root.set_meta("hip_offset", Vector3(-0.39, 0.04, -0.16))
		root.set_meta("hip_rotation", Vector3(0.0, PI + 0.06, -0.10))
		root.set_meta("ads_cam", Vector3(0.16, 0.02, -0.65))
	update(root, 0.0, true)
	return root

static func update(root: Node3D, draw: float, nocked: bool) -> void:
	var nock: Node3D = root.get_node("Nock")
	nock.position = Vector3(0.0, 0.0, -0.44 - 0.23 * draw)
	var shaft: Node3D = root.get_node("NockedArrow")
	shaft.visible = nocked
	shaft.position = nock.position
	for mesh in root.get_meta("limbs"):
		var mi := mesh as MeshInstance3D
		if mi.get_blend_shape_count() > 0:
			mi.set_blend_shape_value(0, draw)
	for pair in root.get_meta("overlays"):
		var original: Vector3 = pair[1]
		(pair[0] as Node3D).position = original - Vector3(0, 0, 0.045 * pow(absf(original.y) / 0.75, 2.0) * draw)
	for i in 2:
		var end := Vector3(0.0, 0.75 if i == 0 else -0.75, -0.44 - 0.045 * draw)
		var line: MeshInstance3D = root.get_node("String%d" % i)
		(line.mesh as CylinderMesh).height = end.distance_to(nock.position)
		line.position = (end + nock.position) * 0.5
		line.basis = Basis.looking_at(end - nock.position, Vector3.RIGHT) * Basis(Vector3.RIGHT, PI * 0.5)
	var hand: Node3D = root.get_node_or_null("RightHand")
	if hand != null:
		hand.position = nock.position
