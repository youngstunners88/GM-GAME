class_name Player
extends CharacterBody2D

enum Outfit { DEFAULT, MINER, CRYSTAL }

signal died

@export var walk_speed: float = 200.0
@export var jump_force: float = -430.0
@export var gravity: float = 1000.0
@export var double_jump_force: float = -370.0
## Falling pulls harder than rising — same jump height (level gaps unchanged),
## ~15% less airtime, kills the floaty feel.
@export var fall_gravity_mult: float = 1.65
@export var max_fall_speed: float = 720.0
## px/s² — ~0.1s from standstill to full run on the ground.
@export var ground_accel: float = 2000.0
@export var ground_decel: float = 2800.0
@export var air_accel: float = 1400.0
@export var air_decel: float = 900.0
## Friction applied when moving faster than input speed in the same direction —
## lets dash/knockback/wall-jump momentum bleed off instead of hard-snapping.
@export var momentum_friction_floor: float = 1200.0
@export var momentum_friction_air: float = 350.0
## Bong "fly" power-up: hold jump/up to rise, release to drift down gently.
## No gravity while active — pure floaty control for the ~10s duration.
@export var fly_rise_speed: float = 260.0
@export var fly_sink_speed: float = 90.0

var current_outfit: Outfit = Outfit.DEFAULT
var _last_fall_speed: float = 0.0

# Ladder climbing state (task #23): zone refcount maintained by ladder.gd via
# enter/exit_ladder_zone(); _climbing is the CLIMB state flag.
var _ladder_zones: int = 0
var _climbing: bool = false
@export var climb_speed: float = 150.0

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

	# Bong flight: hold jump/up to rise, otherwise sink slowly. Overrides all
	# normal gravity/wall/jump vertical logic for the duration. Trippy green
	# smoke trail sells the "lifted" fantasy.
	if GameManager.has_power_up("fly"):
		_update_fly(delta, movement_direction)
		return

	# Ladder climbing (task #23). Enter by pressing up/down inside a ladder
	# zone; while climbing gravity is off and vertical input drives movement.
	# Jump exits with a full jump (mid-climb hop-off); leaving the zone exits.
	if _climbing:
		_update_climb(delta, movement_direction)
		return
	if _ladder_zones > 0 and (Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")):
		_climbing = true
		velocity = Vector2.ZERO
		input_handler.is_wall_sliding = false
		wall_sparks.emitting = false

	# Gravity — wall slide uses reduced gravity while pressing into the wall
	if not is_on_floor():
		var pressing_wall := is_on_wall() and movement_direction != 0
		if pressing_wall and velocity.y > 0:
			input_handler.is_wall_sliding = true
			velocity.y = minf(velocity.y + InputHandler.WALL_SLIDE_GRAVITY * delta,
					InputHandler.WALL_SLIDE_MAX_SPEED)
			wall_sparks.emitting = true
		else:
			input_handler.is_wall_sliding = false
			var g := gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0)
			velocity.y = minf(velocity.y + g * delta, max_fall_speed)
			wall_sparks.emitting = false
		_last_fall_speed = velocity.y
		input_handler.on_left_ground()
	else:
		input_handler.is_wall_sliding = false
		wall_sparks.emitting = false
		var had_buffer := input_handler.jump_buffer_timer > 0
		# First frame back on the ground after a hard fall → landing squash.
		if input_handler.coyote_timer <= 0 and _last_fall_speed > 380.0 and not had_buffer:
			_play_land_squash()
		_last_fall_speed = 0.0
		input_handler.on_landed()
		if had_buffer:
			velocity.y = jump_force * jump_mult
			_play_jump_stretch()
			AudioManager.play_sfx("jump")

	# Variable jump height — release early to cut arc (Skill 3)
	if input_handler.is_jump_released() and velocity.y < 0:
		velocity.y *= 0.5

	# Movement + sprint — accelerate toward input speed instead of snapping.
	# Excess same-direction momentum (dash, knockback, wall jump) bleeds off
	# through gentler friction so those moves keep their punch.
	var direction := movement_direction
	if direction != 0:
		input_handler.handle_facing_direction(direction)
		var target_speed := direction * walk_speed * speed_mult * sprint_mult
		if signf(velocity.x) == signf(target_speed) and absf(velocity.x) > absf(target_speed):
			var friction := momentum_friction_floor if is_on_floor() else momentum_friction_air
			velocity.x = move_toward(velocity.x, target_speed, friction * delta)
		else:
			var accel := ground_accel if is_on_floor() else air_accel
			velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		var decel := ground_decel if is_on_floor() else air_decel
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

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
	if Input.is_action_just_pressed("dash"):
		_try_air_dash()

	_update_sprite_color()
	_update_tool_visual()
	sprite.facing_right = input_handler.facing_right
	sprite.moving = is_on_floor() and absf(velocity.x) > 10.0
	sprite.play_animation(_pick_animation())
	move_and_slide()
	# Torch heat shares the diamond damage aura — both burn enemies on contact.
	aura.monitoring = GameManager.has_power_up("diamond") or GameManager.has_power_up("torch")
	_check_pickaxe_breaks()
	GameManager.player_position = global_position

## Bong flight physics: hold jump/up to ascend, otherwise a slow chill sink.
## Horizontal control stays normal so you can steer to hard-to-reach places.
func _update_fly(delta: float, direction: float) -> void:
	var rising := Input.is_action_pressed("jump") or input_handler.jump_buffer_timer > 0.0
	if MobileInputHandler and MobileInputHandler.get_movement_input() == 0.0:
		pass  # movement handled below; jump comes through the buffer/signal
	if rising:
		velocity.y = -fly_rise_speed
	else:
		velocity.y = fly_sink_speed
	# Horizontal: same accel model as normal air control.
	if direction != 0:
		input_handler.handle_facing_direction(direction)
		var target := direction * walk_speed * power_up_handler.speed_multiplier
		velocity.x = move_toward(velocity.x, target, air_accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_decel * delta)
	# Puff a smoke trail every few frames for the lifted look.
	if Engine.get_physics_frames() % 8 == 0:
		emit_blaze_smoke()
	sprite.facing_right = input_handler.facing_right
	sprite.moving = absf(velocity.x) > 10.0
	move_and_slide()
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
	elif GameManager.has_power_up("fly"):
		sprite.color = Color(0.6, 1.0, 0.75, 0.95)
	else:
		sprite.color = Color.WHITE

## Movement-state → animation name; one-shots (attack/hurt/death) are played
## directly at their trigger sites and hold via LilBluntVisual.
func _pick_animation() -> String:
	if not is_on_floor():
		return "jump_up" if velocity.y < 0.0 else "jump_down"
	return "run" if absf(velocity.x) > 10.0 else "idle"

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
		_hitstop()
		sprite.play_animation("hurt")
		velocity.y = -260.0
		velocity.x = -240.0 if input_handler.facing_right else 240.0
		power_up_handler.activate_invincibility(1.0)
		AudioManager.play_sfx("damage")

## Freeze-frame on impact — ~4 frames at 5% speed reads as a hit, not lag.
## Timer ignores time_scale so the freeze always ends on schedule.
func _hitstop(duration: float = 0.07) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

## Ladder zone refcount — called by ladder.gd on Area2D enter/exit.
func enter_ladder_zone() -> void:
	_ladder_zones += 1

func exit_ladder_zone() -> void:
	_ladder_zones = maxi(0, _ladder_zones - 1)
	if _ladder_zones == 0:
		_climbing = false

## CLIMB state: vertical movement on the ladder, no gravity. Jump = hop off
## with a full jump; touching the floor while pushing down also exits.
func _update_climb(delta: float, movement_direction: float) -> void:
	var vertical := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	velocity.y = vertical * climb_speed
	velocity.x = movement_direction * climb_speed * 0.6
	if input_handler.is_jump_pressed():
		_climbing = false
		velocity.y = jump_force * power_up_handler.jump_multiplier
		_play_jump_stretch()
		AudioManager.play_sfx("jump")
		move_and_slide()
		return
	move_and_slide()
	if is_on_floor() and vertical > 0.0:
		_climbing = false

## Falling into a pit — a HARD fail. Plays a devastating sound, costs a LIFE
## (not just health), and respawns at the last checkpoint if lives remain;
## out of lives ends the run to the main menu. Called by the level kill zone.
func pit_death() -> void:
	if StateMachine.is_dead():
		return
	AudioManager.play_sfx("fall")
	ScreenShake.shake(0.5, 10.0)
	# Heatmap: pits are obstacle deaths; surviving ones count as a retry.
	Web3Bridge.report_metric("death", {"obstacle": "pit"})
	if GameManager.lose_life():
		# Out of lives — real game over.
		if StateMachine.change_state(StateMachine.State.GAME_OVER):
			died.emit()
			var t := create_tween()
			t.tween_property(self, "modulate:a", 0.0, 0.5)
			await get_tree().create_timer(1.6).timeout
			SceneRouter.load_scene("res://src/ui/main_menu.tscn", SceneRouter.Transition.FADE)
		return
	# Lives left — respawn at the level's checkpoint (health already refilled).
	Web3Bridge.report_metric("retry", {})
	var checkpoint := GameManager.get_checkpoint(GameManager.current_level)
	if checkpoint == Vector2.ZERO:
		checkpoint = GameManager.get_checkpoint(1)
	if checkpoint != Vector2.ZERO:
		global_position = checkpoint + Vector2(0, -50)
	else:
		global_position = GameManager.player_position + Vector2(0, -260)
	scale = Vector2.ONE
	modulate.a = 1.0
	velocity = Vector2.ZERO
	power_up_handler.activate_invincibility(1.5)

func die() -> void:
	if StateMachine.is_dead():
		return
	# If the transition is refused (e.g. boss just won the level), do NOT run
	# the death sequence — its end would fail to restore PLAYING and freeze us.
	if not StateMachine.change_state(StateMachine.State.GAME_OVER):
		return
	# AgentMail digest hook: attribute the death to the active boss (if any)
	# so the weekly email can say "you died to the Tax Collector N times".
	if BossVoiceSystem._active_boss_id != "":
		Web3Bridge.report_event("death", {"boss": BossVoiceSystem._active_boss_id})
	# Granular heatmap (task #23): enemy attribution feeds dynamic difficulty.
	var src := BossVoiceSystem._active_boss_id
	if src == "":
		src = GameManager.last_damage_source
	if src != "":
		Web3Bridge.report_metric("death", {"enemy": src})
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
	_try_air_dash()

## Shared keyboard/mobile air dash: flat horizontal burst — zeroing vertical
## speed is what makes it read as a punch instead of a nudge mid-fall.
func _try_air_dash() -> void:
	if not input_handler.is_air_dash_available():
		return
	var dash_dir := input_handler.get_movement_direction()
	if dash_dir == 0:
		dash_dir = 1.0 if input_handler.facing_right else -1.0
	velocity.x = dash_dir * InputHandler.AIR_DASH_SPEED
	velocity.y = 0.0
	input_handler.consume_air_dash()
	EffectSpawner.burst("dash_trail", global_position)
	AudioManager.play_sfx("dash")
