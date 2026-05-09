class_name Player
extends CharacterBody2D

enum Outfit { DEFAULT, MINER, CRYSTAL }

signal died

@export var walk_speed: float = 200.0
@export var jump_force: float = -420.0
@export var gravity: float = 980.0
@export var double_jump_force: float = -350.0

var current_outfit: Outfit = Outfit.DEFAULT
var can_double_jump: bool = false
var facing_right: bool = true
var blaze_smoke_timer: float = 0.0
var invincible_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
const COYOTE_TIME: float = 0.08
const JUMP_BUFFER: float = 0.08

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var smoke_spawn: Marker2D = $SmokeSpawn
@onready var hurtbox: Area2D = $Hurtbox
@onready var aura: Area2D = $Aura

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

    if invincible_timer > 0:
        invincible_timer -= delta
        sprite.visible = fmod(invincible_timer, 0.15) < 0.075
    else:
        sprite.visible = true

    var speed_mult: float = 1.0
    var jump_mult: float = 1.0

    if GameManager.has_power_up("blaze"):
        speed_mult = 1.4
        jump_mult = 1.3
        blaze_smoke_timer -= delta
        if blaze_smoke_timer <= 0:
            emit_blaze_smoke()
            blaze_smoke_timer = 2.0

    if GameManager.has_power_up("big"):
        scale = Vector2(1.5, 1.5)
    else:
        scale = Vector2(1.0, 1.0)

    # Coyote time and jump buffer timers
    if coyote_timer > 0:
        coyote_timer -= delta
    if jump_buffer_timer > 0:
        jump_buffer_timer -= delta

    # Gravity
    if not is_on_floor():
        velocity.y += gravity * delta
        if coyote_timer <= 0 and velocity.y > 0:
            can_double_jump = true
    else:
        can_double_jump = true
        coyote_timer = COYOTE_TIME
        # Consume buffered jump on landing
        if jump_buffer_timer > 0:
            jump_buffer_timer = 0.0
            velocity.y = jump_force * jump_mult
            AudioManager.play_sfx("jump")

    # Variable jump height — release early to cut jump arc
    if Input.is_action_just_released("jump") and velocity.y < 0:
        velocity.y *= 0.5

    # Movement
    var direction := Input.get_axis("move_left", "move_right")
    velocity.x = direction * walk_speed * speed_mult

    if direction != 0:
        facing_right = direction > 0
        sprite.scale.x = 1.0 if facing_right else -1.0
    else:
        velocity.x = move_toward(velocity.x, 0.0, walk_speed * speed_mult)

    # Jump
    if Input.is_action_just_pressed("jump"):
        if is_on_floor() or coyote_timer > 0:
            velocity.y = jump_force * jump_mult
            coyote_timer = 0.0
            can_double_jump = true
            AudioManager.play_sfx("jump")
        elif can_double_jump and not GameManager.has_power_up("big"):
            velocity.y = double_jump_force * jump_mult
            can_double_jump = false
            AudioManager.play_sfx("double_jump")
        else:
            jump_buffer_timer = JUMP_BUFFER

    # Visual tint based on power-up
    if GameManager.has_power_up("diamond"):
        sprite.color = Color(0.0, 1.0, 1.0, 0.9)
    elif GameManager.has_power_up("blaze"):
        sprite.color = Color(0.2, 1.0, 0.2, 0.9)
    elif GameManager.has_power_up("big"):
        sprite.color = Color(1.0, 0.4, 0.4, 0.9)
    else:
        sprite.color = Color(0.2, 0.8, 0.2, 1.0)

    move_and_slide()

    # Enable/disable aura Area2D based on diamond mode
    aura.monitoring = GameManager.has_power_up("diamond")

    GameManager.player_position = global_position

func emit_blaze_smoke() -> void:
    var puff := preload("res://src/effects/smoke_puff.tscn").instantiate()
    puff.global_position = smoke_spawn.global_position
    var base_dir := Vector2.RIGHT if facing_right else Vector2.LEFT
    puff.direction = base_dir + Vector2(velocity.x * 0.3 / walk_speed, 0.0)
    get_tree().current_scene.add_child(puff)

func take_damage(amount: int) -> void:
    if StateMachine.is_dead() or invincible_timer > 0:
        return
    GameManager.take_damage(amount)
    ScreenShake.shake(0.2, 5.0)
    if GameManager.player_health <= 0:
        die()
    else:
        velocity.y = -250.0
        velocity.x = -200.0 if facing_right else 200.0
        invincible_timer = 1.0
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
        invincible_timer = 1.5
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

func set_outfit(outfit: Outfit) -> void:
    current_outfit = outfit
    match outfit:
        Outfit.DEFAULT:
            sprite.color = Color(0.2, 0.8, 0.3, 1.0)
        Outfit.MINER:
            sprite.color = Color(0.6, 0.5, 0.2, 1.0)
        Outfit.CRYSTAL:
            sprite.color = Color(0.3, 0.6, 0.9, 1.0)
