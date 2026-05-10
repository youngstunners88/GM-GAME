class_name EnemyBase
extends CharacterBody2D

@export var max_health: int = 3
@export var speed: float = 100.0
@export var damage: int = 1

var health: int = 3
var is_dead: bool = false

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	health = max_health
	add_to_group("enemy")

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	AudioManager.play_sfx("damage")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	set_physics_process(false)
	GameManager.add_score(100)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()

func deal_damage(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
