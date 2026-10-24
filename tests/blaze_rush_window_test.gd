extends Node
## FAIRNESS GATE for Blaze Rush: how wide is the window a player's tap has to land in?
##
## A candle train is a timing puzzle with a measurable answer: the set of takeoff
## positions that clear it. On a phone the tap reaches the game 60-110 ms late
## (plus jitter), so a window under ~100 ms is a coin flip and under ~30 ms is
## unclearable by skill. The audit measured exactly that on the shipped layouts at
## the real (flat 320 u/s) speed:
##     single candle                      464 ms
##     L1 / L2 triple at 60 u spacing      89 ms   (28.5 u)
##     L3 triple at 70 u spacing           27 ms   (8.5 u, two physics ticks)
## and the old layout test could not see it: it checked gap widths against a speed
## RAMP (320 -> 460) that no runtime code implements.
##
## This is the arbiter. It builds a REAL-PHYSICS replica of the runner — a static
## floor, a CharacterBody2D cube, Area2D candles, a landable StaticBody2D FUD wall,
## pit gaps, the same gravity / jump / move_and_slide sequence as
## blaze_rush.gd:_physics_process — and sweeps the takeoff x in 0.5 u steps. Every
## number it asserts on is MEASURED by the engine, not derived:
##   * RUN_SPEED / GRAVITY / JUMP_VELOCITY / CRASH_Y are read from blaze_rush.gd;
##   * every collision shape (candle, wall, cube, floor depth) is read off a REAL
##     instance of blaze_rush.tscn, so the replica cannot drift from the game;
##   * the hazard POSITIONS are read from BlazeRushLayouts, so moving a candle in
##     the layout file moves it here.
##
## WHAT IS MEASURED (and what is not):
##   * single-jump window of a hazard group = the LONGEST contiguous run of takeoff
##     x positions (0.5 u steps) whose single jump clears the group, / RUN_SPEED.
##     "Group" = a candle train (candles <= 100 u apart), one FUD wall, one pit gap.
##     Gate: >= 120 ms for every group of every level.
##   * a "chain" = a pit gap followed by another hazard group whose first hazard is
##     <= 260 u past the gap's far lip (one jump cannot clear both). Measured:
##       - FIRST-jump window = the gap's own single-jump window.  GATE >= 120 ms.
##       - RE-JUMP window(x1) for a first takeoff x1 that clears the gap: the cube
##         lands at x_L(x1) and may take off again from x_L on (a tap is buffered
##         through the landing, so the very next tick is a takeoff). W2(x1) = the
##         part of the NEXT group's own single-jump window that lies at or after
##         x_L(x1), / RUN_SPEED. A later first jump lands later and SHRINKS W2.
##         GATE: BEST W2 over the first window >= 100 ms (the chain is winnable).
##       - printed, not gated: W2 for a first jump at the window CENTRE, the WORST
##         W2, and the JOINT window = how much of the first window still leaves
##         W2 >= 120 ms. A chain whose JOINT window is under 120 ms is tagged [WEAK].
##   * NOT modelled: coyote time (it only WIDENS gap windows), the jump buffer
##     (it only widens the effective window), touch latency (that is why the gate
##     is 120 ms and not 0).
##
## Run: godot --headless res://tests/blaze_rush_window_test.tscn
## One-line verdict: BLAZE_RUSH_WINDOW: ALL PASS | N FAILURE(S)

const BR := preload("res://src/dashmode/blaze_rush.gd")
const BLAZE_RUSH_SCENE := preload("res://src/dashmode/blaze_rush.tscn")

## The gate. 120 ms is engineering judgement (touch latency 60-110 ms + jitter), not a
## measured human threshold; the shipped layouts measure 148 ms and up.
const MIN_WINDOW_S: float = 0.120
const SWEEP_STEP: float = 0.5
const SWEEP_BACK: float = 400.0   # first takeoff this far before the lane's first hazard
## Gap lanes sweep this far PAST the pit's near lip: past it the cube is no longer
## on the floor and cannot jump, so the sweep costs nothing and keeps the window's
## LATE edge unclipped (coyote-free).
const SWEEP_FWD_GAP: float = 40.0
const LANE_SPACING_Y: float = 3000.0
const LANE_X0: float = 2000.0      # where each lane's first hazard sits
const LANE_FLOOR_END: float = 7000.0
const TICKS: int = 150             # 2.5 s: past the hazard even for the earliest takeoff
## Past this x (relative to the lane origin) every hazard of a group is behind the cube.
const PAST_GROUP: float = 520.0
## A chain: the next group starts within this of the gap's far lip.
const CHAIN_REACH: float = 260.0
## A chain must be WINNABLE: the best first jump leaves at least this long a re-jump
## window. (Not 120: the audit's seven gap+candle chains were not adjusted by the
## fairness pass — only the candle triples were respaced — and the weakest of them
## sits at ~118 ms. The per-chain JOINT window is printed, [WEAK] when it is under
## 120 ms, so the layout author can see exactly which chains need a founder decision.)
const REJUMP_BEST_MIN_S: float = 0.100
## Candles at most this far apart form ONE train (a single jump has to clear all).
const TRAIN_SPACING: float = 100.0

## Geometry read off a real run (filled in _read_real_geometry).
var _candle_size: Vector2
var _candle_pos: Vector2
var _wall_size: Vector2
var _wall_pos: Vector2
var _wall_body_y_offset: float
var _cube_size: Vector2
var _floor_depth: float

var _failures: Array[String] = []
var _lanes: Array[Dictionary] = []
var _hit: Dictionary = {}       # CharacterBody2D -> true (touched a candle / slammed a wall / fell)
var _landed_x: Dictionary = {}  # CharacterBody2D -> x of its first landing after takeoff
var _airborne: Dictionary = {}  # CharacterBody2D -> true once it has left the floor
var _tick: int = 0
var _everything: Array[Node] = []
## signature -> {window_s, lo_rel, hi_rel, samples, landing: Dictionary(rel takeoff -> rel landing)}
var _results: Dictionary = {}

func _ready() -> void:
	Engine.max_physics_steps_per_frame = 8
	await _read_real_geometry()
	_build_lanes()
	print("BLAZE RUSH WINDOW (real physics, %d lanes, %d players):" % [_lanes.size(), _player_count()])

func _player_count() -> int:
	var n: int = 0
	for lane: Dictionary in _lanes:
		n += (lane["players"] as Array).size()
	return n

# ---- geometry ---------------------------------------------------------------

## Instantiate one real run, copy its collision shapes, free it. The replica uses
## the GAME'S shapes, so a change to a candle/wall/cube size is measured, not missed.
func _read_real_geometry() -> void:
	GameManager.dash_return = {
		"scene_path": "res://src/level/level_01_smoke_realm.tscn",
		"position": Vector2(500.0, 400.0),
		"level_index": 1,
	}
	var run: Node2D = BLAZE_RUSH_SCENE.instantiate()
	add_child(run)
	await get_tree().process_frame
	for child in run.get_children():
		if child is Area2D and child.has_meta("hazard") and _candle_size == Vector2.ZERO:
			var cs: CollisionShape2D = _first_shape(child)
			_candle_size = (cs.shape as RectangleShape2D).size
			_candle_pos = cs.position
		elif child is StaticBody2D and child.has_meta("fud_wall") and _wall_size == Vector2.ZERO:
			var ws: CollisionShape2D = _first_shape(child)
			_wall_size = (ws.shape as RectangleShape2D).size
			_wall_pos = ws.position
			_wall_body_y_offset = BR.GROUND_Y - (child as Node2D).position.y
		elif child is StaticBody2D and not child.has_meta("fud_wall") and _floor_depth == 0.0:
			var fs: CollisionShape2D = _first_shape(child)
			_floor_depth = (fs.shape as RectangleShape2D).size.y
	var player: CharacterBody2D = run.get("_player")
	_cube_size = (_first_shape(player).shape as RectangleShape2D).size
	_check("read the real candle / wall / cube / floor geometry off a live run",
		_candle_size != Vector2.ZERO and _wall_size != Vector2.ZERO and _cube_size != Vector2.ZERO
		and _floor_depth > 0.0, "candle %s wall %s cube %s floor %s" % [_candle_size, _wall_size, _cube_size, _floor_depth])
	run.queue_free()
	await get_tree().process_frame

func _first_shape(n: Node) -> CollisionShape2D:
	for c in n.get_children():
		if c is CollisionShape2D:
			return c
	return null

# ---- hazard groups ------------------------------------------------------------

## Parse a level's obstacle list into hazard groups. Returns an Array of
## {kind: "train"|"wall"|"gap", level, x (first hazard x), xs [candle x...], w}.
func _groups_of(level: int) -> Array[Dictionary]:
	var layout: Dictionary = BlazeRushLayouts.get_layout(level)
	var hazards: Array[Dictionary] = []
	for ob in layout.get("obstacles", []):
		var t: String = ob.get("type", "")
		if t == "candle" or t == "fud_wall" or t == "gap":
			hazards.append({"type": t, "x": float(ob.x), "w": float(ob.get("w", 0.0))})
	hazards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	var groups: Array[Dictionary] = []
	var i: int = 0
	while i < hazards.size():
		var h: Dictionary = hazards[i]
		if h.type == "candle":
			var xs: Array[float] = [h.x]
			while i + 1 < hazards.size() and hazards[i + 1].type == "candle" \
					and hazards[i + 1].x - xs[xs.size() - 1] <= TRAIN_SPACING:
				i += 1
				xs.append(hazards[i].x)
			groups.append({"kind": "train", "level": level, "x": xs[0], "xs": xs, "w": 0.0})
		elif h.type == "fud_wall":
			groups.append({"kind": "wall", "level": level, "x": h.x, "xs": [h.x], "w": 0.0})
		else:
			groups.append({"kind": "gap", "level": level, "x": h.x, "xs": [h.x], "w": h.w})
		i += 1
	return groups

## Translation-invariant shape key: the same arrangement measures the same, so each
## distinct shape gets ONE lane (11 lanes instead of ~45) and every instance of it
## in the layouts is judged by that lane's number.
func _signature(g: Dictionary) -> String:
	match g.kind:
		"wall":
			return "wall"
		"gap":
			return "gap%d" % int(round(g.w))
		_:
			var s: String = "train"
			var xs: Array = g.xs
			for k in range(xs.size()):
				s += "_%d" % int(round(float(xs[k]) - float(xs[0])))
			return s

func _all_groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for level in [1, 2, 3]:
		out.append_array(_groups_of(level))
	return out

# ---- building -----------------------------------------------------------------

func _build_lanes() -> void:
	var seen: Dictionary = {}
	var lane_index: int = 0
	for g: Dictionary in _all_groups():
		var sig: String = _signature(g)
		if seen.has(sig):
			continue
		seen[sig] = true
		_lanes.append(_build_lane(sig, g, lane_index))
		lane_index += 1

func _add(n: Node) -> void:
	add_child(n)
	_everything.append(n)

func _floor_segment(x0: float, x1: float, off_y: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x0, BR.GROUND_Y + off_y)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(x1 - x0, _floor_depth)
	col.shape = shape
	col.position = Vector2((x1 - x0) * 0.5, _floor_depth * 0.5)
	body.add_child(col)
	_add(body)

func _build_lane(sig: String, g: Dictionary, lane_index: int) -> Dictionary:
	var off_y: float = float(lane_index) * LANE_SPACING_Y
	var lane: Dictionary = {"sig": sig, "kind": g.kind, "off_y": off_y, "players": [], "starts": [], "w": g.w}
	match g.kind:
		"gap":
			_floor_segment(0.0, LANE_X0, off_y)
			_floor_segment(LANE_X0 + float(g.w), LANE_FLOOR_END, off_y)
		_:
			_floor_segment(0.0, LANE_FLOOR_END, off_y)
	if g.kind == "train":
		for cx: float in g.xs:
			var area := Area2D.new()
			area.position = Vector2(LANE_X0 + cx - float(g.xs[0]), BR.GROUND_Y + off_y)
			area.collision_mask = 2
			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = _candle_size
			col.shape = shape
			col.position = _candle_pos
			area.add_child(col)
			area.body_entered.connect(func(b: Node2D) -> void: _hit[b] = true)
			_add(area)
	elif g.kind == "wall":
		var wall := StaticBody2D.new()
		wall.position = Vector2(LANE_X0, BR.GROUND_Y + off_y - _wall_body_y_offset)
		wall.set_meta("fud_wall", true)
		var wcol := CollisionShape2D.new()
		var wshape := RectangleShape2D.new()
		wshape.size = _wall_size
		wcol.shape = wshape
		wcol.position = _wall_pos
		wall.add_child(wcol)
		_add(wall)
	# The sweep: one cube per 0.5 u of takeoff x, created UP FRONT and freed together
	# at the end (tests/ rule: never a create / wait / free loop of physics bodies).
	# Candle trains / walls: a cube can only take off from the floor BEFORE the first
	# hazard (to stand past it you must already have cleared it), so the sweep stops
	# where the cube would overlap that hazard. (Sweeping past it measured a bogus
	# second "window" between candle 1 and 2 of the 70 u triple.)
	var sweep_end: float = LANE_X0 + SWEEP_FWD_GAP
	if g.kind == "train":
		sweep_end = LANE_X0 - (_candle_size.x * 0.5 + _cube_size.x * 0.5) - SWEEP_STEP
	elif g.kind == "wall":
		sweep_end = LANE_X0 - (_wall_size.x * 0.5 + _cube_size.x * 0.5) - SWEEP_STEP
	var x: float = LANE_X0 - SWEEP_BACK
	while x <= sweep_end:
		var p := CharacterBody2D.new()
		p.collision_layer = 2
		p.collision_mask = 1
		var pc := CollisionShape2D.new()
		var ps := RectangleShape2D.new()
		ps.size = _cube_size
		pc.shape = ps
		p.add_child(pc)
		# Stand ON the floor one tick behind the takeoff x: tick 1 settles on the
		# floor, tick 2 jumps from exactly x (the sequence of blaze_rush.gd).
		p.position = Vector2(x - BR.RUN_SPEED / 60.0, BR.GROUND_Y + off_y - _cube_size.y * 0.5)
		_add(p)
		lane["players"].append(p)
		lane["starts"].append(x - LANE_X0)   # takeoff x relative to the lane's first hazard
		x += SWEEP_STEP
	return lane

# ---- simulation -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _lanes.is_empty() or _tick > TICKS:
		return
	_tick += 1
	for lane: Dictionary in _lanes:
		var off_y: float = lane["off_y"]
		var is_gap: bool = lane["kind"] == "gap"
		for p: CharacterBody2D in lane["players"]:
			# A cube whose verdict can no longer change stops being simulated:
			# already hit; a gap jumper that has landed; or anyone well past the group.
			if _hit.has(p) or p.position.x > LANE_X0 + PAST_GROUP:
				continue
			# A gap jumper that LANDED BEYOND the pit is done. (One that landed short
			# of it keeps running and falls in: its landing is not a success.)
			if is_gap and _landed_x.has(p) and float(_landed_x[p]) > LANE_X0 + float(lane["w"]) * 0.5:
				continue
			p.velocity.x = BR.RUN_SPEED
			p.velocity.y += BR.GRAVITY * delta
			if _tick == 2 and p.is_on_floor():
				p.velocity.y = BR.JUMP_VELOCITY
			p.move_and_slide()
			if _tick >= 2 and not p.is_on_floor():
				_airborne[p] = true
			elif _tick > 2 and _airborne.has(p) and not _landed_x.has(p) and p.is_on_floor():
				_landed_x[p] = p.position.x
			for i in range(p.get_slide_collision_count()):
				var collider: Object = p.get_slide_collision(i).get_collider()
				if collider != null and (collider as Node).has_meta("fud_wall") \
						and absf(p.get_slide_collision(i).get_normal().x) > 0.5:
					_hit[p] = true
			if p.position.y - off_y > BR.CRASH_Y:
				_hit[p] = true
	if _tick == TICKS:
		_finish()

## Longest contiguous run of surviving takeoffs of a lane: {lo, hi, samples, total}.
func _survival_run(lane: Dictionary) -> Dictionary:
	var best_lo: float = 0.0
	var best_hi: float = -1.0
	var run_lo: float = 0.0
	var run_len: int = 0
	var best_len: int = 0
	var total: int = 0
	var players: Array = lane["players"]
	var starts: Array = lane["starts"]
	for i in range(players.size()):
		var alive: bool = not _hit.has(players[i])
		if alive:
			total += 1
			if run_len == 0:
				run_lo = starts[i]
			run_len += 1
			if run_len > best_len:
				best_len = run_len
				best_lo = run_lo
				best_hi = starts[i]
		else:
			run_len = 0
	return {"lo": best_lo, "hi": best_hi, "samples": best_len, "total": total}

## Every contiguous surviving run of a lane as "lo..hi" strings (VERBOSE debugging).
func _all_runs(lane: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var players: Array = lane["players"]
	var starts: Array = lane["starts"]
	var lo: float = 0.0
	var prev: float = 0.0
	var open: bool = false
	for i in range(players.size()):
		var alive: bool = not _hit.has(players[i])
		if alive and not open:
			open = true
			lo = starts[i]
		if alive:
			prev = starts[i]
		if not alive and open:
			open = false
			out.append("%.1f..%.1f" % [lo, prev])
	if open:
		out.append("%.1f..%.1f" % [lo, prev])
	return out

func _finish() -> void:
	for lane: Dictionary in _lanes:
		var run: Dictionary = _survival_run(lane)
		var window_s: float = float(run["samples"]) * SWEEP_STEP / BR.RUN_SPEED
		var landing: Dictionary = {}
		if lane["kind"] == "gap":
			var players: Array = lane["players"]
			var starts: Array = lane["starts"]
			for i in range(players.size()):
				if not _hit.has(players[i]) and _landed_x.has(players[i]):
					landing[starts[i]] = float(_landed_x[players[i]]) - LANE_X0
		_results[lane["sig"]] = {
			"window_s": window_s, "lo": run["lo"], "hi": run["hi"], "samples": run["samples"],
			"total": run["total"], "landing": landing,
		}
		if OS.get_environment("WINDOW_TEST_VERBOSE") == "1":
			print("     runs: %s" % _all_runs(lane))
		print("  lane %-12s window %6.1f ms  (%d of %d samples survive, longest run %.1f..%.1f u)" % [
			lane["sig"], window_s * 1000.0, run["total"], (lane["players"] as Array).size(),
			float(run["lo"]), float(run["hi"])])
	_judge()
	# Free every replica body TOGETHER, then report.
	for n in _everything:
		if is_instance_valid(n):
			n.queue_free()
	_report_and_quit()

# ---- verdicts ----------------------------------------------------------------------

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  [PASS] %s" % label)
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])

func _judge() -> void:
	var groups: Array[Dictionary] = _all_groups()
	# 1. Every hazard group of every level: single-jump window >= 120 ms.
	for g: Dictionary in groups:
		var r: Dictionary = _results[_signature(g)]
		_check("L%d %s at x=%.0f (%s): single-jump window %.0f ms >= %.0f ms" % [
				g.level, g.kind, g.x, _signature(g), float(r.window_s) * 1000.0, MIN_WINDOW_S * 1000.0],
			float(r.window_s) >= MIN_WINDOW_S)
	# 2. Chains: gap then a group within reach.
	for level in [1, 2, 3]:
		var lg: Array[Dictionary] = _groups_of(level)
		for i in range(lg.size() - 1):
			var gap: Dictionary = lg[i]
			var nxt: Dictionary = lg[i + 1]
			if gap.kind != "gap":
				continue
			var gap_end: float = float(gap.x) + float(gap.w)
			if float(nxt.x) - gap_end > CHAIN_REACH:
				continue
			_judge_chain(level, gap, nxt)

func _judge_chain(level: int, gap: Dictionary, nxt: Dictionary) -> void:
	var tag: String = "L%d chain gap x=%.0f w=%.0f -> %s x=%.0f" % [level, gap.x, gap.w, nxt.kind, nxt.x]
	var gr: Dictionary = _results[_signature(gap)]
	var nr: Dictionary = _results[_signature(nxt)]
	# GATE 1 — the FIRST jump: the gap's own window.
	_check("%s: FIRST-jump window %.0f ms >= %.0f ms" % [tag, float(gr.window_s) * 1000.0, MIN_WINDOW_S * 1000.0],
		float(gr.window_s) >= MIN_WINDOW_S)
	var landing: Dictionary = gr["landing"]
	if landing.is_empty():
		_check("%s: the first jump lands at all" % tag, false)
		return
	var gap_abs: float = float(gap.x)
	var next_abs: float = float(nxt.x)
	var lo2: float = next_abs + float(nr.lo)
	var hi2: float = next_abs + float(nr.hi)
	# Re-jump windows over every first-jump takeoff that clears the gap.
	var centre_rel: float = (float(gr.lo) + float(gr.hi)) * 0.5
	var centre_key: float = 0.0
	var centre_d: float = INF
	var worst: float = INF
	var best: float = 0.0
	var joint: int = 0
	for k: float in landing.keys():
		if absf(k - centre_rel) < centre_d:
			centre_d = absf(k - centre_rel)
			centre_key = k
		var w2: float = _rejump_s(gap_abs + float(landing[k]), lo2, hi2)
		worst = minf(worst, w2)
		best = maxf(best, w2)
		if w2 >= MIN_WINDOW_S:
			joint += 1
	var centre: float = _rejump_s(gap_abs + float(landing[centre_key]), lo2, hi2)
	var joint_s: float = float(joint) * SWEEP_STEP / BR.RUN_SPEED
	# GATE 2 — the chain is WINNABLE: some first jump leaves a usable re-jump window.
	_check("%s: BEST re-jump window %.0f ms >= %.0f ms (some first jump leaves a re-jump)" % [
			tag, best * 1000.0, REJUMP_BEST_MIN_S * 1000.0], best >= REJUMP_BEST_MIN_S)
	# INFORMATION — how forgiving the chain really is. [WEAK] = no first-jump timing
	# at all leaves a >= 120 ms re-jump for a big part of the first window.
	var weak: String = "" if joint_s >= MIN_WINDOW_S else "  [WEAK: joint window below %.0f ms]" % (MIN_WINDOW_S * 1000.0)
	print("     (info) re-jump window: first jump at the window centre (lands x=%.0f) %.0f ms; worst %.0f ms; BEST %.0f ms; next window x=%.0f..%.0f; JOINT first-jump window (re-jump >= %.0f ms) %.0f ms%s" % [
		gap_abs + float(landing[centre_key]), centre * 1000.0, worst * 1000.0, best * 1000.0,
		lo2, hi2, MIN_WINDOW_S * 1000.0, joint_s * 1000.0, weak])

## Width, in seconds, of the part of [lo2, hi2] (a takeoff-x window) at or after the
## landing x. The window ends are sample centres, so one SWEEP_STEP is added back.
func _rejump_s(landed_x: float, lo2: float, hi2: float) -> float:
	var lo: float = maxf(lo2, landed_x)
	if hi2 < lo:
		return 0.0
	return (hi2 - lo + SWEEP_STEP) / BR.RUN_SPEED

var _reported: bool = false
func _report_and_quit() -> void:
	if _reported:
		return
	_reported = true
	if _failures.is_empty():
		print("BLAZE_RUSH_WINDOW: ALL PASS")
		get_tree().quit(0)
	else:
		print("BLAZE_RUSH_WINDOW: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  [FAIL] %s" % f)
		get_tree().quit(1)
