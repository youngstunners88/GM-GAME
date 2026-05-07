class_name PowerUpBase
extends Area2D

@export var bob_amplitude: float = 5.0
@export var bob_speed: float = 3.0
@export var power_up_type: String = ""
@export var duration: float = 10.0

var start_y: float = 0.0
var time: float = 0.0

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
    add_to_group("powerup")
    body_entered.connect(_on_body_entered)
    start_y = position.y

func _process(delta: float) -> void:
    time += delta
    position.y = start_y + sin(time * bob_speed) * bob_amplitude

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        collect()

func collect() -> void:
    GameManager.activate_power_up(power_up_type, duration)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
    tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
    tween.tween_property(self, "modulate:a", 0.0, 0.2)
    await tween.finished
    queue_free()
