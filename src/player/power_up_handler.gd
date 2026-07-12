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

const DIAMOND_AURA_SCENE := preload("res://src/effects/diamond_aura.tscn")
var _aura_fx: CPUParticles2D

func _physics_process(delta: float) -> void:
	_update_invincibility(delta)
	_update_blaze(delta)
	_update_scale()
	_update_aura_fx()

## Orbiting cyan particles while the Diamond shield is up — attach once on
## activation, free on expiry.
func _update_aura_fx() -> void:
	var want := GameManager.has_power_up("diamond")
	if want and _aura_fx == null:
		_aura_fx = DIAMOND_AURA_SCENE.instantiate()
		player.add_child(_aura_fx)
		_aura_fx.position = Vector2(16, 16)
	elif not want and _aura_fx != null:
		_aura_fx.queue_free()
		_aura_fx = null

func _update_invincibility(delta: float) -> void:
	if invincible_timer > 0:
		invincible_timer -= delta
		player.sprite.visible = fmod(invincible_timer, 0.15) < 0.075
	else:
		player.sprite.visible = true

func _update_blaze(delta: float) -> void:
	# Purple Weed is the flagship strain: everything Blaze does, but stronger
	# and with a faster auto-puff cadence.
	if GameManager.has_power_up("purple"):
		speed_multiplier = 1.6
		jump_multiplier = 1.45
		blaze_smoke_timer -= delta
		if blaze_smoke_timer <= 0:
			player.emit_blaze_smoke()
			blaze_smoke_timer = 1.2
	elif GameManager.has_power_up("blaze"):
		speed_multiplier = 1.4
		jump_multiplier = 1.3
		blaze_smoke_timer -= delta
		if blaze_smoke_timer <= 0:
			player.emit_blaze_smoke()
			blaze_smoke_timer = 2.0
	else:
		speed_multiplier = 1.0
		jump_multiplier = 1.0

## Only push scale to player when the value actually changes — lets juice tweens run.
func _update_scale() -> void:
	var new_scale := Vector2(1.5, 1.5) if GameManager.has_power_up("big") else Vector2.ONE
	if current_scale != new_scale:
		current_scale = new_scale
		player.scale = current_scale

func activate_invincibility(duration: float) -> void:
	invincible_timer = duration
