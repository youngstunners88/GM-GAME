extends CharacterBody2D

@export var roll_speed: float = 200.0
@export var gravity: float = 980.0

var direction: float = 1.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
    add_to_group("hazard")
    # Invisible adaptive difficulty (task #23): players who keep dying to
    # boulders get a 1-second smoke-puff warning before it starts rolling.
    if DifficultyManager.boulder_warning:
        set_physics_process(false)
        _puff_warning()
        get_tree().create_timer(1.0).timeout.connect(func() -> void:
            if is_instance_valid(self):
                set_physics_process(true))

## Soft grey puff at the boulder's position — a readable "incoming" tell.
func _puff_warning() -> void:
    var puff := CPUParticles2D.new()
    puff.amount = 10
    puff.lifetime = 0.9
    puff.one_shot = true
    puff.emitting = true
    puff.spread = 180.0
    puff.initial_velocity_min = 20.0
    puff.initial_velocity_max = 55.0
    puff.scale_amount_min = 6.0
    puff.scale_amount_max = 14.0
    puff.color = Color(0.8, 0.8, 0.82, 0.5)
    add_child(puff)
    get_tree().create_timer(1.2).timeout.connect(func() -> void:
        if is_instance_valid(puff):
            puff.queue_free())

func _physics_process(delta: float) -> void:
    velocity.x = roll_speed * direction
    velocity.y += gravity * delta

    move_and_slide()

    # Bounce off walls
    if is_on_wall():
        direction *= -1.0

    # Rotate visual
    sprite.rotation += direction * roll_speed * delta * 0.01

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and body.has_method("take_damage"):
        GameManager.last_damage_source = "boulder"
        body.take_damage(2)

## Pickaxe tool shatters boulders instead of the player taking damage.
func smash() -> void:
    set_physics_process(false)
    GameManager.add_score(75)
    AudioManager.play_sfx("damage")
    ScreenShake.shake(0.15, 4.0)
    var tween := create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
    tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
    tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
    tween.finished.connect(queue_free)
