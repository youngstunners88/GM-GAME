class_name RunnerGraybox
extends Node3D
## Episode 2 — Gold Mine Runner, GRAYBOX vertical slice (engine primitives).
##
## This is the throwaway proving-ground for the runner half of the runner↔
## chamber loop (see artifacts/episode2-gold-mine/spec/00_ARCHITECTURE.md §7a
## and the multi-model design review). NO art, NO Blender assets — box meshes
## and pure logic, so the *gameplay* is proven and phone-tested before any GPU
## hour or Blender session is spent. When real GLBs arrive they drop into the
## same node slots without touching this logic.
##
## Deliberately self-contained: it pulls in none of the Episode 1 autoloads
## (StateMachine, GameManager, etc.) so the graybox can be reasoned about and
## headless-tested in isolation. Economy wiring to goldmine_system.gd comes
## when the loop is proven, not in the graybox.
##
## Mode model (per Astra's reviewed architecture): the runner is one of the
## two modes under a future persistent session root. Here it runs standalone
## and emits `chamber_reached` at the chamber entrance — the signal the
## session root will use to swap to the 3D chamber scene, carrying player
## state across. The runner does NOT load the chamber itself.

## Emitted once when the cart reaches the chamber entrance; the run halts.
signal chamber_reached
## Emitted each time an obstacle is struck; carries remaining health.
signal obstacle_hit(remaining_health: int)
## Emitted when health hits zero.
signal run_failed

# --- Tuning (graybox values; feel is tuned later, not law) --------------------
const RUN_SPEED := 12.0            # forward units/sec (+Z)
const LANE_X := [-2.5, 0.0, 2.5]   # three rails
const LANE_SWITCH_SPEED := 12.0    # how fast the cart slides between rails
const GRAVITY := 30.0
const JUMP_VELOCITY := 11.0        # ~0.73s airtime — clears an obstacle
const OBSTACLE_CLEAR_HEIGHT := 1.2 # cart y above this = jumped over it
const OBSTACLE_HIT_Z := 1.0        # z-window for a hit
const OBSTACLE_HIT_X := 0.8        # x-window (same-lane) for a hit
const START_HEALTH := 3

# --- Live state --------------------------------------------------------------
var _lane: int = 1                 # index into LANE_X; start centre
var _cart_y: float = 0.0
var _vy: float = 0.0
var _distance: float = 0.0         # world z travelled
var _health: int = START_HEALTH
var _running: bool = true
var _chamber_z: float = 200.0      # entrance distance

## Obstacles ahead: each {"z": float, "lane": int, "hit": bool}. Plain Array
## (not Array[Dictionary]) to avoid typed-array assignment friction from
## untyped `[]` / literal callers — this is a graybox, kept forgiving.
var _obstacles: Array = []

@onready var _cart: Node3D = $Cart

func _ready() -> void:
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)

## Configure the segment before/at spawn. Call before the run advances.
func setup(chamber_z: float, obstacles: Array = []) -> void:
	_chamber_z = chamber_z
	_obstacles = obstacles.duplicate(true)
	for o in _obstacles:
		o["hit"] = false

func _physics_process(delta: float) -> void:
	if not _running:
		return
	_advance(delta)

## Split out so a headless test can step the sim deterministically without a
## real frame clock: call `step(delta)` directly.
func step(delta: float) -> void:
	if _running:
		_advance(delta)

func _advance(delta: float) -> void:
	# Forward auto-run.
	_distance += RUN_SPEED * delta

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

	# Chamber entrance reached → stop and signal the (future) session root.
	if _distance >= _chamber_z:
		_running = false
		chamber_reached.emit()

func _check_obstacles(cur_x: float) -> void:
	if _cart_y >= OBSTACLE_CLEAR_HEIGHT:
		return  # airborne above obstacle height — cleared
	for o in _obstacles:
		if o.get("hit", false):
			continue
		if absf(_distance - float(o["z"])) > OBSTACLE_HIT_Z:
			continue
		if absf(cur_x - LANE_X[int(o["lane"])]) > OBSTACLE_HIT_X:
			continue
		o["hit"] = true
		_health -= 1
		obstacle_hit.emit(_health)
		if _health <= 0:
			_running = false
			run_failed.emit()

# --- Input-facing API (driven by real input later; tests call directly) ------

## Move one rail left (toward index 0) if possible.
func switch_lane_left() -> void:
	_lane = maxi(0, _lane - 1)

## Move one rail right (toward index 2) if possible.
func switch_lane_right() -> void:
	_lane = mini(LANE_X.size() - 1, _lane + 1)

## Jump, only from the ground (no double-jump in the graybox).
func jump() -> void:
	if is_zero_approx(_cart_y) and is_zero_approx(_vy):
		_vy = JUMP_VELOCITY

# --- Read-only accessors for tests / HUD -------------------------------------
func get_distance() -> float: return _distance
func get_lane() -> int: return _lane
func get_cart_x() -> float: return _cart.position.x if _cart else LANE_X[_lane]
func get_cart_y() -> float: return _cart_y
func get_health() -> int: return _health
func is_running() -> bool: return _running
