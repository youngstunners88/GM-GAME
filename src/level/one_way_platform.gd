extends StaticBody2D
## One-way platform (task #23, Movie Layer). Jump up through it from below
## (one_way_collision on the shape), stand on top, press Down+Jump to drop
## through (collision briefly disabled — single-player, so the global toggle
## is safe). Placement intent: risk/reward path splits — the hard route pays
## more coins, the safe route pays fewer (LEVEL_DEPTH.md).

@export var width: float = 96.0

const DROP_TIME := 0.35

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var deck: ColorRect = $Deck
@onready var top_zone: Area2D = $TopZone
@onready var top_shape: CollisionShape2D = $TopZone/CollisionShape2D

var _player_on_top: bool = false

func _ready() -> void:
	add_to_group("one_way_platform")
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 10)
	shape.shape = rect
	shape.one_way_collision = true
	shape.one_way_collision_margin = 8.0
	deck.size = Vector2(width, 8)
	deck.position = Vector2(-width / 2.0, -5)
	var tz := RectangleShape2D.new()
	tz.size = Vector2(width, 24)
	top_shape.shape = tz
	top_shape.position = Vector2(0, -16)
	top_zone.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_player_on_top = true)
	top_zone.body_exited.connect(func(b: Node2D) -> void:
		if b.is_in_group("player"):
			_player_on_top = false)

func _physics_process(_delta: float) -> void:
	if _player_on_top and not shape.disabled \
			and Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump"):
		_drop_through()

## Let the player fall through, then restore. Deck dims while passable so the
## interaction reads (skippable ambience, no gameplay info hidden in color).
func _drop_through() -> void:
	shape.set_deferred("disabled", true)
	deck.modulate = Color(1, 1, 1, 0.45)
	get_tree().create_timer(DROP_TIME).timeout.connect(func() -> void:
		shape.set_deferred("disabled", false)
		deck.modulate = Color(1, 1, 1, 1))
