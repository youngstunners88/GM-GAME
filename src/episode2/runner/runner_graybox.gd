class_name RunnerGraybox
extends Node3D
## Episode 2 — Gold Mine Runner: SIMULATION. (File/class keep the "graybox"
## name so the session root, tests and scene uid don't churn; the art now lives
## in runner_view.gd, the surfaces in src/episode2/art/ep2_palette.gd, and the
## layout in tracks/*.json.)
##
## This script is pure gameplay logic: it contains NO rendering code at all.
## Everything visible (tunnel, carts, props, hazards, telegraphs, camera,
## environment/sun art pass, reticle/ammo HUD) is built by the child "View"
## node, which only reads this sim through its accessors and signals. So every
## rule here stays headless-testable with no renderer.
##
## Deliberately self-contained: it pulls in none of the Episode-1-specific
## gameplay autoloads (StateMachine, GameManager, etc.) so the runner can be
## reasoned about and headless-tested in isolation.
## `AudioManager` is the one exception — it's a project-wide music/audio
## singleton already used across every episode/level.
##
## Mode model: the runner is one of the two modes under the persistent session
## root. It emits `chamber_reached` at the chamber entrance; it does NOT load
## the chamber itself.
##
## Hazard model (docs/model-responses/2026-09-06-grok-ep2-runner-hazards.md):
##   - "box"     (legacy/default): cleared by jump.
##   - "arrow"   : only ducking (held DUCK_MIN_HOLD) or another lane clears it —
##                 or shooting its archer first.
##   - "boulder" : neither jump nor duck: hop to another rail's cart.
##   - "boarder" : a bear leaps INTO the rider's cart. `"lane": -1` means
##                 "whichever cart the rider is in". Only the pickaxe swipe
##                 (swipe(), SWIPE_WINDOW) knocks it off; jump/duck/hop don't.
##
## Carts: one cart per rail, running as a convoy; a lane switch is Lil Blunt
## HOPPING between carts. `$Cart` is the RIDER anchor.
##
## CART ATTRITION (founder, 2026-09-27 — "a smashed cart is no more available"):
## a boulder SMASHES whatever cart is on its rail, rider or not. A wrecked rail is
## dead: you cannot hop onto it, and a hop can only reach an ADJACENT live cart,
## so a dead centre cart splits the convoy. A rail comes back only when the track
## rolls a fresh cart in from a siding ("rail_events" type "spawn"); a rail can
## also END at a buffer stop ("end"), wrecking any cart still on it. If the
## rider's own cart is wrecked he takes a hit and is thrown to the nearest live
## cart; with no live cart left he is DERAILED and the run fails.
##
## SPEED ramps from the leg's base to its max over SPEED_RAMP_DIST metres.
## GOLD: "gold" obstacles are pickups, collected by passing through them.
##
## Zipline: earned by being airborne at a segment's start_z; chained cables
## need a transfer jump near each end; a miss/drop costs ONE health per chain.
## While hooked, lane-switching and duck are suspended and cart-phase hazards
## don't apply.
##
## Archers + the GOLDEN REVOLVER (founder lock 2026-09-26): balaclava bears on
## scaffolds beside the track. The sim OWNS their world placement
## (archer_world_pos) so the mouse ray test and the drawn bear agree exactly.
## The revolver holds CYLINDER rounds; empty auto-reloads over RELOAD_TIME, R
## reloads manually. Two ways to fire:
##   - fire_ray(origin, dir): mouse aim — ray-sphere against living archers.
##   - shoot(): keyboard auto-aim at the nearest archer ahead (J/Enter).
## Both obey the same cylinder/reload/cooldown rules and consume a round.

## Emitted once when the cart reaches the chamber entrance; the run halts.
signal chamber_reached
## Emitted each time an obstacle is struck; carries remaining health.
signal obstacle_hit(remaining_health: int)
## Emitted when health hits zero.
signal run_failed
## Emitted when the axe hooks a cable (first cable of a chain, or a swing to the next).
signal zip_caught(segment_index: int)
## Emitted when a zipline is missed or dropped; the health cost arrives via obstacle_hit.
signal zip_missed(segment_index: int)
## Emitted on every shot fired (hit or miss) — drives muzzle flash / sound.
signal shot_fired
## Emitted when a shot drops an archer; its pending arrows are already cancelled.
signal archer_down(archer_id: String)
## Emitted after every fired shot with the archer hit ("" for a miss) and the
## point the bullet ended at (hit point, or far along the ray).
signal shot_resolved(hit_id: String, point: Vector3)
## Trigger pulled on an empty cylinder (a reload starts automatically).
signal dry_fire
## Rounds left in the cylinder changed.
signal ammo_changed(ammo: int)
signal reload_started
signal reload_finished
## A boarder was knocked off the cart by the pickaxe.
signal boarder_repelled
## The pickaxe swipe was started.
signal pickaxe_swing
## A rail's cart was destroyed. cause: "boulder" | "rail_end".
signal cart_wrecked(lane: int, cause: String)
## A fresh cart rolled onto a dead rail from a siding.
signal cart_spawned(lane: int)
## A hop was refused: the target rail has no cart (or is off the track).
signal hop_blocked(lane: int)
## The rider's cart was wrecked under him and he was thrown to another cart.
signal rider_bailed(from_lane: int, to_lane: int)
## Gold nugget picked up; carries the leg total.
signal gold_collected(total: int)

# --- Tuning (feel is tuned later, not law) ------------------------------------
const RUN_SPEED := 20.0            # BASE forward speed m/s (+Z); ramps to MAX_SPEED
const MAX_SPEED := 30.0
const SPEED_RAMP_DIST := 900.0     # metres from base to max speed
## Three rails. The camera looks down +Z, so world +X is SCREEN-LEFT: lane 0
## (reached with move_left / A) must be at +X.
const LANE_X := [2.5, 0.0, -2.5]
const LANE_SWITCH_SPEED := 22.0    # hop speed between rails (~0.11 s per rail)
const GRAVITY := 36.0
const JUMP_VELOCITY := 12.0        # ~0.67s airtime — clears an obstacle
const OBSTACLE_CLEAR_HEIGHT := 1.2 # cart y above this = jumped over it
const OBSTACLE_HIT_Z := 1.0        # z-window for a hit
const OBSTACLE_HIT_X := 0.8        # x-window (same-lane) for a hit
const START_HEALTH := 3
const DUCK_MIN_HOLD := 0.10        # seconds a duck must be held to block an arrow
## Float-accumulation slack for the duck-hold comparison (Kimi audit #1).
const DUCK_HOLD_EPSILON := 0.001
const ZIP_HEIGHT := 2.5            # rider Y while ziplining (above jump-clear height)
const ZIP_CATCH_MIN_Y := 0.6       # must be at least this high crossing start_z to hook the cable
const ZIP_TRANSFER_WINDOW := 6.0   # jump within this many units of a cable's end to swing on
const ZIP_CHAIN_GAP := 8.0         # cables closer than this form a chain (swing between them)
const SHOOT_RANGE_MIN := 4.0       # auto-aim: an archer closer than this is already beside/behind you
const SHOOT_RANGE_MAX := 60.0      # ~2.5s ahead at speed — visible on the scaffold
const SHOOT_COOLDOWN := 0.35       # hammer cadence; also stops shoot-spam trivialising volleys

# --- Revolver -----------------------------------------------------------------
const CYLINDER := 6
const RELOAD_TIME := 1.3
const RELOAD_EPSILON := 0.0001
## Archer placement — the ONE definition; the view reads these.
const ARCHER_X := 3.3              # ledge distance from track centre: clear of the tunnel rock (inner wall 4.2-5.8 m), above the outer cart
const ARCHER_Y := 2.2              # scaffold deck height (bear's feet)
const ARCHER_CHEST := 1.4          # chest above the deck — the ray target
const ARCHER_HIT_R := 1.1          # generous sphere: mouse aim at speed
const SHOT_MISS_RANGE := 60.0      # where a missed bullet is drawn to

# --- Pickaxe --------------------------------------------------------------------
const SWIPE_WINDOW := 0.6

# --- Carts / rails ----------------------------------------------------------------
var _cart_alive: Array = [true, true, true]
## [{"z": float, "lane": int, "type": "spawn"|"end", "done": bool}], sorted by z.
var _rail_events: Array = []
var _speed: float = RUN_SPEED
var _base_speed: float = RUN_SPEED
var _max_speed: float = MAX_SPEED
var _gold: int = 0

# --- Live state --------------------------------------------------------------
var _lane: int = 1                 # index into LANE_X; start centre
var _cart_y: float = 0.0
var _vy: float = 0.0
var _distance: float = 0.0         # world z travelled
var _health: int = START_HEALTH
var _running: bool = true
var _chamber_z: float = 200.0      # entrance distance

## Obstacles ahead: each {"z": float, "lane": int, "hit": bool, "type": String}.
## `type` in {"box", "arrow", "boulder", "boarder"} — defaults to "box".
var _obstacles: Array = []

# --- Duck (arrow defense) -----------------------------------------------------
var _duck_held: bool = false
var _duck_hold_time: float = 0.0

# --- Zipline ------------------------------------------------------------------
var _zip_segments: Array = []      # sorted by start_z in setup()
var _ziplining: bool = false
var _was_ziplining: bool = false  # edge-detects the zip→cart dismount frame
var _zip_index: int = -1           # cable currently hooked, or -1
var _zip_transfer_armed: bool = false
var _zip_resolved: Dictionary = {} # segment index -> true once caught/missed (judged exactly once)

# --- Archers + shooting -------------------------------------------------------
## Each {"id": String, "z": float, "side": int(-1 left / +1 right), "alive": bool}.
var _archers: Array = []
var _can_shoot: bool = false       # true once the revolver is in hand
var _shoot_cd: float = 0.0
var _ammo: int = CYLINDER
var _reloading: bool = false
var _reload_t: float = 0.0

# --- Pickaxe ------------------------------------------------------------------
var _swipe_t: float = 0.0

## Runner-section music (founder direction 2026-09-09). Routed through
## AudioManager so the Music bus and volume settings keep working.
const RUNNER_MUSIC_PLAYLIST := [
	"res://src/assets/music/runner_run.mp3",
	"res://src/assets/music/runner_run_1.mp3",
]

@onready var _cart: Node3D = $Cart

func _ready() -> void:
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)
	AudioManager.play_playlist(RUNNER_MUSIC_PLAYLIST, true)

## Configure the segment before/at spawn. Also resets all run state — safe to
## call again on a reused instance.
##
## `archers`: [{"id": String, "z": float, "side": -1|1}]. `can_shoot`: whether the
## revolver is in hand for this leg.
## `opts` (all optional): "rail_events" [{"z","lane","type":"spawn"|"end"}],
## "carts_start" [bool,bool,bool], "start_lane" int, "speed" {"base","max"}.
func setup(chamber_z: float, obstacles: Array = [], zip_segments: Array = [],
		archers: Array = [], can_shoot: bool = false, opts: Dictionary = {}) -> void:
	_chamber_z = chamber_z
	var cs: Array = opts.get("carts_start", [true, true, true])
	_cart_alive = []
	for i in LANE_X.size():
		_cart_alive.append(bool(cs[i]) if i < cs.size() else true)
	_rail_events = []
	var evs: Array = opts.get("rail_events", [])
	for e in evs:
		var ed: Dictionary = e
		_rail_events.append({"z": float(ed.get("z", 0.0)), "lane": int(ed.get("lane", 1)),
			"type": str(ed.get("type", "spawn")), "done": false})
	_rail_events.sort_custom(func(a, b): return float(a["z"]) < float(b["z"]))
	var sp: Dictionary = opts.get("speed", {})
	_base_speed = float(sp.get("base", RUN_SPEED))
	_max_speed = float(sp.get("max", MAX_SPEED))
	_speed = _base_speed
	_gold = 0
	_obstacles = obstacles.duplicate(true)
	for o in _obstacles:
		o["hit"] = false
		o["cancelled"] = false
		o["repelled"] = false
		if not o.has("type"):
			o["type"] = "box"
	_zip_segments = zip_segments.duplicate(true)
	_zip_segments.sort_custom(func(a, b): return float(a["start_z"]) < float(b["start_z"]))
	_archers = []
	for i in archers.size():
		var a: Dictionary = archers[i]
		_archers.append({
			"id": str(a.get("id", "archer_%d" % i)),
			"z": float(a.get("z", 0.0)),
			"side": -1 if int(a.get("side", 1)) < 0 else 1,
			"alive": true,
		})
	_can_shoot = can_shoot
	_shoot_cd = 0.0
	_ammo = CYLINDER
	_reloading = false
	_reload_t = 0.0
	_swipe_t = 0.0

	_lane = int(opts.get("start_lane", 1))
	if not _cart_alive[_lane]:
		_lane = _nearest_live_lane(_lane)
	_cart_y = 0.0
	_vy = 0.0
	_distance = 0.0
	_health = START_HEALTH
	_running = true
	_duck_held = false
	_duck_hold_time = 0.0
	_ziplining = false
	_was_ziplining = false
	_zip_index = -1
	_zip_transfer_armed = false
	_zip_resolved = {}
	var view := get_node_or_null("View")
	if view and view.has_method("rebuild"):
		view.rebuild(self)
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)

func _physics_process(delta: float) -> void:
	if not _running:
		return
	_advance(delta)

## Split out so a headless test can step the sim deterministically.
func step(delta: float) -> void:
	if _running:
		_advance(delta)

func _advance(delta: float) -> void:
	# Forward auto-run, ramping from base to max speed along the leg.
	_speed = lerpf(_base_speed, _max_speed, clampf(_distance / SPEED_RAMP_DIST, 0.0, 1.0))
	_distance += _speed * delta
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	_swipe_t = maxf(0.0, _swipe_t - delta)
	_advance_reload(delta)

	_update_zipline()
	if not _running:
		return  # a zip drop just cost the last health point

	# Duck hold time does NOT accumulate while ziplining (Kimi audit #5b).
	if _duck_held and not _ziplining:
		_duck_hold_time += delta
	else:
		_duck_hold_time = 0.0

	_update_rails()
	if not _running:
		return

	if _ziplining:
		_cart_y = ZIP_HEIGHT
		_vy = 0.0
		# The cable runs over the centre rail: slide to it, and land in that cart
		# (or the nearest live one when the centre cart is wrecked).
		var zl: int = 1 if _cart_alive[1] else _nearest_live_lane(1)
		if zl >= 0:
			_lane = zl
		if _cart:
			var zx: float = move_toward(_cart.position.x, float(LANE_X[1]), LANE_SWITCH_SPEED * delta)
			_cart.position = Vector3(zx, _cart_y, _distance)
		_was_ziplining = true
	else:
		if _was_ziplining:
			# Clean dismount: land back on the rail immediately (Kimi audit #5a).
			_cart_y = 0.0
			_vy = 0.0
			_was_ziplining = false
			if not _cart_alive[_lane]:
				_derail()
				return

		# Vertical (jump/gravity), clamped to the rail floor.
		if _cart_y > 0.0 or _vy != 0.0:
			_vy -= GRAVITY * delta
			_cart_y += _vy * delta
			if _cart_y <= 0.0:
				_cart_y = 0.0
				_vy = 0.0

		# Horizontal lerp toward the active rail.
		var target_x: float = LANE_X[_lane]
		var cur_x: float = _cart.position.x if _cart else target_x
		cur_x = move_toward(cur_x, target_x, LANE_SWITCH_SPEED * delta)

		if _cart:
			_cart.position = Vector3(cur_x, _cart_y, _distance)

		_check_obstacles(cur_x)

	if _distance >= _chamber_z:
		_running = false
		chamber_reached.emit()

func _advance_reload(delta: float) -> void:
	if not _reloading:
		return
	_reload_t += delta
	if _reload_t + RELOAD_EPSILON >= RELOAD_TIME:
		_reloading = false
		_reload_t = 0.0
		_ammo = CYLINDER
		reload_finished.emit()
		ammo_changed.emit(_ammo)

## Zipline state machine. Runs before the cart-phase logic each frame.
func _update_zipline() -> void:
	if _zip_index >= 0:
		var seg: Dictionary = _zip_segments[_zip_index]
		if _distance > float(seg["end_z"]):
			var nxt := _zip_index + 1
			if _is_chained(_zip_index, nxt):
				if _zip_transfer_armed:
					_zip_index = nxt
					_zip_transfer_armed = false
					_zip_resolved[nxt] = true
					zip_caught.emit(nxt)
				else:
					var dropped := nxt
					_zip_index = -1
					_zip_transfer_armed = false
					_resolve_chain_from(nxt)
					zip_missed.emit(dropped)
					_take_hit()
			else:
				_zip_index = -1
				_zip_transfer_armed = false
	else:
		for i in _zip_segments.size():
			if _zip_resolved.has(i):
				continue
			if _distance < float(_zip_segments[i]["start_z"]):
				break
			_zip_resolved[i] = true
			if _cart_y >= ZIP_CATCH_MIN_Y:
				_zip_index = i
				zip_caught.emit(i)
			else:
				if _is_chained(i, i + 1):
					_resolve_chain_from(i + 1)
				zip_missed.emit(i)
				_take_hit()
			break
	_ziplining = _zip_index >= 0

func _is_chained(a: int, b: int) -> bool:
	if a < 0 or b >= _zip_segments.size():
		return false
	return float(_zip_segments[b]["start_z"]) - float(_zip_segments[a]["end_z"]) <= ZIP_CHAIN_GAP

func _resolve_chain_from(start: int) -> void:
	var i := start
	while i < _zip_segments.size():
		_zip_resolved[i] = true
		if not _is_chained(i, i + 1):
			break
		i += 1

## Single place health is lost, so the death check can never be skipped.
func _take_hit() -> void:
	if not _running:
		return
	_health -= 1
	obstacle_hit.emit(_health)
	if _health <= 0:
		_running = false
		run_failed.emit()

func _is_ducking_effective() -> bool:
	return _duck_held and _duck_hold_time + DUCK_HOLD_EPSILON >= DUCK_MIN_HOLD

## Rail events (spawn / end) and boulder cart-smashing, judged once each as the
## convoy passes their z. Runs every frame, including on the zipline (the carts
## keep rolling under the cable).
func _update_rails() -> void:
	for e in _rail_events:
		if e["done"] or _distance < float(e["z"]):
			continue
		e["done"] = true
		var ln: int = int(e["lane"])
		if ln < 0 or ln >= LANE_X.size():
			continue
		if str(e["type"]) == "spawn":
			if not _cart_alive[ln]:
				_cart_alive[ln] = true
				cart_spawned.emit(ln)
		else:
			_wreck(ln, "rail_end")
			if not _running:
				return
	for o in _obstacles:
		if str(o.get("type", "")) != "boulder" or o.get("smashed", false):
			continue
		if _distance < float(o["z"]):
			continue
		o["smashed"] = true
		var bl: int = int(o["lane"])
		if bl >= 0 and bl < LANE_X.size() and _cart_alive[bl]:
			_wreck(bl, "boulder")
			if not _running:
				return

## Destroy lane's cart. The rider's own cart: he's thrown to the nearest live
## cart (the boulder's hit is judged by _check_obstacles; a rail end costs a hit
## here), or derailed when none is left.
func _wreck(lane: int, cause: String) -> void:
	if not _cart_alive[lane]:
		return
	_cart_alive[lane] = false
	cart_wrecked.emit(lane, cause)
	if _ziplining or lane != _lane:
		return
	var to: int = _nearest_live_lane(lane)
	if cause == "rail_end":
		_take_hit()
		if not _running:
			return
	if to < 0:
		_derail()
		return
	_lane = to
	rider_bailed.emit(lane, to)

## No cart left under the rider: the run ends.
func _derail() -> void:
	if not _running:
		return
	_health = 0
	obstacle_hit.emit(_health)
	_running = false
	run_failed.emit()

## Nearest live lane to `from` (ties prefer the centre), or -1 when none.
func _nearest_live_lane(from: int) -> int:
	var best: int = -1
	var best_d: int = 99
	for i in LANE_X.size():
		if not _cart_alive[i]:
			continue
		var d: int = absi(i - from)
		if d < best_d or (d == best_d and i == 1):
			best = i
			best_d = d
	return best

func _check_obstacles(cur_x: float) -> void:
	for o in _obstacles:
		if o.get("hit", false) or o.get("cancelled", false) or o.get("repelled", false):
			continue
		if str(o.get("type", "")) == "gold":
			if not o.get("taken", false) and absf(_distance - float(o["z"])) <= OBSTACLE_HIT_Z \
					and absf(cur_x - LANE_X[clampi(int(o["lane"]), 0, LANE_X.size() - 1)]) <= OBSTACLE_HIT_X:
				o["taken"] = true
				_gold += 1
				gold_collected.emit(_gold)
			continue
		if absf(_distance - float(o["z"])) > OBSTACLE_HIT_Z:
			continue
		var lane_i: int = int(o["lane"])
		# lane -1 = "whichever cart the rider is in" (boarders): no x check.
		if lane_i >= 0 and absf(cur_x - LANE_X[lane_i]) > OBSTACLE_HIT_X:
			continue
		var hazard_type: String = str(o.get("type", "box"))
		if hazard_type == "boarder":
			if _swipe_t > 0.0:
				o["repelled"] = true
				boarder_repelled.emit()
				continue
		elif _is_cleared(hazard_type):
			continue
		o["hit"] = true
		_take_hit()
		if not _running:
			return  # don't double-emit after death (Kimi audit #5d)

## Clear rules, one verb per hazard:
## "box" — jump. "arrow" — duck (or shoot its archer first).
## "boulder" — hop to another rail. "boarder" — pickaxe swipe.
## "shovels" — a ROW of bears across all three rails, shovels raised: nothing on the rails gets past;
## the only answer is to be on the zipline (founder 2026-09-30: "jumping on the zipline becomes the only solution").
func _is_cleared(hazard_type: String) -> bool:
	match hazard_type:
		"arrow":
			return _is_ducking_effective()
		"boulder":
			return false
		"shovels":
			return _ziplining          # a row of shovel bears across every rail: only the zipline goes over them
		"gold":
			return true
		"boarder":
			return _swipe_t > 0.0
		_: # "box"
			return _cart_y >= OBSTACLE_CLEAR_HEIGHT

# --- Input-facing API ---------------------------------------------------------

func switch_lane_left() -> void:
	_try_hop(_lane - 1)

func switch_lane_right() -> void:
	_try_hop(_lane + 1)

## A hop reaches only the ADJACENT rail, and only if it still has a cart.
func _try_hop(to: int) -> void:
	if _ziplining or not _running:
		return
	if to < 0 or to >= LANE_X.size() or not _cart_alive[to]:
		hop_blocked.emit(to)
		return
	_lane = to

## Jump, only from the ground. While hooked, arms the swing to the next cable
## inside ZIP_TRANSFER_WINDOW of the end; otherwise a no-op on the cable.
func jump() -> void:
	if _ziplining:
		if _zip_index >= 0 and _is_chained(_zip_index, _zip_index + 1):
			var to_end: float = float(_zip_segments[_zip_index]["end_z"]) - _distance
			if to_end <= ZIP_TRANSFER_WINDOW:
				_zip_transfer_armed = true
		return
	if is_zero_approx(_cart_y) and is_zero_approx(_vy):
		_vy = JUMP_VELOCITY

func duck_start() -> void:
	if _ziplining:
		return
	_duck_held = true

func duck_end() -> void:
	_duck_held = false
	_duck_hold_time = 0.0

## Pickaxe swipe: opens SWIPE_WINDOW during which a boarder is knocked off.
func swipe() -> void:
	if not _running:
		return
	_swipe_t = SWIPE_WINDOW
	pickaxe_swing.emit()

## Manual reload (R). No-op while already reloading or with a full cylinder.
func reload() -> void:
	if _reloading or _ammo == CYLINDER:
		return
	_start_reload()

func _start_reload() -> void:
	if _reloading:
		return
	_reloading = true
	_reload_t = 0.0
	reload_started.emit()

## Shared trigger rules for fire_ray() and shoot(). Returns true when a round
## was actually fired (and consumed).
func _try_fire_round() -> bool:
	if not _running or not _can_shoot:
		return false
	if _reloading:
		return false
	if _shoot_cd > 0.0:
		return false
	if _ammo <= 0:
		dry_fire.emit()
		_start_reload()
		return false
	_ammo -= 1
	_shoot_cd = SHOOT_COOLDOWN
	shot_fired.emit()
	ammo_changed.emit(_ammo)
	return true

func _after_shot() -> void:
	if _ammo <= 0:
		_start_reload()

## Drop archer `index`: dead, its un-hit arrows cancelled. Returns its id.
func _kill_archer(index: int) -> String:
	var hit: Dictionary = _archers[index]
	hit["alive"] = false
	var id: String = str(hit["id"])
	for o in _obstacles:
		if str(o.get("archer", "")) == id and not o.get("hit", false):
			o["cancelled"] = true
	archer_down.emit(id)
	return id

## World position of an archer's chest — the one placement rule shared by the
## ray test and the view. side -1 = screen-left = world +X.
func archer_world_pos(a: Dictionary) -> Vector3:
	var side: float = float(a.get("side", 1))
	return Vector3(-side * ARCHER_X, ARCHER_Y + ARCHER_CHEST, float(a.get("z", 0.0)))

## Nearest living archer (within SHOOT_RANGE_MAX ahead) whose hit sphere the ray
## crosses. Returns {"index": int (-1 = none), "t": float}.
func _ray_pick(origin: Vector3, dir: Vector3) -> Dictionary:
	var best: int = -1
	var best_t: float = INF
	if dir.length_squared() < 0.000001:
		return {"index": best, "t": best_t}
	var d: Vector3 = dir.normalized()
	var r2: float = ARCHER_HIT_R * ARCHER_HIT_R
	for i in _archers.size():
		var a: Dictionary = _archers[i]
		if not a["alive"]:
			continue
		var dz: float = float(a["z"]) - _distance
		if dz < 0.0 or dz > SHOOT_RANGE_MAX:
			continue
		var c: Vector3 = archer_world_pos(a)
		var oc: Vector3 = c - origin
		var tc: float = oc.dot(d)
		var d2: float = oc.length_squared() - tc * tc
		if d2 > r2:
			continue
		var thc: float = sqrt(maxf(0.0, r2 - d2))
		var t_hit: float = tc - thc
		if t_hit < 0.0:
			t_hit = tc + thc       # origin inside the sphere
		if t_hit < 0.0:
			continue               # sphere is behind the ray
		if t_hit < best_t:
			best_t = t_hit
			best = i
	return {"index": best, "t": best_t}

## Mouse-aimed shot. Returns {"fired": bool, "hit": String, "point": Vector3}.
func fire_ray(origin: Vector3, dir: Vector3) -> Dictionary:
	var result: Dictionary = {"fired": false, "hit": "", "point": origin}
	if not _try_fire_round():
		return result
	var d: Vector3 = dir.normalized() if dir.length_squared() > 0.000001 else Vector3.BACK
	var pick: Dictionary = _ray_pick(origin, d)
	var idx: int = int(pick["index"])
	var hit_id: String = ""
	var point: Vector3 = origin + d * SHOT_MISS_RANGE
	if idx >= 0:
		var t_hit: float = float(pick["t"])
		point = origin + d * t_hit
		hit_id = _kill_archer(idx)
	result["fired"] = true
	result["hit"] = hit_id
	result["point"] = point
	shot_resolved.emit(hit_id, point)
	_after_shot()
	return result

## Pure query: which archer the ray would hit right now ("" for none). No side
## effects — the reticle uses it to turn red over a bear.
func ray_hits_archer(origin: Vector3, dir: Vector3) -> String:
	var pick: Dictionary = _ray_pick(origin, dir)
	var idx: int = int(pick["index"])
	if idx < 0:
		return ""
	var a: Dictionary = _archers[idx]
	return str(a["id"])

## Keyboard auto-aim (J/Enter): the nearest living archer ahead within range.
## Returns true if an archer went down. Obeys the cylinder exactly like
## fire_ray(). Allowed while ziplining.
func shoot() -> bool:
	if not _try_fire_round():
		return false
	var best := -1
	var best_dz := INF
	for i in _archers.size():
		var a: Dictionary = _archers[i]
		if not a["alive"]:
			continue
		var dz: float = float(a["z"]) - _distance
		if dz >= SHOOT_RANGE_MIN and dz <= SHOOT_RANGE_MAX and dz < best_dz:
			best = i
			best_dz = dz
	var hit_id: String = ""
	var point: Vector3 = Vector3(get_cart_x(), _cart_y + 1.2, _distance + SHOT_MISS_RANGE)
	if best >= 0:
		var target: Dictionary = _archers[best]
		point = archer_world_pos(target)
		hit_id = _kill_archer(best)
	shot_resolved.emit(hit_id, point)
	_after_shot()
	return best >= 0

# --- Read-only accessors for tests / HUD / view --------------------------------
func get_obstacles() -> Array: return _obstacles
func get_archers() -> Array: return _archers
func get_zip_segments() -> Array: return _zip_segments
func get_chamber_z() -> float: return _chamber_z
func can_shoot() -> bool: return _can_shoot
func get_zip_index() -> int: return _zip_index
func is_zip_transfer_armed() -> bool: return _zip_transfer_armed
func archers_alive() -> int:
	var n := 0
	for a in _archers:
		if a["alive"]:
			n += 1
	return n
func get_distance() -> float: return _distance
func get_speed() -> float: return _speed
func is_cart_alive(lane: int) -> bool: return lane >= 0 and lane < _cart_alive.size() and bool(_cart_alive[lane])
func get_carts_alive() -> Array: return _cart_alive.duplicate()
func get_rail_events() -> Array: return _rail_events
func get_gold() -> int: return _gold
func get_lane() -> int: return _lane
func get_cart_x() -> float: return _cart.position.x if _cart else LANE_X[_lane]
func get_cart_y() -> float: return _cart_y
func get_health() -> int: return _health
func is_running() -> bool: return _running
func is_ducking() -> bool: return _is_ducking_effective()
func is_duck_held() -> bool: return _duck_held
func is_ziplining() -> bool: return _ziplining
func get_ammo() -> int: return _ammo
func is_reloading() -> bool: return _reloading
func get_reload_progress() -> float:
	if not _reloading:
		return 0.0
	return clampf(_reload_t / RELOAD_TIME, 0.0, 1.0)
func is_swiping() -> bool: return _swipe_t > 0.0
