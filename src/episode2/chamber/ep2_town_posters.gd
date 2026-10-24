class_name Ep2TownPosters
extends RefCounted
## THE WANTED POSTERS (founder 2026-10-24: "the posters of the wanted bandits are not visible anywhere"; skill ep2-wanted-posters).
##
## Until now the jail's wanted board and its front wall carried blank paper boxes, and the street carried nothing. Four painted hand-bills
## (tools/ep2_forge/paint_wanted_posters.py, portraits engraved from the REAL game models via tools/ep2_forge/render_poster_bust.py) are
## The founder's own two (Drive 2026-10-24, "Crypto Queen Wanted.jpg" and "RH Wanted.jpg") hang in the most-seen places: the top row
## of the drop-off notice board, the saloon, the certificate office and the general store. Torn edges keyed to alpha, kept square.
## Nailed up where a man would look for them: the notice board at the drop-off, beside the shop doors under the porches, over the jail's
## blank papers outside and on its wanted board inside.
##
## Streamed (ADR-0005): the images live in the extras pack. A poster whose image is not loadable yet is simply not hung - nothing else
## depends on them. Positions are in each building's LOCAL frame (x along the front, +z out of the front wall, y up), see Ep2GoldTown.

const DIR := "res://src/episode2/extras/town/posters/"
## The painted hand-bills are 640 x 880 (height / width), for callers that size a frame before the image is loaded.
const ASPECT_PAINTED := 880.0 / 640.0
const IDS := ["crypto_queen", "rh", "jack_hammer", "accomplice", "masked_riders", "horse_thieves"]
## Each bill takes its own height / width from its image (the painted hand-bills are 640 x 880, the founder's are square).
## The notice board at the drop-off: Lil Blunt hops off the quad at Ep2GoldTown.DROP_POINT and this is the first thing on the left.
const BOARD_POS := Vector3(-7.0, 0.0, 1405.6)
const BOARD_YAW := PI * 0.5             # its face looks across the street (+x)

## [building, local position of the poster centre, width (m), poster id, roll (rad)]. Kit fronts: wall face z = 0, porch floor y = 0.44,
## ground windows centred at x = +-(w/2 - 1.3), y = 1.6 (0.95 wide) - every poster sits on bare boards between door and window.
const WALL: Array = [
	["Bldg_Certificates", Vector3(1.48, 1.90, 0.03), 0.56, "crypto_queen", -0.03],
	["Bldg_Certificates", Vector3(-1.48, 1.92, 0.03), 0.46, "masked_riders", 0.04],
	["Bldg_Saloon", Vector3(2.35, 1.95, 0.03), 0.62, "rh", 0.02],
	["Bldg_Saloon", Vector3(-1.65, 1.95, 0.03), 0.56, "crypto_queen", -0.02],
	["Bldg_Saloon", Vector3(3.05, 1.80, 0.03), 0.40, "horse_thieves", -0.06],
	["Bldg_Saloon", Vector3(-2.75, 2.0, 0.03), 0.44, "jack_hammer", -0.03],
	["Bldg_A", Vector3(1.25, 1.92, 0.03), 0.44, "horse_thieves", 0.05],
	["Bldg_A", Vector3(-1.25, 1.92, 0.03), 0.52, "rh", -0.02],
	["Bldg_B", Vector3(-1.48, 1.94, 0.03), 0.44, "jack_hammer", 0.03],
	["Bldg_C", Vector3(-1.55, 1.92, 0.03), 0.46, "masked_riders", -0.04],
	["Bldg_C", Vector3(1.50, 1.96, 0.03), 0.44, "jack_hammer", 0.02],
	["Bldg_D", Vector3(1.70, 1.92, 0.03), 0.54, "crypto_queen", -0.03],
	["Bldg_E", Vector3(-1.25, 1.92, 0.03), 0.44, "horse_thieves", 0.04],
	["Bldg_F", Vector3(1.48, 1.94, 0.03), 0.44, "masked_riders", 0.02],
	# the jailhouse front: exactly over the three blank papers build_jailhouse.py nails up (0.40 x 0.55 at z = 0.006)
	["Bldg_Jail", Vector3(-1.45, 1.55, 0.02), 0.40, "jack_hammer", 0.05],
	["Bldg_Jail", Vector3(1.55, 1.45, 0.02), 0.40, "accomplice", -0.04],
	["Bldg_Jail", Vector3(-3.3, 1.40, 0.02), 0.40, "masked_riders", 0.03],
]
## The jail's wanted board inside (right wall, x = HX - T - 0.075 = 3.445, papers 0.26 wide): each faces into the office (-x).
const JAIL_BOARD: Array = [
	[Vector3(3.425, 2.10, -1.80), "jack_hammer", 0.0], [Vector3(3.425, 1.65, -1.80), "accomplice", 0.05],
	[Vector3(3.425, 2.15, -2.35), "masked_riders", 0.10], [Vector3(3.425, 1.70, -2.35), "horse_thieves", 0.15],
]
## The street notice board's four bills (board-local: x across its face, y up, +z out of the face).
const BOARD_BILLS: Array = [
	[Vector3(-0.56, 1.95, 0.07), 0.56, "crypto_queen", -0.02], [Vector3(0.02, 1.86, 0.075), 0.40, "jack_hammer", 0.03],
	[Vector3(0.58, 1.95, 0.07), 0.56, "rh", -0.03],
	[Vector3(-0.30, 1.38, 0.08), 0.26, "masked_riders", 0.06], [Vector3(0.32, 1.37, 0.08), 0.26, "horse_thieves", -0.05],
]


## Hang every loadable poster into `root`; append the notice board's posts to `props` (collision circles). Returns how many were hung.
static func build(root: Node3D, props: Array) -> int:
	var mats: Dictionary = {}
	for id in IDS:
		for ext in ["jpg", "png"]:
			var p: String = DIR + "poster_%s.%s" % [id, ext]
			if Ep2Extras.has(p):
				mats[id] = _mat(load(p) as Texture2D, ext == "png")
				break
	if mats.is_empty():
		return 0
	var hung := 0
	var node := Node3D.new()
	node.name = "WantedPosters"
	root.add_child(node)
	for w in WALL:
		var piece: String = str(w[0])
		if Ep2GoldTown.entry(piece).is_empty() or not mats.has(str(w[3])):
			continue
		if piece == "Bldg_Jail" and not Ep2GoldTown.jail_v1:
			continue
		var xf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry(piece))
		node.add_child(_bill(mats[str(w[3])], xf * Transform3D(Basis(Vector3.FORWARD, float(w[4])), w[1]), float(w[2])))
		hung += 1
	if Ep2GoldTown.jail_v1:
		var jxf: Transform3D = Ep2GoldTown.building_xform(Ep2GoldTown.entry("Bldg_Jail"))
		for b in JAIL_BOARD:
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
	board.transform = Transform3D(Basis(Vector3.UP, BOARD_YAW), BOARD_POS)
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
	for b in BOARD_BILLS:
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
