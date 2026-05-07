extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var lifetime: float = 3.0

@onready var sprite: ColorRect = $ColorRect

func _ready() -> void:
    add_to_group("projectile")
    body_entered.connect(_on_body_entered)
    area_entered.connect(_on_area_entered)
    sprite.color = Color(0.8, 0.9, 0.8, 0.6)
    sprite.size = Vector2(20, 20)
    $CollisionShape2D.position = Vector2(10, 10)
    # Fade out
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, lifetime)
    tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("enemy") and body.has_method("take_damage"):
        body.take_damage(1)
        queue_free()
    elif body.is_in_group("breakable") and body.has_method("break_block"):
        body.break_block()
        queue_free()

func _on_area_entered(area: Area2D) -> void:
    if area.is_in_group("breakable") and area.has_method("break_block"):
        area.break_block()
        queue_free()
