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
## Deliberately self-contained: it pulls in none of the Episode-1-specific
## gameplay autoloads (StateMachine, GameManager, etc.) so the graybox can be
## reasoned about and headless-tested in isolation. Economy wiring to
## goldmine_system.gd comes when the loop is proven, not in the graybox.
## `AudioManager` is the one exception — it's a project-wide music/audio
## singleton already used across every episode/level (not Episode-1-only
## gameplay state), so using it here is consistent with existing convention,
## not a break of the isolation goal above.
##
## Mode model (per Astra's reviewed architecture): the runner is one of the
## two modes under a future persistent session root. Here it runs standalone
## and emits `chamber_reached` at the chamber entrance — the signal the
## session root will use to swap to the 3D chamber scene, carrying player
## state across. The runner does NOT load the chamber itself.
##
## Hazard model (per multi-model design review,
## docs/model-responses/2026-09-06-grok-ep2-runner-hazards.md): arrow and
## boulder hazards are deliberately OPPOSITE, not palette swaps of the
## legacy box obstacle:
##   - "box"     (legacy/default): cleared by jump. Unchanged behaviour —
##                the 7 pre-existing headless assertions keep meaning what
##                they meant before this hazard-type field existed.
##   - "arrow"   (balaclava bears firing down the lane): a flying projectile
##                — jumping does NOT clear it. Only ducking inside the cart
##                (cart walls block it) or being in a different lane clears
##                it. Ducking must be held for DUCK_MIN_HOLD before it counts,
##                so a one-frame duck-on-contact can't cheese the window.
##   - "boulder" (bears pushing rocks down the rails): crushes low — ducking
##                does NOT clear it. Only jump (clears the height) or being
##                in a different lane clears it.
## Zipline is modelled as a boolean mode (`_ziplining`) over a scripted
## z-range, not a fourth rail: it's a different plane of movement (an
## overhead cable), so while active it suspends lane-switching, duck, and
## jump, and cart-phase hazards (arrow/boulder/box) don't apply — you're off
## the rails, not dodging on them.

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
const DUCK_MIN_HOLD := 0.10        # seconds a duck must be held to block an arrow
## Float-accumulation slack for the duck-hold comparison: `delta` sums (e.g.
## 6× double(1/60)) can land a couple of ULPs *below* the nominal target
## (double(1/60)*6 ≈ 0.09999999999999999), which would wrongly read as "not
## yet held long enough" on the exact intended frame. Found by Kimi K3 code
## audit, docs/model-responses/2026-09-06-kimi-ep2-runner-hazards-audit.md #1.
const DUCK_HOLD_EPSILON := 0.001
const ZIP_HEIGHT := 2.5            # cart Y while ziplining (above jump-clear height)

# --- Live state --------------------------------------------------------------
var _lane: int = 1                 # index into LANE_X; start centre
var _cart_y: float = 0.0
var _vy: float = 0.0
var _distance: float = 0.0         # world z travelled
var _health: int = START_HEALTH
var _running: bool = true
var _chamber_z: float = 200.0      # entrance distance

## Obstacles ahead: each {"z": float, "lane": int, "hit": bool, "type": String}.
## `type` in {"box", "arrow", "boulder"} — defaults to "box" (legacy: cleared
## by jump only) when a caller/test omits it, so the original 7 assertions
## keep their original meaning. Plain Array (not Array[Dictionary]) to avoid
## typed-array assignment friction from untyped `[]` / literal callers — this
## is a graybox, kept forgiving.
var _obstacles: Array = []

# --- Duck (arrow defense) -----------------------------------------------------
var _duck_held: bool = false
var _duck_hold_time: float = 0.0

# --- Zipline (a different plane of movement, not a rail) ----------------------
## Each {"start_z": float, "end_z": float}. While `_distance` is inside any
## segment, `_ziplining` is true and cart-phase logic (lane-switch, duck,
## jump, box/arrow/boulder hazards) is suspended.
var _zip_segments: Array = []
var _ziplining: bool = false
var _was_ziplining: bool = false  # edge-detects the zip→cart dismount frame

## Runner-section music. Founder direction (2026-09-09) supersedes the
## 2026-09-06 direction that goldmine_dreams/goldmine_high shuffle here
## "until further notice" — these two tracks are that further notice, and
## were delivered for the runner specifically. The previous two tracks are
## left on disk and in assets/audio-manifest.json (they are real client
## assets) but are no longer wired to any scene.
##
## Sequencing: `AudioManager.play_playlist()` already advances to the next
## track on each track's natural end and shuffles with no-immediate-repeat
## (see `_play_next_in_playlist`), which with a 2-track list means Run and
## Run_1 alternate and then continue indefinitely — the founder's option (b)
## "sequence into Run_1 once Run finishes", with zero new plumbing. It also
## routes playback through the **Music** bus (`current_music_player.bus =
## "Music"`), so the existing volume sliders/settings keep working; a bespoke
## AudioStreamPlayer here would have bypassed them.
##
## `force_first = true` so the runner always OPENS on Run.mp3 (the founder's
## "plays Run.mp3 during runner segments"), then shuffles from there —
## without it, play_playlist picks its first track at random.
const RUNNER_MUSIC_PLAYLIST := [
	"res://src/assets/music/runner_run.mp3",
	"res://src/assets/music/runner_run_1.mp3",
]

@onready var _cart: Node3D = $Cart

func _ready() -> void:
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)
	AudioManager.play_playlist(RUNNER_MUSIC_PLAYLIST, true)

## Configure the segment before/at spawn. Call before the run advances.
## `obstacles` entries missing "type" default to "box" (legacy jump-clears).
## Also resets all run state — safe to call again on a reused instance
## (Kimi audit #5c: a stale `_running = false` from a prior run_failed/
## chamber_reached would otherwise make every step() silently a no-op).
func setup(chamber_z: float, obstacles: Array = [], zip_segments: Array = []) -> void:
	_chamber_z = chamber_z
	_obstacles = obstacles.duplicate(true)
	for o in _obstacles:
		o["hit"] = false
		if not o.has("type"):
			o["type"] = "box"
	_zip_segments = zip_segments.duplicate(true)

	_lane = 1
	_cart_y = 0.0
	_vy = 0.0
	_distance = 0.0
	_health = START_HEALTH
	_running = true
	_duck_held = false
	_duck_hold_time = 0.0
	_ziplining = false
	_was_ziplining = false
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)

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

	_ziplining = _in_any_zip_segment(_distance)

	# Duck hold time does NOT accumulate while ziplining — you let go of duck
	# to grab the cable, so a duck held before/through a zip segment can't
	# carry effective cover out the other side (Kimi audit #5b: the doc
	# comment always claimed duck was suspended during zip, but only
	# duck_start() was actually gated — the timer kept counting regardless).
	if _duck_held and not _ziplining:
		_duck_hold_time += delta
	else:
		_duck_hold_time = 0.0

	if _ziplining:
		# A different plane of movement (overhead cable) — lane, duck, and
		# jump are all suspended; cart-phase hazards don't apply here.
		_cart_y = ZIP_HEIGHT
		_vy = 0.0
		if _cart:
			_cart.position = Vector3(_cart.position.x, _cart_y, _distance)
		_was_ziplining = true
	else:
		if _was_ziplining:
			# Clean dismount: land back on the rail immediately rather than
			# falling from ZIP_HEIGHT under gravity. Without this, ~0.3s of
			# residual fall time after zip-exit both free-clears any
			# box/boulder in that window (still "airborne" above
			# OBSTACLE_CLEAR_HEIGHT) and makes jump() a dead no-op (Kimi
			# audit #5a).
			_cart_y = 0.0
			_vy = 0.0
			_was_ziplining = false

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

func _in_any_zip_segment(distance: float) -> bool:
	for seg in _zip_segments:
		if distance >= float(seg["start_z"]) and distance <= float(seg["end_z"]):
			return true
	return false

## Effective duck: held for at least DUCK_MIN_HOLD, so a one-frame duck
## exactly on hazard contact can't cheese the window (per design review).
## Epsilon-guarded — see DUCK_HOLD_EPSILON.
func _is_ducking_effective() -> bool:
	return _duck_held and _duck_hold_time + DUCK_HOLD_EPSILON >= DUCK_MIN_HOLD

func _check_obstacles(cur_x: float) -> void:
	for o in _obstacles:
		if o.get("hit", false):
			continue
		if absf(_distance - float(o["z"])) > OBSTACLE_HIT_Z:
			continue
		if absf(cur_x - LANE_X[int(o["lane"])]) > OBSTACLE_HIT_X:
			continue
		if _is_cleared(o.get("type", "box")):
			continue
		o["hit"] = true
		_health -= 1
		obstacle_hit.emit(_health)
		if _health <= 0:
			_running = false
			run_failed.emit()
			return  # stop scanning this frame — don't double-emit on a
			        # second same-frame hit after death (Kimi audit #5d)

## Clear rules are deliberately opposite per hazard type (design review):
## "box"/"boulder" — cleared by jump height only, duck does NOT help (a
## boulder crushes low). "arrow" — cleared by ducking only, jump does NOT
## help (a flying projectile still hits an airborne body).
func _is_cleared(hazard_type: String) -> bool:
	match hazard_type:
		"arrow":
			return _is_ducking_effective()
		_: # "box", "boulder"
			return _cart_y >= OBSTACLE_CLEAR_HEIGHT

# --- Input-facing API (driven by real input later; tests call directly) ------

## Move one rail left (toward index 0) if possible. No-op while ziplining —
## a different plane of movement, not a rail.
func switch_lane_left() -> void:
	if _ziplining:
		return
	_lane = maxi(0, _lane - 1)

## Move one rail right (toward index 2) if possible. No-op while ziplining.
func switch_lane_right() -> void:
	if _ziplining:
		return
	_lane = mini(LANE_X.size() - 1, _lane + 1)

## Jump, only from the ground (no double-jump in the graybox). No-op while
## ziplining — you're already off the rails.
func jump() -> void:
	if _ziplining:
		return
	if is_zero_approx(_cart_y) and is_zero_approx(_vy):
		_vy = JUMP_VELOCITY

## Start ducking (holds until duck_end()). No-op while ziplining. Must be
## held for DUCK_MIN_HOLD before it counts as effective cover — see
## _is_ducking_effective().
func duck_start() -> void:
	if _ziplining:
		return
	_duck_held = true

## Release duck. Effective-duck timer resets immediately (no cover on release).
func duck_end() -> void:
	_duck_held = false
	_duck_hold_time = 0.0

# --- Read-only accessors for tests / HUD -------------------------------------
func get_distance() -> float: return _distance
func get_lane() -> int: return _lane
func get_cart_x() -> float: return _cart.position.x if _cart else LANE_X[_lane]
func get_cart_y() -> float: return _cart_y
func get_health() -> int: return _health
func is_running() -> bool: return _running
func is_ducking() -> bool: return _is_ducking_effective()
func is_ziplining() -> bool: return _ziplining
