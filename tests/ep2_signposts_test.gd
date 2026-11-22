extends Node
## EP2 SIGNPOSTS (P1-11, founder 2026-11-22: "The signposts on the ridge and at logans lake are horrid as they are not well created. The words
## are floating in mid air. Fix them."). The real rooms: Logan's Lake (its four signs and the auction sign), the lake trail's signpost, the
## river's ridge sign, the day-88 plank and the dock sign. Every painted word sits on its board (back within 1 cm of the face) and inside
## it (never past the plank's ends); every post stands on the ground (foot within 3 cm of it, set into it); no floating label is left.
## Run: godot --headless res://tests/ep2_signposts_test.tscn
const WORDS := ["LOGAN'S LAKE", "RIVER OVERLOOK", "STAGED CARGO", "DAY-88 RIVER", "AUCTION GROUNDS", "LOGAN'S CAMP AHEAD", "RIDGE TRAIL",
	"RIVER RUN", "DAY-88 DOCK"]
var failures := 0

func check(label: String, ok: bool, detail: String = "") -> void:
	print("  [%s] %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures += 1


## Every painted sign under `root`: [words, gap to the board face (m), fits inside the board].
func _painted(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("SignText*", "MeshInstance3D", true, false):
		var letters := n as MeshInstance3D
		var board := letters.get_parent().get_node_or_null("Board") as MeshInstance3D
		if board == null or not (letters.mesh is TextMesh):
			out.append([str(letters.name), 9.9, false])
			continue
		var tm: TextMesh = letters.mesh
		var bsize: Vector3 = (board.mesh as BoxMesh).size
		var t: AABB = letters.transform * tm.get_aabb()               # in the board's parent frame
		var face: float = board.position.z + bsize.z * 0.5
		var gap: float = absf(t.position.z - face) if String(letters.name) == "SignText" else absf(t.end.z - (board.position.z - bsize.z * 0.5))
		var fits: bool = t.position.x >= board.position.x - bsize.x * 0.5 - 0.001 and t.end.x <= board.position.x + bsize.x * 0.5 + 0.001 \
			and t.position.y >= board.position.y - bsize.y * 0.5 - 0.001 and t.end.y <= board.position.y + bsize.y * 0.5 + 0.001
		out.append([tm.text, gap, fits])
	return out


## Labels left floating with a sign's words.
func _floating(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "Label3D", true, false):
		for w in WORDS:
			if w in (n as Label3D).text.replace("\n", " "):
				out.append((n as Label3D).text)
	return out


## Each Signpost_*: [name, post foot height - ground height].
func _posts(root: Node, ground: Callable) -> Array:
	var out: Array = []
	for n in root.find_children("Signpost_*", "Node3D", true, false):
		var post := (n as Node3D).get_node_or_null("Post") as MeshInstance3D
		if post == null:
			out.append([str(n.name), 9.9, 9.9])
			continue
		var box: AABB = post.global_transform * post.get_aabb()
		var g: float = float(ground.call(post.global_position))
		out.append([str(n.name), box.position.y - g, box.end.y - g])
	return out


func _judge(room: String, root: Node, ground: Callable, expect: int) -> void:
	var painted: Array = _painted(root)
	var worst_gap: float = 0.0
	var spill: Array = []
	for p in painted:
		worst_gap = maxf(worst_gap, float(p[1]))
		if not p[2]: spill.append(p[0])
	check("%s: %d painted faces, every word on its board (worst gap %.3f m <= 0.01)" % [room, painted.size(), worst_gap], painted.size() >= expect and worst_gap <= 0.01)
	check("%s: ...and inside it, never past the plank's ends" % room, spill.is_empty(), str(spill))
	check("%s: no floating label left" % room, _floating(root).is_empty(), str(_floating(root)))
	var bad: Array = []
	for p in _posts(root, ground):
		# the foot is set into the ground (bottom at most 0.5 m under it) and never above it (3 cm), and the post reaches its board
		if float(p[1]) > 0.03 or float(p[1]) < -0.5 or float(p[2]) < 1.4: bad.append("%s foot %+.2f top %.2f" % [p[0], p[1], p[2]])
	check("%s: every post stands on the ground (foot within 3 cm, set into it)" % room, bad.is_empty(), str(bad))


func _ready() -> void:
	await get_tree().process_frame
	print("EP2 SIGNPOSTS:")
	var lake: LogansLakeChamber = load("res://src/episode2/chamber/logans_lake.tscn").instantiate()
	add_child(lake)
	lake.set_physics_process(false)
	lake.setup(0, [], 0)
	lake._auction_sign.visible = true
	_judge("Logan's Lake", lake._visuals, func(p: Vector3) -> float: return Ep2LakeLandform.drawn_height(p.x, p.z), 10)
	Ep2Signpost.retext(lake._marker_label, "CARGO CHECKED")
	_judge("Logan's Lake after the cargo check", lake._visuals, func(p: Vector3) -> float: return Ep2LakeLandform.drawn_height(p.x, p.z), 10)
	lake.free()
	var trail: LakeTrailChamber = load("res://src/episode2/chamber/lake_trail.tscn").instantiate()
	add_child(trail)
	trail.set_physics_process(false)
	trail.setup(0, [], 0)
	var sp: Node3D = trail._visuals.find_child("LogansLakeSignpost", true, false) as Node3D
	check("the trail's signpost is built", sp != null)
	if sp != null:
		_judge("Lake trail", sp, func(_p: Vector3) -> float: return 0.0, 4)
		var post: MeshInstance3D = null
		for c in sp.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and ((c as MeshInstance3D).mesh as BoxMesh).size.y > 2.0: post = c
		var foot: float = (post.global_transform * post.get_aabb()).position.y if post != null else 9.9
		check("Lake trail: its post stands on the trail (foot %+.2f m)" % foot, foot <= 0.03 and foot >= -0.5)
	trail.free()
	var river: RiverCoverChamber = load("res://src/episode2/chamber/river_cover.tscn").instantiate()
	add_child(river)
	river.set_physics_process(false)
	river.debug_no_ranged = true
	var st := Ep2ArmoryState.post_hideout()
	st.river_gear = true
	river.bind_armory(st)
	river.setup(0, [], 0)
	var ridge_y: float = (RiverCoverChamber.RIDGE_POINTS[1] as Vector3).y
	_judge("River ridge and dock", river._visuals, func(_p: Vector3) -> float: return ridge_y, 5)
	river.free()
	print("EP2_SIGNPOSTS: %s" % ("ALL PASS" if failures == 0 else "%d FAIL" % failures))
	get_tree().quit(1 if failures else 0)
