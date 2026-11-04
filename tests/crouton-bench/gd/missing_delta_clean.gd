extends CharacterBody2D

const SPEED := 120.0

func _physics_process(delta: float) -> void:
	position.x += SPEED * delta
	move_and_slide()
