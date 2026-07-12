extends CanvasLayer
## Mobile touch control UI overlay — virtual joystick + action buttons.
## Only visible on mobile devices. Desktop uses keyboard.

class_name MobileControls

@export var button_size: float = 80.0
@export var button_spacing: float = 100.0

var is_mobile: bool = OS.get_name() in ["Android", "iOS"]

# Visual elements
var joystick_bg: ColorRect
var joystick_stick: ColorRect
var jump_button: Button
var sprint_button: Button
var dash_button: Button
var interact_button: Button
var attack_button: Button

func _ready() -> void:
	if not is_mobile:
		hide()
		return

	visible = true
	_setup_joystick()
	_setup_buttons()

	# Connect MobileInputHandler signals
	if MobileInputHandler:
		MobileInputHandler.touch_jump.connect(_on_jump_pressed)
		MobileInputHandler.touch_sprint.connect(_on_sprint_pressed)
		MobileInputHandler.touch_sprint_released.connect(_on_sprint_released)
		MobileInputHandler.touch_dash.connect(_on_dash_pressed)
		MobileInputHandler.touch_interact.connect(_on_interact_pressed)

func _setup_joystick() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# Joystick background (left side, 40% of screen)
	joystick_bg = ColorRect.new()
	joystick_bg.color = Color(0.2, 0.2, 0.2, 0.5)
	joystick_bg.size = Vector2(viewport_size.x * 0.4, viewport_size.y)
	joystick_bg.position = Vector2(0, 0)
	add_child(joystick_bg)

	# Joystick stick (inner circle)
	joystick_stick = ColorRect.new()
	joystick_stick.color = Color(0.5, 0.8, 0.5, 0.7)
	joystick_stick.size = Vector2(60, 60)
	joystick_stick.position = Vector2(viewport_size.x * 0.2 - 30, viewport_size.y / 2 - 30)
	add_child(joystick_stick)

func _setup_buttons() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var button_x: float = viewport_size.x - button_size - 20

	# Jump button (top)
	jump_button = Button.new()
	jump_button.text = "JUMP"
	jump_button.custom_minimum_size = Vector2(button_size, button_size)
	jump_button.position = Vector2(button_x, 20)
	jump_button.modulate = Color(0.3, 0.8, 1.0, 0.8)
	jump_button.pressed.connect(_on_jump_button)
	add_child(jump_button)

	# Sprint button (middle)
	sprint_button = Button.new()
	sprint_button.text = "SPRINT"
	sprint_button.custom_minimum_size = Vector2(button_size, button_size)
	sprint_button.position = Vector2(button_x, 20 + button_spacing)
	sprint_button.modulate = Color(1.0, 0.6, 0.3, 0.8)
	sprint_button.pressed.connect(_on_sprint_button)
	add_child(sprint_button)

	# Dash button (lower)
	dash_button = Button.new()
	dash_button.text = "DASH"
	dash_button.custom_minimum_size = Vector2(button_size, button_size)
	dash_button.position = Vector2(button_x, 20 + button_spacing * 2)
	dash_button.modulate = Color(0.8, 0.3, 1.0, 0.8)
	dash_button.pressed.connect(_on_dash_button)
	add_child(dash_button)

	# Interact button (bottom)
	interact_button = Button.new()
	interact_button.text = "E"
	interact_button.custom_minimum_size = Vector2(button_size, button_size)
	interact_button.position = Vector2(button_x, viewport_size.y - button_size - 20)
	interact_button.modulate = Color(0.8, 0.8, 0.3, 0.8)
	interact_button.pressed.connect(_on_interact_button)
	add_child(interact_button)

	# Attack button (left of the action stack) — press-and-hold aware so the
	# purple ETH-flask fire-breath channel works on touch, not just keyboard.
	attack_button = Button.new()
	attack_button.text = "ATK"
	attack_button.custom_minimum_size = Vector2(button_size, button_size)
	attack_button.position = Vector2(button_x - button_spacing, 20 + button_spacing)
	attack_button.modulate = Color(1.0, 0.4, 0.4, 0.85)
	attack_button.button_down.connect(_on_attack_down)
	attack_button.button_up.connect(_on_attack_up)
	add_child(attack_button)

func _on_jump_button() -> void:
	if MobileInputHandler:
		MobileInputHandler.touch_jump.emit()

func _on_sprint_button() -> void:
	if MobileInputHandler:
		MobileInputHandler.touch_sprint.emit()

func _on_dash_button() -> void:
	if MobileInputHandler:
		MobileInputHandler.touch_dash.emit()

func _on_interact_button() -> void:
	if MobileInputHandler:
		MobileInputHandler.touch_interact.emit()

func _on_attack_down() -> void:
	if attack_button:
		attack_button.modulate = Color(1.0, 0.6, 0.6, 1.0)
	if MobileInputHandler:
		MobileInputHandler.touch_attack.emit()

func _on_attack_up() -> void:
	if attack_button:
		attack_button.modulate = Color(1.0, 0.4, 0.4, 0.85)
	if MobileInputHandler:
		MobileInputHandler.touch_attack_released.emit()

# Input event handlers (called from MobileInputHandler)
func _on_jump_pressed() -> void:
	if jump_button:
		jump_button.modulate = Color(0.5, 1.0, 1.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		jump_button.modulate = Color(0.3, 0.8, 1.0, 0.8)

func _on_sprint_pressed() -> void:
	if sprint_button:
		sprint_button.modulate = Color(1.0, 0.8, 0.5, 1.0)

func _on_sprint_released() -> void:
	if sprint_button:
		sprint_button.modulate = Color(1.0, 0.6, 0.3, 0.8)

func _on_dash_pressed() -> void:
	if dash_button:
		dash_button.modulate = Color(1.0, 0.5, 1.0, 1.0)
		await get_tree().create_timer(0.1).timeout
		dash_button.modulate = Color(0.8, 0.3, 1.0, 0.8)

func _on_interact_pressed() -> void:
	if interact_button:
		interact_button.modulate = Color(1.0, 1.0, 0.7, 1.0)
		await get_tree().create_timer(0.1).timeout
		interact_button.modulate = Color(0.8, 0.8, 0.3, 0.8)
