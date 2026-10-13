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

## action -> strength currently held by touch. Static: touch state is global.
static var _held: Dictionary = {}

## Hold `action` at `strength` (0..1). Cheap to call every frame.
static func press(action: StringName, strength: float = 1.0) -> void:
	if not InputMap.has_action(action):
		return
	strength = clampf(strength, 0.0, 1.0)
	var was_held: bool = _held.has(action)
	_held[action] = strength
	Input.action_press(action, strength)
	if not was_held:
		_push_event(action, true, strength)

## Release `action` if touch is holding it. No-op otherwise, so it can never
## cancel a held keyboard key it did not press.
static func release(action: StringName) -> void:
	if not _held.has(action):
		return
	_held.erase(action)
	Input.action_release(action)
	_push_event(action, false, 0.0)

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

## Let go of everything touch is holding. Called on hide / pause / focus loss /
## layout swap / scene change so a finger that vanished can never leave the hero
## running forever.
static func release_all() -> void:
	for action: StringName in _held.keys():
		release(action)

static func is_held(action: StringName) -> bool:
	return _held.has(action)

static func held_strength(action: StringName) -> float:
	return float(_held.get(action, 0.0))

static func held_count() -> int:
	return _held.size()

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
