class_name RunnerGraybox
extends Node3D
## Episode 2 — Gold Mine Runner: SIMULATION. (File/class keep the "graybox"
## name so the session root, tests and scene uid don't churn; the art now lives
## in runner_view.gd, the surfaces in src/episode2/art/ep2_palette.gd, and the
## layout in tracks/*.json.)
##
## This script is pure gameplay logic: it contains NO rendering code at all.
## Everything visible (tunnel, carts, props, hazards, telegraphs, camera,
## environment/sun art pass) is built by the child "View" node, which only
## reads this sim through its accessors and signals. So every rule here stays
## headless-testable with no renderer, and the art can be restyled freely.
##
## Deliberately self-contained: it pulls in none of the Episode-1-specific
## gameplay autoloads (StateMachine, GameManager, etc.) so the runner can be
## reasoned about and headless-tested in isolation. Economy wiring to
## goldmine_system.gd comes when the loop is proven, not here.
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
##   - "boulder" (bears rolling rocks down a rail): too big to jump and it
##                crushes low, so neither jump NOR duck clears it. The ONLY
##                answer is to hop into the cart on another rail (founder
##                direction 2026-09-23, matching IMG_2492: one cart per rail,
##                Lil Blunt leaps between them). Changed from the earlier
##                "jump clears a boulder" rule; tests updated to match.
##
## Carts: there is one cart per rail, running as a convoy. A "lane switch" is
## Lil Blunt HOPPING between carts, not one cart sliding sideways. The sim is
## unchanged by this (it only ever tracked the rider's x); it is a statement
## about what `$Cart` means — the RIDER anchor — and what the view draws.
##
## Zipline: a different plane of movement (overhead cable), not a fourth rail.
## It must be EARNED (founder direction 2026-09-23 — "jump and connect onto the
## zipline using his axe; jump to the next zipline"):
##   - Crossing a zip segment's start_z while airborne (cart_y >= ZIP_CATCH_MIN_Y)
##     hooks the axe onto the cable. Crossing it on the rails is a miss.
##   - Segments whose gap is <= ZIP_CHAIN_GAP form a chain. Jumping within
##     ZIP_TRANSFER_WINDOW of a segment's end arms the swing to the next cable;
##     reaching the end un-armed drops you.
##   - A miss or a drop costs ONE health for the whole remaining chain (never
##     one per cable) and puts you back on the rails, so it can't cascade.
## While hooked, lane-switching and duck are suspended and cart-phase hazards
## don't apply — you're off the rails, not dodging on them.
##
## Archers: balaclava bears on the scaffolding beside the track. Each "arrow"
## hazard may name the archer that fires it. Once armed (the Winchester is
## granted in Chamber 0 — see STORY_OUTLINE.md), `shoot()` drops the nearest
## living archer ahead within range and cancels its arrows. So an arrow volley
## has two answers: duck through it, or shoot the bear first.

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

# --- Tuning (feel is tuned later, not law) ------------------------------------
const RUN_SPEED := 12.0            # forward units/sec (+Z)
## Three rails. The camera looks down +Z, so world +X is SCREEN-LEFT: lane 0
## (reached with move_left / A) must be at +X. The original [-2.5, 0, 2.5] made
## every hop go the opposite way to the key pressed — found in a browser playtest
## 2026-09-23; headless tests could never see it because they only read x.
const LANE_X := [2.5, 0.0, -2.5]
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
const ZIP_HEIGHT := 2.5            # rider Y while ziplining (above jump-clear height)
const ZIP_CATCH_MIN_Y := 0.6       # must be at least this high crossing start_z to hook the cable
const ZIP_TRANSFER_WINDOW := 6.0   # jump within this many units of a cable's end to swing on
const ZIP_CHAIN_GAP := 8.0         # cables closer than this form a chain (swing between them)
const SHOOT_RANGE_MIN := 4.0       # an archer closer than this is already beside/behind you
const SHOOT_RANGE_MAX := 45.0      # ~3.75s ahead at RUN_SPEED — visible on the scaffold
const SHOOT_COOLDOWN := 0.35       # lever-action cadence; also stops shoot-spam trivialising volleys

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
## typed-array assignment friction from untyped `[]` / literal callers.
var _obstacles: Array = []

# --- Duck (arrow defense) -----------------------------------------------------
var _duck_held: bool = false
var _duck_hold_time: float = 0.0

# --- Zipline (a different plane of movement, not a rail) ----------------------
## Each {"start_z": float, "end_z": float}. While hooked, `_ziplining` is true
## and cart-phase logic (lane-switch, duck, jump, box/arrow/boulder hazards)
## is suspended.
var _zip_segments: Array = []      # sorted by start_z in setup()
var _ziplining: bool = false
var _was_ziplining: bool = false  # edge-detects the zip→cart dismount frame
var _zip_index: int = -1           # cable currently hooked, or -1
var _zip_transfer_armed: bool = false
var _zip_resolved: Dictionary = {} # segment index -> true once caught/missed (judged exactly once)

# --- Archers + shooting -------------------------------------------------------
## Each {"id": String, "z": float, "side": int(-1 left / +1 right), "alive": bool}.
var _archers: Array = []
var _can_shoot: bool = false       # true once the Winchester is in hand
var _shoot_cd: float = 0.0

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

# Presentation lives in runner_view.gd (child node "View"). This script is the
# SIMULATION only: it never reads anything back from the view, so every rule
# here stays headless-testable with no renderer. The view reads get_obstacles(),
# get_archers(), get_zip_segments() and the signals above.

func _ready() -> void:
	if _cart:
		_cart.position = Vector3(LANE_X[_lane], 0.0, 0.0)
	AudioManager.play_playlist(RUNNER_MUSIC_PLAYLIST, true)

## Configure the segment before/at spawn. Call before the run advances.
## `obstacles` entries missing "type" default to "box" (legacy jump-clears).
## Also resets all run state — safe to call again on a reused instance
## (Kimi audit #5c: a stale `_running = false` from a prior run_failed/
## chamber_reached would otherwise make every step() silently a no-op).
##
## `archers`: [{"id": String, "z": float, "side": -1|1}]. `can_shoot`: whether the
## Winchester is in hand for this leg. Both default off, so every pre-existing
## caller keeps its exact behaviour.
func setup(chamber_z: float, obstacles: Array = [], zip_segments: Array = [],
		archers: Array = [], can_shoot: bool = false) -> void:
	_chamber_z = chamber_z
	_obstacles = obstacles.duplicate(true)
	for o in _obstacles:
		o["hit"] = false
		o["cancelled"] = false
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

## Split out so a headless test can step the sim deterministically without a
## real frame clock: call `step(delta)` directly.
func step(delta: float) -> void:
	if _running:
		_advance(delta)

func _advance(delta: float) -> void:
	# Forward auto-run.
	_distance += RUN_SPEED * delta
	_shoot_cd = maxf(0.0, _shoot_cd - delta)

	_update_zipline()
	if not _running:
		return  # a zip drop just cost the last health point

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
		# The cable runs over the centre rail: slide to it, and land in that cart.
		_lane = 1
		if _cart:
			var zx: float = move_toward(_cart.position.x, float(LANE_X[1]), LANE_SWITCH_SPEED * delta)
			_cart.position = Vector3(zx, _cart_y, _distance)
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

## Zipline state machine. Runs before the cart-phase logic each frame.
func _update_zipline() -> void:
	if _zip_index >= 0:
		var seg: Dictionary = _zip_segments[_zip_index]
		if _distance > float(seg["end_z"]):
			var nxt := _zip_index + 1
			if _is_chained(_zip_index, nxt):
				if _zip_transfer_armed:
					_zip_index = nxt           # swing onto the next cable; still airborne in the gap
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
				_zip_index = -1                # end of the chain: clean dismount below
				_zip_transfer_armed = false
	else:
		for i in _zip_segments.size():
			if _zip_resolved.has(i):
				continue
			if _distance < float(_zip_segments[i]["start_z"]):
				break                          # sorted: nothing later has started either
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

## Mark every cable from `start` to the end of its chain as judged, so one miss
## costs one health point — not one per remaining cable.
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

## Effective duck: held for at least DUCK_MIN_HOLD, so a one-frame duck
## exactly on hazard contact can't cheese the window (per design review).
## Epsilon-guarded — see DUCK_HOLD_EPSILON.
func _is_ducking_effective() -> bool:
	return _duck_held and _duck_hold_time + DUCK_HOLD_EPSILON >= DUCK_MIN_HOLD

func _check_obstacles(cur_x: float) -> void:
	for o in _obstacles:
		if o.get("hit", false) or o.get("cancelled", false):
			continue
		if absf(_distance - float(o["z"])) > OBSTACLE_HIT_Z:
			continue
		if absf(cur_x - LANE_X[int(o["lane"])]) > OBSTACLE_HIT_X:
			continue
		if _is_cleared(o.get("type", "box")):
			continue
		o["hit"] = true
		_take_hit()
		if not _running:
			return  # stop scanning this frame — don't double-emit on a
			        # second same-frame hit after death (Kimi audit #5d)

## Clear rules, one verb per hazard so each reads instantly:
## "box"     — jump over it.
## "arrow"   — duck inside the cart (or shoot its archer first).
## "boulder" — nothing clears it in-lane: hop to another rail's cart.
## Only reached for a hazard in the rider's own lane (see _check_obstacles).
func _is_cleared(hazard_type: String) -> bool:
	match hazard_type:
		"arrow":
			return _is_ducking_effective()
		"boulder":
			return false
		_: # "box"
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

## Jump, only from the ground (no double-jump). Also how a zipline is caught:
## be airborne as you reach the cable. While hooked, jump only matters inside
## ZIP_TRANSFER_WINDOW of the cable's end, where it arms the swing to the next
## cable in the chain; anywhere else on the cable it is a no-op.
func jump() -> void:
	if _ziplining:
		if _zip_index >= 0 and _is_chained(_zip_index, _zip_index + 1):
			var to_end: float = float(_zip_segments[_zip_index]["end_z"]) - _distance
			if to_end <= ZIP_TRANSFER_WINDOW:
				_zip_transfer_armed = true
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

## Fire the Winchester at the nearest living archer ahead within range. Returns
## true if an archer went down. No-op before the gun is granted, during the
## lever cooldown, or once the run has ended. Allowed while ziplining — you can
## shoot from the cable.
func shoot() -> bool:
	if not _running or not _can_shoot or _shoot_cd > 0.0:
		return false
	_shoot_cd = SHOOT_COOLDOWN
	shot_fired.emit()
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
	if best < 0:
		return false
	var hit: Dictionary = _archers[best]
	hit["alive"] = false
	for o in _obstacles:
		if str(o.get("archer", "")) == hit["id"] and not o.get("hit", false):
			o["cancelled"] = true
	archer_down.emit(hit["id"])
	return true

# --- Read-only accessors for tests / HUD / view --------------------------------
## The live arrays are returned by reference for the view to read each frame
## without allocating. Treat them as read-only; the sim is their only writer.
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
func get_lane() -> int: return _lane
func get_cart_x() -> float: return _cart.position.x if _cart else LANE_X[_lane]
func get_cart_y() -> float: return _cart_y
func get_health() -> int: return _health
func is_running() -> bool: return _running
func is_ducking() -> bool: return _is_ducking_effective()
## Raw input state (for the view to crouch instantly); is_ducking() is what counts.
func is_duck_held() -> bool: return _duck_held
func is_ziplining() -> bool: return _ziplining
