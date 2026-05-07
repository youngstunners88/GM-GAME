class_name Player
extends CharacterBody2D

signal died

@export var walk_speed: float = 200.0
@export var jump_force: float = -420.0
@export var gravity: float = 980.0
@export var double_jump_force: float = -350.0

var can_double_jump: bool = false
var facing_right: bool = true
var is_dead: bool = false
var blaze_smoke_timer: float = 0.0
var invincible_timer: float = 0.0

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var smoke_spawn: Marker2D = $SmokeSpawn
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
    add_to_group("player")
    GameManager.reset_level()
    hurtbox.area_entered.connect(_on_hurtbox_area_entered)
    hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _physics_process(delta: float) -> void:
    if is_dead:
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

    # Gravity
    if not is_on_floor():
        velocity.y += gravity * delta
    else:
        can_double_jump = true

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
        if is_on_floor():
            velocity.y = jump_force * jump_mult
            can_double_jump = true
            AudioManager.play_sfx("jump")
        elif can_double_jump and not GameManager.has_power_up("big"):
            velocity.y = double_jump_force * jump_mult
            can_double_jump = false
            AudioManager.play_sfx("double_jump")

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

    # Diamond aura damage
    if GameManager.has_power_up("diamond"):
        for i in range(get_slide_collision_count()):
            var col := get_slide_collision(i)
            var collider := col.get_collider()
            if collider and collider.is_in_group("enemy") and collider.has_method("take_damage"):
                collider.take_damage(1)

    GameManager.player_position = global_position

func emit_blaze_smoke() -> void:
    var puff := preload("res://effects/smoke_puff.tscn").instantiate()
    puff.global_position = smoke_spawn.global_position
    puff.direction = Vector2.RIGHT if facing_right else Vector2.LEFT
    get_tree().current_scene.add_child(puff)

func take_damage(amount: int) -> void:
    if is_dead or invincible_timer > 0:
        return
    GameManager.take_damage(amount)
    if GameManager.player_health <= 0:
        die()
    else:
        velocity.y = -250.0
        velocity.x = -200.0 if facing_right else 200.0
        invincible_timer = 1.0
        AudioManager.play_sfx("damage")

func die() -> void:
    is_dead = true
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
    tween.tween_property(self, "modulate:a", 0.0, 0.5)
    await tween.finished
    died.emit()
    var checkpoint := GameManager.get_checkpoint(1)
    if checkpoint != Vector2.ZERO:
        global_position = checkpoint
        GameManager.player_health = GameManager.max_health
        is_dead = false
        scale = Vector2.ONE
        modulate.a = 1.0
        velocity = Vector2.ZERO
        invincible_timer = 1.5
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
