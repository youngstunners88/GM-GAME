extends CharacterBody2D

enum State { PATROL, CHARGE, VULNERABLE, DEFEATED }

@export var patrol_speed: float = 80.0
@export var charge_speed: float = 300.0
@export var vulnerable_time: float = 2.0
@export var max_health: int = 5

var current_state: State = State.PATROL
var health: int = 5
var patrol_direction: float = 1.0
var charge_target: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var is_dead: bool = false

@onready var sprite: ColorRect = $ColorRect
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
    add_to_group("enemy")
    add_to_group("boss")
    health = max_health
    sprite.color = Color(0.4, 0.25, 0.15, 1.0)
    sprite.size = Vector2(96, 96)
    collision.position = Vector2(48, 48)
    hitbox.position = Vector2(48, 48)
    hitbox_shape.shape = collision.shape
    hitbox.body_entered.connect(_on_hitbox_body_entered)
    hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    state_timer -= delta

    match current_state:
        State.PATROL:
            velocity.x = patrol_speed * patrol_direction
            velocity.y += 980.0 * delta
            move_and_slide()
            if is_on_wall():
                patrol_direction *= -1.0
                sprite.scale.x = 1.0 if patrol_direction > 0 else -1.0
            if state_timer <= 0:
                state_timer = 1.5
                current_state = State.CHARGE
                var player := get_tree().get_first_node_in_group("player")
                if player:
                    charge_target = player.global_position

        State.CHARGE:
            var dir := global_position.direction_to(charge_target)
            velocity.x = dir.x * charge_speed
            velocity.y += 980.0 * delta
            move_and_slide()
            if state_timer <= 0 or is_on_wall():
                state_timer = vulnerable_time
                current_state = State.VULNERABLE
                sprite.color = Color(1.0, 0.2, 0.2, 1.0)
                hitbox.monitorable = true
                hitbox.monitoring = true

        State.VULNERABLE:
            velocity.x = move_toward(velocity.x, 0.0, 200.0)
            velocity.y += 980.0 * delta
            move_and_slide()
            # Flash red
            sprite.modulate = Color(1.0, 0.3, 0.3, 1.0) if fmod(state_timer, 0.3) < 0.15 else Color(1.0, 0.1, 0.1, 1.0)
            if state_timer <= 0:
                sprite.modulate = Color(1, 1, 1, 1)
                sprite.color = Color(0.4, 0.25, 0.15, 1.0)
                current_state = State.PATROL
                state_timer = 3.0
                hitbox.monitorable = false
                hitbox.monitoring = false

func take_damage(amount: int) -> void:
    if is_dead or current_state != State.VULNERABLE:
        return
    health -= amount
    AudioManager.play_sfx("damage")
    var tween := create_tween()
    tween.tween_property(sprite, "modulate", Color(10, 10, 10, 1), 0.05)
    tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.05)
    if health <= 0:
        die()
    else:
        # Brief knockback then back to patrol
        current_state = State.PATROL
        state_timer = 2.0
        sprite.color = Color(0.4, 0.25, 0.15, 1.0)
        hitbox.monitorable = false
        hitbox.monitoring = false

func die() -> void:
    is_dead = true
    GameManager.add_score(500)
    hitbox.monitorable = false
    hitbox.monitoring = false
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2.ZERO, 1.0)
    tween.parallel().tween_property(self, "rotation", PI * 4, 1.0)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
    await tween.finished
    # Show victory
    var victory := Label.new()
    victory.text = "LEVEL COMPLETE!\nChill vibes only."
    victory.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    victory.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    victory.position = global_position - Vector2(100, 50)
    victory.add_theme_font_size_override("font_size", 32)
    get_tree().current_scene.add_child(victory)
    await get_tree().create_timer(3.0).timeout
    SceneTransition.transition_to_scene("res://ui/main_menu.tscn")
    queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and body.has_method("take_damage"):
        body.take_damage(1)

func _on_hitbox_area_entered(area: Area2D) -> void:
    if area.is_in_group("projectile"):
        take_damage(1)
