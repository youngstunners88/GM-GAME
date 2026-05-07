extends CharacterBody2D

@export var roll_speed: float = 200.0
@export var gravity: float = 980.0

var direction: float = 1.0

@onready var sprite: ColorRect = $ColorRect

func _ready() -> void:
    add_to_group("hazard")
    sprite.color = Color(0.5, 0.5, 0.5, 1.0)
    sprite.size = Vector2(48, 48)
    $CollisionShape2D.shape.radius = 24.0
    $CollisionShape2D.position = Vector2(24, 24)

func _physics_process(delta: float) -> void:
    velocity.x = roll_speed * direction
    velocity.y += gravity * delta

    move_and_slide()

    # Bounce off walls
    if is_on_wall():
        direction *= -1.0

    # Rotate visual
    sprite.rotation += direction * roll_speed * delta * 0.01

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and body.has_method("take_damage"):
        body.take_damage(2)
