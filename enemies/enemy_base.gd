class_name EnemyBase
extends CharacterBody2D

@export var health: int = 1
@export var score_value: int = 50
@export var contact_damage: int = 1

var is_dead: bool = false
var is_flashing: bool = false

@onready var sprite: ColorRect = $ColorRect

func _ready() -> void:
    add_to_group("enemy")

func take_damage(amount: int) -> void:
    if is_dead:
        return
    health -= amount
    flash()
    if health <= 0:
        die()

func flash() -> void:
    if is_flashing:
        return
    is_flashing = true
    var tween := create_tween()
    tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
    tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
    await tween.finished
    is_flashing = false

func die() -> void:
    is_dead = true
    GameManager.add_score(score_value)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
    tween.tween_property(self, "modulate:a", 0.0, 0.3)
    await tween.finished
    queue_free()

func deal_damage(target: Node2D) -> void:
    if target.has_method("take_damage"):
        target.take_damage(contact_damage)
