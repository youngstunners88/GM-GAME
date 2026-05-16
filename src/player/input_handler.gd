class_name InputHandler
extends Node

const COYOTE_TIME: float = 0.08
const JUMP_BUFFER: float = 0.08
const WALL_SLIDE_GRAVITY: float = 200.0
const SPRINT_MULTIPLIER: float = 1.2
const AIR_DASH_COOLDOWN: float = 0.5
const AIR_DASH_SPEED: float = 300.0

var wall_jump_force: Vector2 = Vector2(250.0, -350.0)
var air_dash_timer: float = 0.0
var can_air_dash: bool = false

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var can_double_jump: bool = false
var facing_right: bool = true
var is_wall_sliding: bool = false

var player: Node2D

func _ready() -> void:
	player = get_parent()

func _physics_process(delta: float) -> void:
	_update_timers(delta)

func _update_timers(delta: float) -> void:
	if coyote_timer > 0:
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if air_dash_timer > 0:
		air_dash_timer -= delta

func get_movement_direction() -> float:
	return Input.get_axis("move_left", "move_right")

func is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump")

func is_jump_released() -> bool:
	return Input.is_action_just_released("jump")

## Returns 1.2 when sprint held, 1.0 otherwise.
func get_sprint_multiplier() -> float:
	var keyboard_sprint := Input.is_action_pressed("sprint")
	var mobile_sprint := MobileInputHandler and MobileInputHandler.is_sprint_active()
	if keyboard_sprint or mobile_sprint:
		return SPRINT_MULTIPLIER
	return 1.0

func handle_facing_direction(direction: float) -> void:
	if direction != 0:
		facing_right = direction > 0
		player.sprite.scale.x = 1.0 if facing_right else -1.0

func on_landed() -> void:
	is_wall_sliding = false
	can_double_jump = true
	can_air_dash = true
	coyote_timer = COYOTE_TIME
	if jump_buffer_timer > 0:
		jump_buffer_timer = 0.0

func on_left_ground() -> void:
	if coyote_timer <= 0:
		can_double_jump = true
		can_air_dash = true

func buffer_jump() -> void:
	jump_buffer_timer = JUMP_BUFFER

func can_jump() -> bool:
	return coyote_timer > 0 or jump_buffer_timer > 0

func reset_double_jump() -> void:
	can_double_jump = false

func consume_double_jump() -> bool:
	if can_double_jump:
		can_double_jump = false
		return true
	return false

func reset_coyote() -> void:
	coyote_timer = 0.0

func is_air_dash_available() -> bool:
	return can_air_dash and air_dash_timer <= 0

func consume_air_dash() -> bool:
	if can_air_dash and air_dash_timer <= 0:
		can_air_dash = false
		air_dash_timer = AIR_DASH_COOLDOWN
		return true
	return false
