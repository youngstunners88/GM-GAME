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
##   1. Double-triggered rewards → `_rewarded_chambers`.
##   2. Stale input → `_mode`. Input verbs are routed by mode and are hard
##      no-ops during TRANSITION.
##   3. Duplicate player → `_teardown_active()` frees and NULLS the outgoing
##      scene before the incoming one is instantiated.
##   4. Wrong resume position → `_completed_distance` accumulates the runner's
##      distance at the moment the chamber was entered.
##   5. Mobile memory → the outgoing scene is `queue_free()`d, never hidden.
##
## ECONOMY: the chamber computes its outcome and emits it; THIS is where it is
## committed to GoldMineSystem (mine_gold / auction pool credit).

signal mode_changed(mode: int)
signal chamber_committed(index: int, result: Dictionary)
signal session_complete
signal session_failed

enum Mode { IDLE, RUNNER, CHAMBER, TRANSITION }

const RUNNER_SCENE := preload("res://src/episode2/runner/runner_graybox.tscn")
const CHAMBER_SCENES := {
	"smelting_facility": preload("res://src/episode2/chamber/smelting_facility.tscn"),
	"miner_shaft": preload("res://src/episode2/chamber/miner_shaft.tscn"),
}
const DEFAULT_CHAMBER := "miner_shaft"

const DEFAULT_GOLD_PRINCIPAL := 1000

var _mode: int = Mode.IDLE
var _active: Node = null
var _plan: Array = []
var _segment: int = 0
var _completed_distance: float = 0.0
var _rewarded_chambers: Dictionary = {}   # index -> true, guard #1
## The segment index the CURRENTLY-LOADED chamber belongs to (guard #1 key).
var _chamber_segment: int = -1
var _commit_to_economy: bool = true
var _totals: Dictionary = {"gold_awarded": 0, "gold_forfeited": 0, "diamonds_burned": 0}

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

func start() -> void:
	if _plan.is_empty():
		return
	_enter_runner()

# --- Mode entry ---------------------------------------------------------------

func _enter_runner() -> void:
	_mode = Mode.TRANSITION
	_teardown_active()
	var seg: Dictionary = _plan[_segment]
	var r: Node = RUNNER_SCENE.instantiate()
	add_child(r)
	_active = r
	r.setup(
		float(seg.get("chamber_z", 200.0)),
		seg.get("obstacles", []),
		seg.get("zip_segments", []),
		seg.get("archers", []),
		bool(seg.get("armed", false))
	)
	r.chamber_reached.connect(_on_chamber_reached, CONNECT_ONE_SHOT)
	r.run_failed.connect(_on_run_failed, CONNECT_ONE_SHOT)
	_mode = Mode.RUNNER
	_sync_mouse_mode()
	mode_changed.emit(_mode)

func _enter_chamber() -> void:
	_mode = Mode.TRANSITION
	_sync_mouse_mode()
	if _active and _active.has_method("get_distance"):
		_completed_distance += float(_active.get_distance())
	_teardown_active()
	var seg: Dictionary = _plan[_segment]
	var chamber_id: String = str(seg.get("chamber", DEFAULT_CHAMBER))
	if not CHAMBER_SCENES.has(chamber_id):
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
		return
	_enter_chamber()

func _on_chamber_cleared(result: Dictionary) -> void:
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
			if awarded > 0 and gm.has_method("mine_gold"):
				gm.mine_gold(awarded)
			# Deliberately NOT gm.forfeit_to_auction() — that debits the player
			# (tests/ep2_session_root_test.gd test 15). The unvested remainder
			# was never in the balance, so it is a plain pool credit.
			if forfeited > 0:
				gm.auction_gold_pool += forfeited

	chamber_committed.emit(owner_segment, result)
	_chamber_segment = -1
	_advance_segment()

func _on_chamber_failed() -> void:
	_chamber_segment = -1
	_mode = Mode.IDLE
	_teardown_active()
	_sync_mouse_mode()
	session_failed.emit()

func _on_run_failed() -> void:
	_mode = Mode.IDLE
	_teardown_active()
	_sync_mouse_mode()
	session_failed.emit()

func _advance_segment() -> void:
	_segment += 1
	if _segment >= _plan.size():
		_mode = Mode.IDLE
		_teardown_active()
		_sync_mouse_mode()
		session_complete.emit()
		return
	_enter_runner()

# --- Input routing (guard #2) -------------------------------------------------

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

## Keyboard auto-aim shot at the nearest archer ahead (no-op on unarmed legs).
func runner_shoot() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.shoot()

## Mouse-aimed revolver shot through the given screen position.
func runner_fire_at_screen(pos: Vector2) -> void:
	if _mode != Mode.RUNNER or _active == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_active.fire_ray(cam.project_ray_origin(pos), cam.project_ray_normal(pos))

func runner_reload() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.reload()

## Pickaxe swipe — knocks a boarding bear off the cart.
func runner_swipe() -> void:
	if _mode == Mode.RUNNER and _active:
		_active.swipe()

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

func step(delta: float) -> void:
	if _active and (_mode == Mode.RUNNER or _mode == Mode.CHAMBER):
		_active.step(delta)

# --- Getters ------------------------------------------------------------------
func get_mode() -> int: return _mode
func get_segment() -> int: return _segment
func get_active() -> Node: return _active
func get_totals() -> Dictionary: return _totals.duplicate()
func get_total_distance() -> float:
	var live: float = 0.0
	if _mode == Mode.RUNNER and _active and _active.has_method("get_distance"):
		live = float(_active.get_distance())
	return _completed_distance + live

# --- Mouse cursor ---------------------------------------------------------------
# The runner view draws its own reticle, so the OS cursor is hidden in RUNNER
# mode and visible everywhere else (chambers, menus, after the session ends).

func _process(_delta: float) -> void:
	_sync_mouse_mode()

func _sync_mouse_mode() -> void:
	var want: Input.MouseMode = Input.MOUSE_MODE_HIDDEN if _mode == Mode.RUNNER else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# --- Live player input (guard #2 still applies) --------------------------------
#
#   Runner   move_left/move_right = switch rail · jump = jump · move_down = duck (hold)
#            LMB = fire revolver at the reticle · RMB / F = pickaxe swipe
#            R = reload · attack (J/Enter) = auto-aim shot
#   Chamber  attack = shoot · interact = start the Miner Rig
#            move_down = take cover (hold) · dash = pull the Early Claim lever
#
# The revolver/pickaxe/reload bindings read raw mouse buttons and physical keys
# so no project.godot input-map edits are needed.

@export var input_enabled: bool = true

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or event.is_echo():
		return
	match _mode:
		Mode.RUNNER:
			if event is InputEventMouseButton:
				var mb: InputEventMouseButton = event
				if mb.pressed:
					if mb.button_index == MOUSE_BUTTON_LEFT:
						runner_fire_at_screen(mb.position)
					elif mb.button_index == MOUSE_BUTTON_RIGHT:
						runner_swipe()
				# Mouse buttons never fall through to actions (an "attack" mapped
				# to LMB would otherwise fire twice).
				return
			if event is InputEventKey:
				var k: InputEventKey = event
				if k.pressed:
					if k.physical_keycode == KEY_R:
						runner_reload()
						return
					if k.physical_keycode == KEY_F:
						runner_swipe()
						return
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
			elif event.is_action_pressed("attack"):
				runner_shoot()
		Mode.CHAMBER:
			if event.is_action_pressed("attack"):
				chamber_shoot()
			elif event.is_action_pressed("interact"):
				chamber_start_rig("eth_diamonds" if Input.is_action_pressed("sprint") else "eth")
			elif event.is_action_pressed("dash"):
				chamber_early_claim()
			elif event.is_action_pressed("move_down"):
				chamber_take_cover()
			elif event.is_action_released("move_down"):
				chamber_leave_cover()
			elif event.is_action_pressed("move_right"):
				chamber_walk(1.0)
			elif event.is_action_pressed("move_left"):
				chamber_walk(-1.0)
			elif event.is_action_released("move_right") or event.is_action_released("move_left"):
				chamber_walk_stop()
