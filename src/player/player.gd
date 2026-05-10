class_name Player
extends CharacterBody2D

enum Outfit { DEFAULT, MINER, CRYSTAL }

signal died

@export var walk_speed: float = 200.0
@export var jump_force: float = -420.0
@export var gravity: float = 980.0
@export var double_jump_force: float = -350.0

var current_outfit: Outfit = Outfit.DEFAULT

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var smoke_spawn: Marker2D = $SmokeSpawn
@onready var hurtbox: Area2D = $Hurtbox
@onready var aura: Area2D = $Aura
@onready var power_up_handler: PowerUpHandler = $PowerUpHandler
@onready var input_handler: InputHandler = $InputHandler

func _ready() -> void:
	add_to_group("player")
	GameManager.reset_level()
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	aura.body_entered.connect(_on_aura_body_entered)
	ScreenShake.register_camera(camera)

func _physics_process(delta: float) -> void:
	if not StateMachine.is_playing():
		return

	var speed_mult: float = power_up_handler.speed_multiplier
	var jump_mult: float = power_up_handler.jump_multiplier

	# Gravity + floor state
	if not is_on_floor():
		velocity.y += gravity * delta
		input_handler.on_left_ground()
	else:
		var had_buffer := input_handler.jump_buffer_timer > 0
		input_handler.on_landed()
		if had_buffer:
			velocity.y = jump_force * jump_mult
			AudioManager.play_sfx("jump")

	# Variable jump height — release early to cut arc
	if input_handler.is_jump_released() and velocity.y < 0:
		velocity.y *= 0.5

	# Movement
	var direction := input_handler.get_movement_direction()
	if direction != 0:
		velocity.x = direction * walk_speed * speed_mult
		input_handler.handle_facing_direction(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * speed_mult)

	# Jump
	if input_handler.is_jump_pressed():
		if is_on_floor() or input_handler.coyote_timer > 0:
			velocity.y = jump_force * jump_mult
			input_handler.reset_coyote()
			input_handler.can_double_jump = true
			AudioManager.play_sfx("jump")
		elif input_handler.consume_double_jump() and not GameManager.has_power_up("big"):
			velocity.y = double_jump_force * jump_mult
			AudioManager.play_sfx("double_jump")
		else:
			input_handler.buffer_jump()

	_update_sprite_color()
	move_and_slide()
	aura.monitoring = GameManager.has_power_up("diamond")
	GameManager.player_position = global_position

func _update_sprite_color() -> void:
	if GameManager.has_power_up("diamond"):
		sprite.color = Color(0.0, 1.0, 1.0, 0.9)
	elif GameManager.has_power_up("blaze"):
		sprite.color = Color(0.2, 1.0, 0.2, 0.9)
	elif GameManager.has_power_up("big"):
		sprite.color = Color(1.0, 0.4, 0.4, 0.9)
	else:
		sprite.color = Color(0.2, 0.8, 0.2, 1.0)

func emit_blaze_smoke() -> void:
	var puff := preload("res://src/effects/smoke_puff.tscn").instantiate()
	puff.global_position = smoke_spawn.global_position
	var base_dir := Vector2.RIGHT if input_handler.facing_right else Vector2.LEFT
	puff.direction = base_dir + Vector2(velocity.x * 0.3 / walk_speed, 0.0)
	get_tree().current_scene.add_child(puff)

func take_damage(amount: int) -> void:
	if StateMachine.is_dead() or power_up_handler.invincible_timer > 0:
		return
	GameManager.take_damage(amount)
	ScreenShake.shake(0.2, 5.0)
	if GameManager.player_health <= 0:
		die()
	else:
		velocity.y = -250.0
		velocity.x = -200.0 if input_handler.facing_right else 200.0
		power_up_handler.activate_invincibility(1.0)
		AudioManager.play_sfx("damage")

func die() -> void:
	if StateMachine.is_dead():
		return
	StateMachine.change_state(StateMachine.State.GAME_OVER)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.finished.connect(_on_death_anim_done)

func _on_death_anim_done() -> void:
	died.emit()
	var checkpoint := GameManager.get_checkpoint(1)
	if checkpoint != Vector2.ZERO:
		global_position = checkpoint + Vector2(0, -50)
		GameManager.player_health = GameManager.max_health
		GameManager.health_changed.emit(GameManager.player_health)
		scale = Vector2.ONE
		modulate.a = 1.0
		velocity = Vector2.ZERO
		power_up_handler.activate_invincibility(1.5)
		StateMachine.change_state(StateMachine.State.PLAYING)
	else:
		get_tree().reload_current_scene()

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("collectible") and area.has_method("collect"):
		area.collect()
	elif area.is_in_group("powerup") and area.has_method("collect"):
		area.collect()

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("deal_damage"):
		body.deal_damage(self)
	elif body.is_in_group("hazard"):
		take_damage(1)

func _on_aura_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(1)

## Switch player visual outfit by level theme.
func set_outfit(outfit: Outfit) -> void:
	current_outfit = outfit
	match outfit:
		Outfit.DEFAULT:
			sprite.color = Color(0.2, 0.8, 0.3, 1.0)
		Outfit.MINER:
			sprite.color = Color(0.6, 0.5, 0.2, 1.0)
		Outfit.CRYSTAL:
			sprite.color = Color(0.3, 0.6, 0.9, 1.0)
