extends Area2D

@export var speed: float = 200.0
@export var lifetime: float = 5.0

var velocity: Vector2 = Vector2.ZERO
var time_alive: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * speed

func _physics_process(delta: float) -> void:
	position += velocity * delta
	time_alive += delta
	if time_alive > lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()
