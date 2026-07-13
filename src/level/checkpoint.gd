extends Area2D

@export var checkpoint_id: int = 0
## Which level this checkpoint belongs to — set by EntitySpawner as a
## pre-add_child prop (see level_base.gd) so it's correct before any touch.
## Was hardcoded to 1 for every level; a Level 2/3 checkpoint silently
## clobbered Level 1's save slot, and every level's respawn read slot 1 back.
@export var level_index: int = 1

@onready var sprite: ColorRect = $ColorRect

var activated: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    sprite.color = Color(0.5, 0.5, 1.0, 0.5)
    sprite.size = Vector2(32, 48)
    $CollisionShape2D.position = Vector2(16, 24)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") and not activated:
        activated = true
        GameManager.save_checkpoint(level_index, checkpoint_id, global_position)
        sprite.color = Color(0.2, 1.0, 0.2, 0.8)
        AudioManager.play_sfx("powerup")
        # Flash effect
        var tween := create_tween()
        tween.tween_property(sprite, "scale:y", 1.5, 0.2)
        tween.tween_property(sprite, "scale:y", 1.0, 0.2)
