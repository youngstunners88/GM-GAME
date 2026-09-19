class_name Ep2SessionRoot
extends Node
## Episode 2 — persistent session root. Owns the runner↔chamber loop.
##
## This is the "persistent session root + separate scenes + explicit transition
## states" from architecture rail #5
## (.claude/skills/gm-game-episode2-gold-mine-runner/SKILL.md). The runner and
## the chamber are DISPOSABLE scenes; everything that must survive a mode swap
## — health, cumulative track distance, GOLD totals, which chambers are done —
## lives here, above both of them.
##
## Rail #5 names five specific guards. Each is implemented and each has a
## headless assertion in tests/ep2_session_root_test.gd:
##
##   1. Double-triggered rewards → `_rewarded_chambers`. A chamber's payout
##      commits at most once per chamber index, even if `chamber_cleared`
##      is emitted twice (re-entrancy, a duplicated connection, or a full-vest
##      tick landing on the same frame as an Early Claim lever pull).
##   2. Stale input → `_mode`. Input verbs are routed by mode and are hard
##      no-ops during TRANSITION, so a button pressed on the last frame of the
##      runner cannot drive a chamber that is mid-load (or vice versa).
##   3. Duplicate player → `_teardown_active()` frees and NULLS the outgoing
##      scene before the incoming one is instantiated, and `_active` is a
##      single slot. There is no path that leaves two player-bearing scenes
##      in the tree.
##   4. Wrong resume position → `_completed_distance` accumulates the runner's
##      distance at the moment the chamber was entered, so the post-chamber
##      segment continues the track instead of restarting it. The runner scene
##      legitimately resets its own `_distance` to 0 on setup(); continuity is
##      this root's job, not the disposable scene's.
##   5. Mobile memory → the outgoing scene is `queue_free()`d, never hidden and
##      kept resident. Two 3D scenes alive at once is the single easiest way to
##      blow a phone's memory budget on this project.
##
## ECONOMY: the chamber computes its outcome and emits it; THIS is where it is
## committed to GoldMineSystem (mine_gold / forfeit_to_auction). Keeping the
## write here is what makes guard #1 possible — a scene that credits itself
## cannot be made idempotent by its caller.

signal mode_changed(mode: int)
## Emitted after a chamber's payout has actually been committed. Carries the
## chamber index and the committed result — the HUD/telemetry hook.
signal chamber_committed(index: int, result: Dictionary)
## Emitted when the whole planned track is finished.
signal session_complete
## Emitted when a run ends badly (runner out of health, or chamber failed).
signal session_failed

enum Mode { IDLE, RUNNER, CHAMBER, TRANSITION }

const RUNNER_SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
## Chambers, by the id a track-plan segment names in its "chamber" key.
##
## Was a single `CHAMBER_SCENE` const pointing at the Miner Shaft. Episode 2
## has seven designed chambers and the FIRST thing the player reaches is not a
## protocol chamber at all — it is the Smelting Facility, where the Inferno Bull
## hands over the Winchester (chambers/00_SMELTING_FACILITY.md). A segment that
## names no chamber still gets the Miner Shaft, so every existing plan and gate
## keeps its exact previous behaviour.
const CHAMBER_SCENES := {
	"smelting_facility": preload("res://src/episode2/chamber/smelting_facility.tscn"),
	"miner_shaft": preload("res://src/episode2/chamber/miner_shaft.tscn"),
}
const DEFAULT_CHAMBER := "miner_shaft"

## Default GOLD principal for a graybox miner. NOT a protocol constant — no
## such value exists in goldmine_system.gd or the white paper (see the
## PROTOCOL NUMBERS note in miner_shaft.gd), so it is a caller-supplied
## placeholder, overridable per segment in the track plan.
const DEFAULT_GOLD_PRINCIPAL := 1000

var _mode: int = Mode.IDLE
var _active: Node = null
var _plan: Array = []              # [{chamber_z, obstacles, zip_segments, gold_principal, diamonds_paid}]
var _segment: int = 0
var _completed_distance: float = 0.0
var _rewarded_chambers: Dictionary = {}   # index -> true, guard #1
## The segment index the CURRENTLY-LOADED chamber belongs to, captured at
## entry. Guard #1 must key on this and not on `_segment`: `_advance_segment()`
## increments `_segment` as part of handling the first payout, so a duplicate
## `chamber_cleared` arriving afterwards would be attributed to the NEXT
## segment's index, find no flag there, and pay out a second time. Keying on
## the owning segment makes the guard hold no matter when the duplicate lands.
var _chamber_segment: int = -1
var _commit_to_economy: bool = true
var _totals: Dictionary = {"gold_awarded": 0, "gold_forfeited": 0, "diamonds_burned": 0}

## `commit_to_economy` exists so a headless gate can exercise the whole loop
## without mutating the real GoldMineSystem singleton and leaking state into
## other tests in the same run. Production callers leave it true.
func configure(plan: Array, commit_to_economy: bool = true) -> void:
	_plan = plan.duplicate(true)
	_commit_to_economy = commit_to_economy
	_segment = 0
	_completed_distance = 0.0
	_rewarded_chambers.clear()
	_chamber_segment = -1
	_totals = {"gold_awarded": 0, "gold_forfeited": 0, "diamonds_burned": 0}
	_teardown_active()
	_mode = Mode.IDLE

## Begin the session at segment 0.
func start() -> void:
	if _plan.is_empty():
		return
	_enter_runner()

# --- Mode entry ---------------------------------------------------------------

func _enter_runner() -> void:
	_mode = Mode.TRANSITION
	_teardown_active()                      # guard #3 + #5: free BEFORE instantiate
	var seg: Dictionary = _plan[_segment]
	var r: Node = RUNNER_SCENE.instantiate()
	add_child(r)
	_active = r
	r.setup(
		float(seg.get("chamber_z", 200.0)),
		seg.get("obstacles", []),
		seg.get("zip_segments", [])
	)
	r.chamber_reached.connect(_on_chamber_reached, CONNECT_ONE_SHOT)
	r.run_failed.connect(_on_run_failed, CONNECT_ONE_SHOT)
	_mode = Mode.RUNNER
	mode_changed.emit(_mode)

func _enter_chamber() -> void:
	_mode = Mode.TRANSITION
	# Banked BEFORE teardown — the runner's distance dies with the scene.
	if _active and _active.has_method("get_distance"):
		_completed_distance += float(_active.get_distance())
	_teardown_active()                      # guard #3 + #5
	var seg: Dictionary = _plan[_segment]
	var chamber_id: String = str(seg.get("chamber", DEFAULT_CHAMBER))
	if not CHAMBER_SCENES.has(chamber_id):
		# Loud, not silent. A typo'd chamber id that quietly fell back to the
		# Miner Shaft would put the player in the wrong room with the right
		# economy attached to it — a story bug wearing a working chamber's face.
		push_error("Ep2SessionRoot: unknown chamber id \"%s\"; falling back to %s" % [chamber_id, DEFAULT_CHAMBER])
		chamber_id = DEFAULT_CHAMBER
	var c: Node = CHAMBER_SCENES[chamber_id].instantiate()
	add_child(c)
	_active = c
	c.setup(
		int(seg.get("gold_principal", DEFAULT_GOLD_PRINCIPAL)),
		seg.get("bears", []),
		int(seg.get("diamonds_paid", 0))
	)
	# CONNECT_ONE_SHOT is belt-and-braces only. The real idempotency guarantee
	# is `_rewarded_chambers` in _on_chamber_cleared — a one-shot connection
	# still fires once per *connection*, and nothing structurally prevents a
	# future caller from connecting twice.
	c.chamber_cleared.connect(_on_chamber_cleared, CONNECT_ONE_SHOT)
	c.chamber_failed.connect(_on_chamber_failed, CONNECT_ONE_SHOT)
	_chamber_segment = _segment
	_mode = Mode.CHAMBER
	mode_changed.emit(_mode)

func _teardown_active() -> void:
	if _active:
		_active.queue_free()
		_active = null

# --- Signal handlers ----------------------------------------------------------

func _on_chamber_reached() -> void:
	if _mode != Mode.RUNNER:
		return                              # guard #2: stale/duplicate signal
	_enter_chamber()

func _on_chamber_cleared(result: Dictionary) -> void:
	# Guard #1. Keyed per-chamber (not a bare bool) so a later multi-chamber
	# plan can't have chamber 2's payout suppressed by chamber 1's flag, and
	# keyed on `_chamber_segment` (not `_segment`) so a duplicate arriving
	# after the segment has already advanced is still recognised — see the
	# declaration comment on `_chamber_segment`.
	var owner_segment: int = _chamber_segment
	if owner_segment < 0 or _rewarded_chambers.has(owner_segment):
		return
	_rewarded_chambers[owner_segment] = true

	var awarded: int = int(result.get("gold_awarded", 0))
	var forfeited: int = int(result.get("gold_forfeited", 0))
	var burned: int = int(result.get("diamonds_burned", 0))
	_totals["gold_awarded"] = int(_totals["gold_awarded"]) + awarded
	_totals["gold_forfeited"] = int(_totals["gold_forfeited"]) + forfeited
	_totals["diamonds_burned"] = int(_totals["diamonds_burned"]) + burned

	if _commit_to_economy:
		var gm: Node = get_node_or_null("/root/GoldMineSystem")
		if gm:
			# Credit the vested portion — the GOLD the player actually earned.
			if awarded > 0 and gm.has_method("mine_gold"):
				gm.mine_gold(awarded)
			# Route the UNVESTED remainder into the auction pool.
			#
			# Deliberately NOT gm.forfeit_to_auction(). Despite the name, that
			# function is a TRANSFER OUT OF the player's balance, not a credit
			# into the pool: it clamps `amount` to `gold_balance` and then does
			# `gold_balance -= amount`. Calling it here clawed back the GOLD
			# mine_gold() had just legitimately credited — a half-vested 1000
			# miner paid 499, then immediately lost all 499 to the clamp, so
			# the player ended a successful early claim with a zero balance.
			# Caught by tests/ep2_session_root_test.gd test 15.
			#
			# The unvested remainder was never in the player's balance (it is
			# GOLD they never earned), so the correct operation is a pool
			# credit with no debit. `auction_gold_pool` is a plain public var
			# on the autoload and is incremented directly elsewhere in that
			# same script (distribute_treasury_revenue, on_player_death).
			if forfeited > 0:
				gm.auction_gold_pool += forfeited

	chamber_committed.emit(owner_segment, result)
	# Clear the slot BEFORE advancing: from here on there is no live chamber,
	# so any further chamber_cleared is by definition stale.
	_chamber_segment = -1
	_advance_segment()

func _on_chamber_failed() -> void:
	_chamber_segment = -1
	_mode = Mode.IDLE
	_teardown_active()
	session_failed.emit()

func _on_run_failed() -> void:
	_mode = Mode.IDLE
	_teardown_active()
	session_failed.emit()

func _advance_segment() -> void:
	_segment += 1
	if _segment >= _plan.size():
		_mode = Mode.IDLE
		_teardown_active()
		session_complete.emit()
		return
	_enter_runner()

# --- Input routing (guard #2) -------------------------------------------------
# Every verb is a no-op unless the matching mode is active. During TRANSITION
# nothing is routed anywhere, which is the whole point of having an explicit
# transition state rather than swapping scenes inline.

func runner_switch_lane_left() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.switch_lane_left()

func runner_switch_lane_right() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.switch_lane_right()

func runner_jump() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.jump()

func runner_duck_start() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.duck_start()

func runner_duck_end() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.duck_end()

func chamber_start_rig(payment: String = "eth") -> bool:
	if _mode == Mode.CHAMBER and _active:
		return _active.start_rig(payment)
	return false

func chamber_shoot() -> bool:
	if _mode == Mode.CHAMBER and _active:
		return _active.shoot()
	return false

func chamber_early_claim() -> bool:
	if _mode == Mode.CHAMBER and _active:
		return _active.early_claim()
	return false

## Walk the player through a chamber that supports it. `has_method` rather than
## an id check: the Miner Shaft legitimately has no walk verb, and adding an
## empty one to it just to satisfy a caller would be worse than asking.
func chamber_walk(direction: float) -> void:
	if _mode == Mode.CHAMBER and _active and _active.has_method("walk"):
		_active.walk(direction)


func chamber_walk_stop() -> void:
	if _mode == Mode.CHAMBER and _active and _active.has_method("walk_stop"):
		_active.walk_stop()


func chamber_take_cover() -> void:
	if _mode == Mode.CHAMBER and _active:
		_active.take_cover()

func chamber_leave_cover() -> void:
	if _mode == Mode.CHAMBER and _active:
		_active.leave_cover()

## Drive the active mode deterministically — the headless-test entry point,
## mirroring RunnerGraybox.step()/MinerShaftChamber.step().
func step(delta: float) -> void:
	if _active and (_mode == Mode.RUNNER or _mode == Mode.CHAMBER):
		_active.step(delta)

# --- Getters ------------------------------------------------------------------
func get_mode() -> int: return _mode
func get_segment() -> int: return _segment
func get_active() -> Node: return _active
func get_totals() -> Dictionary: return _totals.duplicate()
## Cumulative track distance across every runner segment this session — the
## value that must NOT reset when a chamber is entered (guard #4).
func get_total_distance() -> float:
	var live: float = 0.0
	if _mode == Mode.RUNNER and _active and _active.has_method("get_distance"):
		live = float(_active.get_distance())
	return _completed_distance + live

# --- Live player input (guard #2 still applies) --------------------------------
#
# Until this block existed, Episode 2 had NO input handling anywhere: the verbs
# above were callable only from code, so the headless gates drove the whole loop
# while a human pressing keys did nothing. Every gate was green and the feature
# was unplayable — instantiating a scene directly and calling step() proves the
# LOGIC, never the REACHABILITY.
#
# Input maps onto the existing Episode 1 actions rather than adding new ones, so
# the mobile touch controls (which emit these same actions) work here for free:
#
#   Runner   move_left/move_right = switch rail · jump = jump · move_down = duck (hold)
#   Chamber  attack = shoot · interact = start the Miner Rig
#            move_down = take cover (hold) · dash = pull the Early Claim lever
#
# Routing still goes through the mode-gated verbs above, so a key pressed on the
# runner's last frame cannot drive a chamber that is mid-load.

## Set false to drive this root purely from a test harness.
@export var input_enabled: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or event.is_echo():
		return
	match _mode:
		Mode.RUNNER:
			if event.is_action_pressed("move_left"):
				runner_switch_lane_left()
			elif event.is_action_pressed("move_right"):
				runner_switch_lane_right()
			elif event.is_action_pressed("jump"):
				runner_jump()
			elif event.is_action_pressed("move_down"):
				runner_duck_start()
			elif event.is_action_released("move_down"):
				runner_duck_end()
		Mode.CHAMBER:
			if event.is_action_pressed("attack"):
				chamber_shoot()
			elif event.is_action_pressed("interact"):
				# Diamonds cost more but spin a heavier miner; hold sprint to opt in.
				chamber_start_rig("eth_diamonds" if Input.is_action_pressed("sprint") else "eth")
			elif event.is_action_pressed("dash"):
				chamber_early_claim()
			elif event.is_action_pressed("move_down"):
				chamber_take_cover()
			elif event.is_action_released("move_down"):
				chamber_leave_cover()
			# Walking. Only the Smelting Facility moves the player on foot; the
			# Miner Shaft holds position at the rig, so the verb is routed by
			# capability rather than by chamber id — a chamber that cannot walk
			# simply does not answer to it.
			elif event.is_action_pressed("move_right"):
				chamber_walk(1.0)
			elif event.is_action_pressed("move_left"):
				chamber_walk(-1.0)
			elif event.is_action_released("move_right") or event.is_action_released("move_left"):
				chamber_walk_stop()
