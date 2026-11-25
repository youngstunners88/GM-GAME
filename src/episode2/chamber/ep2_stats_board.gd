extends Node3D
## THE GOLD MINE STATS BOARD (founder 2026-11-25, PROMPT_EPISODE2_STOCKPILE_CAD_WHEELBARROW_RIG_STOREFRONT_STATS_2026-11-25 section 6):
## a Western notice board at the street side of the saloon's side ladder. Its labels name the protocol's blocks (supply, locked,
## liquidity) and point at the live page - no numbers, rates or fees are painted on it (those live on the site and change).
## "View live stats [E]" in reach opens the real site. mine4gold.app is a single-page app with its live figures (ROI, day count, the
## Diamond ratio) on the root page and no separate stats route (checked 2026-11-25), so the board links the root.
## Untyped like the ladder (no class_name, no class-cache step): built by ep2_saloon_ladder.gd, reached through GoldTownChamber.
const URL := "https://mine4gold.app/"
const PROMPT := "View live stats"
const AT := Vector3(-8.0, 0.0, 2.6)          # saloon local: past the ladder's foot (-7.08, 0.3), out toward the street, clear of the climb
const YAW := -0.7                            # local: its face turned from the street (+z) toward the lane (-x), where he comes from
const WIDTH := 1.4
const POST_H := 2.45
const BURY := 0.3
const PROMPT_R := 1.5                        # how near the board's centre he must stand (either face: it is painted on both)
const BODY_R := 0.22                         # each post, for the walk-round circles
const TITLE := "GOLD MINE STATS"
const LINES := "SUPPLY . . . see live\nLOCKED . . . see live\nLIQUIDITY . . . see live"
const FOOTER := "VIEW LIVE STATS\nmine4gold.app"

var opened: int = 0                          # evidence for tests and captures
var last_url: String = ""
## Test seam: when valid it is called with the URL instead of OS.shell_open (tests must never open a browser).
var opener: Callable = Callable()
var _xf: Transform3D                         # saloon local -> world


## Stand the board beside the ladder. `xf` is the saloon's transform, `wood` the ladder's timber; both posts join `props`.
static func build(parent: Node3D, xf: Transform3D, wood: Material, props: Array) -> Node3D:
	var n = (load("res://src/episode2/chamber/ep2_stats_board.gd") as GDScript).new()
	n.name = "StatsBoard"
	n._xf = xf
	n.transform = xf * Transform3D(Basis(Vector3.UP, YAW), AT)
	parent.add_child(n)
	n._dress(wood)
	for x in [-WIDTH * 0.5 + 0.08, WIDTH * 0.5 - 0.08]:
		var p: Vector3 = n.transform * Vector3(x, 0.0, -0.1)
		props.append([Vector2(p.x, p.z), BODY_R])
	return n


func _dress(wood: Material) -> void:
	for x in [-WIDTH * 0.5 + 0.08, WIDTH * 0.5 - 0.08]:      # two posts set into the ground, behind the boards
		var post := MeshInstance3D.new()
		post.name = "Post"
		var pm := BoxMesh.new()
		pm.size = Vector3(0.14, POST_H + BURY, 0.14)
		post.mesh = pm
		post.material_override = wood
		post.position = Vector3(x, (POST_H - BURY) * 0.5, -0.11)
		add_child(post)
	var cap := MeshInstance3D.new()                           # a little drip cap over the top board
	cap.name = "Cap"
	var cm := BoxMesh.new()
	cm.size = Vector3(WIDTH + 0.16, 0.05, 0.26)
	cap.mesh = cm
	cap.material_override = wood
	cap.position = Vector3(0.0, POST_H + 0.02, -0.04)
	add_child(cap)
	# three boards, each in its own holder (Ep2Signpost.board makes one per board)
	Ep2Signpost.board(self, Vector3(WIDTH, 0.30, 0.07), Vector3(0.0, 2.22, 0.0), wood, TITLE)
	Ep2Signpost.board(self, Vector3(WIDTH, 0.66, 0.07), Vector3(0.0, 1.66, 0.0), wood, LINES, Color(0.93, 0.88, 0.74))
	Ep2Signpost.board(self, Vector3(WIDTH * 0.8, 0.30, 0.07), Vector3(0.0, 1.13, 0.0), wood, FOOTER)


## Where the board stands (world, on the ground).
func center_world() -> Vector3:
	return global_transform.origin if is_inside_tree() else transform.origin


## He is on the ground within reach of either face.
func can_view(player: Vector3) -> bool:
	var c: Vector3 = center_world()
	return absf(player.y - c.y) < 0.5 and Vector2(player.x - c.x, player.z - c.z).length() < PROMPT_R


func prompt(player: Vector3) -> String:
	return PROMPT if can_view(player) else ""


## [E] in reach: open the live site. Must be called from the key/button handler (the web build only lets a click or key open a tab).
func view(player: Vector3) -> bool:
	if not can_view(player):
		return false
	open_url()
	return true


func open_url() -> void:
	opened += 1
	last_url = URL
	if opener.is_valid():
		opener.call(URL)
	else:
		OS.shell_open(URL)
