extends RefCounted
## Optional poster construction streams with its art; census/layout constants remain in core.
## Hang every loadable poster into `root`; append the notice board's posts to `props` (collision circles). Returns how many were hung.
static func build(root: Node3D, props: Array) -> int:
	var mats: Dictionary = {}
	for id in Ep2TownPosters.IDS:
		for ext in (["png"] if id == "jack_hammer" else ["jpg", "png"]):
			var p: String = Ep2TownPosters.DIR + "poster_%s.%s" % [id, ext]
			if Ep2Extras.has(p):
				mats[id] = _mat(load(p) as Texture2D, ext == "png")
				break
	if mats.is_empty():
		return 0
	var hung := 0
	var node := Node3D.new()
	node.name = "WantedPosters"
	root.add_child(node)
	for w in Ep2TownPosters.WALL:
		var piece: String = str(w[0])
		if Ep2GoldTown.entry(piece).is_empty() or not mats.has(str(w[3])):
			continue
		if piece == "Bldg_Armory" and not Ep2GoldTown.armory_v2:
			continue
		if piece == "Bldg_Jail" and not Ep2GoldTown.jail_v1:
			continue
		var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry(piece))
		if piece == "Bldg_Armory":
			var backing := _box(node, Vector3(0.46, 0.62, 0.014), Vector3.ZERO, Ep2GoldTown._tex_mat("", Color(0.40, 0.26, 0.13), 0.95, Ep2GoldTown.TIMBER_TEX))
			backing.transform = xf * Transform3D(Basis(Vector3.FORWARD, float(w[4])), Vector3(w[1].x, w[1].y, 0.023))
		node.add_child(_bill(mats[str(w[3])], xf * Transform3D(Basis(Vector3.FORWARD, float(w[4])), w[1]), float(w[2])))
		hung += 1
	if Ep2GoldTown.jail_v1:
		var jxf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Jail"))
		for b in Ep2TownPosters.JAIL_BOARD:
			if not mats.has(str(b[1])):
				continue
			var face := Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.FORWARD, float(b[2]))     # quad +z -> local -x (into the room)
			node.add_child(_bill(mats[str(b[1])], jxf * Transform3D(face, b[0]), 0.26))
			hung += 1
	hung += _notice_board(node, mats, props)
	return hung


## The free-standing board at the drop-off: two posts, a plank board under a little shingle cap, its bills.
static func _notice_board(parent: Node3D, mats: Dictionary, props: Array) -> int:
	var board := Node3D.new()
	board.name = "NoticeBoard"
	board.transform = Transform3D(Basis(Vector3.UP, Ep2TownPosters.BOARD_YAW), Ep2TownPosters.BOARD_POS)
	parent.add_child(board)
	var wood: StandardMaterial3D = Ep2GoldTown._tex_mat("", Color(0.62, 0.48, 0.34), 0.9, Ep2GoldTown.TIMBER_TEX)
	var plank: StandardMaterial3D = Ep2GoldTown._tex_mat("", Color(0.78, 0.66, 0.52), 0.7, Ep2GoldTown.PLANK_TEX)
	var roof: StandardMaterial3D = Ep2GoldTown._tex_mat("tex_roof.jpg", Color(0.70, 0.62, 0.56), 0.35, "")
	for sx in [-1.0, 1.0]:
		_box(board, Vector3(0.13, 2.75, 0.13), Vector3(sx * 0.98, 1.375, 0.0), wood)
		props.append([Vector2((board.transform * Vector3(sx * 0.98, 0, 0)).x, (board.transform * Vector3(sx * 0.98, 0, 0)).z), 0.25])
	_box(board, Vector3(1.86, 1.40, 0.06), Vector3(0.0, 1.66, 0.04), plank)                     # the board
	_box(board, Vector3(2.0, 0.08, 0.10), Vector3(0.0, 2.40, 0.06), wood)                        # head rail
	_box(board, Vector3(2.0, 0.08, 0.10), Vector3(0.0, 0.92, 0.06), wood)                        # foot rail
	var cap := _box(board, Vector3(2.3, 0.05, 0.62), Vector3(0.0, 2.80, 0.12), roof)              # shingle cap, tipped forward
	cap.rotation.x = 0.28
	var n := 0
	for b in Ep2TownPosters.BOARD_BILLS:
		if mats.has(str(b[2])):
			board.add_child(_bill(mats[str(b[2])], Transform3D(Basis(Vector3.FORWARD, float(b[3])), b[0]), float(b[1])))
			n += 1
	return n


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _mat(tex: Texture2D, cut: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	if cut:                                         # the founder's posters: torn edges are alpha, scissor keeps them crisp and sorted
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC   # lettering stays legible at a slant
	return m


## One hand-bill: a quad of the poster's aspect, `width` wide, facing +z of `xf`.
static func _bill(mat: StandardMaterial3D, xf: Transform3D, width: float) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.name = "Poster"
	var qm := QuadMesh.new()
	var tex: Texture2D = mat.albedo_texture
	var aspect: float = float(tex.get_height()) / maxf(float(tex.get_width()), 1.0) if tex != null else 1.375
	qm.size = Vector2(width, width * aspect)
	q.mesh = qm
	q.material_override = mat
	q.transform = xf
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q
