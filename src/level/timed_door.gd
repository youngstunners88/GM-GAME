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

## Restyled 2026-08-04 — founder called the flat orange rectangles in Level 3
## "trashy and cheap" and red-circled them. This gate was one of them: a bare
## untextured ColorRect in #cc4d1a. Now built the same way every real platform
## is (dark body + tiled block texture + bright gold lip), so it reads as a
## gold-rush gate rather than a placeholder box.
const BLOCK_TEX := preload("res://src/assets/sprites/tile_block-chain.png")

func _setup_visual() -> void:
	_visual = ColorRect.new()
	_visual.color = Color(0.18, 0.09, 0.04, 1.0)   # L3 platform_body_color
	_visual.size = Vector2(door_width, door_height)
	_visual.position = Vector2(-door_width / 2, -door_height / 2)
	add_child(_visual)

	var blocks := Sprite2D.new()
	blocks.texture = BLOCK_TEX
	blocks.centered = false
	blocks.region_enabled = true
	blocks.region_rect = Rect2(0, 0, door_width, door_height)
	blocks.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	blocks.position = Vector2(-door_width / 2, -door_height / 2)
	blocks.modulate = Color(1.0, 0.8, 0.55, 0.9)
	_visual.add_child(blocks)

	# Gold cap + foot so the gate reads as a machined object with a top and
	# a bottom, not a slab.
	for edge_y in [0.0, door_height - 5.0]:
		var band := ColorRect.new()
		band.color = Color(0.95, 0.75, 0.2, 1.0)   # L3 platform_lip_color
		band.size = Vector2(door_width, 5)
		band.position = Vector2(0, edge_y)
		_visual.add_child(band)

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
	if not is_instance_valid(self) or not is_inside_tree():
		return
	# set_deferred: this line runs after `await tween.finished`, which resumes
	# inside the frame's physics step, so a direct write throws
	# "Can't change this state while flushing queries" from
	# body_set_shape_disabled (2026-07-30 playtest).
	_collision.set_deferred("disabled", true)
	await get_tree().create_timer(open_duration).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	close()

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	# Reached from open()'s awaited timer — same flush hazard as above.
	_collision.set_deferred("disabled", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)
	tween.parallel().tween_property(_visual, "modulate:a", 1.0, 0.5)
