extends Node
## Mobile input handler — translates touch events to game actions.
## Virtual joystick (left side) for movement, buttons (right side) for actions.
## Designed for portrait and landscape orientation detection.

# (no class_name: this script IS the MobileInputHandler autoload; a
# class_name matching an autoload name is a parse error in Godot 4)

signal touch_move(direction: float)  # -1 = left, 0 = neutral, 1 = right
signal touch_jump
signal touch_sprint
signal touch_sprint_released
signal touch_dash
signal touch_interact
signal touch_attack
signal touch_attack_released

# Native mobile OR any touchscreen device — crucially, the Web export reports
# OS.get_name() as "Web" (never "Android"/"iOS"), so a mobile browser only
# reveals itself through DisplayServer.is_touchscreen_available(). Without this,
# itch.io/mobile-web players get no touch controls at all.
var is_mobile: bool = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
var screen_size: Vector2 = get_viewport().get_visible_rect().size

# Virtual joystick zones
var joystick_zone: Rect2  # Left 40% of screen
var action_zone: Rect2    # Right 60% of screen

# Touch tracking
var touch_positions: Dictionary = {}  # touch_id → Vector2
var current_movement: float = 0.0
var button_states: Dictionary = {
	"jump": false,
	"sprint": false,
	"dash": false,
	"interact": false
}

# Joystick dead zone
const JOYSTICK_DEADZONE: float = 30.0
const BUTTON_SIZE: float = 80.0
const BUTTON_SPACING: float = 100.0

func _ready() -> void:
	if not is_mobile:
		return

	screen_size = get_viewport().get_visible_rect().size
	joystick_zone = Rect2(0, 0, screen_size.x * 0.4, screen_size.y)
	action_zone = Rect2(screen_size.x * 0.4, 0, screen_size.x * 0.6, screen_size.y)

func _input(event: InputEvent) -> void:
	if not is_mobile:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	var touch_pos: Vector2 = event.position
	var touch_id: int = event.index

	if event.pressed:
		touch_positions[touch_id] = touch_pos

		if joystick_zone.has_point(touch_pos):
			# Joystick input (movement)
			_update_joystick(touch_pos)
		else:
			# Action buttons
			_handle_action_button(touch_pos)
	else:
		touch_positions.erase(touch_id)

		if joystick_zone.has_point(touch_pos):
			current_movement = 0.0
			touch_move.emit(0.0)
		else:
			_release_action_button(touch_pos)

func _handle_drag(event: InputEventScreenDrag) -> void:
	var touch_id: int = event.index
	var touch_pos: Vector2 = event.position

	touch_positions[touch_id] = touch_pos

	if joystick_zone.has_point(touch_pos):
		_update_joystick(touch_pos)

func _update_joystick(touch_pos: Vector2) -> void:
	var joystick_center: Vector2 = Vector2(screen_size.x * 0.2, screen_size.y / 2)
	var delta: Vector2 = touch_pos - joystick_center

	if delta.length() < JOYSTICK_DEADZONE:
		current_movement = 0.0
	else:
		current_movement = sign(delta.x)

	touch_move.emit(current_movement)

func _handle_action_button(touch_pos: Vector2) -> void:
	var button_y_positions: Array = [
		screen_size.y / 4,          # Jump
		screen_size.y / 2,          # Sprint
		3 * screen_size.y / 4,      # Dash
		screen_size.y - BUTTON_SIZE - 20,  # Interact
	]
	var button_center_x: float = screen_size.x - BUTTON_SIZE

	for i in range(button_y_positions.size()):
		var button_rect: Rect2 = Rect2(
			button_center_x - BUTTON_SIZE / 2,
			button_y_positions[i] - BUTTON_SIZE / 2,
			BUTTON_SIZE,
			BUTTON_SIZE
		)

		if button_rect.has_point(touch_pos):
			match i:
				0:
					touch_jump.emit()
				1:
					button_states["sprint"] = true
					touch_sprint.emit()
				2:
					touch_dash.emit()
				3:
					touch_interact.emit()

func _release_action_button(touch_pos: Vector2) -> void:
	if button_states["sprint"]:
		button_states["sprint"] = false
		touch_sprint_released.emit()

func get_movement_input() -> float:
	return current_movement

func is_sprint_active() -> bool:
	return button_states["sprint"]

# Fallback to keyboard if not mobile
func _physics_process(_delta: float) -> void:
	if is_mobile:
		return

	# Desktop fallback: keyboard still works
	var kb_movement: float = 0.0
	if Input.is_action_pressed("move_left"):
		kb_movement = -1.0
	elif Input.is_action_pressed("move_right"):
		kb_movement = 1.0
	current_movement = kb_movement
