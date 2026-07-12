class_name Player
extends CharacterBody2D

enum Outfit { DEFAULT, MINER, CRYSTAL }

signal died

@export var walk_speed: float = 200.0
@export var jump_force: float = -420.0
@export var gravity: float = 980.0
@export var double_jump_force: float = -350.0

var current_outfit: Outfit = Outfit.DEFAULT

@onready var sprite: LilBluntVisual = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var smoke_spawn: Marker2D = $SmokeSpawn
@onready var hurtbox: Area2D = $Hurtbox
@onready var aura: Area2D = $Aura
@onready var power_up_handler: PowerUpHandler = $PowerUpHandler
@onready var input_handler: InputHandler = $InputHandler
@onready var wall_sparks: CPUParticles2D = $WallSparks
@onready var sprint_dust: CPUParticles2D = $SprintDust

func _ready() -> void:
	add_to_group("player")
	GameManager.reset_level()
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	aura.body_entered.connect(_on_aura_body_entered)
	ScreenShake.register_camera(camera)

	if MobileInputHandler:
		MobileInputHandler.touch_jump.connect(_on_mobile_jump)
		MobileInputHandler.touch_dash.connect(_on_mobile_dash)

func _physics_process(delta: float) -> void:
	if not StateMachine.is_playing():
		return

	var speed_mult: float = power_up_handler.speed_multiplier
	var jump_mult: float = power_up_handler.jump_multiplier
	var sprint_mult: float = input_handler.get_sprint_multiplier()

	# Get movement input from keyboard OR mobile
	var movement_direction: float = input_handler.get_movement_direction()
	if MobileInputHandler:
		movement_direction = MobileInputHandler.get_movement_input()

	# Gravity — wall slide uses reduced gravity while pressing into the wall
	if not is_on_floor():
		var pressing_wall := is_on_wall() and movement_direction != 0
		if pressing_wall and velocity.y > 0:
			input_handler.is_wall_sliding = true
			velocity.y += InputHandler.WALL_SLIDE_GRAVITY * delta
			wall_sparks.emitting = true
		else:
			input_handler.is_wall_sliding = false
			velocity.y += gravity * delta
			wall_sparks.emitting = false
		input_handler.on_left_ground()
	else:
		input_handler.is_wall_sliding = false
		wall_sparks.emitting = false
		var had_buffer := input_handler.jump_buffer_timer > 0
		input_handler.on_landed()
		if had_buffer:
			velocity.y = jump_force * jump_mult
			_play_jump_stretch()
			AudioManager.play_sfx("jump")

	# Variable jump height — release early to cut arc (Skill 3)
	if input_handler.is_jump_released() and velocity.y < 0:
		velocity.y *= 0.5

	# Movement + sprint
	var direction := input_handler.get_movement_direction()
	if direction != 0:
		velocity.x = direction * walk_speed * speed_mult * sprint_mult
		input_handler.handle_facing_direction(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * speed_mult)

	# Sprint dust — only when running fast on ground
	sprint_dust.emitting = is_on_floor() and direction != 0 and sprint_mult > 1.0

	# Jump — floor/coyote, wall jump, double jump
	if input_handler.is_jump_pressed():
		if is_on_floor() or input_handler.coyote_timer > 0:
			velocity.y = jump_force * jump_mult
			input_handler.reset_coyote()
			input_handler.can_double_jump = true
			input_handler.can_air_dash = true
			_play_jump_stretch()
			AudioManager.play_sfx("jump")
		elif input_handler.is_wall_sliding:
			var wall_dir := -1.0 if input_handler.facing_right else 1.0
			velocity.x = wall_dir * input_handler.wall_jump_force.x * 1.2
			velocity.y = input_handler.wall_jump_force.y
			input_handler.is_wall_sliding = false
			input_handler.can_double_jump = true
			input_handler.can_air_dash = true
			_play_jump_stretch()
			AudioManager.play_sfx("jump")
		elif input_handler.consume_double_jump() and not GameManager.has_power_up("big"):
			velocity.y = double_jump_force * jump_mult
			input_handler.can_air_dash = true
			_play_jump_stretch()
			AudioManager.play_sfx("double_jump")
		else:
			input_handler.buffer_jump()

	# Air dash (Tier 2 Skill 1) — horizontal dash in mid-air
	if Input.is_action_just_pressed("dash") and input_handler.is_air_dash_available():
		var dash_dir := input_handler.get_movement_direction()
		if dash_dir == 0:
			dash_dir = 1.0 if input_handler.facing_right else -1.0
		velocity.x = dash_dir * InputHandler.AIR_DASH_SPEED
		input_handler.consume_air_dash()
		AudioManager.play_sfx("dash")

	_update_sprite_color()
	_update_tool_visual()
	sprite.facing_right = input_handler.facing_right
	sprite.moving = is_on_floor() and absf(velocity.x) > 10.0
	move_and_slide()
	# Torch heat shares the diamond damage aura — both burn enemies on contact.
	aura.monitoring = GameManager.has_power_up("diamond") or GameManager.has_power_up("torch")
	_check_pickaxe_breaks()
	GameManager.player_position = global_position

## With the pickaxe out, walking into a breakable block smashes it.
func _check_pickaxe_breaks() -> void:
	if not GameManager.has_power_up("pickaxe"):
		return
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("breakable") and collider.has_method("break_block"):
			collider.break_block()

## Show the held tool sprite while a tool power-up is active.
func _update_tool_visual() -> void:
	if GameManager.has_power_up("pickaxe"):
		sprite.set_tool("res://src/assets/sprites/sprite_item_pickaxe.png")
	elif GameManager.has_power_up("torch"):
		sprite.set_tool("res://src/assets/sprites/sprite_item_torch.png")
	else:
		sprite.set_tool("")

func _update_sprite_color() -> void:
	# Tints over the real sprite art; WHITE = untinted.
	if GameManager.has_power_up("diamond"):
		sprite.color = Color(0.55, 1.0, 1.0, 0.95)
	elif GameManager.has_power_up("purple"):
		sprite.color = Color(0.85, 0.6, 1.0, 0.95)
	elif GameManager.has_power_up("blaze"):
		sprite.color = Color(0.7, 1.0, 0.6, 0.95)
	elif GameManager.has_power_up("big"):
		sprite.color = Color(1.0, 0.7, 0.7, 0.95)
	elif GameManager.has_power_up("torch"):
		sprite.color = Color(1.0, 0.85, 0.65, 1.0)
	else:
		sprite.color = Color.WHITE

## Stretch on launch, snap back — skipped in big mode to avoid fighting PowerUpHandler.
func _play_jump_stretch() -> void:
	if GameManager.has_power_up("big"):
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.06)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)

## Squash on land.
func _play_land_squash() -> void:
	if GameManager.has_power_up("big"):
		return
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 0.7), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)

func emit_blaze_smoke() -> void:
	var puff := preload("res://src/effects/smoke_puff.tscn").instantiate()
	puff.global_position = smoke_spawn.global_position
	var base_dir := Vector2.RIGHT if input_handler.facing_right else Vector2.LEFT
	puff.direction = base_dir + Vector2(velocity.x * 0.3 / walk_speed, 0.0)
	get_tree().current_scene.add_child(puff)

func take_damage(amount: int) -> void:
	# Damage only exists while PLAYING. This also protects the boss-victory
	# window (LEVEL_COMPLETE): dying there used to wedge the StateMachine
	# into an unrecoverable state and boot the player to the main menu.
	if not StateMachine.is_playing() or power_up_handler.invincible_timer > 0:
		return
	GameManager.take_damage(amount)
	ComboSystem.break_combo()
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
	# If the transition is refused (e.g. boss just won the level), do NOT run
	# the death sequence — its end would fail to restore PLAYING and freeze us.
	if not StateMachine.change_state(StateMachine.State.GAME_OVER):
		return
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
	# Pickaxe shatters boulders instead of them hurting us.
	if GameManager.has_power_up("pickaxe") and body.has_method("smash"):
		body.smash()
		return
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
	sprite.set_outfit(outfit)

func _on_mobile_jump() -> void:
	input_handler.buffer_jump()

func _on_mobile_dash() -> void:
	if input_handler.is_air_dash_available():
		var dash_dir := input_handler.get_movement_direction()
		if dash_dir == 0:
			dash_dir = 1.0 if input_handler.facing_right else -1.0
		velocity.x = dash_dir * InputHandler.AIR_DASH_SPEED
		input_handler.consume_air_dash()
		AudioManager.play_sfx("dash")
