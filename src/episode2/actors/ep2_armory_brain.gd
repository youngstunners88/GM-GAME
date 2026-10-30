class_name Ep2ArmoryBrain
extends RefCounted
## RICH & UTAH AT WORK (founder 2026-10-19: "move properly with detailed movements and good autonomy"; skill ep2-armory-npc-autonomy).
##
## Drives one Ep2TownFolk inside the two-storey Armory (Bldg_Armory2, tools/ep2_blender/build_armory2.py). The building's GLB carries
## named waypoints (Spot_*) in its local frame; this brain walks a small graph between them (A*, deterministic), climbs the stair with
## the StairsUp clip, and runs weighted work tasks with each man's character:
##   Rich - the counter owner, measured and dry: mostly at the counter (lean, cigar), wipes a revolver at the case, shows the sniper,
##          fetches from the back rack, goes up to the gallery now and then.
##   Utah - the busy partner, river-linked: hauls crates on the gallery (pick up, carry, put down), cleans rifles at both benches,
##          checks the window, tries a rifle's sight, and uses the stair often.
## Reactions interrupt the task and then resume work: Lil Blunt stepping inside makes Rich turn and greet him (and go to the counter),
## Utah glance and nod; standing at the counter keeps Rich there, facing him. Only one man is ever on the stair (a reservation).
## Pure logic: `step(delta, player_world)` is called by the chamber; a fixed seed replays exactly (tests/ep2_armory_npc_test.gd).

signal greeted(who: String)
## A directed walk reached its spot (the introduction beat, ep2-armory-guns).
signal directed_arrived(who: String, spot: String)

const STAIR_EDGE := ["stair_foot", "stair_head"]
## Walkable graph between the building's spots (both directions). The counter splits the shop: the gaps at its ends are the only ways
## round; the stair is the only way up.
const EDGES := [
	["door", "front_mid"], ["front_mid", "player"], ["front_mid", "case_left"], ["front_mid", "case_right"], ["front_mid", "stair_bottom"],
	["player", "case_left"], ["player", "case_right"], ["case_left", "gap_left"], ["case_left", "shelves"], ["shelves", "gap_left"],
	["case_right", "gap_right"], ["gap_left", "behind_left"], ["behind_left", "case_revolvers"], ["gap_right", "behind_right"],
	["behind_right", "sniper_case"], ["behind_right", "kegs"],
	["case_revolvers", "counter_rich"], ["counter_rich", "counter_till"], ["counter_till", "sniper_case"], ["counter_rich", "back_mid"],
	["counter_till", "back_mid"], ["case_revolvers", "back_mid"], ["sniper_case", "kegs"], ["kegs", "back_mid"], ["back_mid", "rack_back"],
	["rack_back", "bench"], ["stair_bottom", "stair_foot"], ["stair_foot", "stair_head"], ["stair_head", "stair_top"],
	["stair_top", "gallery_river"], ["gallery_river", "gallery_window"], ["gallery_river", "gallery_bench"], ["gallery_window", "gallery_bench"],
	["gallery_bench", "gallery_rack"], ["gallery_rack", "gallery_crates"], ["gallery_rack", "well_view"], ["gallery_crates", "well_view"],
	["well_view", "gallery_gatling"], ["well_view", "gallery_left"],
	# out the door and across the porch to the lane and the Gatling post in the yard (the post's spots are added by the chamber)
	["door", "porch"], ["porch", "lane"], ["lane", "gatling_stand"], ["gatling_stand", "gatling_look"],
]
## Where a man faces while working at a spot (local frame).
const FACE := {
	"counter_rich": Vector3(-0.9, 0.0, -2.0), "counter_till": Vector3(0.7, 0.0, -2.0), "case_revolvers": Vector3(-2.4, 0.0, -5.2),
	"sniper_case": Vector3(2.6, 0.0, -5.2), "rack_back": Vector3(-0.4, 0.0, -12.0), "bench": Vector3(-3.2, 0.0, -9.6),
	"shelves": Vector3(-4.9, 0.0, -4.6), "kegs": Vector3(3.3, 0.0, -6.8), "case_left": Vector3(-3.2, 0.0, -2.2), "case_right": Vector3(3.2, 0.0, -2.2),
	"gallery_rack": Vector3(-0.2, 3.8, -12.0), "gallery_crates": Vector3(-3.7, 3.8, -11.0), "gallery_bench": Vector3(1.6, 3.8, -10.7),
	"gallery_river": Vector3(4.2, 3.8, -10.7), "gallery_window": Vector3(3.0, 3.8, -12.2), "gallery_left": Vector3(-5.0, 3.8, -5.0),
	"well_view": Vector3(-0.9, 0.0, -3.0), "gallery_gatling": Vector3(0.2, 3.8, -8.9),
}
## Tasks: [weight, steps]; a step is [spot, clip, min s, max s, walk clip ("" = Walk)].
const TASKS := {
	"rich": [
		[5.0, [["counter_rich", "Counter", 9.0, 16.0, ""]]],
		[2.0, [["counter_rich", "CigarPuff", 6.8, 6.8, ""]]],
		[1.5, [["counter_till", "Idle", 5.0, 9.0, ""]]],
		[2.0, [["case_revolvers", "WipeRifle", 6.0, 10.0, ""]]],
		[1.0, [["sniper_case", "InspectRifle", 3.9, 3.9, ""], ["sniper_case", "Idle", 2.0, 4.0, ""]]],
		[1.0, [["rack_back", "Reach", 2.9, 2.9, ""], ["rack_back", "InspectRifle", 3.9, 3.9, ""]]],
		[0.4, [["gallery_rack", "InspectRifle", 3.9, 3.9, ""], ["well_view", "Idle", 4.0, 6.0, ""]]],
	],
	"utah": [
		[3.0, [["gallery_crates", "PickUp", 2.9, 2.9, ""], ["gallery_river", "PutDown", 2.9, 2.9, "Carry"]]],
		[2.0, [["kegs", "PickUp", 2.9, 2.9, ""], ["rack_back", "PutDown", 2.9, 2.9, "Carry"]]],
		[3.0, [["bench", "WipeRifle", 8.0, 12.0, ""]]],
		[2.5, [["gallery_bench", "WipeRifle", 8.0, 12.0, ""]]],
		[1.5, [["gallery_window", "Idle", 4.0, 7.0, ""]]],
		[1.5, [["gallery_rack", "InspectRifle", 3.9, 3.9, ""], ["gallery_rack", "Idle", 2.0, 3.0, ""]]],
		[1.0, [["shelves", "Reach", 2.9, 2.9, ""], ["shelves", "Idle", 2.0, 3.0, ""]]],
		[1.0, [["well_view", "Talk", 5.0, 8.0, ""]]],
	],
}

static var _stair_owner: Object = null       # one man on the stair at a time (shared by both brains)

var who: String = ""
var folk: Ep2TownFolk = null
var xf: Transform3D = Transform3D.IDENTITY   # the building's transform (local -> world)
var spots: Dictionary = {}                   # name -> local Vector3 (from the GLB's Spot_* empties)
var walk_speed: float = 0.8                  # matched to the Walk clip's stride at this man's scale (no foot skating)
var rng := RandomNumberGenerator.new()
var state: String = "idle"                   # idle | walk | wait (stair taken) | work | react
var spot: String = ""                        # last spot reached
var visits_upstairs: int = 0
var greet_count: int = 0

var _steps: Array = []                       # remaining steps of the current task
var _route: Array = []                       # remaining spot names to walk
var _step_clip: String = ""
var _step_walk: String = ""
var _t: float = 0.0
var _player_inside: bool = false
var _react_t: float = 0.0
var _wait_t: float = 0.0
var _adj: Dictionary = {}
## DIRECTED: a story beat has him (Rich shows the Sharps, Utah takes Lil Blunt out to the Gatling). While directed he runs no tasks and makes no
## greetings; `release()` hands him back to his work from wherever he stands.
var directed: bool = false
var directed_spot: String = ""
var _announced: bool = false
var _directed_face: Vector3 = Vector3.INF
var _directed_face_world: bool = false


func setup(p_who: String, p_folk: Ep2TownFolk, p_xf: Transform3D, p_spots: Dictionary, start_spot: String, seed: int) -> void:
	who = p_who
	folk = p_folk
	xf = p_xf
	spots = p_spots
	rng.seed = seed
	for e in EDGES:
		if spots.has(e[0]) and spots.has(e[1]):
			_adj.get_or_add(e[0], []).append(e[1])
			_adj.get_or_add(e[1], []).append(e[0])
	folk.use_height = true
	folk.clip_blend = 0.25
	spot = start_spot
	folk.place(world(start_spot))
	_face_local(FACE.get(start_spot, Vector3(0, 0, -2)))
	_next_task()


func world(name: String) -> Vector3:
	return xf * (spots[name] as Vector3)


func local_of(p: Vector3) -> Vector3:
	return xf.affine_inverse() * p


func on_gallery() -> bool:
	return folk.floor_y() > 1.9


func step(delta: float, player_world: Vector3) -> void:
	if folk == null:
		return
	_t -= delta
	if not directed:
		_react(delta, player_world)
	match state:
		"walk":
			if not folk.is_walking():
				_arrive_leg()
		"work":
			if directed:
				if not _announced:
					_announced = true
					directed_arrived.emit(who, spot)
			elif _t <= 0.0:
				_next_step()
		"wait":
			_wait_t -= delta
			if _wait_t <= 0.0:
				_walk_leg()
		"react":
			_react_t -= delta
			if _react_t <= 0.0:
				state = "work"
				_t = 0.5
		_:
			_next_task()
	folk.step(delta)


# --- directed beats -------------------------------------------------------------------------------------------------------

## Walk to `goal` (a spot name in this brain's graph) along the normal routes (stair reservation, the counter's gaps), then play `clip` there facing
## the local point `face` (or a world point when `face_world` is true) until `release()`. Emits `directed_arrived` once he is there.
func direct(goal: String, clip: String, face: Vector3 = Vector3.INF, face_world: bool = false) -> bool:
	if not spots.has(goal):
		return false
	directed = true
	_announced = false
	directed_spot = goal
	if _stair_owner == self and spot not in ["stair_head", "stair_foot"]:
		_stair_owner = null
	_directed_face = face
	_directed_face_world = face_world
	_steps = [[goal, clip, 1.0e6, 1.0e6, ""]]
	state = "idle"
	_next_step()
	return true


## Change what a directed man does where he stands (play another clip, turn to another point) without walking.
func direct_here(clip: String, face: Vector3 = Vector3.INF, face_world: bool = false) -> void:
	directed = true
	if face != Vector3.INF:
		folk.face_point(face if face_world else xf * face)
	folk.hold_clip(clip)


func release() -> void:
	directed = false
	directed_spot = ""
	_announced = false
	_steps = []
	_route = []
	if state != "walk":
		state = "idle"


# --- reactions ------------------------------------------------------------------------------------------------------------

func _react(delta: float, player_world: Vector3) -> void:
	var lp: Vector3 = local_of(player_world)
	var inside: bool = lp.z < -0.3 and lp.z > -11.8 and absf(lp.x) < 4.9
	if inside and not _player_inside and state != "walk":
		# he just came in: turn to him; Rich greets (and heads to his counter after), Utah nods if he is downstairs
		folk.face_point(player_world)
		if who == "rich" or not on_gallery():
			folk.hold_clip("Greet")
			greet_count += 1
			greeted.emit(who)
			state = "react"
			_react_t = 2.2 if who == "rich" else 1.2
			if who == "rich" and spot != "counter_rich" and not on_gallery():
				_steps = [["counter_rich", "Counter", 8.0, 14.0, ""]]
	_player_inside = inside
	# at the counter: Rich stays put at his side of it, facing the customer
	if who == "rich" and inside and lp.distance_to(spots.get("player", Vector3(0.2, 0, -3.4))) < 1.8 and spot == "counter_rich" and state == "work":
		folk.face_point(player_world)
		_t = maxf(_t, 1.0)


# --- tasks ------------------------------------------------------------------------------------------------------------------

func _next_task() -> void:
	var list: Array = TASKS.get(who, [])
	if list.is_empty():
		return
	var total: float = 0.0
	for t in list:
		total += float(t[0])
	var r: float = rng.randf() * total
	for t in list:
		r -= float(t[0])
		if r <= 0.0:
			_steps = (t[1] as Array).duplicate(true)
			break
	_next_step()


func _next_step() -> void:
	if _steps.is_empty():
		_next_task()
		return
	var s: Array = _steps.pop_front()
	_step_clip = str(s[1])
	_step_walk = str(s[4])
	_t = rng.randf_range(float(s[2]), float(s[3]))
	var goal: String = str(s[0])
	if goal == spot:
		_begin_work(goal)
		return
	_route = _path(spot, goal)
	if _route.is_empty():
		_begin_work(spot)                # unreachable (missing spot): work where he stands
		return
	_walk_leg()


func _walk_leg() -> void:
	var nxt: String = _route[0]
	if [spot, nxt] == STAIR_EDGE or [nxt, spot] == STAIR_EDGE:
		if _stair_owner != null and _stair_owner != self:
			# the other one is on the stair: wait a beat at the foot/head, then try again
			folk.stop()
			folk.hold_clip("Idle")
			state = "wait"
			_wait_t = 1.0 + rng.randf() * 1.5
			return
		_stair_owner = self
		folk.walk_clip = "StairsUp" if nxt == "stair_head" else "Walk"
	else:
		folk.walk_clip = _step_walk if _step_walk != "" else "Walk"
	var locomotion_player: AnimationPlayer = folk.anim_player()
	if locomotion_player != null and folk.walk_clip in ["Walk", "Carry"] and locomotion_player.has_animation("Grounded" + folk.walk_clip):
		folk.walk_clip = "Grounded" + folk.walk_clip
	folk.walk_to(world(nxt), walk_speed * (0.85 if folk.walk_clip == "StairsUp" else 1.0))
	state = "walk"


func _arrive_leg() -> void:
	if _route.is_empty():
		_begin_work(spot)
		return
	var reached: String = _route.pop_front()
	if _stair_owner == self and reached in ["stair_head", "stair_foot"] and spot in ["stair_head", "stair_foot"]:
		_stair_owner = null
	if reached == "stair_top" and spot == "stair_head":
		visits_upstairs += 1
	spot = reached
	if _route.is_empty():
		_begin_work(spot)
	else:
		_walk_leg()


func _begin_work(at: String) -> void:
	state = "work"
	folk.walk_clip = "Walk"
	if directed and _directed_face != Vector3.INF:
		folk.face_point(_directed_face if _directed_face_world else xf * _directed_face)
	else:
		_face_local(FACE.get(at, Vector3(0, 0, -2)))
	folk.hold_clip(_step_clip)


func _face_local(p: Vector3) -> void:
	folk.face_point(xf * p)


## Breadth-first shortest hop path over the spot graph (the graph is tiny and its edges short, so hops ~ distance).
func _path(from: String, to: String) -> Array:
	if not _adj.has(from) or not _adj.has(to):
		return []
	var prev: Dictionary = {from: ""}
	var q: Array = [from]
	while not q.is_empty():
		var c: String = q.pop_front()
		if c == to:
			break
		for n in _adj[c]:
			if not prev.has(n):
				prev[n] = c
				q.append(n)
	if not prev.has(to):
		return []
	var out: Array = []
	var c2: String = to
	while c2 != from:
		out.push_front(c2)
		c2 = prev[c2]
	return out
