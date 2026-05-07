extends AnimatableBody2D

@export var move_distance: float = 100.0
@export var move_speed: float = 50.0
@export var vertical: bool = false

var start_pos: Vector2 = Vector2.ZERO
var moving_forward: bool = true

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    start_pos = position
    sprite.color = Color(0.7, 0.8, 0.75, 0.5)
    sprite.size = Vector2(100, 20)
    collision.position = Vector2(50, 10)
    # One-way collision so player can jump through from below
    collision.one_way_collision = true

func _physics_process(delta: float) -> void:
    var target := start_pos + (Vector2(0, move_distance) if vertical else Vector2(move_distance, 0))
    var back := start_pos

    if moving_forward:
        position = position.move_toward(target, move_speed * delta)
        if position.distance_to(target) < 1.0:
            moving_forward = false
    else:
        position = position.move_toward(back, move_speed * delta)
        if position.distance_to(back) < 1.0:
            moving_forward = true
