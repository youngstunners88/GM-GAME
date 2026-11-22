class_name Ep2Signpost
extends RefCounted
## ONE SIGNPOST (founder 2026-11-22: "The signposts on the ridge and at logans lake are horrid as they are not well created. The words are
## floating in mid air."). Before, each room hung a Label3D beside or in front of a box: the ridge sign had no board at all, and the lake,
## trail and auction signs printed words wider than their boards, so the letters hung in the air past the plank's ends.
## Here a sign is a post standing on the ground (its foot set into it), a real board, and the words PAINTED on the board's face: a thin
## TextMesh in the town's western serif, fitted inside the board with a margin, its back on the face (within 1 cm), on both faces.
##   var text: TextMesh = Ep2Signpost.standard(parent, "LOGAN'S LAKE", foot, yaw, 3.2, wood)    # foot = the ground point under the post
##   Ep2Signpost.retext(text, "CARGO CHECKED")                                                  # re-fits on the same board
const FONT := "res://src/episode2/assets/weapons/armory/western_bookman.otf"
const PAINT_DEPTH := 0.004            # painted letters: a skin on the board, not a separate plate
const BURY := 0.3                     # how far a post is set into the ground
const MARGIN := 0.08                  # clear board around the words
const INK := Color(0.96, 0.84, 0.56)


## A post (bottom BURY below `foot`), a board on it at `board_y` above the foot, the words on both faces. The board faces local +Z
## (`yaw` turns it); returns the TextMesh (shared by both faces) so a room can change the words later with retext().
static func standard(parent: Node3D, words: String, foot: Vector3, yaw: float, width: float, wood: Material,
		board_y: float = 1.6, board_h: float = 0.62, post_h: float = 2.2, ink: Color = INK, two_sided: bool = true) -> TextMesh:
	var root := Node3D.new()
	root.name = "Signpost_" + words.strip_edges().replace(" ", "_").replace(">", "").replace("'", "").left(24)
	root.position = foot
	root.rotation.y = yaw
	parent.add_child(root)
	var post := MeshInstance3D.new()
	post.name = "Post"
	var pm := BoxMesh.new()
	pm.size = Vector3(0.15, post_h + BURY, 0.15)
	post.mesh = pm
	post.material_override = wood
	post.position = Vector3(0.0, (post_h - BURY) * 0.5, -0.115)      # behind the board, touching its back
	root.add_child(post)
	return board(root, Vector3(width, board_h, 0.08), Vector3(0.0, board_y, 0.0), wood, words, ink, two_sided)


## A board (box `size` at `center`, faces local +-Z) with the words painted on it; for wall plaques and signs on a frame of their own.
static func board(parent: Node3D, size: Vector3, center: Vector3, wood: Material, words: String, ink: Color = INK, two_sided: bool = true) -> TextMesh:
	var holder := Node3D.new()                        # one holder per board: two boards on one post keep their own Board/SignText names
	holder.name = "Sign_" + words.strip_edges().replace(" ", "_").replace("\n", "_").replace(">", "").replace("'", "").left(24)
	parent.add_child(holder)
	parent = holder
	var plank := MeshInstance3D.new()
	plank.name = "Board"
	var bm := BoxMesh.new()
	bm.size = size
	plank.mesh = bm
	plank.material_override = wood
	plank.position = center
	parent.add_child(plank)
	var tm := TextMesh.new()
	if ResourceLoader.exists(FONT):
		tm.font = load(FONT)
	tm.font_size = 64
	tm.depth = PAINT_DEPTH
	var paint := StandardMaterial3D.new()
	paint.albedo_color = ink
	paint.roughness = 0.85
	tm.material = paint
	tm.set_meta("fit", Vector2(size.x - MARGIN * 2.0, size.y - MARGIN * 2.0))
	retext(tm, words)
	for face in ([1.0, -1.0] if two_sided else [1.0]):
		var letters := MeshInstance3D.new()
		letters.name = "SignText" if face > 0.0 else "SignTextBack"
		letters.mesh = tm
		letters.position = center + Vector3(0.0, 0.0, face * (size.z * 0.5 + PAINT_DEPTH * 0.5 + 0.001))
		letters.rotation.y = 0.0 if face > 0.0 else PI
		parent.add_child(letters)
	return tm


## New words on the same board: the letters are scaled to fit inside it (never wider or taller than the board less its margin).
static func retext(tm: TextMesh, words: String) -> void:
	tm.text = words
	var fit: Vector2 = tm.get_meta("fit", Vector2(2.0, 0.5))
	tm.pixel_size = 0.01
	var box: AABB = tm.get_aabb()
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	tm.pixel_size = 0.01 * minf(fit.x / box.size.x, fit.y / box.size.y)
