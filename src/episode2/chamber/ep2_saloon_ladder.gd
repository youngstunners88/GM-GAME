extends Node3D
## THE SALOON'S SIDE LADDER (founder 2026-11-21: the two old regulars - grandfather and oldtimer, Ep2TownPeople.BALCONY_REGULARS - stand
## drinking OUTSIDE on the saloon's balcony and nobody could get up there; "a LADDER on the outside side wall, not an interior staircase";
## skill ep2-saloon-roof-access).
##
## A weathered timber ladder at the saloon's free (south, desert-side) end, its rails hard against the front corner in line with the
## side wall, iron stays bolted into the corner board, rails running 1 m above the balcony boards, a top step over the porch roof's edge
## onto the balcony's end, and an end rail on the balcony with a gap where the ladder tops out (the far end gets a full end rail).
## The detailed mesh streams with the extras (Ep2Extras.SALOON_LADDER, tools/ep2_blender/build_saloon_ladder.py); until the pack has
## mounted the same ladder stands as rails, rungs and boards built here, and swaps in place when it does.
##
## Lil Blunt climbs it: "Climb [E]" at the foot (INTERACT on a phone) walks him onto the rungs and up them rung by rung, over the step
## and onto the balcony, where he walks between its end rails, the front rail and the wall, round the chairs and the two old men (they
## stay where they are). "Climb down [E]" at the gap takes him back the same way. The chamber (GoldTownChamber) drives its player from
## step(); everything here is in the saloon's local frame (Ep2GoldTown: x along the front, z out to the street, y up).

const BLDG := "Bldg_Saloon"
const DECK_Y := 3.98                                   # Ep2GoldTown.BALCONY_Y: the balcony's plank top
const LADDER_AT := Vector3(-6.42, 0.0, 0.30)           # ground point between the rails, just outside the porch roof's edge (x -6.3)
const RAIL_X := 0.25                                   # half the ladder's width (rail centres), along the saloon's z
const RAIL_TOP := 4.98                                 # 1 m above the boards: a hand-hold to step off and on
const RUNG_STEP := 0.30
const RUNGS := 13                                      # y 0.30 ... 3.90
## The climber's way (saloon-local). On the rungs his body is 0.4 m out from them, facing the ladder (+x).
const FOOT := Vector3(-7.08, 0.0, 0.30)
const ON_LOW := Vector3(-6.82, RUNG_STEP, 0.30)
const ON_HIGH := Vector3(-6.82, RUNG_STEP * RUNGS, 0.30)   # feet on the last rung (3.90)
const LIFT := Vector3(-6.66, DECK_Y + 0.01, 0.30)       # a foot lifted onto the top step's level before he steps forward onto it
const STEP_TOP := Vector3(-6.22, DECK_Y, 0.30)
const DECK_IN := Vector3(-5.40, DECK_Y, 0.45)
const CLIMB_SPEED := 1.05                              # m/s up or down the rungs
const BODY_R := 0.30                                   # the player's radius (Ep2GoldTown.collide)
const PROMPT_R := 1.3                                  # how near the foot he must stand for "Climb [E]"
## The balcony he can walk on: inside its end rails, the front rail (z 1.5) and the wall (z 0), less his radius.
const WALK_MIN := Vector2(-5.95 + BODY_R, 0.02 + BODY_R)
const WALK_MAX := Vector2(5.95 - BODY_R, 1.46 - BODY_R)
const GAP_Z := Vector2(0.0, 0.62)                      # the gap in the near end rail where the ladder tops out
## The balcony's furniture (Ep2GoldTown.BALCONY_CHAIRS / BALCONY_TABLE) as walk-around circles [saloon-local xz, radius].
const DECK_BLOCKS := [[Vector2(-2.6, 0.45), 0.30], [Vector2(-0.7, 0.45), 0.30], [Vector2(-1.65, 0.45), 0.36]]

## Tests force the stand-in to prove the in-place upgrade (never set in the game).
static var force_stand_in: bool = false

var state: String = "ground"                           # ground | up | top | down
var climbs_up: int = 0
var climbs_down: int = 0
var streamed: bool = false                             # the detailed streamed mesh is drawn (false = the stand-in)
var _xf: Transform3D                                   # saloon local -> world
var _path: Array = []                                  # [[local point, seconds, kind]]  kind: "walk" | "rungs" | "turn"
var _seg: int = 0
var _seg_t: float = 0.0
var _from: Vector3
var _yaw: float = 0.0
var _wood: Material
var _iron: Material
var _poll: float = 0.0
## The Gold Mine stats board beside the ladder's foot ("View live stats [E]" opens mine4gold.app): ep2_stats_board.gd.
const STATS_BOARD := preload("res://src/episode2/chamber/ep2_stats_board.gd")
var stats_board = null


## Put the ladder (and the balcony's end rails) on the saloon. `saloon` is the town's copy of the saloon (its Trim material dresses the
## end rails the way the front rail is dressed). Adds the ladder's foot to `props` (player and townspeople walk round it). Null when the
## saloon is not in the layout.
static func build(root: Node3D, saloon: Node3D, props: Array) -> Node3D:
	var e: Array = Ep2GoldTown.entry(BLDG)
	if e.is_empty():
		return null
	var n = (load("res://src/episode2/chamber/ep2_saloon_ladder.gd") as GDScript).new()       # untyped: its own members are set below
	n.name = "SaloonLadder"
	n._xf = Ep2GoldTown.building_xform(e)
	root.add_child(n)
	n._dress(saloon)
	n._place_ladder()
	n._end_rails(saloon)
	props.append([n.to_world2(LADDER_AT), 0.32])
	n.stats_board = STATS_BOARD.build(n, n._xf, n._wood, props)     # the Gold Mine stats board at the ladder's street side (2026-11-25)
	return n


# --- the build ------------------------------------------------------------------------------------------------------------------

func _dress(saloon: Node3D) -> void:
	var w := StandardMaterial3D.new()                  # weathered, sun-greyed pine in the town's own timber grain
	w.albedo_color = Color(0.50, 0.41, 0.32)
	w.roughness = 0.92
	var tex: String = Ep2GoldTown.TEX_DIR + "tex_timber.jpg"
	if ResourceLoader.exists(tex):
		w.albedo_texture = load(tex)
		w.uv1_triplanar = true
		w.uv1_world_triplanar = true
		w.uv1_scale = Vector3.ONE * 0.9
	_wood = w
	var fe := StandardMaterial3D.new()                 # black smithed iron
	fe.albedo_color = Color(0.17, 0.16, 0.15)
	fe.metallic = 0.65
	fe.roughness = 0.6
	_iron = fe


## The ladder's own frame: rungs along its x (= the saloon's z), the climbing side +z (= the saloon's -x), set at LADDER_AT.
func ladder_xform() -> Transform3D:
	return _xf * Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), LADDER_AT)


func _place_ladder() -> void:
	var holder := Node3D.new()
	holder.name = "Ladder"
	holder.transform = ladder_xform()                  # this node sits at the town's origin; the holder carries the full frame
	add_child(holder)
	if not _fill_streamed(holder):
		_stand_in(holder)


## The detailed ladder from the streamed pack; false (nothing added) when it is not mounted yet.
func _fill_streamed(holder: Node3D) -> bool:
	if force_stand_in or not Ep2Extras.has(Ep2Extras.SALOON_LADDER):
		return false
	var ps: PackedScene = load(Ep2Extras.SALOON_LADDER) as PackedScene
	if ps == null:
		return false
	var n: Node3D = ps.instantiate() as Node3D
	n.name = "Streamed"
	holder.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for si in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(si)
			var iron: bool = src != null and String(src.resource_name).begins_with("LadderIron")
			m.set_surface_override_material(si, _iron if iron else _wood)
	streamed = true
	return true


## The same ladder in rails, rungs and boards (no pack yet): same rails, rung heights, step and stays as the streamed mesh.
func _stand_in(holder: Node3D) -> void:
	var s := Node3D.new()
	s.name = "StandIn"
	holder.add_child(s)
	for sx in [-1.0, 1.0]:
		_box(s, Vector3(0.05, RAIL_TOP, 0.08), Vector3(sx * RAIL_X, RAIL_TOP * 0.5, 0.0), _wood)
	for i in RUNGS:
		var r := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.018
		cm.bottom_radius = 0.018
		cm.height = RAIL_X * 2.0 + 0.05
		cm.radial_segments = 8
		cm.rings = 1
		r.mesh = cm
		r.material_override = _wood
		r.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, RUNG_STEP * float(i + 1), 0.0))
		s.add_child(r)
	_box(s, Vector3(0.74, 0.07, 0.20), Vector3(0.0, 0.035, 0.0), _wood)                     # the sill
	_box(s, Vector3(0.56, 0.05, 0.52), Vector3(0.0, DECK_Y - 0.025, -0.21), _wood)          # the top step onto the balcony
	for y in [0.95, 2.15, 3.35]:                                                            # iron stays into the corner board
		_box(s, Vector3(0.012, 0.045, 0.40), Vector3(-0.28, y, -0.23), _iron)


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## End rails on the balcony (it had only its front rail): the near end with a gap at the ladder, the far end whole. Same height as the
## front rail (its top at 4.94), a post at each end of a run and plain balusters between, dressed like the front rail.
func _end_rails(saloon: Node3D) -> void:
	var trim: Material = Ep2SwingDoor.find_material(saloon, "Trim") if saloon != null else null
	if trim == null:
		trim = _wood
	var rails := Node3D.new()
	rails.name = "BalconyEndRails"
	rails.transform = _xf
	add_child(rails)
	for run in [[-5.96, GAP_Z.y, 1.5], [5.96, 0.04, 1.5]]:
		var x: float = float(run[0])
		var z0: float = float(run[1])
		var z1: float = float(run[2])
		_box(rails, Vector3(0.08, 0.08, z1 - z0), Vector3(x, 4.90, (z0 + z1) * 0.5), trim)         # the top rail
		_box(rails, Vector3(0.06, 0.06, z1 - z0), Vector3(x, DECK_Y + 0.12, (z0 + z1) * 0.5), trim) # the bottom rail
		for z in [z0 + 0.04, z1 - 0.04]:
			_box(rails, Vector3(0.09, 0.96, 0.09), Vector3(x, DECK_Y + 0.48, z), trim)                # the posts
		var k: int = int((z1 - z0) / 0.3)
		for i in range(1, k):
			_box(rails, Vector3(0.05, 0.84, 0.05), Vector3(x, DECK_Y + 0.5, z0 + (z1 - z0) * float(i) / float(k)), trim)


func _process(delta: float) -> void:
	if streamed:
		set_process(false)
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		upgrade_now()


## Swap the stand-in for the streamed ladder once the pack has mounted (polled; tests call it). True when the streamed mesh is drawn.
func upgrade_now() -> bool:
	if streamed:
		return true
	var holder: Node3D = get_node_or_null("Ladder") as Node3D
	if holder == null or not _fill_streamed(holder):
		return false
	var s: Node = holder.get_node_or_null("StandIn")
	if s != null:
		s.queue_free()
	return true


# --- frames ---------------------------------------------------------------------------------------------------------------------

func to_local_s(world: Vector3) -> Vector3:
	return _xf.affine_inverse() * world


func to_world(local: Vector3) -> Vector3:
	return _xf * local


func to_world2(local: Vector3) -> Vector2:
	var w: Vector3 = _xf * local
	return Vector2(w.x, w.z)


func _yaw_of(local_dir: Vector3) -> float:
	var d: Vector3 = _xf.basis * local_dir
	return atan2(d.x, d.z)


## The world point at the ladder's foot where a climb starts, and the one on the balcony where it ends.
func foot_world() -> Vector3:
	return to_world(FOOT)


func deck_world() -> Vector3:
	return to_world(DECK_IN)


# --- the climb --------------------------------------------------------------------------------------------------------------------

func busy() -> bool:
	return state == "up" or state == "down"


func on_top() -> bool:
	return state == "top"


## He stands at the ladder's foot, on the ground, on the street side of it (never from the porch, through the ladder).
func can_climb_up(player: Vector3) -> bool:
	if state != "ground":
		return false
	var l: Vector3 = to_local_s(player)
	return absf(l.y) < 0.5 and l.x <= LADDER_AT.x - 0.2 and Vector2(l.x - FOOT.x, l.z - FOOT.z).length() < PROMPT_R


## He stands on the balcony by the gap in its end rail.
func can_climb_down(player: Vector3) -> bool:
	if state != "top":
		return false
	var l: Vector3 = to_local_s(player)
	return l.x < -4.85 and l.z < GAP_Z.y + 0.35


func prompt(player: Vector3) -> String:
	if can_climb_up(player):
		return "Climb"
	if can_climb_down(player):
		return "Climb down"
	return ""


func start_up(player: Vector3) -> bool:
	if not can_climb_up(player):
		return false
	_begin("up", player, [[FOOT, maxf(0.25, Vector2(to_local_s(player).x - FOOT.x, to_local_s(player).z - FOOT.z).length() / 1.4), "walk"],
		[ON_LOW, 0.45, "turn"], [ON_HIGH, (ON_HIGH.y - ON_LOW.y) / CLIMB_SPEED, "rungs"], [LIFT, 0.35, "turn"], [STEP_TOP, 0.4, "turn"],
		[DECK_IN, 0.55, "walk"]])
	return true


func start_down(player: Vector3) -> bool:
	if not can_climb_down(player):
		return false
	var l: Vector3 = to_local_s(player)
	var gap_in := Vector3(-5.55, DECK_Y, 0.30)
	_begin("down", player, [[gap_in, maxf(0.2, Vector2(l.x - gap_in.x, l.z - gap_in.z).length() / 1.4), "walk"], [STEP_TOP, 0.4, "walk"],
		[LIFT, 0.4, "turn"], [ON_HIGH, 0.35, "turn"], [ON_LOW, (ON_HIGH.y - ON_LOW.y) / CLIMB_SPEED, "rungs"], [FOOT, 0.45, "turn"]])
	return true


func _begin(kind: String, player: Vector3, path: Array) -> void:
	state = kind
	_path = path
	_seg = 0
	_seg_t = 0.0
	_from = to_local_s(player)
	_yaw = _yaw_of(Vector3(1, 0, 0))


## Advance the climb by `delta`. Returns {"pos": world feet position, "yaw": world yaw to face, "rung": rung number under his hands (or
## -1), "done": true on the frame he arrives}. Call only while busy().
func step(delta: float) -> Dictionary:
	var out := {"pos": to_world(_from), "yaw": _yaw, "rung": -1, "done": false}
	if not busy():
		return out
	_seg_t += delta
	while _seg < _path.size() and _seg_t >= float(_path[_seg][1]):
		_seg_t -= float(_path[_seg][1])
		_from = _path[_seg][0]
		_seg += 1
	if _seg >= _path.size():
		var up: bool = state == "up"
		state = "top" if up else "ground"
		if up:
			climbs_up += 1
		else:
			climbs_down += 1
		_from = _path[_path.size() - 1][0]
		out["pos"] = to_world(_from)
		out["done"] = true
		out["yaw"] = _yaw_of(Vector3(0, 0, 1)) if up else _yaw_of(Vector3(-1, 0, 0))   # looking out over the street / away from the wall
		return out
	var to: Vector3 = _path[_seg][0]
	var dur: float = float(_path[_seg][1])
	var kind: String = str(_path[_seg][2])
	var k: float = clampf(_seg_t / maxf(dur, 1e-4), 0.0, 1.0)
	var p: Vector3
	if kind == "rungs":
		# rung by rung: a pull, then a short settle on each rung, his weight shifting hand to hand (a little sway along the rungs)
		var y0: float = _from.y
		var span: float = to.y - y0
		var steps: float = absf(span) / RUNG_STEP
		var f: float = k * steps
		var i: float = floorf(f)
		var frac: float = f - i
		var e: float = smoothstep(0.0, 0.8, frac)
		var y: float = y0 + signf(span) * RUNG_STEP * minf(i + e, steps)
		var sway: float = sin((i + e) * PI) * 0.03
		p = Vector3(to.x, y, to.z + sway)
		out["rung"] = int(round((y - 0.0) / RUNG_STEP))
		_yaw = _yaw_of(Vector3(1, 0, 0))
	else:
		var e2: float = k * k * (3.0 - 2.0 * k)
		p = _from.lerp(to, e2)
		if kind == "walk":
			var d: Vector3 = to - _from
			if Vector2(d.x, d.z).length() > 0.05:
				_yaw = _yaw_of(Vector3(d.x, 0, d.z).normalized())
		else:
			_yaw = _yaw_of(Vector3(1, 0, 0))                   # onto / off the rungs: facing the ladder
	out["pos"] = to_world(p)
	out["yaw"] = _yaw
	return out


## Keep a body on the balcony: inside the end rails, the front rail and the wall, round its chairs and table and anyone up there
## (`bodies`: world positions of the people at that height). `p` is the wished-for world point; returns where he may stand.
func collide_deck(p: Vector3, bodies: Array) -> Vector3:
	var l: Vector3 = to_local_s(p)
	var c := Vector2(clampf(l.x, WALK_MIN.x, WALK_MAX.x), clampf(l.z, WALK_MIN.y, WALK_MAX.y))
	var blocks: Array = DECK_BLOCKS.duplicate()
	for b in bodies:
		var bl: Vector3 = to_local_s(b)
		blocks.append([Vector2(bl.x, bl.z), 0.34])
	for _pass in 2:
		for b in blocks:
			var at: Vector2 = b[0]
			var r: float = float(b[1]) + BODY_R
			var dv: Vector2 = c - at
			if dv.length() < r:
				c = at + (dv.normalized() if dv.length() > 0.001 else Vector2(-1, 0)) * r
		c = Vector2(clampf(c.x, WALK_MIN.x, WALK_MAX.x), clampf(c.y, WALK_MIN.y, WALK_MAX.y))
	return to_world(Vector3(c.x, DECK_Y, c.y))


## True when a world point is over the balcony's walkable boards (a teleport elsewhere means he is no longer up there).
func over_deck(p: Vector3) -> bool:
	var l: Vector3 = to_local_s(p)
	return l.x > WALK_MIN.x - 0.2 and l.x < WALK_MAX.x + 0.2 and l.z > WALK_MIN.y - 0.2 and l.z < WALK_MAX.y + 0.2 and l.y > DECK_Y - 0.6


## Back on the ground without climbing (a scripted beat moved him): the ladder forgets the climb.
func reset() -> void:
	state = "ground"
	_path = []
