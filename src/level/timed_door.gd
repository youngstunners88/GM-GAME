class_name TimedDoor
extends StaticBody2D

@export var door_width: float = 60.0
@export var door_height: float = 120.0
@export var open_duration: float = 3.0

var _is_open: bool = false
var _visual: ColorRect
var _collision: CollisionShape2D

func _ready() -> void:
	_setup_visual()

func _setup_visual() -> void:
	_visual = ColorRect.new()
	_visual.color = Color(0.8, 0.3, 0.1, 1.0)
	_visual.size = Vector2(door_width, door_height)
	_visual.position = Vector2(-door_width / 2, -door_height / 2)
	add_child(_visual)

	_collision = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(door_width, door_height)
	_collision.shape = shape
	_collision.position = Vector2(0, 0)
	add_child(_collision)

func open() -> void:
	if _is_open:
		return
	_is_open = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.5)
	await tween.finished
	_collision.disabled = true
	await get_tree().create_timer(open_duration).timeout
	close()

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_collision.disabled = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)
	tween.parallel().tween_property(_visual, "modulate:a", 1.0, 0.5)
