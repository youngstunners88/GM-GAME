extends CharacterBody2D

@export var roll_speed: float = 200.0
@export var gravity: float = 980.0

var direction: float = 1.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
    add_to_group("hazard")

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
