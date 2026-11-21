extends RefCounted
## Streamed with the official poster: keeps optional range art out of the near-full core pack.
func build(parent: Node3D, world_pos: Vector3, face_toward: Vector3, size: Vector2, tex: Texture2D) -> Dictionary:
	var n := Node3D.new()
	n.name = "JackHammerBillboard"
	parent.add_child(n)
	n.position = world_pos - parent.position
	var toward: Vector3 = face_toward - world_pos
	n.rotation.y = atan2(toward.x, toward.z)
	var carpentry: RefCounted = load(Ep2TownPosters.DIR + "town_posters_builder.gd").new()
	var wood := Ep2GoldTown._tex_mat("", Color(0.46, 0.31, 0.17), 0.95, Ep2GoldTown.TIMBER_TEX)
	for x in [-size.x * 0.5, size.x * 0.5]:
		carpentry._box(n, Vector3(0.16, world_pos.y + size.y * 0.5 + 0.16, 0.18), Vector3(x, -(world_pos.y - size.y * 0.5) * 0.5, -0.08), wood)
	for y in [-size.y * 0.5, 0.0, size.y * 0.5]:
		carpentry._box(n, Vector3(size.x + 0.24, 0.14, 0.10), Vector3(0, y, -0.06), wood)
	var canvas := MeshInstance3D.new()
	canvas.name = "OfficialWantedCanvas"
	var q := QuadMesh.new()
	q.size = size
	canvas.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/episode2/art/ep2_wanted_canvas.gdshader")
	mat.set_shader_parameter("poster", tex)
	mat.set_shader_parameter("damage", 0.0)
	canvas.material_override = mat
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(canvas)
	var holes: Array[MeshInstance3D] = []
	var hole_mat := ShaderMaterial.new()
	hole_mat.shader = load("res://src/episode2/art/ep2_wanted_hole.gdshader")
	var hole_mesh := QuadMesh.new()
	hole_mesh.size = Vector2(0.085, 0.085)
	for i in 200:
		var hole := MeshInstance3D.new()
		hole.mesh = hole_mesh
		hole.material_override = hole_mat
		hole.visible = false
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(hole)
		holes.append(hole)
	return {"kind": "billboard", "node": n, "swing": null, "hits": 0,
		"size": size, "material": mat, "holes": holes, "damage_state": "clean"}
