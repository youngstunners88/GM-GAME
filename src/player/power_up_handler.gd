class_name PowerUpHandler
extends Node

var speed_multiplier: float = 1.0
var jump_multiplier: float = 1.0
var invincible_timer: float = 0.0
var blaze_smoke_timer: float = 0.0
var current_scale: Vector2 = Vector2.ONE
var player: Node2D

func _ready() -> void:
	player = get_parent()

func _physics_process(delta: float) -> void:
	_update_invincibility(delta)
	_update_blaze(delta)
	_update_scale()

func _update_invincibility(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta
		player.sprite.visible = fmod(invincible_timer, 0.15) < 0.075
	else:
		player.sprite.visible = true

func _update_blaze(delta: float) -> void:
	if GameManager.has_power_up("blaze"):
		speed_multiplier = 1.4
		jump_multiplier = 1.3
		blaze_smoke_timer -= delta
		if blaze_smoke_timer <= 0:
			player.emit_blaze_smoke()
			blaze_smoke_timer = 2.0
	else:
		speed_multiplier = 1.0
		jump_multiplier = 1.0

func _update_scale() -> void:
	if GameManager.has_power_up("big"):
		current_scale = Vector2(1.5, 1.5)
	else:
		current_scale = Vector2(1.0, 1.0)
	player.scale = current_scale

func activate_invincibility(duration: float) -> void:
	invincible_timer = duration
