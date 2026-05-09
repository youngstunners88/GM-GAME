class_name MineCart
extends AnimatableBody2D

@export var move_distance: float = 200.0
@export var cycle_time: float = 8.0
@export var start_delay: float = 0.0

var _time_elapsed: float = 0.0
var _visual: ColorRect
var _flash_timer: float = 0.0
var _is_flashing: bool = false

func _ready() -> void:
	_setup_visual()
	_time_elapsed = start_delay

func _setup_visual() -> void:
	_visual = ColorRect.new()
	_visual.color = Color(0.4, 0.2, 0.05, 1.0)
	_visual.size = Vector2(80, 40)
	_visual.position = Vector2(-40, -20)
	add_child(_visual)

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 40)
	col.shape = shape
	col.position = Vector2(0, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	_time_elapsed += delta

	var cycle_position = fmod(_time_elapsed, cycle_time) / cycle_time
	var new_x = move_distance * cycle_position
	position.x = new_x

	_check_warning_flash(cycle_position)

func _check_warning_flash(cycle_position: float) -> void:
	var time_until_departure = (1.0 - cycle_position) * cycle_time
	if time_until_departure <= 2.0:
		if not _is_flashing:
			_is_flashing = true
			_start_flash()
	else:
		_is_flashing = false
		_visual.modulate = Color.WHITE

func _start_flash() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_visual, "modulate", Color.YELLOW, 0.2)
	tween.tween_property(_visual, "modulate", Color.WHITE, 0.2)
