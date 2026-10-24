class_name TouchActions
extends RefCounted
## The ONE door from touch into gameplay: existing InputMap actions.
##
## Gameplay (player.gd, combat, forges...) only ever reads `Input.*` for
## `move_left` / `move_right` / `move_up` / `move_down` / `jump` / `dash` /
## `sprint` / `attack` / `interact`. This class presses and releases those same
## actions, so desktop keyboard parity holds by construction and gameplay needs
## zero knowledge of touch.
##
## It mirrors what the engine's own TouchScreenButton does, because that is the
## path the shipped game already proves out:
##   1. `Input.action_press(action, strength)` -> polled reads
##      (`is_action_pressed`, `get_action_strength`, `get_axis`, `just_pressed`)
##   2. an `InputEventAction` pushed through the root viewport on the press and
##      release EDGES only -> `_input` / `_unhandled_input` handlers that test
##      `event.is_action_pressed("jump")` (Blaze Rush, panels) still see touch.
## Analog strength updates (the joystick) only touch step 1, so a moving thumb
## never floods the event queue.
##
## Beyond press / release it offers the verbs the finger-movement controls need:
##   * pulse(action)  a momentary press (a swipe gesture): down now, up after the next
##                    physics + process frame
##   * tap(action)    a FRESH down edge even if the action is already held (a tap field:
##                    a resting thumb must not swallow the next finger's tap)
##   * add_look / take_look  a look-delta accumulator for the first-person look pad
##   * ensure_action  register an empty InputMap action for a touch-only verb

## What the FINGERS hold right now (action -> strength), whether or not it is being
## injected. Static: touch state is global.
static var _wanted: Dictionary = {}
## What is actually pressed on `Input` (action -> strength).
static var _held: Dictionary = {}
## While suspended (the hero is dead or the game is paused) fingers keep being
## tracked but nothing is injected; see set_suspended().
static var _suspended: bool = false
## Look-drag accumulator (canvas units x gain): filled by VirtualLookPad, drained by
## the first-person room once a frame via take_look(). Not an InputMap action because
## a look delta is a vector, not a press. Cleared by release_all() and set_suspended().
static var _look: Vector2 = Vector2.ZERO
## Actions with a pulse() release still pending (action -> true).
static var _pulsing: Dictionary = {}

## Actions whose HELD state is restored when a suspension ends: direction and run.
## Edge-triggered ones (jump, attack, dash, interact) are NOT, so a button held down
## through a death does not fire the moment the hero respawns (a held key would not).
const RESUME_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"sprint"]

## Hold `action` at `strength` (0..1). Cheap to call every frame.
static func press(action: StringName, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		return
	strength = clampf(strength, 0.0, 1.0)
	_wanted[action] = strength
	if not _suspended:
		_commit_press(action, strength)

## Release `action` if touch is holding it. No-op otherwise, so it can never
## cancel a held keyboard key it did not press.
static func release(action: StringName) -> void:
	_wanted.erase(action)
	_commit_release(action)

## Register an EMPTY InputMap action (no key, no button) if it does not exist yet, so a
## touch-only verb (`ep2_touch_reload`, ...) can be pressed and read like any other
## action without colliding with a keyboard binding. Idempotent; never touches an
## action that already exists (a real keyboard action keeps its events).
static func ensure_action(action: StringName) -> void:
	if action == &"" or InputMap.has_action(action):
		return
	InputMap.add_action(action)

## A momentary press for EDGE-reading code (a swipe gesture): the action goes down now
## (a fresh edge even if it was already held) and comes back up on the first process
## frame AFTER the next physics frame, so a polled `_physics_process` reader always
## sees it and an `_input` handler sees both the down and the up event. Dropped while
## suspended (a gesture made during a death animation must not fire on respawn).
static func pulse(action: StringName, strength: float = 1.0) -> void:
	if _suspended or not InputMap.has_action(action):
		return
	if _held.has(action):
		_commit_release(action)
	press(action, strength)
	if _pulsing.has(action):
		return
	var loop: MainLoop = Engine.get_main_loop()
	if not (loop is SceneTree):
		release(action)
		return
	_pulsing[action] = true
	(loop as SceneTree).physics_frame.connect(_pulse_after_physics.bind(action), CONNECT_ONE_SHOT)

static func _pulse_after_physics(action: StringName) -> void:
	if not _pulsing.has(action):
		return
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).process_frame.connect(_pulse_end.bind(action), CONNECT_ONE_SHOT)
	else:
		_pulse_end(action)

static func _pulse_end(action: StringName) -> void:
	if _pulsing.erase(action):
		release(action)

## Press `action` and make sure consumers see a FRESH down edge even if it is already
## held: release + press in the same frame. A resting thumb on a tap field would
## otherwise swallow the next finger's tap (press() only pushes an event on the
## not-held -> held edge). The action then stays held until release()/release_all().
static func tap(action: StringName, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		return
	if _held.has(action):
		_commit_release(action)
	press(action, strength)

## Add a look delta (canvas units x the pad's gain). Ignored while suspended, so a pad
## never banks a camera jump during a pause.
static func add_look(delta: Vector2) -> void:
	if _suspended:
		return
	_look += delta

## Drain the look accumulator (the camera consumes it once per frame).
static func take_look() -> Vector2:
	var out: Vector2 = _look
	_look = Vector2.ZERO
	return out

## Peek at the accumulator without draining it (debug overlay, tests).
static func look_pending() -> Vector2:
	return _look

## Drive a bipolar axis from one signed value: the matching side is pressed at
## |value| (0 releases both). Used for the joystick's left/right and up/down.
static func set_axis(negative: StringName, positive: StringName, value: float) -> void:
	if value > 0.0:
		release(negative)
		press(positive, value)
	elif value < 0.0:
		release(positive)
		press(negative, -value)
	else:
		release(negative)
		release(positive)

## Let go of everything touch is holding AND forget what the fingers wanted. Called
## on hide / transition / focus loss / layout swap so a finger that vanished can
## never leave the hero running forever.
static func release_all() -> void:
	_look = Vector2.ZERO
	_pulsing.clear()
	var actions: Array = _held.keys()
	for action: StringName in _wanted.keys():
		if not actions.has(action):
			actions.append(action)
	for action: StringName in actions:
		release(action)

## Pause injection WITHOUT forgetting the fingers (death animation, pause): every
## pressed action is released at once, the fingers' wishes are kept, and when the
## suspension ends the held direction/run comes straight back. The thumb never has
## to lift, and a press made during the suspension counts.
static func set_suspended(on: bool) -> void:
	if on == _suspended:
		return
	_suspended = on
	if on:
		_look = Vector2.ZERO
		_pulsing.clear()
		for action: StringName in _held.keys():
			_commit_release(action)
	else:
		for action: StringName in _wanted.keys().duplicate():
			if RESUME_ACTIONS.has(action):
				_commit_press(action, float(_wanted[action]))
			else:
				_wanted.erase(action)

static func is_suspended() -> bool:
	return _suspended

## True while touch has `action` PRESSED on Input (false while suspended).
static func is_held(action: StringName) -> bool:
	return _held.has(action)

static func held_strength(action: StringName) -> float:
	return float(_held.get(action, 0.0))

static func held_count() -> int:
	return _held.size()

static func _commit_press(action: StringName, strength: float) -> void:
	var was_held: bool = _held.has(action)
	_held[action] = strength
	Input.action_press(action, strength)
	if not was_held:
		_push_event(action, true, strength)

static func _commit_release(action: StringName) -> void:
	if not _held.has(action):
		return
	_held.erase(action)
	Input.action_release(action)
	_push_event(action, false, 0.0)

## Player preference (MobileLayoutManager.set_haptics).
static var haptics_enabled: bool = true

## Short haptic tick where the platform has one (Android browsers and native
## builds; silently nothing on iOS Safari and desktop).
static func buzz(duration_ms: int = 12) -> void:
	if haptics_enabled:
		Input.vibrate_handheld(duration_ms)

static func _push_event(action: StringName, pressed: bool, strength: float) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = strength
	(loop as SceneTree).root.push_input(ev, false)
