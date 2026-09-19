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

## REUSE THE SCENE'S OWN NODES — never add a parallel set.
##
## `timed_door.tscn` ships both a ColorRect and a CollisionShape2D. This
## function used to `.new()` a second one of each and keep only those in
## `_visual` / `_collision`, so the SCENE's CollisionShape2D was never
## referenced and never disabled by open()/close(). The gate had two colliders
## and only ever dropped one: it stayed solid through every "open", which
## killed Stage 3's headline race-the-gate mechanic outright AND welded any
## player standing on its roof to a collider nothing in the script could turn
## off. Measured with a raycast: with `_collision.disabled == true` the body
## still returned a hit. (Founder 2026-09-16: "it disappears and then the
## game freezes".) The stale orange ColorRect from the .tscn was also still
## rendering underneath the restyled one.
func _setup_visual() -> void:
	_visual = get_node_or_null("ColorRect") as ColorRect
	if _visual == null:
		_visual = ColorRect.new()
		add_child(_visual)
	_visual.color = Color(0.18, 0.09, 0.04, 1.0)   # L3 platform_body_color
	# The .tscn lays the rect out with offsets; clear the anchors so the
	# explicit size/position below are what actually applies.
	_visual.anchor_left = 0.0
	_visual.anchor_top = 0.0
	_visual.anchor_right = 0.0
	_visual.anchor_bottom = 0.0
	_visual.size = Vector2(door_width, door_height)
	_visual.position = Vector2(-door_width / 2, -door_height / 2)

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

	# Same rule as the ColorRect above: adopt the scene's collider, never add a
	# second one beside it. A shape resource is built fresh so door_width /
	# door_height stay authoritative even when a level overrides them.
	_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision == null:
		_collision = CollisionShape2D.new()
		add_child(_collision)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(door_width, door_height)
	_collision.shape = shape
	_collision.position = Vector2(0, 0)
	_collision.disabled = false

## NEVER TWEEN THIS BODY'S OWN `scale` (founder 2026-08-26 / 2026-09-16 freeze
## class). This gate is a StaticBody2D the player can stand on — it is a 60x120
## pillar in Stage 3's Gold Rush lane at (1520,530), and its top is a ledge.
## Scaling the BODY scales its CollisionShape2D with it; at the bottom of that
## tween the collider is degenerate (a zero-scale transform is non-invertible),
## and anyone standing on it cannot depenetrate — `is_on_floor()` stops
## resolving and the run hard-freezes with the music still playing.
##
## That exact bug was root-caused and fixed in `breakable_block.gd` and
## `secret_wall.gd`; this file was edited in the SAME pass for the deferred-
## write hazard below but the zero-scale half was never applied here, leaving
## the last live instance of the freeze in the game. Two halves, both needed:
##  1. Drop the collider FIRST, before any animation — the gate stops being a
##     floor immediately and cleanly, so a player on top just falls.
##  2. Animate the VISUAL only. The body's transform stays at scale 1 for its
##     whole life, so a degenerate collider cannot exist at all.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	# set_deferred, not a direct write: open() is reached from a pressure
	# plate's body_entered, i.e. inside a physics flush, where a direct write
	# throws "Can't change this state while flushing queries" from
	# body_set_shape_disabled (2026-07-30 playtest).
	_collision.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2(1.0, 0.0), 0.5)
	tween.parallel().tween_property(_visual, "modulate:a", 0.0, 0.5)
	await tween.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	await get_tree().create_timer(open_duration).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	close()

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector2.ONE, 0.5)
	tween.parallel().tween_property(_visual, "modulate:a", 1.0, 0.5)
	await tween.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	# Restored only once the gate is VISIBLY back, so the collider never leads
	# the art (a solid-but-invisible pillar is its own kind of bug report).
	_collision.set_deferred("disabled", false)
